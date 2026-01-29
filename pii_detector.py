
import re
import spacy

nlp = spacy.load("en_core_web_sm")

aadhaar_pattern = r"\b\d{4}\s\d{4}\s\d{4}\b"
pan_pattern = r"\b[A-Z]{5}[0-9]{4}[A-Z]\b"
phone_pattern = r"\b[6-9]\d{9}\b"
email_pattern = r"\b[\w\.-]+@[\w\.-]+\.\w+\b"

def detect_pii(text):
    results = []

    results += re.findall(aadhaar_pattern, text)
    results += re.findall(pan_pattern, text)
    results += re.findall(phone_pattern, text)
    results += re.findall(email_pattern, text)

    doc = nlp(text)
    for ent in doc.ents:
        if ent.label_ in ["PERSON", "GPE", "ORG"]:
            results.append(ent.text)

    return list(set(results))
