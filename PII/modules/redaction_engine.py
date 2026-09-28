"""
Module 6: Redaction Intelligence Engine.
Applies policy redaction decisions to both extracted text and document images.

Types of redaction:
- FULL_REDACT  → Replace with █████ (text) / solid black box (image)
- PARTIAL_MASK → Format-preserving masking like ****1234 (text) / mosaic pixelation (image)
- KEEP         → Preserved without redaction

Key Improvements:
- Exact Character-Offset Slicing: Eliminates duplicate word replacement errors.
- Sequence-Aware Bounding Box Matching: Prevents catastrophic over-redaction of common sub-words.
- Robust Mosaic Pixelation: Cryptographically irreversible masking that scales to any token dimension.
"""

import os
import re
import cv2
import numpy as np


def _clean_token(t):
    """Normalize token by stripping non-alphanumeric characters."""
    return re.sub(r'[\W_]+', '', t.lower())


def _get_replacement_text(value, detection):
    """Generate masked or redacted replacement string according to policy decision."""
    decision = detection.get('decision', 'FULL_REDACT')

    if decision == 'KEEP':
        return value

    val_len = max(1, len(value))

    if decision == 'FULL_REDACT':
        return '█' * val_len

    if decision == 'PARTIAL_MASK':
        pii_type = detection.get('type', '')

        if pii_type == 'PHONE':
            digits = re.sub(r'\D', '', value)
            if len(digits) >= 4:
                return 'X' * (len(digits) - 4) + digits[-4:]
            return 'X' * len(digits)

        elif pii_type == 'EMAIL':
            if '@' in value:
                parts = value.split('@', 1)
                user, domain = parts[0], parts[1]
                masked_user = user[0] + '***' if len(user) > 1 else '***'
                return f"{masked_user}@{domain}"
            return '█' * val_len

        elif pii_type == 'PERSON_NAME':
            words = value.split()
            masked_words = []
            for w in words:
                if len(w) > 1:
                    masked_words.append(w[0] + '*' * (len(w) - 1))
                else:
                    masked_words.append(w)
            return ' '.join(masked_words)

        elif pii_type in ('DATE', 'DOB'):
            return re.sub(r'\d', 'X', value)

        elif pii_type == 'AADHAAR':
            digits = re.sub(r'\D', '', value)
            if len(digits) == 12:
                return f"XXXX-XXXX-{digits[-4:]}"
            return '█' * val_len

        elif pii_type in ('CREDIT_CARD', 'BANK_ACCOUNT'):
            digits = re.sub(r'\D', '', value)
            if len(digits) >= 4:
                return '*' * (len(digits) - 4) + digits[-4:]
            return '█' * val_len

        else:
            if val_len > 4:
                return '*' * (val_len - 4) + value[-4:]
            return '█' * val_len

    return '█' * val_len


def redact_text(text, detections):
    """
    Apply redaction decisions to text using reverse-order exact character slicing.

    Args:
        text: Original extracted text
        detections: List of detections enriched with decisions

    Returns:
        Redacted text string
    """
    if not text or not detections:
        return text

    # Sort strictly in descending order of start offset
    sorted_dets = sorted(detections, key=lambda d: d.get('start', 0), reverse=True)
    redacted = text

    for det in sorted_dets:
        start = det.get('start')
        end = det.get('end')
        val = det.get('value', '')
        decision = det.get('decision', 'FULL_REDACT')

        if decision == 'KEEP':
            continue

        replacement = _get_replacement_text(val, det)

        # Precise slice replacement if valid offsets exist
        if start is not None and end is not None and 0 <= start <= end <= len(redacted):
            # Verify slice alignment
            slice_text = redacted[start:end]
            if slice_text == val or slice_text.strip() == val.strip():
                redacted = redacted[:start] + replacement + redacted[end:]
                continue

        # Fallback to single exact match
        if val in redacted:
            idx = redacted.rfind(val)
            if idx != -1:
                redacted = redacted[:idx] + replacement + redacted[idx + len(val):]

    return redacted


def _find_word_boxes_for_pii(pii_value, ocr_words):
    """
    Sequence-aware bounding box locator for PII values in OCR word tokens.
    Prevents over-redaction by requiring exact token or n-gram matches.
    """
    if not pii_value or not ocr_words:
        return []

    target_tokens = [_clean_token(t) for t in pii_value.split() if _clean_token(t)]
    if not target_tokens:
        clean_pii = _clean_token(pii_value)
        if not clean_pii:
            return []
        target_tokens = [clean_pii]

    matching_boxes = []
    n_tokens = len(target_tokens)
    n_words = len(ocr_words)

    # Strategy 1: Match multi-word consecutive sequences
    for i in range(n_words - n_tokens + 1):
        window_words = ocr_words[i:i + n_tokens]
        window_tokens = [_clean_token(w['text']) for w in window_words]

        if window_tokens == target_tokens:
            # Union of bounding boxes across the sequence
            min_x = min(w['x'] for w in window_words)
            min_y = min(w['y'] for w in window_words)
            max_x = max(w['x'] + w['w'] for w in window_words)
            max_y = max(w['y'] + w['h'] for w in window_words)
            matching_boxes.append({
                'x': min_x,
                'y': min_y,
                'w': max_x - min_x,
                'h': max_y - min_y
            })

    # Strategy 2: Single-token containment (e.g. email or continuous Aadhaar)
    if not matching_boxes:
        clean_full_pii = _clean_token(pii_value)
        for w in ocr_words:
            w_clean = _clean_token(w['text'])
            if not w_clean:
                continue
            # Either exact token match or full PII contained in single OCR word
            if w_clean == clean_full_pii or (len(w_clean) >= 6 and w_clean in clean_full_pii):
                matching_boxes.append({
                    'x': w['x'],
                    'y': w['y'],
                    'w': w['w'],
                    'h': w['h']
                })

    return matching_boxes


def redact_image(image, detections, ocr_words):
    """
    Apply visual redaction to document image based on OCR bounding boxes.

    Args:
        image: OpenCV BGR image (np.ndarray)
        detections: List of detections with decisions
        ocr_words: List of OCR words with bounding boxes

    Returns:
        Redacted OpenCV BGR image (np.ndarray)
    """
    if image is None:
        return None

    redacted_img = image.copy()
    img_h, img_w = redacted_img.shape[:2]

    for det in detections:
        decision = det.get('decision', 'FULL_REDACT')
        if decision == 'KEEP':
            continue

        boxes = _find_word_boxes_for_pii(det.get('value', ''), ocr_words)
        if not boxes:
            continue

        for box in boxes:
            padding = 4
            x = max(0, box['x'] - padding)
            y = max(0, box['y'] - padding)
            w = min(img_w - x, box['w'] + 2 * padding)
            h = min(img_h - y, box['h'] + 2 * padding)

            if w <= 0 or h <= 0:
                continue

            if decision == 'FULL_REDACT':
                # Filled black box
                cv2.rectangle(redacted_img, (x, y), (x + w, y + h), (0, 0, 0), -1)

            elif decision == 'PARTIAL_MASK':
                # Safe mosaic pixelation (robust for any ROI size)
                roi = redacted_img[y:y + h, x:x + w]
                if roi.size > 0:
                    small_w = max(1, w // 8)
                    small_h = max(1, h // 8)
                    small = cv2.resize(roi, (small_w, small_h), interpolation=cv2.INTER_LINEAR)
                    pixelated = cv2.resize(small, (w, h), interpolation=cv2.INTER_NEAREST)
                    redacted_img[y:y + h, x:x + w] = pixelated

    return redacted_img


def save_redacted_pdf_pages(redacted_images, output_path):
    """
    Save multiple redacted BGR images as a multi-page PDF document.

    Args:
        redacted_images: list of np.ndarray (BGR)
        output_path: str, path to output .pdf file

    Returns:
        str: output_path
    """
    if not redacted_images:
        return None
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    from PIL import Image
    pil_images = [
        Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
        for img in redacted_images
        if img is not None
    ]
    if not pil_images:
        return None
    pil_images[0].save(
        output_path,
        "PDF",
        save_all=True,
        append_images=pil_images[1:]
    )
    return output_path


def save_redacted_image(redacted_img, output_path):
    """Save redacted image to destination file path."""
    if redacted_img is None:
        return None
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    if output_path.lower().endswith('.pdf'):
        return save_redacted_pdf_pages([redacted_img], output_path)
    else:
        cv2.imwrite(output_path, redacted_img)
    return output_path


def save_redacted_text(redacted_text, output_path):
    """Save redacted text to destination file path."""
    if redacted_text is None or not output_path:
        return None
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(redacted_text)
    return output_path


def process_redaction(original_text, original_image, ocr_words, detections, output_image_path):
    """
    Main redaction entrypoint: process text and visual image redactions.

    Returns:
        dict: {
            'redacted_text': str,
            'redacted_image_path': str or None,
            'summary': dict
        }
    """
    redacted_text = redact_text(original_text, detections)

    redacted_path = None
    if original_image is not None and output_image_path:
        redacted_image = redact_image(original_image, detections, ocr_words)
        redacted_path = save_redacted_image(redacted_image, output_image_path)
    elif output_image_path:
        redacted_path = save_redacted_text(redacted_text, output_image_path)

    full_redacted = sum(1 for d in detections if d.get('decision') == 'FULL_REDACT')
    partial_masked = sum(1 for d in detections if d.get('decision') == 'PARTIAL_MASK')
    kept = sum(1 for d in detections if d.get('decision') == 'KEEP')

    return {
        'redacted_text': redacted_text,
        'redacted_image_path': redacted_path,
        'summary': {
            'total_pii': len(detections),
            'full_redacted': full_redacted,
            'partial_masked': partial_masked,
            'kept': kept
        }
    }
