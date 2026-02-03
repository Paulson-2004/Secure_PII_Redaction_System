from redaction import redact_text


def test_redaction_policy_mask_and_redact():
    text = "Aadhaar 1234 5678 9012 PAN ABCDE1234F Email john@gmail.com"
    pii_list = [
        {"type": "AADHAAR", "value": "1234 5678 9012"},
        {"type": "PAN", "value": "ABCDE1234F"},
        {"type": "EMAIL", "value": "john@gmail.com"},
    ]
    redacted = redact_text(text, pii_list)

    assert "████████" in redacted
    assert "******1234F" in redacted
    assert "*****n@gmail.com" in redacted
