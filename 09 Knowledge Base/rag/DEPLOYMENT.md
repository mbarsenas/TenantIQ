# TenantIQ RAG Deployment

This document describes the production runtime contract for the TenantIQ Knowledge Assistant backend.

## Required services

- TenantIQ RAG API container
- PostgreSQL 16 with pgvector
- External HTTPS ingress / reverse proxy or managed container platform

## Required environment variables

- `DATABASE_URL`
- `OPENAI_API_KEY`
- `OPENAI_EMBEDDING_MODEL` (default: `text-embedding-3-small`)
- `OPENAI_CHAT_MODEL` (default: `gpt-5`)
- `TENANTIQ_ALLOWED_ORIGINS`

Optional:

- `TENANTIQ_API_HOST` (default in container: `0.0.0.0`)
- `TENANTIQ_API_PORT` (default: `8787`)

## Production rules

1. Do not use the default development PostgreSQL password in production.
2. Do not expose PostgreSQL publicly.
3. Store `OPENAI_API_KEY` and database credentials in the hosting platform's secret store.
4. Set `TENANTIQ_ALLOWED_ORIGINS` to the deployed TenantIQ website origin only.
5. Terminate TLS at the hosting platform or reverse proxy and expose the API only through HTTPS.
6. Configure the TenantIQ website `TENANTIQ_RAG_API` environment variable to the deployed HTTPS RAG API base URL.

Example:

```text
TENANTIQ_RAG_API=https://rag.tenantiq365.com
TENANTIQ_ALLOWED_ORIGINS=https://tenantiq365.com
```

## Container health check

The API exposes:

```text
GET /health
```

Expected response:

```json
{"status":"ok","service":"tenantiq-rag","version":"1.1.0"}
```

## Local container validation

From the RAG directory:

```powershell
cd "C:\Users\Mark\Documents\TenantIQ-GitHub\09 Knowledge Base\rag"
docker compose up --build -d
Invoke-RestMethod http://127.0.0.1:8787/health
```

To stop the stack:

```powershell
cd "C:\Users\Mark\Documents\TenantIQ-GitHub\09 Knowledge Base\rag"
docker compose down
```

## Deployment sequence

1. Provision PostgreSQL 16 + pgvector.
2. Configure production secrets and environment variables.
3. Deploy the TenantIQ RAG API image.
4. Run the knowledge ingestion process against the production database.
5. Import the required TenantIQ assessment data.
6. Verify `/health`.
7. Set the TenantIQ web application's `TENANTIQ_RAG_API` variable.
8. Verify the web proxy health endpoint and `/assistant` end to end.
