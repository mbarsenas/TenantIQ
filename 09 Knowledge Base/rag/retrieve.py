from __future__ import annotations

import os
from dataclasses import dataclass

import psycopg
from dotenv import load_dotenv
from openai import OpenAI
from pgvector import Vector
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


def retrieve(
    question: str,
    workload: str | None = None,
    check_id: str | None = None,
    limit: int = 5,
) -> list[Match]:
    query_vector = Vector(embed(question))

    where: list[str] = []
    params: list[object] = []

    if workload:
        where.append("workload = %s")
        params.append(workload)
    if check_id:
        where.append("metadata->>'check_id' = %s")
        params.append(check_id)

    where_sql = f"WHERE {' AND '.join(where)}" if where else ""

    sql = f"""
        SELECT source_path, workload, content, embedding <=> %s::vector AS distance
        FROM tenantiq_knowledge_chunks
        {where_sql}
        ORDER BY embedding <=> %s::vector
        LIMIT %s
    """

    with psycopg.connect(DATABASE_URL) as conn:
        register_vector(conn)
        rows = conn.execute(
            sql,
            (query_vector, *params, query_vector, limit),
        ).fetchall()

    return [Match(*row) for row in rows]


def answer(
    question: str,
    workload: str | None = None,
    check_id: str | None = None,
) -> str:
    matches = retrieve(question, workload=workload, check_id=check_id)
    if not matches:
        scope = f" for check {check_id}" if check_id else ""
        return f"TenantIQ does not have enough grounded information to answer{scope}."

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
    parser.add_argument("--check-id", default=None)
    args = parser.parse_args()
    print(answer(args.question, workload=args.workload, check_id=args.check_id))
