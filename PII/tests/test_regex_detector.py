import unittest
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from modules.regex_detector import (
    detect_pii_regex,
    validate_verhoeff,
    validate_luhn,
    get_pattern_summary
)


class TestRegexDetector(unittest.TestCase):
    """Unit tests for regex pattern detection and algorithmic validators."""

    def test_verhoeff_checksum(self):
        """Test Verhoeff algorithm on known checksum values."""
        # 212345678901 is mathematically verified under Verhoeff D5
        self.assertTrue(validate_verhoeff("212345678901"))
        # Invalid checksum
        self.assertFalse(validate_verhoeff("212345678908"))
        self.assertFalse(validate_verhoeff("123456789012"))

    def test_luhn_checksum(self):
        """Test Luhn algorithm on credit card numbers."""
        # 4539148803436467 is a standard 16-digit synthetic test vector
        self.assertTrue(validate_luhn("4539148803436467"))
        self.assertFalse(validate_luhn("4539148803436468"))

    def test_aadhaar_detection(self):
        """Test Aadhaar pattern recognition."""
        text = "My Aadhaar number is 4832 7612 9045 and alternate is 2123-4567-8909."
        results = detect_pii_regex(text)
        aadhaar_types = [r for r in results if r['type'] == 'AADHAAR']
        self.assertGreaterEqual(len(aadhaar_types), 1)
        self.assertEqual(aadhaar_types[0]['value'], '4832 7612 9045')

        # Numbers starting with 0 or 1 should be excluded
        invalid_text = "Tracking ID: 0123 4567 8901 and 1234 5678 9012"
        invalid_results = [r for r in detect_pii_regex(invalid_text) if r['type'] == 'AADHAAR']
        for r in invalid_results:
            self.assertFalse(r['value'].startswith('0') or r['value'].startswith('1'))

    def test_pan_detection(self):
        """Test PAN card identifier detection."""
        text = "Taxpayer PAN: ABCPK1234F registered for assessment."
        results = detect_pii_regex(text)
        pan_dets = [r for r in results if r['type'] == 'PAN']
        self.assertEqual(len(pan_dets), 1)
        self.assertEqual(pan_dets[0]['value'], 'ABCPK1234F')
        self.assertAlmostEqual(pan_dets[0]['confidence'], 0.98)

    def test_phone_detection(self):
        """Test mobile numbers with and without +91 prefix."""
        text = "Contact me at +91 9876543210 or 8765432109 for queries."
        results = detect_pii_regex(text)
        phone_dets = [r for r in results if r['type'] == 'PHONE']
        self.assertEqual(len(phone_dets), 2)
        values = [p['value'] for p in phone_dets]
        self.assertIn('+91 9876543210', values)
        self.assertIn('8765432109', values)

    def test_email_detection(self):
        """Test email address detection."""
        text = "Write to support.team_12@example.co.in or user@test.com."
        results = detect_pii_regex(text)
        email_dets = [r for r in results if r['type'] == 'EMAIL']
        self.assertEqual(len(email_dets), 2)
        values = [e['value'] for e in email_dets]
        self.assertIn('support.team_12@example.co.in', values)
        self.assertIn('user@test.com', values)

    def test_passport_and_ifsc(self):
        """Test passport numbers and banking IFSC codes."""
        text = "Passport: K1234567, Bank IFSC: HDFC0001234."
        results = detect_pii_regex(text)
        types = {r['type']: r['value'] for r in results}
        self.assertIn('PASSPORT', types)
        self.assertEqual(types['PASSPORT'], 'K1234567')
        self.assertIn('IFSC', types)
        self.assertEqual(types['IFSC'], 'HDFC0001234')

    def test_dob_detection(self):
        """Test Date of Birth formats."""
        text = "Born on 15/08/1995 or 1995-08-15."
        results = detect_pii_regex(text)
        dob_dets = [r for r in results if r['type'] == 'DOB']
        self.assertGreaterEqual(len(dob_dets), 1)

    def test_pincode_detection(self):
        """Test 6-digit Indian PIN codes."""
        text = "Delivery address in Chennai - 600040."
        results = detect_pii_regex(text)
        pin_dets = [r for r in results if r['type'] == 'PINCODE']
        self.assertEqual(len(pin_dets), 1)
        self.assertEqual(pin_dets[0]['value'], '600040')

    def test_non_overlapping_order(self):
        """Test that overlapping entities resolve cleanly without corrupted spans."""
        text = "Card: ABCPK1234F, Aadhaar: 4832 7612 9045"
        results = detect_pii_regex(text)
        for i in range(len(results) - 1):
            self.assertLessEqual(results[i]['end'], results[i + 1]['start'])

    def test_pattern_summary(self):
        """Test pattern summary structure."""
        summary = get_pattern_summary()
        self.assertIn('AADHAAR', summary)
        self.assertIn('PAN', summary)
        self.assertIn('PHONE', summary)
        self.assertIn('EMAIL', summary)
        self.assertIn('PASSPORT', summary)
        self.assertIn('IFSC', summary)


if __name__ == '__main__':
    unittest.main()
