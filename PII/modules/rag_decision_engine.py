"""
Module 5: RAG-Based AI Decision Engine.
Retrieval Augmented Generation for Policy-Aware Redaction.

AI Architecture:
- Privacy policies codified into a regulatory knowledge base (DPDP Act, IT Act, Aadhaar Act, RBI).
- FAISS vector database + SentenceTransformer embeddings for semantic policy retrieval.
- Embedding caching & batch encoding for ultra-low latency.
- Deterministic TF-IDF / semantic similarity fallback when external vector DB dependencies are offline.
"""

import math
import logging
from collections import Counter

logger = logging.getLogger('rag_decision_engine')

# Attempt imports for high-dimensional vector search
try:
    from sentence_transformers import SentenceTransformer
    EMBEDDINGS_AVAILABLE = True
except ImportError:
    EMBEDDINGS_AVAILABLE = False

try:
    import faiss
    FAISS_AVAILABLE = True
except ImportError:
    FAISS_AVAILABLE = False


# ============================================================
# PRIVACY POLICIES KNOWLEDGE BASE
# ============================================================

PRIVACY_POLICIES = [
    {
        "id": "POL-001",
        "pii_type": "AADHAAR",
        "policy_text": "Aadhaar number is a 12-digit unique identity number issued by UIDAI. It is highly sensitive personal data. Full redaction or masking of the first 8 digits is mandated. No unmasked display allowed.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "regulation": "Aadhaar Act 2016 (Sec 29), UIDAI Circular 2018"
    },
    {
        "id": "POL-002",
        "pii_type": "PAN",
        "policy_text": "Permanent Account Number is a 10-character alphanumeric tax identifier issued by the Income Tax Department. Critical financial identity. Must be fully redacted to prevent tax identity theft.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "regulation": "Income Tax Act 1961, IT Rules"
    },
    {
        "id": "POL-003",
        "pii_type": "PHONE",
        "policy_text": "Mobile and telephone contact numbers are personal identifiers. Redact or partially mask showing only the last 4 digits for verification.",
        "action": "PARTIAL_MASK",
        "mask_format": "XXXXXX{last4}",
        "severity": "HIGH",
        "regulation": "Digital Personal Data Protection (DPDP) Act 2023"
    },
    {
        "id": "POL-004",
        "pii_type": "EMAIL",
        "policy_text": "Personal and enterprise email addresses reveal electronic communications identity. Partially mask username while preserving domain for contextual authenticity.",
        "action": "PARTIAL_MASK",
        "mask_format": "{u}***@{domain}",
        "severity": "HIGH",
        "regulation": "DPDP Act 2023, IT Act 2000"
    },
    {
        "id": "POL-005",
        "pii_type": "PERSON_NAME",
        "policy_text": "Individual names identify the data principal. Mask surname or middle name to preserve document context while safeguarding identity.",
        "action": "PARTIAL_MASK",
        "mask_format": "{first_char}***",
        "severity": "MEDIUM",
        "regulation": "DPDP Act 2023"
    },
    {
        "id": "POL-006",
        "pii_type": "LOCATION",
        "policy_text": "Specific geographic localities, districts, and regions can enable physical tracking when paired with other identifiers. Redact residential locations.",
        "action": "FULL_REDACT",
        "severity": "MEDIUM",
        "regulation": "DPDP Act 2023"
    },
    {
        "id": "POL-007",
        "pii_type": "DRIVING_LICENSE",
        "policy_text": "Government driving licence number issued by state RTOs. Official identity proof. Fully redact to prevent counterfeit licensing and impersonation.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "regulation": "Motor Vehicles Act 1988"
    },
    {
        "id": "POL-008",
        "pii_type": "VOTER_ID",
        "policy_text": "Electoral Photo Identity Card (EPIC) voter ID number issued by Election Commission. High sensitivity voter identification. Must be fully redacted.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "regulation": "Representation of the People Act 1951"
    },
    {
        "id": "POL-009",
        "pii_type": "DOB",
        "policy_text": "Date of birth is an authentication factor in banking and KYC verification. Fully redact or mask day/month to prevent age-related vulnerability.",
        "action": "FULL_REDACT",
        "severity": "HIGH",
        "regulation": "DPDP Act 2023"
    },
    {
        "id": "POL-010",
        "pii_type": "PINCODE",
        "policy_text": "Postal Index Numbers indicate general postal zones. PIN codes are semi-public and may be kept for regional demographics unless bound to street addresses.",
        "action": "KEEP",
        "severity": "LOW",
        "regulation": "General Privacy Practice"
    },
    {
        "id": "POL-011",
        "pii_type": "ORGANIZATION",
        "policy_text": "Institutional names (employers, banks, universities) are generally public entities. Keep unless explicitly marked confidential.",
        "action": "KEEP",
        "severity": "LOW",
        "regulation": "General Privacy Practice"
    },
    {
        "id": "POL-012",
        "pii_type": "ADDRESS",
        "policy_text": "Detailed residential or private address data. Poses severe physical privacy risks. Must be fully redacted.",
        "action": "FULL_REDACT",
        "severity": "HIGH",
        "regulation": "DPDP Act 2023"
    },
    {
        "id": "POL-013",
        "pii_type": "PASSPORT",
        "policy_text": "International travel passport number. Sovereign identity credential. Mandatory full redaction to prevent international passport fraud.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "regulation": "Passports Act 1967"
    },
    {
        "id": "POL-014",
        "pii_type": "CREDIT_CARD",
        "policy_text": "Payment card numbers (PAN/CVV) subject to PCI-DSS standards. Primary Account Number must have middle digits masked.",
        "action": "PARTIAL_MASK",
        "mask_format": "XXXX-XXXX-XXXX-{last4}",
        "severity": "CRITICAL",
        "regulation": "PCI-DSS v4.0, RBI Digital Payment Guidelines"
    },
    {
        "id": "POL-015",
        "pii_type": "IFSC",
        "policy_text": "Indian Financial System Code identifying bank branch. Public bank routing metadata. May be kept for routing context.",
        "action": "KEEP",
        "severity": "LOW",
        "regulation": "RBI Banking Regulations"
    },
]


def _tokenize(text):
    return [w.lower() for w in text.split() if len(w) > 2]


class RAGDecisionEngine:
    """
    RAG Policy Decision Engine with FAISS vector search, batch caching, and TF-IDF fallback.
    """

    def __init__(self):
        self.policies = PRIVACY_POLICIES
        self.policy_by_type = {p['pii_type']: p for p in self.policies}
        self.embedding_model = None
        self.faiss_index = None
        self.use_rag = False
        self._embedding_cache = {}
        self._tfidf_docs = []
        self._vocab = set()

        self._initialize()

    def _initialize(self):
        """Initialize FAISS vector store or setup TF-IDF fallback vocabulary."""
        # Setup fallback search vocabulary
        for p in self.policies:
            tokens = _tokenize(f"{p['pii_type']} {p['policy_text']} {p['regulation']}")
            self._tfidf_docs.append((p, Counter(tokens)))
            self._vocab.update(tokens)

        if EMBEDDINGS_AVAILABLE and FAISS_AVAILABLE:
            try:
                self.embedding_model = SentenceTransformer('all-MiniLM-L6-v2')
                texts = [f"{p['pii_type']}: {p['policy_text']}" for p in self.policies]
                embeddings = self.embedding_model.encode(texts)
                dimension = embeddings.shape[1]

                self.faiss_index = faiss.IndexFlatL2(dimension)
                self.faiss_index.add(embeddings.astype('float32'))
                self.use_rag = True
                logger.info("RAG Engine online: %d policies indexed in FAISS", len(self.policies))
            except Exception as e:
                logger.warning("RAG FAISS initialization failed (%s). Using semantic fallback.", e)
                self.use_rag = False
        else:
            self.use_rag = False

    def _retrieve_tfidf_fallback(self, query):
        """Lightweight semantic similarity fallback using token vector cosine similarity."""
        q_tokens = Counter(_tokenize(query))
        best_policy = None
        best_score = -1.0

        for policy, doc_tokens in self._tfidf_docs:
            common = set(q_tokens.keys()) & set(doc_tokens.keys())
            if not common:
                continue
            dot = sum(q_tokens[t] * doc_tokens[t] for t in common)
            norm_q = math.sqrt(sum(v * v for v in q_tokens.values()))
            norm_d = math.sqrt(sum(v * v for v in doc_tokens.values()))
            score = dot / (norm_q * norm_d) if norm_q and norm_d else 0.0

            if score > best_score:
                best_score = score
                best_policy = policy

        return best_policy, round(best_score, 3)

    def get_decision(self, pii_detection):
        """
        Evaluate redaction decision for a single PII entity.

        Args:
            pii_detection: dict with keys {type, value, confidence, ...}

        Returns:
            dict of decision metadata {action, severity, regulation, policy_id, ...}
        """
        pii_type = pii_detection.get('type', 'UNKNOWN')
        pii_val = pii_detection.get('value', '')

        # Fast deterministic lookup if exact policy exists
        direct_policy = self.policy_by_type.get(pii_type)

        if self.use_rag:
            query = f"Privacy policy and redaction rules for {pii_type} with value {pii_val}"
            try:
                if query not in self._embedding_cache:
                    q_emb = self.embedding_model.encode([query])
                    self._embedding_cache[query] = q_emb
                else:
                    q_emb = self._embedding_cache[query]

                distances, indices = self.faiss_index.search(q_emb.astype('float32'), 1)
                best_idx = indices[0][0]
                dist = float(distances[0][0])
                retrieved_policy = self.policies[best_idx]

                # Semantic verification: if retrieved policy matches type or is close
                if retrieved_policy['pii_type'] == pii_type or direct_policy is None:
                    policy = retrieved_policy
                else:
                    policy = direct_policy

                engine_mode = 'RAG_FAISS'
            except Exception:
                policy = direct_policy or self.policies[0]
                dist = 0.0
                engine_mode = 'FALLBACK_DIRECT'
        else:
            if direct_policy:
                policy = direct_policy
                dist = 0.0
                engine_mode = 'RULE_POLICY'
            else:
                retrieved, score = self._retrieve_tfidf_fallback(f"{pii_type} {pii_val}")
                policy = retrieved or {
                    "pii_type": pii_type,
                    "action": "FULL_REDACT",
                    "severity": "HIGH",
                    "regulation": "Default Privacy Baseline",
                    "policy_text": "Uncategorized sensitive data default redaction.",
                    "id": "POL-DEF"
                }
                dist = 1.0 - score if score > 0 else 1.0
                engine_mode = 'SEMANTIC_FALLBACK'

        return {
            'action': policy.get('action', 'FULL_REDACT'),
            'severity': policy.get('severity', 'HIGH'),
            'regulation': policy.get('regulation', 'Standard Privacy Policy'),
            'policy_id': policy.get('id', 'POL-DEFAULT'),
            'policy_text': policy.get('policy_text', ''),
            'mask_format': policy.get('mask_format'),
            'retrieval_distance': dist,
            'engine': engine_mode
        }

    def process_all_detections(self, detections):
        """Enrich a list of PII detections with regulatory decisions."""
        enriched = []
        for d in detections:
            decision = self.get_decision(d)
            enriched.append({
                **d,
                'decision': decision['action'],
                'severity': decision['severity'],
                'regulation': decision['regulation'],
                'policy_id': decision['policy_id'],
                'mask_format': decision['mask_format'],
                'decision_engine': decision['engine']
            })
        return enriched

    def get_engine_status(self):
        """Return engine operational status for API diagnostics."""
        return {
            'rag_enabled': self.use_rag,
            'total_policies': len(self.policies),
            'embedding_model': 'all-MiniLM-L6-v2' if self.use_rag else 'TF-IDF-Cosine-Fallback',
            'vector_db': 'FAISS' if self.use_rag else 'Embedded-Semantic-Index',
            'index_size': self.faiss_index.ntotal if self.faiss_index else len(self.policies)
        }


# Singleton instance
_engine = None


def get_rag_engine():
    """Retrieve or construct the global RAG decision engine singleton."""
    global _engine
    if _engine is None:
        _engine = RAGDecisionEngine()
    return _engine


def decide_redaction(detections):
    """Convenience function: process detections through policy decision pipeline."""
    return get_rag_engine().process_all_detections(detections)
