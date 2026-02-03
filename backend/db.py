from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone, timedelta
from typing import Dict, Optional
import hashlib
import secrets
import uuid

import bcrypt

from sqlalchemy import JSON, Column, DateTime, Integer, String, create_engine, desc
from sqlalchemy.orm import declarative_base, sessionmaker

from config import CONFIG

Base = declarative_base()


class RedactionLog(Base):
    __tablename__ = "redaction_logs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, nullable=True)
    username = Column(String(150), nullable=True)
    filename = Column(String(255), nullable=False)
    content_type = Column(String(255), nullable=False)
    size_bytes = Column(Integer, nullable=False)
    total_pii = Column(Integer, nullable=False)
    pii_counts = Column(JSON, nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False)


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String(150), nullable=False, unique=True)
    email = Column(String(255), nullable=True, unique=True)
    password_hash = Column(String(255), nullable=False)
    api_token = Column(String(64), nullable=True)
    token_expires_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False)


class PasswordResetToken(Base):
    __tablename__ = "password_reset_tokens"

    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, nullable=False)
    token_hash = Column(String(64), nullable=False, unique=True)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    used_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False)


@dataclass(frozen=True)
class RedactionLogData:
    user_id: Optional[int]
    username: Optional[str]
    filename: str
    content_type: str
    size_bytes: int
    total_pii: int
    pii_counts: Dict[str, int]


def _get_engine():
    if not CONFIG.db_url:
        return None
    return create_engine(CONFIG.db_url, echo=CONFIG.db_echo, future=True)


_ENGINE = _get_engine()
_SessionLocal = sessionmaker(bind=_ENGINE, autoflush=False, autocommit=False, future=True) if _ENGINE else None


def get_engine():
    return _ENGINE


def init_db() -> None:
    if not _ENGINE:
        return
    Base.metadata.create_all(bind=_ENGINE)


def log_redaction(event: RedactionLogData) -> Optional[int]:
    if not _SessionLocal:
        return None
    with _SessionLocal() as session:
        entry = RedactionLog(
            user_id=event.user_id,
            username=event.username,
            filename=event.filename,
            content_type=event.content_type,
            size_bytes=event.size_bytes,
            total_pii=event.total_pii,
            pii_counts=event.pii_counts,
            created_at=datetime.now(timezone.utc),
        )
        session.add(entry)
        session.commit()
        session.refresh(entry)
        return entry.id


def fetch_logs(
    limit: int = 100,
    offset: int = 0,
    filename: str | None = None,
    pii_type: str | None = None,
    date_from: datetime | None = None,
    date_to: datetime | None = None,
    sort_by: str | None = None,
    sort_dir: str | None = None,
    user_id: int | None = None,
):
    if not _SessionLocal:
        return [], 0
    with _SessionLocal() as session:
        query = session.query(RedactionLog)
        if user_id is not None:
            query = query.filter(RedactionLog.user_id == user_id)
        if filename:
            query = query.filter(RedactionLog.filename.like(f"%{filename}%"))
        if date_from:
            query = query.filter(RedactionLog.created_at >= date_from)
        if date_to:
            query = query.filter(RedactionLog.created_at <= date_to)

        sort_key = (sort_by or "created_at").lower()
        sort_dir = (sort_dir or "desc").lower()
        sort_col = {
            "created_at": RedactionLog.created_at,
            "size_bytes": RedactionLog.size_bytes,
            "total_pii": RedactionLog.total_pii,
            "filename": RedactionLog.filename,
        }.get(sort_key, RedactionLog.created_at)

        order = desc(sort_col) if sort_dir == "desc" else sort_col
        if pii_type:
            all_rows = query.order_by(order).all()
            filtered = [
                row for row in all_rows if (row.pii_counts or {}).get(pii_type, 0) > 0
            ]
            total = len(filtered)
            rows = filtered[offset : offset + limit]
        else:
            total = query.count()
            rows = (
                query.order_by(order)
                .offset(offset)
                .limit(limit)
                .all()
            )

        data = [
            {
                "id": row.id,
                "user_id": row.user_id,
                "username": row.username,
                "filename": row.filename,
                "content_type": row.content_type,
                "size_bytes": row.size_bytes,
                "total_pii": row.total_pii,
                "pii_counts": row.pii_counts,
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]
        return data, total


def fetch_log_by_id(log_id: int):
    if not _SessionLocal:
        return None
    with _SessionLocal() as session:
        row = session.query(RedactionLog).filter(RedactionLog.id == log_id).first()
        if not row:
            return None
        return {
            "id": row.id,
            "user_id": row.user_id,
            "username": row.username,
            "filename": row.filename,
            "content_type": row.content_type,
            "size_bytes": row.size_bytes,
            "total_pii": row.total_pii,
            "pii_counts": row.pii_counts,
            "created_at": row.created_at.isoformat(),
        }


def create_user(username: str, password: str, email: Optional[str] = None) -> Optional[dict]:
    if not _SessionLocal:
        return None
    if not username or not password:
        raise ValueError("Username and password are required")
    with _SessionLocal() as session:
        existing = session.query(User).filter(User.username == username).first()
        if existing:
            raise ValueError("User already exists")
        if email:
            existing_email = session.query(User).filter(User.email == email).first()
            if existing_email:
                raise ValueError("Email already exists")
        pwd_hash = bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        user = User(
            username=username,
            email=email,
            password_hash=pwd_hash,
            api_token=None,
            token_expires_at=None,
            created_at=datetime.now(timezone.utc),
        )
        session.add(user)
        session.commit()
        session.refresh(user)
        return {"id": user.id, "username": user.username}


def login_user(username: str, password: str) -> Optional[dict]:
    if not _SessionLocal:
        return None
    with _SessionLocal() as session:
        user = session.query(User).filter(User.username == username).first()
        if not user:
            return None
        if not bcrypt.checkpw(password.encode("utf-8"), user.password_hash.encode("utf-8")):
            return None
        token = uuid.uuid4().hex
        ttl = max(1, CONFIG.user_token_ttl_minutes)
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=ttl)
        user.api_token = token
        user.token_expires_at = expires_at
        session.commit()
        session.refresh(user)
        return {
            "id": user.id,
            "username": user.username,
            "token": token,
            "expires_at": user.token_expires_at.isoformat(),
        }


def get_user_by_token(token: str) -> Optional[dict]:
    if not _SessionLocal or not token:
        return None
    with _SessionLocal() as session:
        user = session.query(User).filter(User.api_token == token).first()
        if not user:
            return None
        if user.token_expires_at and datetime.now(timezone.utc) >= user.token_expires_at:
            user.api_token = None
            user.token_expires_at = None
            session.commit()
            return None
        return {"id": user.id, "username": user.username}


def logout_user(token: str) -> bool:
    if not _SessionLocal or not token:
        return False
    with _SessionLocal() as session:
        user = session.query(User).filter(User.api_token == token).first()
        if not user:
            return False
        user.api_token = None
        user.token_expires_at = None
        session.commit()
        return True


def change_password(token: str, old_password: str, new_password: str) -> bool:
    if not _SessionLocal or not token:
        return False
    with _SessionLocal() as session:
        user = session.query(User).filter(User.api_token == token).first()
        if not user:
            return False
        if not bcrypt.checkpw(old_password.encode("utf-8"), user.password_hash.encode("utf-8")):
            return False
        pwd_hash = bcrypt.hashpw(new_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        user.password_hash = pwd_hash
        user.api_token = None
        user.token_expires_at = None
        session.commit()
        return True


def reset_password_admin(username: str, new_password: str) -> bool:
    if not _SessionLocal or not username:
        return False
    with _SessionLocal() as session:
        user = session.query(User).filter(User.username == username).first()
        if not user:
            return False
        pwd_hash = bcrypt.hashpw(new_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        user.password_hash = pwd_hash
        user.api_token = None
        user.token_expires_at = None
        session.commit()
        return True


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def create_password_reset_token(email: str) -> Optional[str]:
    if not _SessionLocal or not email:
        return None
    with _SessionLocal() as session:
        user = session.query(User).filter(User.email == email).first()
        if not user:
            return None
        raw_token = secrets.token_urlsafe(32)
        token_hash = _hash_token(raw_token)
        ttl = max(5, CONFIG.reset_token_ttl_minutes)
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=ttl)
        entry = PasswordResetToken(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=expires_at,
            used_at=None,
            created_at=datetime.now(timezone.utc),
        )
        session.add(entry)
        session.commit()
        return raw_token


def reset_password_with_token(raw_token: str, new_password: str) -> bool:
    if not _SessionLocal or not raw_token:
        return False
    token_hash = _hash_token(raw_token)
    with _SessionLocal() as session:
        entry = (
            session.query(PasswordResetToken)
            .filter(PasswordResetToken.token_hash == token_hash)
            .first()
        )
        if not entry or entry.used_at is not None:
            return False
        if entry.expires_at and datetime.now(timezone.utc) >= entry.expires_at:
            return False
        user = session.query(User).filter(User.id == entry.user_id).first()
        if not user:
            return False
        pwd_hash = bcrypt.hashpw(new_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
        user.password_hash = pwd_hash
        user.api_token = None
        user.token_expires_at = None
        entry.used_at = datetime.now(timezone.utc)
        session.commit()
        return True
