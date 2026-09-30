"""
Database management module supporting PostgreSQL pooling, MySQL connection pooling,
and SQLite fallback. Provides thread-safe query execution and transaction handling.
"""

import os
import re
import sqlite3
import logging
from contextlib import contextmanager
from urllib.parse import urlparse, urlunparse

try:
    import psycopg2
    from psycopg2 import pool as pg_pool
    from psycopg2.extras import RealDictCursor
    POSTGRES_AVAILABLE = True
except ImportError:
    POSTGRES_AVAILABLE = False

try:
    import mysql.connector
    from mysql.connector import Error, pooling as mysql_pooling
    MYSQL_AVAILABLE = True
except ImportError:
    MYSQL_AVAILABLE = False
    Error = Exception

from config import Config

logger = logging.getLogger('database')


def sanitize_db_url(url):
    """Sanitize database URL by masking password for safe logging."""
    if not url:
        return ""
    try:
        parsed = urlparse(url)
        if parsed.password:
            user = parsed.username or ''
            host = parsed.hostname or ''
            port = f":{parsed.port}" if parsed.port else ""
            netloc = f"{user}:***@{host}{port}"
            return urlunparse((parsed.scheme, netloc, parsed.path, parsed.params, parsed.query, parsed.fragment))
        return url
    except Exception:
        return "postgresql://***:***@***"


class Database:
    """Thread-safe database connection and query handler supporting PostgreSQL pooling, MySQL pooling, and SQLite."""

    def __init__(self, config=None):
        self.config = config or Config
        self.pool = None
        self.engine = None  # 'postgresql', 'mysql', or 'sqlite'
        self.sqlite_path = None
        self._initialized = False

    @property
    def use_sqlite(self):
        return self.engine == 'sqlite'

    @use_sqlite.setter
    def use_sqlite(self, value):
        if value:
            self.engine = 'sqlite'
        elif self.engine == 'sqlite':
            self.engine = None

    @property
    def engine_name(self):
        if self.engine == 'postgresql':
            return 'PostgreSQL'
        elif self.engine == 'mysql':
            return 'MySQL'
        elif self.engine == 'sqlite' or self.use_sqlite:
            return 'SQLite'
        # If connect has not yet established an engine, infer target from config
        force_sqlite = str(self._cfg('USE_SQLITE', os.getenv('USE_SQLITE', 'false'))).lower() in ('true', '1')
        if force_sqlite:
            return 'SQLite'
        db_url = self._cfg('DATABASE_URL', os.getenv('DATABASE_URL', ''))
        if db_url and isinstance(db_url, str) and db_url.strip():
            return 'PostgreSQL'
        return 'MySQL'

    def _cfg(self, key, default=None):
        if isinstance(self.config, dict):
            return self.config.get(key, default)
        return getattr(self.config, key, default)

    def connect(self):
        """Establish database connection pool based on configuration hierarchy.

        Selection hierarchy:
        1. If USE_SQLITE=true explicitly -> SQLite (used for isolated testing)
        2. Else if DATABASE_URL is configured -> PostgreSQL (no fallback to SQLite if unreachable)
        3. Else -> MySQL (local development default; no silent fallback to SQLite)
        """
        force_sqlite = str(self._cfg('USE_SQLITE', os.getenv('USE_SQLITE', 'false'))).lower() in ('true', '1')

        # 1. Explicit SQLite mode (testing / isolated runs)
        if force_sqlite:
            return self._init_sqlite()

        # 2. PostgreSQL (Production / Cloud via DATABASE_URL)
        db_url = self._cfg('DATABASE_URL', os.getenv('DATABASE_URL', ''))
        if db_url and isinstance(db_url, str) and db_url.strip():
            db_url = db_url.strip()
            self.engine = 'postgresql'
            if POSTGRES_AVAILABLE:
                try:
                    pool_size = int(self._cfg('POSTGRES_POOL_SIZE', 5))
                    conn_url = db_url
                    if conn_url.startswith('postgres://'):
                        conn_url = 'postgresql://' + conn_url[len('postgres://'):]

                    self.pool = pg_pool.ThreadedConnectionPool(
                        minconn=1,
                        maxconn=pool_size,
                        dsn=conn_url,
                    )
                    self._initialized = True
                    self._init_postgres_schema()
                    sanitized = sanitize_db_url(db_url)
                    logger.info("PostgreSQL connection pool established successfully (%s, max_conn=%d)", sanitized, pool_size)
                    return True
                except Exception as e:
                    logger.error("PostgreSQL connection failed: %s. Database is unavailable (no silent fallback).", e)
                    if self.pool and hasattr(self.pool, 'closeall'):
                        try:
                            self.pool.closeall()
                        except Exception:
                            pass
                    self.pool = None
                    self._initialized = False
                    return False
            else:
                logger.error("DATABASE_URL is configured but psycopg2 is not installed. Database is unavailable.")
                self.pool = None
                self._initialized = False
                return False

        # 3. MySQL (Local development default)
        self.engine = 'mysql'
        if MYSQL_AVAILABLE:
            try:
                pool_size = int(self._cfg('MYSQL_POOL_SIZE', 5))
                host = self._cfg('MYSQL_HOST', '127.0.0.1')
                port = int(self._cfg('MYSQL_PORT', 3306))
                user = self._cfg('MYSQL_USER', 'root')
                password = self._cfg('MYSQL_PASSWORD', '')
                database = self._cfg('MYSQL_DB', 'pii_redaction_system')

                # Ensure database exists if MySQL user has permission
                try:
                    admin_conn = mysql.connector.connect(
                        host=host,
                        port=port,
                        user=user,
                        password=password
                    )
                    admin_cur = admin_conn.cursor()
                    admin_cur.execute(f"CREATE DATABASE IF NOT EXISTS `{database}`")
                    admin_cur.close()
                    admin_conn.close()
                except Exception as db_err:
                    logger.debug("Database creation check skipped: %s", db_err)

                self.pool = mysql_pooling.MySQLConnectionPool(
                    pool_name="pii_redaction_pool",
                    pool_size=pool_size,
                    pool_reset_session=True,
                    host=host,
                    port=port,
                    user=user,
                    password=password,
                    database=database,
                )
                self._initialized = True
                self._init_mysql_schema()
                logger.info("MySQL connection pool established successfully for '%s'", database)
                return True
            except Exception as e:
                logger.error("MySQL connection failed: %s. Database is unavailable.", e)
                self.pool = None
                self._initialized = False
                return False

        logger.error("MySQL driver not available and no alternative database configured.")
        self.pool = None
        self._initialized = False
        return False

    def _init_postgres_schema(self):
        """Ensure all required tables exist in PostgreSQL with proper indexes and constraints."""
        schema_statements = [
            """
            CREATE TABLE IF NOT EXISTS users (
                id SERIAL PRIMARY KEY,
                username VARCHAR(255) UNIQUE NOT NULL,
                email VARCHAR(255) UNIQUE NOT NULL,
                password VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_users_email ON users (email);
            """,
            """
            CREATE TABLE IF NOT EXISTS audit_logs (
                id SERIAL PRIMARY KEY,
                user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                action VARCHAR(255) NOT NULL,
                details TEXT,
                status VARCHAR(50) DEFAULT 'success',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs (user_id);
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs (created_at);
            """,
            """
            CREATE TABLE IF NOT EXISTS documents (
                id SERIAL PRIMARY KEY,
                user_id INT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                filename VARCHAR(255) NOT NULL,
                original_filename VARCHAR(255) NOT NULL,
                doc_type VARCHAR(100),
                status VARCHAR(50) DEFAULT 'processed',
                file_path VARCHAR(500),
                pii_detected JSONB,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_documents_user_id ON documents (user_id);
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_documents_created_at ON documents (created_at);
            """,
            """
            CREATE TABLE IF NOT EXISTS user_security (
                id SERIAL PRIMARY KEY,
                user_id INT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
                pin_code VARCHAR(255),
                fingerprint_data TEXT,
                is_fingerprint_enabled BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_user_security_user_id ON user_security (user_id);
            """
        ]

        trigger_statements = [
            """
            CREATE OR REPLACE FUNCTION update_updated_at_column()
            RETURNS TRIGGER AS $$
            BEGIN
                NEW.updated_at = CURRENT_TIMESTAMP;
                RETURN NEW;
            END;
            $$ LANGUAGE 'plpgsql';
            """,
            """
            DO $$
            BEGIN
                IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'set_timestamp_users') THEN
                    CREATE TRIGGER set_timestamp_users
                    BEFORE UPDATE ON users
                    FOR EACH ROW
                    EXECUTE FUNCTION update_updated_at_column();
                END IF;
                IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'set_timestamp_user_security') THEN
                    CREATE TRIGGER set_timestamp_user_security
                    BEFORE UPDATE ON user_security
                    FOR EACH ROW
                    EXECUTE FUNCTION update_updated_at_column();
                END IF;
            END $$;
            """
        ]

        with self.get_connection() as conn:
            cursor = conn.cursor()
            try:
                for stmt in schema_statements:
                    cursor.execute(stmt)
                conn.commit()

                # Attempt trigger creation (non-critical if user lacks permissions)
                try:
                    for stmt in trigger_statements:
                        cursor.execute(stmt)
                    conn.commit()
                except Exception as trig_err:
                    conn.rollback()
                    logger.debug("PostgreSQL trigger creation skipped: %s", trig_err)
            finally:
                cursor.close()
        logger.info("PostgreSQL schema verification completed")

    def _init_mysql_schema(self):
        """Ensure all required tables exist in MySQL with proper indexes and constraints."""
        schema_statements = [
            """
            CREATE TABLE IF NOT EXISTS users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(255) UNIQUE NOT NULL,
                email VARCHAR(255) UNIQUE NOT NULL,
                password VARCHAR(255) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_username (username),
                INDEX idx_email (email)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """,
            """
            CREATE TABLE IF NOT EXISTS audit_logs (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                action VARCHAR(255) NOT NULL,
                details TEXT,
                status VARCHAR(50) DEFAULT 'success',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_user_id (user_id),
                INDEX idx_created_at (created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """,
            """
            CREATE TABLE IF NOT EXISTS documents (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                filename VARCHAR(255) NOT NULL,
                original_filename VARCHAR(255) NOT NULL,
                doc_type VARCHAR(100),
                status VARCHAR(50) DEFAULT 'processed',
                file_path VARCHAR(500),
                pii_detected JSON,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_user_id (user_id),
                INDEX idx_created_at (created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """,
            """
            CREATE TABLE IF NOT EXISTS user_security (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL UNIQUE,
                pin_code VARCHAR(255),
                fingerprint_data LONGTEXT,
                is_fingerprint_enabled BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                INDEX idx_user_id (user_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
            """
        ]
        with self.get_connection() as conn:
            cursor = conn.cursor()
            try:
                for stmt in schema_statements:
                    cursor.execute(stmt)
                conn.commit()
            finally:
                cursor.close()
        logger.info("MySQL schema verification completed")

    def _init_sqlite(self):
        """Initialize local SQLite database with required schema."""
        self.engine = 'sqlite'
        base_dir = os.path.dirname(os.path.abspath(__file__))
        self.sqlite_path = self._cfg('SQLITE_PATH', os.path.join(base_dir, 'privlock.db'))

        conn = None
        try:
            conn = sqlite3.connect(self.sqlite_path)
            cursor = conn.cursor()
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                email TEXT UNIQUE NOT NULL,
                password TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
            """)
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS audit_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                action TEXT NOT NULL,
                details TEXT,
                status TEXT DEFAULT 'success',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            );
            """)
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS documents (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                filename TEXT NOT NULL,
                original_filename TEXT NOT NULL,
                doc_type TEXT,
                status TEXT DEFAULT 'processed',
                file_path TEXT,
                pii_detected TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            );
            """)
            cursor.execute("""
            CREATE TABLE IF NOT EXISTS user_security (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL UNIQUE,
                pin_code TEXT,
                fingerprint_data TEXT,
                is_fingerprint_enabled INTEGER DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            );
            """)
            conn.commit()
            self._initialized = True
            logger.info("SQLite database initialized at %s", self.sqlite_path)
            return True
        except Exception as e:
            logger.error("SQLite initialization failed: %s", e)
            return False
        finally:
            if conn:
                try:
                    conn.close()
                except Exception:
                    pass

    @contextmanager
    def get_connection(self):
        """Context manager to obtain and safely release a database connection."""
        if not self._initialized:
            if not self.connect():
                raise RuntimeError(f"Database ({self.engine_name}) connection could not be established")

        if self.engine == 'sqlite':
            conn = sqlite3.connect(self.sqlite_path)
            conn.row_factory = sqlite3.Row
            try:
                yield conn
            finally:
                conn.close()
        elif self.engine == 'postgresql':
            conn = self.pool.getconn()
            try:
                yield conn
            finally:
                if self.pool and conn:
                    try:
                        self.pool.putconn(conn)
                    except Exception:
                        pass
        else:  # mysql
            conn = None
            max_retries = 10
            for attempt in range(max_retries):
                try:
                    conn = self.pool.get_connection()
                    break
                except Exception as e:
                    if 'pool exhausted' in str(e).lower() and attempt < max_retries - 1:
                        import time
                        time.sleep(0.05)
                        continue
                    if self.connect() and self.engine == 'mysql':
                        conn = self.pool.get_connection()
                        break
                    else:
                        raise
            try:
                yield conn
            finally:
                if conn and hasattr(conn, 'close'):
                    try:
                        conn.close()
                    except Exception:
                        pass

    def disconnect(self):
        """Release connections/pools (mostly for shutdown or tests)."""
        if self.engine == 'postgresql' and self.pool:
            try:
                self.pool.closeall()
            except Exception as e:
                logger.debug("Error closing PostgreSQL pool: %s", e)
        self.pool = None
        self.engine = None
        self._initialized = False

    def query(self, sql, params=None):
        """Execute a SELECT query and return list of row dictionaries."""
        params = params or ()
        try:
            with self.get_connection() as conn:
                if self.engine == 'sqlite':
                    # Translate MySQL %s placeholder to SQLite ?
                    sql_converted = sql.replace('%s', '?')
                    cursor = conn.cursor()
                    try:
                        cursor.execute(sql_converted, params)
                        return [dict(row) for row in cursor.fetchall()]
                    finally:
                        cursor.close()
                elif self.engine == 'postgresql':
                    cursor = conn.cursor(cursor_factory=RealDictCursor)
                    try:
                        cursor.execute(sql, params)
                        return [dict(row) for row in cursor.fetchall()]
                    finally:
                        cursor.close()
                else:  # mysql
                    cursor = conn.cursor(dictionary=True)
                    try:
                        cursor.execute(sql, params)
                        return cursor.fetchall()
                    finally:
                        cursor.close()
        except Exception as e:
            logger.error("Database query error: %s [SQL: %s]", e, sql)
            return None

    def execute(self, sql, params=None):
        """Execute an INSERT, UPDATE, or DELETE statement with transaction commit."""
        params = params or ()
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                try:
                    if self.engine == 'sqlite':
                        sql_converted = sql.replace('%s', '?')
                        # SQLite ON DUPLICATE KEY UPDATE replacement
                        if 'ON DUPLICATE KEY UPDATE' in sql_converted.upper():
                            if 'user_security' in sql_converted:
                                sql_converted = """
                                INSERT INTO user_security (user_id, pin_code, fingerprint_data, is_fingerprint_enabled)
                                VALUES (?, ?, ?, ?)
                                ON CONFLICT(user_id) DO UPDATE SET
                                    pin_code = COALESCE(excluded.pin_code, user_security.pin_code),
                                    fingerprint_data = COALESCE(excluded.fingerprint_data, user_security.fingerprint_data),
                                    is_fingerprint_enabled = COALESCE(excluded.is_fingerprint_enabled, user_security.is_fingerprint_enabled),
                                    updated_at = CURRENT_TIMESTAMP
                                """
                        cursor.execute(sql_converted, params)
                        conn.commit()
                        affected = cursor.rowcount
                        last_id = cursor.lastrowid
                        return {'affected': affected, 'last_id': last_id}
                    elif self.engine == 'postgresql':
                        sql_exec = sql
                        # Translate MySQL upsert syntax to PostgreSQL ON CONFLICT
                        if 'ON DUPLICATE KEY UPDATE' in sql_exec.upper():
                            if 'user_security' in sql_exec:
                                sql_exec = """
                                INSERT INTO user_security (user_id, pin_code, fingerprint_data, is_fingerprint_enabled)
                                VALUES (%s, %s, %s, %s)
                                ON CONFLICT (user_id) DO UPDATE SET
                                    pin_code = COALESCE(EXCLUDED.pin_code, user_security.pin_code),
                                    fingerprint_data = COALESCE(EXCLUDED.fingerprint_data, user_security.fingerprint_data),
                                    is_fingerprint_enabled = COALESCE(EXCLUDED.is_fingerprint_enabled, user_security.is_fingerprint_enabled),
                                    updated_at = CURRENT_TIMESTAMP
                                """
                        # Normalize boolean literal compatibility for PostgreSQL
                        if 'is_fingerprint_enabled = 1' in sql_exec:
                            sql_exec = sql_exec.replace('is_fingerprint_enabled = 1', 'is_fingerprint_enabled = TRUE')
                        elif 'is_fingerprint_enabled = 0' in sql_exec:
                            sql_exec = sql_exec.replace('is_fingerprint_enabled = 0', 'is_fingerprint_enabled = FALSE')
                        if ', 1)' in sql_exec and 'user_security' in sql_exec:
                            sql_exec = sql_exec.replace(', 1)', ', TRUE)')
                        elif ', 0)' in sql_exec and 'user_security' in sql_exec:
                            sql_exec = sql_exec.replace(', 0)', ', FALSE)')

                        # Handle last_id on INSERT statements
                        table_match = re.search(r'^\s*INSERT\s+INTO\s+([a-zA-Z0-9_]+)', sql_exec, re.IGNORECASE)
                        has_returning = 'RETURNING' in sql_exec.upper()
                        last_id = None

                        if table_match and not has_returning and table_match.group(1).lower() in ('users', 'audit_logs', 'documents', 'user_security'):
                            cursor.execute(sql_exec + " RETURNING id", params)
                            row = cursor.fetchone()
                            if row:
                                last_id = row[0]
                        else:
                            cursor.execute(sql_exec, params)

                        conn.commit()
                        affected = cursor.rowcount
                        return {'affected': affected, 'last_id': last_id}
                    else:  # mysql
                        cursor.execute(sql, params)
                        conn.commit()
                        affected = cursor.rowcount
                        last_id = cursor.lastrowid
                        return {'affected': affected, 'last_id': last_id}
                except Exception:
                    if hasattr(conn, 'rollback'):
                        try:
                            conn.rollback()
                        except Exception:
                            pass
                    raise
                finally:
                    cursor.close()
        except Exception as e:
            logger.error("Database execute error: %s [SQL: %s]", e, sql)
            return None

    def query_one(self, sql, params=None):
        """Execute a query and return only the first record."""
        results = self.query(sql, params)
        return results[0] if results else None


# Global database singleton
db = Database()
