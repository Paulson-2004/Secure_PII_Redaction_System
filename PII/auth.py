import bcrypt
from database import db


def hash_password(password):
    """Hash a password using bcrypt"""
    salt = bcrypt.gensalt(rounds=10)
    return bcrypt.hashpw(password.encode('utf-8'), salt).decode('utf-8')


def verify_password(password, hashed_password):
    """Verify a password against its hash"""
    return bcrypt.checkpw(password.encode('utf-8'), hashed_password.encode('utf-8'))


def hash_pin(pin):
    """Hash a PIN code using bcrypt"""
    salt = bcrypt.gensalt(rounds=10)
    return bcrypt.hashpw(pin.encode('utf-8'), salt).decode('utf-8')


def verify_pin(pin, hashed_pin):
    """Verify a PIN against its hash"""
    return bcrypt.checkpw(pin.encode('utf-8'), hashed_pin.encode('utf-8'))


def get_user_by_username(username):
    """Get user from database by username"""
    sql = "SELECT id, username, email, password FROM users WHERE username = %s"
    return db.query_one(sql, (username,))


def get_user_by_email(email):
    """Get user from database by email"""
    sql = "SELECT id, username, email, password FROM users WHERE email = %s"
    return db.query_one(sql, (email,))


def user_exists(username, email):
    """Check if user with username or email already exists"""
    sql = "SELECT id FROM users WHERE username = %s OR email = %s"
    result = db.query(sql, (username, email))
    return len(result) > 0 if result else False


def create_user(username, email, password):
    """Create a new user in the database"""
    hashed_password = hash_password(password)
    sql = "INSERT INTO users (username, email, password) VALUES (%s, %s, %s)"
    result = db.execute(sql, (username, email, hashed_password))
    return result is not None


def save_pin_code(user_id, pin):
    """Save or update PIN code for a user"""
    hashed_pin = hash_pin(pin)
    sql = """
    INSERT INTO user_security (user_id, pin_code)
    VALUES (%s, %s)
    ON DUPLICATE KEY UPDATE pin_code = %s, updated_at = NOW()
    """
    result = db.execute(sql, (user_id, hashed_pin, hashed_pin))
    return result is not None


def save_fingerprint(user_id, fingerprint_data):
    """Save or update fingerprint data for a user"""
    sql = """
    INSERT INTO user_security (user_id, fingerprint_data, is_fingerprint_enabled)
    VALUES (%s, %s, TRUE)
    ON DUPLICATE KEY UPDATE fingerprint_data = %s, is_fingerprint_enabled = TRUE, updated_at = NOW()
    """
    result = db.execute(sql, (user_id, fingerprint_data, fingerprint_data))
    return result is not None


def get_user_security(user_id):
    """Get security info (PIN and fingerprint) for a user"""
    sql = """
    SELECT id, user_id, pin_code, fingerprint_data, is_fingerprint_enabled, created_at, updated_at
    FROM user_security WHERE user_id = %s
    """
    return db.query_one(sql, (user_id,))


def verify_user_pin(user_id, pin):
    """Verify if provided PIN matches user's saved PIN"""
    security = get_user_security(user_id)
    if not security or not security['pin_code']:
        return False
    return verify_pin(pin, security['pin_code'])


def verify_user_fingerprint(user_id, fingerprint_data):
    """Verify if provided fingerprint matches user's saved fingerprint"""
    security = get_user_security(user_id)
    if not security or not security['fingerprint_data'] or not security['is_fingerprint_enabled']:
        return False
    # Simple comparison - in production, use proper fingerprint matching algorithm
    return security['fingerprint_data'] == fingerprint_data


def update_user_password(user_id, current_password, new_password):
    """Update the user's account password after verifying the current password"""
    sql = "SELECT password FROM users WHERE id = %s"
    user = db.query_one(sql, (user_id,))
    if not user or not verify_password(current_password, user['password']):
        return False

    new_hashed_password = hash_password(new_password)
    sql = "UPDATE users SET password = %s WHERE id = %s"
    result = db.execute(sql, (new_hashed_password, user_id))
    return result is not None


def delete_user_security(user_id):
    """Delete security info for a user"""
    sql = "DELETE FROM user_security WHERE user_id = %s"
    result = db.execute(sql, (user_id,))
    return result is not None
