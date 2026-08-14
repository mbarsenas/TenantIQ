FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TENANTIQ_API_HOST=0.0.0.0 \
    TENANTIQ_API_PORT=8787

WORKDIR /app

COPY requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8787

CMD ["/bin/sh", "-c", "python -m uvicorn api:app --host 0.0.0.0 --port ${PORT:-8787}"]
