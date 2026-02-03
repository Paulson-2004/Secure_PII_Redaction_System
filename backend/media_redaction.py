from io import BytesIO
from typing import List

import cv2
import numpy as np
from pdf2image import convert_from_path
from PIL import Image

from config import CONFIG


def redact_image_bytes(image_bytes: bytes, boxes: List[dict]) -> bytes:
    image_array = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(image_array, cv2.IMREAD_COLOR)
    if image is None:
        return image_bytes

    for box in boxes:
        x = int(box.get("x", 0))
        y = int(box.get("y", 0))
        w = int(box.get("w", 0))
        h = int(box.get("h", 0))
        if w > 0 and h > 0:
            cv2.rectangle(image, (x, y), (x + w, y + h), (0, 0, 0), thickness=-1)

    ok, encoded = cv2.imencode(".png", image)
    if not ok:
        return image_bytes
    return encoded.tobytes()


def redact_pdf_with_boxes(pdf_path: str, boxes: List[dict], output_path: str) -> str:
    pages = convert_from_path(pdf_path, dpi=CONFIG.pdf_dpi)
    redacted_pages = []

    for page_index, page in enumerate(pages):
        image = cv2.cvtColor(np.array(page), cv2.COLOR_RGB2BGR)
        page_boxes = [b for b in boxes if b.get("page", 0) == page_index]
        for box in page_boxes:
            x = int(box.get("x", 0))
            y = int(box.get("y", 0))
            w = int(box.get("w", 0))
            h = int(box.get("h", 0))
            if w > 0 and h > 0:
                cv2.rectangle(image, (x, y), (x + w, y + h), (0, 0, 0), thickness=-1)

        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        redacted_pages.append(Image.fromarray(rgb))

    if not redacted_pages:
        return output_path

    first, rest = redacted_pages[0], redacted_pages[1:]
    first.save(output_path, save_all=True, append_images=rest)
    return output_path
