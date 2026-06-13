"""
Document parser using PyMuPDF.
Extracts text content with page metadata from PDFs and images.
Outputs markdown-formatted text for optimal LLM comprehension.
"""

from __future__ import annotations
import os
import logging
from dataclasses import dataclass, field
from pathlib import Path

import pymupdf

logger = logging.getLogger(__name__)


@dataclass
class PageContent:
    """Text content from a single page with metadata."""
    page_number: int
    text: str
    char_count: int = 0

    def __post_init__(self):
        self.char_count = len(self.text)


@dataclass
class ParsedDocument:
    """Result of parsing a document — contains all pages and metadata."""
    file_name: str
    total_pages: int
    pages: list[PageContent] = field(default_factory=list)
    full_text: str = ""
    file_type: str = ""

    def get_page_text(self, page_number: int) -> str:
        """Get text for a specific page (1-indexed)."""
        for page in self.pages:
            if page.page_number == page_number:
                return page.text
        return ""

    def get_text_with_page_markers(self) -> str:
        """Get full text with [Page X] markers for citation tracking."""
        parts = []
        for page in self.pages:
            if page.text.strip():
                parts.append(f"[Page {page.page_number}]\n{page.text.strip()}")
        return "\n\n".join(parts)


def parse_pdf(file_path: str) -> ParsedDocument:
    """
    Parse a PDF file and extract text content with page metadata.
    Uses PyMuPDF for fast, accurate text extraction.
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"File not found: {file_path}")

    logger.info(f"Parsing PDF: {path.name}")

    doc = pymupdf.open(file_path)
    pages: list[PageContent] = []

    total_pages = len(doc)
    for page_num in range(total_pages):
        page = doc[page_num]
        # Extract text in markdown-like format for better LLM processing
        text = page.get_text("text")

        if text.strip():
            pages.append(PageContent(
                page_number=page_num + 1,  # 1-indexed
                text=text,
            ))

    doc.close()

    full_text = "\n\n".join(p.text for p in pages)

    result = ParsedDocument(
        file_name=path.name,
        total_pages=total_pages,
        pages=pages,
        full_text=full_text,
        file_type="pdf",
    )

    logger.info(f"Parsed {result.total_pages} pages, {len(full_text)} characters")
    return result


def parse_image(file_path: str) -> ParsedDocument:
    """
    For image files (posters, screenshots, flyers), we pass directly
    to Gemini's vision capabilities rather than traditional OCR.
    Returns a minimal ParsedDocument with file metadata.
    """
    path = Path(file_path)
    if not path.exists():
        raise FileNotFoundError(f"File not found: {file_path}")

    logger.info(f"Image file detected: {path.name} — will use Gemini Vision for extraction")

    return ParsedDocument(
        file_name=path.name,
        total_pages=1,
        pages=[PageContent(page_number=1, text="[Image document — extracted via AI vision]")],
        full_text="",
        file_type=_get_image_type(path.suffix),
    )


def parse_document(file_path: str) -> ParsedDocument:
    """
    Auto-detect file type and parse accordingly.
    Supports: PDF, PNG, JPG, JPEG, WEBP
    """
    path = Path(file_path)
    suffix = path.suffix.lower()

    if suffix == ".pdf":
        return parse_pdf(file_path)
    elif suffix in (".png", ".jpg", ".jpeg", ".webp", ".bmp", ".gif"):
        return parse_image(file_path)
    else:
        raise ValueError(f"Unsupported file type: {suffix}")


def _get_image_type(suffix: str) -> str:
    """Map file extension to MIME-friendly type."""
    mapping = {
        ".png": "image",
        ".jpg": "image",
        ".jpeg": "image",
        ".webp": "image",
        ".bmp": "image",
        ".gif": "image",
    }
    return mapping.get(suffix.lower(), "unknown")
