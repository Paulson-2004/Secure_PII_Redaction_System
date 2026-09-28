# PrivLock AI — Backend & Application Engine

[![Flutter](https://img.shields.io/badge/Flutter-Client-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Flask](https://img.shields.io/badge/Flask-API-000000?logo=flask&logoColor=white)](https://flask.palletsprojects.com/)
[![Python](https://img.shields.io/badge/Python-3.11%2B%20%7C%203.14.7%20Verified-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![MySQL](https://img.shields.io/badge/MySQL-8.x-4479A1?logo=mysql&logoColor=white)](https://www.mysql.com/)

This directory contains the core application implementation:

- **Flutter Client**: Cross-platform frontend for authentication, document upload, redaction visualization, and audit trail management.
- **Flask REST API**: Backend server orchestrating OCR, PII detection, regulatory policy retrieval and decisioning, and document redaction.
- **AI Redaction Pipeline**: Modular engines for single-pass OCR, checksum-validated regex, spaCy NER, semantic hybrid fusion, regulatory policy retrieval/decisioning, and bounding-box/offset redaction.

## Folder Overview

```text
PII/
├── app.py                  # Flask REST API server entry point
├── auth.py                 # Authentication, bcrypt hashing, and session management
├── config.py               # Central environment configuration loader
├── database.py             # MySQL connection pool with SQLite fallback
├── schema.sql              # Idempotent baseline MySQL schema
├── utils.py                # Security sanitizers and path normalization
├── requirements.txt        # Backend dependencies (Python 3.11+ supported, 3.14.7 verified)
├── pubspec.yaml            # Flutter project specification
├── pubspec.lock            # Locked Dart dependencies
├── analysis_options.yaml   # Flutter strict static analysis configuration
├── vercel.json             # Vercel SPA routing and security configuration
├── Dockerfile              # Production container specification
├── docker-compose.yml      # Local MySQL 8.0 orchestration stack
├── README.md               # App-level technical guide (this file)
├── RUNNING_GUIDE.md        # Comprehensive execution instructions
├── TESTING_GUIDE.md        # Complete testing and verification manual
├── assets/                 # App branding, icons, and shield graphics
├── lib/                    # Flutter Dart source code (UI, state, services)
├── modules/                # AI redaction pipeline
│   ├── ocr_engine.py       # Tesseract OCR & OpenCV preprocessing
│   ├── regex_detector.py   # Pattern detection with Verhoeff/Luhn checksums
│   ├── ner_detector.py     # SpaCy contextual entity recognition
│   ├── hybrid_engine.py    # Semantic fusion & conflict resolution
│   ├── rag_decision_engine.py # Regulatory policy retrieval & decision engine
│   └── redaction_engine.py # Precision bounding box & text slicing
├── test/                   # Flutter widget test suite
├── tests/                  # Backend unit, security, and E2E test suites
├── web/                    # Flutter Web index and PWA configuration
├── android/                # Android native platform files
└── windows/                # Windows desktop runner
```

## Prerequisites

- **Python**: Python 3.11+ supported (Verified development/test baseline: Python 3.14.7)
- **Flutter SDK**: 3.x+
- **Database**: MySQL 8.x (Optional: If MySQL is offline, the backend automatically falls back to an embedded SQLite database `privlock.db`)
- **Tesseract OCR**: Installed and accessible (default path `C:\Program Files\Tesseract-OCR\tesseract.exe` or configured via `TESSERACT_CMD` in `.env`)
- **PyMuPDF**: Modern `pymupdf` library for PDF rendering

## Setup Instructions

### 1. Configure Environment

```bash
copy .env.example .env
```

Update `.env` with your local database credentials. If MySQL is not configured, the backend seamlessly operates using the embedded SQLite fallback.

### 2. Install Backend Dependencies

```bash
# Ensure Python 3.11+ is active (verified on Python 3.14.7)
python -m venv venv

# Windows Activation
venv\Scripts\activate

# Install Dependencies
pip install -r requirements.txt
python -m spacy download en_core_web_sm
```

### 3. Install Flutter Dependencies

```bash
flutter pub get
```

### 4. Run Backend

```bash
python app.py
```

Health check endpoint:
```text
http://127.0.0.1:5000/api/health
```

### 5. Run Flutter Web Client

```bash
flutter run -d edge --dart-define=API_BASE_URL=http://127.0.0.1:5000 --web-port=5080
```
*(PrivLock AI is browser-agnostic: use `-d edge`, `-d chrome`, or access the URL in any modern browser including Microsoft Edge, Google Chrome, Mozilla Firefox, or Apple Safari).*

### 6. Run on Android Mobile

For an Android emulator:
```bash
flutter run -d android
```

For a physical device on the same local network:
```bash
flutter run -d android --dart-define=API_BASE_URL=http://<your-pc-ip>:5000
```

Release APK generation:
```bash
flutter build apk --release --dart-define=API_BASE_URL=http://<your-pc-ip>:5000
```

## API Summary

- `POST /login` and `POST /register`: User authentication and JWT/session management.
- `POST /api/process`: Document upload, AI detection, policy evaluation, and redacted file generation.
- `GET /api/health`: Health diagnostics, database connectivity, and AI module status.
- `GET /audit-logs`: Tenant-isolated document processing history.
- `GET /api/download/<filename>`: Secure path-validated download of redacted documents.
- `GET /api/preview/<filename>`: Secure path-validated visual/text preview of redacted documents (strict ownership validation; unredacted files rejected).

## Cloud Deployment (Free Tier: Vercel + Render)

PrivLock is architected for free-tier cloud deployment:
- **Backend**: Render Free Web Service (or Blueprint via `../render.yaml`), running Gunicorn (`gunicorn app:app --bind 0.0.0.0:$PORT --workers 1 --threads 4 --timeout 120`) with `USE_SQLITE=true` and `FLASK_ENV=production`.
- **Frontend**: Vercel Static Hosting. Because standard Vercel environments lack the Flutter SDK, build the web bundle locally (`flutter build web --release --dart-define=API_BASE_URL=https://<your-actual-render-url>`) and deploy the static artifact directly (`npx vercel deploy build/web --prod`), or configure a GitHub Actions CI workflow to build and push to Vercel. SPA rewrites and caching are managed by `web/vercel.json`.

## Guides & Documentation

- [RUNNING_GUIDE.md](RUNNING_GUIDE.md): Detailed local and cloud execution instructions.
- [TESTING_GUIDE.md](TESTING_GUIDE.md): Full regression and test suite procedures.

## Operational Notes

- Client service communication is centralized in [lib/services/api_service.dart](lib/services/api_service.dart).
- Mobile devices connect to the host IP rather than `localhost`.
- Generated runtime directories (`uploads/`, `uploads/redacted/`, `build/`, and `venv/`) are excluded from version control via `.gitignore`.
