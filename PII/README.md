# PII Application

[![Flutter](https://img.shields.io/badge/Flutter-Client-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Flask](https://img.shields.io/badge/Flask-API-000000?logo=flask&logoColor=white)](https://flask.palletsprojects.com/)
[![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![MySQL](https://img.shields.io/badge/MySQL-8.x-4479A1?logo=mysql&logoColor=white)](https://www.mysql.com/)

This folder contains the complete app implementation:

- Flutter frontend for authentication, upload, result visualization, and audit logs.
- Flask backend that orchestrates OCR, PII detection, policy decisions, and redaction.
- AI modules for regex, NER, hybrid fusion, and policy-aware redaction decisions.

## Folder Overview

```text
PII/
├─ lib/                     # Flutter client
├─ modules/                 # AI engines and redaction pipeline
├─ app.py                   # Flask API server
├─ auth.py                  # Authentication logic
├─ database.py              # DB connection and helpers
├─ config.py                # Environment-driven configuration
├─ requirements.txt         # Backend dependencies
├─ pubspec.yaml             # Flutter dependencies
├─ schema.sql               # Database schema
├─ RUNNING_GUIDE.md
└─ TESTING_GUIDE.md
```

## Prerequisites

- Python 3.10+
- Flutter SDK
- MySQL 8+
- Tesseract OCR installed and accessible

## Setup

### 1. Configure Backend Environment

```bash
copy .env.example .env
```

Update `.env` values for your machine.

### 2. Install Backend Dependencies

```bash
python -m venv .venv
# Windows
.venv\Scripts\activate
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

Health check:

```text
http://127.0.0.1:5000/api/health
```

### 5. Run Frontend

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:5000 --web-port=5080
```

### 6. Run on Android Mobile

For an Android emulator:

```bash
flutter run -d android
```

For a physical phone, start the backend on a network-accessible host and pass that URL:

```bash
flutter run -d android --dart-define=API_BASE_URL=http://<your-pc-ip>:5000
```

If you want an installable build:

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://<your-pc-ip>:5000
```

## API Summary

- `POST /login` and `POST /register` for account flow.
- `POST /api/process` for upload and PII redaction.
- `GET /api/health` for service health and AI module status.
- `GET /audit-logs` for processing history.

## Development Guides

- [RUNNING_GUIDE.md](RUNNING_GUIDE.md)
- [TESTING_GUIDE.md](TESTING_GUIDE.md)

## Notes

- Client service layer is implemented in [lib/services/api_service.dart](lib/services/api_service.dart).
- The mobile app can talk to the Flask backend directly; a physical device needs the backend host IP, not `localhost`.
- Runtime output folders (uploads/redacted) and local env files are git-ignored.
