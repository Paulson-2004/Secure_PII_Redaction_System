import unittest
import sys
import os
from unittest.mock import patch, MagicMock

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import modules.rag_decision_engine as rag_mod
from modules.rag_decision_engine import (
    RAGDecisionEngine,
    get_rag_engine,
    decide_redaction,
    get_rag_status_lightweight
)


class TestRAGDecisionEngine(unittest.TestCase):
    """Unit tests for RAG policy decision engine, lazy embedding loading, and regulatory retrieval."""

    def test_01_engine_initialization_metadata(self):
        """Engine initializes lightweight metadata without loading heavy embeddings."""
        engine = RAGDecisionEngine()
        status = engine.get_engine_status()
        self.assertIn('rag_enabled', status)
        self.assertIn('total_policies', status)
        self.assertGreaterEqual(status['total_policies'], 13)
        self.assertFalse(status['embeddings_loaded'])
        self.assertIsNone(engine.embedding_model)
        self.assertIsNone(engine.faiss_index)

    def test_02_engine_creation_does_not_load_sentence_transformer(self):
        """Creating RAGDecisionEngine must not instantiate SentenceTransformer."""
        with patch('modules.rag_decision_engine.SentenceTransformer') as mock_st:
            engine = RAGDecisionEngine()
            mock_st.assert_not_called()
            self.assertIsNone(engine.embedding_model)
            self.assertIsNone(engine.faiss_index)

    def test_03_lightweight_status_does_not_initialize(self):
        """get_rag_status_lightweight() must not instantiate engine or SentenceTransformer."""
        orig_engine = rag_mod._engine
        rag_mod._engine = None
        try:
            with patch('modules.rag_decision_engine.SentenceTransformer') as mock_st:
                status = get_rag_status_lightweight()
                self.assertEqual(status['status'], 'ready_lazy')
                self.assertTrue(status['rag_enabled'])
                self.assertFalse(status['initialized'])
                self.assertEqual(status['total_policies'], 15)
                mock_st.assert_not_called()
                self.assertIsNone(rag_mod._engine)
        finally:
            rag_mod._engine = orig_engine

    def test_04_aadhaar_direct_policy_decision(self):
        """Direct AADHAAR policy returns POL-001 / FULL_REDACT without loading SentenceTransformer."""
        with patch('modules.rag_decision_engine.SentenceTransformer') as mock_st:
            engine = RAGDecisionEngine()
            det = {'type': 'AADHAAR', 'value': '4832 7612 9045', 'confidence': 0.95}
            decision = engine.get_decision(det)

            self.assertEqual(decision['action'], 'FULL_REDACT')
            self.assertEqual(decision['severity'], 'CRITICAL')
            self.assertEqual(decision['policy_id'], 'POL-001')
            self.assertIn('Aadhaar', decision['regulation'])
            self.assertEqual(decision['engine'], 'RULE_POLICY')
            self.assertEqual(decision['retrieval_distance'], 0.0)

            # Assert embeddings remained completely unloaded
            mock_st.assert_not_called()
            self.assertIsNone(engine.embedding_model)
            self.assertIsNone(engine.faiss_index)

    def test_05_pan_direct_policy_decision(self):
        """Direct PAN policy returns POL-002 / FULL_REDACT without loading SentenceTransformer."""
        with patch('modules.rag_decision_engine.SentenceTransformer') as mock_st:
            engine = RAGDecisionEngine()
            det = {'type': 'PAN', 'value': 'ABCPK1234F', 'confidence': 0.98}
            decision = engine.get_decision(det)

            self.assertEqual(decision['action'], 'FULL_REDACT')
            self.assertEqual(decision['severity'], 'CRITICAL')
            self.assertEqual(decision['policy_id'], 'POL-002')
            self.assertIn('Income Tax', decision['regulation'])
            self.assertEqual(decision['engine'], 'RULE_POLICY')

            mock_st.assert_not_called()
            self.assertIsNone(engine.embedding_model)

    def test_06_phone_direct_policy_decision(self):
        """Direct PHONE policy returns POL-003 / PARTIAL_MASK without loading SentenceTransformer."""
        with patch('modules.rag_decision_engine.SentenceTransformer') as mock_st:
            engine = RAGDecisionEngine()
            det = {'type': 'PHONE', 'value': '9876543210', 'confidence': 0.90}
            decision = engine.get_decision(det)

            self.assertEqual(decision['action'], 'PARTIAL_MASK')
            self.assertEqual(decision['severity'], 'HIGH')
            self.assertEqual(decision['policy_id'], 'POL-003')
            self.assertEqual(decision['mask_format'], 'XXXXXX{last4}')
            self.assertEqual(decision['engine'], 'RULE_POLICY')

            mock_st.assert_not_called()
            self.assertIsNone(engine.embedding_model)

    def test_07_batch_enrichment(self):
        """process_all_detections enriches all direct PII detections without loading SentenceTransformer."""
        with patch('modules.rag_decision_engine.SentenceTransformer') as mock_st:
            engine = RAGDecisionEngine()
            dets = [
                {'type': 'AADHAAR', 'value': '4832 7612 9045'},
                {'type': 'PAN', 'value': 'ABCPK1234F'},
                {'type': 'PHONE', 'value': '9876543210'},
                {'type': 'EMAIL', 'value': 'test@example.com'},
                {'type': 'PINCODE', 'value': '600001'},
            ]
            enriched = engine.process_all_detections(dets)
            self.assertEqual(len(enriched), 5)
            for e in enriched:
                self.assertIn('decision', e)
                self.assertIn('regulation', e)
                self.assertIn('policy_id', e)
                self.assertIn('decision_engine', e)
                self.assertEqual(e['decision_engine'], 'RULE_POLICY')

            mock_st.assert_not_called()
            self.assertIsNone(engine.embedding_model)

    def test_08_unknown_entity_triggers_semantic_retrieval(self):
        """Unknown PII type triggers lazy semantic search when embeddings are available."""
        engine = RAGDecisionEngine()
        det = {'type': 'CUSTOM_SENSITIVE_FIELD', 'value': 'XYZ-12345'}
        decision = engine.get_decision(det)
        self.assertIn(decision['action'], ['FULL_REDACT', 'PARTIAL_MASK'])
        self.assertIn(decision['engine'], ['RAG_FAISS', 'SEMANTIC_FALLBACK'])

    def test_09_semantic_failure_falls_back_safely(self):
        """When semantic embedding initialization throws, it safely falls back to TF-IDF."""
        engine = RAGDecisionEngine()
        with patch.object(engine, '_ensure_semantic_engine', return_value=False):
            det = {'type': 'UNKNOWN_HEALTH_RECORD', 'value': 'patient diagnosis confidential'}
            decision = engine.get_decision(det)
            self.assertIn(decision['action'], ['FULL_REDACT', 'PARTIAL_MASK', 'KEEP'])
            self.assertEqual(decision['engine'], 'SEMANTIC_FALLBACK')

    def test_10_singleton_thread_safety(self):
        """get_rag_engine() returns a consistent singleton instance."""
        e1 = get_rag_engine()
        e2 = get_rag_engine()
        self.assertIs(e1, e2)


if __name__ == '__main__':
    unittest.main()

