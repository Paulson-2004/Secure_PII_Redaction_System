from policy_engine import decide_action

def mask_value(value):
    if "@" in value:
        local, domain = value.split("@", 1)
        if len(local) <= 1:
            return "*" + "@" + domain
        stars = max(5, len(local) - 1)
        return "*" * stars + local[-1:] + "@" + domain

    if len(value) <= 4:
        return "*" * len(value)

    return "*" * (len(value) - 4) + value[-4:]


def mask_value_by_type(value, pii_type):
    if pii_type == "PAN":
        if len(value) <= 5:
            return "*" * len(value)
        return "******" + value[-5:]

    return mask_value(value)

def _apply_span_replacements(text, replacements):
    # Apply from end to avoid shifting indices.
    for start, end, replacement in sorted(replacements, key=lambda r: r[0], reverse=True):
        if start is None or end is None or start < 0 or end < 0 or end < start:
            continue
        text = text[:start] + replacement + text[end:]
    return text


def redact_text(text, pii_list):
    span_replacements = []

    for item in pii_list:
        action = decide_action(item, text=text)
        value = item["value"]
        start = item.get("start")
        end = item.get("end")

        if action == "REDACT":
            if start is not None and end is not None:
                span_replacements.append((start, end, "████████"))
            else:
                text = text.replace(value, "████████")

        elif action == "MASK":
            if start is not None and end is not None:
                original = text[start:end]
                span_replacements.append((start, end, mask_value_by_type(original, item.get("type"))))
            else:
                text = text.replace(value, mask_value_by_type(value, item.get("type")))

    if span_replacements:
        text = _apply_span_replacements(text, span_replacements)

    return text
