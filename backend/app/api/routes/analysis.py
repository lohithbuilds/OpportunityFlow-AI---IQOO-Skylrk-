"""
Eligibility and Summary API routes.
"""

from __future__ import annotations
import logging

from fastapi import APIRouter, HTTPException, Query

from ...models.opportunity import EligibilityRequest, EligibilityResult
from ...models.chat import RoadmapRequest, RoadmapResponse
from ...services.eligibility_service import check_eligibility
from ...services.summary_service import generate_summary, generate_roadmap
from .upload import opportunities_store

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api", tags=["analysis"])


@router.post("/eligibility")
async def check_user_eligibility(request: EligibilityRequest):
    """
    Check if a student is eligible for an opportunity.
    Compares user profile against extracted eligibility criteria.
    """
    opportunity = opportunities_store.get(request.opportunity_id)
    if not opportunity:
        raise HTTPException(status_code=404, detail="Opportunity not found")

    result = await check_eligibility(
        opportunity=opportunity,
        age=request.age,
        grade=request.grade,
        college=request.college,
        skills=request.skills,
        interests=request.interests,
    )
    return result


@router.get("/opportunities/{opportunity_id}/summary")
async def get_summary(
    opportunity_id: str,
    level: str = Query(default="short", pattern="^(short|medium|detailed)$"),
):
    """
    Generate a summary at the requested detail level.
    - short: 30-second overview (2-3 sentences)
    - medium: 2-minute summary (1-2 paragraphs)
    - detailed: Full breakdown with sections
    """
    opportunity = opportunities_store.get(opportunity_id)
    if not opportunity:
        raise HTTPException(status_code=404, detail="Opportunity not found")

    result = await generate_summary(opportunity, level)
    return result


@router.post("/roadmap", response_model=RoadmapResponse)
async def create_roadmap(request: RoadmapRequest):
    """
    Generate a preparation roadmap (3, 7, or 14 days) for an opportunity.
    """
    opportunity = opportunities_store.get(request.opportunity_id)
    if not opportunity:
        raise HTTPException(status_code=404, detail="Opportunity not found")

    if request.duration_days not in (3, 7, 14):
        raise HTTPException(
            status_code=400,
            detail="Duration must be 3, 7, or 14 days",
        )

    result = await generate_roadmap(
        opportunity=opportunity,
        duration_days=request.duration_days,
        user_skills=request.user_skills,
    )
    return result


@router.get("/dashboard")
async def get_dashboard():
    """
    Get the opportunity dashboard grouped by tracking status.
    """
    from ...models.opportunity import DashboardItem, DashboardResponse

    items_by_status: dict[str, list] = {
        "upcoming": [],
        "deadline_soon": [],
        "applied": [],
        "completed": [],
    }

    for opp in opportunities_store.values():
        item = DashboardItem(
            id=opp.id,
            event_name=opp.extraction.event_name,
            organizer=opp.extraction.organizer,
            opportunity_type=opp.extraction.opportunity_type,
            tracking_status=opp.tracking_status,
            bookmarked=opp.bookmarked,
            deadline_info=opp.deadline_info,
            created_at=opp.created_at,
        )

        # Sort into buckets
        if opp.deadline_info.is_urgent:
            items_by_status["deadline_soon"].append(item)
        elif opp.tracking_status == "applied":
            items_by_status["applied"].append(item)
        elif opp.tracking_status == "completed":
            items_by_status["completed"].append(item)
        else:
            items_by_status["upcoming"].append(item)

    return DashboardResponse(
        upcoming=items_by_status["upcoming"],
        deadline_soon=items_by_status["deadline_soon"],
        applied=items_by_status["applied"],
        completed=items_by_status["completed"],
        total_count=len(opportunities_store),
    )
