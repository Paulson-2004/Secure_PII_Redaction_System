"""
Module 5: RAG-Based AI Decision Engine
(Retrieval Augmented Generation for Policy-Aware Redaction)

AI Components:
- Privacy policies converted to vector embeddings
- FAISS vector database for similarity search
- Policy retrieval for each detected PII type
- Decision engine: REDACT / MASK / KEEP

This module implements RAG without requiring an external LLM.
The policy retrieval + rule-based decision acts as the "generation" step.
"""

import numpy as np
import json

# Try to import sentence-transformers and faiss
try:
    from sentence_transformers import SentenceTransformer
    EMBEDDINGS_AVAILABLE = True
except ImportError:
    EMBEDDINGS_AVAILABLE = False
    print("Warning: sentence-transformers not installed. Using fallback policy engine.")

try:
    import faiss
    FAISS_AVAILABLE = True
except ImportError:
    FAISS_AVAILABLE = False
    print("Warning: faiss-cpu not installed. Using fallback policy engine.")


# ============================================================
# PRIVACY POLICIES (Knowledge Base for RAG)
# ============================================================

PRIVACY_POLICIES = [
    {
        "id": "POL-001",
        "pii_type": "AADHAAR",
        "policy_text": "Aadhaar number is a 12-digit unique identity number issued by UIDAI. It is highly sensitive personal information. Must be fully redacted in all documents. No partial display allowed as per UIDAI guidelines.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "regulation": "Aadhaar Act 2016, Section 29"
    },
    {
        "id": "POL-002",
        "pii_type": "PAN",
        "policy_text": "PAN card number is a 10-character alphanumeric identifier issued by Income Tax Department. Contains sensitive financial identity. Must be fully redacted to prevent identity theft and financial fraud.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "regulation": "Income Tax Act, IT Rules"
    },
    {
        "id": "POL-003",
        "pii_type": "PHONE",
        "policy_text": "Mobile phone number is personal contact information. Can be partially masked showing only last 4 digits for verification purposes while protecting privacy.",
        "action": "PARTIAL_MASK",
        "mask_format": "XXXXXX{last4}",
        "severity": "HIGH",
        "regulation": "IT Act 2000, DPDP Act 2023"
    },
    {
        "id": "POL-004",
        "pii_type": "EMAIL",
        "policy_text": "Email address is personal contact information. Should be partially masked showing only the domain name for context while hiding the username.",
        "action": "PARTIAL_MASK",
        "mask_format": "****@{domain}",
        "severity": "HIGH",
        "regulation": "DPDP Act 2023"
    },
    {
        "id": "POL-005",
        "pii_type": "PERSON_NAME",
        "policy_text": "Person name is personally identifiable information. In government documents, names should be partially masked to protect identity while maintaining document readability.",
        "action": "PARTIAL_MASK",
        "mask_format": "{first_char}***",
        "severity": "MEDIUM",
        "regulation": "DPDP Act 2023"
    },
    {
        "id": "POL-006",
        "pii_type": "LOCATION",
        "policy_text": "Location and address information can reveal personal residence. Should be fully redacted when part of a personal document to prevent tracking.",
        "action": "FULL_REDACT",
        "severity": "MEDIUM",
        "regulation": "DPDP Act 2023"
    },
    {
        "id": "POL-007",
        "pii_type": "DRIVING_LICENSE",
        "policy_text": "Driving license number is a government-issued identity number. Must be fully redacted as it can be used for identity fraud.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "regulation": "Motor Vehicles Act"
    },
    {
        "id": "POL-008",
        "pii_type": "VOTER_ID",
        "policy_text": "Voter ID EPIC number is a government-issued unique identifier. Must be fully redacted to prevent election fraud and identity theft.",
        "action": "FULL_REDACT",
        "severity": "CRITICAL",
        "regulation": "Representation of People Act"
    },
    {
        "id": "POL-009",
        "pii_type": "DOB",
        "policy_text": "Date of birth is sensitive personal information used in identity verification. Should be fully redacted to prevent age-based discrimination and identity theft.",
        "action": "FULL_REDACT",
        "severity": "HIGH",
        "regulation": "DPDP Act 2023"
    },
    {
        "id": "POL-010",
        "pii_type": "PINCODE",
        "policy_text": "PIN code reveals geographic location at area level. Can be kept in most cases as it's semi-public information, but should be redacted when combined with other address details.",
        "action": "KEEP",
        "severity": "LOW",
        "regulation": "General Privacy Practice"
    },
    {
        "id": "POL-011",
        "pii_type": "ORGANIZATION",
        "policy_text": "Organization names are generally public information. Can be kept unless they reveal employment or institutional affiliation that could identify a person.",
        "action": "KEEP",
        "severity": "LOW",
        "regulation": "General Privacy Practice"
    },
    {
        "id": "POL-012",
        "pii_type": "ADDRESS",
        "policy_text": "Full residential address is highly sensitive personal information. Must be fully redacted to prevent physical security threats and stalking.",
        "action": "FULL_REDACT",
        "severity": "HIGH",
        "regulation": "DPDP Act 2023"
    },
    {
        "id": "POL-013",
        "pii_type": "DATE",
        "policy_text": "Generic dates in documents may or may not be PII. Issue dates and expiry dates of documents are less sensitive but dates of birth should be redacted.",
        "action": "PARTIAL_MASK",
        "mask_format": "XX/XX/XXXX",
        "severity": "MEDIUM",
        "regulation": "General Privacy Practice"
    }
]


class RAGDecisionEngine:
    """
    RAG-Based Policy Decision Engine.
    
    Pipeline:
    1. Encode privacy policies into vector embeddings
    2. Store embeddings in FAISS vector database
    3. For each detected PII → create query
    4. Retrieve most relevant policy using vector similarity
    5. Return redaction decision based on retrieved policy
    """
    
    def __init__(self):
        self.policies = PRIVACY_POLICIES
        self.policy_texts = [p['policy_text'] for p in self.policies]
        self.embedding_model = None
        self.faiss_index = None
        self.embeddings = None
        self.use_rag = False
        
        self._initialize()
    
    def _initialize(self):
        """Initialize embedding model and FAISS index."""
        if EMBEDDINGS_AVAILABLE and FAISS_AVAILABLE:
            try:
                # Load sentence transformer model for embeddings
                self.embedding_model = SentenceTransformer('all-MiniLM-L6-v2')
                
                # Encode all policies into vectors
                self.embeddings = self.embedding_model.encode(self.policy_texts)
                
                # Create FAISS index
                dimension = self.embeddings.shape[1]
                self.faiss_index = faiss.IndexFlatL2(dimension)
                self.faiss_index.add(self.embeddings.astype('float32'))
                
                self.use_rag = True
                print(f"RAG Engine initialized: {len(self.policies)} policies indexed in FAISS")
            except Exception as e:
                print(f"RAG initialization failed: {e}. Using fallback.")
                self.use_rag = False
        else:
            self.use_rag = False
            print("RAG Engine using fallback (direct policy lookup)")
    
    def _retrieve_policy_rag(self, query_text):
        """
        Retrieve most relevant policy using FAISS similarity search.
        This is the RAG retrieval step.
        """
        query_embedding = self.embedding_model.encode([query_text])
        
        # Search FAISS for top-k similar policies
        k = 3
        distances, indices = self.faiss_index.search(query_embedding.astype('float32'), k)
        
        # Return best matching policy
        best_idx = indices[0][0]
        best_distance = distances[0][0]
        
        return self.policies[best_idx], float(best_distance)
    
    def _retrieve_policy_fallback(self, pii_type):
        """
        Fallback: Direct lookup by PII type when FAISS is not available.
        """
        for policy in self.policies:
            if policy['pii_type'] == pii_type:
                return policy, 0.0
        
        # Default policy: REDACT
        return {
            "pii_type": pii_type,
            "action": "FULL_REDACT",
            "severity": "HIGH",
            "regulation": "Default Privacy Policy",
            "policy_text": "Unknown PII type - default to full redaction for safety."
        }, 1.0
    
    def get_decision(self, pii_detection):
        """
        Get redaction decision for a detected PII item.
        
        Args:
            pii_detection: Dict with {type, value, confidence, ...}
            
        Returns:
            Dict with {action, severity, regulation, policy_text, retrieval_distance}
        """
        pii_type = pii_detection['type']
        pii_value = pii_detection['value']
        
        if self.use_rag:
            # RAG-based retrieval
            query = f"How to handle {pii_type} with value like {pii_value} in a document?"
            policy, distance = self._retrieve_policy_rag(query)
        else:
            # Fallback lookup
            policy, distance = self._retrieve_policy_fallback(pii_type)
        
        return {
            'action': policy.get('action', 'FULL_REDACT'),
            'severity': policy.get('severity', 'HIGH'),
            'regulation': policy.get('regulation', 'Unknown'),
            'policy_id': policy.get('id', 'FALLBACK'),
            'policy_text': policy.get('policy_text', ''),
            'mask_format': policy.get('mask_format', None),
            'retrieval_distance': distance,
            'engine': 'RAG' if self.use_rag else 'FALLBACK'
        }
    
    def process_all_detections(self, detections):
        """
        Process all PII detections and return decisions for each.
        
        Args:
            detections: List of PII detection dicts from hybrid engine
            
        Returns:
            List of detections enriched with redaction decisions
        """
        enriched = []
        
        for detection in detections:
            decision = self.get_decision(detection)
            
            enriched_detection = {
                **detection,
                'decision': decision['action'],
                'severity': decision['severity'],
                'regulation': decision['regulation'],
                'policy_id': decision['policy_id'],
                'mask_format': decision['mask_format'],
                'decision_engine': decision['engine']
            }
            
            enriched.append(enriched_detection)
        
        return enriched
    
    def get_engine_status(self):
        """Return RAG engine status for display."""
        return {
            'rag_enabled': self.use_rag,
            'total_policies': len(self.policies),
            'embedding_model': 'all-MiniLM-L6-v2' if self.use_rag else 'N/A',
            'vector_db': 'FAISS' if self.use_rag else 'N/A',
            'index_size': self.faiss_index.ntotal if self.faiss_index else 0
        }


# Singleton instance
_engine = None

def get_rag_engine():
    """Get or create RAG Decision Engine singleton."""
    global _engine
    if _engine is None:
        _engine = RAGDecisionEngine()
    return _engine


def decide_redaction(detections):
    """
    Convenience function: Process detections through RAG engine.
    """
    engine = get_rag_engine()
    return engine.process_all_detections(detections)


# Test function
if __name__ == '__main__':
    # Simulate detections
    test_detections = [
        {'type': 'AADHAAR', 'value': '4832 7612 9045', 'confidence': 0.95, 'source': 'REGEX'},
        {'type': 'PAN', 'value': 'ABCPK1234F', 'confidence': 0.98, 'source': 'REGEX'},
        {'type': 'PHONE', 'value': '9876543210', 'confidence': 0.90, 'source': 'REGEX'},
        {'type': 'EMAIL', 'value': 'rajesh@gmail.com', 'confidence': 0.95, 'source': 'REGEX'},
        {'type': 'PERSON_NAME', 'value': 'Rajesh Kumar', 'confidence': 0.85, 'source': 'NER'},
        {'type': 'LOCATION', 'value': 'Chennai', 'confidence': 0.85, 'source': 'NER'},
    ]
    
    engine = get_rag_engine()
    print(f"=== RAG Engine Status ===")
    for k, v in engine.get_engine_status().items():
        print(f"  {k}: {v}")
    
    print(f"\n=== RAG Decisions ===")
    results = engine.process_all_detections(test_detections)
    for r in results:
        print(f"  [{r['type']}] '{r['value']}' → {r['decision']} "
              f"(severity: {r['severity']}, regulation: {r['regulation']})")
