import pytesseract
from PIL import Image
from pdf2image import convert_from_path
import os

def extract_text(path):
    ext = os.path.splitext(path)[1].lower()

    if ext == ".pdf":
        pages = convert_from_path(path)
        text = ""
        for page in pages:
            text += pytesseract.image_to_string(page)
        return text

    elif ext == ".txt":
        with open(path, "r", encoding="utf-8") as f:
            return f.read()

    elif ext in [".png", ".jpg", ".jpeg"]:
        img = Image.open(path)
        return pytesseract.image_to_string(img)

    else:
        return ""
