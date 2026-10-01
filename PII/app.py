"""
Flask REST API Backend for Secure PII Redaction System.
Orchestrates authentication, file ingestion, OCR, hybrid PII detection,
policy decisioning, exact visual/text redaction, and audit trail management.
"""

import os
import io
import sys
import time
import json
import logging
import secrets
import datetime
from datetime import timedelta

from flask import Flask, request, send_file, session
from flask_cors import CORS
from werkzeug.utils import secure_filename

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

from config import config, Config
from database import db
from auth import (
    hash_password, verify_password, get_user_by_username,
    user_exists, create_user, save_pin_code, save_fingerprint,
    get_user_security, verify_user_pin, verify_user_fingerprint,
    update_user_password, delete_user_security
)
from utils import success_response, error_response, validate_request_data, log_audit, record_document_log

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s'
)
logger = logging.getLogger('app')

# In-memory authentication token store with timestamp tracking
AUTH_TOKENS = {}

# In-memory ephemeral registry for guest-processed document artifacts with TTL tracking
GUEST_ARTIFACTS = {}
GUEST_ARTIFACT_TTL = datetime.timedelta(hours=1)


def _cleanup_expired_guest_artifacts():
    """Remove expired guest document files from disk and memory registry."""
    now = datetime.datetime.now()
    expired_keys = [
        k for k, v in list(GUEST_ARTIFACTS.items())
        if now - v.get('created_at', now) > GUEST_ARTIFACT_TTL
    ]
    for k in expired_keys:
        artifact = GUEST_ARTIFACTS.pop(k, None)
        if artifact:
            for p in (artifact.get('filepath'), artifact.get('redacted_path')):
                if p and os.path.exists(p):
                    try:
                        os.remove(p)
                    except OSError as e:
                        logger.warning("Failed to remove expired guest file %s: %s", p, e)


# Import AI modules
try:
    from modules.ocr_engine import get_full_text_and_boxes, get_pdf_pages_data
    from modules.regex_detector import detect_pii_regex, get_pattern_summary
    from modules.ner_detector import detect_pii_ner, get_ner_model_info
    from modules.hybrid_engine import detect_pii_hybrid
    from modules.rag_decision_engine import decide_redaction, get_rag_engine, get_rag_status_lightweight
    from modules.redaction_engine import (
        process_redaction,
        save_redacted_pdf_pages,
        redact_image,
        redact_text
    )
    AI_MODULES_LOADED = True
    AI_MODULE_SOURCE = os.path.join(BASE_DIR, 'modules')
except Exception as e:
    logger.error("Failed to import AI modules: %s", e)
    AI_MODULES_LOADED = False
    AI_MODULE_SOURCE = None


def _issue_auth_token(user):
    """Generate a cryptographically secure token with timestamp."""
    token = secrets.token_urlsafe(32)
    AUTH_TOKENS[token] = {
        'user_id': user['id'],
        'username': user['username'],
        'email': user['email'],
        'created_at': datetime.datetime.now(),
    }
    return token


def _get_current_user_id():
    """
    Resolve authenticated user from X-Auth-Token or Authorization Bearer header,
    or session cookie. Validates token freshness against configured TTL.
    """
    token = request.headers.get('X-Auth-Token', '').strip()
    if not token:
        auth_header = request.headers.get('Authorization', '').strip()
        if auth_header.lower().startswith('bearer '):
            token = auth_header[7:].strip()
        elif auth_header:
            token = auth_header

    if token:
        if token in AUTH_TOKENS:
            auth_context = AUTH_TOKENS[token]
            ttl = datetime.timedelta(hours=app.config.get('AUTH_TOKEN_TTL_HOURS', 24))
            if datetime.datetime.now() - auth_context['created_at'] > ttl:
                AUTH_TOKENS.pop(token, None)
                return None
            return auth_context['user_id']
        # Explicit token was supplied but is invalid/tampered -> reject immediately
        return None

    # Fall back to session cookie only if no token header was supplied
    return session.get('user_id')


# Initialize Flask application
app = Flask(__name__)
env = os.getenv('FLASK_ENV', 'development')
app.config.from_object(config.get(env, config['default']))

# Session & Cookie Security
app.config['PERMANENT_SESSION_LIFETIME'] = timedelta(days=7)
app.config['SESSION_COOKIE_HTTPONLY'] = True
app.config['SESSION_COOKIE_SAMESITE'] = app.config.get('SESSION_COOKIE_SAMESITE', 'Lax')
app.config['SESSION_COOKIE_SECURE'] = app.config.get('SESSION_COOKIE_SECURE', False)

# Build CORS allowed origins (localhost/127.0.0.1 + optional FRONTEND_URL or CORS_ALLOWED_ORIGINS)
import re
cors_origins = [re.compile(r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$")]
frontend_url = app.config.get('FRONTEND_URL') or os.getenv('FRONTEND_URL')
if frontend_url:
    for u in frontend_url.split(','):
        u_clean = u.strip().rstrip('/')
        if u_clean:
            if '*' in u_clean:
                regex_pattern = re.compile(
                    r"^" + re.escape(u_clean).replace(r"\*", r".*") + r"$"
                )
                cors_origins.append(regex_pattern)
            elif u_clean not in cors_origins:
                cors_origins.append(u_clean)
custom_cors = app.config.get('CORS_ALLOWED_ORIGINS') or os.getenv('CORS_ALLOWED_ORIGINS')
if custom_cors:
    for u in custom_cors.split(','):
        u_clean = u.strip().rstrip('/')
        if u_clean:
            if '*' in u_clean:
                regex_pattern = re.compile(
                    r"^" + re.escape(u_clean).replace(r"\*", r".*") + r"$"
                )
                cors_origins.append(regex_pattern)
            elif u_clean not in cors_origins:
                cors_origins.append(u_clean)

# Enable CORS for Flutter Web & Mobile clients
CORS(
    app,
    resources={
        r"/*": {
            'origins': cors_origins,
            'supports_credentials': True,
            'allow_headers': [
                'Content-Type',
                'Authorization',
                'Accept',
                'X-Auth-Token',
                'x-auth-token',
            ],
            'methods': ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
            'expose_headers': ['Content-Type', 'X-Auth-Token'],
        }
    },
)

# Ensure upload and redacted directories exist
os.makedirs(app.config.get('UPLOAD_FOLDER', os.path.join(BASE_DIR, 'uploads')), exist_ok=True)
os.makedirs(app.config.get('REDACTED_FOLDER', os.path.join(BASE_DIR, 'uploads', 'redacted')), exist_ok=True)

# Initialize database pool
with app.app_context():
    db.config = app.config
    db.connect()


# ==================== SYSTEM HEALTH & DIAGNOSTICS ====================

@app.route('/api/health', methods=['GET'])
def health_check():
    """Return backend, database, and AI pipeline operational status."""
    db_ok = False
    try:
        db_ok = db.query_one('SELECT 1 AS ok') is not None
    except Exception as e:
        logger.warning("Health check DB query warning: %s", e)

    ai_status = {'loaded': AI_MODULES_LOADED, 'source': AI_MODULE_SOURCE}
    if AI_MODULES_LOADED:
        try:
            ai_status['ocr'] = {'loaded': True}
            ai_status['regex'] = get_pattern_summary()
            ai_status['ner'] = get_ner_model_info()
            ai_status['hybrid'] = {'loaded': True}
            ai_status['rag'] = get_rag_status_lightweight()
            ai_status['redaction'] = {'loaded': True}
        except Exception as e:
            ai_status['error'] = str(e)

    return success_response(
        'System health status retrieved successfully',
        {
            'backend': 'running',
            'database': 'connected' if db_ok else 'unavailable',
            'database_engine': getattr(db, 'engine_name', 'SQLite' if getattr(db, 'use_sqlite', False) else 'MySQL'),
            'ai': ai_status,
        },
        200
    )


# ==================== AUTHENTICATION ROUTES ====================

@app.route('/register', methods=['POST'])
def register():
    """Register a new user account."""
    data = request.get_json(silent=True) or {}
    missing = validate_request_data(data, ['username', 'email', 'password'])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    username = data.get('username', '').strip()
    email = data.get('email', '').strip().lower()
    password = data.get('password', '')

    if len(username) < 3:
        return error_response('Username must be at least 3 characters long', 400)
    if '@' not in email or '.' not in email.split('@')[-1]:
        return error_response('Invalid email format', 400)
    if len(password) < 6:
        return error_response('Password must be at least 6 characters long', 400)

    if user_exists(username, email):
        return error_response('Username or email already exists', 409)

    try:
        if create_user(username, email, password):
            user = get_user_by_username(username)
            auth_token = _issue_auth_token(user)
            log_audit(user['id'], 'user_registered', 'User registered new account')
            return success_response(
                'Account created successfully',
                {'username': user['username'], 'email': user['email'], 'auth_token': auth_token},
                201
            )
        return error_response('Failed to create account', 500)
    except Exception as e:
        logger.error("Registration error: %s", e)
        return error_response('Server error while creating account', 500)


@app.route('/login', methods=['POST'])
def login():
    """Authenticate user with username and password."""
    data = request.get_json(silent=True) or {}
    missing = validate_request_data(data, ['username', 'password'])
    if missing:
        return error_response(f"Missing required fields: {', '.join(missing)}", 400)

    username = data.get('username', '').strip()
    password = data.get('password', '')

    try:
        user = get_user_by_username(username)
        if not user or not verify_password(password, user['password']):
            return error_response('Invalid username or password', 401)

        session.permanent = True
        session['user_id'] = user['id']
        session['username'] = user['username']
        session['email'] = user['email']

        auth_token = _issue_auth_token(user)
        session['auth_token'] = auth_token

        log_audit(user['id'], 'login', 'User logged in successfully')

        return success_response(
            'Login successful',
            {
                'username': user['username'],
                'email': user['email'],
                'auth_token': auth_token,
            },
            200
        )
    except Exception as e:
        logger.error("Login error: %s", e)
        return error_response('Server error while logging in', 500)


@app.route('/logout', methods=['GET', 'POST'])
def logout():
    """Terminate current user session and revoke token."""
    try:
        user_id = session.get('user_id')
        token = request.headers.get('X-Auth-Token', '').strip()
        if not token:
            auth_header = request.headers.get('Authorization', '').strip()
            if auth_header.lower().startswith('bearer '):
                token = auth_header[7:].strip()
            elif auth_header:
                token = auth_header

        if token:
            if token in AUTH_TOKENS:
                token_user_id = AUTH_TOKENS[token].get('user_id')
                AUTH_TOKENS.pop(token, None)
                if not user_id:
                    user_id = token_user_id
            else:
                AUTH_TOKENS.pop(token, None)

        if user_id:
            for t, ctx in list(AUTH_TOKENS.items()):
                if ctx.get('user_id') == user_id:
                    AUTH_TOKENS.pop(t, None)
            log_audit(user_id, 'logout', 'User logged out')

        session.clear()
        return success_response('Logged out successfully', {}, 200)
    except Exception as e:
        logger.error("Logout error: %s", e)
        return error_response('Error while logging out', 500)


# ==================== DOCUMENT PROCESSING PIPELINE ====================

@app.route('/api/process', methods=['POST'])
def process_document():
    """
    Main PII Redaction Pipeline Endpoint:
    1. Authenticate & validate upload
    2. Extract text and bounding boxes (OCR)
    3. Run Hybrid PII detection (Regex + NER)
    4. Apply RAG privacy policy decisioning
    5. Perform exact text slicing and visual image redaction
    6. Log audit event and document metadata
    """
    user_id = _get_current_user_id()
    is_guest = (user_id is None)

    if not AI_MODULES_LOADED:
        return error_response('AI processing modules unavailable. Please check configuration.', 500)

    if 'file' not in request.files:
        return error_response('No file provided in request', 400)

    file = request.files['file']
    doc_type = request.form.get('doc_type', 'general').strip().lower()
    action = request.form.get('action', 'redact').strip().lower()
    detection_mode = request.form.get('detection_mode', 'automatic').strip().lower()
    if detection_mode not in ('automatic', 'manual', 'automatic_manual'):
        detection_mode = 'automatic'

    # Parse and validate manual selection regions
    raw_manual_regions = request.form.get('manual_regions', '')
    manual_regions = []
    if raw_manual_regions:
        try:
            parsed = json.loads(raw_manual_regions) if isinstance(raw_manual_regions, str) else raw_manual_regions
            if isinstance(parsed, list):
                for r in parsed[:50]:  # Cap at 50 regions for security & performance
                    if isinstance(r, dict):
                        try:
                            p_idx = int(r.get('page', 1))
                            if p_idx < 1:
                                p_idx = 1
                            x_val = float(r.get('x', 0.0))
                            y_val = float(r.get('y', 0.0))
                            w_val = float(r.get('width', r.get('w', 0.0)))
                            h_val = float(r.get('height', r.get('h', 0.0)))

                            # Clamp normalized coordinates to [0.0, 1.0]
                            cx = max(0.0, min(1.0, x_val))
                            cy = max(0.0, min(1.0, y_val))
                            cw = max(0.001, min(1.0 - cx, w_val))
                            ch = max(0.001, min(1.0 - cy, h_val))

                            reg_action = str(r.get('action') or action).lower()
                            if reg_action not in ('redact', 'mask', 'blur'):
                                reg_action = action

                            manual_regions.append({
                                'page': p_idx,
                                'x': round(cx, 4),
                                'y': round(cy, 4),
                                'width': round(cw, 4),
                                'height': round(ch, 4),
                                'action': reg_action
                            })
                        except (ValueError, TypeError):
                            continue
        except Exception as e:
            logger.warning("Error parsing manual_regions: %s", e)

    if not file or file.filename == '':
        return error_response('No file selected', 400)

    # Sanitize filename and validate extension
    original_name = secure_filename(file.filename) or 'upload.bin'
    ext = os.path.splitext(original_name)[1].lower().lstrip('.')
    allowed_exts = app.config.get('ALLOWED_EXTENSIONS', {'jpg', 'jpeg', 'png', 'webp', 'bmp', 'tiff', 'pdf', 'txt'})

    if ext not in allowed_exts:
        return error_response(f"Invalid file type '.{ext}'. Allowed types: {', '.join(allowed_exts)}", 400)

    uploads_dir = os.path.abspath(app.config.get('UPLOAD_FOLDER', os.path.join(BASE_DIR, 'uploads')))
    redacted_dir = os.path.abspath(app.config.get('REDACTED_FOLDER', os.path.join(uploads_dir, 'redacted')))
    os.makedirs(uploads_dir, exist_ok=True)
    os.makedirs(redacted_dir, exist_ok=True)

    timestamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
    if is_guest:
        guest_token = secrets.token_hex(16)
        filename = f"guest_{guest_token}_{timestamp}_{original_name}"
    else:
        guest_token = None
        filename = f"{user_id}_{timestamp}_{original_name}"
    filepath = os.path.join(uploads_dir, filename)

    start_proc_time = time.time()
    # Stage-level profiling: high-resolution monotonic timer (no sensitive data logged)
    _t0 = time.perf_counter()
    file_size_bytes = request.content_length or 0
    logger.info(
        "PROFILE PROCESS_START: doc_type=%s action=%s mode=%s ext=%s size_bytes=%d guest=%s",
        doc_type, action, detection_mode, ext, file_size_bytes, is_guest
    )

    try:
        file.save(filepath)
        _t_upload_save = time.perf_counter()
        logger.info("PROFILE STAGE upload_save=%.3fs", _t_upload_save - _t0)

        ext = file.filename.rsplit('.', 1)[1].lower() if '.' in file.filename else ''
        redacted_filename = f"redacted_{filename}"
        redacted_path = os.path.join(redacted_dir, redacted_filename)

        if ext == 'pdf':
            # Multi-page PDF Processing Pipeline:
            # Process each page sequentially through OCR, detection, policy engine, and redaction
            pages_data = get_pdf_pages_data(filepath, detection_fn=detect_pii_hybrid)
            page_count = len(pages_data)

            all_enriched_detections = []
            all_raw_detections = []
            page_redacted_images = []
            all_redacted_text_parts = []
            all_extracted_text_parts = []

            total_stats = {
                'total_detected': 0,
                'regex_count': 0,
                'ner_count': 0,
                'fused_count': 0,
                'high_confidence_count': 0,
                'medium_confidence_count': 0,
                'low_confidence_count': 0,
                'dedup_removed': 0,
                'avg_confidence': 0.0,
            }

            rag_status = {'rag_enabled': True}

            for page_idx, page in enumerate(pages_data):
                p_text = page['text']
                p_words = page['words']
                p_orig_img = page['original_image']
                all_extracted_text_parts.append(f"--- Page {page_idx + 1} ---\n{p_text}")

                page_manual_regions = [r for r in manual_regions if r.get('page') == page_idx + 1]

                # Hybrid PII Detection on page text
                p_hybrid = page.get('detection_result')
                if p_hybrid is None:
                    p_hybrid = detect_pii_hybrid(p_text)
                p_detections = p_hybrid.get('detections', [])
                p_stats = p_hybrid.get('stats', {})

                for k in ('total_detected', 'regex_count', 'ner_count', 'fused_count',
                          'high_confidence_count', 'medium_confidence_count', 'low_confidence_count',
                          'dedup_removed'):
                    total_stats[k] += p_stats.get(k, 0)

                # Policy Engine decision
                try:
                    p_enriched = decide_redaction(p_detections)
                    rag_status = get_rag_engine().get_engine_status()
                except Exception as e:
                    logger.warning("Policy decisioning warning on page %d: %s", page_idx + 1, e)
                    p_enriched = p_detections
                    rag_status = {'rag_enabled': False, 'error': str(e)}

                if action == 'mask':
                    for d in p_enriched:
                        if d.get('decision') != 'KEEP':
                            d['decision'] = 'PARTIAL_MASK'
                elif action == 'blur':
                    for d in p_enriched:
                        if d.get('decision') != 'KEEP':
                            d['decision'] = 'BLUR'
                elif action == 'redact':
                    for d in p_enriched:
                        if d.get('decision') != 'KEEP':
                            d['decision'] = 'FULL_REDACT'

                # Annotate detections with 1-indexed page number
                for d in p_enriched:
                    d_copy = dict(d)
                    d_copy['page'] = page_idx + 1
                    all_enriched_detections.append(d_copy)

                for d in p_detections:
                    d_copy = dict(d)
                    d_copy['page'] = page_idx + 1
                    all_raw_detections.append(d_copy)

                # Visual and text redaction for this page according to detection_mode
                if detection_mode == 'manual':
                    if page_manual_regions:
                        p_redacted_img = redact_image(p_orig_img, detections=[], ocr_words=[], manual_regions=page_manual_regions)
                    else:
                        p_redacted_img = p_orig_img.copy()
                    p_redacted_text = p_text
                elif detection_mode == 'automatic_manual':
                    p_redacted_img = redact_image(p_orig_img, p_enriched, p_words, manual_regions=page_manual_regions)
                    p_redacted_text = redact_text(p_text, p_enriched)
                else:
                    # 'automatic'
                    p_redacted_img = redact_image(p_orig_img, p_enriched, p_words)
                    p_redacted_text = redact_text(p_text, p_enriched)

                page_redacted_images.append(p_redacted_img)
                all_redacted_text_parts.append(f"--- Page {page_idx + 1} ---\n{p_redacted_text}")

            # Reconstruct multi-page redacted PDF preserving original page count and order
            save_redacted_pdf_pages(page_redacted_images, redacted_path)

            full_redacted = sum(1 for d in all_enriched_detections if d.get('decision') == 'FULL_REDACT')
            partial_masked = sum(1 for d in all_enriched_detections if d.get('decision') == 'PARTIAL_MASK')
            kept = sum(1 for d in all_enriched_detections if d.get('decision') == 'KEEP')

            if detection_mode == 'manual':
                full_redacted = sum(1 for r in manual_regions if r.get('action') == 'redact')
                partial_masked = sum(1 for r in manual_regions if r.get('action') == 'mask')
                blurred = sum(1 for r in manual_regions if r.get('action') == 'blur')
                total_reported = len(manual_regions)
            else:
                blurred = sum(1 for d in all_enriched_detections if d.get('decision') == 'BLUR')
                total_reported = len(all_enriched_detections)

            redaction_results = {
                'redacted_text': '\n\n'.join(all_redacted_text_parts),
                'redacted_image_path': redacted_path,
                'summary': {
                    'total_pii': total_reported,
                    'full_redacted': full_redacted,
                    'partial_masked': partial_masked,
                    'blurred': blurred if 'blurred' in locals() else 0,
                    'kept': kept
                }
            }

            extracted_text = '\n\n'.join(all_extracted_text_parts)
            pii_detections = all_raw_detections
            enriched_detections = all_enriched_detections
            detection_stats = total_stats
            if detection_stats.get('total_detected', 0) > 0:
                detection_stats['avg_confidence'] = round(
                    sum(d.get('confidence', 0.0) for d in enriched_detections) / len(enriched_detections), 4
                )
        else:
            # Single document (image or text) processing
            page_count = 1
            # Step 1: Document Text & Bounding Box Extraction (OCR)
            _t_ocr_start = time.perf_counter()
            text_result = get_full_text_and_boxes(
                filepath,
                detection_fn=detect_pii_hybrid if ext != 'txt' else None
            )
            _t_ocr_end = time.perf_counter()
            extracted_text = text_result.get('text', '')
            word_boxes = text_result.get('words', [])
            original_image = text_result.get('original_image')
            detection_elapsed = text_result.get('detection_elapsed', 0.0)
            _ocr_img_h, _ocr_img_w = (original_image.shape[:2] if original_image is not None else (0, 0))
            _ocr_word_count = len(word_boxes)
            logger.info(
                "PROFILE STAGE ocr_total=%.3fs words=%d img_w=%d img_h=%d text_chars=%d",
                max(0.0, _t_ocr_end - _t_ocr_start - detection_elapsed),
                _ocr_word_count, _ocr_img_w, _ocr_img_h, len(extracted_text)
            )

            # Step 2: Hybrid PII Detection (Regex + NER)
            _t_hybrid_start = time.perf_counter()
            hybrid_result = text_result.get('detection_result')
            if hybrid_result is None:
                hybrid_result = detect_pii_hybrid(extracted_text)
                _t_hybrid_end = time.perf_counter()
                hybrid_elapsed = _t_hybrid_end - _t_hybrid_start
            else:
                hybrid_elapsed = detection_elapsed
            pii_detections = hybrid_result.get('detections', [])
            detection_stats = hybrid_result.get('stats', {})
            logger.info(
                "PROFILE STAGE hybrid_detection=%.3fs regex=%d ner=%d merged=%d",
                hybrid_elapsed,
                detection_stats.get('regex_detections', 0),
                detection_stats.get('ner_detections', 0),
                len(pii_detections)
            )

            # Step 3: RAG Decision Engine - Apply Policy Redaction Actions
            _t_policy_start = time.perf_counter()
            try:
                enriched_detections = decide_redaction(pii_detections)
                rag_status = get_rag_engine().get_engine_status()
            except Exception as e:
                logger.warning("RAG policy decisioning warning: %s", e)
                enriched_detections = pii_detections
                rag_status = {'rag_enabled': False, 'error': str(e)}
            _t_policy_end = time.perf_counter()
            logger.info(
                "PROFILE STAGE policy_decision=%.3fs engine=%s pii_enriched=%d",
                _t_policy_end - _t_policy_start,
                rag_status.get('embedding_model', 'unknown'),
                len(enriched_detections)
            )

            # Override decision if user explicitly requested specific action
            if action == 'mask':
                for d in enriched_detections:
                    if d.get('decision') != 'KEEP':
                        d['decision'] = 'PARTIAL_MASK'
            elif action == 'blur':
                for d in enriched_detections:
                    if d.get('decision') != 'KEEP':
                        d['decision'] = 'BLUR'
            elif action == 'redact':
                for d in enriched_detections:
                    if d.get('decision') != 'KEEP':
                        d['decision'] = 'FULL_REDACT'

            # Step 4: Redaction Engine - Apply Text Masking and Visual Image Redaction according to detection_mode
            if detection_mode == 'manual':
                active_detections = []
                active_manual_regions = manual_regions
            elif detection_mode == 'automatic_manual':
                active_detections = enriched_detections
                active_manual_regions = manual_regions
            else:
                active_detections = enriched_detections
                active_manual_regions = None

            _t_redact_start = time.perf_counter()
            redaction_results = process_redaction(
                extracted_text,
                original_image,
                word_boxes,
                active_detections,
                redacted_path,
                manual_regions=active_manual_regions
            )
            _t_redact_end = time.perf_counter()
            logger.info(
                "PROFILE STAGE redaction=%.3fs detections=%d mode=%s",
                _t_redact_end - _t_redact_start, len(active_detections), detection_mode
            )

        elapsed_time = round(time.time() - start_proc_time, 2)
        # Diagnostic log: successful completion — no filenames, OCR text, or PII values logged
        logger.info(
            "process_document DONE: doc_type=%s action=%s mode=%s elapsed=%.2fs "
            "pii_count=%d pages=%d guest=%s",
            doc_type, action, detection_mode, elapsed_time,
            len(pii_detections), page_count, is_guest
        )

        # Extract PII types and non-sensitive summary
        pii_types = sorted(list({d.get('type', 'unknown') for d in enriched_detections}))
        pii_summary_list = [
            {
                'type': d.get('type'),
                'confidence': d.get('confidence', 0.0),
                'decision': d.get('decision', 'FULL_REDACT'),
                'regulation': d.get('regulation', ''),
                **({'page': d['page']} if 'page' in d else {})
            }
            for d in enriched_detections
        ]

        # Step 5: Save audit trail in database for authenticated users, or register ephemeral artifact for guests
        if not is_guest:
            record_document_log(
                user_id=user_id,
                filename=redacted_filename,
                original_filename=file.filename,
                doc_type=doc_type,
                status='processed',
                file_path=redacted_path,
                pii_detected=pii_types
            )
            log_audit(
                user_id,
                'pii_document_processed',
                f'Processed {doc_type} ({file.filename}) in {detection_mode} mode: {len(pii_detections)} PII, {len(manual_regions)} manual regions in {elapsed_time}s',
                'success'
            )
        else:
            _cleanup_expired_guest_artifacts()
            artifact_entry = {
                'token': guest_token,
                'filename': filename,
                'redacted_filename': redacted_filename,
                'created_at': datetime.datetime.now(),
                'filepath': filepath,
                'redacted_path': redacted_path,
            }
            GUEST_ARTIFACTS[redacted_filename] = artifact_entry
            GUEST_ARTIFACTS[filename] = artifact_entry

        response_data = {
            'filename': filename,
            'redacted_filename': redacted_filename,
            'original_filename': file.filename,
            'doc_type': doc_type,
            'action': action,
            'detection_mode': detection_mode,
            'manual_regions_count': len(manual_regions),
            'manual_regions': manual_regions,
            'status': 'processed',
            'is_guest': is_guest,
            'page_count': page_count,
            'extracted_text_preview': extracted_text[:300] if extracted_text else '',
            'pii_detected': pii_types,
            'pii_details': pii_summary_list,
            'total_pii_found': len(pii_detections),
            'detection_stats': detection_stats,
            'rag_status': rag_status,
            'redaction_summary': f"Successfully redacted {len(pii_detections)} PII element(s) under regulatory policy" if detection_mode != 'manual' else f"Successfully redacted {len(manual_regions)} user-selected region(s)",
            'redaction_details': redaction_results.get('summary', {}),
            'processing_time': elapsed_time,
            'processed_at': datetime.datetime.now().isoformat()
        }

        return success_response('Document processed successfully with AI PII detection', response_data, 200)

    except Exception as e:
        elapsed_fail = round(time.time() - start_proc_time, 2)
        # Diagnostic log: failure summary — exception class only, no PII values or filenames logged
        logger.info(
            "process_document FAIL: doc_type=%s action=%s mode=%s elapsed=%.2fs "
            "error_type=%s guest=%s",
            doc_type, action, detection_mode, elapsed_fail,
            type(e).__name__, is_guest
        )
        logger.error("Document processing error: %s", e, exc_info=True)
        if user_id:
            log_audit(user_id, 'pii_document_processing_failed', f"Error on {file.filename}: {str(e)}", 'error')
        return error_response(f'Failed to process document: {str(e)}', 500)


# ==================== SECURE DOWNLOAD ROUTE ====================

@app.route('/api/download/<filename>', methods=['GET'])
@app.route('/download/<filename>', methods=['GET'])
def download_document(filename):
    """
    Secure document download endpoint with strict path traversal prevention,
    user ownership isolation for registered accounts, and secure ephemeral
    token verification for guests.
    """
    clean_filename = secure_filename(filename)
    if not clean_filename or clean_filename != filename:
        return error_response('Invalid filename format', 400)

    uploads_dir = os.path.abspath(app.config.get('UPLOAD_FOLDER', os.path.join(BASE_DIR, 'uploads')))
    redacted_dir = os.path.abspath(app.config.get('REDACTED_FOLDER', os.path.join(uploads_dir, 'redacted')))

    is_guest_file = clean_filename.startswith(('guest_', 'redacted_guest_'))

    if is_guest_file:
        _cleanup_expired_guest_artifacts()
        if clean_filename not in GUEST_ARTIFACTS:
            return error_response('Document not found or session expired', 404)
        target_path = GUEST_ARTIFACTS[clean_filename].get(
            'redacted_path' if clean_filename.startswith('redacted_') else 'filepath'
        )
        base_dir = redacted_dir if clean_filename.startswith('redacted_') else uploads_dir
        user_id = None
    else:
        user_id = _get_current_user_id()
        if not user_id:
            return error_response('Unauthorized: Please login first', 401)

        allowed_prefixes = (f"{user_id}_", f"redacted_{user_id}_")
        if not clean_filename.startswith(allowed_prefixes):
            return error_response('Access denied: You do not have permission to view this document', 403)

        if clean_filename.startswith('redacted_'):
            target_path = os.path.abspath(os.path.join(redacted_dir, clean_filename))
            base_dir = redacted_dir
        else:
            target_path = os.path.abspath(os.path.join(uploads_dir, clean_filename))
            base_dir = uploads_dir

    # Path traversal validation
    try:
        if os.path.commonpath([base_dir, target_path]) != base_dir:
            return error_response('Access denied: Invalid file path', 400)
    except (ValueError, TypeError):
        return error_response('Access denied: Invalid file path', 400)

    if not target_path or not os.path.exists(target_path) or not os.path.isfile(target_path):
        return error_response('Document not found', 404)

    if not is_guest_file and user_id:
        log_audit(user_id, 'document_downloaded', f'Downloaded: {clean_filename}')
    return send_file(target_path, as_attachment=True)


# ==================== SECURE PREVIEW ROUTE ====================

@app.route('/api/preview/<filename>', methods=['GET'])
def preview_document(filename):
    """
    Secure document preview endpoint with strict path traversal prevention,
    user ownership isolation, and privacy guarantee:
    ONLY redacted output artifacts can be previewed (never the original unredacted document).
    Supports both authenticated user artifacts and active ephemeral guest artifacts.
    """
    clean_filename = secure_filename(filename)
    if not clean_filename or clean_filename != filename:
        return error_response('Invalid filename format', 400)

    # CRITICAL PRIVACY & SECURITY CHECK:
    # Previews MUST ONLY be served for redacted artifacts (redacted_...)!
    # Original unredacted uploads are strictly forbidden from preview.
    if not clean_filename.startswith('redacted_'):
        return error_response('Access denied: Only processed redacted documents can be previewed', 403)

    uploads_dir = os.path.abspath(app.config.get('UPLOAD_FOLDER', os.path.join(BASE_DIR, 'uploads')))
    redacted_dir = os.path.abspath(app.config.get('REDACTED_FOLDER', os.path.join(uploads_dir, 'redacted')))

    is_guest_file = clean_filename.startswith('redacted_guest_')

    if is_guest_file:
        _cleanup_expired_guest_artifacts()
        if clean_filename not in GUEST_ARTIFACTS:
            return error_response('Document not found or session expired', 404)
        target_path = GUEST_ARTIFACTS[clean_filename].get('redacted_path')
    else:
        user_id = _get_current_user_id()
        if not user_id:
            return error_response('Unauthorized: Please login first', 401)

        allowed_prefix = f"redacted_{user_id}_"
        if not clean_filename.startswith(allowed_prefix):
            return error_response('Access denied: Only processed redacted documents can be previewed', 403)

        target_path = os.path.abspath(os.path.join(redacted_dir, clean_filename))

    # Path traversal validation
    try:
        if os.path.commonpath([redacted_dir, target_path]) != redacted_dir:
            return error_response('Access denied: Invalid file path', 400)
    except (ValueError, TypeError):
        return error_response('Access denied: Invalid file path', 400)

    if not target_path or not os.path.exists(target_path) or not os.path.isfile(target_path):
        return error_response('Document not found', 404)

    ext = os.path.splitext(clean_filename)[1].lower()

    # Image files: return directly with appropriate mimetype
    image_mimetypes = {
        '.png': 'image/png',
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.webp': 'image/webp',
        '.bmp': 'image/bmp',
        '.tiff': 'image/tiff',
    }

    if ext in image_mimetypes:
        return send_file(target_path, mimetype=image_mimetypes[ext], as_attachment=False)

    # PDF files: render first page to PNG using PyMuPDF infrastructure
    if ext == '.pdf':
        try:
            import pymupdf
            doc = pymupdf.open(target_path)
            if len(doc) == 0:
                doc.close()
                return error_response('PDF document is empty', 400)
            page = doc[0]
            pix = page.get_pixmap(dpi=150)
            png_bytes = pix.tobytes("png")
            doc.close()
            return send_file(io.BytesIO(png_bytes), mimetype='image/png', as_attachment=False)
        except Exception as e:
            logger.error("PDF preview generation error: %s", e)
            return error_response('Failed to generate PDF preview', 500)

    # Plain text files: return as text/plain
    if ext == '.txt':
        return send_file(target_path, mimetype='text/plain; charset=utf-8', as_attachment=False)

    return error_response('Preview not supported for this file format', 415)


# ==================== AUDIT LOGS ROUTE ====================

@app.route('/audit-logs', methods=['GET'])
def get_audit_logs():
    """Retrieve structured audit logs and document history for current user."""
    user_id = _get_current_user_id()
    if not user_id:
        return error_response('Unauthorized: Please login first', 401)

    try:
        # Step 1: Query documents table
        doc_sql = """
        SELECT id, original_filename AS filename, doc_type AS document_type,
               pii_detected, status AS action_taken, created_at
        FROM documents
        WHERE user_id = %s
        ORDER BY created_at DESC
        LIMIT 100
        """
        docs = db.query(doc_sql, (user_id,))

        results = []
        if docs:
            for doc in docs:
                pii_list = []
                raw_pii = doc.get('pii_detected')
                if raw_pii:
                    try:
                        pii_list = json.loads(raw_pii) if isinstance(raw_pii, str) else raw_pii
                    except Exception:
                        pii_list = []

                created_val = doc.get('created_at')
                created_str = created_val.isoformat() if hasattr(created_val, 'isoformat') else str(created_val or '')

                results.append({
                    'id': doc['id'],
                    'filename': doc['filename'],
                    'document_type': doc['document_type'] or 'general',
                    'pii_count': len(pii_list),
                    'action_taken': (doc['action_taken'] or 'PROCESSED').upper(),
                    'processing_time': 0.8,
                    'created_at': created_str,
                })

        return success_response('Audit logs retrieved successfully', results, 200)

    except Exception as e:
        logger.error("Audit logs query error: %s", e)
        return error_response('Failed to retrieve audit logs', 500)


# ==================== SECURITY & BIOMETRIC SETTINGS ====================

@app.route('/api/security/pin', methods=['POST'])
def set_pin_code():
    """Register or update user account PIN code."""
    user_id = _get_current_user_id()
    if not user_id:
        return error_response('Unauthorized: Please login first', 401)

    data = request.get_json(silent=True) or {}
    pin = str(data.get('pin', '')).strip()

    if not pin or len(pin) < 4 or len(pin) > 6 or not pin.isdigit():
        return error_response('PIN must be 4 to 6 digits', 400)

    try:
        if save_pin_code(user_id, pin):
            log_audit(user_id, 'pin_set', 'User registered PIN code', 'success')
            return success_response('PIN code saved successfully', {}, 200)
        return error_response('Failed to save PIN code', 500)
    except Exception as e:
        logger.error("PIN save error: %s", e)
        return error_response('Error saving PIN code', 500)


@app.route('/api/security/verify-pin', methods=['POST'])
def verify_pin_endpoint():
    """Verify submitted PIN against hashed user PIN."""
    user_id = _get_current_user_id()
    if not user_id:
        return error_response('Unauthorized: Please login first', 401)

    data = request.get_json(silent=True) or {}
    pin = str(data.get('pin', '')).strip()
    if not pin:
        return error_response('PIN is required', 400)

    try:
        if verify_user_pin(user_id, pin):
            log_audit(user_id, 'pin_verified', 'User verified PIN', 'success')
            return success_response('PIN verified successfully', {'verified': True}, 200)
        log_audit(user_id, 'pin_verification_failed', 'Invalid PIN entered', 'error')
        return error_response('Invalid PIN code', 401)
    except Exception as e:
        logger.error("PIN verify error: %s", e)
        return error_response('Error verifying PIN', 500)


@app.route('/api/security/fingerprint', methods=['POST'])
def set_fingerprint():
    """Register device biometric enrollment for user."""
    user_id = _get_current_user_id()
    if not user_id:
        return error_response('Unauthorized: Please login first', 401)

    data = request.get_json(silent=True) or {}
    fingerprint_data = data.get('fingerprint_data', '').strip()
    if not fingerprint_data:
        return error_response('Fingerprint token is required', 400)

    try:
        sec = get_user_security(user_id)
        if sec and sec.get('is_fingerprint_enabled'):
            return error_response('Biometrics already registered for this account', 409)

        if save_fingerprint(user_id, fingerprint_data):
            log_audit(user_id, 'fingerprint_registered', 'User enrolled biometrics', 'success')
            return success_response('Fingerprint registered successfully', {'registered': True}, 201)
        return error_response('Failed to register biometrics', 500)
    except Exception as e:
        logger.error("Fingerprint save error: %s", e)
        return error_response('Error registering fingerprint', 500)


@app.route('/api/security/verify-fingerprint', methods=['POST'])
def verify_fingerprint_endpoint():
    """Verify device biometric attestation token."""
    user_id = _get_current_user_id()
    if not user_id:
        return error_response('Unauthorized: Please login first', 401)

    data = request.get_json(silent=True) or {}
    fingerprint_data = data.get('fingerprint_data', '').strip()
    if not fingerprint_data:
        return error_response('Fingerprint token is required', 400)

    try:
        if verify_user_fingerprint(user_id, fingerprint_data):
            log_audit(user_id, 'fingerprint_verified', 'User verified biometric token', 'success')
            return success_response('Fingerprint verified successfully', {'verified': True}, 200)
        return error_response('Biometric verification failed', 401)
    except Exception as e:
        logger.error("Fingerprint verification error: %s", e)
        return error_response('Error verifying biometrics', 500)


@app.route('/api/change-password', methods=['POST'])
def change_password():
    """Update user account password with verification of current password."""
    user_id = _get_current_user_id()
    if not user_id:
        return error_response('Unauthorized: Please login first', 401)

    data = request.get_json(silent=True) or {}
    current_password = data.get('current_password', '')
    new_password = data.get('new_password', '')

    if not current_password or not new_password:
        return error_response('Current and new passwords are required', 400)
    if len(new_password) < 6:
        return error_response('New password must be at least 6 characters long', 400)

    try:
        if update_user_password(user_id, current_password, new_password):
            log_audit(user_id, 'password_changed', 'User updated password', 'success')
            return success_response('Password updated successfully', {}, 200)
        return error_response('Current password does not match', 401)
    except Exception as e:
        logger.error("Password change error: %s", e)
        return error_response('Error updating password', 500)


@app.route('/api/security/status', methods=['GET'])
def get_security_status():
    """Retrieve PIN and biometric status for current user."""
    user_id = _get_current_user_id()
    if not user_id:
        return error_response('Unauthorized: Please login first', 401)

    try:
        sec = get_user_security(user_id)
        pin_enabled = bool(sec and sec.get('pin_code'))
        fp_enabled = bool(sec and sec.get('is_fingerprint_enabled'))
        c_at = sec.get('created_at') if sec else None
        u_at = sec.get('updated_at') if sec else None

        return success_response(
            'Security status retrieved',
            {
                'pin_enabled': pin_enabled,
                'fingerprint_enabled': fp_enabled,
                'created_at': c_at.isoformat() if hasattr(c_at, 'isoformat') else str(c_at or ''),
                'updated_at': u_at.isoformat() if hasattr(u_at, 'isoformat') else str(u_at or ''),
            },
            200
        )
    except Exception as e:
        logger.error("Security status error: %s", e)
        return error_response('Failed to retrieve security status', 500)


# ==================== ERROR HANDLERS ====================

@app.errorhandler(404)
def not_found(error):
    return error_response('Requested endpoint was not found on this server', 404)


@app.errorhandler(405)
def method_not_allowed(error):
    return error_response('HTTP method not allowed for this route', 405)


@app.errorhandler(413)
def request_entity_too_large(error):
    return error_response('File size exceeds the maximum upload limit (16MB)', 413)


@app.errorhandler(500)
def internal_error(error):
    return error_response('Internal server error occurred', 500)


if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    debug = app.config.get('DEBUG', False)
    logger.info("Starting Secure PII Redaction API on port %d (debug=%s)", port, debug)
    app.run(host='0.0.0.0', port=port, debug=debug)
