"""
Module 6: Redaction Intelligence Engine
Applies redaction decisions to both text and images.

Types of redaction:
- FULL_REDACT  → Replace with █████ (text) / black box (image)
- PARTIAL_MASK → Replace with ****1234 (text) / partial blur (image)
- KEEP         → No modification

Uses OCR bounding boxes to locate PII regions on images for visual redaction.
"""

import cv2
import numpy as np
import re
import os


def _apply_text_redaction(text, detection):
    """Apply redaction to a single PII item in text."""
    value = detection['value']
    decision = detection.get('decision', 'FULL_REDACT')
    mask_format = detection.get('mask_format', None)
    
    if decision == 'KEEP':
        return text
    
    if decision == 'FULL_REDACT':
        replacement = '█' * len(value)
        return text.replace(value, replacement, 1)
    
    if decision == 'PARTIAL_MASK':
        pii_type = detection['type']
        
        if pii_type == 'PHONE':
            # Show last 4 digits: XXXXXX3210
            clean = value.replace(' ', '').replace('-', '').replace('+91', '')
            if len(clean) >= 4:
                masked = 'X' * (len(clean) - 4) + clean[-4:]
            else:
                masked = 'X' * len(clean)
            return text.replace(value, masked, 1)
        
        elif pii_type == 'EMAIL':
            # Show domain only: ****@gmail.com
            parts = value.split('@')
            if len(parts) == 2:
                masked = '****@' + parts[1]
            else:
                masked = '█' * len(value)
            return text.replace(value, masked, 1)
        
        elif pii_type == 'PERSON_NAME':
            # Show first character: R****
            words = value.split()
            masked_words = []
            for word in words:
                if len(word) > 1:
                    masked_words.append(word[0] + '*' * (len(word) - 1))
                else:
                    masked_words.append(word)
            masked = ' '.join(masked_words)
            return text.replace(value, masked, 1)
        
        elif pii_type in ('DATE', 'DOB'):
            # Replace with XX/XX/XXXX
            masked = re.sub(r'\d', 'X', value)
            return text.replace(value, masked, 1)
        
        else:
            # Default partial: show last 4 chars
            if len(value) > 4:
                masked = '*' * (len(value) - 4) + value[-4:]
            else:
                masked = '█' * len(value)
            return text.replace(value, masked, 1)
    
    # Default: full redact
    return text.replace(value, '█' * len(value), 1)


def redact_text(text, detections):
    """
    Apply all redaction decisions to extracted text.
    
    Args:
        text: Original OCR text
        detections: List of detections with decisions from RAG engine
        
    Returns:
        Redacted text string
    """
    redacted_text = text
    
    # Sort by position (reverse) to avoid offset issues
    sorted_dets = sorted(detections, key=lambda x: x.get('start', 0), reverse=True)
    
    for det in sorted_dets:
        redacted_text = _apply_text_redaction(redacted_text, det)
    
    return redacted_text


def _find_word_boxes_for_pii(pii_value, ocr_words):
    """
    Find OCR bounding boxes that match a PII value.
    Returns list of bounding boxes to redact on the image.
    """
    pii_tokens = pii_value.lower().split()
    matching_boxes = []
    
    for i, word in enumerate(ocr_words):
        word_text = word['text'].lower().strip()
        
        # Check if this word is part of the PII value
        if word_text in pii_tokens or pii_value.lower().find(word_text) >= 0:
            matching_boxes.append({
                'x': word['x'],
                'y': word['y'],
                'w': word['w'],
                'h': word['h']
            })
        
        # Also check for combined tokens (e.g., "4832" in "4832 7612 9045")
        for token in pii_tokens:
            if token == word_text:
                if {'x': word['x'], 'y': word['y'], 'w': word['w'], 'h': word['h']} not in matching_boxes:
                    matching_boxes.append({
                        'x': word['x'],
                        'y': word['y'],
                        'w': word['w'],
                        'h': word['h']
                    })
    
    return matching_boxes


def redact_image(image, detections, ocr_words):
    """
    Apply visual redaction to image using OCR bounding boxes.
    
    Args:
        image: OpenCV image (numpy array)
        detections: List of detections with decisions
        ocr_words: List of OCR words with bounding boxes
        
    Returns:
        Redacted image (numpy array)
    """
    redacted_img = image.copy()
    
    for det in detections:
        decision = det.get('decision', 'FULL_REDACT')
        
        if decision == 'KEEP':
            continue
        
        # Find matching bounding boxes
        boxes = _find_word_boxes_for_pii(det['value'], ocr_words)
        
        if not boxes:
            continue
        
        for box in boxes:
            x, y, w, h = box['x'], box['y'], box['w'], box['h']
            
            # Add small padding
            padding = 3
            x = max(0, x - padding)
            y = max(0, y - padding)
            w = w + 2 * padding
            h = h + 2 * padding
            
            if decision == 'FULL_REDACT':
                # Draw black filled rectangle
                cv2.rectangle(redacted_img, (x, y), (x + w, y + h), (0, 0, 0), -1)
            
            elif decision == 'PARTIAL_MASK':
                # Apply blur effect for partial masking
                roi = redacted_img[y:y+h, x:x+w]
                if roi.size > 0:
                    blurred = cv2.GaussianBlur(roi, (23, 23), 30)
                    redacted_img[y:y+h, x:x+w] = blurred
    
    return redacted_img


def save_redacted_image(redacted_img, output_path):
    """Save redacted image to disk."""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    cv2.imwrite(output_path, redacted_img)
    return output_path


def process_redaction(original_text, original_image, ocr_words, detections, output_image_path):
    """
    Main redaction function: Process both text and image redaction.
    
    Args:
        original_text: OCR extracted text
        original_image: OpenCV image
        ocr_words: OCR words with bounding boxes
        detections: Enriched detections with decisions
        output_image_path: Path to save redacted image
        
    Returns:
        Dict with redacted text, redacted image path, and summary
    """
    # Text redaction
    redacted_text = redact_text(original_text, detections)
    
    # Image redaction
    redacted_image = redact_image(original_image, detections, ocr_words)
    
    # Save redacted image
    save_redacted_image(redacted_image, output_image_path)
    
    # Build summary
    full_redacted = sum(1 for d in detections if d.get('decision') == 'FULL_REDACT')
    partial_masked = sum(1 for d in detections if d.get('decision') == 'PARTIAL_MASK')
    kept = sum(1 for d in detections if d.get('decision') == 'KEEP')
    
    return {
        'redacted_text': redacted_text,
        'redacted_image_path': output_image_path,
        'summary': {
            'total_pii': len(detections),
            'full_redacted': full_redacted,
            'partial_masked': partial_masked,
            'kept': kept
        }
    }


# Test function
if __name__ == '__main__':
    sample_text = """Name: Rajesh Kumar
Aadhaar No: 4832 7612 9045
PAN: ABCPK1234F
Phone: 9876543210
Email: rajesh@gmail.com"""
    
    test_detections = [
        {'type': 'PERSON_NAME', 'value': 'Rajesh Kumar', 'decision': 'PARTIAL_MASK'},
        {'type': 'AADHAAR', 'value': '4832 7612 9045', 'decision': 'FULL_REDACT'},
        {'type': 'PAN', 'value': 'ABCPK1234F', 'decision': 'FULL_REDACT'},
        {'type': 'PHONE', 'value': '9876543210', 'decision': 'PARTIAL_MASK'},
        {'type': 'EMAIL', 'value': 'rajesh@gmail.com', 'decision': 'PARTIAL_MASK'},
    ]
    
    result = redact_text(sample_text, test_detections)
    print("=== Original Text ===")
    print(sample_text)
    print("\n=== Redacted Text ===")
    print(result)
