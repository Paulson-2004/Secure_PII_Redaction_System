# Troubleshooting & Diagnostics Guide — PrivLock

This guide provides troubleshooting solutions for common local development, configuration, network, and production issues across PrivLock.

---

## 1. Quick Diagnostic Checklist

When encountering an unexpected behavior, verify the stack in this order:

```mermaid
flowchart TD
    Step1{"1. Is Backend Running?"} -->|"No"| Fix1["Start backend: cd PII && python app.py"]
    Step1 -->|"Yes"| Step2{"2. Health Check returns 200 OK?<br/>curl http://127.0.0.1:5000/api/health"}

    Step2 -->|"No"| Fix2["Inspect PII/app.py console for startup exceptions"]
    Step2 -->|"Yes"| Step3{"3. Is Database Connected?"}

    Step3 -->|"No"| Fix3["Check MySQL service or set USE_SQLITE=true in PII/.env"]
    Step3 -->|"Yes"| Step4{"4. Is Frontend Running?"}

    Step4 -->|"No"| Fix4["Start Flutter: flutter run -d edge --dart-define=API_BASE_URL=..."]
    Step4 -->|"Yes"| Step5["Ready: Access http://localhost:5080"]
```

---

## 2. Common Issues & Solutions

### A. Python & Virtual Environment

#### `ModuleNotFoundError: No module named 'flask'` (or `spacy`, `fitz`, etc.)
- **Cause**: The Python virtual environment is not activated, or dependencies were not installed into the active virtual environment.
- **Solution**:
  ```bash
  cd PII
  # Activate venv
  venv\Scripts\activate   # Windows
  # source venv/bin/activate # Linux/macOS

  # Re-install dependencies
  pip install -r requirements.txt
  python -m spacy download en_core_web_sm
  ```

#### `Can't find model 'en_core_web_sm'`
- **Cause**: The spaCy English language model has not been downloaded into the active environment.
- **Solution**:
  ```bash
  python -m spacy download en_core_web_sm
  ```

---

### B. OCR & Document Processing

#### `pytesseract.pytesseract.TesseractNotFoundError: tesseract is not installed or it's not in your PATH`
- **Cause**: Tesseract OCR engine binary is not installed on the system or is installed in a non-standard directory.
- **Solution**:
  1. Download and install Tesseract OCR for Windows (e.g. from UB-Mannheim).
  2. The default recognized path is `C:\Program Files\Tesseract-OCR\tesseract.exe`.
  3. If installed in a custom location, add `TESSERACT_CMD` to your `PII/.env`:
     ```env
     TESSERACT_CMD=C:\Your\Custom\Path\tesseract.exe
     ```

#### OCR Latency on Large Images / PDFs
- **Cause**: Large high-resolution images (> 4000px) take longer to preprocess and run through Tesseract.
- **Solution**: PrivLock already implements an optimized single-pass OCR pipeline that reduces processing time by ~49% compared to traditional dual-pass architectures. For very large PDFs, processing occurs on a per-page basis with PyMuPDF rendering at 150 DPI for optimal balance between accuracy and speed.

---

### C. Database Connectivity

#### `mysql.connector.errors.DatabaseError: 2003: Can't connect to MySQL server`
- **Cause**: Local MySQL service is stopped, unreachable, or credentials in `PII/.env` are incorrect.
- **Automatic Fallback**: PrivLock automatically falls back to an embedded SQLite database (`PII/privlock.db`) when MySQL is unreachable. You do not need to install MySQL to run PrivLock locally.
- **Explicit SQLite Mode**: To force SQLite mode and skip MySQL connection attempts entirely, configure `PII/.env`:
  ```env
  USE_SQLITE=true
  ```

#### PostgreSQL Connection Failure on Cloud (Render / Neon)
- **Cause**: Missing `sslmode=require` query parameter in `DATABASE_URL` or expired Neon database credentials.
- **Solution**: Ensure your connection string includes SSL parameters:
  ```env
  DATABASE_URL=postgresql://user:pass@ep-hostname.neon.tech/dbname?sslmode=require
  USE_POSTGRES=true
  ```

---

### D. Network, CORS & API Connectivity

#### Browser Error: `Failed to fetch` or `CORS policy: No 'Access-Control-Allow-Origin' header`
- **Cause**:
  1. The backend is not running.
  2. The frontend is requesting a different origin that is not in the backend's allowed list.
- **Solution**:
  - Verify the backend is listening: `curl http://127.0.0.1:5000/api/health`.
  - Check `PII/.env` and ensure `CORS_ALLOWED_ORIGINS` includes your frontend origin:
    ```env
    CORS_ALLOWED_ORIGINS=http://localhost:*,http://127.0.0.1:*,https://privlock-ai.vercel.app
    ```

#### Render Free Tier Cold Start Delay
- **Symptom**: The first API call takes 30 to 50 seconds before returning a response.
- **Explanation**: Render's free tier automatically suspends web service containers after 15 minutes of inactivity. When a request arrives, Render spins up the container. Once initialized, subsequent requests respond in normal latency (sub-second to a few seconds).
- **Frontend Mitigation**: The Flutter web client uses generous connection timeouts (60 seconds) and displays user-friendly progress indicators during processing.

---

### E. Flutter Web & Android

#### White / Blank Screen on Flutter Web
- **Cause**: Browser cache serving obsolete JavaScript bundles or service worker cache conflicts.
- **Solution**:
  1. Perform a hard refresh in your browser: `Ctrl + Shift + R` (Windows) or `Cmd + Shift + R` (macOS).
  2. If using private browsing or incognito, close and reopen the tab.
  3. Clean the local build cache:
     ```bash
     cd PII
     flutter clean
     flutter pub get
     flutter run -d edge --dart-define=API_BASE_URL=http://127.0.0.1:5000 --web-port=5080
     ```

#### Android Mobile Cannot Connect to Backend
- **Symptom**: Android emulator or physical device throws `SocketException: Connection refused`.
- **Cause**: On mobile devices, `http://localhost:5000` refers to the mobile device itself, not your development workstation.
- **Solution**:
  - **Android Emulator**: Use `http://10.0.2.2:5000` (the Android emulator loopback alias to host machine).
  - **Physical Device**: Connect the phone to the same Wi-Fi network as your PC and supply your PC's local LAN IP address:
    ```bash
    flutter run -d android --dart-define=API_BASE_URL=http://192.168.1.100:5000
    ```
  - Ensure Windows Defender / firewall allows incoming connections on port 5000.

---

### F. Manual Redaction Coordinate Misalignment

#### Redaction Rectangle Shifted from Selection Area
- **Cause**: Screen display aspect ratio mismatch or improper letterbox/pillarbox compensation.
- **Verification**:
  - PrivLock uses [`ImageDisplayGeometry`](../PII/lib/models/image_display_geometry.dart) to automatically calculate letterbox and pillarbox offsets for `BoxFit.contain`.
  - For PDF documents, PrivLock uses [`PdfPageGeometryParser`](../PII/lib/models/pdf_page_geometry.dart) to detect native MediaBox dimensions and rotation.
  - In the UI, verify the detected page geometry tag (e.g. `Page 1 · A4 Portrait`) matches your document. Do not force an incompatible manual preset if the detected geometry is accurate.

---

## 3. Diagnostic Commands Summary

| Diagnostic Target | Command | Expected Output |
|---|---|---|
| **Python Version** | `python --version` | `Python 3.11+` (e.g. `Python 3.14.7`) |
| **Flutter Doctor** | `flutter doctor` | All checks green for Web & tools |
| **Backend Health** | `curl http://127.0.0.1:5000/api/health` | `HTTP 200 {"data": {"backend": "running", ...}}` |
| **Flutter Static Analysis** | `cd PII && flutter analyze lib test` | `No issues found!` |
| **Backend Test Suite** | `cd PII && .\venv\Scripts\python.exe -m unittest discover tests` | `Ran 80 tests ... OK` |
| **Flutter Test Suite** | `cd PII && flutter test` | `All tests passed!` |
| **Clean Shutdown** | Double-click `scripts/stop_privlock.bat` | Graceful termination of all processes |

