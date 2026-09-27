# All In One Guide

## Database Architecture

The backend supports dual database connectivity:
1. **Primary**: MySQL database (`pii_redaction_system`) using thread-safe connection pooling (`MySQLConnectionPool`). Credentials are configured via `PII/.env`.
2. **Automated Fallback**: If MySQL is offline, the backend seamlessly activates an embedded SQLite database (`PII/privlock.db`), ensuring zero-friction setup for development, evaluation, and viva presentations.

The canonical schema is defined in [PII/schema.sql](PII/schema.sql).

## Architecture Components

- **Flask Backend Server**: [PII/app.py](PII/app.py)
- **AI / NLP Detection Modules**: [PII/modules/](PII/modules)
  - Single-Pass OCR & Preprocessing: [PII/modules/ocr_engine.py](PII/modules/ocr_engine.py)
  - Precompiled Regex & Checksums (Verhoeff/Luhn): [PII/modules/regex_detector.py](PII/modules/regex_detector.py)
  - Contextual NER & Suppression: [PII/modules/ner_detector.py](PII/modules/ner_detector.py)
  - Semantic Hybrid Fusion: [PII/modules/hybrid_engine.py](PII/modules/hybrid_engine.py)
  - Regulatory Policy Retrieval & Decision Engine: [PII/modules/rag_decision_engine.py](PII/modules/rag_decision_engine.py)
  - Visual & Text Redaction Engine: [PII/modules/redaction_engine.py](PII/modules/redaction_engine.py)
- **Upload & Redacted Storage**: `PII/uploads/` and `PII/uploads/redacted/`
- **Flutter Client UI**: [PII/lib/](PII/lib)

## Running the Backend

1. Navigate to the `PII` directory:

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

2. Copy and configure environment variables:
```bash
copy .env.example .env
```

3. Start the Flask application:
```bash
python app.py
```

4. Verify backend health:
```bash
curl http://127.0.0.1:5000/api/health
```

Expected health JSON:
- `backend`: `"running"`
- `database`: `"connected"`
- `database_engine`: `"MySQL"` (or `"SQLite"` if running offline)
- `ai`: status dictionary confirming all AI modules are operational.

## Running the Flutter Frontend

```bash
cd PII
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:5000 --web-port=5080
```

Access the web client at `http://localhost:5080`.

## Automated Verification Suite

Run the full automated testing suite:

```bash
# 1. Backend Automated Tests (34 unit, security, and pipeline tests)
cd PII
python -m unittest discover tests

# 2. Flutter Static Code Analysis
flutter analyze lib

# 3. Flutter Widget Tests
flutter test

# 4. Flutter Web Production Build
flutter build web
```
