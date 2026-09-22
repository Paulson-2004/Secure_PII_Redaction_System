import unittest
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from modules.rag_decision_engine import get_rag_engine, decide_redaction


class TestRAGDecisionEngine(unittest.TestCase):
    """Unit tests for RAG policy decision engine and regulatory retrieval."""

    def setUp(self):
        self.engine = get_rag_engine()

    def test_engine_initialization(self):
        status = self.engine.get_engine_status()
        self.assertIn('rag_enabled', status)
        self.assertIn('total_policies', status)
        self.assertGreaterEqual(status['total_policies'], 13)

    def test_aadhaar_policy_decision(self):
        det = {'type': 'AADHAAR', 'value': '4832 7612 9045', 'confidence': 0.95}
        decision = self.engine.get_decision(det)
        self.assertEqual(decision['action'], 'FULL_REDACT')
        self.assertEqual(decision['severity'], 'CRITICAL')
        self.assertIn('Aadhaar', decision['regulation'])

    def test_pan_policy_decision(self):
        det = {'type': 'PAN', 'value': 'ABCPK1234F', 'confidence': 0.98}
        decision = self.engine.get_decision(det)
        self.assertEqual(decision['action'], 'FULL_REDACT')
        self.assertEqual(decision['severity'], 'CRITICAL')
        self.assertIn('Income Tax', decision['regulation'])

    def test_phone_policy_decision(self):
        det = {'type': 'PHONE', 'value': '9876543210', 'confidence': 0.90}
        decision = self.engine.get_decision(det)
        self.assertEqual(decision['action'], 'PARTIAL_MASK')
        self.assertEqual(decision['severity'], 'HIGH')

    def test_batch_enrichment(self):
        dets = [
            {'type': 'AADHAAR', 'value': '4832 7612 9045'},
            {'type': 'PAN', 'value': 'ABCPK1234F'},
            {'type': 'PHONE', 'value': '9876543210'},
            {'type': 'EMAIL', 'value': 'test@example.com'},
            {'type': 'PINCODE', 'value': '600001'},
        ]
        enriched = self.engine.process_all_detections(dets)
        self.assertEqual(len(enriched), 5)
        for e in enriched:
            self.assertIn('decision', e)
            self.assertIn('regulation', e)
            self.assertIn('policy_id', e)
            self.assertIn('decision_engine', e)

    def test_unknown_entity_fallback(self):
        det = {'type': 'CUSTOM_SENSITIVE_FIELD', 'value': 'XYZ-12345'}
        decision = self.engine.get_decision(det)
        self.assertIn(decision['action'], ['FULL_REDACT', 'PARTIAL_MASK'])


if __name__ == '__main__':
    unittest.main()

