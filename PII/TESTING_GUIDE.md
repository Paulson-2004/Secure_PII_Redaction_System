# Testing Guide

Use this checklist and test suite to verify the application end-to-end.

## Automated Checks

### 1. Flutter Static Analysis & Unit Tests
Run from the `PII/` directory:

```bash
cd PII
flutter analyze
flutter test
```

### 2. Backend Automated Test Suite
Run 34 comprehensive backend unit, security, and end-to-end pipeline tests:

```bash
cd PII
python -m unittest discover tests
```

*Modules verified by automated tests:*
- `tests/test_regex_detector.py`: Verhoeff Aadhaar validation, Luhn credit card validation, PAN, IFSC, phone, email patterns.
- `tests/test_hybrid_fusion.py`: Multi-engine fusion, semantic entity compatibility, bounding box synchronization.
- `tests/test_redaction_engine.py`: Sequence-aware image redaction, non-destructive offset slicing, partial masking.
- `tests/test_rag_engine.py`: Regulatory retrieval across 15 frameworks (DPDP Act 2023, Aadhaar Act 2016, IT Act, PCI-DSS) with TF-IDF fallback.
- `tests/test_api_security.py`: JWT auth, password hashing, SQL injection defenses, path traversal protection, CORS.
- `tests/test_end_to_end_pipeline.py`: Full end-to-end lifecycle from registration to document upload, hybrid redaction, audit logging, and download.

### 3. Backend Smoke Test & Health Check

```bash
python app.py
```

Health check verification:
```bash
curl http://127.0.0.1:5000/api/health
```

## Manual UI Test Flow

### Web

### 1. Register

- Open `http://localhost:5080`
- Create a new account
- Confirm you move forward to the security setup screen

### 2. Login

- Sign in with the account you created
- Confirm the dashboard loads

### 3. Set PIN

- Enter a 4 to 6 digit PIN
- Confirm the PIN saves successfully
- If fingerprint is shown in desktop/mobile, you can skip it on web

### 4. Upload and Process a Document

- Select `Aadhaar Card` or another document type
- Upload an image from the dataset or your own test document
- Click `Process Document`
- Confirm the result screen shows PII count, redaction summary, and detected PII types

### 5. Download Redacted File

- On the result screen, click `Download`
- Confirm the browser downloads the redacted file successfully

### 6. Audit Logs

- Open the audit logs screen from the drawer
- Confirm the processing event appears in the list

## Expected Results

- Backend health returns `success: true`
- Login/register work without CORS or fetch errors
- PIN setup works in Chrome
- Upload works in Chrome using browser-safe byte uploads
- Download works in Chrome using browser-safe download handling
- AI redaction produces a processed file and result summary

## Android Mobile Smoke Test

1. Start the backend on a reachable IP address.
2. Launch the app with `flutter run -d android --dart-define=API_BASE_URL=http://<your-pc-ip>:5000`.
3. Register and log in on the phone.
4. Set PIN and verify fingerprint setup if the device supports it.
5. Upload a test document from the phone gallery or files app.
6. Process the document and confirm the redacted output screen loads.
7. Download or share the processed file if your Android version allows it.

## Common Issues

| Problem | Likely Cause | Fix |
|---------|--------------|-----|
| White screen | Stale web session or old build | Hard refresh the browser |
| Failed to fetch | Backend not running or CORS issue | Check backend port 5000 and refresh |
| Download failed | Old browser session | Hard refresh and try again |
| Upload unsupported | Wrong build path or old frontend code | Restart the frontend and reselect the file |

## Quick End-to-End Smoke Test

1. Start backend and frontend.
2. Register a test user.
3. Login.
4. Set PIN.
5. Upload a test Aadhaar image.
6. Process document.
7. Download the redacted output.
