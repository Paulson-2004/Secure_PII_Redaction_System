# All In One Guide

## Database

The backend connects to MySQL database `privlock` on `127.0.0.1` using the credentials in [PII/.env](PII/.env).

The schema lives in [PII/schema.sql](PII/schema.sql). If you want the older root schema reference, it is in [database/schema.sql](database/schema.sql).

## What Runs

- Flask backend: [PII/app.py](PII/app.py)
- AI modules: [PII/modules](PII/modules)
- Upload and redaction output folders: [PII/uploads](PII/uploads) and [PII/uploads/redacted](PII/uploads/redacted)

## Run Backend

1. Open a terminal in `D:\PII\PII`.
2. Activate the project virtual environment:

```powershell
& D:\PII\.venv\Scripts\Activate.ps1
```

3. Start the backend:

```powershell
python app.py
```

4. Confirm it is alive:

```powershell
Invoke-WebRequest http://127.0.0.1:5000/api/health | Select-Object -ExpandProperty Content
```

## Run AI Pipeline Manually

The backend already wires OCR, regex detection, NER, hybrid fusion, RAG decisioning, and redaction through `/api/process`.

To test the AI flow, log in first, then upload an image or document through the backend API. The response includes OCR text, detected PII, RAG status, and the redacted output path.

## Test Backend

Run the backend smoke check from the project virtualenv:

```powershell
Set-Location D:\PII\PII
@'
import os
os.environ['FLASK_ENV'] = 'development'
from app import app
with app.test_client() as client:
    resp = client.get('/api/health')
    print(resp.status_code)
    print(resp.get_json())
'@ | & D:\PII\.venv\Scripts\python.exe -
```

Expected result:

- `status_code` should be `200`
- `database` should be `connected`
- `ai.loaded` should be `True`

## Test Database Only

If you want to verify MySQL separately, use the same `/api/health` endpoint or check `PII/database.py`, which connects with `MYSQL_HOST`, `MYSQL_USER`, `MYSQL_PASSWORD`, and `MYSQL_DB`.

## Optional Checks

- Backend unit smoke test: `python test_pipeline.py` from `D:\PII`
- Flutter test suite: `flutter test` from `D:\PII\PII` if you decide to include frontend validation later
