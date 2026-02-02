import re
import spacy

nlp = spacy.load("custom_pii_model")

def detect_pii(text):
    pii_list = []

    # Regex detection
    patterns = {
        "AADHAAR": r"\b\d{4}\s\d{4}\s\d{4}\b",
        "PAN": r"\b[A-Z]{5}[0-9]{4}[A-Z]\b",
        "PHONE": r"\b[6-9]\d{9}\b",
        "EMAIL": r"\b[\w\.-]+@[\w\.-]+\.\w+\b"
    }

    for pii_type, pattern in patterns.items():
        matches = re.findall(pattern, text)
        for match in matches:
            pii_list.append({"type": pii_type, "value": match})

    # NER detection
    doc = nlp(text)
    for ent in doc.ents:
        if ent.label_ == "PERSON":
            pii_list.append({"type": "PERSON", "value": ent.text})

    return pii_list
