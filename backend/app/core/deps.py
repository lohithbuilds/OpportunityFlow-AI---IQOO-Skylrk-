"""
Dependency injection for FastAPI endpoints.
Provides shared resources like Gemini client, ChromaDB, etc.
"""

import os
from functools import lru_cache
from google import genai
import chromadb
from .config import get_settings


def is_api_key_valid() -> bool:
    """Check if the configured Gemini API key is valid (not empty and not a placeholder)."""
    settings = get_settings()
    key = settings.gemini_api_key
    return bool(key and not key.startswith("your_") and len(key) > 15)


@lru_cache()
def get_gemini_client() -> genai.Client:
    """Initialize and cache the Gemini AI client."""
    settings = get_settings()
    # Use dummy key if not configured to prevent client instantiation error
    api_key = settings.gemini_api_key if is_api_key_valid() else "dummy_api_key_for_testing"
    return genai.Client(api_key=api_key)


@lru_cache()
def get_chroma_client() -> chromadb.ClientAPI:
    """Initialize and cache the ChromaDB persistent client."""
    settings = get_settings()
    os.makedirs(settings.chroma_persist_dir, exist_ok=True)
    return chromadb.PersistentClient(path=settings.chroma_persist_dir)


def get_chroma_collection(opportunity_id: str) -> chromadb.Collection:
    """Get or create a ChromaDB collection for a specific opportunity."""
    client = get_chroma_client()
    return client.get_or_create_collection(
        name=f"opp_{opportunity_id}",
        metadata={"hnsw:space": "cosine"},
    )
