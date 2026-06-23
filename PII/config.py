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
    SECRET_KEY = _env('SECRET_KEY', default='your-secret-key-change-in-production')
    SESSION_TYPE = 'filesystem'
    
    # Database
    MYSQL_HOST = _env('MYSQL_HOST', 'DB_HOST', default='127.0.0.1')
    MYSQL_USER = _env('MYSQL_USER', 'DB_USER', default='root')
    MYSQL_PASSWORD = _env('MYSQL_PASSWORD', 'DB_PASSWORD', default='')
    MYSQL_DB = _env('MYSQL_DB', 'DB_NAME', default='pii_redaction_db')
    MYSQL_CURSORCLASS = 'DictCursor'
    
    # Tesseract OCR Path (Windows)
    TESSERACT_CMD = _env('TESSERACT_CMD', default=r'C:\Program Files\Tesseract-OCR\tesseract.exe')
    
    # Upload settings for AI modules
    UPLOAD_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'uploads')
    REDACTED_FOLDER = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'uploads', 'redacted')
    ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'webp', 'bmp', 'tiff', 'pdf', 'gif', 'docx', 'txt'}
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB max upload


class DevelopmentConfig(Config):
    """Development configuration"""
    DEBUG = True
    TESTING = False


class ProductionConfig(Config):
    """Production configuration"""
    DEBUG = False
    TESTING = False


class TestingConfig(Config):
    """Testing configuration"""
    DEBUG = True
    TESTING = True
    MYSQL_DB = 'privlock_test'


config = {
    'development': DevelopmentConfig,
    'production': ProductionConfig,
    'testing': TestingConfig,
    'default': DevelopmentConfig
}
