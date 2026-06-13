"""
Upload API route — handles document upload, parsing, extraction, and indexing.
Accepts PDF, images, and returns structured opportunity data.
"""

from __future__ import annotations
import os
import uuid
import logging
from pathlib import Path

from fastapi import APIRouter, UploadFile, File, HTTPException

from ...core.config import get_settings
from ...models.opportunity import OpportunityData, UploadResponse
from ...ingestion.parser import parse_document
from ...ingestion.extractor import extract_from_document
from ...services.rag_service import index_opportunity

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["upload"])

# In-memory store for hackathon MVP (replace with Firestore in production)
opportunities_store: dict[str, OpportunityData] = {}


@router.post("/upload", response_model=UploadResponse)
async def upload_document(file: UploadFile = File(...)):
    """
    Upload a document (PDF, image) and extract opportunity information.

    Flow:
    1. Save uploaded file
    2. Parse document (PyMuPDF for PDF, Gemini Vision for images)
    3. Extract structured data via Gemini
    4. Index content in ChromaDB for RAG chat
    5. Return structured opportunity data
    """
    settings = get_settings()

    # Validate file type
    allowed_types = {".pdf", ".png", ".jpg", ".jpeg", ".webp", ".bmp"}
    file_ext = Path(file.filename or "unknown").suffix.lower()
    if file_ext not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type: {file_ext}. Allowed: {', '.join(allowed_types)}",
        )

    # Validate file size
    content = await file.read()
    size_mb = len(content) / (1024 * 1024)
    if size_mb > settings.max_file_size_mb:
        raise HTTPException(
            status_code=400,
            detail=f"File too large: {size_mb:.1f}MB. Maximum: {settings.max_file_size_mb}MB",
        )

    # Save file
    opportunity_id = str(uuid.uuid4())[:12]
    upload_dir = Path(settings.upload_dir)
    upload_dir.mkdir(parents=True, exist_ok=True)

    file_path = upload_dir / f"{opportunity_id}{file_ext}"
    with open(file_path, "wb") as f:
        f.write(content)

    logger.info(f"Saved upload: {file_path} ({size_mb:.1f}MB)")

    try:
        # Step 1: Parse document
        parsed_doc = parse_document(str(file_path))

        # Step 2: Extract structured data
        opportunity = await extract_from_document(parsed_doc, str(file_path))
        opportunity.id = opportunity_id
        opportunity.source_file_name = file.filename or "unknown"

        # Step 3: Index for RAG chat
        await index_opportunity(opportunity_id, opportunity)

        # Step 4: Store in memory (MVP) — production would use Firestore
        opportunities_store[opportunity_id] = opportunity

        return UploadResponse(
            opportunity_id=opportunity_id,
            status="ready",
            message=f"Successfully extracted opportunity: {opportunity.extraction.event_name}",
            data=opportunity,
        )

    except Exception as e:
        logger.error(f"Processing failed: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Document processing failed: {str(e)}",
        )


@router.get("/opportunities/{opportunity_id}")
async def get_opportunity(opportunity_id: str):
    """Get extracted opportunity data by ID."""
    opportunity = opportunities_store.get(opportunity_id)
    if not opportunity:
        raise HTTPException(status_code=404, detail="Opportunity not found")
    return opportunity


@router.get("/opportunities")
async def list_opportunities():
    """List all processed opportunities."""
    return {
        "opportunities": [
            {
                "id": opp.id,
                "event_name": opp.extraction.event_name,
                "organizer": opp.extraction.organizer,
                "opportunity_type": opp.extraction.opportunity_type,
                "tracking_status": opp.tracking_status,
                "bookmarked": opp.bookmarked,
                "deadline_info": opp.deadline_info.model_dump(),
                "created_at": opp.created_at,
            }
            for opp in opportunities_store.values()
        ],
        "total_count": len(opportunities_store),
    }


@router.post("/opportunities/{opportunity_id}/bookmark")
async def toggle_bookmark(opportunity_id: str):
    """Toggle bookmark status for an opportunity."""
    opportunity = opportunities_store.get(opportunity_id)
    if not opportunity:
        raise HTTPException(status_code=404, detail="Opportunity not found")
    opportunity.bookmarked = not opportunity.bookmarked
    return {"bookmarked": opportunity.bookmarked}


@router.patch("/opportunities/{opportunity_id}/status")
async def update_tracking_status(opportunity_id: str, status: str):
    """Update tracking status: discovered | applied | upcoming | completed."""
    valid_statuses = {"discovered", "applied", "upcoming", "completed"}
    if status not in valid_statuses:
        raise HTTPException(status_code=400, detail=f"Invalid status. Must be one of: {valid_statuses}")
    opportunity = opportunities_store.get(opportunity_id)
    if not opportunity:
        raise HTTPException(status_code=404, detail="Opportunity not found")
    opportunity.tracking_status = status
    return {"tracking_status": status}
