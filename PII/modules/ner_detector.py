"""
Module 3: NER (Named Entity Recognition) - NLP AI
Uses SpaCy pretrained model to detect contextual PII:
- PERSON names
- Organizations (ORG)
- Locations / Addresses (GPE, LOC)
- Dates

These are entities that regex cannot reliably detect
because they don't follow fixed patterns.
"""

import spacy
import warnings
warnings.filterwarnings('ignore')


# Load SpaCy English NER model
try:
    nlp = spacy.load('en_core_web_sm')
except OSError:
    print("SpaCy model not found. Run: python -m spacy download en_core_web_sm")
    nlp = None


# Map SpaCy entity labels to PII types
ENTITY_MAP = {
    'PERSON': 'PERSON_NAME',
    'ORG': 'ORGANIZATION',
    'GPE': 'LOCATION',        # Geopolitical entity (cities, countries)
    'LOC': 'LOCATION',        # Non-GPE locations
    'DATE': 'DATE',
    'FAC': 'ADDRESS',         # Facilities (buildings, airports)
}

# Entity labels we want to detect as PII
TARGET_LABELS = set(ENTITY_MAP.keys())


def detect_pii_ner(text):
    """
    Detect contextual PII using SpaCy NER model.
    
    Args:
        text: OCR extracted text string
        
    Returns:
        List of detected PII items:
        [{type, value, start, end, confidence, description, source}]
    """
    if nlp is None:
        return []
    
    # Process text through NER pipeline
    doc = nlp(text)
    
    detections = []
    
    for ent in doc.ents:
        if ent.label_ in TARGET_LABELS:
            pii_type = ENTITY_MAP[ent.label_]
            value = ent.text.strip()
            
            # Skip very short entities (likely noise)
            if len(value) < 2:
                continue
            
            # Skip purely numeric entities (handled by regex)
            if value.replace(' ', '').replace('-', '').isdigit():
                continue
            
            detection = {
                'type': pii_type,
                'value': value,
                'start': ent.start_char,
                'end': ent.end_char,
                'confidence': 0.85,  # SpaCy pretrained model confidence
                'description': f'NER detected {ent.label_} entity',
                'source': 'NER'
            }
            
            detections.append(detection)
    
    # Sort by position
    detections.sort(key=lambda x: x['start'])
    
    return detections


def get_ner_model_info():
    """Return information about the loaded NER model."""
    if nlp is None:
        return {'status': 'NOT LOADED', 'model': None}
    
    return {
        'status': 'LOADED',
        'model': nlp.meta.get('name', 'unknown'),
        'version': nlp.meta.get('version', 'unknown'),
        'pipeline': nlp.pipe_names,
        'entity_labels': list(nlp.get_pipe('ner').labels) if 'ner' in nlp.pipe_names else []
    }


# Test function
if __name__ == '__main__':
    sample_text = """
    Government of India
    Name: Rajesh Kumar
    Son of: Suresh Kumar
    Address: 45, Anna Nagar, Chennai, Tamil Nadu
    Organization: Mount Zion College of Engineering
    Date of Birth: 15 March 1990
    Place: Pudukkottai District
    """
    
    results = detect_pii_ner(sample_text)
    print("=== NER PII Detection Results ===")
    for r in results:
        print(f"  [{r['type']}] '{r['value']}' (confidence: {r['confidence']}) at pos {r['start']}-{r['end']}")
    print(f"\nTotal NER entities found: {len(results)}")
    
    print("\n=== NER Model Info ===")
    info = get_ner_model_info()
    for k, v in info.items():
        print(f"  {k}: {v}")
