"""
Module 1: OCR AI - Text and Bounding Box Extraction Engine.
Uses Tesseract OCR with OpenCV image preprocessing, PyMuPDF for PDFs, and plain text handlers.
Extracts text and word-level bounding boxes for visual PII redaction.
"""

import os
import sys
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
    1. Upscale small images to >= 1000px width for OCR fidelity
    2. Grayscale conversion
    3. Fast non-local means denoising
    4. Adaptive Gaussian thresholding
    5. Morphological closing to solidify text contours

    Returns: (processed_binary_image, original_resized_bgr_image)
    """
    height, width = img.shape[:2]
    if width < 1000:
        scale = 1000.0 / width
        img = cv2.resize(img, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    denoised = cv2.fastNlMeansDenoising(gray, None, h=10, templateWindowSize=7, searchWindowSize=21)
    thresh = cv2.adaptiveThreshold(
        denoised, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2
    )
    kernel = np.ones((1, 1), np.uint8)
    processed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
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


def get_full_text_and_boxes(file_path):
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

    # Single-pass execution: get full word-level data dictionary
    data = pytesseract.image_to_data(
        processed_img,
        config=custom_config,
        output_type=pytesseract.Output.DICT
    )

    words, extracted_text = _parse_ocr_data(data, processed_img, custom_config)

    return {
        'text': extracted_text,
        'words': words,
        'original_image': original_img,
        'processed_image': processed_img,
        'is_text_file': False
    }


def get_pdf_pages_data(file_path):
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

        data = pytesseract.image_to_data(
            processed_img,
            config=custom_config,
            output_type=pytesseract.Output.DICT
        )

        words, page_text = _parse_ocr_data(data, processed_img, custom_config)

        pages.append({
            'page_num': page_idx,
            'original_image': resized_bgr,
            'processed_image': processed_img,
            'text': page_text,
            'words': words
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
