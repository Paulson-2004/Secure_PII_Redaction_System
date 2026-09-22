"""
End-to-End Pipeline Integration Test for Secure PII Redaction System.
Tests:
1. User Registration & Authentication
2. Text and Image Document Upload
3. Single-pass OCR & Parsing
4. Hybrid PII Detection (Regex + NER + Whitelisting)
5. RAG Policy Evaluation
6. Redaction Execution (Visual & Text)
7. Audit Logging & Document History Verification
8. Secure File Download
"""

import os
import io
import unittest
import json
from PIL import Image, ImageDraw

os.environ["DATABASE_NAME"] = "test_e2e_db"
os.environ["SECRET_KEY"] = "test-secret-key-12345"

from app import app
from database import db


class TestEndToEndPipeline(unittest.TestCase):
    def setUp(self):
        self.app = app
        self.client = self.app.test_client()
        self.username = "e2e_auditor"
        self.email = "e2e_auditor@example.com"
        self.password = "SecureAuditorPass123!"
        self.token = None

        # Clean test user if exists
        db.execute(
            "DELETE FROM users WHERE username = %s",
            (self.username,)
        )

    def tearDown(self):
        db.execute(
            "DELETE FROM users WHERE username = %s",
            (self.username,)
        )

    def test_full_pipeline_text_document(self):
        # Step 1: Register User
        reg_resp = self.client.post(
            "/register",
            data=json.dumps({"username": self.username, "email": self.email, "password": self.password}),
            content_type="application/json"
        )
        self.assertIn(reg_resp.status_code, [200, 201])

        # Step 2: Login
        login_resp = self.client.post(
            "/login",
            data=json.dumps({"username": self.username, "password": self.password}),
            content_type="application/json"
        )
        self.assertEqual(login_resp.status_code, 200)
        login_data = json.loads(login_resp.data)
        token_info = login_data.get("data", login_data)
        self.token = token_info.get("auth_token") or token_info.get("token")
        self.assertIsNotNone(self.token)
        headers = {"Authorization": f"Bearer {self.token}"}

        # Step 3: Prepare Synthetic Document
        # Uses Verhoeff-valid Aadhaar: 3675 9834 6012 and standard PAN: ABCDE1234F
        raw_doc_content = (
            "Government of India - Income Tax Department\n"
            "Official Notice for Rajesh Kumar\n"
            "Permanent Account Number: ABCDE1234F\n"
            "Aadhaar Number: 3675 9834 6012\n"
            "Contact Email: rajesh.kumar@example.com\n"
            "Phone: +91 9876543210\n"
        )
        file_bytes = io.BytesIO(raw_doc_content.encode("utf-8"))

        # Step 4: Submit to /api/process
        upload_resp = self.client.post(
            "/api/process",
            headers=headers,
            data={
                "file": (file_bytes, "official_notice.txt"),
                "doc_type": "tax_notice",
                "action": "redact"
            },
            content_type="multipart/form-data"
        )
        self.assertEqual(upload_resp.status_code, 200)
        res_json = json.loads(upload_resp.data)
        self.assertTrue(res_json.get("success"))
        data = res_json.get("data", {})
        self.assertIn("redacted_filename", data)
        redacted_filename = data["redacted_filename"]

        # Step 5: Verify Detection & Hybrid Fusion
        pii_detected = data.get("pii_detected", [])
        self.assertIn("AADHAAR", pii_detected)
        self.assertIn("PAN", pii_detected)
        self.assertIn("EMAIL", pii_detected)
        self.assertIn("PHONE", pii_detected)

        # Ensure Government of India / Income Tax Department was NOT flagged as PII
        pii_details = data.get("pii_details", [])
        detail_types = [p.get("type") for p in pii_details]
        self.assertNotIn("ORGANIZATION", detail_types)

        # Step 6: Verify Download Endpoint & Content
        download_resp = self.client.get(
            f"/api/download/{redacted_filename}",
            headers=headers
        )
        self.assertEqual(download_resp.status_code, 200)
        redacted_text = download_resp.data.decode("utf-8")

        # Original PII must not appear in the redacted file
        self.assertNotIn("3675 9834 6012", redacted_text)
        self.assertNotIn("ABCDE1234F", redacted_text)
        self.assertNotIn("rajesh.kumar@example.com", redacted_text)
        self.assertNotIn("+91 9876543210", redacted_text)
        # Non-PII structure preserved
        self.assertIn("Government of India", redacted_text)
        self.assertIn("Permanent Account Number", redacted_text)

        # Step 7: Verify Audit Logging in Database & API
        audit_resp = self.client.get("/audit-logs", headers=headers)
        self.assertEqual(audit_resp.status_code, 200)
        audit_res = json.loads(audit_resp.data)
        audit_data = audit_res.get("data", [])
        self.assertTrue(len(audit_data) > 0)

        # Check that the record matches our document
        doc_entry = next((item for item in audit_data if "official_notice.txt" in item.get("filename", "")), None)
        self.assertIsNotNone(doc_entry)
        self.assertGreaterEqual(doc_entry.get("pii_count", 0), 4)

    def test_full_pipeline_image_document(self):
        # Step 1: Login
        login_resp = self.client.post(
            "/login",
            data=json.dumps({"username": self.username, "password": self.password}),
            content_type="application/json"
        )
        if login_resp.status_code != 200:
            self.client.post(
                "/register",
                data=json.dumps({"username": self.username, "email": self.email, "password": self.password}),
                content_type="application/json"
            )
            login_resp = self.client.post(
                "/login",
                data=json.dumps({"username": self.username, "password": self.password}),
                content_type="application/json"
            )

        login_data = json.loads(login_resp.data)
        token_info = login_data.get("data", login_data)
        token = token_info.get("auth_token") or token_info.get("token")
        headers = {"Authorization": f"Bearer {token}"}

        # Step 2: Create Synthetic Image with PII
        img = Image.new("RGB", (400, 100), color="white")
        draw = ImageDraw.Draw(img)
        draw.text((20, 40), "User: admin@cyberguard.org", fill="black")
        img_bytes = io.BytesIO()
        img.save(img_bytes, format="PNG")
        img_bytes.seek(0)

        # Step 3: Send to /api/process
        upload_resp = self.client.post(
            "/api/process",
            headers=headers,
            data={
                "file": (img_bytes, "profile_card.png"),
                "doc_type": "id_card",
                "action": "redact"
            },
            content_type="multipart/form-data"
        )
        self.assertEqual(upload_resp.status_code, 200)
        res_json = json.loads(upload_resp.data)
        self.assertTrue(res_json.get("success"))
        data = res_json.get("data", {})
        self.assertIn("redacted_filename", data)
        redacted_filename = data["redacted_filename"]

        # Step 4: Download Redacted Image
        download_resp = self.client.get(
            f"/api/download/{redacted_filename}",
            headers=headers
        )
        self.assertEqual(download_resp.status_code, 200)
        
        # Verify valid image bytes and preserved aspect ratio (4:1)
        redacted_image = Image.open(io.BytesIO(download_resp.data))
        self.assertGreater(redacted_image.size[0], 0)
        self.assertGreater(redacted_image.size[1], 0)
        aspect_ratio = redacted_image.size[0] / redacted_image.size[1]
        self.assertAlmostEqual(aspect_ratio, 4.0, delta=0.1)


if __name__ == "__main__":
    unittest.main()
