FROM python:3.12-slim

WORKDIR /app

# Install dependencies first (cached layer)
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Render sets PORT env var; default to 10000
EXPOSE ${PORT:-10000}

CMD uvicorn main:app --host 0.0.0.0 --port ${PORT:-10000}
