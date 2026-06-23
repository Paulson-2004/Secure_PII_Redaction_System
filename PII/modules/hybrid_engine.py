"""
Module 4: Hybrid AI Detection Engine
Combines Rule-Based (Regex) + ML-Based (NER) detection results.

Key AI Concepts:
- Result fusion: Merge detections from multiple AI sources
- Confidence boosting: Higher confidence when both systems agree
- Overlap resolution: Handle cases where regex and NER detect same text
- Deduplication: Remove redundant detections
"""

from modules.regex_detector import detect_pii_regex
from modules.ner_detector import detect_pii_ner


def _ranges_overlap(start1, end1, start2, end2):
    """Check if two text ranges overlap."""
    return start1 < end2 and start2 < end1


def _merge_detections(regex_results, ner_results):
    """
    Merge regex and NER results with intelligent deduplication.
    
    Rules:
    1. If both detect same span → boost confidence to 1.0
    2. If regex detects but NER doesn't → keep regex result
    3. If NER detects but regex doesn't → keep NER result
    4. Overlapping detections → keep higher confidence one
    """
    merged = []
    used_ner = set()
    
    # Process regex results first (higher precision for structured data)
    for regex_det in regex_results:
        matched_ner = None
        
        for i, ner_det in enumerate(ner_results):
            if i in used_ner:
                continue
            
            # Check if they overlap
            if _ranges_overlap(regex_det['start'], regex_det['end'],
                             ner_det['start'], ner_det['end']):
                matched_ner = ner_det
                used_ner.add(i)
                break
        
        if matched_ner:
            # Both detected → confidence boost
            merged_det = {
                'type': regex_det['type'],  # Prefer regex type (more specific)
                'value': regex_det['value'],
                'start': min(regex_det['start'], matched_ner['start']),
                'end': max(regex_det['end'], matched_ner['end']),
                'confidence': 1.0,  # Maximum confidence when both agree
                'description': f"{regex_det['description']} (confirmed by NER)",
                'source': 'HYBRID',
                'regex_match': True,
                'ner_match': True
            }
        else:
            # Only regex detected
            merged_det = {
                **regex_det,
                'source': 'REGEX',
                'regex_match': True,
                'ner_match': False
            }
        
        merged.append(merged_det)
    
    # Add remaining NER-only detections
    for i, ner_det in enumerate(ner_results):
        if i not in used_ner:
            # Check if it overlaps with any already-merged detection
            overlaps = False
            for m in merged:
                if _ranges_overlap(ner_det['start'], ner_det['end'],
                                 m['start'], m['end']):
                    overlaps = True
                    break
            
            if not overlaps:
                merged.append({
                    **ner_det,
                    'source': 'NER',
                    'regex_match': False,
                    'ner_match': True
                })
    
    # Sort by position
    merged.sort(key=lambda x: x['start'])
    
    return merged


def detect_pii_hybrid(text):
    """
    Main hybrid detection function.
    Runs both Regex and NER, then merges results.
    
    Args:
        text: OCR extracted text
        
    Returns:
        dict with:
        - detections: merged PII list
        - stats: detection statistics
        - regex_count: number from regex
        - ner_count: number from NER
        - hybrid_count: number confirmed by both
    """
    # Run both detection engines
    regex_results = detect_pii_regex(text)
    ner_results = detect_pii_ner(text)
    
    # Merge results
    merged = _merge_detections(regex_results, ner_results)
    
    # Calculate statistics
    hybrid_count = sum(1 for d in merged if d.get('source') == 'HYBRID')
    regex_only = sum(1 for d in merged if d.get('source') == 'REGEX')
    ner_only = sum(1 for d in merged if d.get('source') == 'NER')
    
    avg_confidence = sum(d['confidence'] for d in merged) / len(merged) if merged else 0
    
    return {
        'detections': merged,
        'stats': {
            'total_pii_found': len(merged),
            'regex_detections': len(regex_results),
            'ner_detections': len(ner_results),
            'hybrid_confirmed': hybrid_count,
            'regex_only': regex_only,
            'ner_only': ner_only,
            'average_confidence': round(avg_confidence, 3)
        }
    }


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
    Address: 45, Anna Nagar, Chennai, Tamil Nadu - 600040
    Organization: Mount Zion College
    DL No: TN 01 2020 0001234
    Voter ID: XYZ1234567
    """
    
    result = detect_pii_hybrid(sample_text)
    
    print("=== Hybrid Detection Results ===")
    for d in result['detections']:
        icon = "🔗" if d['source'] == 'HYBRID' else ("📏" if d['source'] == 'REGEX' else "🧠")
        print(f"  {icon} [{d['type']}] '{d['value']}' conf={d['confidence']} src={d['source']}")
    
    print(f"\n=== Statistics ===")
    for k, v in result['stats'].items():
        print(f"  {k}: {v}")
