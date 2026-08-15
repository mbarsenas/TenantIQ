from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from typing import Any

import psycopg
from dotenv import load_dotenv

from assessment_loader import load_assessment
from check_catalog import CHECKS, canonical_check_id

load_dotenv()

DATABASE_URL = os.environ["DATABASE_URL"]
DEFAULT_CUSTOMER_ID = os.getenv("TENANTIQ_DEFAULT_CUSTOMER_ID", "local-dev").strip() or "local-dev"
CANONICAL_CHECK_IDS = {check.check_id for check in CHECKS}


def _customer_id(value: str | None) -> str:
    return (value or DEFAULT_CUSTOMER_ID).strip() or DEFAULT_CUSTOMER_ID


def ensure_schema(conn: psycopg.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS tenantiq_assessments (
            assessment_id TEXT PRIMARY KEY,
            customer_id TEXT NOT NULL DEFAULT 'local-dev',
            source_file TEXT NOT NULL,
            source_name TEXT NOT NULL,
            imported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            finding_count INTEGER NOT NULL DEFAULT 0,
            metadata JSONB NOT NULL DEFAULT '{}'::jsonb
        )
        """
    )
    conn.execute("ALTER TABLE tenantiq_assessments ADD COLUMN IF NOT EXISTS customer_id TEXT")
    conn.execute("UPDATE tenantiq_assessments SET customer_id = %s WHERE customer_id IS NULL OR BTRIM(customer_id) = ''", (DEFAULT_CUSTOMER_ID,))
    conn.execute("ALTER TABLE tenantiq_assessments ALTER COLUMN customer_id SET DEFAULT 'local-dev'")
    conn.execute("ALTER TABLE tenantiq_assessments ALTER COLUMN customer_id SET NOT NULL")
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS tenantiq_assessment_findings (
            assessment_id TEXT NOT NULL REFERENCES tenantiq_assessments(assessment_id) ON DELETE CASCADE,
            check_id TEXT NOT NULL,
            workload TEXT,
            category TEXT,
            status TEXT,
            severity TEXT,
            title TEXT,
            evidence JSONB,
            recommendation TEXT,
            source_assessment_file TEXT,
            raw JSONB NOT NULL DEFAULT '{}'::jsonb,
            imported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            PRIMARY KEY (assessment_id, check_id)
        )
        """
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS tenantiq_assessments_customer_idx ON tenantiq_assessments (customer_id, imported_at DESC)"
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS tenantiq_assessment_findings_workload_idx ON tenantiq_assessment_findings (assessment_id, workload)"
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS tenantiq_assessment_findings_status_idx ON tenantiq_assessment_findings (assessment_id, status)"
    )


def assessment_id_for(path: Path) -> str:
    resolved = path.resolve()
    digest = hashlib.sha256(resolved.read_bytes()).hexdigest()[:16]
    return f"{resolved.stem}-{digest}"


def _json_value(value: Any) -> str:
    if value is None:
        return "null"
    if isinstance(value, (dict, list, int, float, bool)):
        return json.dumps(value)
    return json.dumps(str(value))


def _merge_duplicate_findings(findings: list[dict[str, Any]]) -> list[dict[str, Any]]:
    merged: dict[str, dict[str, Any]] = {}
    for finding in findings:
        check_id = finding.get("check_id")
        if not check_id:
            continue
        existing = merged.get(check_id)
        if existing is None:
            merged[check_id] = dict(finding)
            continue
        combined = dict(existing)
        for key, value in finding.items():
            if value not in (None, "", [], {}):
                combined[key] = value
        duplicate_sources = list(combined.get("duplicate_source_files", []))
        for candidate in (existing.get("source_assessment_file"), finding.get("source_assessment_file")):
            if candidate and candidate not in duplicate_sources:
                duplicate_sources.append(candidate)
        if duplicate_sources:
            combined["duplicate_source_files"] = duplicate_sources
        merged[check_id] = combined
    return list(merged.values())


def _stored_validation_metadata(findings: list[dict[str, Any]], metadata: dict[str, Any]) -> dict[str, Any]:
    if not metadata.get("validated"):
        return metadata

    canonical_count = 0
    for finding in findings:
        check_id = str(finding.get("check_id") or "").strip()
        canonical = canonical_check_id(check_id) if check_id else None
        if canonical and canonical in CANONICAL_CHECK_IDS:
            canonical_count += 1

    finding_count = len(findings)
    return {
        **metadata,
        "canonical_findings": canonical_count,
        "canonical_ratio": round(canonical_count / finding_count, 4) if finding_count else 0.0,
    }


def import_assessment(path: str, metadata: dict[str, Any] | None = None, customer_id: str | None = None) -> tuple[str, int]:
    assessment_path = Path(path)
    findings = load_assessment(str(assessment_path))
    assessment_id = assessment_id_for(assessment_path)
    customer = _customer_id(customer_id)
    canonical_findings = _merge_duplicate_findings(findings)
    stored_metadata = {"input_type": assessment_path.suffix.lower()}
    if metadata:
        stored_metadata.update({k: v for k, v in metadata.items() if v not in (None, "")})
    stored_metadata = _stored_validation_metadata(canonical_findings, stored_metadata)
    source_name = str(stored_metadata.get("original_filename") or assessment_path.name)

    with psycopg.connect(DATABASE_URL, autocommit=True) as conn:
        ensure_schema(conn)
        conn.execute(
            """
            INSERT INTO tenantiq_assessments
                (assessment_id, customer_id, source_file, source_name, finding_count, metadata, imported_at)
            VALUES (%s, %s, %s, %s, %s, %s, NOW())
            ON CONFLICT (assessment_id) DO UPDATE SET
                customer_id = EXCLUDED.customer_id,
                source_file = EXCLUDED.source_file,
                source_name = EXCLUDED.source_name,
                finding_count = EXCLUDED.finding_count,
                metadata = EXCLUDED.metadata,
                imported_at = NOW()
            """,
            (assessment_id, customer, str(assessment_path.resolve()), source_name, len(canonical_findings), json.dumps(stored_metadata)),
        )
        conn.execute("DELETE FROM tenantiq_assessment_findings WHERE assessment_id = %s", (assessment_id,))
        for finding in canonical_findings:
            conn.execute(
                """
                INSERT INTO tenantiq_assessment_findings
                    (assessment_id, check_id, workload, category, status, severity,
                     title, evidence, recommendation, source_assessment_file, raw, imported_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s::jsonb, %s, %s, %s::jsonb, NOW())
                ON CONFLICT (assessment_id, check_id) DO UPDATE SET
                    workload = EXCLUDED.workload,
                    category = EXCLUDED.category,
                    status = EXCLUDED.status,
                    severity = EXCLUDED.severity,
                    title = EXCLUDED.title,
                    evidence = EXCLUDED.evidence,
                    recommendation = EXCLUDED.recommendation,
                    source_assessment_file = EXCLUDED.source_assessment_file,
                    raw = EXCLUDED.raw,
                    imported_at = NOW()
                """,
                (
                    assessment_id,
                    finding.get("check_id"), finding.get("workload"), finding.get("category"), finding.get("status"),
                    finding.get("severity"), finding.get("title"), _json_value(finding.get("evidence")),
                    finding.get("recommendation"), finding.get("source_assessment_file"), json.dumps(finding),
                ),
            )
    return assessment_id, len(canonical_findings)


def latest_assessment_id(customer_id: str | None = None) -> str | None:
    customer = _customer_id(customer_id)
    with psycopg.connect(DATABASE_URL) as conn:
        ensure_schema(conn)
        row = conn.execute(
            "SELECT assessment_id FROM tenantiq_assessments WHERE customer_id = %s ORDER BY imported_at DESC, assessment_id DESC LIMIT 1",
            (customer,),
        ).fetchone()
    return str(row[0]) if row else None


def assessment_exists(assessment_id: str, customer_id: str | None = None) -> bool:
    customer = _customer_id(customer_id)
    with psycopg.connect(DATABASE_URL) as conn:
        ensure_schema(conn)
        row = conn.execute(
            "SELECT 1 FROM tenantiq_assessments WHERE assessment_id = %s AND customer_id = %s LIMIT 1",
            (assessment_id, customer),
        ).fetchone()
    return row is not None


def assessment_metadata(assessment_id: str, customer_id: str | None = None) -> dict[str, Any] | None:
    customer = _customer_id(customer_id)
    with psycopg.connect(DATABASE_URL) as conn:
        ensure_schema(conn)
        row = conn.execute(
            """
            SELECT assessment_id, customer_id, source_name, imported_at, finding_count, metadata
            FROM tenantiq_assessments
            WHERE assessment_id = %s AND customer_id = %s
            """,
            (assessment_id, customer),
        ).fetchone()
    if not row:
        return None
    return {
        "assessment_id": str(row[0]), "customer_id": row[1], "source_name": row[2],
        "imported_at": row[3].isoformat() if row[3] else None, "finding_count": int(row[4] or 0),
        "metadata": row[5] or {},
    }


def list_assessments(limit: int = 25, customer_id: str | None = None) -> list[dict[str, Any]]:
    safe_limit = max(1, min(int(limit), 100))
    customer = _customer_id(customer_id)
    with psycopg.connect(DATABASE_URL) as conn:
        ensure_schema(conn)
        rows = conn.execute(
            """
            SELECT assessment_id, customer_id, source_name, imported_at, finding_count, metadata
            FROM tenantiq_assessments
            WHERE customer_id = %s
            ORDER BY imported_at DESC, assessment_id DESC
            LIMIT %s
            """,
            (customer, safe_limit),
        ).fetchall()
    return [
        {
            "assessment_id": str(row[0]), "customer_id": row[1], "source_name": row[2],
            "imported_at": row[3].isoformat() if row[3] else None, "finding_count": int(row[4] or 0),
            "metadata": row[5] or {},
        }
        for row in rows
    ]


def load_finding_from_db(assessment_id: str, check_id: str, customer_id: str | None = None) -> dict[str, Any] | None:
    customer = _customer_id(customer_id)
    with psycopg.connect(DATABASE_URL) as conn:
        ensure_schema(conn)
        row = conn.execute(
            """
            SELECT f.check_id, f.workload, f.category, f.status, f.severity, f.title,
                   f.evidence, f.recommendation, f.source_assessment_file, f.raw
            FROM tenantiq_assessment_findings f
            JOIN tenantiq_assessments a ON a.assessment_id = f.assessment_id
            WHERE f.assessment_id = %s AND f.check_id = %s AND a.customer_id = %s
            """,
            (assessment_id, check_id, customer),
        ).fetchone()
    if not row:
        return None
    keys = ["check_id", "workload", "category", "status", "severity", "title", "evidence", "recommendation", "source_assessment_file", "raw"]
    return {key: value for key, value in zip(keys, row) if value not in (None, "")}


def claim_assessments(source_customer_id: str, target_customer_id: str, *, allow_explicit_source: bool = False) -> int:
    source = _customer_id(source_customer_id)
    target = _customer_id(target_customer_id)
    if source == target:
        return 0
    if not allow_explicit_source and source != "local-dev":
        raise ValueError("Assessment claiming is restricted to the local-dev source identity.")
    if target == "local-dev":
        raise ValueError("Target customer identity must not be local-dev.")

    with psycopg.connect(DATABASE_URL, autocommit=True) as conn:
        ensure_schema(conn)
        row = conn.execute(
            """
            WITH moved AS (
                UPDATE tenantiq_assessments
                SET customer_id = %s
                WHERE customer_id = %s
                RETURNING assessment_id
            )
            SELECT COUNT(*) FROM moved
            """,
            (target, source),
        ).fetchone()
    return int(row[0] or 0) if row else 0


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Persist or claim TenantIQ assessments in PostgreSQL.")
    subparsers = parser.add_subparsers(dest="command")

    import_parser = subparsers.add_parser("import", help="Import an assessment file.")
    import_parser.add_argument("assessment_file")
    import_parser.add_argument("--customer-id", default=None)

    claim_parser = subparsers.add_parser("claim-local", help="Move local-dev assessments to an authenticated customer identity.")
    claim_parser.add_argument("--target-customer-id", required=True)

    migrate_parser = subparsers.add_parser("migrate-customer", help="Move assessments from one explicit customer identity to another.")
    migrate_parser.add_argument("--source-customer-id", required=True)
    migrate_parser.add_argument("--target-customer-id", required=True)
    migrate_parser.add_argument("--confirm", action="store_true", help="Required safety confirmation for explicit customer migration.")

    args = parser.parse_args()

    if args.command == "claim-local":
        moved = claim_assessments("local-dev", args.target_customer_id)
        print(f"Claimed {moved} local assessment(s) for {args.target_customer_id}.")
    elif args.command == "migrate-customer":
        if not args.confirm:
            parser.error("migrate-customer requires --confirm.")
        moved = claim_assessments(args.source_customer_id, args.target_customer_id, allow_explicit_source=True)
        print(f"Migrated {moved} assessment(s) from {args.source_customer_id} to {args.target_customer_id}.")
    else:
        assessment_file = getattr(args, "assessment_file", None)
        customer_id = getattr(args, "customer_id", None)
        if not assessment_file:
            parser.error("assessment_file is required. Use the 'import' subcommand or provide a command.")
        assessment_id, count = import_assessment(assessment_file, customer_id=customer_id)
        print(f"Imported assessment {assessment_id} with {count} canonical findings.")
