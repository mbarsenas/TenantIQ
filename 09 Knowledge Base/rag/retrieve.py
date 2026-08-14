from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path

import psycopg
from dotenv import load_dotenv
from openai import OpenAI
from pgvector import Vector
from pgvector.psycopg import register_vector

from assessment_loader import load_assessment, select_finding

load_dotenv()

ROOT = Path(__file__).resolve().parents[2]
OUTPUT_ROOT = ROOT / "06 Output"
DATABASE_URL = os.environ["DATABASE_URL"]
EMBEDDING_MODEL = os.getenv("OPENAI_EMBEDDING_MODEL", "text-embedding-3-small")
CHAT_MODEL = os.getenv("OPENAI_CHAT_MODEL", "gpt-5")

client = OpenAI()

SYSTEM_PROMPT = """You are the TenantIQ Microsoft 365 assessment assistant.
Use only the supplied TenantIQ knowledge context and assessment finding evidence to answer the user's question.
You may explain findings, risks, evidence, Microsoft 365 concepts, and recommended remediation.
Treat assessment finding evidence as tenant-specific observed data.
Do not invent missing counts, statuses, identities, dates, policies, or configuration details.
Do not claim to execute PowerShell, Microsoft Graph, or administrative changes.
Do not claim remediation has been performed.
If the supplied knowledge or evidence is insufficient, say that TenantIQ does not have enough grounded information to answer.
Include a short Sources section listing the TenantIQ knowledge source paths you used.
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


def load_finding(path: str | None) -> dict | None:
    if not path:
        return None

    finding_path = Path(path)
    if not finding_path.exists():
        raise SystemExit(f"Finding file not found: {finding_path}")

    try:
        finding = json.loads(finding_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Finding file is not valid JSON: {exc}") from exc

    if not isinstance(finding, dict):
        raise SystemExit("Finding file must contain a JSON object.")

    return finding


def latest_portfolio_assessment() -> Path | None:
    candidates = sorted(
        OUTPUT_ROOT.glob("TenantIQ-Portfolio-Assessment-*.csv"),
        key=lambda path: path.stat().st_mtime,
        reverse=True,
    )
    return candidates[0] if candidates else None


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
    finding: dict | None = None,
) -> str:
    effective_check_id = check_id
    if finding:
        finding_check_id = finding.get("check_id") or finding.get("checkId")
        if effective_check_id and finding_check_id and effective_check_id != finding_check_id:
            raise SystemExit(
                f"Check ID mismatch: --check-id is {effective_check_id}, but finding evidence contains {finding_check_id}."
            )
        effective_check_id = effective_check_id or finding_check_id

    matches = retrieve(question, workload=workload, check_id=effective_check_id)
    if not matches:
        scope = f" for check {effective_check_id}" if effective_check_id else ""
        return f"TenantIQ does not have enough grounded information to answer{scope}."

    context = "\n\n".join(
        f"SOURCE: {m.source_path}\nWORKLOAD: {m.workload or 'General'}\n{m.content}"
        for m in matches
    )

    finding_context = ""
    if finding:
        finding_context = (
            "\n\nTenant-specific assessment finding evidence:\n"
            + json.dumps(finding, indent=2, sort_keys=True)
        )

    response = client.responses.create(
        model=CHAT_MODEL,
        instructions=SYSTEM_PROMPT,
        input=(
            f"TenantIQ knowledge context:\n\n{context}"
            f"{finding_context}"
            f"\n\nUser question:\n{question}"
        ),
    )
    return response.output_text


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Ask the TenantIQ RAG knowledge base a question.")
    parser.add_argument("question")
    parser.add_argument("--workload", default=None)
    parser.add_argument("--check-id", default=None)
    parser.add_argument(
        "--finding-file",
        default=None,
        help="Path to a JSON file containing one tenant-specific finding.",
    )
    parser.add_argument(
        "--assessment-file",
        default=None,
        help="Path to a TenantIQ assessment .csv or .json file containing multiple findings.",
    )
    parser.add_argument(
        "--latest-assessment",
        action="store_true",
        help="Use the newest TenantIQ portfolio assessment found under 06 Output.",
    )
    args = parser.parse_args()

    if args.finding_file and (args.assessment_file or args.latest_assessment):
        raise SystemExit("Use --finding-file by itself, or use an assessment source.")
    if args.assessment_file and args.latest_assessment:
        raise SystemExit("Use either --assessment-file or --latest-assessment, not both.")

    finding = load_finding(args.finding_file)
    assessment_path: str | None = args.assessment_file

    if args.latest_assessment:
        latest = latest_portfolio_assessment()
        if not latest:
            raise SystemExit(f"No TenantIQ portfolio assessment found under {OUTPUT_ROOT}.")
        assessment_path = str(latest)
        print(f"Using latest assessment: {latest}")

    if assessment_path:
        if not args.check_id:
            raise SystemExit("Assessment queries require --check-id so TenantIQ can select one finding.")
        finding = select_finding(load_assessment(assessment_path), args.check_id)

    print(
        answer(
            args.question,
            workload=args.workload,
            check_id=args.check_id,
            finding=finding,
        )
    )
