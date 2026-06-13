"""
Application configuration via environment variables.
Uses Pydantic BaseSettings for validation and .env file loading.
"""

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # ── Gemini AI ──────────────────────────────────────────────
    gemini_api_key: str = ""
    gemini_model: str = "gemini-2.5-flash"
    gemini_embedding_model: str = "gemini-embedding-001"

    # ── Firebase ───────────────────────────────────────────────
    firebase_project_id: str = ""
    firebase_storage_bucket: str = ""
    firebase_credentials_path: str = ""

    # ── Server ─────────────────────────────────────────────────
    host: str = "0.0.0.0"
    port: int = 8080
    debug: bool = True
    cors_origins: list[str] = ["*"]

    # ── ChromaDB ───────────────────────────────────────────────
    chroma_persist_dir: str = "./data/chromadb"

    # ── Upload ─────────────────────────────────────────────────
    upload_dir: str = "./data/uploads"
    max_file_size_mb: int = 20

    model_config = {
        "env_file": ".env",
        "env_file_encoding": "utf-8",
        "case_sensitive": False,
    }


@lru_cache()
def get_settings() -> Settings:
    """Cached settings singleton."""
    return Settings()
