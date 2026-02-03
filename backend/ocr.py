import os
from typing import List, Tuple

import cv2
import numpy as np
import pytesseract
from pdf2image import convert_from_path
from pytesseract import Output

from config import CONFIG


if CONFIG.tesseract_cmd:
    pytesseract.pytesseract.tesseract_cmd = CONFIG.tesseract_cmd


def preprocess_image(image: np.ndarray) -> np.ndarray:
    # Convert to grayscale
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    # Noise removal
    gray = cv2.GaussianBlur(gray, (5, 5), 0)

    # Thresholding
    _, thresh = cv2.threshold(gray, 150, 255, cv2.THRESH_BINARY)

    return thresh


def _extract_from_image(image: np.ndarray, page_index: int, use_preprocess: bool) -> Tuple[str, List[dict]]:
    if use_preprocess:
        image = preprocess_image(image)

    data = pytesseract.image_to_data(image, output_type=Output.DICT)

    words = []
    full_text_parts = []
    current_index = 0
    n_boxes = len(data["text"])
    for i in range(n_boxes):
        word = data["text"][i]
        if word.strip() != "":
            if full_text_parts:
                full_text_parts.append(" ")
                current_index += 1

            start = current_index
            end = start + len(word)
            current_index = end

            words.append(
                {
                    "text": word,
                    "x": data["left"][i],
                    "y": data["top"][i],
                    "w": data["width"][i],
                    "h": data["height"][i],
                    "page": page_index,
                    "start": start,
                    "end": end,
                }
            )

            full_text_parts.append(word)

    full_text = "".join(full_text_parts)
    return full_text, words


def extract_text_and_boxes(file_path: str, use_preprocess: bool = True) -> Tuple[str, List[dict]]:
    ext = os.path.splitext(file_path)[1].lower()

    if ext == ".pdf":
        pages = convert_from_path(file_path, dpi=CONFIG.pdf_dpi)
        all_words = []
        page_texts = []
        offset = 0
        for page_index, page in enumerate(pages):
            image = cv2.cvtColor(np.array(page), cv2.COLOR_RGB2BGR)
            text, words = _extract_from_image(image, page_index, use_preprocess)
            for word in words:
                word["start"] += offset
                word["end"] += offset
            page_texts.append(text)
            all_words.extend(words)
            offset += len(text) + 2

        full_text = "\n\n".join(page_texts)
        return full_text, all_words

    image = cv2.imread(file_path)
    if image is None:
        return "", []

    return _extract_from_image(image, page_index=0, use_preprocess=use_preprocess)
