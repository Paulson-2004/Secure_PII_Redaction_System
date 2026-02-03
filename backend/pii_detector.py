import re
from typing import Optional

import spacy

from config import CONFIG


def _load_model() -> Optional["spacy.language.Language"]:
    try:
        return spacy.load(CONFIG.ner_model_path)
    except Exception:
        try:
            return spacy.load("en_core_web_sm")
        except Exception:
            return None


_NLP = _load_model()


def _normalize_address(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


_PATTERNS = [
    ("AADHAAR", re.compile(r"\b\d{4}\s\d{4}\s\d{4}\b"), None),
    ("PAN", re.compile(r"\b[A-Z]{5}[0-9]{4}[A-Z]\b"), None),
    ("PHONE", re.compile(r"\b[6-9]\d{9}\b"), None),
    ("EMAIL", re.compile(r"\b[\w\.-]+@[\w\.-]+\.\w+\b"), None),
    ("DL", re.compile(r"\b[A-Z]{2}\d{2}\s?\d{11}\b"), None),
    ("PASSPORT", re.compile(r"\b[A-Z][0-9]{7}\b"), None),
    ("VOTER_ID", re.compile(r"\b[A-Z]{3}[0-9]{7}\b"), None),
    ("ACCOUNT", re.compile(r"\b[0-9]{9,18}\b"), None),
    ("IFSC", re.compile(r"\b[A-Z]{4}0[0-9A-Z]{6}\b"), None),
    ("IP_ADDRESS", re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b"), None),
    ("DOB", re.compile(r"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"), None),
    (
        "ADDRESS",
        re.compile(
            r"\b(?:Address|Addr)[:\-]\s*([A-Za-z0-9#.,\-\/\s]{10,200}?)(?=\n\s*[A-Za-z ]{2,20}[:\-]|$)",
            re.DOTALL,
        ),
        1,
    ),
]


def detect_pii(text):
    pii_list = []

    for pii_type, pattern, group_index in _PATTERNS:
        for match in pattern.finditer(text):
            if group_index:
                value = _normalize_address(match.group(group_index))
                start = match.start(group_index)
                end = match.end(group_index)
            else:
                value = match.group(0)
                start = match.start()
                end = match.end()

            pii_list.append(
                {
                    "type": pii_type,
                    "value": value,
                    "start": start,
                    "end": end,
                    "source": "regex",
                }
            )

    # NER detection (best-effort)
    if _NLP is not None:
        doc = _NLP(text)
        for ent in doc.ents:
            if ent.label_ == "PERSON":
                pii_list.append(
                    {
                        "type": "PERSON",
                        "value": ent.text,
                        "start": ent.start_char,
                        "end": ent.end_char,
                        "source": "ner",
                    }
                )

    return pii_list
