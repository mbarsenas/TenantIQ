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


def parse_front_matter(text: str) -> tuple[dict, str]:
    if not text.startswith("---\n"):
        return {}, text

    end = text.find("\n---\n", 4)
    if end == -1:
        return {}, text

    raw = text[4:end]
    body = text[end + 5 :].lstrip()
    metadata: dict[str, str] = {}

    for line in raw.splitlines():
        if not line.strip() or line.lstrip().startswith("#") or ":" not in line:
            continue
        key, value = line.split(":", 1)
        metadata[key.strip()] = value.strip().strip('"').strip("'")

    return metadata, body


def infer_metadata(path: Path, front_matter: dict | None = None) -> dict:
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

    metadata = {
        "source_path": rel,
        "workload": workload,
        "content_type": path.parent.name,
    }

    if front_matter:
        metadata.update({k: v for k, v in front_matter.items() if v not in (None, "")})
        if front_matter.get("workload"):
            metadata["workload"] = front_matter["workload"]

    return metadata


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
    conn.execute(
        "CREATE INDEX IF NOT EXISTS tenantiq_knowledge_check_id_idx "
        "ON tenantiq_knowledge_chunks ((metadata->>'check_id'))"
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
        indexed_paths: set[str] = set()

        for path in files:
            raw_text = path.read_text(encoding="utf-8")
            front_matter, text = parse_front_matter(raw_text)
            metadata = infer_metadata(path, front_matter)
            source_path = metadata["source_path"]
            indexed_paths.add(source_path)

            # Replace all chunks for this source atomically at the source-path level.
            # This prevents stale chunks from surviving when a document is edited,
            # shortened, or re-chunked.
            conn.execute(
                "DELETE FROM tenantiq_knowledge_chunks WHERE source_path = %s",
                (source_path,),
            )

            for index, chunk in enumerate(chunk_text(text)):
                stable = f"{source_path}:{index}".encode("utf-8")
                chunk_id = hashlib.sha256(stable).hexdigest()
                vector = embed(chunk)
                conn.execute(
                    """
                    INSERT INTO tenantiq_knowledge_chunks
                        (id, source_path, workload, content_type, chunk_index, content, embedding, metadata, updated_at)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, NOW())
                    ON CONFLICT (id) DO UPDATE SET
                        source_path = EXCLUDED.source_path,
                        workload = EXCLUDED.workload,
                        content_type = EXCLUDED.content_type,
                        chunk_index = EXCLUDED.chunk_index,
                        content = EXCLUDED.content,
                        embedding = EXCLUDED.embedding,
                        metadata = EXCLUDED.metadata,
                        updated_at = NOW()
                    """,
                    (
                        chunk_id,
                        source_path,
                        metadata.get("workload"),
                        metadata.get("content_type"),
                        index,
                        chunk,
                        vector,
                        json.dumps(metadata),
                    ),
                )
            print(f"Indexed {source_path}")

        # Remove knowledge rows for Markdown sources that no longer exist in the KB.
        rows = conn.execute(
            "SELECT DISTINCT source_path FROM tenantiq_knowledge_chunks"
        ).fetchall()
        current_sources = {str(row[0]) for row in rows}
        stale_sources = current_sources - indexed_paths
        for source_path in stale_sources:
            conn.execute(
                "DELETE FROM tenantiq_knowledge_chunks WHERE source_path = %s",
                (source_path,),
            )
            print(f"Removed stale source {source_path}")


if __name__ == "__main__":
    main()
