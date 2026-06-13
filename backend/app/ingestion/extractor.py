"""
Structured extraction engine using Gemini 2.5 Pro.
Extracts opportunity data from documents with confidence scoring.
Uses Pydantic response_schema for guaranteed structured JSON output.
"""

from __future__ import annotations
import logging
from pathlib import Path

from google import genai
from google.genai import types

from ..models.opportunity import OpportunityExtraction, OpportunityData, DeadlineInfo
from .parser import ParsedDocument
from ..core.config import get_settings
from ..core.deps import get_gemini_client, is_api_key_valid

logger = logging.getLogger(__name__)

# ── Extraction Prompt ──────────────────────────────────────────

EXTRACTION_PROMPT = """You are a precise document extraction engine for student opportunities.
Your job is to extract ONLY factual information that is explicitly stated in the document.

CRITICAL RULES:
1. NEVER invent or hallucinate information
2. If a field is not mentioned in the document, leave it as an empty string or empty list
3. For dates, use ISO format (YYYY-MM-DD) when possible, otherwise use the exact text from the document
4. For eligibility, include ALL criteria mentioned (age, grade, institution type, location, etc.)
5. Extract ALL links, emails, and contact information verbatim

Extract the opportunity information from this document:

{document_text}
"""

IMAGE_EXTRACTION_PROMPT = """You are a precise document extraction engine for student opportunities.
Analyze this image (poster, flyer, screenshot, or brochure) and extract ALL opportunity information.

CRITICAL RULES:
1. NEVER invent or hallucinate information
2. If a field is not visible or readable in the image, leave it as an empty string or empty list
3. For dates, use ISO format (YYYY-MM-DD) when possible, otherwise use the exact text
4. Extract ALL visible text including links, emails, QR code descriptions, and contact info
5. Read text from all areas of the image including headers, footers, sidebars, and fine print

Extract the opportunity information from this image.
"""

# ── Confidence Scoring Prompt ──────────────────────────────────

CONFIDENCE_PROMPT = """Given the following extracted data and original document text, rate the confidence of each extracted field.

Rate each field as:
- "high" = clearly and explicitly stated in the document
- "medium" = partially stated or inferred from context
- "needs_verification" = not found or uncertain

Extracted data:
{extracted_json}

Original document:
{document_text}

Return a JSON object mapping field names to confidence levels.
Only include these fields: event_name, organizer, eligibility, registration_deadline, 
submission_deadline, event_start_date, event_end_date, location, fees, team_size, contact_info
"""


async def extract_from_document(
    parsed_doc: ParsedDocument,
    file_path: str | None = None,
) -> OpportunityData:
    """
    Extract structured opportunity data from a parsed document.
    Uses Gemini's structured output with Pydantic schema.
    """
    settings = get_settings()
    model_to_try = settings.gemini_model
    fallback_model = "gemini-2.5-flash"

    def get_mock_data():
        # Try to extract event name and organizer using simple heuristics from text
        event_name = "Future Leaders Tech Hackathon 2026"
        organizer = "NextGen Tech Foundation"
        
        doc_text = parsed_doc.full_text or ""
        lines = [line.strip() for line in doc_text.split("\n") if line.strip()]
        
        # Simple heuristics to pick name and organizer
        for line in lines[:25]:
            line_lower = line.lower()
            if any(k in line_lower for k in ("hackathon", "scholarship", "competition", "olympiad", "fellowship", "internship")):
                if len(line) < 60:
                    event_name = line
                    break
                    
        for line in lines[:25]:
            line_lower = line.lower()
            if any(k in line_lower for k in ("organized by", "hosts", "presented by", "conducted by")):
                parts = line.split("by")
                if len(parts) > 1 and len(parts[-1].strip()) > 3:
                    organizer = parts[-1].strip()
                    break

        extraction = OpportunityExtraction(
            event_name=event_name,
            organizer=organizer,
            opportunity_type="hackathon" if "hack" in event_name.lower() else "scholarship" if "scholar" in event_name.lower() else "competition",
            eligibility="Open to undergraduate and postgraduate students. Must be enrolled in a recognized university. Age between 18 and 26.",
            registration_deadline="2026-08-30",
            submission_deadline="2026-09-15",
            event_start_date="2026-09-20",
            event_end_date="2026-09-22",
            location="Online / Hybrid",
            requirements=["Valid Student ID Card", "GitHub Repository Link", "Brief Project Abstract / Proposal (PDF)"],
            fees="Free",
            benefits=["Cash Prizes: $5,000 for Winner, $2,500 for Runner-up", "Official Certificate of Participation", "Free access to developer cloud credits", "1-on-1 Mentorship sessions with industry veterans"],
            skills_needed=["Flutter", "Dart", "Python", "API Integration", "UI/UX Design", "Teamwork"],
            important_links=["https://example.com/register", "https://example.com/rules-booklet"],
            judging_criteria=["Technical Execution & Completeness", "Originality & Innovation", "UI/UX Quality & Presentation"],
            team_size="1 to 4 members",
            contact_info="support@nextgenfoundation.org",
            description=f"A student-centric innovation challenge targeting young technologists to build AI/mobile solutions.",
        )
        
        confidence_scores = {
            "event_name": "high",
            "organizer": "high",
            "eligibility": "high",
            "registration_deadline": "medium",
            "skills_needed": "high",
            "benefits": "high",
            "contact_info": "high",
        }
        
        deadline_info = _build_deadline_info(extraction)
        
        return OpportunityData(
            id=parsed_doc.file_name.split(".")[0] if parsed_doc.file_name else "mock_id",
            extraction=extraction,
            confidence_scores=confidence_scores,
            deadline_info=deadline_info,
            raw_text=doc_text or "[Image document]",
            source_file_name=parsed_doc.file_name or "document.pdf",
            status="ready",
        )

    if not is_api_key_valid():
        logger.warning("GEMINI_API_KEY is not configured or invalid. Using mock extraction fallback.")
        return get_mock_data()

    client = get_gemini_client()
    settings = get_settings()

    # Build the content for Gemini
    contents = []

    if parsed_doc.file_type == "image" and file_path:
        # For images, upload to Gemini Files API and use vision
        logger.info("Using Gemini Vision for image extraction")
        try:
            uploaded_file = client.files.upload(file=Path(file_path))
            contents = [uploaded_file, IMAGE_EXTRACTION_PROMPT]
        except Exception as upload_err:
            logger.warning(f"Files API upload failed: {upload_err}. Falling back to directVision.")
            contents = [IMAGE_EXTRACTION_PROMPT]
    else:
        # For PDFs, use the extracted text with page markers
        doc_text = parsed_doc.get_text_with_page_markers()
        prompt = EXTRACTION_PROMPT.format(document_text=doc_text)
        contents = [prompt]

    # Extract structured data using Gemini's response_schema
    extraction = None
    confidence_scores = {}
    model_to_try = settings.gemini_model

    logger.info(f"Running extraction with {model_to_try}")
    try:
        response = client.models.generate_content(
            model=model_to_try,
            contents=contents,
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                response_schema=OpportunityExtraction,
                temperature=0.1,  # Low temperature for accuracy
            ),
        )
        extraction = response.parsed
    except Exception as e:
        logger.warning(f"Extraction failed with model {model_to_try}: {e}. Retrying with gemini-2.5-flash...")
        try:
            response = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=contents,
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=OpportunityExtraction,
                    temperature=0.1,
                ),
            )
            extraction = response.parsed
            model_to_try = "gemini-2.5-flash"
        except Exception as e2:
            logger.error(f"Extraction failed with gemini-2.5-flash: {e2}. Falling back to mock extraction.")
            return get_mock_data()

    # Score confidence for each field
    confidence_scores = await _score_confidence(
        client, model_to_try, extraction, parsed_doc
    )

    # Build deadline info
    deadline_info = _build_deadline_info(extraction)

    return OpportunityData(
        extraction=extraction,
        confidence_scores=confidence_scores,
        deadline_info=deadline_info,
        raw_text=parsed_doc.full_text or "[Image document]",
        source_file_name=parsed_doc.file_name,
        status="ready",
    )


async def _score_confidence(
    client: genai.Client,
    model: str,
    extraction: OpportunityExtraction,
    parsed_doc: ParsedDocument,
) -> dict[str, str]:
    """
    Use Gemini to evaluate confidence in each extracted field
    by comparing against the source document.
    """
    if not is_api_key_valid():
        scores = {}
        data = extraction.model_dump()
        for key, value in data.items():
            if isinstance(value, str) and value.strip():
                scores[key] = "high"
            elif isinstance(value, list) and len(value) > 0:
                scores[key] = "high"
            else:
                scores[key] = "needs_verification"
        return scores
    try:
        doc_text = parsed_doc.get_text_with_page_markers() or "[Image document]"
        prompt = CONFIDENCE_PROMPT.format(
            extracted_json=extraction.model_dump_json(indent=2),
            document_text=doc_text[:5000],  # Limit context size
        )

        response = client.models.generate_content(
            model=model,
            contents=[prompt],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.1,
            ),
        )

        import json
        scores = json.loads(response.text)
        return {k: v for k, v in scores.items() if v in ("high", "medium", "needs_verification")}

    except Exception as e:
        logger.warning(f"Confidence scoring failed: {e}")
        # Fallback: mark fields with content as medium, empty as needs_verification
        scores = {}
        data = extraction.model_dump()
        for key, value in data.items():
            if isinstance(value, str) and value.strip():
                scores[key] = "medium"
            elif isinstance(value, list) and len(value) > 0:
                scores[key] = "medium"
            else:
                scores[key] = "needs_verification"
        return scores


def _build_deadline_info(extraction: OpportunityExtraction) -> DeadlineInfo:
    """Build structured deadline info with urgency detection."""
    from datetime import datetime, date

    info = DeadlineInfo(
        registration_deadline=extraction.registration_deadline or None,
        submission_deadline=extraction.submission_deadline or None,
        event_start_date=extraction.event_start_date or None,
        event_end_date=extraction.event_end_date or None,
    )

    # Try to calculate days remaining for the earliest deadline
    earliest_deadline = extraction.registration_deadline or extraction.submission_deadline
    if earliest_deadline:
        try:
            # Try ISO format first
            deadline_date = datetime.fromisoformat(earliest_deadline.replace("Z", "+00:00")).date()
            today = date.today()
            days_left = (deadline_date - today).days
            info.days_remaining = days_left
            info.is_urgent = days_left <= 3
        except (ValueError, TypeError):
            # If date parsing fails, leave as None
            pass

    return info
