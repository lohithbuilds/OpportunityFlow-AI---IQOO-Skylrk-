# OpportunityFlow AI 🚀

OpportunityFlow AI is an AI-powered student opportunity navigator, parser, and preparation platform. It helps students discover, analyze, and prepare for premium opportunities (like hackathons, scholarships, fellowships, and competitions) using advanced **Retrieval-Augmented Generation (RAG)** and the **Gemini 2.5 Flash** model.

The platform extracts structured metadata from messy PDFs, images (brochures, posters), or web URLs and instantly builds customized day-by-day preparation roadmaps and a source-grounded interactive chat mentor.

---

## ✨ Key Features

1. **📄 AI-Powered Document Ingestion**: Drop any scholarship guidelines PDF, snap a photo of a hackathon poster, or paste a competition website URL. The system parses and indexes it instantly.
2. **🎯 Intelligent Metadata Extraction**: Generates structured information containing details on eligibility, deadlines, locations, benefits, fees, team size limits, and required skills with confidence scoring.
3. **🤖 Source-Grounded AI Mentor (RAG)**: Chat with an AI Mentor trained on the opportunity's guidelines. Every answer includes citations referring back to the page/section in the original document.
4. **📅 Dynamic Study Roadmaps**: Custom-tailored preparation schedules (3, 7, or 14 days) mapping out day-by-day tasks across *research, skill building, practice, logistics,* and *networking*.
5. **📊 Beautiful Dashboard**: A premium dark-themed web client styled with glassmorphism, responsive grid layouts, bookmarks, and automated urgency highlighting for upcoming deadlines.

---

## 🛠 Tech Stack

### Backend
* **FastAPI**: High-performance, asynchronous REST API.
* **Google GenAI SDK**: Powering structured extraction, embedding generation, and chat responses via **Gemini 2.5 Flash**.
* **ChromaDB**: High-performance vector database used to store document embeddings for RAG retrieval.
* **PyMuPDF**: For robust extraction and page-by-page mapping of uploaded PDF documents.

### Frontend
* **Flutter**: Cross-platform client deployed on **Google Chrome Web**.
* **Flutter Animate**: Creating sleek micro-animations, pulse borders, and glow effects.
* **Flutter Markdown**: Renders beautiful markdown content, codeblocks, and lists for AI responses and study plans.

---

## 🚀 Getting Started

### Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Create a virtual environment and activate it:
   ```bash
   python -m venv .venv
   # Windows:
   .venv\Scripts\activate
   # macOS/Linux:
   source .venv/bin/activate
   ```

3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

4. Create a `.env` file in the `backend` folder and add your Gemini API Key:
   ```env
   GEMINI_API_KEY=your_gemini_api_key_here
   PORT=8080
   DEBUG=true
   ```

5. Run the FastAPI server:
   ```bash
   uvicorn main:app --port 8080
   ```
   The backend will start running at `http://localhost:8080`. You can test the health endpoint at `http://localhost:8080/health`.

### Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Run the Flutter web client:
   ```bash
   flutter run -d chrome
   ```
   This compiles the project and opens it in your Chrome browser.

---

## 🛡 Robust Fallback & Error Recovery

OpportunityFlow AI is built with offline/free-tier resilience. If the Gemini API hits key validation issues or rate limits (e.g. `429 RESOURCE_EXHAUSTED`), the backend automatically:
* Retries with **`gemini-2.5-flash`** for high-quota free tier processing.
* Gracefully falls back to structured **mock document parsing, mock preparation roadmaps, and mock chat mentors** so that the application remains 100% functional and interactive.

---

## 📂 Project Structure

```
OpportunityFlow-AI/
├── backend/
│   ├── app/
│   │   ├── api/routes/      # API endpoints (upload, analysis, chat)
│   │   ├── core/            # Config, settings, and deps
│   │   ├── ingestion/       # PDF/image parsing and Gemini extractor
│   │   ├── models/          # Pydantic schemas (opportunity, chat)
│   │   └── services/        # RAG and summary generators
│   ├── main.py              # Backend entrypoint
│   └── requirements.txt
├── frontend/
│   ├── lib/
│   │   ├── core/            # Theme, common widgets, API service
│   │   └── features/        # Upload, Analysis, Chat, Roadmap modules
│   └── pubspec.yaml
└── README.md
```
