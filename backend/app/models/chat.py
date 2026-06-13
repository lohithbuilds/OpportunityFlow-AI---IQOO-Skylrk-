"""
Pydantic models for the AI chat system with source citations.
"""

from __future__ import annotations
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class SourceCitation(BaseModel):
    """A citation pointing back to the source document."""
    text: str = Field(description="The relevant text from the source")
    page: Optional[int] = Field(default=None, description="Page number in the document")
    section: Optional[str] = Field(default=None, description="Section heading or label")

    def __str__(self) -> str:
        if self.page:
            return f"Source: Page {self.page}"
        if self.section:
            return f"Source: {self.section}"
        return "Source: Extracted Document"


class ChatMessage(BaseModel):
    """A single message in the chat conversation."""
    role: str  # user | assistant
    content: str
    sources: list[SourceCitation] = Field(default_factory=list)
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())


class ChatRequest(BaseModel):
    """Request to the AI chat endpoint."""
    opportunity_id: str
    message: str
    conversation_history: list[ChatMessage] = Field(default_factory=list)


class ChatResponse(BaseModel):
    """Response from the AI chat with grounded citations."""
    answer: str
    sources: list[SourceCitation] = Field(default_factory=list)
    suggested_questions: list[str] = Field(default_factory=list)
    confidence: str = "high"  # high | medium | low


class RoadmapTask(BaseModel):
    """A single task in a preparation roadmap."""
    day: int
    title: str
    description: str
    category: str  # research | skill_building | practice | logistics | networking
    estimated_hours: float = 1.0
    completed: bool = False


class RoadmapRequest(BaseModel):
    """Request to generate a preparation roadmap."""
    opportunity_id: str
    duration_days: int = 7  # 3, 7, or 14
    user_skills: list[str] = Field(default_factory=list)


class RoadmapResponse(BaseModel):
    """Generated preparation roadmap."""
    opportunity_name: str
    duration_days: int
    tasks: list[RoadmapTask] = Field(default_factory=list)
    total_estimated_hours: float = 0.0
