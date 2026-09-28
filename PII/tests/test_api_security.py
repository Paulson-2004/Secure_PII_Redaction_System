import unittest
import sys
import os
import json

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app import app
from database import db


class TestAPISecurity(unittest.TestCase):
    """Integration and security tests for Flask REST API."""

    @classmethod
    def setUpClass(cls):
        app.config['TESTING'] = True
        cls.client = app.test_client()
        cls.test_username = 'sec_test_user'
        cls.test_email = 'sec_test@example.com'
        cls.test_password = 'Password123!'

        # Clean any existing test user
        with app.app_context():
            user = db.query_one("SELECT id FROM users WHERE username = %s", (cls.test_username,))
            if user:
                db.execute("DELETE FROM users WHERE id = %s", (user['id'],))

    def test_01_health_endpoint(self):
        """Verify health check returns 200 with all components loaded."""
        resp = self.client.get('/api/health')
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()
        self.assertTrue(data['success'])
        self.assertEqual(data['data']['backend'], 'running')
        self.assertEqual(data['data']['database'], 'connected')

    def test_02_registration_validation(self):
        """Verify input validation on user registration."""
        # Missing fields
        resp = self.client.post('/register', json={'username': 'abc'})
        self.assertEqual(resp.status_code, 400)

        # Successful registration
        resp = self.client.post('/register', json={
            'username': self.test_username,
            'email': self.test_email,
            'password': self.test_password
        })
        self.assertEqual(resp.status_code, 201)

        # Duplicate registration
        resp = self.client.post('/register', json={
            'username': self.test_username,
            'email': self.test_email,
            'password': self.test_password
        })
        self.assertEqual(resp.status_code, 409)

    def test_03_login_and_token(self):
        """Verify password authentication and token generation."""
        # Wrong password
        resp = self.client.post('/login', json={
            'username': self.test_username,
            'password': 'WrongPassword123'
        })
        self.assertEqual(resp.status_code, 401)

        # Valid login
        resp = self.client.post('/login', json={
            'username': self.test_username,
            'password': self.test_password
        })
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()['data']
        self.assertIn('auth_token', data)
        self.__class__.token = data['auth_token']

    def test_04_pin_setup_and_verify(self):
        """Test PIN setup and verification."""
        headers = {'X-Auth-Token': self.__class__.token}

        # Invalid PIN length
        resp = self.client.post('/api/security/pin', json={'pin': '12'}, headers=headers)
        self.assertEqual(resp.status_code, 400)

        # Valid PIN
        resp = self.client.post('/api/security/pin', json={'pin': '1234'}, headers=headers)
        self.assertEqual(resp.status_code, 200)

        # Verify correct PIN
        resp = self.client.post('/api/security/verify-pin', json={'pin': '1234'}, headers=headers)
        self.assertEqual(resp.status_code, 200)

        # Verify incorrect PIN
        resp = self.client.post('/api/security/verify-pin', json={'pin': '9999'}, headers=headers)
        self.assertEqual(resp.status_code, 401)

    def test_05_path_traversal_prevention(self):
        """Verify that path traversal attempts on download routes are strictly blocked."""
        headers = {'X-Auth-Token': self.__class__.token}

        # Attempt directory traversal attacks
        traversal_payloads = [
            '../../config.py',
            '..%2F..%2Fconfig.py',
            'redacted_1_../../config.py',
            'redacted_1_..\\..\\config.py',
            '../..\\windows\\runner\\main.cpp'
        ]

        for payload in traversal_payloads:
            resp = self.client.get(f'/api/download/{payload}', headers=headers)
            self.assertIn(resp.status_code, [400, 403, 404], f"Payload {payload} was not blocked")

    def test_06_audit_logs_endpoint(self):
        """Verify audit logs endpoint returns valid data structure."""
        headers = {'X-Auth-Token': self.__class__.token}
        resp = self.client.get('/audit-logs', headers=headers)
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()
        self.assertTrue(data['success'])
        self.assertIsInstance(data['data'], list)

    def test_07_change_password(self):
        """Verify password update flow."""
        headers = {'X-Auth-Token': self.__class__.token}

        # Wrong current password
        resp = self.client.post('/api/change-password', json={
            'current_password': 'WrongPassword123',
            'new_password': 'NewPassword123!'
        }, headers=headers)
        self.assertEqual(resp.status_code, 401)

        # Correct update
        resp = self.client.post('/api/change-password', json={
            'current_password': self.test_password,
            'new_password': 'NewPassword123!'
        }, headers=headers)
    def test_08_preview_security(self):
        """Verify that document preview strictly enforces authentication, ownership, and redacted-only rules."""
        # 1. Unauthenticated request -> 401
        unauth_client = app.test_client()
        unauth_resp = unauth_client.get('/api/preview/redacted_1_sample.png')
        self.assertEqual(unauth_resp.status_code, 401)

        headers = {'X-Auth-Token': self.__class__.token}

        # 2. Attempting to preview original unredacted file -> 403
        unredacted_resp = self.client.get('/api/preview/1_sample.png', headers=headers)
        self.assertEqual(unredacted_resp.status_code, 403)

        # 3. Attempting to preview another user's file -> 403
        other_user_resp = self.client.get('/api/preview/redacted_999999_sample.png', headers=headers)
        self.assertEqual(other_user_resp.status_code, 403)

        # 4. Traversal attack -> blocked (400, 403, or 404)
        traversal_resp = self.client.get('/api/preview/redacted_1_../../config.py', headers=headers)
        self.assertIn(traversal_resp.status_code, [400, 403, 404])

        # 5. Non-existent file of the current user -> 404
        with app.app_context():
            user = db.query_one("SELECT id FROM users WHERE username = %s", (self.test_username,))
            user_id = user['id']

        missing_resp = self.client.get(f'/api/preview/redacted_{user_id}_missing_doc.png', headers=headers)
        self.assertEqual(missing_resp.status_code, 404)

        # 6. Authenticated user's valid redacted file -> 200 OK
        redacted_dir = os.path.abspath(app.config.get('REDACTED_FOLDER', os.path.join(app.root_path, 'uploads', 'redacted')))
        os.makedirs(redacted_dir, exist_ok=True)
        test_file_name = f"redacted_{user_id}_valid_preview_test.txt"
        test_file_path = os.path.join(redacted_dir, test_file_name)
        with open(test_file_path, 'w', encoding='utf-8') as f:
            f.write("Sanitized content without PII.")
        try:
            valid_resp = self.client.get(f'/api/preview/{test_file_name}', headers=headers)
            self.assertEqual(valid_resp.status_code, 200)
            self.assertIn(b"Sanitized content without PII.", valid_resp.data)
            valid_resp.close()
        finally:
            if os.path.exists(test_file_path):
                try:
                    os.remove(test_file_path)
                except OSError:
                    pass


if __name__ == '__main__':
    unittest.main()

