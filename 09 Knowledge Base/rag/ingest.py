from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from typing import Iterable

import psycopg
from dotenv import load_dotenv
from openai import OpenAI
from pgvector.psycopg import register_vector

load_dotenv()

ROOT = Path(__file__).resolve().parents[2]
KB_ROOT = ROOT / "09 Knowledge Base"
EMBEDDING_MODEL = os.getenv("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small")
DATABASE_URL = os.environ["DATABASE_URL"]

client = OpenAI()


def chunk_text(text: str, size: int = 2200, overlap: int = 300) -> Iterable[str]:
    text = "\n".join(line.rstrip() for line in text.splitlines()).strip()
    if not text:
        return []
    chunks: list[str] = []
    start = 0
    while start < len(text):
        end = min(len(text), start + size)
        chunk = text[start:end].strip()
        if chunk:
            chunks.append(chunk)
        if end == len(text):
            break
        start = max(0, end - overlap)
    return chunks


def infer_metadata(path: Path) -> dict:
    rel = path.relative_to(ROOT).as_posix()
    parts = [p.lower() for p in path.parts]
    workload = None
    workload_map = {
        "entra": "Entra ID",
        "exchange": "Exchange Online",
        "sharepoint": "SharePoint Online",
        "teams": "Microsoft Teams",
        "onedrive": "OneDrive",
        "intune": "Microsoft Intune",
        "defender": "Microsoft Defender",
        "purview": "Microsoft Purview",
    }
    for key, label in workload_map.items():
        if key in parts:
            workload = label
            break
    return {
        "source_path": rel,
        "workload": workload,
        "content_type": path.parent.name,
    }


def ensure_schema(conn: psycopg.Connection) -> None:
    conn.execute("CREATE EXTENSION IF NOT EXISTS vector")
    register_vector(conn)
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS tenantiq_knowledge_chunks (
            id TEXT PRIMARY KEY,
            source_path TEXT NOT NULL,
            workload TEXT,
            content_type TEXT,
            chunk_index INTEGER NOT NULL,
            content TEXT NOT NULL,
            embedding VECTOR(1536) NOT NULL,
            metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
            updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
        )
        """
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS tenantiq_knowledge_embedding_idx "
        "ON tenantiq_knowledge_chunks USING hnsw (embedding vector_cosine_ops)"
    )


def markdown_files() -> list[Path]:
    excluded = {"README.md"}
    return [
        p for p in KB_ROOT.rglob("*.md")
        if p.name not in excluded and "rag" not in [part.lower() for part in p.parts]
    ]


def embed(text: str) -> list[float]:
    result = client.embeddings.create(model=EMBEDDING_MODEL, input=text)
    return result.data[0].embedding


def main() -> None:
    files = markdown_files()
    if not files:
        raise SystemExit("No knowledge-base Markdown files found.")

    with psycopg.connect(DATABASE_URL, autocommit=True) as conn:
        ensure_schema(conn)
        for path in files:
            metadata = infer_metadata(path)
            text = path.read_text(encoding="utf-8")
            for index, chunk in enumerate(chunk_text(text)):
                stable = f"{metadata['source_path']}:{index}:{chunk}".encode("utf-8")
                chunk_id = hashlib.sha256(stable).hexdigest()
                vector = embed(chunk)
                conn.execute(
                    """
                    INSERT INTO tenantiq_knowledge_chunks
                        (id, source_path, workload, content_type, chunk_index, content, embedding, metadata, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, NOW())
                    ON CONFLICT (id) DO UPDATE SET
                        content = EXCLUDED.content,
                        embedding = EXCLUDED.embedding,
                        metadata = EXCLUDED.metadata,
                        updated_at = NOW()
                    """,
                    (
                        chunk_id,
                        metadata["source_path"],
                        metadata["workload"],
                        metadata["content_type"],
                        index,
                        chunk,
                        vector,
                        json.dumps(metadata),
                    ),
                )
            print(f"Indexed {metadata['source_path']}")


if __name__ == "__main__":
    main()
