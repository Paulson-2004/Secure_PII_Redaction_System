from sqlalchemy import inspect, text

from db import get_engine, init_db


def _ensure_column(engine, table: str, column: str, ddl: str) -> None:
    inspector = inspect(engine)
    if table not in inspector.get_table_names():
        return
    cols = {col["name"] for col in inspector.get_columns(table)}
    if column in cols:
        return
    with engine.begin() as conn:
        conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {ddl}"))


def main() -> None:
    init_db()
    engine = get_engine()
    if not engine:
        print("Database not configured; skipping migration.")
        return

    _ensure_column(engine, "redaction_logs", "user_id", "user_id INT NULL")
    _ensure_column(engine, "redaction_logs", "username", "username VARCHAR(150) NULL")
    _ensure_column(engine, "users", "api_token", "api_token VARCHAR(64) NULL")
    _ensure_column(engine, "users", "token_expires_at", "token_expires_at DATETIME NULL")
    _ensure_column(engine, "users", "email", "email VARCHAR(255) NULL")
    print("Database migration complete.")


if __name__ == "__main__":
    main()
