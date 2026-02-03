from config import CONFIG
from rag_service import decide_action_rag

policy_rules = {
    "AADHAAR": "REDACT",
    "PAN": "MASK",
    "PHONE": "MASK",
    "EMAIL": "MASK",
    "DL": "MASK",
    "PASSPORT": "MASK",
    "VOTER_ID": "MASK",
    "ACCOUNT": "MASK",
    "IFSC": "MASK",
    "IP_ADDRESS": "MASK",
    "DOB": "MASK",
    "ADDRESS": "REDACT",
    "PERSON": "KEEP",
}


def rag_policy_stub(pii_item, text):
    pii_type = pii_item.get("type")
    action = policy_rules.get(pii_type, "KEEP")
    return {"action": action, "reason": "rag_stub_default"}


def decide_action(pii_item, text=None):
    if CONFIG.enable_rag_stub:
        return decide_action_rag(pii_item, text or "")

    pii_type = pii_item.get("type") if isinstance(pii_item, dict) else pii_item
    return policy_rules.get(pii_type, "KEEP")
