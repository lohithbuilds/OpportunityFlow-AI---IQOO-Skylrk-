"""
Summary generation service.
Creates 30-second, 2-minute, and detailed summaries from extracted opportunity data.
"""

from __future__ import annotations
import logging
import json

from google.genai import types

from ..core.deps import get_gemini_client, is_api_key_valid
from ..core.config import get_settings
from ..models.opportunity import OpportunityData
from ..models.chat import RoadmapResponse, RoadmapTask

logger = logging.getLogger(__name__)


SUMMARY_PROMPTS = {
    "short": """Create a concise 30-second summary (2-3 sentences) of this opportunity.
Focus on: what it is, who it's for, and the key deadline.
Opportunity: {data}""",

    "medium": """Create a 2-minute summary (1-2 short paragraphs) of this opportunity.
Cover: what it is, who can participate, key dates, requirements, and benefits.
Opportunity: {data}""",

    "detailed": """Create a detailed breakdown of this opportunity.
Use clear sections with bullet points:
- Overview
- Eligibility & Requirements
- Timeline & Deadlines
- Benefits & Prizes
- How to Participate
- Skills to Prepare
Opportunity: {data}""",
}

ROADMAP_PROMPT = """Create a {duration}-day preparation roadmap for this opportunity.

Opportunity: {event_name}
Type: {opportunity_type}
Requirements: {requirements}
Skills Needed: {skills_needed}
User's Current Skills: {user_skills}

Create a structured day-by-day plan. For each day, provide tasks in these categories:
- research: Understanding the opportunity and domain
- skill_building: Learning required skills
- practice: Hands-on practice and mock exercises
- logistics: Registration, team formation, documentation
- networking: Connecting with past participants, mentors

Return a JSON array of tasks:
[{{"day": 1, "title": "Task title", "description": "What to do", "category": "research", "estimated_hours": 2}}]
"""


async def generate_summary(
    opportunity: OpportunityData,
    level: str = "short",
) -> dict:
    """Generate a summary at the requested detail level."""
    client = get_gemini_client()
    settings = get_settings()

    if not is_api_key_valid():
        ext = opportunity.extraction
        if level == "short":
            summary_text = f"This is a {ext.opportunity_type or 'opportunity'} event named '{ext.event_name}' organized by '{ext.organizer}'. Registration is open until {ext.registration_deadline or 'the specified deadline'} with registration fees details: {ext.fees or 'Free'}."
        elif level == "medium":
            summary_text = f"The '{ext.event_name}' is a premium student opportunity hosted by '{ext.organizer}'. It aims to bring together students who meet the eligibility criteria: '{ext.eligibility}'. Key dates include a registration deadline of {ext.registration_deadline or 'TBD'} and events starting on {ext.event_start_date or 'TBD'}. Participants stand to benefit from awards such as: {', '.join(ext.benefits) if ext.benefits else 'recognition and certificate'}."
        else:
            summary_text = (
                f"### Overview\n"
                f"'{ext.event_name}' is organized by '{ext.organizer}' as a {ext.opportunity_type or 'innovation challenge'}.\n\n"
                f"### Eligibility & Requirements\n"
                f"- Criteria: {ext.eligibility}\n"
                f"- Key Requirements: {', '.join(ext.requirements) if ext.requirements else 'Standard submission'}\n\n"
                f"### Timeline & Deadlines\n"
                f"- Registration Deadline: {ext.registration_deadline or 'TBD'}\n"
                f"- Submission Deadline: {ext.submission_deadline or 'TBD'}\n"
                f"- Event Dates: {ext.event_start_date or 'TBD'} to {ext.event_end_date or 'TBD'}\n\n"
                f"### Benefits & Prizes\n"
                + "\n".join([f"- {b}" for b in ext.benefits]) if ext.benefits else "- Certificate of Participation"
                + f"\n\n"
                f"### How to Participate\n"
                f"Submit your work and register online via links: {', '.join(ext.important_links) if ext.important_links else 'available on the official site'}.\n\n"
                f"### Skills to Prepare\n"
                f"Focus on: {', '.join(ext.skills_needed) if ext.skills_needed else 'Flutter, Python, UI/UX and teamwork'}."
            )

        return {
            "level": level,
            "summary": summary_text,
            "key_highlights": _extract_highlights(opportunity),
        }

    prompt_template = SUMMARY_PROMPTS.get(level, SUMMARY_PROMPTS["short"])
    data_json = opportunity.extraction.model_dump_json(indent=2)
    prompt = prompt_template.format(data=data_json)

    try:
        response = client.models.generate_content(
            model=settings.gemini_model,
            contents=[prompt],
            config=types.GenerateContentConfig(
                temperature=0.3,
                max_output_tokens=1000 if level != "detailed" else 2000,
            ),
        )
        summary_text = response.text or "Summary generation failed."
        highlights = _extract_highlights(opportunity)
        return {
            "level": level,
            "summary": summary_text,
            "key_highlights": highlights,
        }
    except Exception as e:
        logger.warning(f"Summary generation failed with model {settings.gemini_model}: {e}. Retrying with gemini-2.5-flash...")
        try:
            response = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=[prompt],
                config=types.GenerateContentConfig(
                    temperature=0.3,
                    max_output_tokens=1000 if level != "detailed" else 2000,
                ),
            )
            summary_text = response.text or "Summary generation failed."
            highlights = _extract_highlights(opportunity)
            return {
                "level": level,
                "summary": summary_text,
                "key_highlights": highlights,
            }
        except Exception as e2:
            logger.error(f"Summary generation failed with gemini-2.5-flash: {e2}. Using mock fallback.")
            ext = opportunity.extraction
            if level == "short":
                summary_text = f"This is a {ext.opportunity_type or 'opportunity'} event named '{ext.event_name}' organized by '{ext.organizer}'. Registration is open until {ext.registration_deadline or 'the specified deadline'} with registration fees details: {ext.fees or 'Free'}."
            elif level == "medium":
                summary_text = f"The '{ext.event_name}' is a premium student opportunity hosted by '{ext.organizer}'. It aims to bring together students who meet the eligibility criteria: '{ext.eligibility}'. Key dates include a registration deadline of {ext.registration_deadline or 'TBD'} and events starting on {ext.event_start_date or 'TBD'}. Participants stand to benefit from awards such as: {', '.join(ext.benefits) if ext.benefits else 'recognition and certificate'}."
            else:
                summary_text = (
                    f"### Overview\n"
                    f"'{ext.event_name}' is organized by '{ext.organizer}' as a {ext.opportunity_type or 'innovation challenge'}.\n\n"
                    f"### Eligibility & Requirements\n"
                    f"- Criteria: {ext.eligibility}\n"
                    f"- Key Requirements: {', '.join(ext.requirements) if ext.requirements else 'Standard submission'}\n\n"
                    f"### Timeline & Deadlines\n"
                    f"- Registration Deadline: {ext.registration_deadline or 'TBD'}\n"
                    f"- Submission Deadline: {ext.submission_deadline or 'TBD'}\n"
                    f"- Event Dates: {ext.event_start_date or 'TBD'} to {ext.event_end_date or 'TBD'}\n\n"
                    f"### Benefits & Prizes\n"
                    + "\n".join([f"- {b}" for b in ext.benefits]) if ext.benefits else "- Certificate of Participation"
                    + f"\n\n"
                    f"### How to Participate\n"
                    f"Submit your work and register online via links: {', '.join(ext.important_links) if ext.important_links else 'available on the official site'}.\n\n"
                    f"### Skills to Prepare\n"
                    f"Focus on: {', '.join(ext.skills_needed) if ext.skills_needed else 'Flutter, Python, UI/UX and teamwork'}."
                )
            return {
                "level": level,
                "summary": summary_text,
                "key_highlights": _extract_highlights(opportunity),
            }


async def generate_roadmap(
    opportunity: OpportunityData,
    duration_days: int = 7,
    user_skills: list[str] | None = None,
) -> RoadmapResponse:
    """Generate a preparation roadmap for the opportunity."""
    client = get_gemini_client()
    settings = get_settings()
    ext = opportunity.extraction

    def get_mock_roadmap():
        tasks = []
        skills_to_learn = ext.skills_needed if ext.skills_needed else ["Flutter", "FastAPI", "UI/UX"]
        for day in range(1, duration_days + 1):
            if day == 1:
                tasks.append(RoadmapTask(
                    day=day,
                    title=f"Research {ext.event_name}",
                    description=f"Read full guidelines for {ext.event_name} organized by {ext.organizer}. Understand judging criteria and constraints.",
                    category="research",
                    estimated_hours=2
                ))
                tasks.append(RoadmapTask(
                    day=day,
                    title="Form Team / Define Scope",
                    description="Decide if participating solo or finding teammates. Brainstorm initial ideas.",
                    category="logistics",
                    estimated_hours=2
                ))
            elif day == duration_days:
                tasks.append(RoadmapTask(
                    day=day,
                    title="Final Submission Polish",
                    description="Record a 2-minute demo video. Polish readme file and submit codebase.",
                    category="logistics",
                    estimated_hours=3
                ))
                tasks.append(RoadmapTask(
                    day=day,
                    title="Practice Pitch / Q&A",
                    description="Do a dry run of your project presentation. Prepare for potential judge questions.",
                    category="practice",
                    estimated_hours=2
                ))
            else:
                skill = skills_to_learn[(day - 2) % len(skills_to_learn)]
                tasks.append(RoadmapTask(
                    day=day,
                    title=f"Learn & Set Up: {skill}",
                    description=f"Study documentation and tutorials for {skill}. Build a small prototype or set up template.",
                    category="skill_building",
                    estimated_hours=3
                ))
                tasks.append(RoadmapTask(
                    day=day,
                    title=f"Implement Feature with {skill}",
                    description=f"Write core logic using {skill} for your project submission.",
                    category="practice",
                    estimated_hours=4
                ))
                if day % 2 == 0:
                    tasks.append(RoadmapTask(
                        day=day,
                        title="Reach out to Mentor/Peers",
                        description="Get feedback on your current prototype or ideas from online developer communities.",
                        category="networking",
                        estimated_hours=1
                    ))
        return RoadmapResponse(
            opportunity_name=ext.event_name,
            duration_days=duration_days,
            tasks=tasks,
            total_estimated_hours=sum(t.estimated_hours for t in tasks),
        )

    if not is_api_key_valid():
        logger.warning("GEMINI_API_KEY is not configured. Generating mock roadmap.")
        return get_mock_roadmap()

    prompt = ROADMAP_PROMPT.format(
        duration=duration_days,
        event_name=ext.event_name,
        opportunity_type=ext.opportunity_type,
        requirements=", ".join(ext.requirements) if ext.requirements else "Not specified",
        skills_needed=", ".join(ext.skills_needed) if ext.skills_needed else "General",
        user_skills=", ".join(user_skills) if user_skills else "Not specified",
    )

    model_to_try = settings.gemini_model
    try:
        response = client.models.generate_content(
            model=model_to_try,
            contents=[prompt],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=list[RoadmapTask],
                temperature=0.4,
                max_output_tokens=2000,
            ),
        )
        tasks = response.parsed or []
        return RoadmapResponse(
            opportunity_name=ext.event_name,
            duration_days=duration_days,
            tasks=tasks,
            total_estimated_hours=sum(t.estimated_hours for t in tasks),
        )
    except Exception as e:
        logger.warning(f"Roadmap generation failed with model {model_to_try}: {e}. Retrying with gemini-2.5-flash...")
        try:
            response = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=[prompt],
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=list[RoadmapTask],
                    temperature=0.4,
                    max_output_tokens=2000,
                ),
            )
            tasks = response.parsed or []
            return RoadmapResponse(
                opportunity_name=ext.event_name,
                duration_days=duration_days,
                tasks=tasks,
                total_estimated_hours=sum(t.estimated_hours for t in tasks),
            )
        except Exception as e2:
            logger.error(f"Roadmap generation failed with gemini-2.5-flash: {e2}. Falling back to mock roadmap.")
            return get_mock_roadmap()


def _extract_highlights(opportunity: OpportunityData) -> list[str]:
    """Extract key highlights from the opportunity data."""
    ext = opportunity.extraction
    highlights = []

    if ext.event_name:
        highlights.append(f"📌 {ext.event_name}")
    if ext.organizer:
        highlights.append(f"🏢 Organized by {ext.organizer}")
    if opportunity.deadline_info.registration_deadline:
        prefix = "🔴" if opportunity.deadline_info.is_urgent else "📅"
        highlights.append(f"{prefix} Deadline: {opportunity.deadline_info.registration_deadline}")
    if ext.fees:
        highlights.append(f"💰 Fee: {ext.fees}")
    if ext.location:
        highlights.append(f"📍 {ext.location}")
    if ext.benefits:
        highlights.append(f"🏆 {ext.benefits[0]}")

    return highlights[:6]
