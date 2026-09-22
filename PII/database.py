"""
Database management module with MySQL connection pooling and optional SQLite fallback.
Provides thread-safe query execution and transaction handling.
"""

import os
import sqlite3
import logging
from contextlib import contextmanager

try:
    import mysql.connector
    from mysql.connector import Error, pooling
    MYSQL_AVAILABLE = True
except ImportError:
    MYSQL_AVAILABLE = False
    Error = Exception

from config import Config

logger = logging.getLogger('database')


class Database:
    """Thread-safe database connection and query handler supporting MySQL pooling and SQLite."""

    def __init__(self, config=None):
        self.config = config or Config
        self.pool = None
        self.use_sqlite = False
        self.sqlite_path = None
        self._initialized = False

    def _cfg(self, key, default=None):
        if isinstance(self.config, dict):
            return self.config.get(key, default)
        return getattr(self.config, key, default)

    def connect(self):
        """Establish database connection pool (MySQL) or initialize SQLite fallback."""
        force_sqlite = str(self._cfg('USE_SQLITE', 'false')).lower() in ('true', '1')

        if not force_sqlite and MYSQL_AVAILABLE:
            try:
                pool_size = int(self._cfg('MYSQL_POOL_SIZE', 5))
                self.pool = pooling.MySQLConnectionPool(
                    pool_name="pii_redaction_pool",
                    pool_size=pool_size,
                    pool_reset_session=True,
                    host=self._cfg('MYSQL_HOST', '127.0.0.1'),
                    port=int(self._cfg('MYSQL_PORT', 3306)),
                    user=self._cfg('MYSQL_USER', 'root'),
                    password=self._cfg('MYSQL_PASSWORD', ''),
                    database=self._cfg('MYSQL_DB', 'pii_redaction_db'),
                )
                self.use_sqlite = False
                self._initialized = True
                logger.info("MySQL connection pool established successfully")
                return True
            except Exception as e:
                logger.warning("MySQL connection failed: %s. Initializing SQLite fallback.", e)

        # SQLite fallback mode
        return self._init_sqlite()

    def _init_sqlite(self):
        """Initialize local SQLite database with required schema."""
        self.use_sqlite = True
        base_dir = os.path.dirname(os.path.abspath(__file__))
        self.sqlite_path = self._cfg('SQLITE_PATH', os.path.join(base_dir, 'privlock.db'))

        try:
            with sqlite3.connect(self.sqlite_path) as conn:
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

    @contextmanager
    def get_connection(self):
        """Context manager to obtain and safely release a database connection."""
        if not self._initialized:
            if not self.connect():
                raise RuntimeError("Database connection could not be established")

        if self.use_sqlite:
            conn = sqlite3.connect(self.sqlite_path)
            conn.row_factory = sqlite3.Row
            try:
                yield conn
            finally:
                conn.close()
        else:
            conn = None
            try:
                conn = self.pool.get_connection()
                yield conn
            except Exception:
                # If pool connection fails, try reconnecting pool once
                if self.connect() and not self.use_sqlite:
                    conn = self.pool.get_connection()
                    yield conn
                else:
                    raise
            finally:
                if conn and hasattr(conn, 'close'):
                    try:
                        conn.close()
                    except Exception:
                        pass

    def disconnect(self):
        """Release connections/pools (mostly for shutdown or tests)."""
        self.pool = None
        self._initialized = False

    def query(self, sql, params=None):
        """Execute a SELECT query and return list of row dictionaries."""
        params = params or ()
        try:
            with self.get_connection() as conn:
                if self.use_sqlite:
                    # Translate MySQL %s placeholder to SQLite ?
                    sql_converted = sql.replace('%s', '?')
                    cursor = conn.cursor()
                    cursor.execute(sql_converted, params)
                    rows = [dict(row) for row in cursor.fetchall()]
                    cursor.close()
                    return rows
                else:
                    cursor = conn.cursor(dictionary=True)
                    cursor.execute(sql, params)
                    rows = cursor.fetchall()
                    cursor.close()
                    return rows
        except Exception as e:
            logger.error("Database query error: %s [SQL: %s]", e, sql)
            return None

    def execute(self, sql, params=None):
        """Execute an INSERT, UPDATE, or DELETE statement with transaction commit."""
        params = params or ()
        try:
            with self.get_connection() as conn:
                if self.use_sqlite:
                    sql_converted = sql.replace('%s', '?')
                    # SQLite ON DUPLICATE KEY UPDATE replacement
                    if 'ON DUPLICATE KEY UPDATE' in sql_converted.upper():
                        # Handle user_security upsert for SQLite
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
                    cursor = conn.cursor()
                    cursor.execute(sql_converted, params)
                    conn.commit()
                    affected = cursor.rowcount
                    last_id = cursor.lastrowid
                    cursor.close()
                    return {'affected': affected, 'last_id': last_id}
                else:
                    cursor = conn.cursor()
                    cursor.execute(sql, params)
                    conn.commit()
                    affected = cursor.rowcount
                    last_id = cursor.lastrowid
                    cursor.close()
                    return {'affected': affected, 'last_id': last_id}
        except Exception as e:
            logger.error("Database execute error: %s [SQL: %s]", e, sql)
            return None

    def query_one(self, sql, params=None):
        """Execute a query and return only the first record."""
        results = self.query(sql, params)
        return results[0] if results else None


# Global database singleton
db = Database()
