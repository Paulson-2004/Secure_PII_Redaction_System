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
    get_rag_status_lightweight,
    PRIVACY_POLICIES,
    SOURCE_TYPES,
    COMPLIANCE_DISCLAIMER
)


class TestRAGDecisionEngine(unittest.TestCase):
    """Unit tests for Authoritative Privacy & Security Policy Corpus and RAG decision engine."""

    def test_01_engine_initialization_metadata(self):
        """Engine initializes lightweight metadata without loading heavy embeddings."""
        engine = RAGDecisionEngine()
        status = engine.get_engine_status()
        self.assertIn('rag_enabled', status)
        self.assertIn('total_policies', status)
        self.assertEqual(status['total_policies'], 29)
        self.assertEqual(status['corpus_name'], 'Authoritative Privacy & Security Policy Corpus')
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
                self.assertEqual(status['total_policies'], 29)
                self.assertEqual(status['corpus_name'], 'Authoritative Privacy & Security Policy Corpus')
                self.assertIn('source_type_breakdown', status)
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
            self.assertEqual(decision['source_type'], 'legislation')
            self.assertIn('Aadhaar', decision['regulation'])
            self.assertEqual(decision['engine'], 'RULE_POLICY')
            self.assertEqual(decision['retrieval_distance'], 0.0)
            self.assertIn('PrivLock provides technical privacy/security guidance', decision['disclaimer'])

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
            self.assertEqual(decision['source_type'], 'legislation')
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
            self.assertEqual(decision['source_type'], 'regulation')
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
                self.assertIn('source_type', e)
                self.assertIn('disclaimer', e)
                self.assertIn('decision_engine', e)
                self.assertEqual(e['decision_engine'], 'RULE_POLICY')

            mock_st.assert_not_called()
            self.assertIsNone(engine.embedding_model)

    def test_08_unknown_entity_triggers_semantic_retrieval(self):
        """Unknown PII type triggers lazy semantic search when embeddings are available."""
        engine = RAGDecisionEngine()
        det = {'type': 'CUSTOM_SENSITIVE_FIELD', 'value': 'XYZ-12345'}
        decision = engine.get_decision(det)
        self.assertIn(decision['action'], ['FULL_REDACT', 'PARTIAL_MASK', 'KEEP'])
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

    def test_11_authoritative_policy_metadata_verification(self):
        """Verify all policies contain valid source_type, source_url, jurisdiction, and action."""
        self.assertEqual(len(PRIVACY_POLICIES), 29)
        for p in PRIVACY_POLICIES:
            self.assertTrue(len(p.get('id', '')) > 0)
            self.assertTrue(len(p.get('name', '')) > 0)
            self.assertTrue(len(p.get('pii_type', '')) > 0)
            self.assertIn(p.get('source_type'), SOURCE_TYPES)
            self.assertTrue(len(p.get('citation', '')) > 0)
            self.assertTrue(len(p.get('jurisdiction', '')) > 0)
            self.assertTrue(len(p.get('applicability', '')) > 0)
            self.assertTrue(len(p.get('source_url', '')) > 0)
            self.assertTrue(p.get('source_url', '').startswith(('http://', 'https://')))
            self.assertIn(p.get('action'), ['FULL_REDACT', 'PARTIAL_MASK', 'BLUR', 'KEEP'])
            self.assertIn(p.get('severity'), ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'])

    def test_12_source_type_categorization_integrity(self):
        """Verify legislation, regulations, standards, official guidance, and mappings are distinct."""
        policies_by_id = {p['id']: p for p in PRIVACY_POLICIES}

        # 1. Primary legislation (Acts of Parliament / EU Regulations)
        self.assertEqual(policies_by_id['POL-001']['source_type'], 'legislation')  # Aadhaar Act 2016
        self.assertEqual(policies_by_id['POL-002']['source_type'], 'legislation')  # Income Tax Act 1961
        self.assertEqual(policies_by_id['POL-005']['source_type'], 'legislation')  # DPDP Act 2023 / GDPR
        self.assertEqual(policies_by_id['POL-007']['source_type'], 'legislation')  # Motor Vehicles Act 1988
        self.assertEqual(policies_by_id['POL-008']['source_type'], 'legislation')  # Representation of the People Act 1951
        self.assertEqual(policies_by_id['POL-013']['source_type'], 'legislation')  # Passports Act 1967
        self.assertEqual(policies_by_id['POL-016']['source_type'], 'legislation')  # DPDP Act 2023 / GDPR Art 5

        # 2. Subordinate Regulations (Rules notified under Acts)
        self.assertEqual(policies_by_id['POL-003']['source_type'], 'regulation')   # DPDP Rules 2025
        self.assertEqual(policies_by_id['POL-004']['source_type'], 'regulation')   # DPDP Rules 2025 / SPDI
        self.assertEqual(policies_by_id['POL-017']['source_type'], 'regulation')   # DPDP Rules 2025
        self.assertEqual(policies_by_id['POL-018']['source_type'], 'regulation')   # DPDP Rules 2025
        self.assertEqual(policies_by_id['POL-019']['source_type'], 'regulation')   # DPDP Rules 2025

        # 3. Security Standards (Industry / international standards, NOT laws)
        self.assertEqual(policies_by_id['POL-014']['source_type'], 'standard')     # PCI DSS v4.0.1
        self.assertEqual(policies_by_id['iso_27001_masking']['source_type'], 'standard')  # ISO/IEC 27001:2022

        # 4. Official Guidance (Government technical guidance, NOT legislation)
        self.assertEqual(policies_by_id['nist_sp_800_122']['source_type'], 'official_guidance')

        # 5. Policy Mappings (PrivLock technical use-case rules derived from primary sources)
        self.assertEqual(policies_by_id['POL-010']['source_type'], 'policy_mapping')  # PINCODE
        self.assertEqual(policies_by_id['POL-011']['source_type'], 'policy_mapping')  # ORGANIZATION
        self.assertEqual(policies_by_id['POL-015']['source_type'], 'policy_mapping')  # IFSC
        self.assertEqual(policies_by_id['medical_data_confidentiality']['source_type'], 'policy_mapping')
        self.assertEqual(policies_by_id['bank_stmt_redaction']['source_type'], 'policy_mapping')
        self.assertEqual(policies_by_id['salary_slip_confidentiality']['source_type'], 'policy_mapping')
        self.assertEqual(policies_by_id['tax_return_confidentiality']['source_type'], 'policy_mapping')
        self.assertEqual(policies_by_id['contract_nda_confidentiality']['source_type'], 'policy_mapping')
        self.assertEqual(policies_by_id['general_pii_default']['source_type'], 'policy_mapping')

    def test_13_dpdp_rules_2025_final_rules_represented(self):
        """Verify final DPDP Rules 2025 notified Nov 2025 is cited and old draft rules are not used."""
        engine = RAGDecisionEngine()
        phone_p = engine.search_policy("PHONE")
        self.assertEqual(phone_p['source_type'], 'regulation')
        self.assertIn("Personal Data Protection Rules, 2025", phone_p['citation'])
        self.assertIn("Nov 2025", phone_p['version'])
        self.assertEqual(phone_p['effective_date'], "2025-11-14")
        self.assertIn("meity.gov.in", phone_p['source_url'])

    def test_14_pci_dss_v4_0_1_credit_card_standard(self):
        """Verify PCI DSS v4.0.1 published active standard and cardholder masking metadata."""
        engine = RAGDecisionEngine()
        cc_p = engine.search_policy("credit card payment card primary account number")
        self.assertEqual(cc_p['pii_type'], "CREDIT_CARD")
        self.assertEqual(cc_p['source_type'], "standard")
        self.assertIn("PCI DSS v4.0.1", cc_p['citation'])
        self.assertIn("June 2024", cc_p['version'])
        self.assertEqual(cc_p['action'], "PARTIAL_MASK")
        self.assertIn("pcisecuritystandards.org", cc_p['source_url'])
        self.assertIn("Applies to entities that store, process, or transmit cardholder data", cc_p['applicability'])

    def test_15_gdpr_data_minimization_and_erasure(self):
        """Verify GDPR (EU) 2016/679 and DPDP data minimization and retention policies."""
        engine = RAGDecisionEngine()
        min_p = engine.search_policy("data minimization purpose limitation extraneous data")
        self.assertEqual(min_p['pii_type'], "DATA_MINIMIZATION")
        self.assertEqual(min_p['source_type'], "legislation")
        self.assertIn("2016/679", min_p['citation'])
        self.assertIn("eur-lex.europa.eu", min_p['source_url'])

        ret_p = engine.search_policy("data retention erasure mandate storage limitation")
        self.assertEqual(ret_p['pii_type'], "DATA_RETENTION")
        self.assertEqual(ret_p['source_type'], "regulation")
        self.assertIn("DPDP Rules 2025", ret_p['regulation'])
        self.assertEqual(ret_p['action'], "FULL_REDACT")

    def test_16_aadhaar_uidai_policy_retrieval(self):
        """Verify Aadhaar Act 2016 legislation and technical masking treatment."""
        engine = RAGDecisionEngine()
        a_p = engine.search_policy("Aadhaar number unique identification UIDAI Indian personal data")
        self.assertEqual(a_p['pii_type'], "AADHAAR")
        self.assertEqual(a_p['source_type'], "legislation")
        self.assertIn("Aadhaar", a_p['citation'])
        self.assertIn("uidai.gov.in", a_p['source_url'])
        self.assertEqual(a_p['action'], "FULL_REDACT")

    def test_17_disha_not_represented_as_enacted_law(self):
        """Verify DISHA is explicitly noted as a draft/un-enacted proposal and medical data is policy_mapping."""
        policies_by_id = {p['id']: p for p in PRIVACY_POLICIES}
        med_policy = policies_by_id['medical_data_confidentiality']
        self.assertEqual(med_policy['source_type'], 'policy_mapping')
        self.assertIn('DISHA', med_policy['description'])
        self.assertIn('never enacted', med_policy['description'].lower())
        self.assertIn('DPDP Act 2023', med_policy['derived_from'][0])

        # Verify no policy claims DISHA as an enacted statute
        for p in PRIVACY_POLICIES:
            if 'DISHA' in p.get('citation', ''):
                self.assertNotEqual(p.get('source_type'), 'legislation')

    def test_18_policy_mappings_have_derived_from(self):
        """Verify all policy mappings document their primary derived sources and do not claim to be statutes."""
        for p in PRIVACY_POLICIES:
            if p['source_type'] == 'policy_mapping':
                self.assertIn('derived_from', p)
                self.assertIsInstance(p['derived_from'], list)
                self.assertGreaterEqual(len(p['derived_from']), 1)
                self.assertNotEqual(p['status'], 'enacted')


if __name__ == '__main__':
    unittest.main()
