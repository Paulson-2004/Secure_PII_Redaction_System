policy_rules = {
    "AADHAAR": "REDACT",
    "PAN": "MASK",
    "PHONE": "MASK",
    "EMAIL": "MASK",
    "PERSON": "KEEP"
}

def decide_action(pii_type):
    return policy_rules.get(pii_type, "KEEP")
