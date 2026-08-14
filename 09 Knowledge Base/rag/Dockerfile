FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TENANTIQ_API_HOST=0.0.0.0 \
    TENANTIQ_API_PORT=8787

WORKDIR /app

COPY "09 Knowledge Base/rag/requirements.txt" ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY "09 Knowledge Base/rag" ./rag
WORKDIR /app/rag

EXPOSE 8787

CMD ["python", "-m", "uvicorn", "api:app", "--host", "0.0.0.0", "--port", "8787"]
