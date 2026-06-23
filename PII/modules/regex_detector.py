"""
Module 2: Regex-Based Pattern Detection (Rule-Based AI)
Detects structured PII using regular expressions:
- Aadhaar Number
- PAN Card Number
- Phone Numbers
- Email Addresses
- Driving License Numbers
- Voter ID Numbers
- Date of Birth
- PIN Codes
"""

import re


# ============================================================
# PII REGEX PATTERNS FOR INDIAN DOCUMENTS
# ============================================================

PII_PATTERNS = {
    'AADHAAR': {
        'patterns': [
            r'\b\d{4}\s\d{4}\s\d{4}\b',           # 1234 5678 9012
            r'\b\d{4}-\d{4}-\d{4}\b',               # 1234-5678-9012
            r'\b\d{12}\b',                            # 123456789012 (no spaces)
        ],
        'description': 'Aadhaar Card Number (12 digits)',
        'confidence': 0.95
    },
    'PAN': {
        'patterns': [
            r'\b[A-Z]{5}\d{4}[A-Z]\b',              # ABCDE1234F
        ],
        'description': 'PAN Card Number',
        'confidence': 0.98
    },
    'PHONE': {
        'patterns': [
            r'\b[6-9]\d{9}\b',                       # 9876543210
            r'\b\+91[\s-]?[6-9]\d{9}\b',            # +91 9876543210
            r'\b91[\s-]?[6-9]\d{9}\b',              # 91 9876543210
        ],
        'description': 'Indian Phone Number',
        'confidence': 0.90
    },
    'EMAIL': {
        'patterns': [
            r'\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}\b',
        ],
        'description': 'Email Address',
        'confidence': 0.95
    },
    'DRIVING_LICENSE': {
        'patterns': [
            r'\b[A-Z]{2}[\s-]?\d{2}[\s-]?\d{4}[\s-]?\d{7}\b',   # TN 01 2020 0001234
            r'\b[A-Z]{2}\d{13}\b',                                  # TN0120200001234
            r'\b[A-Z]{2}[\s-]?\d{2}[\s-]?\d{11}\b',               # TN 01 20200001234
        ],
        'description': 'Driving License Number',
        'confidence': 0.90
    },
    'VOTER_ID': {
        'patterns': [
            r'\b[A-Z]{3}\d{7}\b',                    # ABC1234567
        ],
        'description': 'Voter ID / EPIC Number',
        'confidence': 0.90
    },
    'DOB': {
        'patterns': [
            r'\b\d{2}[/-]\d{2}[/-]\d{4}\b',         # 15/03/1990 or 15-03-1990
            r'\b\d{4}[/-]\d{2}[/-]\d{2}\b',         # 1990/03/15
            r'\b\d{2}\s(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s\d{4}\b',  # 15 Mar 1990
        ],
        'description': 'Date of Birth',
        'confidence': 0.85
    },
    'PINCODE': {
        'patterns': [
            r'\b[1-9]\d{5}\b',                       # 600001
        ],
        'description': 'Indian PIN Code',
        'confidence': 0.70  # Lower confidence - 6 digits can be other things
    },
}


def detect_pii_regex(text):
    """
    Scan text for all PII patterns using regex.
    
    Args:
        text: OCR extracted text string
        
    Returns:
        List of detected PII items:
        [{type, value, start, end, confidence, description, source}]
    """
    detections = []
    
    for pii_type, config in PII_PATTERNS.items():
        for pattern in config['patterns']:
            matches = re.finditer(pattern, text, re.IGNORECASE if pii_type == 'EMAIL' else 0)
            
            for match in matches:
                value = match.group()
                
                # Validate PINCODE - skip if it's already detected as part of Aadhaar
                if pii_type == 'PINCODE':
                    is_part_of_other = False
                    for det in detections:
                        if det['start'] <= match.start() and det['end'] >= match.end():
                            is_part_of_other = True
                            break
                    if is_part_of_other:
                        continue
                
                # Validate Aadhaar - check it's not a phone number
                if pii_type == 'AADHAAR' and len(value.replace(' ', '').replace('-', '')) == 12:
                    clean = value.replace(' ', '').replace('-', '')
                    if clean[0] in '01':  # Aadhaar doesn't start with 0 or 1
                        continue
                
                detection = {
                    'type': pii_type,
                    'value': value,
                    'start': match.start(),
                    'end': match.end(),
                    'confidence': config['confidence'],
                    'description': config['description'],
                    'source': 'REGEX'
                }
                
                # Avoid duplicate detections at same position
                is_duplicate = False
                for existing in detections:
                    if (existing['start'] == detection['start'] and 
                        existing['end'] == detection['end']):
                        is_duplicate = True
                        break
                
                if not is_duplicate:
                    detections.append(detection)
    
    # Sort by position in text
    detections.sort(key=lambda x: x['start'])
    
    return detections


def get_pattern_summary():
    """Return summary of all patterns for documentation/display."""
    summary = {}
    for pii_type, config in PII_PATTERNS.items():
        summary[pii_type] = {
            'description': config['description'],
            'pattern_count': len(config['patterns']),
            'confidence': config['confidence']
        }
    return summary


# Test function
if __name__ == '__main__':
    sample_text = """
    Government of India
    Name: Rajesh Kumar
    Aadhaar No: 4832 7612 9045
    DOB: 15/03/1990
    PAN: ABCPK1234F
    Phone: 9876543210
    Email: rajesh.kumar@gmail.com
    Address: 45, Anna Nagar, Chennai - 600040
    DL No: TN 01 2020 0001234
    Voter ID: XYZ1234567
    """
    
    results = detect_pii_regex(sample_text)
    print("=== Regex PII Detection Results ===")
    for r in results:
        print(f"  [{r['type']}] '{r['value']}' (confidence: {r['confidence']}) at pos {r['start']}-{r['end']}")
    print(f"\nTotal PII found: {len(results)}")
