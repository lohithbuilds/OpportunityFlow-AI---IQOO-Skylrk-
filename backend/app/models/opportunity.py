"""
Pydantic models for opportunity data extraction and API responses.
These schemas enforce structured output from Gemini and validate API contracts.
"""

from __future__ import annotations
from pydantic import BaseModel, Field
from typing import Optional
from enum import Enum
from datetime import datetime


# ── Confidence Levels ──────────────────────────────────────────

class ConfidenceLevel(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    NEEDS_VERIFICATION = "needs_verification"


# ── Extracted Opportunity Data ─────────────────────────────────

class ExtractedField(BaseModel):
    """A field extracted from a document with its confidence score."""
    value: str = ""
    confidence: ConfidenceLevel = ConfidenceLevel.NEEDS_VERIFICATION
    source_page: Optional[int] = None
    source_section: Optional[str] = None


class DeadlineInfo(BaseModel):
    """Structured deadline information."""
    registration_deadline: Optional[str] = None
    submission_deadline: Optional[str] = None
    event_start_date: Optional[str] = None
    event_end_date: Optional[str] = None
    is_urgent: bool = False
    days_remaining: Optional[int] = None


class OpportunityExtraction(BaseModel):
    """
    Structured extraction from Gemini — this is the schema used as
    response_schema for guaranteed JSON output from the LLM.
    """
    event_name: str = Field(default="", description="Name of the event or opportunity")
    organizer: str = Field(default="", description="Organization hosting the event")
    opportunity_type: str = Field(default="", description="Type: hackathon, scholarship, internship, olympiad, fellowship, competition, cultural event, sports, other")
    eligibility: str = Field(default="", description="Who can participate — age, grade, college requirements")
    registration_deadline: str = Field(default="", description="Last date to register, in ISO format if possible")
    submission_deadline: str = Field(default="", description="Last date to submit work")
    event_start_date: str = Field(default="", description="When the event starts")
    event_end_date: str = Field(default="", description="When the event ends")
    location: str = Field(default="", description="Venue or 'Online'")
    requirements: list[str] = Field(default_factory=list, description="What participants need")
    fees: str = Field(default="", description="Registration or participation fees")
    benefits: list[str] = Field(default_factory=list, description="Prizes, certificates, rewards")
    skills_needed: list[str] = Field(default_factory=list, description="Technical or soft skills required")
    important_links: list[str] = Field(default_factory=list, description="Registration URLs, resources")
    judging_criteria: list[str] = Field(default_factory=list, description="How submissions are evaluated")
    team_size: str = Field(default="", description="Individual or team, min/max members")
    contact_info: str = Field(default="", description="Email, phone, social media for queries")
    description: str = Field(default="", description="Brief description of the opportunity")


class OpportunityData(BaseModel):
    """Full opportunity model with confidence scores and metadata."""
    id: str = ""
    extraction: OpportunityExtraction = Field(default_factory=OpportunityExtraction)
    confidence_scores: dict[str, str] = Field(default_factory=dict)
    deadline_info: DeadlineInfo = Field(default_factory=DeadlineInfo)
    raw_text: str = ""
    source_file_name: str = ""
    source_file_url: str = ""
    status: str = "analyzing"  # analyzing | ready | error
    tracking_status: str = "discovered"  # discovered | applied | upcoming | completed
    bookmarked: bool = False
    created_at: str = Field(default_factory=lambda: datetime.now().isoformat())
    updated_at: str = Field(default_factory=lambda: datetime.now().isoformat())


# ── API Request/Response Models ────────────────────────────────

class UploadResponse(BaseModel):
    """Response after uploading and processing a document."""
    opportunity_id: str
    status: str
    message: str
    data: Optional[OpportunityData] = None


class EligibilityRequest(BaseModel):
    """User profile for eligibility checking."""
    opportunity_id: str
    age: Optional[int] = None
    grade: Optional[str] = None
    college: Optional[str] = None
    skills: list[str] = Field(default_factory=list)
    interests: list[str] = Field(default_factory=list)


class EligibilityResult(BaseModel):
    """Eligibility determination result."""
    status: str  # eligible | possibly_eligible | not_eligible
    reasoning: str
    matching_criteria: list[str] = Field(default_factory=list)
    missing_criteria: list[str] = Field(default_factory=list)
    confidence: ConfidenceLevel = ConfidenceLevel.MEDIUM


class SummaryResponse(BaseModel):
    """Summary at different detail levels."""
    level: str  # short | medium | detailed
    summary: str
    key_highlights: list[str] = Field(default_factory=list)


class DashboardItem(BaseModel):
    """Condensed opportunity for dashboard display."""
    id: str
    event_name: str
    organizer: str
    opportunity_type: str
    tracking_status: str
    bookmarked: bool
    deadline_info: DeadlineInfo
    created_at: str


class DashboardResponse(BaseModel):
    """Dashboard with opportunities grouped by status."""
    upcoming: list[DashboardItem] = Field(default_factory=list)
    deadline_soon: list[DashboardItem] = Field(default_factory=list)
    applied: list[DashboardItem] = Field(default_factory=list)
    completed: list[DashboardItem] = Field(default_factory=list)
    total_count: int = 0
