# PrivLock — Intelligent PII Detection & Redaction System

![PII Fullstack Banner](.github/assets/banner.svg)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python: 3.11+ | 3.14.7 Verified](https://img.shields.io/badge/Python-3.11%2B%20%7C%203.14.7%20Verified-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![Flutter: 3.x](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Flask: 3.x](https://img.shields.io/badge/Flask-Backend-000000?logo=flask&logoColor=white)](https://flask.palletsprojects.com/)
[![Database: MySQL | PostgreSQL | SQLite](https://img.shields.io/badge/Database-MySQL%20%7C%20Postgres%20%7C%20SQLite-4479A1?logo=postgresql&logoColor=white)](docs/ARCHITECTURE.md)
[![Deployed on Vercel](https://img.shields.io/badge/Vercel-Frontend-black?logo=vercel&logoColor=white)](https://privlock-ai.vercel.app)
[![Deployed on Render](https://img.shields.io/badge/Render-Backend-46E3B7?logo=render&logoColor=white)](https://secure-pii-redaction-system.onrender.com)

**PrivLock** is an enterprise-grade, privacy-first system designed to detect and redact Personally Identifiable Information (PII) from scanned documents, multi-page PDFs, and plain text. Combining a high-performance single-pass AI pipeline, interactive manual redaction studio, guest evaluation mode, and an authoritative regulatory policy decision engine, PrivLock ensures automated compliance while strictly safeguarding confidential data.

---

## 🌐 Live Deployments & Endpoints

| Service | Platform | Live URL | Description |
|---|---|---|---|
| **Web Application** | Vercel Edge CDN | [https://privlock-ai.vercel.app](https://privlock-ai.vercel.app) | Responsive Flutter Material 3 Web SPA |
| **REST API Server** | Render Web Service | [https://secure-pii-redaction-system.onrender.com](https://secure-pii-redaction-system.onrender.com) | Python Flask API + AI Redaction Pipeline |
| **Health Diagnostic** | Render Web Service | [`/api/health`](https://secure-pii-redaction-system.onrender.com/api/health) | Live system status & AI engine readiness |

---

## ⚡ Key Capabilities

- **Zero-Account Guest Mode**: Instant document evaluation without registration. Guest artifacts use ephemeral session tokens and auto-purge after a 1-hour TTL with zero database persistence.
- **6-Stage Hybrid AI Pipeline**: Single-pass Tesseract OCR, OpenCV adaptive thresholding, 11 pre-compiled regex detectors with mathematical checksums (Verhoeff $D_5$ for Aadhaar, Luhn for cards), spaCy NER, semantic fusion, and dense vector policy retrieval.
- **Interactive Manual Redaction Studio**: Interactive canvas supporting custom rectangular zone marking with normalized coordinate resolution (`ImageDisplayGeometry` compensating for letterbox/pillarbox) and native PDF `MediaBox` geometry detection.
- **3 Processing Modes & 3 Visual Treatments**:
  - *Modes*: Automatic PII Detection, Manual Selection, Automatic + Manual.
  - *Treatments*: Solid Blackout (`#000000`), Format-Preserving Mask (`****`), and Gaussian Blur ($\sigma \ge 15$).
- **Multi-Page PDF Selectivity**: Selective per-page redaction where unselected pages remain completely untouched in the exported vector PDF.
- **29-Source Regulatory Knowledge Base**: FAISS vector search and embedded TF-IDF fallback citing authoritative legislation (DPDP Act 2023, Aadhaar Act 2016, GDPR), subordinate rules (DPDP Rules 2025), security standards (PCI DSS v4.0.1, ISO/IEC 27001:2022), and official technical guidance (NIST SP 800-122).
- **Resilient Multi-Engine Data Layer**: Thread-safe MySQL 8.x connection pooling locally, persistent Neon Serverless PostgreSQL in production, and automatic zero-configuration SQLite fallback (`privlock.db`).
- **49% OCR Latency Reduction**: Optimized single-pass line reconstruction reduces local OCR latency from 1089.1 ms to 555.8 ms.

---

## 🏗️ System Architecture

```text
[ Flutter Web / Android Client ]
               │
               │ HTTPS REST API (Bearer Token / Ephemeral Guest Token)
               ▼
[ Flask REST API Server (app.py) ]
       │
       ├──> Database Layer (database.py)
       │    ├──> Neon Serverless PostgreSQL (Production via DATABASE_URL)
       │    ├──> MySQL 8.x Connection Pool (Local Primary)
       │    └──> SQLite 3 Embedded (Automated Fallback: privlock.db)
       │
       └──> AI Redaction & Policy Pipeline (modules/)
            ├──> 1. Single-Pass OCR Engine (Tesseract + OpenCV + PyMuPDF)
            ├──> 2. Pattern Detector (Regex + Verhoeff & Luhn Checksums)
            ├──> 3. Contextual NER Engine (SpaCy en_core_web_sm)
            ├──> 4. Semantic Hybrid Fusion (Type Compatibility Matrix)
            ├──> 5. RAG Policy Decision Engine (29 Sources + FAISS & TF-IDF)
            └──> 6. Redaction Engine (Visual Blackout, Mask, Gaussian Blur)
```

---

## 🚀 Quick Start (Windows 1-Click Launcher)

To launch the complete application stack (backend + web client) automatically on Windows:

1. Double-click **`run_privlock.bat`** from the repository root.
   - Detects Python 3.11+ and Flutter SDK.
   - Initializes or activates virtual environment (`PII/venv`).
   - Starts Flask API in a dedicated console window and polls `/api/health`.
   - Opens the Flutter Web client in your default web browser at `http://localhost:5080`.
2. To shut down gracefully: double-click **`scripts/stop_privlock.bat`**.

For manual step-by-step installation on Windows, Linux, macOS, or Android, see [docs/SETUP.md](docs/SETUP.md).

---

## 📚 Documentation Index

All technical guides and detailed architecture specifications are organized in the [`docs/`](docs/) directory:

| Guide | Description |
|---|---|
| 📖 [**Architecture Guide**](docs/ARCHITECTURE.md) | Complete component topology, data flows, 6-stage AI pipeline, and database abstraction |
| 🛠️ [**Setup & Installation**](docs/SETUP.md) | Local prerequisites, single-click launcher, manual backend/frontend setup, and Android instructions |
| 🧪 [**Testing & Quality Assurance**](docs/TESTING.md) | 80 backend tests, 29 Flutter tests, static analysis, production web build, and manual QA |
| ☁️ [**Cloud Deployment Guide**](docs/DEPLOYMENT.md) | Vercel static edge hosting, Render backend configuration, Neon PostgreSQL, and Docker |
| 🛡️ [**Security & Privacy Guide**](docs/SECURITY.md) | Guest mode isolation, bcrypt hashing, stateless tokens, path sanitization (`safe_join`), and 1-hour TTL |
| ✂️ [**Redaction & Geometry Guide**](docs/REDACTION.md) | Display geometry math (`ImageDisplayGeometry`), native PDF `MediaBox`, and multi-page selective redaction |
| 📜 [**Policy Corpus Catalog**](docs/POLICY_CORPUS.md) | The 29 authoritative privacy sources, legal/technical taxonomy, DISHA clarification, and citations |
| 🔧 [**Troubleshooting & Diagnostics**](docs/TROUBLESHOOTING.md) | Solutions for Python venv, Tesseract OCR path, CORS errors, database connections, and cold starts |

---

## 📂 Repository Layout

```text
Secure_PII_Redaction_System/
├── run_privlock.bat            # Windows automated 1-click startup script
├── render.yaml                 # Render cloud blueprint specification
├── vercel.json                 # Vercel SPA routing & security headers
├── LICENSE                     # MIT License
├── README.md                   # Repository landing page & index (this file)
├── docs/                       # Comprehensive technical documentation
│   ├── ARCHITECTURE.md         # System architecture & AI pipeline deep dive
│   ├── SETUP.md                # Local setup for Windows, Linux, macOS & Android
│   ├── TESTING.md              # Test execution & verification procedures
│   ├── DEPLOYMENT.md           # Production deployment (Vercel, Render, Neon)
│   ├── SECURITY.md             # Security controls & guest isolation architecture
│   ├── REDACTION.md            # Redaction modes, visual treatments & geometry math
│   ├── POLICY_CORPUS.md        # 29-source authoritative regulatory corpus catalog
│   └── TROUBLESHOOTING.md      # Diagnostics and issue resolution guide
├── scripts/                    # Maintenance & icon generation utilities
│   ├── generate_launcher_icons.py
│   ├── generate_logo_icons.py
│   └── stop_privlock.bat       # Clean process termination script
└── PII/                        # Fullstack application core
    ├── app.py                  # Flask REST API entry point
    ├── auth.py                 # Authentication, bcrypt, & session control
    ├── config.py               # Central environment loader
    ├── database.py             # Multi-engine database manager (PostgreSQL/MySQL/SQLite)
    ├── schema.sql              # Relational database schema
    ├── utils.py                # Security sanitizers & path normalization
    ├── requirements.txt        # Python backend dependencies
    ├── pubspec.yaml            # Flutter project specification
    ├── .env.example            # Backend environment template
    ├── lib/                    # Flutter Dart UI, state models, & API client
    ├── modules/                # AI Redaction Pipeline
    │   ├── ocr_engine.py       # Tesseract OCR & OpenCV preprocessing
    │   ├── regex_detector.py   # Pattern detection with Verhoeff/Luhn checksums
    │   ├── ner_detector.py     # SpaCy contextual entity recognition
    │   ├── hybrid_engine.py    # Semantic fusion & conflict resolution
    │   ├── rag_decision_engine.py # 29-source policy retrieval & decisioning
    │   └── redaction_engine.py # Bounding box visual masking & text slicing
    ├── test/                   # Flutter widget & unit test suite (29 tests)
    └── tests/                  # Backend unit, security, & E2E test suites (80 tests)
```

---

## 📸 Screenshots

| Upload & Redaction Studio | Processing & Inspection |
|:---:|:---:|
| <img width="500" alt="Upload Screen" src="https://github.com/user-attachments/assets/d613abcb-a94e-47c1-abeb-2f767e9400a8" /> | <img width="500" alt="Result Screen" src="https://github.com/user-attachments/assets/f5c2253c-c890-4788-85b3-1f0d750215e9" /> |
| **Document Comparison** | **Detection Statistics** |
| <img width="500" alt="Comparison View" src="https://github.com/user-attachments/assets/7c2b93f4-0322-4198-a9d5-cc9714b55cf8" /> | <img width="500" alt="Statistics View" src="https://github.com/user-attachments/assets/1a9debc0-d6f2-4676-8874-d06d155287e5" /> |

---

## ⚖️ Legal & Compliance Disclaimer

> [!IMPORTANT]
> PrivLock provides technical privacy assistance, pattern detection, and automated document redaction. It does **not** constitute legal advice, statutory interpretation, or regulatory compliance certification. PrivLock does not claim independent certification under GDPR, the DPDP Act, PCI DSS, or ISO/IEC 27001. Automated detection models and OCR may not achieve 100% recall on all document formats; human verification is strongly recommended before distributing redacted documents containing high-risk personal data.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
