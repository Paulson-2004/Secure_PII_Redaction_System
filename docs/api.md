# API Reference

Base URL (local dev):
- Emulator: `http://10.0.2.2:8000`
- Physical device on LAN: `http://<your-ip>:8000`

## POST /process/
Upload a file and return redacted output.

Query params:
- `return_pdf=true` to return a PDF (text-only) instead of JSON.
- `return_redacted_file=true` to return a redacted image/PDF (black boxes).

Request:
- `multipart/form-data`
- field name: `file`

Response (JSON):
```json
{
  "total_pii_detected": 3,
  "redacted_text": "Name: ██████",
  "boxes": [
    {
      "x": 10, "y": 20, "w": 100, "h": 20,
      "page": 0, "type": "PERSON",
      "start": 0, "end": 8
    }
  ],
  "pii": [
    {
      "type": "EMAIL",
      "value": "john@gmail.com",
      "start": 25,
      "end": 39,
      "source": "regex"
    }
  ]
}
```

Response (PDF):
- `application/pdf` when `return_pdf=true`
- `application/pdf` when `return_redacted_file=true` and input is PDF
- `image/png` when `return_redacted_file=true` and input is image

Errors:
- `400` unsupported file type/content type
- `413` file too large

## GET /health
Simple health check:
```json
{ "status": "ok" }
```

## GET /config (debug)
Only enabled when `APP_ENABLE_CONFIG_DEBUG=true`.

## GET /decrypt (admin)
Only enabled when `APP_ENABLE_DECRYPT_ENDPOINT=true` and encryption is enabled.
Query params:
- `filename`
- `token`

## Auth

### POST /auth/register
Create a user.

Request:
```json
{ "username": "alice", "password": "StrongPass123!", "email": "alice@example.com" }
```

Password rules:
- Minimum 8 characters
- At least 1 uppercase, 1 lowercase, 1 number, 1 special character

### POST /auth/login
Login and receive a user token.

### POST /auth/logout?user_token=<token>
Invalidate the current user token.

### POST /auth/change-password?user_token=<token>
```json
{ "old_password": "...", "new_password": "StrongPass123!" }
```

### POST /auth/forgot-password
Request a reset token via email (SMTP).

```json
{ "email": "alice@example.com" }
```

### POST /auth/reset-password-token
Reset using the emailed token.

```json
{ "token": "<token>", "new_password": "StrongPass123!" }
```

### POST /auth/reset-password?token=<admin_token>
Admin-only reset.

```json
{ "username": "alice", "new_password": "StrongPass123!" }
```

## Logs

### GET /logs
Query params:
- `limit`, `offset`
- `filename`, `pii_type`
- `date_from`, `date_to` (ISO)
- `sort_by` (`created_at`, `size_bytes`, `total_pii`, `filename`)
- `sort_dir` (`asc`, `desc`)
- `token` (API/admin token)
- `user_token` (optional, scope to user)

### GET /logs/{id}
Returns a single log entry.
