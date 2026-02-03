# 🔐 Secure PII File Redaction System (Backend)

This is the backend service. The Android app lives in `android-app/` at the repo root.

## New Capabilities
- RAG-based policy decision (OpenAI embeddings + chat)
- Expanded PII categories (passport, voter ID, IFSC, account, IP, DOB, address)
- True PDF/image redaction output via `return_redacted_file=true`

## RAG Configuration
Set the following environment variables (or `config.toml`):
- `OPENAI_API_KEY`
- `OPENAI_EMBED_MODEL` (default: `text-embedding-3-small`)
- `OPENAI_CHAT_MODEL` (default: `gpt-4o-mini`)
- `RAG_DB_PATH` (default: `rag_store`)
- `RAG_COLLECTION` (default: `policy_rules`)
- `RAG_TOP_K` (default: `3`)
![Tests](https://github.com/your-username/Secure_PII_Redaction_System/actions/workflows/tests.yml/badge.svg)

A secure AI-powered system that automatically detects and redacts sensitive Personal Identifiable Information (PII) from documents before sharing.

This project supports text files, images, and scanned documents using OCR, Regex, and Named Entity Recognition (NER).

---

## 📌 Features

- 📄 Supports `.txt`, `.pdf`, `.png`, `.jpg`, `.jpeg`, `.docx`
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
Text Extraction (OCR / File Reader / PDF Pages)
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
└── outputs/ (optional)
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

After installation, set an environment variable:

```bash
setx TESSERACT_CMD "C:\Program Files\Tesseract-OCR\tesseract.exe"
```
Or configure it in `config.toml` (see below).

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
  "redacted_text": "Name: ██████\nAadhaar: ********9012\nPAN: ******1234F\nPhone: ******3210\nEmail: *****n@gmail.com"
}
```

---

## 🔍 Supported PII Types

- Aadhaar Number (4-4-4 format)
- PAN Card Number
- Phone Numbers
- Email Addresses
- Driving License (basic pattern)
- Address (label-based pattern)
- Named Entities (via NER)

---

## ⚠️ Limitations

- OCR accuracy depends on image quality
- Handwritten documents may reduce detection accuracy
- Some redaction is rule-based (policy engine)
- PDF OCR requires Poppler to be installed and available on PATH

---

## ⚙️ Configuration

Configuration is loaded from `config.toml` with environment variable overrides.

Environment overrides:
- `APP_ALLOWED_EXTENSIONS` (comma-separated list)
- `APP_ALLOWED_CONTENT_TYPES` (comma-separated list)
- `APP_UPLOADS_DIR`
- `APP_OUTPUT_DIR`
- `APP_ENABLE_CONFIG_DEBUG` (true/false)
- `APP_MAX_UPLOAD_MB` (int)
- `APP_ENABLE_RAG_STUB` (true/false)
- `RAG_VECTORDB_URL`
- `RAG_VECTORDB_API_KEY`
- `APP_ENCRYPTION_ENABLED` (true/false)
- `APP_ENCRYPTION_KEY` (AES-256-GCM base64 key)
- `APP_ENABLE_DECRYPT_ENDPOINT` (true/false)
- `APP_ADMIN_TOKEN`
- `APP_API_TOKEN` (required for protected endpoints if set)
- `APP_RESET_TOKEN_TTL_MINUTES`
- `OCR_TESSERACT_CMD`
- `OCR_USE_PREPROCESS` (true/false)
- `OCR_PDF_DPI` (int)
- `NER_MODEL_PATH`
- `DB_URL` (e.g., `mysql+mysqlconnector://pii_user:password@localhost:3306/secure_pii_db`)
- `DB_ECHO` (true/false)
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USER`
- `SMTP_PASSWORD`
- `SMTP_FROM`
- `SMTP_USE_TLS`
You can also set these in a `.env` file (see `.env.example`).

Example `config.toml`:

```toml
[app]
allowed_extensions = [".txt", ".pdf", ".png", ".jpg", ".jpeg", ".docx"]
allowed_content_types = [
  "text/plain",
  "application/pdf",
  "image/png",
  "image/jpeg",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
]
uploads_dir = "uploads"
output_dir = "outputs"
enable_config_debug = false
max_upload_mb = 10
enable_rag_stub = false
rag_vectordb_url = ""
rag_vectordb_api_key = ""
encryption_enabled = false
encryption_key = ""
enable_decrypt_endpoint = false
admin_token = ""

[ocr]
tesseract_cmd = "C:\\Program Files\\Tesseract-OCR\\tesseract.exe"
use_preprocess = true
pdf_dpi = 200

[ner]
model_path = "custom_pii_model"

[db]
url = "mysql+mysqlconnector://pii_user:password@localhost:3306/secure_pii_db"
echo = false

[security]
api_token = ""
user_token_ttl_minutes = 1440
reset_token_ttl_minutes = 30

[smtp]
host = ""
port = 587
user = ""
password = ""
from = ""
use_tls = true
```

---

## 📄 PDF Output

You can request a redacted PDF by passing `return_pdf=true` to the `/process/` endpoint.

---

## ✅ Health & Config

- `GET /health` returns `{ "status": "ok" }`
- `GET /config` is only enabled when `APP_ENABLE_CONFIG_DEBUG=true`
- `GET /logs` returns recent redaction history with filters + pagination (requires `APP_API_TOKEN` if set and `APP_ADMIN_TOKEN` if set).
  Query params: `limit`, `offset`, `filename`, `pii_type`, `date_from`, `date_to`, `sort_by` (`created_at`, `size_bytes`, `total_pii`, `filename`), `sort_dir` (`asc`/`desc`), `token`.
- `GET /logs/{id}` returns a single log entry
- `user_token` (optional) scopes `/logs` and `/logs/{id}` to a specific user

---

## 🧰 Upload Validation

- File extensions are validated against `allowed_extensions`
- Content types are validated against `allowed_content_types`
- Max upload size defaults to 10 MB (`APP_MAX_UPLOAD_MB`)

---

## 🔐 Encryption (Optional)

When `APP_ENCRYPTION_ENABLED=true`, uploaded files are stored encrypted using AES-256-GCM.
Generate a key in Python:

```python
from encryption import generate_key
print(generate_key())
```

---

## 🔓 Decrypt Endpoint (Admin Only)

Enable by setting `APP_ENABLE_DECRYPT_ENDPOINT=true` and `APP_ADMIN_TOKEN`.
Request:
`GET /decrypt?filename=<stored_filename>&token=<admin_token>`

If `APP_API_TOKEN` is set, pass the same `token` param with the API token.

---

## 🗄️ MySQL Setup

1. Create database and user (example):

```sql
CREATE DATABASE secure_pii_db;
CREATE USER 'pii_user'@'localhost' IDENTIFIED BY 'StrongPass123';
GRANT ALL PRIVILEGES ON secure_pii_db.* TO 'pii_user'@'localhost';
FLUSH PRIVILEGES;
```

2. Configure environment:

```
DB_URL=mysql+mysqlconnector://pii_user:StrongPass123@localhost:3306/secure_pii_db
DB_ECHO=false
```

3. Run migration (creates tables):

```bash
python migrate_db.py
```

---

## 👤 User Accounts (Simple)

Create an account:

```bash
POST /auth/register
{ "username": "alice", "password": "StrongPass123!", "email": "alice@example.com" }
```

Login:

```bash
POST /auth/login
{ "username": "alice", "password": "StrongPass123" }
```

Response includes a `token` (user token). Use it as `user_token`:

```
POST /process/?user_token=<token>
GET /logs?user_token=<token>
GET /logs/{id}?user_token=<token>
```

Logout or change password:

```bash
POST /auth/logout?user_token=<token>
POST /auth/change-password?user_token=<token>
{ "old_password": "...", "new_password": "..." }
```

Admin reset password:

```bash
POST /auth/reset-password?token=<admin_token>
{ "username": "alice", "new_password": "..." }
```

Token expiry:
- Tokens expire after `APP_USER_TOKEN_TTL_MINUTES` (default 1440 minutes).

Password rules:
- Minimum 8 characters
- At least 1 uppercase, 1 lowercase, 1 number, 1 special character

Email reset flow (SMTP):

1. Request a reset token:

```bash
POST /auth/forgot-password
{ "email": "alice@example.com" }
```

2. Reset with token:

```bash
POST /auth/reset-password-token
{ "token": "<token>", "new_password": "StrongPass123!" }
```

SMTP configuration (set in `.env` or `config.toml`):

```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your_email@gmail.com
SMTP_PASSWORD=your_app_password
SMTP_FROM=your_email@gmail.com
SMTP_USE_TLS=true
```

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
