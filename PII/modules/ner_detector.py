"""
Module 3: NER (Named Entity Recognition) - NLP AI.
Uses SpaCy pretrained model to detect contextual PII:
- PERSON names
- Organizations (filtered for document labels)
- Locations and Addresses (GPE, LOC, FAC)
- Dates

Includes contextual filtering to prevent document labels (DOB, PAN) and
institutional headers (Government of India) from being false positives.
"""

import logging
import spacy
import warnings
warnings.filterwarnings('ignore')

logger = logging.getLogger('ner_detector')

# Load SpaCy English model
try:
    nlp = spacy.load('en_core_web_sm')
except OSError:
    logger.warning("SpaCy model 'en_core_web_sm' not found. Run: python -m spacy download en_core_web_sm")
    nlp = None

# Mapping SpaCy entity labels to PII categories
ENTITY_MAP = {
    'PERSON': 'PERSON_NAME',
    'ORG': 'ORGANIZATION',
    'GPE': 'LOCATION',
    'LOC': 'LOCATION',
    'DATE': 'DATE',
    'FAC': 'ADDRESS',
}

TARGET_LABELS = set(ENTITY_MAP.keys())

# Non-PII form labels and institutional headers that should NOT be redacted
LABEL_BLACKLIST = {
    'dob', 'pan', 'aadhaar', 'aadhar', 'name', 'father', 'mother', 'husband',
    'gender', 'sex', 'male', 'female', 'signature', 'photo', 'address',
    'phone', 'mobile', 'email', 'card', 'date', 'issue', 'valid', 'expiry',
    'year', 'no', 'number', 'pin', 'pincode', 'dist', 'district', 'state'
}

INSTITUTIONAL_HEADERS = {
    'government of india',
    'govt of india',
    'income tax department',
    'unique identification authority of india',
    'uidai',
    'election commission of india',
    'republic of india',
    'transport department',
    'ministry of road transport and highways',
    'driving licence',
    'driving license',
    'identity card',
    'voter identity card',
    'passport sewa'
}


def detect_pii_ner(text):
    """
    Detect contextual PII using SpaCy NER pipeline with label/header suppression.

    Args:
        text: OCR extracted text string

    Returns:
        List of detected PII items:
        [{type, value, start, end, confidence, description, source}]
    """
    if not text or nlp is None:
        return []

    doc = nlp(text)
    detections = []

    for ent in doc.ents:
        if ent.label_ not in TARGET_LABELS:
            continue

        raw_val = ent.text
        # Entities should not span across line breaks on structured documents
        if '\n' in raw_val:
            raw_val = raw_val.split('\n')[0]

        clean_val = raw_val.strip(' \t\r\n:-,')

        # Skip ultra-short or empty entities
        if len(clean_val) < 2:
            continue

        lower_clean = clean_val.lower()

        # Suppress document labels that SpaCy frequently misclassifies as ORG
        if lower_clean in LABEL_BLACKLIST:
            continue

        # Suppress government headers
        if lower_clean in INSTITUTIONAL_HEADERS:
            continue

        # Skip purely numeric strings (handled with higher accuracy by regex)
        if clean_val.replace(' ', '').replace('-', '').replace('/', '').isdigit():
            continue

        # Re-locate exact start/end within the original text
        exact_start = text.find(clean_val, ent.start_char)
        if exact_start == -1:
            exact_start = ent.start_char
        exact_end = exact_start + len(clean_val)

        pii_type = ENTITY_MAP[ent.label_]

        detections.append({
            'type': pii_type,
            'value': clean_val,
            'start': exact_start,
            'end': exact_end,
            'confidence': 0.85,
            'description': f'Contextual NER detection ({ent.label_})',
            'source': 'NER'
        })

    detections.sort(key=lambda x: x['start'])
    return detections


def get_ner_model_info():
    """Return runtime metadata about the loaded SpaCy model."""
    if nlp is None:
        return {'status': 'NOT LOADED', 'model': None}

    return {
        'status': 'LOADED',
        'model': nlp.meta.get('name', 'core_web_sm'),
        'version': nlp.meta.get('version', 'unknown'),
        'pipeline': nlp.pipe_names,
        'entity_labels': list(nlp.get_pipe('ner').labels) if 'ner' in nlp.pipe_names else []
    }
