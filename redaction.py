
def mask_value(value):
    return "*" * (len(value)-4) + value[-4:]

def redact_text(text, pii_list):
    for item in pii_list:
        if len(item) > 8:
            text = text.replace(item, mask_value(item))
        else:
            text = text.replace(item, "██████")
    return text
