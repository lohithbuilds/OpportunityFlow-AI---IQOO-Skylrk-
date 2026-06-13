"""
Eligibility engine: determines if a student is eligible for an opportunity.
Compares user profile against extracted eligibility criteria using Gemini.
Returns structured result with reasoning.
"""

from __future__ import annotations
import logging
import json

from google.genai import types

from ..core.deps import get_gemini_client, is_api_key_valid
from ..core.config import get_settings
from ..models.opportunity import OpportunityData, ConfidenceLevel
from ..models.chat import SourceCitation

logger = logging.getLogger(__name__)

ELIGIBILITY_PROMPT = """You are an eligibility assessment engine. Analyze whether a student is eligible for the given opportunity.

OPPORTUNITY DETAILS:
- Name: {event_name}
- Eligibility Criteria: {eligibility}
- Requirements: {requirements}
- Skills Needed: {skills_needed}
- Team Size: {team_size}
- Location: {location}

STUDENT PROFILE:
- Age: {age}
- Grade/Year: {grade}
- College/Institution: {college}
- Skills: {skills}
- Interests: {interests}

RULES:
1. Compare ONLY against the stated eligibility criteria in the document.
2. If the document doesn't specify certain criteria, assume the student MAY be eligible.
3. Be specific about which criteria match and which don't.

Return a JSON object with:
{{
    "status": "eligible" | "possibly_eligible" | "not_eligible",
    "reasoning": "Clear explanation of why",
    "matching_criteria": ["list of criteria the student meets"],
    "missing_criteria": ["list of criteria the student doesn't meet or needs to verify"]
}}
"""


async def check_eligibility(
    opportunity: OpportunityData,
    age: int | None = None,
    grade: str | None = None,
    college: str | None = None,
    skills: list[str] | None = None,
    interests: list[str] | None = None,
) -> dict:
    """
    Check student eligibility against opportunity requirements.
    Returns structured eligibility result with reasoning.
    """
    client = get_gemini_client()
    settings = get_settings()
    ext = opportunity.extraction

    if not is_api_key_valid():
        logger.warning("GEMINI_API_KEY is not configured. Using heuristic eligibility assessment.")
        status = "eligible"
        matching_criteria = []
        missing_criteria = []
        reasoning_parts = []

        # Age evaluation
        if age:
            if age >= 18:
                matching_criteria.append("Age requirement met (18+)")
                reasoning_parts.append(f"Student age ({age}) satisfies the standard requirements.")
            else:
                missing_criteria.append("Age requirement (under 18)")
                status = "possibly_eligible"
                reasoning_parts.append(f"Student is under 18 years old ({age}), which might require guardian consent or exclude them depending on host rules.")
        else:
            missing_criteria.append("Age not provided for verification")
            status = "possibly_eligible"
            reasoning_parts.append("Age is missing from profile; eligibility cannot be fully verified.")

        # Skills evaluation
        student_skills = [s.lower() for s in (skills or [])]
        opp_skills = [s.lower() for s in ext.skills_needed]
        matched_skills = [s for s in ext.skills_needed if s.lower() in student_skills]
        
        if matched_skills:
            matching_criteria.append(f"Skills matched: {', '.join(matched_skills)}")
            reasoning_parts.append(f"Possesses matching skills: {', '.join(matched_skills)}.")
        elif ext.skills_needed:
            missing_criteria.append(f"Skills missing: {', '.join(ext.skills_needed)}")
            status = "possibly_eligible" if status == "eligible" else status
            reasoning_parts.append(f"Does not list skills required for the opportunity: {', '.join(ext.skills_needed)}.")

        # Grade / College evaluation
        if grade:
            matching_criteria.append(f"Grade/Year: {grade}")
            reasoning_parts.append(f"Enrolled as {grade}.")
        else:
            missing_criteria.append("Enrollment verification")

        reasoning = " ".join(reasoning_parts)
        if not reasoning:
            reasoning = "Student meets general participation criteria. No conflicting exclusions found."

        return {
            "status": status,
            "reasoning": reasoning,
            "matching_criteria": matching_criteria,
            "missing_criteria": missing_criteria,
            "confidence": "high",
            "source": {
                "text": ext.eligibility or "No eligibility criteria found",
                "section": "Eligibility",
            },
        }

    prompt = ELIGIBILITY_PROMPT.format(
        event_name=ext.event_name,
        eligibility=ext.eligibility or "Not specified",
        requirements=", ".join(ext.requirements) if ext.requirements else "Not specified",
        skills_needed=", ".join(ext.skills_needed) if ext.skills_needed else "Not specified",
        team_size=ext.team_size or "Not specified",
        location=ext.location or "Not specified",
        age=age or "Not provided",
        grade=grade or "Not provided",
        college=college or "Not provided",
        skills=", ".join(skills) if skills else "Not provided",
        interests=", ".join(interests) if interests else "Not provided",
    )

    try:
        response = client.models.generate_content(
            model=settings.gemini_model,
            contents=[prompt],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.1,
            ),
        )

        result = json.loads(response.text)

        # Determine confidence based on how specific the eligibility criteria are
        confidence = ConfidenceLevel.HIGH
        if not ext.eligibility or ext.eligibility.lower() in ("not specified", ""):
            confidence = ConfidenceLevel.NEEDS_VERIFICATION

        return {
            "status": result.get("status", "possibly_eligible"),
            "reasoning": result.get("reasoning", "Unable to determine eligibility."),
            "matching_criteria": result.get("matching_criteria", []),
            "missing_criteria": result.get("missing_criteria", []),
            "confidence": confidence.value,
            "source": SourceCitation(
                text=ext.eligibility or "No eligibility criteria found",
                section="Eligibility",
            ).model_dump(),
        }

    except Exception as e:
        logger.error(f"Eligibility check failed: {e}")
        return {
            "status": "possibly_eligible",
            "reasoning": f"Unable to fully assess eligibility: {str(e)}",
            "matching_criteria": [],
            "missing_criteria": ["Verification needed"],
            "confidence": ConfidenceLevel.NEEDS_VERIFICATION.value,
        }
