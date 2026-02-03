from dataclasses import dataclass
from typing import List, Optional
import os

from dotenv import load_dotenv

try:
    import tomllib as tomli
except ImportError:  # Python < 3.11
    import tomli


load_dotenv()

CONFIG_PATH = os.getenv("APP_CONFIG_PATH", "config.toml")


def _env_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "y", "on"}


def _env_list(name: str, default: List[str]) -> List[str]:
    raw = os.getenv(name)
    if not raw:
        return default
    return [item.strip() for item in raw.split(",") if item.strip()]


def _env_int(name: str, default: int) -> int:
    raw = os.getenv(name)
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        return default


def _read_toml(path: str) -> dict:
    if not os.path.exists(path):
        return {}
    with open(path, "rb") as f:
        return tomli.load(f)


@dataclass(frozen=True)
class AppConfig:
    allowed_extensions: List[str]
    allowed_content_types: List[str]
    uploads_dir: str
    output_dir: str
    enable_config_debug: bool
    max_upload_mb: int
    enable_rag_stub: bool
    rag_vectordb_url: Optional[str]
    rag_vectordb_api_key: Optional[str]
    rag_db_path: str
    rag_collection: str
    rag_top_k: int
    openai_api_key: Optional[str]
    openai_embed_model: str
    openai_chat_model: str
    encryption_enabled: bool
    encryption_key: Optional[str]
    enable_decrypt_endpoint: bool
    admin_token: Optional[str]
    tesseract_cmd: Optional[str]
    use_preprocess: bool
    pdf_dpi: int
    ner_model_path: str
    db_url: Optional[str]
    db_echo: bool
    api_token: Optional[str]
    user_token_ttl_minutes: int
    reset_token_ttl_minutes: int
    smtp_host: Optional[str]
    smtp_port: int
    smtp_user: Optional[str]
    smtp_password: Optional[str]
    smtp_from: Optional[str]
    smtp_use_tls: bool


def _load_config() -> AppConfig:
    defaults = {
        "app": {
            "allowed_extensions": [".txt", ".pdf", ".png", ".jpg", ".jpeg", ".docx"],
            "allowed_content_types": [
                "text/plain",
                "application/pdf",
                "image/png",
                "image/jpeg",
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            ],
            "uploads_dir": "uploads",
            "output_dir": "outputs",
            "enable_config_debug": False,
            "max_upload_mb": 10,
            "enable_rag_stub": False,
            "rag_vectordb_url": "",
            "rag_vectordb_api_key": "",
            "rag_db_path": "rag_store",
            "rag_collection": "policy_rules",
            "rag_top_k": 3,
            "openai_api_key": "",
            "openai_embed_model": "text-embedding-3-small",
            "openai_chat_model": "gpt-4o-mini",
            "encryption_enabled": False,
            "encryption_key": "",
            "enable_decrypt_endpoint": False,
            "admin_token": "",
        },
        "ocr": {
            "tesseract_cmd": r"C:\Program Files\Tesseract-OCR\tesseract.exe",
            "use_preprocess": True,
            "pdf_dpi": 200,
        },
        "ner": {
            "model_path": "custom_pii_model",
        },
        "db": {
            "url": "",
            "echo": False,
        },
        "security": {
            "api_token": "",
            "user_token_ttl_minutes": 1440,
            "reset_token_ttl_minutes": 30,
        },
        "smtp": {
            "host": "",
            "port": 587,
            "user": "",
            "password": "",
            "from": "",
            "use_tls": True,
        },
    }

    toml_data = _read_toml(CONFIG_PATH)

    app = {**defaults["app"], **toml_data.get("app", {})}
    ocr = {**defaults["ocr"], **toml_data.get("ocr", {})}
    ner = {**defaults["ner"], **toml_data.get("ner", {})}
    db = {**defaults["db"], **toml_data.get("db", {})}
    security = {**defaults["security"], **toml_data.get("security", {})}
    smtp = {**defaults["smtp"], **toml_data.get("smtp", {})}

    allowed_extensions = _env_list("APP_ALLOWED_EXTENSIONS", app["allowed_extensions"])
    allowed_content_types = _env_list("APP_ALLOWED_CONTENT_TYPES", app["allowed_content_types"])
    uploads_dir = os.getenv("APP_UPLOADS_DIR", app["uploads_dir"])
    output_dir = os.getenv("APP_OUTPUT_DIR", app["output_dir"])
    enable_config_debug = _env_bool("APP_ENABLE_CONFIG_DEBUG", app["enable_config_debug"])
    max_upload_mb = _env_int("APP_MAX_UPLOAD_MB", app["max_upload_mb"])
    enable_rag_stub = _env_bool("APP_ENABLE_RAG_STUB", app["enable_rag_stub"])
    rag_vectordb_url = os.getenv("RAG_VECTORDB_URL", app["rag_vectordb_url"])
    rag_vectordb_api_key = os.getenv("RAG_VECTORDB_API_KEY", app["rag_vectordb_api_key"])
    rag_db_path = os.getenv("RAG_DB_PATH", app["rag_db_path"])
    rag_collection = os.getenv("RAG_COLLECTION", app["rag_collection"])
    rag_top_k = _env_int("RAG_TOP_K", app["rag_top_k"])
    openai_api_key = os.getenv("OPENAI_API_KEY", app["openai_api_key"])
    openai_embed_model = os.getenv("OPENAI_EMBED_MODEL", app["openai_embed_model"])
    openai_chat_model = os.getenv("OPENAI_CHAT_MODEL", app["openai_chat_model"])
    encryption_enabled = _env_bool("APP_ENCRYPTION_ENABLED", app["encryption_enabled"])
    encryption_key = os.getenv("APP_ENCRYPTION_KEY", app["encryption_key"])
    enable_decrypt_endpoint = _env_bool("APP_ENABLE_DECRYPT_ENDPOINT", app["enable_decrypt_endpoint"])
    admin_token = os.getenv("APP_ADMIN_TOKEN", app["admin_token"])

    tesseract_cmd = os.getenv("OCR_TESSERACT_CMD", ocr["tesseract_cmd"])
    use_preprocess = _env_bool("OCR_USE_PREPROCESS", ocr["use_preprocess"])
    pdf_dpi = _env_int("OCR_PDF_DPI", ocr["pdf_dpi"])

    model_path = os.getenv("NER_MODEL_PATH", ner["model_path"])
    db_url = os.getenv("DB_URL", db["url"])
    db_echo = _env_bool("DB_ECHO", db["echo"])
    api_token = os.getenv("APP_API_TOKEN", security["api_token"])
    user_token_ttl_minutes = _env_int(
        "APP_USER_TOKEN_TTL_MINUTES", security["user_token_ttl_minutes"]
    )
    reset_token_ttl_minutes = _env_int(
        "APP_RESET_TOKEN_TTL_MINUTES", security["reset_token_ttl_minutes"]
    )

    smtp_host = os.getenv("SMTP_HOST", smtp["host"])
    smtp_port = _env_int("SMTP_PORT", smtp["port"])
    smtp_user = os.getenv("SMTP_USER", smtp["user"])
    smtp_password = os.getenv("SMTP_PASSWORD", smtp["password"])
    smtp_from = os.getenv("SMTP_FROM", smtp["from"])
    smtp_use_tls = _env_bool("SMTP_USE_TLS", smtp["use_tls"])

    return AppConfig(
        allowed_extensions=allowed_extensions,
        allowed_content_types=allowed_content_types,
        uploads_dir=uploads_dir,
        output_dir=output_dir,
        enable_config_debug=enable_config_debug,
        max_upload_mb=max_upload_mb,
        enable_rag_stub=enable_rag_stub,
        rag_vectordb_url=rag_vectordb_url if rag_vectordb_url else None,
        rag_vectordb_api_key=rag_vectordb_api_key if rag_vectordb_api_key else None,
        rag_db_path=rag_db_path,
        rag_collection=rag_collection,
        rag_top_k=rag_top_k,
        openai_api_key=openai_api_key if openai_api_key else None,
        openai_embed_model=openai_embed_model,
        openai_chat_model=openai_chat_model,
        encryption_enabled=encryption_enabled,
        encryption_key=encryption_key if encryption_key else None,
        enable_decrypt_endpoint=enable_decrypt_endpoint,
        admin_token=admin_token if admin_token else None,
        tesseract_cmd=tesseract_cmd,
        use_preprocess=use_preprocess,
        pdf_dpi=pdf_dpi,
        ner_model_path=model_path,
        db_url=db_url if db_url else None,
        db_echo=db_echo,
        api_token=api_token if api_token else None,
        user_token_ttl_minutes=user_token_ttl_minutes,
        reset_token_ttl_minutes=reset_token_ttl_minutes,
        smtp_host=smtp_host if smtp_host else None,
        smtp_port=smtp_port,
        smtp_user=smtp_user if smtp_user else None,
        smtp_password=smtp_password if smtp_password else None,
        smtp_from=smtp_from if smtp_from else None,
        smtp_use_tls=smtp_use_tls,
    )


CONFIG = _load_config()
