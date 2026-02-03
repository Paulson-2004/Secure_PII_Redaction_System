from pii_detector import detect_pii


def test_detect_pii_regex():
    text = "Aadhaar 1234 5678 9012, PAN ABCDE1234F, Phone 9876543210, Email a@b.com"
    found = detect_pii(text)
    types = {item["type"] for item in found}
    values = {item["value"] for item in found}

    assert "AADHAAR" in types
    assert "PAN" in types
    assert "PHONE" in types
    assert "EMAIL" in types
    assert "1234 5678 9012" in values
    assert "ABCDE1234F" in values
    assert "9876543210" in values
    assert "a@b.com" in values


def test_detect_dl_and_address():
    text = "DL: TN01 20201234567 Address: 12, MG Road,\nChennai"
    found = detect_pii(text)
    types = {item["type"] for item in found}
    values = {item["value"] for item in found}

    assert "DL" in types
    assert "ADDRESS" in types
    assert "TN01 20201234567" in values
    assert "12, MG Road, Chennai" in values


def test_detect_address_stops_at_next_label():
    text = "Address: 12 MG Road\nCity: Chennai"
    found = detect_pii(text)
    values = {item["value"] for item in found}

    assert "12 MG Road" in values


def test_detect_additional_pii():
    text = (
        "Passport: K1234567 Voter: ABC1234567 IFSC: HDFC0123456 "
        "Account: 123456789012 DOB: 12/10/1995 IP: 192.168.1.10"
    )
    found = detect_pii(text)
    types = {item["type"] for item in found}
    values = {item["value"] for item in found}

    assert "PASSPORT" in types
    assert "VOTER_ID" in types
    assert "IFSC" in types
    assert "ACCOUNT" in types
    assert "DOB" in types
    assert "IP_ADDRESS" in types
    assert "K1234567" in values
    assert "ABC1234567" in values
    assert "HDFC0123456" in values
    assert "123456789012" in values
    assert "12/10/1995" in values
    assert "192.168.1.10" in values
