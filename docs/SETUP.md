# Setup & Installation Guide — PrivLock

This guide details the step-by-step procedures for setting up and running PrivLock locally across Windows, Linux, macOS, and Android.

---

## 1. Prerequisites

Before installing, ensure the following core tools are installed on your workstation:

| Requirement | Minimum Version | Verified Baseline | Purpose |
|---|---|---|---|
| **Python** | 3.11+ | Python 3.14.7 | Backend Flask API & AI Pipeline |
| **Flutter SDK** | 3.x+ | Flutter 3.24+ | Cross-Platform Client (Web & Mobile) |
| **Tesseract OCR** | 5.x+ | Tesseract 5.3+ | Optical Character Recognition |
| **Database** | MySQL 8.x / SQLite | MySQL 8.0 / SQLite 3 | Account credentials & processing audit logs |
| **Web Browser** | Standards Compliant | Edge, Chrome, Firefox, Safari | Web interface client |

> [!NOTE]
> Installing a standalone MySQL server is **optional**. If MySQL is not detected or is offline, the backend automatically switches to an embedded SQLite database (`PII/privlock.db`).

---

## 2. Quick Start: Windows Single-Click Launcher

For the fastest developer setup on Windows:

1. Double-click **`run_privlock.bat`** from the repository root.
   - Automatically validates Python 3.11+ and Flutter SDK.
   - Creates or activates the virtual environment (`PII/venv`).
   - Installs backend dependencies on the first run; skips re-installation on subsequent launches.
   - Starts the Flask backend in a separate terminal window and polls `http://127.0.0.1:5000/api/health` until ready.
   - Detects your default browser (Google Chrome or Microsoft Edge) and launches the Flutter Web client.
2. To cleanly shut down both backend and frontend processes without orphaned tasks:
   - Double-click **`scripts/stop_privlock.bat`**.

---

## 3. Manual Development Setup

If you are developing on Linux, macOS, or prefer manual CLI controls on Windows:

### Step A: Backend Environment Setup

1. Open a terminal and navigate to the backend directory:
   ```bash
   cd PII
   ```
2. Initialize and activate the Python virtual environment:
   ```bash
   # Windows:
   python -m venv venv
   venv\Scripts\activate

   # Linux/macOS:
   # python3 -m venv venv
   # source venv/bin/activate
   ```
3. Install backend dependencies and download the spaCy language model:
   ```bash
   pip install -r requirements.txt
   python -m spacy download en_core_web_sm
   ```
4. Configure local environment variables:
   ```bash
   # Copy the backend configuration template
   copy .env.example .env        # Windows
   # cp .env.example .env         # Linux/macOS
   ```
   *Edit `PII/.env` to configure your local MySQL credentials, or set `USE_SQLITE=true` to force embedded SQLite mode.*
5. Start the Flask API:
   ```bash
   python app.py
   ```
6. Verify backend health in another terminal:
   ```bash
   curl http://127.0.0.1:5000/api/health
   ```

---

### Step B: Frontend Setup (Flutter Web)

1. Open a second terminal and navigate to `PII`:
   ```bash
   cd PII
   ```
2. Fetch Dart dependencies:
   ```bash
   flutter pub get
   ```
3. Launch the web application targeting your preferred browser:
   ```bash
   # Microsoft Edge
   flutter run -d edge --dart-define=API_BASE_URL=http://127.0.0.1:5000 --web-port=5080

   # Google Chrome
   flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:5000 --web-port=5080
   ```
   *Access the client at `http://localhost:5080` in Microsoft Edge, Google Chrome, Mozilla Firefox, or Apple Safari.*

---

### Step C: Frontend Setup (Android Mobile)

#### 1. Android Emulator
Ensure an Android Virtual Device (AVD) is running via Android Studio:
```bash
cd PII
flutter run -d android
```

#### 2. Physical Android Device
1. Connect your Android device via USB with USB Debugging enabled, or connect over Wi-Fi.
2. Ensure your workstation and phone are on the same local network.
3. Pass your workstation's local LAN IP address so the mobile app can reach the backend:
   ```bash
   flutter run -d android --dart-define=API_BASE_URL=http://192.168.1.100:5000
   ```

#### 3. Release APK Compilation
```bash
cd PII
flutter build apk --release --dart-define=API_BASE_URL=http://192.168.1.100:5000
```
The compiled APK will be generated at `PII/build/app/outputs/flutter-apk/app-release.apk`.

---

## 4. Local Service Endpoints

| Service | Target URL | Method | Role |
|---|---|---|---|
| **Flutter Web Client** | `http://localhost:5080` | Browser | Web application UI |
| **Flask API Root** | `http://127.0.0.1:5000` | HTTP | Base REST API service |
| **Health Diagnostic** | `http://127.0.0.1:5000/api/health` | GET | System status & AI module readiness |
| **Document Processing** | `http://127.0.0.1:5000/api/process` | POST | Multipart document upload & redaction |
| **Document Download** | `http://127.0.0.1:5000/api/download/<file>` | GET | Secure file retrieval |
| **Document Preview** | `http://127.0.0.1:5000/api/preview/<file>` | GET | Redacted document preview |
| **Audit History** | `http://127.0.0.1:5000/audit-logs` | GET | Tenant-isolated processing events |

