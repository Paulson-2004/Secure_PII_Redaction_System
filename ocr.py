import pytesseract
from PIL import Image
import cv2
import os
import numpy as np

pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

def extract_text(path):
    ext = os.path.splitext(path)[1].lower()

    if ext in [".png", ".jpg", ".jpeg"]:
        img = cv2.imread(path)

        # Preprocessing (as in your PDF)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        denoised = cv2.medianBlur(gray, 3)
        _, thresh = cv2.threshold(denoised, 150, 255, cv2.THRESH_BINARY)

        text = pytesseract.image_to_string(thresh)
        return text

    elif ext == ".txt":
        with open(path, "r", encoding="utf-8") as f:
            return f.read()

    else:
        return ""
