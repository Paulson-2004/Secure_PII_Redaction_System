import os
import re
from typing import Iterable, List, Tuple

import cv2
import numpy as np
import pytesseract
from PIL import Image


_OCR_DIGIT = r"[0-9OIl]"
_OCR_LETTER = r"[A-Z0-9]"

ALL_PATTERNS = [
    ("AADHAAR", re.compile(rf"\b{_OCR_DIGIT}{{4}}[\s\-]?{_OCR_DIGIT}{{4}}[\s\-]?{_OCR_DIGIT}{{3,4}}\b")),
    ("PAN", re.compile(rf"\b{_OCR_LETTER}{{4,6}}{_OCR_DIGIT}{{3,5}}{_OCR_LETTER}\b")),
    ("DL", re.compile(rf"\b{_OCR_LETTER}{{2}}{_OCR_DIGIT}{{2}}[\s\-]?{_OCR_DIGIT}{{6,13}}\b")),
    ("VOTER_ID", re.compile(rf"\b{_OCR_LETTER}{{3}}{_OCR_DIGIT}{{6,8}}\b")),
    ("PASSPORT", re.compile(rf"\b{_OCR_LETTER}{_OCR_DIGIT}{{6,8}}\b")),
    (
        "PHONE",
        re.compile(
            rf"\b[6-9OIl]{_OCR_DIGIT}{{2}}[\s\-]?{_OCR_DIGIT}{{3}}[\s\-]?{_OCR_DIGIT}{{4}}\b"
        ),
    ),
    ("EMAIL", re.compile(r"\b[\w\.-]+@[\w\.-]+\.\w+\b")),
    ("IFSC", re.compile(rf"\b{_OCR_LETTER}{{4}}[0O]{_OCR_DIGIT}{{6}}\b")),
    ("ACCOUNT", re.compile(rf"\b{_OCR_DIGIT}{{8,20}}\b")),
    ("DOB", re.compile(r"\b\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}\b")),
    ("IP_ADDRESS", re.compile(r"\b(?:\d{1,3}\.){3}\d{1,3}\b")),
    (
        "ADDRESS",
        re.compile(
            r"\b(?:Address|Addr)[:\-]\s*([A-Za-z0-9#.,\-\/\s]{10,200}?)(?=\n\s*[A-Za-z ]{2,20}[:\-]|$)",
            re.DOTALL,
        ),
    ),
]

PRESET_LABELS = {
    "all": {
        "AADHAAR",
        "PAN",
        "DL",
        "VOTER_ID",
        "PASSPORT",
        "PHONE",
        "EMAIL",
        "IFSC",
        "ACCOUNT",
        "DOB",
        "IP_ADDRESS",
        "ADDRESS",
    },
    "ids": {"AADHAAR", "PAN", "DL", "VOTER_ID", "PASSPORT"},
    "ids_contact": {"AADHAAR", "PAN", "DL", "VOTER_ID", "PASSPORT", "PHONE", "EMAIL"},
}


def select_patterns(label_set: str) -> List[Tuple[str, re.Pattern]]:
    labels = PRESET_LABELS.get(label_set)
    if not labels:
        raise ValueError(f"Unknown label set: {label_set}")
    return [(label, pattern) for label, pattern in ALL_PATTERNS if label in labels]


def iter_images(root: str) -> Iterable[str]:
    for dirpath, _, filenames in os.walk(root):
        for name in filenames:
            lower = name.lower()
            if lower.endswith((".png", ".jpg", ".jpeg", ".tif", ".tiff", ".bmp")):
                yield os.path.join(dirpath, name)


def preprocess_image(image: np.ndarray, scale: float = 2.0) -> np.ndarray:
    if scale and scale != 1.0:
        image = cv2.resize(image, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    gray = cv2.fastNlMeansDenoising(gray, h=12, templateWindowSize=7, searchWindowSize=21)
    clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
    gray = clahe.apply(gray)
    thresh = cv2.adaptiveThreshold(
        gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 31, 10
    )
    coords = np.column_stack(np.where(thresh < 255))
    if coords.size > 0:
        rect = cv2.minAreaRect(coords)
        angle = rect[-1]
        if angle < -45:
            angle = -(90 + angle)
        else:
            angle = -angle
        (h, w) = thresh.shape[:2]
        center = (w // 2, h // 2)
        matrix = cv2.getRotationMatrix2D(center, angle, 1.0)
        thresh = cv2.warpAffine(
            thresh, matrix, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE
        )
    return thresh


def ocr_image(path: str, preprocess: bool = False, psm: int = 6) -> str:
    try:
        if preprocess:
            image = cv2.imread(path)
            if image is None:
                return ""
            processed = preprocess_image(image)
            image = Image.fromarray(processed)
        else:
            image = Image.open(path)
    except Exception:
        return ""
    config = f"--oem 3 --psm {psm}"
    text = pytesseract.image_to_string(image, config=config)
    return text.strip()


def _normalize_address(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def _normalize_ocr_digits(value: str) -> str:
    return value.translate(str.maketrans({"O": "0", "o": "0", "I": "1", "l": "1"}))


def _normalize_ocr_letters(value: str) -> str:
    return value.translate(str.maketrans({"0": "O", "1": "I", "2": "Z", "5": "S", "8": "B"}))


def _is_valid_aadhaar(value: str) -> bool:
    digits = re.sub(r"\D", "", _normalize_ocr_digits(value))
    if len(digits) != 12:
        return False
    return digits[0] not in {"0", "1"}


def _is_valid_pan(value: str) -> bool:
    cleaned = re.sub(r"\s", "", value.upper())
    normalized = _normalize_ocr_letters(_normalize_ocr_digits(cleaned))
    return re.fullmatch(r"[A-Z]{5}\d{4}[A-Z]", normalized) is not None


def _is_valid_dl(value: str) -> bool:
    cleaned = re.sub(r"\s", "", value.upper())
    normalized = _normalize_ocr_letters(_normalize_ocr_digits(cleaned))
    return re.fullmatch(r"[A-Z]{2}\d{2}\d{6,13}", normalized) is not None


def _is_valid_voter(value: str) -> bool:
    cleaned = re.sub(r"\s", "", value.upper())
    normalized = _normalize_ocr_letters(_normalize_ocr_digits(cleaned))
    return re.fullmatch(r"[A-Z]{3}\d{6,8}", normalized) is not None


def _is_valid_passport(value: str) -> bool:
    cleaned = re.sub(r"\s", "", value.upper())
    normalized = _normalize_ocr_letters(_normalize_ocr_digits(cleaned))
    return re.fullmatch(r"[A-Z]\d{6,8}", normalized) is not None


def _is_valid_phone(value: str) -> bool:
    digits = re.sub(r"\D", "", _normalize_ocr_digits(value))
    if len(digits) != 10:
        return False
    return digits[0] in {"6", "7", "8", "9"}


_VALIDATORS = {
    "AADHAAR": _is_valid_aadhaar,
    "PAN": _is_valid_pan,
    "DL": _is_valid_dl,
    "VOTER_ID": _is_valid_voter,
    "PASSPORT": _is_valid_passport,
    "PHONE": _is_valid_phone,
}


def find_entities(text: str, patterns: List[Tuple[str, re.Pattern]]) -> List[Tuple[int, int, str]]:
    entities: List[Tuple[int, int, str]] = []
    for label, pattern in patterns:
        for match in pattern.finditer(text):
            if label == "ADDRESS":
                value = _normalize_address(match.group(1))
                start = match.start(1)
                end = match.end(1)
                if not value:
                    continue
            else:
                start = match.start()
                end = match.end()
            validator = _VALIDATORS.get(label)
            if validator:
                snippet = text[start:end]
                if not validator(snippet):
                    continue
            entities.append((start, end, label))

    entities.sort(key=lambda item: (item[0], item[1]))
    filtered: List[Tuple[int, int, str]] = []
    last_end = -1
    for start, end, label in entities:
        if start < last_end:
            continue
        filtered.append((start, end, label))
        last_end = end
    return filtered
