"""
Unit and integration tests for PrivLock database management.
Tests PostgreSQL, MySQL, and SQLite configuration, strict selection hierarchy,
URL sanitization, SQL dialect translation, absence of silent fallback, and persistence.
"""

import os
import unittest
import tempfile
import shutil
from unittest.mock import patch, MagicMock

import database
from database import Database, sanitize_db_url


class TestDatabaseManagement(unittest.TestCase):
    """Test suite for database abstraction layer across engines."""

    def setUp(self):
        self.temp_dir = tempfile.mkdtemp()
        self.sqlite_file = os.path.join(self.temp_dir, 'test_privlock.db')

    def tearDown(self):
        shutil.rmtree(self.temp_dir, ignore_errors=True)

    # ==================== 1. URL SANITIZATION ====================

    def test_sanitize_db_url_masks_password(self):
        """Sanitizer masks password while preserving host, user, port, and database."""
        raw_url = "postgresql://privlock_user:super_secret_pwd@ep-xyz.us-east-2.aws.neon.tech:5432/neondb?sslmode=require"
        sanitized = sanitize_db_url(raw_url)
        self.assertNotIn("super_secret_pwd", sanitized)
        self.assertIn("privlock_user:***", sanitized)
        self.assertIn("ep-xyz.us-east-2.aws.neon.tech:5432", sanitized)
        self.assertIn("neondb", sanitized)
        self.assertIn("sslmode=require", sanitized)

    def test_sanitize_db_url_without_password(self):
        """Sanitizer leaves URLs without passwords untouched."""
        url = "postgresql://localhost:5432/mydb"
        self.assertEqual(sanitize_db_url(url), url)

    def test_sanitize_db_url_handles_empty(self):
        """Sanitizer safely handles empty or None input."""
        self.assertEqual(sanitize_db_url(""), "")
        self.assertEqual(sanitize_db_url(None), "")

    # ==================== 2. SELECTION HIERARCHY & NO SILENT FALLBACK ====================

    def test_selection_A_explicit_sqlite_mode(self):
        """A. Explicit USE_SQLITE=true takes precedence and initializes SQLite."""
        cfg = {
            'USE_SQLITE': 'true',
            'SQLITE_PATH': self.sqlite_file,
            'DATABASE_URL': 'postgresql://user:pass@host:5432/db',
        }
        db = Database(config=cfg)
        self.assertTrue(db.connect())
        self.assertEqual(db.engine, 'sqlite')
        self.assertTrue(db.use_sqlite)
        self.assertEqual(db.engine_name, 'SQLite')
        self.assertTrue(os.path.exists(self.sqlite_file))
        db.disconnect()

    @patch('database.pg_pool.ThreadedConnectionPool')
    def test_selection_B_database_url_configured(self, mock_pool_cls):
        """B. When DATABASE_URL is set and USE_SQLITE is false, PostgreSQL is selected."""
        mock_pool = MagicMock()
        mock_pool_cls.return_value = mock_pool

        mock_conn = MagicMock()
        mock_cur = MagicMock()
        mock_conn.cursor.return_value = mock_cur
        mock_pool.getconn.return_value = mock_conn

        cfg = {
            'USE_SQLITE': 'false',
            'DATABASE_URL': 'postgresql://admin:secret@ep-xyz.neon.tech:5432/neondb',
            'POSTGRES_POOL_SIZE': 5,
        }
        db = Database(config=cfg)
        result = db.connect()

        self.assertTrue(result)
        self.assertEqual(db.engine, 'postgresql')
        self.assertFalse(db.use_sqlite)
        self.assertEqual(db.engine_name, 'PostgreSQL')
        mock_pool_cls.assert_called_once_with(
            minconn=1,
            maxconn=5,
            dsn='postgresql://admin:secret@ep-xyz.neon.tech:5432/neondb'
        )
        db.disconnect()
        mock_pool.closeall.assert_called_once()

    @patch('database.pg_pool.ThreadedConnectionPool')
    def test_selection_B_postgres_url_scheme_normalization(self, mock_pool_cls):
        """postgres:// URI scheme is normalized to postgresql://."""
        mock_pool = MagicMock()
        mock_pool_cls.return_value = mock_pool
        mock_conn = MagicMock()
        mock_pool.getconn.return_value = mock_conn

        cfg = {
            'USE_SQLITE': 'false',
            'DATABASE_URL': 'postgres://user:pass@host:5432/db',
        }
        db = Database(config=cfg)
        db.connect()

        self.assertEqual(db.engine, 'postgresql')
        call_kwargs = mock_pool_cls.call_args[1]
        self.assertTrue(call_kwargs['dsn'].startswith('postgresql://'))
        db.disconnect()

    def test_selection_C_database_url_absent_and_sqlite_false_selects_mysql(self):
        """C. When DATABASE_URL is absent and USE_SQLITE is false, MySQL is the target engine."""
        cfg = {
            'USE_SQLITE': 'false',
            'DATABASE_URL': None,
        }
        db = Database(config=cfg)
        self.assertEqual(db.engine_name, 'MySQL')
        self.assertFalse(db.use_sqlite)

    def test_selection_D_postgres_failure_reports_error(self):
        """D. When DATABASE_URL is configured but connection fails, connect() fails and db is unavailable."""
        cfg = {
            'USE_SQLITE': 'false',
            'DATABASE_URL': 'postgresql://invalid_user:invalid_pass@127.0.0.1:9999/nonexistent_db',
            'SQLITE_PATH': self.sqlite_file,
        }
        db = Database(config=cfg)
        result = db.connect()

        self.assertFalse(result)
        self.assertFalse(db._initialized)
        self.assertIsNone(db.pool)
        self.assertEqual(db.engine, 'postgresql')
        self.assertEqual(db.engine_name, 'PostgreSQL')
        self.assertIsNone(db.query("SELECT 1"))
        self.assertIsNone(db.execute("DELETE FROM users"))
        db.disconnect()

    def test_selection_E_postgres_failure_does_not_fallback_to_sqlite(self):
        """E. PostgreSQL connection failure does NOT cause automatic fallback to SQLite."""
        cfg = {
            'USE_SQLITE': 'false',
            'DATABASE_URL': 'postgresql://invalid_user:invalid_pass@127.0.0.1:9999/nonexistent_db',
            'SQLITE_PATH': self.sqlite_file,
        }
        db = Database(config=cfg)
        result = db.connect()

        # Connect fails
        self.assertFalse(result)
        # Target remains PostgreSQL, never switched to SQLite
        self.assertEqual(db.engine, 'postgresql')
        self.assertEqual(db.engine_name, 'PostgreSQL')
        self.assertFalse(db.use_sqlite)
        # SQLite file must NOT have been created
        self.assertFalse(os.path.exists(self.sqlite_file))
        db.disconnect()

    def test_selection_E_postgres_failure_health_endpoint_reports_unavailable_not_sqlite(self):
        """Health check reports PostgreSQL as unavailable without silently falling back to SQLite."""
        from app import app
        import database as db_mod

        orig_config = db_mod.db.config
        orig_engine = db_mod.db.engine
        orig_init = db_mod.db._initialized
        orig_pool = db_mod.db.pool

        try:
            # Point db singleton to failing PostgreSQL
            db_mod.db.config = {
                'USE_SQLITE': 'false',
                'DATABASE_URL': 'postgresql://invalid_user:invalid_pass@127.0.0.1:9999/nonexistent_db',
                'SQLITE_PATH': self.sqlite_file,
            }
            db_mod.db.pool = None
            db_mod.db.engine = 'postgresql'
            db_mod.db._initialized = False

            client = app.test_client()
            resp = client.get('/api/health')
            self.assertEqual(resp.status_code, 200)
            data = resp.get_json()['data']

            # Reports unavailable and PostgreSQL, NOT SQLite
            self.assertEqual(data['database'], 'unavailable')
            self.assertEqual(data['database_engine'], 'PostgreSQL')
            self.assertFalse(os.path.exists(self.sqlite_file))
        finally:
            db_mod.db.config = orig_config
            db_mod.db.engine = orig_engine
            db_mod.db._initialized = orig_init
            db_mod.db.pool = orig_pool

    # ==================== 3. SQL TRANSLATION & EXECUTION ====================

    def test_postgres_execute_appends_returning_id_for_inserts(self):
        """On PostgreSQL, execute() appends RETURNING id for known entity inserts."""
        mock_pool = MagicMock()
        mock_conn = MagicMock()
        mock_cur = MagicMock()
        mock_cur.rowcount = 1
        mock_cur.fetchone.return_value = (42,)
        mock_conn.cursor.return_value = mock_cur
        mock_pool.getconn.return_value = mock_conn

        db = Database(config={'USE_SQLITE': 'false'})
        db.engine = 'postgresql'
        db.pool = mock_pool
        db._initialized = True

        insert_sql = "INSERT INTO users (username, email, password) VALUES (%s, %s, %s)"
        params = ('alice', 'alice@example.com', 'hashed_pwd')
        res = db.execute(insert_sql, params)

        self.assertIsNotNone(res)
        self.assertEqual(res['affected'], 1)
        self.assertEqual(res['last_id'], 42)

        # Verify cursor executed with RETURNING id
        executed_sql = mock_cur.execute.call_args[0][0]
        self.assertTrue(executed_sql.strip().endswith("RETURNING id"))
        mock_conn.commit.assert_called_once()

    def test_postgres_execute_normalizes_boolean_and_upsert(self):
        """On PostgreSQL, execute() normalizes boolean literals and translates upserts."""
        mock_pool = MagicMock()
        mock_conn = MagicMock()
        mock_cur = MagicMock()
        mock_cur.rowcount = 1
        mock_cur.fetchone.return_value = (1,)
        mock_conn.cursor.return_value = mock_cur
        mock_pool.getconn.return_value = mock_conn

        db = Database(config={'USE_SQLITE': 'false'})
        db.engine = 'postgresql'
        db.pool = mock_pool
        db._initialized = True

        # Test boolean literal translation
        bool_sql = "UPDATE user_security SET fingerprint_data = %s, is_fingerprint_enabled = 1 WHERE user_id = %s"
        db.execute(bool_sql, ('data', 1))
        executed_sql = mock_cur.execute.call_args[0][0]
        self.assertIn("is_fingerprint_enabled = TRUE", executed_sql)

        # Test upsert translation
        upsert_sql = """
        INSERT INTO user_security (user_id, pin_code, fingerprint_data, is_fingerprint_enabled)
        VALUES (%s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE pin_code = %s
        """
        db.execute(upsert_sql, (1, 'pin', 'fp', 1, 'pin'))
        executed_upsert = mock_cur.execute.call_args[0][0]
        self.assertIn("ON CONFLICT (user_id) DO UPDATE SET", executed_upsert)

    # ==================== 4. DATA PERSISTENCE ACROSS SESSIONS ====================

    def test_data_persistence_across_instance_reload(self):
        """Data inserted into persistent database remains accessible after instance reload."""
        cfg = {
            'USE_SQLITE': 'true',
            'SQLITE_PATH': self.sqlite_file,
        }
        # First session: create user and security records
        db1 = Database(config=cfg)
        self.assertTrue(db1.connect())
        insert_res = db1.execute(
            "INSERT INTO users (username, email, password) VALUES (%s, %s, %s)",
            ('persistent_user', 'persistent@privlock.org', 'test_password_hash')
        )
        self.assertIsNotNone(insert_res)
        user_id = insert_res['last_id']
        self.assertIsNotNone(user_id)

        db1.execute(
            "INSERT INTO audit_logs (user_id, action, details, status) VALUES (%s, %s, %s, %s)",
            (user_id, 'USER_REGISTER', 'Created user account', 'success')
        )
        db1.disconnect()

        # Second session: simulate container restart pointing to same database
        db2 = Database(config=cfg)
        self.assertTrue(db2.connect())
        user = db2.query_one("SELECT * FROM users WHERE username = %s", ('persistent_user',))
        self.assertIsNotNone(user)
        self.assertEqual(user['email'], 'persistent@privlock.org')

        logs = db2.query("SELECT * FROM audit_logs WHERE user_id = %s", (user['id'],))
        self.assertEqual(len(logs), 1)
        self.assertEqual(logs[0]['action'], 'USER_REGISTER')
        db2.disconnect()


if __name__ == '__main__':
    unittest.main()

