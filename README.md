# PrivLock AI — Intelligent PII Detection & Redaction System

![PII Fullstack Banner](.github/assets/banner.svg)

[![GitHub Stars](https://img.shields.io/github/stars/Paulson-2004/Secure_PII_Redaction_System?style=for-the-badge&logo=github)](https://github.com/Paulson-2004/Secure_PII_Redaction_System/stargazers)
[![GitHub Forks](https://img.shields.io/github/forks/Paulson-2004/Secure_PII_Redaction_System?style=for-the-badge&logo=github)](https://github.com/Paulson-2004/Secure_PII_Redaction_System/network/members)
[![GitHub Issues](https://img.shields.io/github/issues/Paulson-2004/Secure_PII_Redaction_System?style=for-the-badge&logo=github)](https://github.com/Paulson-2004/Secure_PII_Redaction_System/issues)
[![Last Commit](https://img.shields.io/github/last-commit/Paulson-2004/Secure_PII_Redaction_System?style=for-the-badge&logo=git)](https://Paulson-2004/Secure_PII_Redaction_System/commits/main)

[![GitHub Repo](https://img.shields.io/badge/repo-Secure_PII_Redaction_System-181717?logo=github)](https://github.com/Paulson-2004/Secure_PII_Redaction_System)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Python](https://img.shields.io/badge/Python-3.11%2B%20%7C%203.14.7%20Verified-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Flask](https://img.shields.io/badge/Flask-Backend-000000?logo=flask&logoColor=white)](https://flask.palletsprojects.com/)
[![MySQL](https://img.shields.io/badge/MySQL-8.x-4479A1?logo=mysql&logoColor=white)](https://www.mysql.com/)

Production-style fullstack system for detecting and redacting Personally Identifiable Information from documents (images, PDFs, and text) using a hybrid AI pipeline.

## Why This Project

- **End-to-end workflow**: Authentication, upload, multi-engine detection, policy-driven decisioning, and verified redacted output.
- **Multi-stage AI pipeline**: Single-pass OCR + checksum-validated regex + contextual spaCy NER + semantic hybrid fusion + regulatory policy decisioning.
- **Fullstack delivery**: Native Flutter client and Python Flask backend in a single, well-organized repository.
- **Audit-focused**: Tenant-isolated redaction metrics, detection summaries, and audit logs stored directly in the database.

## Repository Structure

```text
Secure_PII_Redaction_System/
├── run_privlock.bat            # Single-click application launcher (Windows)
├── render.yaml                 # Render Blueprint specification (Backend API)
├── vercel.json                 # Vercel deployment configuration (Frontend SPA)
├── README.md                   # Project overview & system architecture
├── .env.example                # Root environment template
├── .gitignore                  # Workspace-wide git ignore rules
├── LICENSE                     # MIT License
├── .github/
│   └── assets/
│       └── banner.svg          # Graphical project banner
├── docs/
│   └── allinone.md             # Consolidated system architecture guide
├── scripts/
│   ├── generate_launcher_icons.py  # Android mipmap icon generator
│   ├── generate_logo_icons.py      # Brand logo and shield asset generator
│   └── stop_privlock.bat           # Clean process termination script
└── PII/                        # Core application root
    ├── app.py                  # Flask REST API entry point
    ├── auth.py                 # Token authentication and session control
    ├── config.py               # Environment configuration loader
    ├── database.py             # MySQL connection pool with SQLite fallback
    ├── schema.sql              # MySQL idempotent database schema
    ├── utils.py                # Security sanitizers and path normalization
    ├── requirements.txt        # Python backend dependencies (Python 3.11+ supported, 3.14.7 verified)
    ├── pubspec.yaml            # Flutter project specification
    ├── pubspec.lock            # Locked Dart dependencies
    ├── analysis_options.yaml   # Flutter strict static analysis rules
    ├── vercel.json             # Vercel routing configuration
    ├── Dockerfile              # Containerized backend build specification
    ├── docker-compose.yml      # Local MySQL 8.0 service definition
    ├── README.md               # App-level technical documentation
    ├── RUNNING_GUIDE.md        # Comprehensive execution manual
    ├── TESTING_GUIDE.md        # Verification and testing manual
    ├── .env.example            # Backend environment template
    ├── .gitignore              # Local Python and Flutter ignore rules
    ├── assets/                 # UI image assets and logos
    ├── lib/                    # Flutter client source (UI, state, API)
    ├── modules/                # AI redaction pipeline
    │   ├── ocr_engine.py       # Tesseract OCR & OpenCV preprocessing
    │   ├── regex_detector.py   # Pattern detection with Verhoeff/Luhn checksums
    │   ├── ner_detector.py     # SpaCy contextual entity recognition
    │   ├── hybrid_engine.py    # Semantic fusion & conflict resolution
    │   ├── rag_decision_engine.py # Regulatory policy retrieval & decision engine
    │   └── redaction_engine.py # Precision bounding box & text slicing
    ├── test/                   # Flutter widget tests
    ├── tests/                  # Backend unit, security, and E2E test suites
    ├── web/                    # Flutter Web index and PWA configuration
    ├── android/                # Android native embedding
    └── windows/                # Windows native runner
```

> [!NOTE]
> Generated directories (`PII/build/`, `PII/venv/`, `PII/uploads/`, and database cache files like `privlock.db`) are excluded by `.gitignore` to maintain repository hygiene.

## System Architecture

```text
Flutter Client (Web & Mobile, Material 3)
	│
	│ HTTP REST API (Bearer Token)
	▼
Flask REST Backend (app.py)
	│
	├──> Database Layer:
	│    ├──> MySQL Connection Pool (MySQLConnectionPool, Primary)
	│    └──> SQLite Fallback (privlock.db, Automated)
	│
	└──> AI Redaction Pipeline:
	     ├──> OCR Engine (Single-pass Tesseract + OpenCV + PyMuPDF)
	     ├──> Regex Detector (Precompiled + Verhoeff & Luhn Checksums)
	     ├──> NER Detector (SpaCy en_core_web_sm + Administrative Blacklist)
	     ├──> Hybrid Fusion Engine (Semantic Type Compatibility Matrix)
	     ├──> Regulatory Policy Retrieval & Decision Engine (15 Regulations + Dense/TF-IDF Cosine Retrieval)
	     └──> Redaction Engine (Sequence-Aware Visual Masking + Descending Slicing)
```

## 🚀 Cloud Deployment (Free Tier: Vercel + Render)

PrivLock AI is pre-configured for cost-free cloud deployment combining Vercel (Frontend static hosting) and Render (Backend API Web Service):

### 1. Backend Deployment (Render Free Tier)
- **Repository Setup**: Connect your GitHub repository to [Render](https://render.com/).
- **Blueprint or Web Service**:
  - **Option A (Blueprint)**: Select **Blueprints** and point to `render.yaml`.
  - **Option B (Manual Web Service)**:
    - **Root Directory**: `PII`
    - **Runtime**: `Python 3`
    - **Build Command**: `pip install -r requirements.txt && python -m spacy download en_core_web_sm`
    - **Start Command**: `gunicorn app:app --bind 0.0.0.0:$PORT --workers 1 --threads 4 --timeout 120`
    - **Environment Variables**:
      - `USE_SQLITE`: `true` (enables zero-maintenance embedded SQLite demo database)
      - `FLASK_ENV`: `production`
      - `SECRET_KEY`: `<generate-a-random-32-byte-hex-string>`
      - `CORS_ALLOWED_ORIGINS`: `https://<your-app>.vercel.app,http://localhost:*`
      - `FRONTEND_URL`: `https://<your-app>.vercel.app`

### 2. Frontend Deployment (Vercel Static Hosting)

> [!IMPORTANT]
> **Static Hosting Model**: Standard Vercel build environments do not include the Flutter SDK. PrivLock utilizes Vercel as a high-performance **Edge CDN for static hosting** of the compiled Flutter Web bundle (`PII/build/web`), with single-page app (SPA) rewrites and security headers managed by `vercel.json`.

**Option A: Local Build + Vercel CLI (Recommended — Zero CI Configuration)**
1. Compile the production web bundle locally with your real Render backend URL:
   ```bash
   cd PII
   flutter build web --release --dart-define=API_BASE_URL=https://<your-actual-render-service>.onrender.com
   ```
2. Deploy the static artifact directly to production:
   ```bash
   npx vercel deploy build/web --prod
   ```

**Option B: Automated GitHub Actions CI (Optional)**
For automated deployment on push, set up a GitHub Actions workflow with `subosito/flutter-action` to build the web bundle with your `--dart-define=API_BASE_URL` secret, then deploy `PII/build/web` to Vercel using `amondnet/vercel-action`.

> [!NOTE]
> - **Render Free Tier Spin-Down**: Free Render web services spin down after 15 minutes of inactivity; the initial request after idle may experience a 30–50 second cold start delay.
> - **Storage Ephemerality**: Documents processed on Render's free tier are stored on ephemeral local disk and cleaned up on container restarts. For permanent cloud storage, attach a persistent disk or cloud storage bucket.

## Quick Start (Single-Click Launcher)

For an automated startup experience on Windows, double-click:
**`run_privlock.bat`**

This script executes the verified startup flow:
1. Verifies Python (Python 3.11+ supported, verified on 3.14.7) and Flutter prerequisites.
2. Automatically creates or activates the virtual environment (`PII/venv`).
3. Installs dependencies from `requirements.txt` (skipped automatically on subsequent runs if already initialized).
4. Starts the Flask backend in a separate terminal and polls `http://127.0.0.1:5000/api/health` until ready.
5. Launches the Flutter Web frontend in your default browser (Microsoft Edge or Google Chrome; accessible from any modern browser: Chrome, Edge, Firefox, Safari).

To cleanly shut down the backend and frontend without orphaned background processes, run:
**`scripts/stop_privlock.bat`**

## Manual Setup

### 1. Clone Repository

```bash
git clone https://github.com/Paulson-2004/Secure_PII_Redaction_System.git
cd Secure_PII_Redaction_System/PII
```

### 2. Backend Setup

```bash
# Python Version: Python 3.11+ supported (Verified development/test environment: Python 3.14.7)
python -m venv venv

# Activate Virtual Environment (Windows)
venv\Scripts\activate

# Install Dependencies
pip install -r requirements.txt
python -m spacy download en_core_web_sm
```

### 3. Environment Configuration

```bash
copy .env.example .env
```

Update `.env` with your local MySQL credentials. If MySQL is offline or unconfigured, the backend automatically switches to local SQLite fallback (`privlock.db`).

### 4. Start Backend

```bash
python app.py
```

Health check verification:
```text
http://127.0.0.1:5000/api/health
```

### 5. Start Flutter Web Client

```bash
flutter pub get
# Launch on your available web browser (Edge or Chrome):
flutter run -d edge --dart-define=API_BASE_URL=http://127.0.0.1:5000 --web-port=5080
```
*(PrivLock AI is browser-agnostic: use `-d edge`, `-d chrome`, or navigate to the web URL in any modern browser including Microsoft Edge, Google Chrome, Mozilla Firefox, or Apple Safari).*

Client URL:
```text
http://localhost:5080
```

## Core Features

- **Authentication & Tenant Isolation**: bcrypt password hashing, token validation, token revocation on logout, and user-isolated document access.
- **Resilient Database Layer**: Thread-safe MySQL connection pooling (`MySQLConnectionPool`) with an automatic, zero-config SQLite fallback (`privlock.db`) for offline development and academic evaluation.
- **Single-Pass Document OCR**: Optimized image preprocessing and line reconstruction via Tesseract with PyMuPDF support for PDFs and raw text files. (Achieved 49.0% local controlled OCR latency reduction in benchmark: 1089.1 ms dual-pass vs 555.8 ms single-pass, 5-run average).
- **High-Precision PII Detection**:
  - Pre-compiled regex patterns with mathematical **Verhoeff ($D_5$) checksum** for Aadhaar and **Luhn modulus-10 checksum** for payment cards.
  - Contextual NER via SpaCy with administrative header/label suppression dictionaries.
  - Semantic hybrid fusion with type compatibility matrix and conflict resolution.
- **Regulatory Policy Retrieval & Decision Engine**: Codified knowledge base of 15 statutory regulations (DPDP Act 2023, Aadhaar Act 2016 §29, IT Act 2000 §43A, PCI-DSS v4.0) with dense vector retrieval (FAISS) and embedded TF-IDF cosine similarity fallback.
- **Accurate Redaction Engine**: Sequence-aware n-gram bounding box token matching preventing visual over-redaction, paired with descending start-offset text slicing.
- **Audit Logging**: Structured document processing history and system security events viewable in the Flutter UI.

## Tech Stack

- **Frontend**: Flutter (v3.x), Dart, Provider, Material 3, Cross-Browser Flutter Web (Microsoft Edge, Google Chrome, Mozilla Firefox, Apple Safari) and Android support
- **Backend**: Python 3.11+ (verified development/test environment: Python 3.14.7), Flask, Flask-CORS, bcrypt
- **AI & NLP Pipeline**: Tesseract OCR, OpenCV, PyMuPDF, SpaCy (`en_core_web_sm`), sentence-transformers (`all-MiniLM-L6-v2`), FAISS, TF-IDF Cosine Retrieval (embedded fallback)
- **Data Layer**: MySQL 8.x (primary pooled) / SQLite 3 (`privlock.db`, automated fallback)

## Verified Quality & Benchmarks

- **Backend Automated Tests**: 34/34 tests passing across unit, security, and integration suites (`python -m unittest discover tests`, verified on Python 3.14.7).
- **End-to-End Pipeline**: 2/2 pipeline tests passing (`python -m unittest tests.test_end_to_end_pipeline`).
- **Flutter Code Quality**: `flutter analyze lib` reports 0 issues; all widget tests passing (`flutter test`).
- **Web Build**: Successfully compiles to production web bundle (`flutter build web --release`).
- **OCR Latency Reduction**: 49.0% reduction in local controlled benchmark (1089.1 ms dual-pass vs 555.8 ms single-pass, 5-run average).

## 📸 Screenshots

Home Page
<img width="582" height="327" alt="Picture2" src="https://github.com/user-attachments/assets/f012d76d-01e7-4482-8408-3535a0e3bb79" />

Document Upload Page
<img width="595" height="334" alt="Picture3" src="https://github.com/user-attachments/assets/d613abcb-a94e-47c1-abeb-2f767e9400a8" />

Processing & Redaction Output
<img width="1323" height="596" alt="Picture4" src="https://github.com/user-attachments/assets/f5c2253c-c890-4788-85b3-1f0d750215e9" />

Document Comparison
<img width="1291" height="602" alt="Picture5" src="https://github.com/user-attachments/assets/7c2b93f4-0322-4198-a9d5-cc9714b55cf8" />

AI Detection Statistics
<img width="1278" height="718" alt="Picture6" src="https://github.com/user-attachments/assets/1a9debc0-d6f2-4676-8874-d06d155287e5" />

## Documentation

- App-level Technical Guide: [PII/README.md](PII/README.md)
- Complete Running Guide: [PII/RUNNING_GUIDE.md](PII/RUNNING_GUIDE.md)
- Verification & Testing Guide: [PII/TESTING_GUIDE.md](PII/TESTING_GUIDE.md)
- Consolidated Architecture Reference: [docs/allinone.md](docs/allinone.md)

## Security Notes

- `.env`, local uploads, generated build artifacts, and dataset folders are ignored via `.gitignore`.
- Use non-production credentials locally and rotate secrets before production deployment.

## License

Licensed under MIT. See [LICENSE](LICENSE).
