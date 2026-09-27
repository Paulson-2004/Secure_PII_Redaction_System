# Running Guide — PrivLock AI

This repository contains:
- **Flutter Frontend** (Web & Mobile) in `PII/`
- **Flask REST API Backend** with AI Redaction Pipeline in `PII/`

---

## Method A: Recommended Windows Single-Click Launcher

For the simplest and fastest startup on Windows:

1. Navigate to the repository root directory:
   `Secure_PII_Redaction_System/`
2. Double-click:
   **`run_privlock.bat`**

The launcher automatically:
- Validates the installation of **Python 3.11+** (verified on **Python 3.14.7**) and **Flutter SDK**.
- Creates or detects the virtual environment (`PII/venv`).
- Automatically installs dependencies if first run, or skips installation if the environment is already prepared.
- Starts the Flask backend in a separate dedicated terminal window.
- Polls `http://127.0.0.1:5000/api/health` until the backend is fully initialized.
- Launches the Flutter Web frontend in **Microsoft Edge** or **Google Chrome** (accessible from any modern browser: Chrome, Edge, Firefox, Safari).

### Graceful Shutdown
To cleanly shut down both the backend and frontend processes without leaving background tasks running:
- Double-click **`scripts/stop_privlock.bat`**.

---

## Method B: Manual Development Setup

### 1. Prerequisites

- **Python**: Python 3.11 or higher (Verified development/test environment: Python 3.14.7)
- **Flutter SDK**: 3.x+
- **Database**: MySQL Server 8.x (Optional: If MySQL is not running, the backend automatically activates an embedded SQLite fallback database `privlock.db`)
- **Tesseract OCR**: Installed at `C:\Program Files\Tesseract-OCR\tesseract.exe` or configured via `TESSERACT_CMD` in `.env`
- **Browser**: Any modern standards-compliant web browser (Microsoft Edge, Google Chrome, Mozilla Firefox, Apple Safari)

### 2. Backend Setup

1. Open a terminal and navigate to `PII`:
   ```bash
   cd PII
   ```
2. Create and activate the Python virtual environment (Python 3.11+):
   ```bash
   python -m venv venv

   # On Windows:
   venv\Scripts\activate

   # On Linux/macOS:
   # source venv/bin/activate
   ```
3. Install backend dependencies and spaCy language model:
   ```bash
   pip install -r requirements.txt
   python -m spacy download en_core_web_sm
   ```
4. Configure environment:
   ```bash
   copy .env.example .env
   ```
   *(Ensure credentials match your MySQL server if running. If offline, the backend automatically switches to SQLite `privlock.db`).*
5. Start the backend:
   ```bash
   python app.py
   ```
   Backend URLs:
   - Base API: `http://127.0.0.1:5000`
   - Health Diagnostic: `http://127.0.0.1:5000/api/health`

### 3. Frontend Setup (Web)

1. Open a second terminal and navigate to `PII`:
   ```bash
   cd PII
   ```
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Launch the web application:
   ```bash
   flutter run -d edge --dart-define=API_BASE_URL=http://127.0.0.1:5000 --web-port=5080
   ```
   *(PrivLock AI is browser-agnostic. Target `-d edge`, `-d chrome`, or open the URL in any modern browser including Microsoft Edge, Google Chrome, Mozilla Firefox, or Apple Safari).*

   Frontend URL:
   - `http://localhost:5080`

### 4. Frontend Setup (Android Mobile)

#### Android Emulator
```bash
flutter run -d android
```

#### Physical Android Device
1. Connect device via USB or ensure it is on the same local Wi-Fi network.
2. Ensure the backend is listening on `0.0.0.0` (default in `app.py`).
3. Launch the app providing your workstation's local IP address:
   ```bash
   flutter run -d android --dart-define=API_BASE_URL=http://<your-pc-ip>:5000
   ```

#### Release APK Build
```bash
flutter build apk --release --dart-define=API_BASE_URL=http://<your-pc-ip>:5000
```

---

## Recommended Execution Order

1. Start MySQL (if using MySQL; otherwise continue with SQLite fallback).
2. Start the backend and verify `http://127.0.0.1:5000/api/health` returns `200 OK`.
3. Start the Flutter frontend for web or Android.
4. Access the web application at `http://localhost:5080`, or run on mobile.

---

## Browser Notes & Troubleshooting

- **Hard Refresh**: Press `Ctrl + Shift + R` if cached assets prevent loading.
- **Clean Rebuild**:
  1. Stop Flutter (`Ctrl + C` or `q`).
  2. Run `flutter clean`.
  3. Re-run `flutter pub get` and the launch command.
- **Biometrics on Web**: Fingerprint authentication is automatically disabled on Web (mobile-only plugin) and falls back to PIN authentication.
- **File Handling**: Upload and download operations use browser-safe raw byte streams for cross-platform compatibility.
