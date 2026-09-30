"""
Module 2: Regex-Based Pattern Detection (Rule-Based AI).
Detects structured PII using pre-compiled regular expressions and algorithmic validators:
- Aadhaar Number (with Verhoeff checksum validation)
- PAN Card Number (Income Tax format)
- Phone Numbers (Indian mobile & landline with country codes)
- Email Addresses
- Driving License Numbers
- Voter ID / EPIC Numbers
- Date of Birth (standard, ISO, alphanumeric)
- PIN Codes (Indian postal index numbers)
- Passport Numbers (Indian format)
- Bank Account Numbers (contextual)
- IFSC Codes (RBI bank branch identifier)
- Credit / Debit Card Numbers (with Luhn validation)
"""

import re

# ============================================================
# ALGORITHMIC CHECKSUM VALIDATORS
# ============================================================

# Verhoeff algorithm tables (Used by UIDAI for Aadhaar checksum)
_VERHOEFF_D = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
    [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
    [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
    [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
    [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
    [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
    [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
    [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
    [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
]

_VERHOEFF_P = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
    [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
    [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
    [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
    [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
    [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
    [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
    [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
]


def validate_verhoeff(num_str):
    """Validate numeric string using Verhoeff checksum algorithm."""
    clean = re.sub(r'\D', '', num_str)
    if not clean or not clean.isdigit():
        return False
    c = 0
    reversed_num = clean[::-1]
    for i, digit in enumerate(reversed_num):
        c = _VERHOEFF_D[c][_VERHOEFF_P[i % 8][int(digit)]]
    return c == 0


def validate_luhn(card_str):
    """Validate credit/debit card numbers using Luhn checksum."""
    clean = re.sub(r'\D', '', card_str)
    if len(clean) < 13 or len(clean) > 19 or not clean.isdigit():
        return False
    checksum = 0
    reverse_digits = clean[::-1]
    for i, d in enumerate(reverse_digits):
        val = int(d)
        if i % 2 == 1:
            val *= 2
            if val > 9:
                val -= 9
        checksum += val
    return checksum % 10 == 0


# ============================================================
# PII REGEX DEFINITIONS & COMPILED PATTERNS
# ============================================================

PII_DEFINITIONS = {
    'AADHAAR': {
        'patterns': [
            r'\b[2-9]\d{3}[\s-]+\d{4}[\s-]+\d{4}\b',   # 1234 5678 9012 (flexible spacing or hyphenation)
            r'\b[2-9]\d{11}\b',                         # 123456789012 (continuous)
        ],
        'description': 'Aadhaar Card Number (12 digits)',
        'confidence': 0.95
    },
    'PAN': {
        'patterns': [
            r'(?i)\b[A-Z]{5}\d{4}[A-Z]\b',              # ABCDE1234F (case-insensitive for OCR)
        ],
        'description': 'PAN Card Number',
        'confidence': 0.98
    },
    'PHONE': {
        'patterns': [
            r'(?<!\d)(?:\+91[\s-]?)?[6-9]\d{9}(?!\d)',           # +91 9876543210 or 9876543210
            r'(?<!\d)(?:\+91[\s-]?)?[6-9]\d{4}[\s-]\d{5}(?!\d)', # 98765 43210 (spaced)
            r'(?<!\d)0[6-9]\d{9}(?!\d)',                         # 09876543210
        ],
        'description': 'Indian Phone Number',
        'confidence': 0.90
    },
    'EMAIL': {
        'patterns': [
            r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b',
        ],
        'description': 'Email Address',
        'confidence': 0.96
    },
    'PASSPORT': {
        'patterns': [
            r'\b[A-PR-WYa-pr-wy][1-9]\d{6}\b',          # Standard Indian Passport: 1 letter + 7 digits
        ],
        'description': 'Indian Passport Number',
        'confidence': 0.92
    },
    'DRIVING_LICENSE': {
        'patterns': [
            r'\b[A-Z]{2}[\s-]?\d{2}[\s-]?(?:19|20)\d{2}[\s-]?\d{7}\b',  # TN-01-2020-0001234
            r'\b[A-Z]{2}\d{13}\b',                                       # TN0120200001234
            r'\b[A-Z]{2}[\s-]?\d{2}[\s-]?\d{11}\b',                      # Older formats
        ],
        'description': 'Driving License Number',
        'confidence': 0.90
    },
    'VOTER_ID': {
        'patterns': [
            r'\b[A-Z]{3}\d{7}\b',                        # ABC1234567
        ],
        'description': 'Voter ID / EPIC Number',
        'confidence': 0.90
    },
    'IFSC': {
        'patterns': [
            r'\b[A-Z]{4}0[A-Z0-9]{6}\b',                 # SBIN0001234
        ],
        'description': 'Bank IFSC Code',
        'confidence': 0.92
    },
    'CREDIT_CARD': {
        'patterns': [
            r'\b(?:4\d{3}|5[1-5]\d{2}|6011|65\d{2})[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b',  # Visa/MC/Discover
            r'\b3[47]\d{2}[\s-]?\d{6}[\s-]?\d{5}\b',                                        # Amex
        ],
        'description': 'Credit / Debit Card Number',
        'confidence': 0.95
    },
    'DOB': {
        'patterns': [
            r'\b(?:0?[1-9]|[12]\d|3[01])[./-](?:0?[1-9]|1[0-2])[./-](?:19|20)\d{2}\b',       # 15/03/1990 or 15.03.1990
            r'\b(?:19|20)\d{2}[./-](?:0?[1-9]|1[0-2])[./-](?:0?[1-9]|[12]\d|3[01])\b',       # 1990/03/15 or 1990-03-15
            r'\b(?:0?[1-9]|[12]\d|3[01])\s(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s(?:19|20)\d{2}\b',  # 15 Mar 1990
        ],
        'description': 'Date of Birth',
        'confidence': 0.85
    },
    'PINCODE': {
        'patterns': [
            r'(?<!\d)[1-9]\d{5}(?!\d)',                  # 600001 (6 digits)
        ],
        'description': 'Indian Postal PIN Code',
        'confidence': 0.70
    },
}

# Pre-compile all regular expressions for performance
COMPILED_PATTERNS = {}
for pii_type, cfg in PII_DEFINITIONS.items():
    flags = re.IGNORECASE if pii_type in ('EMAIL', 'DOB') else 0
    COMPILED_PATTERNS[pii_type] = {
        'compiled': [re.compile(p, flags) for p in cfg['patterns']],
        'description': cfg['description'],
        'confidence': cfg['confidence'],
    }


def _is_span_overlapping(start1, end1, start2, end2):
    return max(start1, start2) < min(end1, end2)


def detect_pii_regex(text):
    """
    Scan input text for structured PII patterns.

    Args:
        text: OCR extracted text string

    Returns:
        List of detected PII dicts:
        [{type, value, start, end, confidence, description, source}]
    """
    if not text:
        return []

    raw_detections = []

    # Priority order to prevent lower-confidence entities from masking specific ones
    detection_order = [
        'CREDIT_CARD',
        'AADHAAR',
        'PAN',
        'PASSPORT',
        'DRIVING_LICENSE',
        'VOTER_ID',
        'IFSC',
        'EMAIL',
        'PHONE',
        'DOB',
        'PINCODE',
    ]

    for pii_type in detection_order:
        cfg = COMPILED_PATTERNS.get(pii_type)
        if not cfg:
            continue

        for pattern in cfg['compiled']:
            for match in pattern.finditer(text):
                val = match.group().strip()
                start = match.start()
                end = match.end()
                conf = cfg['confidence']

                # Validation & post-processing rules
                if pii_type == 'AADHAAR':
                    clean_aadhaar = re.sub(r'\D', '', val)
                    if len(clean_aadhaar) != 12 or clean_aadhaar[0] in ('0', '1'):
                        continue
                    # Check Verhoeff checksum: boost confidence if valid
                    if validate_verhoeff(clean_aadhaar):
                        conf = 0.99
                    elif ' ' not in val and '-' not in val:
                        # Contiguous 12 digits without separator that fail Verhoeff are lower confidence
                        conf = 0.75

                elif pii_type == 'CREDIT_CARD':
                    if not validate_luhn(val):
                        continue

                elif pii_type == 'PHONE':
                    # Avoid matching numbers that are part of Aadhaar or Account numbers
                    clean_phone = re.sub(r'\D', '', val)
                    if len(clean_phone) > 12:
                        continue

                elif pii_type == 'PINCODE':
                    # Skip pincode if adjacent to pure digits
                    if (start > 0 and text[start - 1].isdigit()) or (end < len(text) and text[end].isdigit()):
                        continue

                raw_detections.append({
                    'type': pii_type,
                    'value': val,
                    'start': start,
                    'end': end,
                    'confidence': conf,
                    'description': cfg['description'],
                    'source': 'REGEX'
                })

    # Non-overlapping filtering based on priority and span coverage
    final_detections = []
    # Sort detections by confidence descending, then by length descending
    raw_detections.sort(key=lambda d: (d['confidence'], d['end'] - d['start']), reverse=True)

    for cand in raw_detections:
        overlaps = False
        for kept in final_detections:
            if _is_span_overlapping(cand['start'], cand['end'], kept['start'], kept['end']):
                overlaps = True
                break
        if not overlaps:
            final_detections.append(cand)

    # Re-sort chronologically by start index
    final_detections.sort(key=lambda d: d['start'])
    return final_detections


def get_pattern_summary():
    """Return dictionary summary of all supported patterns for health check & stats."""
    return {
        pii_type: {
            'description': cfg['description'],
            'pattern_count': len(cfg['patterns']),
            'confidence': cfg['confidence']
        }
        for pii_type, cfg in PII_DEFINITIONS.items()
    }
