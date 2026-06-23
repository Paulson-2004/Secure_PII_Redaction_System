"""
Module 1: OCR AI - Text Extraction Engine
Uses Tesseract OCR with OpenCV image preprocessing
Extracts text and word bounding boxes from ID card images
"""

import cv2
import numpy as np
import pytesseract
from PIL import Image
import os
import sys

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config import Config

# Set Tesseract path
pytesseract.pytesseract.tesseract_cmd = Config.TESSERACT_CMD


def preprocess_image(image_path):
    """
    AI Preprocessing Pipeline:
    1. Load image
    2. Convert to grayscale
    3. Apply denoising
    4. Apply adaptive thresholding
    Returns preprocessed image ready for OCR
    """
    # Read image
    img = cv2.imread(image_path)
    if img is None:
        # Try with PIL for webp format
        pil_img = Image.open(image_path).convert('RGB')
        img = np.array(pil_img)
        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)

    # Step 1: Resize if too small (improves OCR accuracy)
    height, width = img.shape[:2]
    if width < 1000:
        scale = 1000 / width
        img = cv2.resize(img, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)

    # Step 2: Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Step 3: Apply denoising
    denoised = cv2.fastNlMeansDenoising(gray, None, h=10, templateWindowSize=7, searchWindowSize=21)

    # Step 4: Apply adaptive thresholding
    thresh = cv2.adaptiveThreshold(
        denoised, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 11, 2
    )

    # Step 5: Morphological operations to clean up
    kernel = np.ones((1, 1), np.uint8)
    processed = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)

    return processed, img


def extract_text(image_path):
    """
    Extract plain text from image using Tesseract OCR.
    Returns extracted text string.
    """
    processed_img, _ = preprocess_image(image_path)
    
    # OCR Configuration for Indian documents
    custom_config = r'--oem 3 --psm 6 -l eng'
    
    text = pytesseract.image_to_string(processed_img, config=custom_config)
    return text.strip()


def extract_text_with_boxes(image_path):
    """
    Extract text with bounding box coordinates.
    Returns list of {text, x, y, w, h, confidence} for each word.
    Used by redaction engine to locate PII on the image.
    """
    processed_img, original_img = preprocess_image(image_path)
    
    # Get word-level data with bounding boxes
    custom_config = r'--oem 3 --psm 6 -l eng'
    data = pytesseract.image_to_data(processed_img, config=custom_config, output_type=pytesseract.Output.DICT)
    
    words = []
    n_boxes = len(data['text'])
    
    for i in range(n_boxes):
        text = data['text'][i].strip()
        conf = int(data['conf'][i])
        
        if text and conf > 30:  # Filter low confidence noise
            words.append({
                'text': text,
                'x': data['left'][i],
                'y': data['top'][i],
                'w': data['width'][i],
                'h': data['height'][i],
                'confidence': conf / 100.0
            })
    
    return words, original_img, processed_img


def get_full_text_and_boxes(image_path):
    """
    Main function: Returns both full text and word boxes.
    This is the primary interface used by the pipeline.
    """
    text = extract_text(image_path)
    words, original_img, processed_img = extract_text_with_boxes(image_path)
    
    return {
        'text': text,
        'words': words,
        'original_image': original_img,
        'processed_image': processed_img
    }


# Test function
if __name__ == '__main__':
    import glob
    test_images = glob.glob(r'd:\PII\PII-DATASET\PII - dataset\aadhar card\*.jpg')
    if test_images:
        result = get_full_text_and_boxes(test_images[0])
        print("=== OCR Extracted Text ===")
        print(result['text'])
        print(f"\n=== Found {len(result['words'])} words with bounding boxes ===")
        for w in result['words'][:10]:
            print(f"  '{w['text']}' at ({w['x']},{w['y']}) conf={w['confidence']:.2f}")
    else:
        print("No test images found")
