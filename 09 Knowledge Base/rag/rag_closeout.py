from __future__ import annotations

import argparse
import importlib.util
import os
import subprocess
import sys
from pathlib import Path

import psycopg
from dotenv import load_dotenv

from assessment_store import DATABASE_URL, ensure_schema, latest_assessment_id
from assessment_summary import load_findings, summarize
from check_catalog import CHECKS

load_dotenv()

RAG_ROOT = Path(__file__).resolve().parent
ROOT = RAG_ROOT.parent.parent if len(RAG_ROOT.parents) >= 2 else RAG_ROOT

REQUIRED_FILES = (
    "assistant.py",
    "assessment_insights.py",
    "assessment_loader.py",
    "assessment_store.py",
    "assessment_summary.py",
    "check_catalog.py",
    "evaluate.py",
    "ingest.py",
    "retrieve.py",
)

REQUIRED_PACKAGES = (
    "openai",
    "psycopg",
    "pgvector",
    "dotenv",
)

EXPECTED_WORKLOADS = {
    "Entra ID",
    "Exchange Online",
    "SharePoint Online",
    "Microsoft Teams",
    "OneDrive",
    "Microsoft Intune",
    "Microsoft Defender",
    "Microsoft Purview",
}


def ok(label: str, detail: str = "") -> None:
    suffix = f" - {detail}" if detail else ""
    print(f"[PASS] {label}{suffix}")


def fail(label: str, detail: str = "") -> None:
    suffix = f" - {detail}" if detail else ""
    print(f"[FAIL] {label}{suffix}")


def warn(label: str, detail: str = "") -> None:
    suffix = f" - {detail}" if detail else ""
    print(f"[WARN] {label}{suffix}")


def check_files() -> bool:
    missing = [name for name in REQUIRED_FILES if not (RAG_ROOT / name).exists()]
    if missing:
        fail("RAG runtime files", ", ".join(missing))
        return False
    ok("RAG runtime files", f"{len(REQUIRED_FILES)} present")
    return True


def check_packages() -> bool:
    missing = [name for name in REQUIRED_PACKAGES if importlib.util.find_spec(name) is None]
    if missing:
        fail("Python dependencies", ", ".join(missing))
        return False
    ok("Python dependencies", "required packages importable")
    return True


def check_environment() -> bool:
    required = ("DATABASE_URL", "OPENAI_API_KEY")
    missing = [name for name in required if not os.getenv(name)]
    if missing:
        fail("Environment", f"missing {', '.join(missing)}")
        return False
    ok("Environment", "DATABASE_URL and OPENAI_API_KEY set")
    return True


def check_catalog() -> bool:
    if not CHECKS:
        fail("Canonical check catalog", "no checks loaded")
        return False

    ids = [check.check_id for check in CHECKS]
    duplicates = sorted({check_id for check_id in ids if ids.count(check_id) > 1})
    if duplicates:
        fail("Canonical check catalog", f"duplicate IDs: {', '.join(duplicates[:10])}")
        return False

    workloads = {str(getattr(check, "workload", "")).strip() for check in CHECKS}
    missing_workloads = sorted(EXPECTED_WORKLOADS - workloads)
    if missing_workloads:
        warn("Catalog workload coverage", f"not labeled as expected: {', '.join(missing_workloads)}")
    else:
        ok("Catalog workload coverage", "all 8 workloads represented")

    ok("Canonical check catalog", f"{len(CHECKS)} unique checks")
    return True


def check_database() -> tuple[bool, str | None]:
    try:
        with psycopg.connect(DATABASE_URL) as conn:
            ensure_schema(conn)
            vector_extension = conn.execute(
                "SELECT 1 FROM pg_extension WHERE extname = 'vector'"
            ).fetchone()
            knowledge_count = conn.execute(
                "SELECT COUNT(*) FROM tenantiq_knowledge_chunks"
            ).fetchone()[0]
            assessment_count = conn.execute(
                "SELECT COUNT(*) FROM tenantiq_assessments"
            ).fetchone()[0]
    except Exception as exc:
        fail("PostgreSQL connectivity", str(exc))
        return False, None

    ok("PostgreSQL connectivity")
    if vector_extension:
        ok("pgvector extension")
    else:
        fail("pgvector extension", "vector extension not installed")
        return False, None

    if knowledge_count > 0:
        ok("Knowledge index", f"{knowledge_count} chunks")
    else:
        fail("Knowledge index", "no chunks found; run ingest.py")
        return False, None

    if assessment_count > 0:
        ok("Stored assessments", f"{assessment_count} assessment(s)")
    else:
        fail("Stored assessments", "no assessments imported")
        return False, None

    assessment_id = latest_assessment_id()
    if not assessment_id:
        fail("Latest stored assessment", "none available")
        return False, None

    findings = load_findings(assessment_id)
    if not findings:
        fail("Latest stored assessment", "contains no findings")
        return False, None

    summary = summarize(findings)
    ok(
        "Latest stored assessment",
        f"{assessment_id} with {summary.get('finding_count', 0)} canonical findings",
    )
    return True, assessment_id


def run_evaluation() -> bool:
    command = [sys.executable, str(RAG_ROOT / "evaluate.py")]
    print("\nRunning grounding evaluation...")
    completed = subprocess.run(command, cwd=RAG_ROOT)
    if completed.returncode != 0:
        fail("Grounding evaluation", f"exit code {completed.returncode}")
        return False
    ok("Grounding evaluation")
    return True


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate TenantIQ RAG readiness and run the grounding gate."
    )
    parser.add_argument(
        "--skip-evaluation",
        action="store_true",
        help="Skip evaluate.py and run structural readiness checks only.",
    )
    args = parser.parse_args()

    print("TenantIQ RAG closeout gate\n")

    checks = [
        check_files(),
        check_packages(),
        check_environment(),
        check_catalog(),
    ]

    db_ok = False
    if all(checks[:3]):
        db_ok, _ = check_database()
    checks.append(db_ok)

    if not args.skip_evaluation and all(checks):
        checks.append(run_evaluation())

    passed = all(checks)
    print("\n" + ("TenantIQ RAG READY" if passed else "TenantIQ RAG NOT READY"))
    if not passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
