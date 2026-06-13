"""
RAG (Retrieval-Augmented Generation) service.
Provides source-grounded AI chat using ChromaDB + Gemini.
Every response includes citations back to the source document.
"""

from __future__ import annotations
import logging
import uuid

from google.genai import types

from ..core.deps import get_gemini_client, get_chroma_collection, is_api_key_valid
from ..core.config import get_settings
from ..models.opportunity import OpportunityData
from ..models.chat import ChatRequest, ChatResponse, SourceCitation, ChatMessage

logger = logging.getLogger(__name__)

# ── System Prompt ──────────────────────────────────────────────

MENTOR_SYSTEM_PROMPT = """You are OpportunityFlow AI Mentor — a helpful, accurate assistant that helps students understand and prepare for opportunities.

CRITICAL RULES:
1. ONLY answer based on the provided opportunity document content and extracted data.
2. NEVER make up information that is not in the document.
3. If you don't know something or it's not in the document, say "This information is not available in the provided document."
4. Always cite your sources using [Page X] or [Section: Y] format.
5. Be encouraging but honest about eligibility and requirements.
6. When giving preparation advice, base it on the requirements and skills mentioned in the document.

OPPORTUNITY DATA:
{opportunity_json}

DOCUMENT CONTENT:
{document_text}
"""

SUGGESTED_QUESTIONS = [
    "Am I eligible for this opportunity?",
    "What skills do I need to prepare?",
    "Is there a registration fee?",
    "What are the judging criteria?",
    "How do I register?",
    "What are the prizes or benefits?",
    "What is the team size requirement?",
    "When is the deadline?",
]


async def index_opportunity(opportunity_id: str, opportunity: OpportunityData) -> None:
    """
    Index an opportunity's content into ChromaDB for RAG retrieval.
    Chunks the document text and stores with page metadata.
    """
    settings = get_settings()
    client = get_gemini_client()
    collection = get_chroma_collection(opportunity_id)

    # Build chunks from the raw text with page markers
    raw_text = opportunity.raw_text
    if not raw_text or raw_text == "[Image document]":
        # For images, use the structured extraction as the indexed content
        raw_text = opportunity.extraction.model_dump_json(indent=2)

    chunks = _chunk_text(raw_text, chunk_size=800, overlap=150)

    if not chunks:
        logger.warning(f"No chunks to index for opportunity {opportunity_id}")
        return

    # Generate embeddings via Gemini
    embeddings = []
    for chunk in chunks:
        try:
            if not is_api_key_valid():
                embeddings.append([0.0] * 768)
                continue
            result = client.models.embed_content(
                model=settings.gemini_embedding_model,
                contents=chunk["text"],
            )
            embeddings.append(result.embeddings[0].values)
        except Exception as e:
            logger.error(f"Embedding failed for chunk: {e}")
            embeddings.append([0.0] * 768)  # Fallback zero vector

    # Store in ChromaDB
    collection.add(
        ids=[chunk["id"] for chunk in chunks],
        documents=[chunk["text"] for chunk in chunks],
        embeddings=embeddings,
        metadatas=[{"page": chunk.get("page", 0), "index": i} for i, chunk in enumerate(chunks)],
    )

    logger.info(f"Indexed {len(chunks)} chunks for opportunity {opportunity_id}")


async def chat_with_mentor(
    request: ChatRequest,
    opportunity: OpportunityData,
) -> ChatResponse:
    """
    RAG-powered chat: retrieve relevant chunks, then generate
    a grounded response with source citations.
    """
    def get_mock_chat_response():
        query_lower = request.message.lower()
        ext = opportunity.extraction
        
        # Pick citation based on fields
        citation_text = "Opportunity document details"
        page = 1
        
        if "eligib" in query_lower:
            answer_text = f"According to the document, the eligibility criteria are: {ext.eligibility}. Let me know if you would like me to check your profile against this!"
            citation_text = f"Eligibility: {ext.eligibility[:100]}..."
        elif "dead" in query_lower or "date" in query_lower or "when" in query_lower:
            answer_text = f"The registration deadline is {ext.registration_deadline or 'not specified'} and the submission deadline is {ext.submission_deadline or 'not specified'}."
            citation_text = f"Timeline: Registration by {ext.registration_deadline}"
        elif "fee" in query_lower or "cost" in query_lower or "pay" in query_lower:
            answer_text = f"The registration fee for this event is: {ext.fees or 'Free'}."
            citation_text = f"Registration Fees: {ext.fees}"
        elif "prize" in query_lower or "award" in query_lower or "benefit" in query_lower or "trophy" in query_lower or "money" in query_lower:
            benefits_list = "\n".join([f"- {b}" for b in ext.benefits]) if ext.benefits else "not explicitly mentioned."
            answer_text = f"Here are the benefits and prizes for participating:\n{benefits_list}"
            citation_text = "Benefits & Rewards"
        elif "skill" in query_lower or "prepare" in query_lower or "learn" in query_lower:
            skills_str = ", ".join(ext.skills_needed) if ext.skills_needed else "general technical skills."
            answer_text = f"To prepare for this opportunity, you should focus on: {skills_str}. You can also generate a study roadmap from the Roadmap tab!"
            citation_text = f"Skills required: {skills_str}"
        elif "team" in query_lower or "size" in query_lower or "member" in query_lower:
            answer_text = f"The team requirements are: {ext.team_size or 'Individual participation or team rules not specified'}."
            citation_text = f"Team Size: {ext.team_size}"
        elif "contact" in query_lower or "support" in query_lower or "email" in query_lower:
            answer_text = f"You can reach out to the organizers at: {ext.contact_info or 'not provided'}."
            citation_text = f"Contact Information: {ext.contact_info}"
        else:
            answer_text = f"Hello! I am your AI Opportunity Mentor. Regarding '{ext.event_name}', here is a brief overview:\n\n{ext.description}\n\nYou can ask me about eligibility, requirements, deadlines, fees, skills needed, or benefits."
            citation_text = f"Overview of {ext.event_name}"

        suggested = _get_suggested_questions(request.message, request.conversation_history)
        
        return ChatResponse(
            answer=answer_text,
            sources=[SourceCitation(text=citation_text, page=page, section="Extracted Document")],
            suggested_questions=suggested,
            confidence="high",
        )

    if not is_api_key_valid():
        return get_mock_chat_response()

    client = get_gemini_client()
    settings = get_settings()

    # Step 1: Retrieve relevant chunks from ChromaDB
    try:
        retrieved_context, source_citations = await _retrieve_context(
            request.opportunity_id, request.message
        )
    except Exception as e:
        logger.warning(f"RAG retrieval failed: {e}. Using raw text context.")
        retrieved_context = opportunity.raw_text[:5000]
        source_citations = [SourceCitation(text="Full document", section="Extracted Document")]

    # Step 2: Build system prompt with opportunity data + retrieved context
    system_prompt = MENTOR_SYSTEM_PROMPT.format(
        opportunity_json=opportunity.extraction.model_dump_json(indent=2),
        document_text=retrieved_context or opportunity.raw_text[:5000],
    )

    # Step 3: Build conversation history
    contents = []
    for msg in request.conversation_history[-10:]:  # Last 10 messages
        contents.append(
            types.Content(
                role="user" if msg.role == "user" else "model",
                parts=[types.Part(text=msg.content)],
            )
        )

    # Add current user message
    contents.append(
        types.Content(
            role="user",
            parts=[types.Part(text=request.message)],
        )
    )

    model_to_try = settings.gemini_model
    # Step 4: Generate response
    try:
        response = client.models.generate_content(
            model=model_to_try,
            contents=contents,
            config=types.GenerateContentConfig(
                system_instruction=system_prompt,
                temperature=0.3,
                max_output_tokens=1500,
            ),
        )
        answer_text = response.text or "I'm sorry, I couldn't generate a response."
        suggested = _get_suggested_questions(request.message, request.conversation_history)
        return ChatResponse(
            answer=answer_text,
            sources=source_citations,
            suggested_questions=suggested,
            confidence="high" if source_citations else "medium",
        )
    except Exception as e:
        logger.warning(f"Chat failed with model {model_to_try}: {e}. Retrying with gemini-2.5-flash...")
        try:
            response = client.models.generate_content(
                model="gemini-2.5-flash",
                contents=contents,
                config=types.GenerateContentConfig(
                    system_instruction=system_prompt,
                    temperature=0.3,
                    max_output_tokens=1500,
                ),
            )
            answer_text = response.text or "I'm sorry, I couldn't generate a response."
            suggested = _get_suggested_questions(request.message, request.conversation_history)
            return ChatResponse(
                answer=answer_text,
                sources=source_citations,
                suggested_questions=suggested,
                confidence="high" if source_citations else "medium",
            )
        except Exception as e2:
            logger.error(f"Chat failed with gemini-2.5-flash: {e2}. Falling back to mock chat response.")
            return get_mock_chat_response()


async def _retrieve_context(
    opportunity_id: str, query: str
) -> tuple[str, list[SourceCitation]]:
    """Retrieve relevant document chunks from ChromaDB."""
    try:
        client = get_gemini_client()
        settings = get_settings()
        collection = get_chroma_collection(opportunity_id)

        # Embed the query
        result = client.models.embed_content(
            model=settings.gemini_embedding_model,
            contents=query,
        )
        query_embedding = result.embeddings[0].values

        # Retrieve top-5 relevant chunks
        results = collection.query(
            query_embeddings=[query_embedding],
            n_results=5,
        )

        if not results["documents"] or not results["documents"][0]:
            return "", []

        # Build context and citations
        context_parts = []
        citations = []
        seen_pages = set()

        for doc, metadata in zip(results["documents"][0], results["metadatas"][0]):
            context_parts.append(doc)
            page = metadata.get("page", 0)
            if page and page not in seen_pages:
                seen_pages.add(page)
                citations.append(SourceCitation(
                    text=doc[:150] + "..." if len(doc) > 150 else doc,
                    page=page,
                    section="Extracted Section",
                ))

        return "\n\n".join(context_parts), citations

    except Exception as e:
        logger.warning(f"RAG retrieval failed: {e}")
        return "", [SourceCitation(text="Full document", section="Extracted Document")]


def _chunk_text(text: str, chunk_size: int = 800, overlap: int = 150) -> list[dict]:
    """Split text into overlapping chunks with page tracking."""
    chunks = []
    current_page = 1

    # Track page markers
    lines = text.split("\n")
    current_chunk = []
    current_length = 0

    for line in lines:
        # Detect page markers
        if line.strip().startswith("[Page ") and line.strip().endswith("]"):
            try:
                current_page = int(line.strip()[6:-1])
            except ValueError:
                pass
            continue

        current_chunk.append(line)
        current_length += len(line) + 1

        if current_length >= chunk_size:
            chunk_text = "\n".join(current_chunk)
            chunks.append({
                "id": str(uuid.uuid4()),
                "text": chunk_text,
                "page": current_page,
            })

            # Keep overlap
            overlap_lines = []
            overlap_length = 0
            for l in reversed(current_chunk):
                if overlap_length + len(l) > overlap:
                    break
                overlap_lines.insert(0, l)
                overlap_length += len(l) + 1

            current_chunk = overlap_lines
            current_length = overlap_length

    # Last chunk
    if current_chunk:
        chunks.append({
            "id": str(uuid.uuid4()),
            "text": "\n".join(current_chunk),
            "page": current_page,
        })

    return chunks


def _get_suggested_questions(
    current_msg: str, history: list[ChatMessage]
) -> list[str]:
    """Pick relevant suggested questions that haven't been asked yet."""
    asked = {current_msg.lower()}
    for msg in history:
        if msg.role == "user":
            asked.add(msg.content.lower())

    suggestions = [q for q in SUGGESTED_QUESTIONS if q.lower() not in asked]
    return suggestions[:3]
