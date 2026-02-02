import pytesseract
from pytesseract import Output
import cv2
import numpy as np
from pdf2image import convert_from_path
from PIL import Image
import os

pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

def preprocess_image(image_path):
    img = cv2.imread(image_path)

    # Convert to grayscale
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # Noise removal
    gray = cv2.GaussianBlur(gray, (5, 5), 0)

    # Thresholding
    _, thresh = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY)

    return thresh

def extract_text_and_boxes(image_path):
    image = cv2.imread(image_path)

    data = pytesseract.image_to_data(image, output_type=Output.DICT)

    words = []
    n_boxes = len(data['text'])

    for i in range(n_boxes):
        word = data['text'][i]
        if word.strip() != "":
            words.append({
                "text": word,
                "x": data['left'][i],
                "y": data['top'][i],
                "w": data['width'][i],
                "h": data['height'][i]
            })

    full_text = " ".join([w["text"] for w in words])

    return full_text, words
