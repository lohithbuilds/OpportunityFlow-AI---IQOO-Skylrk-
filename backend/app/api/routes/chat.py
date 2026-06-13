"""
Chat API route — RAG-powered AI mentor conversations.
"""

from __future__ import annotations
import logging

from fastapi import APIRouter, HTTPException

from ...models.chat import ChatRequest, ChatResponse
from ...services.rag_service import chat_with_mentor
from .upload import opportunities_store

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["chat"])


@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """
    Send a message to the AI Mentor for a specific opportunity.
    Returns a source-grounded response with citations.
    """
    opportunity = opportunities_store.get(request.opportunity_id)
    if not opportunity:
        raise HTTPException(
            status_code=404,
            detail="Opportunity not found. Please upload a document first.",
        )

    if opportunity.status != "ready":
        raise HTTPException(
            status_code=400,
            detail="Opportunity is still being processed.",
        )

    try:
        response = await chat_with_mentor(request, opportunity)
        return response

    except Exception as e:
        logger.error(f"Chat failed: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Chat error: {str(e)}",
        )
