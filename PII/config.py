import os
from dotenv import load_dotenv

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
WORKSPACE_DIR = os.path.dirname(BASE_DIR)

# Load the workspace .env first, then let the backend-local .env override it.
load_dotenv(os.path.join(WORKSPACE_DIR, '.env'))
load_dotenv(os.path.join(BASE_DIR, '.env'), override=True)


def _env(*names, default=None):
    for name in names:
        value = os.getenv(name)
        if value not in (None, ''):
            return value
    return default

class Config:
    """Base configuration"""
    SECRET_KEY = _env('SECRET_KEY', default='dev-insecure-secret-key-change-in-production')
    SESSION_TYPE = 'filesystem'
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SECURE = _env('SESSION_COOKIE_SECURE', default='false').lower() in ('true', '1')
    SESSION_COOKIE_SAMESITE = 'None' if SESSION_COOKIE_SECURE else 'Lax'
    PERMANENT_SESSION_LIFETIME = int(_env('SESSION_LIFETIME_SECONDS', default=7 * 86400))
    AUTH_TOKEN_TTL_HOURS = int(_env('AUTH_TOKEN_TTL_HOURS', default=24))

    # CORS Allowed Origins
    FRONTEND_URL = _env('FRONTEND_URL', default=None)
    CORS_ALLOWED_ORIGINS = _env('CORS_ALLOWED_ORIGINS', default=None)

    # Database
    DATABASE_URL = _env('DATABASE_URL', default=None)
    USE_SQLITE = _env('USE_SQLITE', default='false').lower() in ('true', '1')
    POSTGRES_POOL_SIZE = int(_env('POSTGRES_POOL_SIZE', default=5))
    MYSQL_HOST = _env('MYSQL_HOST', 'DB_HOST', default='127.0.0.1')
    MYSQL_PORT = int(_env('MYSQL_PORT', 'DB_PORT', default=3306))
    MYSQL_USER = _env('MYSQL_USER', 'DB_USER', default='root')
    MYSQL_PASSWORD = _env('MYSQL_PASSWORD', 'DB_PASSWORD', default='')
    MYSQL_DB = _env('MYSQL_DB', 'DB_NAME', default='pii_redaction_system')
    MYSQL_CURSORCLASS = 'DictCursor'
    MYSQL_POOL_SIZE = int(_env('MYSQL_POOL_SIZE', default=10))

    # Tesseract OCR Path (Windows/Linux/macOS)
    TESSERACT_CMD = _env(
        'TESSERACT_CMD',
        default=r'C:\Program Files\Tesseract-OCR\tesseract.exe' if os.name == 'nt' else '/usr/bin/tesseract'
    )

    # Upload settings for AI modules
    UPLOAD_FOLDER = os.path.join(BASE_DIR, 'uploads')
    REDACTED_FOLDER = os.path.join(BASE_DIR, 'uploads', 'redacted')
    ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'webp', 'bmp', 'tiff', 'pdf', 'txt'}
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB max upload


class DevelopmentConfig(Config):
    """Development configuration"""
    DEBUG = True
    TESTING = False


class ProductionConfig(Config):
    """Production configuration"""
    DEBUG = False
    TESTING = False
    SESSION_COOKIE_SECURE = True
    SESSION_COOKIE_SAMESITE = 'None'


class TestingConfig(Config):
    """Testing configuration"""
    DEBUG = True
    TESTING = True
    MYSQL_DB = _env('MYSQL_TEST_DB', default='pii_redaction_test_db')
    UPLOAD_FOLDER = os.path.join(BASE_DIR, 'test_uploads')
    REDACTED_FOLDER = os.path.join(BASE_DIR, 'test_uploads', 'redacted')


config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': DevelopmentConfig
}
