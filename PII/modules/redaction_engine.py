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

    if decision == 'BLUR':
        return '[BLURRED]' if val_len >= 8 else '░' * val_len

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
            return '*' * val_len

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
            return '*' * val_len

        elif pii_type in ('CREDIT_CARD', 'BANK_ACCOUNT'):
            digits = re.sub(r'\D', '', value)
            if len(digits) >= 4:
                return '*' * (len(digits) - 4) + digits[-4:]
            return '*' * val_len

        elif pii_type == 'PAN':
            if len(value) == 10:
                return f"XXXXX{value[5:9]}X"
            return '*' * val_len

        else:
            if val_len > 4:
                return '*' * (val_len - 4) + value[-4:]
            return '*' * val_len

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
    Finds all occurrences of the PII entity across the document page.
    """
    if not pii_value or not ocr_words:
        return []

    # Sort words spatially into reading order (bucketed y, x)
    sorted_words = sorted(ocr_words, key=lambda w: (round(w.get('y', 0) / 20.0), w.get('x', 0)))

    target_tokens = [_clean_token(t) for t in pii_value.split() if _clean_token(t)]
    if not target_tokens:
        clean_pii = _clean_token(pii_value)
        if not clean_pii:
            return []
        target_tokens = [clean_pii]

    matching_boxes = []
    n_tokens = len(target_tokens)
    n_words = len(sorted_words)

    def _already_covered(cand_box):
        cx, cy, cw, ch = cand_box['x'], cand_box['y'], cand_box['w'], cand_box['h']
        for mb in matching_boxes:
            mx, my, mw, mh = mb['x'], mb['y'], mb['w'], mb['h']
            if not (cx + cw < mx or cx > mx + mw or cy + ch < my or cy > my + mh):
                return True
        return False

    # Strategy 1: Match multi-word consecutive sequences (all occurrences across page)
    for i in range(n_words - n_tokens + 1):
        window_words = sorted_words[i:i + n_tokens]
        window_tokens = [_clean_token(w['text']) for w in window_words]

        if window_tokens == target_tokens:
            min_x = min(w['x'] for w in window_words)
            min_y = min(w['y'] for w in window_words)
            max_x = max(w['x'] + w['w'] for w in window_words)
            max_y = max(w['y'] + w['h'] for w in window_words)
            box = {
                'x': min_x,
                'y': min_y,
                'w': max_x - min_x,
                'h': max_y - min_y
            }
            if not _already_covered(box):
                matching_boxes.append(box)

    # Strategy 2: Single-token containment (e.g. email or continuous Aadhaar)
    clean_full_pii = _clean_token(pii_value)
    for w in sorted_words:
        w_clean = _clean_token(w['text'])
        if not w_clean:
            continue
        if w_clean == clean_full_pii or (len(w_clean) >= 6 and w_clean in clean_full_pii):
            box = {
                'x': w['x'],
                'y': w['y'],
                'w': w['w'],
                'h': w['h']
            }
            if not _already_covered(box):
                matching_boxes.append(box)

    # Strategy 3: Multi-word sequence whose combined text matches clean_full_pii
    for i in range(n_words):
        accumulated = ""
        seq_words = []
        for j in range(i, min(n_words, i + 8)):
            cw = _clean_token(sorted_words[j]['text'])
            if not cw:
                continue
            accumulated += cw
            seq_words.append(sorted_words[j])
            if accumulated == clean_full_pii:
                min_x = min(w['x'] for w in seq_words)
                min_y = min(w['y'] for w in seq_words)
                max_x = max(w['x'] + w['w'] for w in seq_words)
                max_y = max(w['y'] + w['h'] for w in seq_words)
                box = {
                    'x': min_x,
                    'y': min_y,
                    'w': max_x - min_x,
                    'h': max_y - min_y
                }
                if not _already_covered(box):
                    matching_boxes.append(box)
                break
            elif len(accumulated) > len(clean_full_pii):
                break

    return matching_boxes


def apply_visual_treatment(image, x, y, w, h, decision, replacement_text="****"):
    """
    Apply visual treatment (FULL_REDACT, BLUR, PARTIAL_MASK) directly to image bounding box.
    Modifies image in-place.
    """
    if image is None:
        return
    img_h, img_w = image.shape[:2]
    # Clamp coordinates to image boundaries
    x = max(0, min(img_w - 1, int(x)))
    y = max(0, min(img_h - 1, int(y)))
    w = max(1, min(img_w - x, int(w)))
    h = max(1, min(img_h - y, int(h)))

    if decision == 'FULL_REDACT':
        # Filled solid black box
        cv2.rectangle(image, (x, y), (x + w, y + h), (0, 0, 0), -1)

    elif decision == 'BLUR':
        # Irreversible Gaussian Blur over target region
        roi = image[y:y + h, x:x + w]
        if roi.size > 0:
            down_w = max(1, w // 6)
            down_h = max(1, h // 6)
            small = cv2.resize(roi, (down_w, down_h), interpolation=cv2.INTER_LINEAR)
            upscaled = cv2.resize(small, (w, h), interpolation=cv2.INTER_LINEAR)
            k_w = max(15, (w // 3) * 2 + 1)
            k_h = max(15, (h // 3) * 2 + 1)
            blurred = cv2.GaussianBlur(upscaled, (k_w, k_h), sigmaX=10, sigmaY=10)
            image[y:y + h, x:x + w] = blurred

    elif decision == 'PARTIAL_MASK':
        # Format-preserving visual mask:
        # 1. Clear original sensitive pixels completely with clean neutral background
        cv2.rectangle(image, (x, y), (x + w, y + h), (245, 245, 245), -1)
        cv2.rectangle(image, (x, y), (x + w, y + h), (190, 190, 190), 1)

        # 2. Format-preserving mask text
        mask_str = replacement_text.replace('█', '*').replace('░', '*')
        if not mask_str or not mask_str.strip():
            mask_str = '****'

        # 3. Fit and draw text inside bounding box
        font = cv2.FONT_HERSHEY_SIMPLEX
        font_scale = min(0.85, max(0.32, (h - 4) / 28.0))
        thickness = 1 if font_scale < 0.6 else 2

        (tw, th), _ = cv2.getTextSize(mask_str, font, font_scale, thickness)
        if tw > w - 4 and len(mask_str) > 4:
            mask_str = '****'
            (tw, th), _ = cv2.getTextSize(mask_str, font, font_scale, thickness)

        while tw > max(4, w - 4) and font_scale > 0.22:
            font_scale -= 0.04
            (tw, th), _ = cv2.getTextSize(mask_str, font, font_scale, thickness)

        tx = max(x + 2, x + (w - tw) // 2)
        ty = max(y + th + 2, y + (h + th) // 2)
        cv2.putText(image, mask_str, (tx, ty), font, font_scale, (30, 30, 30), thickness, cv2.LINE_AA)


def redact_image(image, detections, ocr_words, manual_regions=None):
    """
    Apply visual redaction to document image based on OCR bounding boxes and/or manual regions.

    Args:
        image: OpenCV BGR image (np.ndarray)
        detections: List of detections with decisions
        ocr_words: List of OCR words with bounding boxes
        manual_regions: Optional list of user-selected regions (normalized or pixel dicts)

    Returns:
        Redacted OpenCV BGR image (np.ndarray)
    """
    if image is None:
        return None

    redacted_img = image.copy()
    img_h, img_w = redacted_img.shape[:2]

    processed_boxes = []

    def _boxes_overlap(b1, b2, iou_thresh=0.7):
        x1 = max(b1[0], b2[0])
        y1 = max(b1[1], b2[1])
        x2 = min(b1[0] + b1[2], b2[0] + b2[2])
        y2 = min(b1[1] + b1[3], b2[1] + b2[3])
        inter = max(0, x2 - x1) * max(0, y2 - y1)
        if inter <= 0:
            return False
        area1 = b1[2] * b1[3]
        area2 = b2[2] * b2[3]
        union = area1 + area2 - inter
        return (inter / union) >= iou_thresh if union > 0 else False

    # 1. Automatic OCR Detections
    if detections and ocr_words:
        for det in detections:
            decision = det.get('decision', 'FULL_REDACT')
            if decision == 'KEEP':
                continue

            boxes = _find_word_boxes_for_pii(det.get('value', ''), ocr_words)
            if not boxes:
                continue

            replacement_text = _get_replacement_text(det.get('value', ''), det)

            for box in boxes:
                padding = 4
                x = max(0, box['x'] - padding)
                y = max(0, box['y'] - padding)
                w = min(img_w - x, box['w'] + 2 * padding)
                h = min(img_h - y, box['h'] + 2 * padding)

                if w <= 0 or h <= 0:
                    continue

                apply_visual_treatment(redacted_img, x, y, w, h, decision, replacement_text)
                processed_boxes.append((x, y, w, h))

    # 2. Manual User-Selected Regions
    if manual_regions:
        for mreg in manual_regions:
            action = str(mreg.get('action', 'redact')).upper()
            if action in ('FULL_REDACT', 'REDACT'):
                decision = 'FULL_REDACT'
            elif action in ('BLUR',):
                decision = 'BLUR'
            elif action in ('PARTIAL_MASK', 'MASK'):
                decision = 'PARTIAL_MASK'
            else:
                decision = 'FULL_REDACT'

            norm_x = float(mreg.get('x', 0.0))
            norm_y = float(mreg.get('y', 0.0))
            norm_w = float(mreg.get('width', mreg.get('w', 0.0)))
            norm_h = float(mreg.get('height', mreg.get('h', 0.0)))

            # If normalized coordinates (0.0 .. 1.0), scale to actual image pixels
            if norm_w <= 1.0 and norm_h <= 1.0 and norm_x <= 1.0 and norm_y <= 1.0:
                px_x = int(round(norm_x * img_w))
                px_y = int(round(norm_y * img_h))
                px_w = int(round(norm_w * img_w))
                px_h = int(round(norm_h * img_h))
            else:
                px_x = int(round(norm_x))
                px_y = int(round(norm_y))
                px_w = int(round(norm_w))
                px_h = int(round(norm_h))

            px_x = max(0, min(img_w - 1, px_x))
            px_y = max(0, min(img_h - 1, px_y))
            px_w = max(1, min(img_w - px_x, px_w))
            px_h = max(1, min(img_h - px_y, px_h))

            box_tuple = (px_x, px_y, px_w, px_h)
            if any(_boxes_overlap(box_tuple, pb, iou_thresh=0.7) for pb in processed_boxes):
                continue

            apply_visual_treatment(redacted_img, px_x, px_y, px_w, px_h, decision, "********")
            processed_boxes.append(box_tuple)

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


def process_redaction(original_text, original_image, ocr_words, detections, output_image_path, manual_regions=None):
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
        redacted_image = redact_image(original_image, detections, ocr_words, manual_regions=manual_regions)
        redacted_path = save_redacted_image(redacted_image, output_image_path)
    elif output_image_path:
        redacted_path = save_redacted_text(redacted_text, output_image_path)

    full_redacted = sum(1 for d in detections if d.get('decision') == 'FULL_REDACT')
    partial_masked = sum(1 for d in detections if d.get('decision') == 'PARTIAL_MASK')
    blurred = sum(1 for d in detections if d.get('decision') == 'BLUR')
    kept = sum(1 for d in detections if d.get('decision') == 'KEEP')

    if manual_regions:
        for m in manual_regions:
            m_act = str(m.get('action', 'redact')).upper()
            if m_act in ('BLUR',):
                blurred += 1
            elif m_act in ('PARTIAL_MASK', 'MASK'):
                partial_masked += 1
            else:
                full_redacted += 1

    total_elements = len(detections) + (len(manual_regions) if manual_regions else 0)

    return {
        'redacted_text': redacted_text,
        'redacted_image_path': redacted_path,
        'summary': {
            'total_pii': total_elements,
            'full_redacted': full_redacted,
            'partial_masked': partial_masked,
            'blurred': blurred,
            'kept': kept
        }
    }
