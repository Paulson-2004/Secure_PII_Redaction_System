from flask import jsonify
from datetime import datetime


def success_response(message, data=None, status_code=200):
    """Create a standardized success response"""
    response = {
        'success': True,
        'message': message,
    }
    if data is not None:
        response['data'] = data
    return jsonify(response), status_code


def error_response(message, status_code=400):
    """Create a standardized error response"""
    return jsonify({
        'success': False,
        'message': message,
    }), status_code


def log_audit(user_id, action, details=None, status='success'):
    """Log an action to the audit table"""
    from database import db
    
    sql = """
    INSERT INTO audit_logs (user_id, action, details, status, created_at)
    VALUES (%s, %s, %s, %s, %s)
    """
    now_str = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    db.execute(sql, (user_id, action, details, status, now_str))


def record_document_log(user_id, filename, original_filename, doc_type, status='processed', file_path=None, pii_detected=None):
    """Save processed document record into documents table for audit trails"""
    from database import db
    import json

    sql = """
    INSERT INTO documents (user_id, filename, original_filename, doc_type, status, file_path, pii_detected, created_at)
    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """
    pii_json = json.dumps(pii_detected) if pii_detected is not None else '[]'
    now_str = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    db.execute(sql, (user_id, filename, original_filename, doc_type, status, file_path or '', pii_json, now_str))


def validate_request_data(data, required_fields):
    """Validate that all required fields are present in request data"""
    missing_fields = [field for field in required_fields if field not in data or not data[field]]
    return missing_fields
