import unittest
import sys
import os
import json
import time

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

    def test_08_cors_wildcard_matching(self):
        """Verify CORS wildcard regex transformation and matching behavior."""
        import re
        from flask_cors.core import try_match

        wildcard_entry = "https://*.vercel.app"
        regex_pattern = re.compile(r"^" + re.escape(wildcard_entry).replace(r"\*", r".*") + r"$")

        # 1. Matches Vercel production origin
        self.assertIsNotNone(try_match('https://privlock.vercel.app', regex_pattern))

        # 2. Matches Vercel preview origin
        self.assertIsNotNone(try_match('https://my-app.vercel.app', regex_pattern))

        # 3. Rejects unrelated domain
        self.assertIsNone(try_match('https://example.com', regex_pattern))

        # 4. Rejects attacker domain with suffix
        self.assertIsNone(try_match('https://malicious-vercel.app.attacker.com', regex_pattern))

        # 5. Localhost matches base app preflight
        res_local = self.client.options(
            '/api/health',
            headers={'Origin': 'http://localhost:5080', 'Access-Control-Request-Method': 'GET'}
        )
        self.assertEqual(res_local.status_code, 200)
        self.assertEqual(res_local.headers.get('Access-Control-Allow-Origin'), 'http://localhost:5080')

    def test_09_health_check_lightweight_no_rag_init(self):
        """Verify /api/health is lightweight and does NOT instantiate RAG engine or SentenceTransformer."""
        from unittest.mock import patch
        import modules.rag_decision_engine as rag_mod

        # Ensure singleton is reset for clean verification
        original_engine = rag_mod._engine
        rag_mod._engine = None

        try:
            with patch('modules.rag_decision_engine.get_rag_engine') as mock_get_rag, \
                 patch('modules.rag_decision_engine.SentenceTransformer') as mock_st:
                t0 = time.time()
                res = self.client.get('/api/health')
                duration = time.time() - t0

                self.assertEqual(res.status_code, 200)
                data = res.get_json()
                self.assertTrue(data.get('success'))
                health = data.get('data', {})
                self.assertEqual(health.get('backend'), 'running')
                self.assertIn('database', health)
                self.assertIn('ai', health)

                rag_info = health['ai'].get('rag', {})
                self.assertEqual(rag_info.get('status'), 'ready_lazy')
                self.assertTrue(rag_info.get('rag_enabled'))
                self.assertFalse(rag_info.get('initialized'))

                # Prove that neither get_rag_engine nor SentenceTransformer was invoked
                mock_get_rag.assert_not_called()
                mock_st.assert_not_called()

                # Health check should respond extremely quickly (< 1.0 second)
                self.assertLess(duration, 1.0)
        finally:
            rag_mod._engine = original_engine

    def test_10_guest_mode_pipeline_and_isolation(self):
        """Verify guest mode processing, download, preview, and security isolation."""
        import io
        from app import GUEST_ARTIFACTS

        # 1. Guest can process document without auth token or cookie
        guest_client = app.test_client()
        sample_doc = io.BytesIO(b"Candidate Aadhaar: 2345 6789 0123. Contact: test@example.com")
        data = {
            'file': (sample_doc, 'guest_test.txt'),
            'doc_type': 'general',
            'action': 'redact'
        }
        res = guest_client.post('/api/process', data=data, content_type='multipart/form-data')
        self.assertEqual(res.status_code, 200)
        body = res.get_json()
        self.assertTrue(body['success'])
        proc_data = body['data']
        self.assertTrue(proc_data.get('is_guest'))

        redacted_filename = proc_data['redacted_filename']
        self.assertTrue(redacted_filename.startswith('redacted_guest_'))
        self.assertIn(redacted_filename, GUEST_ARTIFACTS)

        # 2. Verify zero audit logs or document records created for guest in DB
        with app.app_context():
            doc_record = db.query_one("SELECT id FROM documents WHERE filename = %s", (redacted_filename,))
            self.assertIsNone(doc_record, "Guest processing must NOT record in documents table")
            audit_records = db.query("SELECT id FROM audit_logs WHERE details LIKE %s", (f"%{proc_data['filename']}%",))
            self.assertEqual(len(audit_records or []), 0, "Guest processing must NOT record in audit_logs table")

        # 3. Guest can download their own redacted result
        dl_resp = guest_client.get(f'/api/download/{redacted_filename}')
        self.assertEqual(dl_resp.status_code, 200)
        self.assertIn(b"Candidate Aadhaar", dl_resp.data)
        dl_resp.close()

        # 4. Guest can preview their own redacted result
        prev_resp = guest_client.get(f'/api/preview/{redacted_filename}')
        self.assertEqual(prev_resp.status_code, 200)
        prev_resp.close()

        # 5. Guest CANNOT preview original unredacted file -> 403 Forbidden
        orig_filename = proc_data['filename']
        self.assertTrue(orig_filename.startswith('guest_'))
        orig_prev_resp = guest_client.get(f'/api/preview/{orig_filename}')
        self.assertEqual(orig_prev_resp.status_code, 403)
        orig_prev_resp.close()

        # 6. Guest CANNOT access /audit-logs -> 401 Unauthorized
        audit_resp = guest_client.get('/audit-logs')
        self.assertEqual(audit_resp.status_code, 401)
        audit_resp.close()

        # 7. Unauthenticated request to another user's file -> 401
        other_user_dl = guest_client.get('/api/download/redacted_9999_sample.png')
        self.assertEqual(other_user_dl.status_code, 401)
        other_user_dl.close()

        # 8. Nonexistent guest token -> 404
        fake_guest_dl = guest_client.get('/api/download/redacted_guest_0123456789abcdef0123456789abcdef_sample.txt')
        self.assertEqual(fake_guest_dl.status_code, 404)
        fake_guest_dl.close()

    def test_11_guest_ephemeral_ttl_cleanup(self):
        """Verify expired guest document files and registry entries are purged."""
        import datetime
        from app import GUEST_ARTIFACTS, _cleanup_expired_guest_artifacts

        uploads_dir = os.path.abspath(app.config.get('UPLOAD_FOLDER', os.path.join(app.root_path, 'uploads')))
        redacted_dir = os.path.abspath(app.config.get('REDACTED_FOLDER', os.path.join(uploads_dir, 'redacted')))
        os.makedirs(redacted_dir, exist_ok=True)

        expired_name = "redacted_guest_deadbeefdeadbeefdeadbeefdeadbeef_20260101_expired.txt"
        expired_path = os.path.join(redacted_dir, expired_name)
        with open(expired_path, 'w', encoding='utf-8') as f:
            f.write("Expired guest content")

        GUEST_ARTIFACTS[expired_name] = {
            'token': 'deadbeefdeadbeefdeadbeefdeadbeef',
            'filename': expired_name.replace('redacted_', ''),
            'redacted_filename': expired_name,
            'created_at': datetime.datetime.now() - datetime.timedelta(hours=2),
            'filepath': None,
            'redacted_path': expired_path,
        }

        self.assertTrue(os.path.exists(expired_path))
        _cleanup_expired_guest_artifacts()

        self.assertNotIn(expired_name, GUEST_ARTIFACTS)
        self.assertFalse(os.path.exists(expired_path))

    def test_12_audit_logs_zero_documents_no_auth_events_as_filenames(self):
        """Verify that a user with auth events but 0 processed documents gets an empty list in /audit-logs (no login/logout events)."""
        import time
        fresh_name = f"no_docs_user_{int(time.time() * 1000)}"
        fresh_email = f"{fresh_name}@example.com"
        fresh_pass = "SecurePass123!"

        # Register and login
        reg_resp = self.client.post('/register', json={
            'username': fresh_name,
            'email': fresh_email,
            'password': fresh_pass
        })
        self.assertEqual(reg_resp.status_code, 201)

        login_resp = self.client.post('/login', json={
            'username': fresh_name,
            'password': fresh_pass
        })
        self.assertEqual(login_resp.status_code, 200)
        token = login_resp.get_json().get('data', {}).get('auth_token')

        # Request /audit-logs
        headers = {'X-Auth-Token': token}
        audit_resp = self.client.get('/audit-logs', headers=headers)
        self.assertEqual(audit_resp.status_code, 200)
        audit_data = audit_resp.get_json().get('data', [])

        # Must be empty list: NO login or logout events allowed as document filenames
        self.assertEqual(audit_data, [])
        for entry in audit_data:
            self.assertNotIn(entry.get('filename'), ['login', 'logout', 'user_registered', 'document_downloaded'])

    def test_13_process_actions_mask_blur_redact_pipeline(self):
        """Verify that /api/process correctly executes mask, blur, and redact actions with distinct outputs."""
        import io

        text_content = b"Confidential Report. PAN: ABCDE1234F, Mobile: 9876543210."

        # 1. Action: mask
        data_mask = {
            'file': (io.BytesIO(text_content), 'test_mask.txt'),
            'doc_type': 'general',
            'action': 'mask'
        }
        resp_mask = self.client.post('/api/process', data=data_mask, content_type='multipart/form-data')
        self.assertEqual(resp_mask.status_code, 200)
        res_mask = resp_mask.get_json()['data']
        self.assertEqual(res_mask['action'], 'mask')
        self.assertGreater(res_mask['total_pii_found'], 0)

        # 2. Action: blur
        data_blur = {
            'file': (io.BytesIO(text_content), 'test_blur.txt'),
            'doc_type': 'general',
            'action': 'blur'
        }
        resp_blur = self.client.post('/api/process', data=data_blur, content_type='multipart/form-data')
        self.assertEqual(resp_blur.status_code, 200)
        res_blur = resp_blur.get_json()['data']
        self.assertEqual(res_blur['action'], 'blur')
        self.assertGreater(res_blur['total_pii_found'], 0)

        # 3. Action: redact
        data_redact = {
            'file': (io.BytesIO(text_content), 'test_redact.txt'),
            'doc_type': 'general',
            'action': 'redact'
        }
        resp_redact = self.client.post('/api/process', data=data_redact, content_type='multipart/form-data')
        self.assertEqual(resp_redact.status_code, 200)
        res_redact = resp_redact.get_json()['data']
        self.assertEqual(res_redact['action'], 'redact')
        self.assertGreater(res_redact['total_pii_found'], 0)

        # Verify preview downloads return materially different results
        mask_dl = self.client.get(f"/api/preview/{res_mask['redacted_filename']}")
        blur_dl = self.client.get(f"/api/preview/{res_blur['redacted_filename']}")
        redact_dl = self.client.get(f"/api/preview/{res_redact['redacted_filename']}")

        self.assertEqual(mask_dl.status_code, 200)
        self.assertEqual(blur_dl.status_code, 200)
        self.assertEqual(redact_dl.status_code, 200)

        mask_text = mask_dl.data.decode('utf-8')
        blur_text = blur_dl.data.decode('utf-8')
        redact_text = redact_dl.data.decode('utf-8')

        mask_dl.close()
        blur_dl.close()
        redact_dl.close()

        self.assertIn("XXXXXX3210", mask_text)
        self.assertIn("[BLURRED]", blur_text)
        self.assertIn("██████████", redact_text)

        self.assertNotEqual(mask_text, blur_text)
        self.assertNotEqual(mask_text, redact_text)
        self.assertNotEqual(blur_text, redact_text)

    def test_14_manual_selection_image_redact_mask_blur(self):
        """Verify manual region redaction on images with redact, mask, and blur."""
        import io
        import json
        import numpy as np
        import cv2

        # Create a 200x300 synthetic test image (white canvas with dark pattern)
        img = np.ones((200, 300, 3), dtype=np.uint8) * 255
        cv2.putText(img, "Confidential Aadhaar 4832 7612 9045", (20, 60), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 0), 2)
        _, img_png = cv2.imencode('.png', img)

        manual_regions = [
            {'page': 1, 'x': 0.05, 'y': 0.15, 'width': 0.5, 'height': 0.25, 'action': 'redact'},
            {'page': 1, 'x': 0.60, 'y': 0.15, 'width': 0.35, 'height': 0.25, 'action': 'blur'},
        ]

        data = {
            'file': (io.BytesIO(img_png.tobytes()), 'test_manual.png'),
            'doc_type': 'government_id',
            'action': 'redact',
            'detection_mode': 'manual',
            'manual_regions': json.dumps(manual_regions),
        }

        resp = self.client.post('/api/process', data=data, content_type='multipart/form-data')
        self.assertEqual(resp.status_code, 200)
        res = resp.get_json()['data']
        self.assertEqual(res['detection_mode'], 'manual')
        self.assertEqual(res['manual_regions_count'], 2)
        self.assertIn('redacted_filename', res)

        # Download preview image and inspect pixels
        prev_resp = self.client.get(f"/api/preview/{res['redacted_filename']}")
        self.assertEqual(prev_resp.status_code, 200)
        arr = np.frombuffer(prev_resp.data, dtype=np.uint8)
        redacted_cv = cv2.imdecode(arr, cv2.IMREAD_COLOR)
        prev_resp.close()

        self.assertIsNotNone(redacted_cv)
        ret_h, ret_w = redacted_cv.shape[:2]
        # Region 1 (redact) center: x=(0.05 + 0.25)*ret_w, y=(0.15 + 0.125)*ret_h -> should be black (0, 0, 0)
        check_x = int(0.30 * ret_w)
        check_y = int(0.275 * ret_h)
        self.assertEqual(list(redacted_cv[check_y, check_x]), [0, 0, 0])
        # Bottom-right area (outside manual boxes) must remain unmodified white
        self.assertEqual(list(redacted_cv[int(0.9 * ret_h), int(0.9 * ret_w)]), [255, 255, 255])

    def test_15_multipage_pdf_manual_page_specific_selection(self):
        """Verify multi-page PDF processing with page-specific manual selections."""
        import io
        import json
        import pymupdf
        import numpy as np
        import cv2

        # Create a 2-page PDF
        doc = pymupdf.open()
        p1 = doc.new_page(width=300, height=200)
        p1.insert_text((30, 50), "Page 1: Sensitive Account 9876543210", fontname="helv", fontsize=12)
        p2 = doc.new_page(width=300, height=200)
        p2.insert_text((30, 50), "Page 2: Public General Information", fontname="helv", fontsize=12)

        pdf_bytes = doc.tobytes()
        doc.close()

        # Target manual redaction ONLY on Page 1; Page 2 has no manual selections
        manual_regions = [
            {'page': 1, 'x': 0.1, 'y': 0.1, 'width': 0.7, 'height': 0.3, 'action': 'redact'}
        ]

        data = {
            'file': (io.BytesIO(pdf_bytes), 'multipage_manual_test.pdf'),
            'doc_type': 'general',
            'action': 'redact',
            'detection_mode': 'manual',
            'manual_regions': json.dumps(manual_regions),
        }

        resp = self.client.post('/api/process', data=data, content_type='multipart/form-data')
        self.assertEqual(resp.status_code, 200)
        res = resp.get_json()['data']
        self.assertEqual(res['detection_mode'], 'manual')
        self.assertEqual(res['page_count'], 2)

        # Download the resulting redacted PDF
        dl_resp = self.client.get(f"/api/download/{res['redacted_filename']}")
        self.assertEqual(dl_resp.status_code, 200)

        # Inspect resulting PDF page count
        result_pdf = pymupdf.open(stream=dl_resp.data, filetype='pdf')
        self.assertEqual(len(result_pdf), 2)
        result_pdf.close()
        dl_resp.close()

    def test_16_manual_mode_guest_and_authenticated_isolation(self):
        """Verify guest mode manual redaction produces ephemeral tokens without DB rows."""
        import io
        import json
        guest_client = app.test_client()

        data = {
            'file': (io.BytesIO(b"Guest manual test"), 'guest_manual.txt'),
            'doc_type': 'general',
            'action': 'redact',
            'detection_mode': 'manual',
            'manual_regions': json.dumps([{'page': 1, 'x': 0.0, 'y': 0.0, 'width': 0.5, 'height': 0.5}]),
        }

        resp = guest_client.post('/api/process', data=data, content_type='multipart/form-data')
        self.assertEqual(resp.status_code, 200)
        res = resp.get_json()['data']
        self.assertTrue(res['is_guest'])
        self.assertTrue(res['redacted_filename'].startswith('redacted_guest_'))
        guest_client.get('/logout')

    def test_17_automatic_manual_combined_mode(self):
        """Verify automatic_manual mode processes both automatic PII and user manual regions."""
        import io
        import json

        text_content = b"PAN: ABCDE1234F, Extra Secret Info: TopSecret123."
        manual_regions = [
            {'page': 1, 'x': 0.5, 'y': 0.1, 'width': 0.4, 'height': 0.2, 'action': 'mask'}
        ]

        data = {
            'file': (io.BytesIO(text_content), 'combined_test.txt'),
            'doc_type': 'general',
            'action': 'redact',
            'detection_mode': 'automatic_manual',
            'manual_regions': json.dumps(manual_regions),
        }

        resp = self.client.post('/api/process', data=data, content_type='multipart/form-data')
        self.assertEqual(resp.status_code, 200)
        res = resp.get_json()['data']
        self.assertEqual(res['detection_mode'], 'automatic_manual')
        self.assertEqual(res['manual_regions_count'], 1)
        self.assertGreater(res['total_pii_found'], 0)

    def test_18_malformed_manual_regions_sanitization(self):
        """Verify that negative, out-of-bounds, or malformed manual regions are safely handled."""
        import io
        import json

        malformed_regions = [
            {'page': -5, 'x': -0.9, 'y': -0.5, 'width': 5.0, 'height': 10.0, 'action': 'redact'},
            {'page': 'invalid', 'x': 'not_a_number'},
            {'invalid_key': 123},
        ]

        data = {
            'file': (io.BytesIO(b"Safe malformed test text"), 'safe_malformed.txt'),
            'doc_type': 'general',
            'action': 'redact',
            'detection_mode': 'manual',
            'manual_regions': json.dumps(malformed_regions),
        }

        resp = self.client.post('/api/process', data=data, content_type='multipart/form-data')
        self.assertEqual(resp.status_code, 200)
        res = resp.get_json()['data']
        self.assertEqual(res['detection_mode'], 'manual')
        # Sanitized region page should be >= 1 and clamped coordinates
        for r in res.get('manual_regions', []):
            self.assertGreaterEqual(r['page'], 1)
            self.assertGreaterEqual(r['x'], 0.0)
            self.assertLessEqual(r['x'], 1.0)


if __name__ == '__main__':
    unittest.main()

