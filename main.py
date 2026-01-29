import os
from fastapi import FastAPI, UploadFile
import shutil
from ocr import extract_text
from pii_detector import detect_pii
from redaction import redact_text

app = FastAPI()

UPLOAD_FOLDER = "uploads"
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

@app.post("/process/")
async def process_file(file: UploadFile):
    path = f"{UPLOAD_FOLDER}/{file.filename}"

    with open(path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    text = extract_text(path)
    pii_data = detect_pii(text)
    redacted_text = redact_text(text, pii_data)

    return {"redacted_text": redacted_text}
