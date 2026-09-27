# Consolidated Architecture & Operational Guide — PrivLock AI

---

## 1. Database Architecture & Resiliency

PrivLock AI implements a thread-safe dual-engine database strategy:

1. **Primary Database (MySQL 8.x)**:
   - Configured via environment variables (`PII/.env`).
   - Uses `MySQLConnectionPool` for thread safety, connection reuse, and automatic reconnection backoff.
   - Database name: `pii_redaction_system`.
   - The canonical baseline schema is defined in [PII/schema.sql](../PII/schema.sql).
2. **Automated Fallback (SQLite 3)**:
   - If MySQL is offline, unreachable, or unconfigured (or when `USE_SQLITE=true` is set), the database manager automatically activates an embedded SQLite database at `PII/privlock.db`.
   - Provides zero-configuration setup for local academic evaluation, continuous integration, and offline demos.

---

## 2. System Architecture & Components

The application follows a strictly decoupled layered architecture:

- **Frontend Client**: Located in [`PII/lib/`](../PII/lib/)
  - Flutter Material 3 cross-platform UI (Web and Android).
  - Centralized API communication via [`PII/lib/services/api_service.dart`](../PII/lib/services/api_service.dart).
  - Configurable backend target via `--dart-define=API_BASE_URL=<url>`.
- **REST API Backend**: Located at [`PII/app.py`](../PII/app.py)
  - Python 3.11+ Flask server (verified on Python 3.14.7).
  - Token-based authentication and user session security in [`PII/auth.py`](../PII/auth.py).
  - Path-validated file management preventing traversal attacks in [`PII/utils.py`](../PII/utils.py).
- **AI Redaction Pipeline**: Located in [`PII/modules/`](../PII/modules/)
  - **Single-Pass OCR Engine** ([`ocr_engine.py`](../PII/modules/ocr_engine.py)): Tesseract OCR, OpenCV adaptive preprocessing, and modern PyMuPDF document rendering.
  - **Pattern Detection Engine** ([`regex_detector.py`](../PII/modules/regex_detector.py)): 11 pre-compiled regex detectors with Verhoeff ($D_5$) and Luhn checksum validation.
  - **Contextual NER Engine** ([`ner_detector.py`](../PII/modules/ner_detector.py)): SpaCy `en_core_web_sm` with administrative suppression.
  - **Semantic Hybrid Fusion** ([`hybrid_engine.py`](../PII/modules/hybrid_engine.py)): Span overlap conflict resolution using semantic type compatibility.
  - **Regulatory Policy Retrieval & Decision Engine** ([`rag_decision_engine.py`](../PII/modules/rag_decision_engine.py)): FAISS dense vector retrieval and TF-IDF cosine similarity fallback across 15 statutory frameworks.
  - **Precision Redaction Engine** ([`redaction_engine.py`](../PII/modules/redaction_engine.py)): N-gram sequence-aware visual masking and descending offset text slicing.

---

## 3. Quick Start: Windows Single-Click Launcher

To launch the complete application with a single action on Windows:

1. Double-click **`run_privlock.bat`** from the repository root.
   - Detects Python (Python 3.11+ supported, verified on 3.14.7) and Flutter.
   - Reuses or creates `PII/venv`.
   - Starts the Flask backend in a dedicated window.
   - Polls `/api/health` until HTTP 200 is verified.
   - Launches the Flutter Web client in your default browser (Microsoft Edge or Google Chrome; accessible from any modern browser: Chrome, Edge, Firefox, Safari).
2. To shut down gracefully:
   - Double-click **`scripts/stop_privlock.bat`**.

---

## 4. Manual Execution Procedures

### Backend Execution
1. Navigate to the `PII` directory:
   ```bash
   cd PII
   ```
2. Initialize virtual environment:
   ```bash
   # Python 3.11+ supported (verified on Python 3.14.7)
   python -m venv venv
   # Windows:
   venv\Scripts\activate
   # Linux/macOS:
   # source venv/bin/activate
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   python -m spacy download en_core_web_sm
   ```
4. Configure environment:
   ```bash
   copy .env.example .env
   ```
5. Start Flask API:
   ```bash
   python app.py
   ```
6. Diagnostic health check:
   ```bash
   curl http://127.0.0.1:5000/api/health
   ```

### Frontend Execution (Web)
```bash
cd PII
flutter pub get
flutter run -d edge --dart-define=API_BASE_URL=http://127.0.0.1:5000 --web-port=5080
```
*(PrivLock AI is browser-agnostic: use `-d edge`, `-d chrome`, or navigate to `http://localhost:5080` in Microsoft Edge, Google Chrome, Mozilla Firefox, or Apple Safari).*

Access the client at `http://localhost:5080`.

---

## 5. Verification & Test Suite

All quality gates are verified on the codebase:

```bash
# 1. Full Backend Unit & Security Suite (34 tests)
cd PII
python -m unittest discover tests

# 2. End-to-End Pipeline Tests (2 tests)
python -m unittest tests.test_end_to_end_pipeline

# 3. Flutter Static Code Analysis (0 issues)
flutter analyze lib

# 4. Flutter Widget Test Suite
flutter test

# 5. Production Web Bundle Compilation
flutter build web --release
```
