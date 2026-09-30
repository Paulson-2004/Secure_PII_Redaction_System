# PrivLock Application Core — Backend & Frontend Engine

This directory contains the core application source code for PrivLock:
- **Flask REST API**: Python backend exposing document ingestion, AI-driven PII detection, regulatory policy decisioning, and precision redaction endpoints.
- **Flutter Client**: Cross-platform Material 3 user interface supporting Web and Android with guest mode and manual redaction studio.
- **AI Redaction Pipeline**: 6-stage hybrid pipeline in `modules/`.

For complete system documentation, architecture diagrams, and operational guides, refer to the [Root README](../README.md) and the [`docs/`](../docs/) directory.

---

## Directory Overview

```text
PII/
├── app.py                  # Flask REST API server & routing entry point
├── auth.py                 # Authentication, bcrypt hashing, and session management
├── config.py               # Environment configuration loader
├── database.py             # Multi-engine database manager (PostgreSQL, MySQL, SQLite)
├── schema.sql              # Relational database schema
├── utils.py                # Security sanitizers and safe_join path normalization
├── requirements.txt        # Python backend dependencies (Python 3.11+ supported, 3.14.7 verified)
├── .env.example            # Backend environment configuration template
├── pubspec.yaml            # Flutter project specification
├── pubspec.lock            # Locked Dart dependencies
├── analysis_options.yaml   # Flutter strict static analysis rules
├── vercel.json             # Vercel SPA routing and security headers
├── Dockerfile              # Production container build specification
├── docker-compose.yml      # Local MySQL 8.0 orchestration stack
├── assets/                 # App icons, logos, and UI graphics
├── lib/                    # Flutter Dart source code (UI, state, services)
│   ├── models/             # Data models (ImageDisplayGeometry, PdfPageGeometry, etc.)
│   ├── screens/            # Application screens (Dashboard, Redaction Studio, Result, Audit)
│   ├── services/           # Centralized API service & state providers
│   └── widgets/            # Custom UI widgets and dialogs
├── modules/                # AI Redaction Pipeline
│   ├── ocr_engine.py       # Tesseract OCR & OpenCV preprocessing
│   ├── regex_detector.py   # Pattern detection with Verhoeff/Luhn checksums
│   ├── ner_detector.py     # SpaCy contextual entity recognition
│   ├── hybrid_engine.py    # Semantic fusion & conflict resolution
│   ├── rag_decision_engine.py # 29-source policy retrieval & decision engine
│   └── redaction_engine.py # Precision bounding box masking & text slicing
├── test/                   # Flutter widget & unit test suite (29 tests)
├── tests/                  # Backend unit, security, and E2E test suites (80 tests)
├── web/                    # Flutter Web index and PWA configuration
├── android/                # Android native embedding
└── windows/                # Windows native runner
```

---

## Quick Reference Commands

### Backend Execution
```bash
# 1. Activate virtual environment (Python 3.11+ supported, 3.14.7 verified):
venv\Scripts\activate   # Windows
# source venv/bin/activate # Linux/macOS

# 2. Run backend API:
python app.py

# 3. Health check diagnostic:
curl http://127.0.0.1:5000/api/health
```

### Frontend Execution (Web)
```bash
flutter pub get
flutter run -d edge --dart-define=API_BASE_URL=http://127.0.0.1:5000 --web-port=5080
```

### Test Verification
```bash
# Backend automated test suite (80 tests):
python -m unittest discover tests

# Flutter static code analysis:
flutter analyze lib test

# Flutter test suite (29 tests):
flutter test

# Production release web build:
flutter build web --release
```

---

## Technical Documentation Links

- 📖 [System Architecture & Pipeline](../docs/ARCHITECTURE.md)
- 🛠️ [Complete Setup Guide (Windows, Linux, macOS, Android)](../docs/SETUP.md)
- 🧪 [Testing & Quality Assurance Guide](../docs/TESTING.md)
- ☁️ [Cloud Deployment Guide (Vercel, Render, Neon)](../docs/DEPLOYMENT.md)
- 🛡️ [Security, Authentication & Guest Mode Isolation](../docs/SECURITY.md)
- ✂️ [Redaction Modes, Coordinate Geometry & PDF Parser](../docs/REDACTION.md)
- 📜 [29-Source Regulatory Policy Knowledge Base](../docs/POLICY_CORPUS.md)
- 🔧 [Troubleshooting & Diagnostics](../docs/TROUBLESHOOTING.md)
