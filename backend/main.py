"""
OpportunityFlow AI — FastAPI Backend Entry Point

A production-grade API that transforms opportunity documents into
intelligent AI mentors using Gemini 2.5 Pro + RAG.

Run: uvicorn main:app --reload --port 8000
"""

from __future__ import annotations
import os
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

# Load .env before anything else
load_dotenv()

from app.core.config import get_settings
from app.api.routes import upload, chat, analysis

# ── Logging ────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(name)s | %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("opportunityflow")


# ── Lifespan ───────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Startup and shutdown events."""
    settings = get_settings()
    logger.info("=" * 60)
    logger.info("  OpportunityFlow AI — Starting Up")
    logger.info(f"  Model: {settings.gemini_model}")
    logger.info(f"  Debug: {settings.debug}")
    logger.info("=" * 60)

    # Create upload directory
    os.makedirs(settings.upload_dir, exist_ok=True)
    os.makedirs(settings.chroma_persist_dir, exist_ok=True)

    yield

    logger.info("OpportunityFlow AI — Shutting Down")


# ── App ────────────────────────────────────────────────────────

app = FastAPI(
    title="OpportunityFlow AI",
    description="Transform opportunity documents into intelligent AI mentors",
    version="1.0.0",
    lifespan=lifespan,
)

# ── CORS ───────────────────────────────────────────────────────

settings = get_settings()
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routes ─────────────────────────────────────────────────────

app.include_router(upload.router)
app.include_router(chat.router)
app.include_router(analysis.router)


@app.get("/")
async def root():
    """Health check endpoint."""
    return {
        "app": "OpportunityFlow AI",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs",
    }


@app.get("/health")
async def health():
    """Detailed health check."""
    return {
        "status": "healthy",
        "model": settings.gemini_model,
        "has_api_key": bool(settings.gemini_api_key),
    }
