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

## Method C: Cloud Deployment (Vercel + Render Free Tier)

PrivLock AI is ready for production deployment across free-tier cloud platforms:

### 1. Deploy the Backend to Render
1. Create a free account at [render.com](https://render.com/).
2. Create a new **Web Service** and connect your GitHub repository.
3. Configure the service settings:
   - **Root Directory**: `PII`
   - **Runtime**: `Python 3`
   - **Build Command**:
     ```bash
     pip install -r requirements.txt && python -m spacy download en_core_web_sm
     ```
   - **Start Command**:
     ```bash
     gunicorn app:app --bind 0.0.0.0:$PORT --workers 1 --threads 4 --timeout 120
     ```
4. Configure Environment Variables in Render:
   - `USE_SQLITE`: `true`
   - `FLASK_ENV`: `production`
   - `SECRET_KEY`: `<generate-a-secure-random-string>`
   - `CORS_ALLOWED_ORIGINS`: `https://<your-app>.vercel.app,http://localhost:*`
   - `FRONTEND_URL`: `https://privlock-ai.vercel.app`
5. Click **Deploy**. Note your assigned backend URL (e.g. `https://privlock-api.onrender.com`).

### 2. Deploy the Frontend to Vercel (Static Edge Hosting)

Standard Vercel build images do not include the Flutter SDK. Vercel is used as the **static hosting edge CDN** for the compiled Flutter Web bundle (`PII/build/web`).

**Method 1: Local Build & Direct CLI Deploy (Recommended)**
1. Generate the production release bundle using your actual Render backend URL:
   ```bash
   cd PII
   flutter build web --release --dart-define=API_BASE_URL=https://<your-actual-render-service>.onrender.com
   ```
2. Deploy the static `build/web` directory directly to Vercel:
   ```bash
   npx vercel deploy build/web --prod
   ```

**Method 2: Automated GitHub Actions CI (Optional)**
If you prefer automatic deployment on git push, configure a GitHub Actions workflow using `subosito/flutter-action` to run the build command and deploy the artifact to Vercel using `amondnet/vercel-action`.

> [!NOTE]
> On Render's free tier, the web service spins down after 15 minutes of inactivity. The first request after a period of dormancy may take 30–50 seconds to initialize the container.

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

---

## Redaction Modes & Regulatory Frameworks

### 1. Detection & Redaction Modes
- **Automatic PII Detection**: Full automated AI pipeline (single-pass OCR, regex with Verhoeff/Luhn checksums, spaCy NER, and FAISS policy matching).
- **Manual Selection**: Only user-selected rectangular regions are redacted, masked, or blurred. All text and visuals outside user selections remain strictly intact.
- **Automatic + Manual**: Combines automated detections with custom user-marked zones, applying IoU deduplication to eliminate duplicate passes.

### 2. Supported Visual Treatments
- **Redact**: Solid blackout rectangle (`#000000`).
- **Mask**: Format-preserving character replacement (e.g. `XXXX-XXXX-1234` or `****`).
- **Blur**: Gaussian blur smoothing filter over the bounding zone.

### 3. Multi-Page Document Support
- For multi-page PDFs, assign manual redaction zones per page (`Target Page: 1, 2, ...`).
- In Manual mode, pages without user selections are preserved completely untouched in the exported PDF.

### 4. Authoritative Privacy & Security Policy Corpus
PrivLock embeds a codified corpus of 29 privacy & security policy sources across clearly defined legal and technical categories:

- **Legislation**:
  - Digital Personal Data Protection Act, 2023 (India, Act 22 of 2023, MeitY)
  - Aadhaar Act, 2016 (India, Act 18 of 2016, amended 2019, UIDAI)
  - Income Tax Act, 1961 (India, Act 43 of 1961, Sec 139A & 138, CBDT)
  - Motor Vehicles Act, 1988 (India, Act 59 of 1988, amended 2019, MoRTH)
  - Representation of the People Act, 1951 (India, Act 43 of 1951, Sec 61, ECI)
  - Passports Act, 1967 (India, Act 15 of 1967, Sec 3 & 12, MEA / ICAO Doc 9303)
  - General Data Protection Regulation (EU) 2016/679 (GDPR, Art 4, 5, 6, 9, 32-34)
- **Regulations**:
  - Digital Personal Data Protection Rules, 2025 (Final rules notified Nov 2025 by MeitY)
  - Information Technology (SPDI) Rules, 2011 (Sec 43A)
  - Registration of Electors Rules, 1960 (Rule 28 - EPIC voter card)
- **Standards**:
  - PCI DSS v4.0.1 (Published June 2024 by PCI Security Standards Council - Req 3.4/3.5)
  - ISO/IEC 27001:2022 Control A.8.11 Data Masking
- **Official Guidance**:
  - NIST SP 800-122 (Guide to Protecting the Confidentiality of PII)
- **Policy Mappings**:
  - Medical / Health Record Confidentiality (Derived from DPDP Act 2023 Sec 8(5), DPDP Rules 2025 Rule 6, GDPR Art 9; DISHA was a 2018 draft and was not enacted)
  - Bank Statement & Account Redaction (Derived from RBI KYC Master Direction 2016/2024 and DPDP Act 2023)
  - Salary Slip & Compensation Confidentiality (Derived from DPDP Act 2023 and Code on Wages 2019)
  - Tax Return Confidentiality (Derived from Income Tax Act 1961 Sec 138 and DPDP Act 2023)
  - Commercial Contract & NDA Confidentiality (Derived from Indian Contract Act 1872 and commercial trade secret principles)
  - General PII Default Redaction Baseline (Derived from DPDP Act 2023 Sec 8(5), GDPR Art 5, ISO 27001 A.8.11)
  - Postal Index Demographic Mapping (Department of Posts 1972)
  - Public Corporate Entity Governance (Companies Act 2013 Sec 399)
  - Bank Routing Metadata Mapping (RBI IFSC directory)

*Disclaimer: PrivLock provides technical privacy/security guidance and automated redaction. It is not legal advice and does not certify regulatory compliance.*
