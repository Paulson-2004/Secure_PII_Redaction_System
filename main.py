from pdf_generator import generate_redacted_pdf
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI, UploadFile, File
from ocr import extract_text_and_boxes
from pii_detector import detect_pii
from redaction import redact_text
import shutil, os

app = FastAPI()

os.makedirs("uploads", exist_ok=True)

@app.post("/process/")
async def process_file(file: UploadFile = File(...)):
    path = f"uploads/{file.filename}"

    with open(path, "wb") as buffer:
        buffer.write(await file.read())

    text, words = extract_text_and_boxes(path)

    pii_data = detect_pii(text)

    redacted_text = text
    boxes = []

    for pii in pii_data:
        redacted_text = redacted_text.replace(pii["value"], "[REDACTED]")

        for word in words:
            if word["text"] == pii["value"]:
                boxes.append({
                    "x": word["x"],
                    "y": word["y"],
                    "w": word["w"],
                    "h": word["h"]
                })

    return {
        "total_pii_detected": len(pii_data),
        "redacted_text": redacted_text,
        "boxes": boxes
    }
