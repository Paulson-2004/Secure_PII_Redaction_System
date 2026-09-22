import unittest
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from modules.hybrid_engine import detect_pii_hybrid, _spans_overlap, _are_types_compatible


class TestHybridFusion(unittest.TestCase):
    """Unit tests for multi-model hybrid detection and fusion."""

    def test_spans_overlap(self):
        self.assertTrue(_spans_overlap(10, 20, 15, 25))
        self.assertTrue(_spans_overlap(10, 20, 5, 15))
        self.assertTrue(_spans_overlap(10, 20, 12, 18))
        self.assertFalse(_spans_overlap(10, 20, 20, 30))
        self.assertFalse(_spans_overlap(10, 20, 0, 10))

    def test_are_types_compatible(self):
        self.assertTrue(_are_types_compatible('DOB', 'DATE'))
        self.assertTrue(_are_types_compatible('DATE', 'DOB'))
        self.assertTrue(_are_types_compatible('PINCODE', 'LOCATION'))
        self.assertFalse(_are_types_compatible('PHONE', 'PERSON_NAME'))
        self.assertFalse(_are_types_compatible('AADHAAR', 'ORGANIZATION'))

    def test_hybrid_detection_pipeline(self):
        sample = (
            "Government of India\n"
            "Name: Rajesh Kumar\n"
            "Aadhaar: 4832 7612 9045\n"
            "DOB: 15/03/1990\n"
            "PAN: ABCPK1234F\n"
            "Phone: 9876543210\n"
            "Email: rajesh.kumar@example.com\n"
            "PIN: 600040"
        )
        res = detect_pii_hybrid(sample)
        dets = res['detections']
        stats = res['stats']

        self.assertGreaterEqual(stats['total_pii_found'], 5)
        types = [d['type'] for d in dets]
        self.assertIn('PERSON_NAME', types)
        self.assertIn('AADHAAR', types)
        self.assertIn('PAN', types)
        self.assertIn('PHONE', types)
        self.assertIn('EMAIL', types)

        # Government of India should NOT be detected as an entity
        values = [d['value'] for d in dets]
        self.assertNotIn('Government of India', values)
        self.assertNotIn('Govt of India', values)

        # Labels like DOB and PAN must not be detected as organizations
        org_values = [d['value'] for d in dets if d['type'] == 'ORGANIZATION']
        self.assertNotIn('DOB', org_values)
        self.assertNotIn('PAN', org_values)

        # Ensure all detected spans match original text exactly
        for d in dets:
            span_text = sample[d['start']:d['end']]
            self.assertEqual(span_text, d['value'], f"Span mismatch for {d['type']}")


if __name__ == '__main__':
    unittest.main()

