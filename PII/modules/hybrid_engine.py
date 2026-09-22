"""
Module 4: Hybrid AI Detection Engine.
Combines Rule-Based (Regex) + ML-Based (NER) detection results.

Key Principles:
- Semantic Compatibility: Confidence boosting only occurs when regex and NER agree on compatible entity types.
- Precision Prioritization: Structured regex detections take precedence over unstructured NER tokens for official IDs.
- Synchronized Spans: Exact start, end, and text value remain strictly in sync.
"""

from modules.regex_detector import detect_pii_regex
from modules.ner_detector import detect_pii_ner

COMPATIBLE_TYPES = {
    ('DOB', 'DATE'),
    ('DATE', 'DOB'),
    ('PINCODE', 'LOCATION'),
    ('PINCODE', 'ADDRESS'),
}


def _spans_overlap(s1, e1, s2, e2):
    """Check if two half-open spans [s1, e1) and [s2, e2) intersect."""
    return max(s1, s2) < min(e1, e2)


def _are_types_compatible(regex_type, ner_type):
    """Return True if regex and NER types are semantically compatible."""
    if regex_type == ner_type:
        return True
    return (regex_type, ner_type) in COMPATIBLE_TYPES


def _merge_detections(text, regex_results, ner_results):
    """
    Merge regex and NER results with semantic deduplication and span synchronization.
    """
    merged = []
    used_ner = set()

    # Step 1: Process high-precision regex results
    for reg in regex_results:
        matched_ner = None
        overlapping_ner_indices = []

        for i, ner in enumerate(ner_results):
            if _spans_overlap(reg['start'], reg['end'], ner['start'], ner['end']):
                overlapping_ner_indices.append(i)
                if _are_types_compatible(reg['type'], ner['type']) and matched_ner is None:
                    matched_ner = ner

        # Mark all overlapping NER entities as consumed so sub-tokens aren't duplicated
        for idx in overlapping_ner_indices:
            used_ner.add(idx)

        if matched_ner:
            # Semantic agreement between Regex and NER
            new_start = min(reg['start'], matched_ner['start'])
            new_end = max(reg['end'], matched_ner['end'])
            merged.append({
                'type': reg['type'],
                'value': text[new_start:new_end],
                'start': new_start,
                'end': new_end,
                'confidence': min(1.0, round(reg['confidence'] + 0.05, 3)),
                'description': f"{reg['description']} (verified by contextual NER)",
                'source': 'HYBRID',
                'regex_match': True,
                'ner_match': True
            })
        else:
            merged.append({
                **reg,
                'source': 'REGEX',
                'regex_match': True,
                'ner_match': False
            })

    # Step 2: Add remaining non-overlapping contextual NER detections
    for i, ner in enumerate(ner_results):
        if i in used_ner:
            continue

        # Double check overlap against all merged entities
        overlaps = any(
            _spans_overlap(ner['start'], ner['end'], m['start'], m['end'])
            for m in merged
        )
        if not overlaps:
            merged.append({
                **ner,
                'source': 'NER',
                'regex_match': False,
                'ner_match': True
            })

    # Step 3: Sort chronologically by start offset
    merged.sort(key=lambda d: d['start'])
    return merged


def detect_pii_hybrid(text):
    """
    Main hybrid detection entrypoint.
    Executes regex and NER pipelines, then merges results with conflict resolution.

    Args:
        text: OCR extracted text string

    Returns:
        dict: {
            'detections': list of merged detections,
            'stats': dict of metrics and counts
        }
    """
    if not text:
        return {
            'detections': [],
            'stats': {
                'total_pii_found': 0,
                'regex_detections': 0,
                'ner_detections': 0,
                'hybrid_confirmed': 0,
                'regex_only': 0,
                'ner_only': 0,
                'average_confidence': 0.0
            }
        }

    regex_results = detect_pii_regex(text)
    ner_results = detect_pii_ner(text)
    merged = _merge_detections(text, regex_results, ner_results)

    hybrid_count = sum(1 for d in merged if d.get('source') == 'HYBRID')
    regex_only = sum(1 for d in merged if d.get('source') == 'REGEX')
    ner_only = sum(1 for d in merged if d.get('source') == 'NER')
    avg_conf = sum(d['confidence'] for d in merged) / len(merged) if merged else 0.0

    return {
        'detections': merged,
        'stats': {
            'total_pii_found': len(merged),
            'regex_detections': len(regex_results),
            'ner_detections': len(ner_results),
            'hybrid_confirmed': hybrid_count,
            'regex_only': regex_only,
            'ner_only': ner_only,
            'average_confidence': round(avg_conf, 3)
        }
    }
