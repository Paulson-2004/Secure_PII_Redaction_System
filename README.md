# PII Fullstack Redaction Platform

![PII Fullstack Banner](.github/assets/banner.svg)

[![GitHub Stars](https://img.shields.io/github/stars/Da-ya7/PII_FULLSTACK?style=for-the-badge&logo=github)](https://github.com/Da-ya7/PII_FULLSTACK/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/Da-ya7/PII_FULLSTACK?style=for-the-badge&logo=github)](https://github.com/Da-ya7/PII_FULLSTACK/network/members)
[![GitHub Issues](https://img.shields.io/github/issues/Da-ya7/PII_FULLSTACK?style=for-the-badge&logo=github)](https://github.com/Da-ya7/PII_FULLSTACK/issues)
[![Last Commit](https://img.shields.io/github/last-commit/Da-ya7/PII_FULLSTACK?style=for-the-badge&logo=git)](https://github.com/Da-ya7/PII_FULLSTACK/commits/main)

[![GitHub Repo](https://img.shields.io/badge/repo-PII__FULLSTACK-181717?logo=github)](https://github.com/Da-ya7/PII_FULLSTACK)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Python](https://img.shields.io/badge/Python-3.10%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Flask](https://img.shields.io/badge/Flask-Backend-000000?logo=flask&logoColor=white)](https://flask.palletsprojects.com/)
[![MySQL](https://img.shields.io/badge/MySQL-8.x-4479A1?logo=mysql&logoColor=white)](https://www.mysql.com/)

Production-style fullstack system for detecting and redacting Personally Identifiable Information from document images using a hybrid AI pipeline.

## Why This Project

- End-to-end workflow: authentication, upload, detection, decisioning, and redacted output.
- Multi-stage AI pipeline: OCR + regex + NER + policy-aware decisions.
- Fullstack delivery: Flutter client and Flask backend in one repository.
- Audit-focused: redaction results and processing logs are available in the app.

## Repository Structure

```text
PII_FULLSTACK/
├─ PII/                     # Main application
│  ├─ lib/                  # Flutter app (UI + state + services)
│  ├─ modules/              # AI pipeline modules (OCR, regex, NER, hybrid, RAG, redaction)
│  ├─ app.py                # Flask backend entry point
│  ├─ requirements.txt      # Python dependencies
│  ├─ pubspec.yaml          # Flutter dependencies
│  ├─ RUNNING_GUIDE.md
│  └─ TESTING_GUIDE.md
├─ README.md                # This file
└─ LICENSE
```

## System Architecture

```text
Flutter Client
	|
	| HTTP API
	v
Flask Backend (app.py)
	|
	+--> OCR Engine (Tesseract + OpenCV)
	+--> Regex Detector
	+--> NER Detector (SpaCy)
	+--> Hybrid Fusion Engine
	+--> Policy Decision Engine (RAG/FAISS fallback-aware)
	+--> Redaction Engine (text + image)
	|
	+--> MySQL (users, auth, audit logs)
```

## Quick Start

### 1. Clone

```bash
git clone https://github.com/Da-ya7/PII_FULLSTACK.git
cd PII_FULLSTACK/PII
```

### 2. Backend Setup

```bash
python -m venv .venv
# Windows
.venv\Scripts\activate
pip install -r requirements.txt
python -m spacy download en_core_web_sm
```

### 3. Environment Configuration

```bash
copy .env.example .env
```

Update `.env` with your local configuration values.

### 4. Start Backend

```bash
python app.py
```

Backend health endpoint:

```text
http://127.0.0.1:5000/api/health
```

### 5. Start Flutter Web Client

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:5000 --web-port=5080
```

Client URL:

```text
http://localhost:5080
```

## Core Features

- Secure user registration/login.
- Document upload and processing from Flutter UI.
- OCR extraction with bounding boxes.
- Structured PII detection via regex patterns.
- Contextual PII detection via NER.
- Hybrid confidence-aware fusion.
- Policy-driven action (full redact, partial mask, keep).
- Downloadable redacted results.
- Audit history for processed files.

## Tech Stack

- Frontend: Flutter, Provider, Material 3
- Backend: Flask, Flask-CORS, bcrypt
- AI/NLP: Tesseract OCR, OpenCV, SpaCy, sentence-transformers, FAISS
- Data: MySQL

## Documentation

- App-level README: [PII/README.md](PII/README.md)
- Runtime guide: [PII/RUNNING_GUIDE.md](PII/RUNNING_GUIDE.md)
- Testing guide: [PII/TESTING_GUIDE.md](PII/TESTING_GUIDE.md)

## Security Notes

- `.env`, local uploads, generated build artifacts, and dataset folders are ignored via `.gitignore`.
- Use non-production credentials locally and rotate secrets before deployment.

## License

Licensed under MIT. See [LICENSE](LICENSE).
