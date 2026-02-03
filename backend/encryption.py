import base64
import os

from cryptography.hazmat.primitives.ciphers.aead import AESGCM


def _get_key() -> bytes:
    # Resolve config at call time so tests that reload config pick it up.
    from config import CONFIG

    if not CONFIG.encryption_enabled:
        raise ValueError("Encryption is disabled")

    if not CONFIG.encryption_key:
        raise ValueError("Encryption enabled but APP_ENCRYPTION_KEY is missing")

    try:
        key = base64.urlsafe_b64decode(CONFIG.encryption_key.encode("utf-8"))
    except Exception as exc:
        raise ValueError("APP_ENCRYPTION_KEY must be base64-encoded") from exc

    if len(key) != 32:
        raise ValueError("APP_ENCRYPTION_KEY must be 32 bytes (base64-encoded) for AES-256")

    return key


def encrypt_bytes(data: bytes) -> bytes:
    key = _get_key()
    aesgcm = AESGCM(key)
    nonce = os.urandom(12)
    ciphertext = aesgcm.encrypt(nonce, data, None)
    return nonce + ciphertext


def decrypt_bytes(data: bytes) -> bytes:
    key = _get_key()
    if len(data) < 13:
        raise ValueError("Invalid encrypted payload")
    nonce = data[:12]
    ciphertext = data[12:]
    aesgcm = AESGCM(key)
    return aesgcm.decrypt(nonce, ciphertext, None)


def generate_key() -> str:
    key = os.urandom(32)
    return base64.urlsafe_b64encode(key).decode("utf-8")
