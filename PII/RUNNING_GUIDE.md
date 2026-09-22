# Running Guide

This repository contains:
- **Flutter frontend** (Mobile & Web) in `PII/`
- **Flask REST API backend** with AI Redaction Pipeline in `PII/`

## Prerequisites

- Python 3.10+
- Flutter SDK (3.x+)
- MySQL Server (Optional: If MySQL is not running, the backend automatically activates an embedded SQLite fallback database `privlock.db`)
- Tesseract OCR (Windows: standard path `C:\Program Files\Tesseract-OCR\tesseract.exe` or configured via `TESSERACT_CMD` in `.env`)

## Backend Setup

1. Open terminal 1.
2. Navigate to `PII`:

```bash
cd PII
python -m venv .venv
# On Windows:
.\.venv\Scripts\activate
# On Linux/macOS:
# source .venv/bin/activate
pip install -r requirements.txt
python -m spacy download en_core_web_sm
```

3. Configure environment:
```bash
copy .env.example .env
```
*(If MySQL is running locally, ensure credentials in `.env` match. If offline, the backend seamlessly falls back to local SQLite).*

4. Start backend:

```bash
python app.py
```

Backend URL:
- `http://127.0.0.1:5000`

Health check:
- `http://127.0.0.1:5000/api/health`

## Frontend Setup (Web)

1. Open terminal 2.
2. Navigate to `PII`:

```bash
cd PII
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:5000 --web-port=5080
```

Frontend URL:
- `http://localhost:5080`

## Frontend Setup (Android Mobile)

### Android Emulator

Run the app directly:

```bash
flutter run -d android
```

### Physical Android Phone

1. Connect the phone over USB or keep it on the same Wi-Fi network as the backend.
2. Start the backend on a machine reachable from the phone.
3. Run:

```bash
flutter run -d android --dart-define=API_BASE_URL=http://<your-pc-ip>:5000
```

### Release APK

```bash
flutter build apk --release --dart-define=API_BASE_URL=http://<your-pc-ip>:5000
```

## Recommended Run Order

1. Start MySQL.
2. Start backend and confirm `/api/health` is success.
3. Start Flutter frontend for web or Android.
4. Open the web app at `http://localhost:5080`, or install/run the Android build on your phone.

## Browser Notes / White Screen Fix

- Hard refresh: `Ctrl + Shift + R`
- If still blank:
  1. Stop Flutter (`Ctrl + C`)
  2. Run `flutter clean`
  3. Run frontend command again
  4. Open a fresh tab at `http://localhost:5080`
- On web, fingerprint login is disabled (mobile-only plugin).
- On web, upload/download uses browser-safe byte handling.
