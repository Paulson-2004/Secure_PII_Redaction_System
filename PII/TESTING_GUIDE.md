# Testing Guide — PrivLock AI

Use this verification guide and automated test suite to validate the application end-to-end.

---

## Verified Baseline Results

The following test suites and quality gates have been executed and verified on the codebase:

| Verification Stage | Command | Result | Details |
|---|---|---|---|
| **Backend Unit & Security** | `python -m unittest discover tests` | **PASS** | 34/34 tests passed |
| **End-to-End Pipeline** | `python -m unittest tests.test_end_to_end_pipeline` | **PASS** | 2/2 tests passed |
| **Flutter Static Analysis** | `flutter analyze lib` | **PASS** | 0 warnings, 0 errors, 0 lints |
| **Flutter Widget Tests** | `flutter test` | **PASS** | All tests passed |
| **Flutter Production Web** | `flutter build web --release` | **PASS** | `build/web` generated cleanly |
| **Launcher First Run** | `run_privlock.bat` | **PASS** | Created venv, started backend & web browser |
| **Launcher Second Run** | `run_privlock.bat` | **PASS** | Reused venv, skipped reinstall, started |
| **Stop Script** | `scripts/stop_privlock.bat` | **PASS** | Clean window-targeted shutdown |
| **MySQL Connectivity** | Health check | **PASS** | Connected to `pii_redaction_system` pool |
| **SQLite Fallback** | `USE_SQLITE=true` | **PASS** | Automated fallback to `privlock.db` |

---

## Automated Checks

### 1. Flutter Static Analysis & Unit Tests

Run from the `PII/` directory:

```bash
cd PII
flutter analyze lib
flutter test
```

### 2. Backend Automated Test Suites

Ensure your virtual environment is active (`venv\Scripts\activate` on Windows) before running tests:

#### Full Unit & Security Suite (34 Tests)
```bash
python -m unittest discover tests
```

*Test suites verified:*
- `tests/test_regex_detector.py`: Verhoeff Aadhaar validation, Luhn credit card validation, PAN, IFSC, phone, email patterns.
- `tests/test_hybrid_fusion.py`: Multi-engine fusion, semantic entity compatibility, bounding box synchronization.
- `tests/test_redaction_engine.py`: Sequence-aware image redaction, non-destructive offset slicing, partial masking.
- `tests/test_rag_engine.py`: Regulatory Policy Retrieval & Decision Engine across 15 frameworks (DPDP Act 2023, Aadhaar Act 2016, IT Act, PCI-DSS) with TF-IDF fallback.
- `tests/test_api_security.py`: Token authentication, password hashing, SQL injection defenses, path traversal protection, tenant isolation.

#### End-to-End Pipeline Suite (2 Tests)
```bash
python -m unittest tests.test_end_to_end_pipeline
```
Verifies full document lifecycle: registration $\rightarrow$ login $\rightarrow$ upload $\rightarrow$ OCR $\rightarrow$ detection $\rightarrow$ policy decision $\rightarrow$ visual/text redaction $\rightarrow$ audit trail logging.

### 3. Backend Health Diagnostic

Start the backend:
```bash
python app.py
```

Query the health diagnostic endpoint:
```bash
curl http://127.0.0.1:5000/api/health
```

Expected JSON response:
```json
{
  "data": {
    "backend": "running",
    "database": "connected",
    "database_engine": "MySQL",
    "ai": {
      "loaded": true,
      "ocr": { "loaded": true },
      "regex": { ... },
      "ner": { "status": "LOADED" },
      "hybrid": { "loaded": true },
      "rag": { "total_policies": 15, "rag_enabled": true },
      "redaction": { "loaded": true }
    }
  },
  "success": true
}
```

---

## Manual UI Verification Flow

### Web Testing Flow (Any Modern Browser: Edge, Chrome, Firefox, Safari)

1. **User Registration**:
   - Access `http://localhost:5080`.
   - Register a new test account.
   - Confirm progression to the security setup screen.
2. **User Authentication**:
   - Sign in using the registered credentials.
   - Confirm the main dashboard renders cleanly.
3. **Security PIN Configuration**:
   - Configure a 4 to 6 digit security PIN.
   - Confirm PIN persistence (skip biometric enrollment on Web).
4. **Document Processing**:
   - Select document type (e.g. `Aadhaar Card`, `PAN Card`, or raw text).
   - Upload a test document image or PDF.
   - Click **Process Document**.
   - Confirm detection summary: PII count, policy reference, and detected entity types.
5. **Redacted Document Download**:
   - Click **Download** on the results panel.
   - Confirm the browser downloads the redacted file successfully.
6. **Audit Trail Verification**:
   - Open the **Audit Logs** screen from the navigation drawer.
   - Confirm that the processing event is recorded with timestamp and tenant isolation.

---

## Expected Behavioral Results

- Backend health check returns HTTP 200 with `success: true`.
- Authentication flow operates without CORS or network errors.
- PIN setup and session handling function cleanly in the browser.
- Document upload executes using browser-safe raw byte streams.
- Redacted file downloads cleanly without path traversal or corrupted formats.
- AI pipeline accurately detects sensitive data and applies precision masking.

---

## Troubleshooting Reference

| Symptom | Probable Cause | Corrective Action |
|---|---|---|
| **White Screen in Browser** | Stale cached assets | Perform hard refresh (`Ctrl + Shift + R`) or run `flutter clean` |
| **Failed to Fetch (API)** | Backend not running or wrong port | Verify backend is active on `http://127.0.0.1:5000/api/health` |
| **Download Failed** | Invalid filename or session timeout | Re-login and download the file from the audit log |
| **MySQL Connection Refused** | MySQL service stopped | Start MySQL service or allow automatic fallback to SQLite `privlock.db` |
