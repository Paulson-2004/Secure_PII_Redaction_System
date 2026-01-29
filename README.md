# 🔐 Secure PII File Redaction System

A secure AI-powered system that automatically detects and redacts sensitive Personal Identifiable Information (PII) from documents before sharing.

This project supports text files, images, and scanned documents using OCR, Regex, and Named Entity Recognition (NER).

---

## 📌 Features

- 📄 Supports `.txt`, `.pdf`, `.png`, `.jpg`, `.jpeg`
- 🔍 Automatic PII detection (Aadhaar, PAN, Phone, Email, etc.)
- 🤖 AI-assisted detection using:
  - Regex pattern matching
  - spaCy NER model
- ✂️ Intelligent masking and redaction
- ⚡ FastAPI backend with REST API
- 📂 File upload via Swagger UI
- 🔐 Secure and modular architecture

---

## 🏗️ Project Architecture

```
User Upload
      ↓
FastAPI Backend
      ↓
Text Extraction (OCR / File Reader)
      ↓
PII Detection (Regex + NER)
      ↓
Redaction Engine
      ↓
Return Clean Redacted Output
```

---

## 🛠️ Technology Stack

| Layer        | Technology Used |
|-------------|-----------------|
| Backend     | FastAPI (Python) |
| OCR Engine  | Tesseract OCR (via pytesseract) |
| AI / NLP    | spaCy (NER) |
| File Handling | Pillow, pdf2image |
| API Server  | Uvicorn |

---

## 📂 Project Structure

```
Secure_PII_Redaction_System/
│
├── main.py
├── ocr.py
├── pii_detector.py
├── redaction.py
├── requirements.txt
├── uploads/
└── outputs/
```

---

## 🚀 Installation & Setup

### 1️⃣ Clone the Repository

```bash
git clone https://github.com/your-username/Secure_PII_Redaction_System.git
cd Secure_PII_Redaction_System
```

### 2️⃣ Create Virtual Environment (Recommended)

```bash
python -m venv venv
venv\Scripts\activate   # Windows
```

### 3️⃣ Install Dependencies

```bash
python -m pip install -r requirements.txt
```

### 4️⃣ Install spaCy Model

```bash
python -m spacy download en_core_web_sm
```

### 5️⃣ Install Tesseract OCR (Windows)

Download from:
https://github.com/UB-Mannheim/tesseract/wiki

After installation, add this line in `ocr.py`:

```python
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"
```

---

## ▶️ Running the Application

```bash
uvicorn main:app --reload
```

Open browser:

```
http://127.0.0.1:8000/docs
```

Use Swagger UI to upload and process files.

---

## 🧪 Sample Test Input

```
Name: John Doe
Aadhaar: 1234 5678 9012
PAN: ABCDE1234F
Phone: 9876543210
Email: john@gmail.com
```

### Example Output

```json
{
  "redacted_text": "Name: ██████\nAadhaar: ********9012\nPAN: ******1234F\nPhone: ******3210\nEmail: ********@gmail.com"
}
```

---

## 🔍 Supported PII Types

- Aadhaar Number (4-4-4 format)
- PAN Card Number
- Phone Numbers
- Email Addresses
- Named Entities (via NER)

---

## ⚠️ Limitations

- OCR accuracy depends on image quality
- Handwritten documents may reduce detection accuracy
- Currently rule-based masking logic

---

## 📈 Future Improvements

- Policy-based intelligent redaction (RAG integration)
- PDF redaction with direct file output
- Database logging (MySQL integration)
- Flutter mobile frontend
- Role-based access control

---

## 🎓 Academic Use

This project was developed as a Final Year Engineering Project focusing on:

- Secure document handling
- AI-based information detection
- Privacy-preserving systems
- REST API design

---

## 📜 License

This project is for educational and research purposes.
