# Testing & Quality Assurance Guide — PrivLock

This document details the automated test suites, quality gates, static code analysis, and manual verification procedures for PrivLock.

---

## 1. Verified Quality Gates Baseline

All quality gates have been executed and verified on the codebase:

| Verification Stage | Command / Scope | Target Directory | Verified Result | Details |
|---|---|---|---|---|
| **Backend Unit & Security** | `python -m unittest discover tests` | `PII/` | **PASS (80/80)** | Unit, security, guest mode, RAG, and pipeline tests |
| **Flutter Static Analysis** | `flutter analyze lib test` | `PII/` | **PASS (0 issues)** | Zero warnings, zero errors, zero linter hints |
| **Flutter Tests** | `flutter test` | `PII/` | **PASS (29/29)** | Unit, widget, geometry, and guest mode tests |
| **Web Production Build** | `flutter build web --release` | `PII/` | **PASS** | Clean release web bundle in `PII/build/web` |
| **Backend Health Probe** | `GET /api/health` | `http://127.0.0.1:5000` | **PASS (HTTP 200)** | Database connected, all AI modules loaded |
| **Git Diff Hygiene** | `git diff --check` | Repository root | **PASS** | Zero trailing whitespace or conflict markers |

---

## 2. Backend Automated Test Suite (80 Tests)

The backend test suite covers detection engines, policy decisioning, security barriers, guest mode isolation, coordinate geometry, and end-to-end processing.

### Running Backend Tests

Activate your Python virtual environment (Python 3.11+ supported, verified on Python 3.14.7) from the `PII` directory:

```bash
cd PII

# Windows:
venv\Scripts\activate

# Linux/macOS:
# source venv/bin/activate

# Run all 80 tests:
python -m unittest discover tests -v
```

### Backend Test Modules Breakdown

| Test File | Focus Area | Key Invariants Tested |
|---|---|---|
| `tests/test_regex_detector.py` | Pattern Detection & Checksums | Verhoeff ($D_5$) Aadhaar validation; Luhn modulus-10 card validation; PAN format; Indian Passport, Voter ID (EPIC), Driving Licence regex; Phone and Email pattern matching; False positive suppression. |
| `tests/test_hybrid_fusion.py` | Engine Fusion & Resolution | Multi-engine span overlap resolution; Semantic type compatibility matrix; Bounding box synchronization; Confidence weighting between Regex and spaCy NER. |
| `tests/test_redaction_engine.py` | Precision Redaction | Visual blackout (`#000000`), format-preserving character masking (`****`), and Gaussian blur; N-gram sequence-aware token matching; Descending start-offset text slicing; Multi-page PDF page preservation. |
| `tests/test_rag_engine.py` | Policy Retrieval & Decisioning | 29 codified policy sources across 5 taxonomy types; FAISS dense vector retrieval and embedded TF-IDF cosine similarity fallback; Classification of DISHA as draft bill (policy mapping); Statutory citation verification. |
| `tests/test_api_security.py` | Authentication & Security Barriers | Password hashing via bcrypt; Stateless Bearer token validation and revocation; SQL injection prevention via parameterized queries; Path traversal protection (`safe_join`); Unredacted file preview rejection. |
| `tests/test_guest_mode.py` | Ephemeral Guest Processing | Processing without authentication; Ephemeral guest token generation; Zero-persistence guarantee (no history/audit rows created); 1-hour artifact TTL cleanup; Guest download/preview token enforcement. |
| `tests/test_manual_redaction.py` | Manual Coordinates & PDF Geometry | Normalized coordinate handling ($0.0 \le x, y, w, h \le 1.0$); Boundary clamping; Maximum 50 regions limit; Multi-page PDF page selectivity; Aspect-ratio letterbox/pillarbox compensation. |
| `tests/test_end_to_end_pipeline.py` | Full Document Lifecycle | End-to-end flow: Registration $\rightarrow$ Login $\rightarrow$ Document Upload $\rightarrow$ OCR $\rightarrow$ Hybrid Detection $\rightarrow$ Policy Evaluation $\rightarrow$ Redaction $\rightarrow$ Download $\rightarrow$ Audit Trail. |
| `tests/test_multi_page_pdf.py` | Multi-Page PDF Handling | Multi-page PDF ingestion, per-page OCR and coordinate alignment, selective page redaction, unselected page preservation. |

---

## 3. Frontend Automated Test Suite (29 Tests)

The Flutter test suite verifies UI state management, guest mode transitions, manual redaction canvas geometry, and cross-platform compatibility.

### Running Flutter Tests

From the `PII` directory:

```bash
cd PII

# 1. Static code analysis (analyzes both lib and test):
flutter analyze lib test

# 2. Run all Flutter unit and widget tests:
flutter test -v
```

### Flutter Test Modules Breakdown

| Test File | Focus Area | Key Behaviors Verified |
|---|---|---|
| `test/guest_mode_test.dart` | Guest Mode User Flow | "Continue as Guest" entrypoint on login screen; Ephemeral session state; Audit log gating with account prompt; Result screen download with guest token; Logout/exit handling. |
| `test/manual_redaction_test.dart` | Manual Redaction Studio | Interactive bounding box creation; Coordinate normalization ($[0.0, 1.0]$); Visual mode switching (Redact / Mask / Blur); Region deletion and clear; Mode selection (Auto / Manual / Auto+Manual). |
| `test/image_display_geometry_test.dart` | Display Geometry Math | `ImageDisplayGeometry` calculation for `BoxFit.contain`; Letterbox/pillarbox offset calculations; Screen coordinate to normalized image coordinate mapping; Clamping and scale inversion. |
| `test/pdf_page_geometry_test.dart` | PDF Geometry & MediaBox | Native PDF MediaBox detection (`/MediaBox [0 0 W H]`); Page rotation handling (`/Rotate 90/180/270`); Auto aspect-ratio calculation; Multi-page dimension extraction. |
| `test/widget_test.dart` | Widget Tree & Navigation | Material 3 theme rendering; Navigation drawer routing; Security PIN dialog; Responsive layout adaptability across desktop and mobile viewports. |

---

## 4. Production Web Build Verification

To verify that the Flutter web bundle compiles cleanly without minification or tree-shaking failures:

```bash
cd PII
flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:5000
```

The compiled static assets are generated in `PII/build/web/`. Verify that:
- `PII/build/web/index.html` exists.
- `PII/build/web/main.dart.js` (or Flutter WASM/CanvasKit modules) compile without error.
- No tree-shaking or symbol resolution errors occur during the release build.

---

## 5. Backend Diagnostic Health Check

With the backend running (`python app.py`), query the health endpoint:

```bash
curl http://127.0.0.1:5000/api/health
```

### Expected HTTP 200 JSON Response

```json
{
  "data": {
    "backend": "running",
    "database": "connected",
    "database_engine": "MySQL",
    "ai": {
      "loaded": true,
      "ocr": { "loaded": true },
      "regex": { "loaded": true, "total_detectors": 11 },
      "ner": { "status": "LOADED" },
      "hybrid": { "loaded": true },
      "rag": { "total_policies": 29, "rag_enabled": true },
      "redaction": { "loaded": true }
    }
  },
  "success": true
}
```

*Note: In production (Render + Neon), `database_engine` will report `PostgreSQL`.*

---

## 6. Manual End-to-End Verification Procedures

In addition to automated tests, perform manual verification using the following workflows:

### A. Guest Mode Verification Flow
1. Open `http://localhost:5080` in your web browser.
2. On the authentication screen, click **"Continue as Guest"**.
3. Verify that you land directly on the document processing dashboard without entering credentials.
4. Upload a sample document (image or PDF containing mock PII).
5. Select a redaction mode (`Automatic PII Detection`, `Manual Selection`, or `Automatic + Manual`).
6. Click **Process Document**.
7. Confirm detection results appear with policy citations.
8. Click **Download** or **Preview** to verify the redacted output.
9. Try navigating to **Audit Logs**; verify that the app displays a prompt explaining that history and audit logs require an account.

### B. Manual Redaction Coordinate Alignment Flow
1. Select a document and choose **Manual Selection** or **Automatic + Manual**.
2. On the interactive canvas, draw a selection rectangle tightly around a specific element (e.g., photo region or date of birth).
3. Select visual treatment: `Redact` (blackout), `Mask`, or `Blur`.
4. Process the document.
5. In the resulting preview, verify that the redacted rectangle matches the exact position and dimensions drawn on the canvas, with zero horizontal or vertical offset.

### C. Multi-Page PDF Verification Flow
1. Upload a multi-page PDF document (e.g., a 2-page or 3-page test document).
2. In **Manual Selection** mode, draw a redaction region on Page 1 only.
3. Process the document and inspect the output PDF.
4. Verify:
   - Page 1 contains the redacted region.
   - Pages 2+ remain completely untouched with original formatting preserved.

### D. Authenticated User Flow
1. Register a new test account and log in.
2. Configure a 4 to 6 digit security PIN.
3. Process a document.
4. Navigate to **Audit Logs**; verify that the processing event is recorded with timestamp, document name, entity count, and policy reference.
5. Log out; verify the session token is revoked.

---

## 7. Pre-Commit Quality Gate Checklist

Before submitting pull requests or considering changes complete, run this comprehensive quality checklist:

```bash
# 1. Backend tests (all 80 must pass)
cd PII && .\venv\Scripts\python.exe -m unittest discover tests

# 2. Flutter static analysis (must report 0 issues)
flutter analyze lib test

# 3. Flutter tests (all 29 must pass)
flutter test

# 4. Flutter web release compilation
flutter build web --release

# 5. Git diff whitespace check
cd .. && git diff --check
```

