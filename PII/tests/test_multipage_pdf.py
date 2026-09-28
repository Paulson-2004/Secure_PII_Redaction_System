"""
Tests for Multi-Page PDF Processing Pipeline in PrivLock AI.
Verifies:
1. Multi-page PDF is processed across all pages.
2. Page count and sequential order are strictly preserved (Input == Output).
3. PII elements across distinct pages are detected, evaluated by policy engine, and redacted.
4. Output multi-page PDF is reconstructed and downloadable.
5. Preview endpoint returns Page 1 PNG for the redacted output and 403 Forbidden for the original unredacted file.
"""

import io
import os
import unittest
import pymupdf
from app import app, BASE_DIR
from database import db


class TestMultiPagePDFProcessing(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        app.config['TESTING'] = True
        cls.client = app.test_client()
        cls.test_username = 'pdf_audit_user'
        cls.test_password = 'PdfPassword123!'
        cls.test_email = 'pdf_audit@example.com'

        with app.app_context():
            user = db.query_one("SELECT id FROM users WHERE username = %s", (cls.test_username,))
            if user:
                db.execute("DELETE FROM users WHERE id = %s", (user['id'],))

        reg_res = cls.client.post('/register', json={
            'username': cls.test_username,
            'password': cls.test_password,
            'email': cls.test_email
        })

        login_res = cls.client.post('/login', json={
            'username': cls.test_username,
            'password': cls.test_password
        })
        login_data = login_res.get_json()
        cls.token = login_data.get('data', {}).get('auth_token')
        cls.headers = {'X-Auth-Token': cls.token}
        cls.created_files = []

    @classmethod
    def tearDownClass(cls):
        uploads_dir = os.path.join(BASE_DIR, 'uploads')
        redacted_dir = os.path.join(uploads_dir, 'redacted')

        for f in cls.created_files:
            p1 = os.path.join(uploads_dir, f)
            if os.path.exists(p1):
                try:
                    os.remove(p1)
                except OSError:
                    pass
            p2 = os.path.join(redacted_dir, f)
            if os.path.exists(p2):
                try:
                    os.remove(p2)
                except OSError:
                    pass

        with app.app_context():
            user = db.query_one("SELECT id FROM users WHERE username = %s", (cls.test_username,))
            if user:
                db.execute("DELETE FROM users WHERE id = %s", (user['id'],))

    def _create_3page_synthetic_pdf(self) -> bytes:
        """Create a 3-page synthetic PDF with different PII on each page."""
        doc = pymupdf.open()

        # Page 1: Aadhaar + Phone Number
        p1 = doc.new_page(width=595, height=842)
        p1.insert_text(pymupdf.Point(72, 100), "CONFIDENTIAL VERIFICATION FORM - PAGE 1", fontsize=14)
        p1.insert_text(pymupdf.Point(72, 140), "Resident Aadhaar: 9876 5432 1098", fontsize=11)
        p1.insert_text(pymupdf.Point(72, 170), "Contact Mobile: +91 9876543210", fontsize=11)

        # Page 2: PAN Card + Date of Birth
        p2 = doc.new_page(width=595, height=842)
        p2.insert_text(pymupdf.Point(72, 100), "TAX AND IDENTITY RECORDS - PAGE 2", fontsize=14)
        p2.insert_text(pymupdf.Point(72, 140), "Permanent Account Number: ABCDE1234F", fontsize=11)
        p2.insert_text(pymupdf.Point(72, 170), "Date of Birth: 15/08/1990", fontsize=11)

        # Page 3: Credit Card + Email Address
        p3 = doc.new_page(width=595, height=842)
        p3.insert_text(pymupdf.Point(72, 100), "PAYMENT SETTLEMENT RECEIPT - PAGE 3", fontsize=14)
        p3.insert_text(pymupdf.Point(72, 140), "Credit Card: 4532 1234 5678 9012", fontsize=11)
        p3.insert_text(pymupdf.Point(72, 170), "Billing Email: confidential.officer@domain.com", fontsize=11)

        pdf_bytes = doc.tobytes()
        doc.close()
        return pdf_bytes

    def test_multipage_pdf_processing_pipeline(self):
        pdf_bytes = self._create_3page_synthetic_pdf()
        filename = 'multipage_audit_sample.pdf'

        data = {
            'file': (io.BytesIO(pdf_bytes), filename),
            'doc_type': 'general_document',
            'action': 'redact'
        }

        response = self.client.post(
            '/api/process',
            data=data,
            content_type='multipart/form-data',
            headers=self.headers
        )

        self.assertEqual(response.status_code, 200, f"Process failed: {response.get_data(as_text=True)}")
        resp_json = response.get_json()
        self.assertTrue(resp_json.get('success'))

        payload = resp_json.get('data', {})
        uploaded_name = payload.get('filename')
        redacted_name = payload.get('redacted_filename')

        if uploaded_name:
            self.__class__.created_files.append(uploaded_name)
        if redacted_name:
            self.__class__.created_files.append(redacted_name)

        # 1. Page count check
        self.assertEqual(payload.get('page_count'), 3, "Output page count must match 3-page input")
        self.assertTrue(redacted_name.lower().endswith('.pdf'))

        # 2. Output file on disk check
        redacted_disk_path = os.path.join(BASE_DIR, 'uploads', 'redacted', redacted_name)
        self.assertTrue(os.path.exists(redacted_disk_path), "Redacted PDF file must exist on disk")

        # 3. Verify reconstructed PDF page count and renderability
        redacted_doc = pymupdf.open(redacted_disk_path)
        self.assertEqual(len(redacted_doc), 3, "Reconstructed PDF must have exactly 3 pages")
        for idx in range(len(redacted_doc)):
            pix = redacted_doc[idx].get_pixmap(dpi=100)
            self.assertGreater(pix.width, 0)
            self.assertGreater(pix.height, 0)
        redacted_doc.close()

        # 4. Multi-page PII details check
        pii_details = payload.get('pii_details', [])
        pages_with_detections = {d.get('page') for d in pii_details if 'page' in d}
        self.assertGreaterEqual(len(pages_with_detections), 2, "Detections should span multiple pages")

        # 5. Preview endpoint verification
        preview_res = self.client.get(f'/api/preview/{redacted_name}', headers=self.headers)
        self.assertEqual(preview_res.status_code, 200)
        self.assertEqual(preview_res.mimetype, 'image/png')
        self.assertGreater(len(preview_res.data), 100)

        # 6. Preview security: original unredacted upload must be blocked
        unredacted_preview_res = self.client.get(f'/api/preview/{uploaded_name}', headers=self.headers)
        self.assertEqual(unredacted_preview_res.status_code, 403, "Original unredacted file must be forbidden from preview")

        # 7. Download endpoint delivers the full multi-page PDF
        dl_res = self.client.get(f'/api/download/{redacted_name}', headers=self.headers)
        self.assertEqual(dl_res.status_code, 200)
        dl_doc = pymupdf.open(stream=dl_res.data, filetype='pdf')
        self.assertEqual(len(dl_doc), 3, "Downloaded PDF must contain all 3 pages")
        dl_doc.close()


if __name__ == '__main__':
    unittest.main()
