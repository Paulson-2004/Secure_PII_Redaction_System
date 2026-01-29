import pytesseract
from PIL import Image
from pdf2image import convert_from_path
import cv2
import os

# 🔹 Set Tesseract path (Windows only)
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"


def extract_text(path):
    """
    Extracts text from TXT, PDF, and Image files.
    Includes light preprocessing for better OCR accuracy.
    """

    ext = os.path.splitext(path)[1].lower()

    # ----------------------------
    # TEXT FILE
    # ----------------------------
    if ext == ".txt":
        with open(path, "r", encoding="utf-8") as f:
            return f.read()

    # ----------------------------
    # PDF FILE
    # ----------------------------
    elif ext == ".pdf":
        pages = convert_from_path(path)
        text = ""
        for page in pages:
            text += pytesseract.image_to_string(page, config="--oem 3 --psm 6")
        return text
    # ----------------------------
    # IMAGE FILE
    # ----------------------------
    elif ext in [".png", ".jpg", ".jpeg"]:
        img = cv2.imread(path)

        # Light preprocessing (safe)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        gray = cv2.GaussianBlur(gray, (3, 3), 0)

        text = pytesseract.image_to_string(
            gray,
            config="--oem 3 --psm 6"
        )

        return text

    # ----------------------------
    # Unsupported Format
    # ----------------------------
    else:
        return ""
