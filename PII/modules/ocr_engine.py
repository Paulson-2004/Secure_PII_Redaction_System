"""
Module 1: OCR AI - Text and Bounding Box Extraction Engine.
Uses Tesseract OCR with OpenCV image preprocessing, PyMuPDF for PDFs, and plain text handlers.
Extracts text and word-level bounding boxes for visual PII redaction.
"""

import os
import sys
import time
import logging
import cv2
import numpy as np
import pytesseract
from PIL import Image

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
try:
    from config import Config
    tess_path = getattr(Config, 'TESSERACT_CMD', r'C:\Program Files\Tesseract-OCR\tesseract.exe')
except ImportError:
    tess_path = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

# Configure Tesseract binary path if it exists
if os.path.exists(tess_path):
    pytesseract.pytesseract.tesseract_cmd = tess_path

try:
    import pymupdf  # Modern PyMuPDF API
    PDF_SUPPORT = True
except ImportError:
    PDF_SUPPORT = False

logger = logging.getLogger('ocr_engine')


def load_document_image(file_path):
    """
    Load document as an OpenCV BGR image.
    Supports images (PNG, JPG, WEBP, BMP, TIFF) and PDF first page rendering.
    """
    ext = os.path.splitext(file_path)[1].lower()

    if ext == '.pdf':
        if not PDF_SUPPORT:
            raise ValueError("PDF uploaded but PyMuPDF is not installed")
        doc = pymupdf.open(file_path)
        if len(doc) == 0:
            raise ValueError("PDF is empty")
        page = doc[0]
        pix = page.get_pixmap(dpi=150)
        img = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, pix.n)
        if pix.n == 4:
            return cv2.cvtColor(img, cv2.COLOR_RGBA2BGR)
        return cv2.cvtColor(img, cv2.COLOR_RGB2BGR)

    # Standard image loading
    img = cv2.imread(file_path)
    if img is None:
        # Fallback to PIL for formats like WEBP or uncommon color spaces
        try:
            pil_img = Image.open(file_path).convert('RGB')
            img = np.array(pil_img)
            img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
        except Exception as e:
            raise ValueError(f"Could not decode image at {file_path}: {e}")

    return img


def preprocess_cv2_image(img):
    """
    AI Preprocessing Pipeline for an in-memory BGR image:
    1. Upscale small images to >= 1400px width for OCR fidelity
    2. Grayscale conversion
    3. Fast non-local means denoising
    4. Adaptive Gaussian thresholding
    5. Morphological closing to solidify text contours

    Returns: (processed_binary_image, original_resized_bgr_image)
    """
    _tp0 = time.perf_counter()
    height, width = img.shape[:2]
    if width < 1400:
        scale = 1400.0 / width
        img = cv2.resize(img, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    _tp1 = time.perf_counter()

    denoised = cv2.fastNlMeansDenoising(gray, None, h=10, templateWindowSize=7, searchWindowSize=21)
    _tp2 = time.perf_counter()

    thresh = cv2.adaptiveThreshold(
        denoised, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2
    )
    kernel = np.ones((1, 1), np.uint8)
    processed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
    _tp3 = time.perf_counter()

    logger.info(
        "PROFILE OCR_PREPROCESS: resize_gray=%.3fs denoise=%.3fs threshold=%.3fs "
        "total=%.3fs out_w=%d out_h=%d",
        _tp1 - _tp0, _tp2 - _tp1, _tp3 - _tp2, _tp3 - _tp0,
        img.shape[1], img.shape[0]
    )
    return processed, img


def preprocess_image(file_path):
    """
    AI Preprocessing Pipeline:
    1. Load image (with PDF rendering support)
    2. Upscale small images to >= 1000px width for OCR fidelity
    3. Grayscale conversion
    4. Fast non-local means denoising
    5. Adaptive Gaussian thresholding
    6. Morphological closing to solidify text contours

    Returns: (processed_binary_image, original_resized_bgr_image)
    """
    img = load_document_image(file_path)
    return preprocess_cv2_image(img)


def _parse_ocr_data(data, processed_img, custom_config):
    """Parse pytesseract Output.DICT into bounding boxes and extracted text string."""
    words = []
    text_lines = []
    current_line = []
    last_line_id = None

    n_boxes = len(data.get('text', []))

    for i in range(n_boxes):
        raw_text = data['text'][i].strip()
        # Safe character normalization: normalize non-breaking spaces, zero-width chars, and Unicode hyphens
        raw_text = raw_text.replace('\u00a0', ' ').replace('\u200b', '').replace('\u2010', '-').replace('\u2013', '-').replace('\u2014', '-').replace('—', '-')
        conf = int(data['conf'][i]) if str(data['conf'][i]).isdigit() or isinstance(data['conf'][i], (int, float)) else -1

        line_id = (data.get('block_num', [0])[i], data.get('par_num', [0])[i], data.get('line_num', [0])[i])

        if line_id != last_line_id:
            if current_line:
                text_lines.append(' '.join(current_line))
                current_line = []
            last_line_id = line_id

        if raw_text:
            current_line.append(raw_text)
            if conf > 25:  # Filter noise tokens
                words.append({
                    'text': raw_text,
                    'x': int(data['left'][i]),
                    'y': int(data['top'][i]),
                    'w': int(data['width'][i]),
                    'h': int(data['height'][i]),
                    'confidence': max(0.0, min(1.0, conf / 100.0))
                })

    if current_line:
        text_lines.append(' '.join(current_line))

    extracted_text = '\n'.join(text_lines).strip()
    if not extracted_text:
        extracted_text = pytesseract.image_to_string(processed_img, config=custom_config).strip()

    return words, extracted_text


def get_full_text_and_boxes(file_path, detection_fn=None):
    """
    Extract full text and word-level bounding boxes in a single optimized pass.

    Returns:
        dict: {
            'text': str,
            'words': list of dicts {text, x, y, w, h, confidence},
            'original_image': np.ndarray (BGR),
            'processed_image': np.ndarray (Binary),
            'is_text_file': bool
        }
    """
    ext = os.path.splitext(file_path)[1].lower()

    # Plain text file handler
    if ext == '.txt':
        try:
            with open(file_path, 'r', encoding='utf-8', errors='replace') as f:
                text = f.read()
        except Exception:
            with open(file_path, 'r', encoding='latin-1', errors='replace') as f:
                text = f.read()

        return {
            'text': text,
            'words': [],
            'original_image': None,
            'processed_image': None,
            'is_text_file': True
        }

    # Image / PDF processing
    processed_img, original_img = preprocess_image(file_path)
    custom_config = r'--oem 3 --psm 6 -l eng'

    words, extracted_text, detection_result, detection_elapsed = _extract_words_and_text(
        processed_img, original_img, custom_config, detection_fn=detection_fn
    )

    return {
        'text': extracted_text,
        'words': words,
        'original_image': original_img,
        'processed_image': processed_img,
        'is_text_file': False,
        'detection_result': detection_result,
        'detection_elapsed': detection_elapsed,
    }


def _extract_words_and_text(processed_img, bgr_img, custom_config=r'--oem 3 --psm 6 -l eng', detection_fn=None):
    """
    Multi-pass OCR extraction:
    Pass 1: Standard structured layout extraction with PSM 6.
    Pass 2: High-fidelity sparse text pass with PSM 11 on grayscale to capture
            small/micro tokens (e.g. secondary Aadhaar numbers under ghost photos,
            isolated serial numbers, and corner credentials).
    Merges tokens, resolves overlaps favoring numeric clarity and higher confidence,
    and sorts words spatially into natural reading order.
    """
    _tocr1_start = time.perf_counter()
    data1 = pytesseract.image_to_data(
        processed_img,
        config=custom_config,
        output_type=pytesseract.Output.DICT
    )
    _tocr1_end = time.perf_counter()
    words, extracted_text = _parse_ocr_data(data1, processed_img, custom_config)
    logger.info(
        "PROFILE OCR_PASS1: psm=6 elapsed=%.3fs img_shape=%s raw_boxes=%d words_kept=%d",
        _tocr1_end - _tocr1_start,
        str(processed_img.shape if hasattr(processed_img, 'shape') else 'N/A'),
        len(data1.get('text', [])),
        len(words)
    )

    detection_elapsed = 0.0
    if detection_fn is not None:
        _tdetect_start = time.perf_counter()
        detection_result = detection_fn(extracted_text)
        detection_elapsed = time.perf_counter() - _tdetect_start
    else:
        detection_result = None
    avg_confidence = (
        sum(word['confidence'] for word in words) / len(words) if words else 0.0
    )
    pass2_enabled = bgr_img is not None
    if detection_fn is not None:
        pii_count = len((detection_result or {}).get('detections', []))
        p1_word_count = len(words)
        enough_words = p1_word_count >= 15
        has_pii = pii_count >= 1
        high_confidence = avg_confidence >= 0.65
        skip_pass2 = enough_words and (has_pii or high_confidence)
        pass2_enabled = not skip_pass2
        if skip_pass2:
            reason = 'sufficient_words_with_pii' if has_pii else 'sufficient_words_high_confidence'
        elif not enough_words:
            reason = 'insufficient_words'
        elif not high_confidence:
            reason = 'low_confidence_without_pii'
        else:
            reason = 'insufficient_pass1_quality'
        logger.info(
            'OCR_DECISION: p1_words=%d avg_conf=%.3f pii_entities=%d pass2=%s reason=%s',
            p1_word_count, avg_confidence, pii_count,
            'fallback' if pass2_enabled else 'skipped', reason
        )

    # Pass 2: High-fidelity sparse pass on grayscale image
    if pass2_enabled:
        try:
            gray = cv2.cvtColor(bgr_img, cv2.COLOR_BGR2GRAY)
            h, w = gray.shape[:2]
            scale = 1.5 if w <= 2000 else 1.0
            if scale != 1.0:
                scan_img = cv2.resize(gray, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)
            else:
                scan_img = gray

            _tocr2_start = time.perf_counter()
            data2 = pytesseract.image_to_data(
                scan_img,
                config=r'--oem 3 --psm 11 -l eng',
                output_type=pytesseract.Output.DICT
            )
            _tocr2_end = time.perf_counter()

            pass2_words = []
            n_boxes = len(data2.get('text', []))
            for i in range(n_boxes):
                raw_text = data2['text'][i].strip()
                raw_text = raw_text.replace('\u00a0', ' ').replace('\u200b', '').replace('\u2010', '-').replace('\u2013', '-').replace('\u2014', '-').replace('—', '-')
                conf = int(data2['conf'][i]) if str(data2['conf'][i]).isdigit() or isinstance(data2['conf'][i], (int, float)) else -1
                if raw_text and conf > 25:
                    pass2_words.append({
                        'text': raw_text,
                        'confidence': max(0.0, min(1.0, conf / 100.0)),
                        'x': int(data2['left'][i] / scale),
                        'y': int(data2['top'][i] / scale),
                        'w': int(data2['width'][i] / scale),
                        'h': int(data2['height'][i] / scale),
                    })

            logger.info(
                "PROFILE OCR_PASS2: psm=11 elapsed=%.3fs scale=%.1f scan_shape=%s raw_boxes=%d words_kept=%d",
                _tocr2_end - _tocr2_start, scale,
                str(scan_img.shape if hasattr(scan_img, 'shape') else 'N/A'),
                n_boxes, len(pass2_words)
            )

            for p2 in pass2_words:
                x, y, w, h = p2['x'], p2['y'], p2['w'], p2['h']
                overlapping_idx = None
                for j, ew in enumerate(words):
                    if not (x + w < ew['x'] or x > ew['x'] + ew['w'] or y + h < ew['y'] or y > ew['y'] + ew['h']):
                        overlapping_idx = j
                        break
                if overlapping_idx is None:
                    words.append(p2)
                else:
                    ew = words[overlapping_idx]
                    # If Pass 2 word is digits while Pass 1 was non-digits (e.g. 'esr' vs '6081'),
                    # or Pass 2 has notably higher confidence, replace it
                    if (p2['text'].isdigit() and not ew['text'].isdigit()) or (p2['confidence'] > ew['confidence'] + 0.15):
                        words[overlapping_idx] = p2

        except Exception as e:
            logger.debug("Pass 2 sparse OCR pass skipped: %s", e)

    # Sort words spatially into reading order (bucketed y, x)
    words.sort(key=lambda item: (round(item.get('y', 0) / 20.0), item.get('x', 0)))
    return words, extracted_text, detection_result, detection_elapsed



def get_pdf_pages_data(file_path, detection_fn=None):
    """
    Extract images, text, and bounding boxes for all pages of a PDF document.

    Returns:
        list of dict: [
            {
                'page_num': int,
                'original_image': np.ndarray (BGR),
                'processed_image': np.ndarray (Binary),
                'text': str,
                'words': list of dicts {text, x, y, w, h, confidence}
            },
            ...
        ]
    """
    if not PDF_SUPPORT:
        raise ValueError("PDF uploaded but PyMuPDF is not installed")
    doc = pymupdf.open(file_path)
    if len(doc) == 0:
        doc.close()
        raise ValueError("PDF is empty")

    custom_config = r'--oem 3 --psm 6 -l eng'
    pages = []

    for page_idx in range(len(doc)):
        page = doc[page_idx]
        pix = page.get_pixmap(dpi=150)
        img = np.frombuffer(pix.samples, dtype=np.uint8).reshape(pix.height, pix.width, pix.n)
        if pix.n == 4:
            bgr_img = cv2.cvtColor(img, cv2.COLOR_RGBA2BGR)
        else:
            bgr_img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)

        processed_img, resized_bgr = preprocess_cv2_image(bgr_img)

        words, page_text, detection_result, detection_elapsed = _extract_words_and_text(
            processed_img, resized_bgr, custom_config, detection_fn=detection_fn
        )

        pages.append({
            'page_num': page_idx,
            'original_image': resized_bgr,
            'processed_image': processed_img,
            'text': page_text,
            'words': words,
            'detection_result': detection_result,
            'detection_elapsed': detection_elapsed,
        })

    doc.close()
    return pages


def extract_text(file_path):
    """Convenience function: extract plain text only."""
    return get_full_text_and_boxes(file_path)['text']


def extract_text_with_boxes(file_path):
    """Convenience function: extract words, original image, and processed image."""
    res = get_full_text_and_boxes(file_path)
    return res['words'], res['original_image'], res['processed_image']
