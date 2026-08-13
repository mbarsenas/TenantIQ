# TenantIQ Knowledge Base

This directory contains curated, retrieval-ready knowledge used by the TenantIQ RAG assistant.

## Scope

The knowledge base is intentionally separated from the assessment engine. It provides explanations, remediation guidance, safety boundaries, and source metadata without modifying TenantIQ health-check execution.

## Structure

- `product/` — TenantIQ product, assessment, and assistant behavior documentation.
- `workloads/` — workload-specific knowledge for Entra ID, Exchange Online, SharePoint Online, Teams, OneDrive, Intune, Defender, and Purview.
- `remediation/` — cross-workload remediation guidance.
- `schema/` — normalized knowledge-record schema.
- `rag/` — ingestion, retrieval, and local development scaffolding.

## Design principles

1. Read-only assistant behavior.
2. Ground answers in TenantIQ knowledge and approved sources.
3. Preserve source path and workload metadata for citations and filtering.
4. Never claim that remediation was executed.
5. Never invent TenantIQ findings or tenant evidence.
6. Prefer structured check identifiers so future assessment results can retrieve exact guidance.

## Initial retrieval model

Each knowledge item should carry metadata such as:

- `checkId`
- `workload`
- `category`
- `title`
- `contentType`
- `sourcePath`
- `sourceUrl`
- `version`

The RAG service can then use semantic similarity plus metadata filtering to retrieve the most relevant TenantIQ context for a user question.
