from policy_engine import decide_action

def mask_value(value):
    return "*" * (len(value)-4) + value[-4:]

def redact_text(text, pii_list):
    for item in pii_list:
        action = decide_action(item["type"])
        value = item["value"]

        if action == "REDACT":
            text = text.replace(value, "████████")

        elif action == "MASK":
            text = text.replace(value, mask_value(value))

    return text
