from pdf_generator import generate_redacted_pdf
from fastapi.responses import FileResponse
from fastapi import FastAPI, UploadFile
import shutil, os
from ocr import extract_text
from pii_detector import detect_pii
from redaction import redact_text

app = FastAPI()

os.makedirs("uploads", exist_ok=True)

@app.post("/process/")
async def process_file(file: UploadFile):

    path = f"uploads/{file.filename}"

    with open(path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    text = extract_text(path)
    pii_data = detect_pii(text)
    redacted_text = redact_text(text, pii_data)

    if path.lower().endswith(".pdf"):
        output_path = generate_redacted_pdf(redacted_text)
        return FileResponse(
            output_path,
            media_type="application/pdf",
            filename="redacted_output.pdf"
        )

    return {
        "total_pii_detected": len(pii_data),
        "detected_types": list(set([item["type"] for item in pii_data])),
        "redacted_text": redacted_text
    }
