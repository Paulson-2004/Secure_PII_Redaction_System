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
    db.execute(sql, (user_id, action, details, status, datetime.now()))


def validate_request_data(data, required_fields):
    """Validate that all required fields are present in request data"""
    missing_fields = [field for field in required_fields if field not in data or not data[field]]
    return missing_fields
