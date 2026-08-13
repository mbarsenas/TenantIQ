from __future__ import annotations

import os
from dataclasses import dataclass

import psycopg
from dotenv import load_dotenv
from openai import OpenAI
from pgvector.psycopg import register_vector

load_dotenv()

DATABASE_URL = os.environ["DATABASE_URL"]
EMBEDDING_MODEL = os.getenv("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small")
CHAT_MODEL = os.getenv("OPENAI_CHAT_MODEL", "gpt-5")

client = OpenAI()

SYSTEM_PROMPT = """You are the TenantIQ Microsoft 365 assessment assistant.
Use only the supplied TenantIQ context to answer the user's question.
You may explain findings, risks, evidence, Microsoft 365 concepts, and recommended remediation.
Do not claim to execute PowerShell, Microsoft Graph, or administrative changes.
Do not invent assessment findings or tenant evidence.
If the context is insufficient, say that TenantIQ does not have enough grounded information to answer.
Include a short Sources section listing the source paths you used.
"""


@dataclass
class Match:
    source_path: str
    workload: str | None
    content: str
    distance: float


def embed(text: str) -> list[float]:
    response = client.embeddings.create(model=EMBEDDING_MODEL, input=text)
    return response.data[0].embedding


def retrieve(question: str, workload: str | None = None, limit: int = 5) -> list[Match]:
    query_vector = embed(question)
    with psycopg.connect(DATABASE_URL) as conn:
        register_vector(conn)
        if workload:
            rows = conn.execute(
                """
                SELECT source_path, workload, content, embedding <=> %s AS distance
                FROM tenantiq_knowledge_chunks
                WHERE workload = %s
                ORDER BY embedding <=> %s
                LIMIT %s
                """,
                (query_vector, workload, query_vector, limit),
            ).fetchall()
        else:
            rows = conn.execute(
                """
                SELECT source_path, workload, content, embedding <=> %s AS distance
                FROM tenantiq_knowledge_chunks
                ORDER BY embedding <=> %s
                LIMIT %s
                """,
                (query_vector, query_vector, limit),
            ).fetchall()
    return [Match(*row) for row in rows]


def answer(question: str, workload: str | None = None) -> str:
    matches = retrieve(question, workload=workload)
    context = "\n\n".join(
        f"SOURCE: {m.source_path}\nWORKLOAD: {m.workload or 'General'}\n{m.content}"
        for m in matches
    )
    response = client.responses.create(
        model=CHAT_MODEL,
        instructions=SYSTEM_PROMPT,
        input=f"TenantIQ context:\n\n{context}\n\nUser question:\n{question}",
    )
    return response.output_text


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Ask the TenantIQ RAG knowledge base a question.")
    parser.add_argument("question")
    parser.add_argument("--workload", default=None)
    args = parser.parse_args()
    print(answer(args.question, workload=args.workload))
