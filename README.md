# Secure PII Redaction System (Monorepo)

This repository contains both the backend (FastAPI) and the Android frontend.

## Structure
- `backend/` — FastAPI API, OCR, PII detection, redaction, tests
- `android-app/` — Android Studio project
- `docs/` — API contract and notes

## Quick Start (Backend)
```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
python -m pip install -r requirements.txt
python -m uvicorn main:app --reload
```

See `backend/README.md` for full backend documentation and configuration.
See `docs/api.md` for the API contract used by the Android app.
See `android-app/README.md` for Android build and run steps.
