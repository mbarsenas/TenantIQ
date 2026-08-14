from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from typing import Any

import psycopg
from dotenv import load_dotenv

from assessment_loader import load_assessment

load_dotenv()

DATABASE_URL = os.environ["DATABASE_URL"]


def ensure_schema(conn: psycopg.Connection) -> None:
    conn.execute(
        """
        CREATE TABLE IF NOT EXISTS tenantiq_assessments (
            assessment_id TEXT PRIMARY KEY,
            source_file TEXT NOT NULL,
            source_name TEXT NOT NULL,
            imported_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
            finding_count INTEGER NOT NULL DEFAULT 0,
            metadata JSONB NOT NULL DEFAULT '{}'::jsonb
        )
        """
    )
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
        "CREATE INDEX IF NOT EXISTS tenantiq_assessment_findings_workload_idx "
        "ON tenantiq_assessment_findings (assessment_id, workload)"
    )
    conn.execute(
        "CREATE INDEX IF NOT EXISTS tenantiq_assessment_findings_status_idx "
        "ON tenantiq_assessment_findings (assessment_id, status)"
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
        for candidate in (
            existing.get("source_assessment_file"),
            finding.get("source_assessment_file"),
        ):
            if candidate and candidate not in duplicate_sources:
                duplicate_sources.append(candidate)
        if duplicate_sources:
            combined["duplicate_source_files"] = duplicate_sources

        merged[check_id] = combined

    return list(merged.values())


def import_assessment(path: str) -> tuple[str, int]:
    assessment_path = Path(path)
    findings = load_assessment(str(assessment_path))
    assessment_id = assessment_id_for(assessment_path)

    canonical_findings = _merge_duplicate_findings(findings)

    with psycopg.connect(DATABASE_URL, autocommit=True) as conn:
        ensure_schema(conn)
        conn.execute(
            """
            INSERT INTO tenantiq_assessments
                (assessment_id, source_file, source_name, finding_count, metadata, imported_at)
            VALUES (%s, %s, %s, %s, %s, NOW())
            ON CONFLICT (assessment_id) DO UPDATE SET
                source_file = EXCLUDED.source_file,
                source_name = EXCLUDED.source_name,
                finding_count = EXCLUDED.finding_count,
                metadata = EXCLUDED.metadata,
                imported_at = NOW()
            """,
            (
                assessment_id,
                str(assessment_path.resolve()),
                assessment_path.name,
                len(canonical_findings),
                json.dumps({"input_type": assessment_path.suffix.lower()}),
            ),
        )

        conn.execute(
            "DELETE FROM tenantiq_assessment_findings WHERE assessment_id = %s",
            (assessment_id,),
        )

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
                    finding.get("check_id"),
                    finding.get("workload"),
                    finding.get("category"),
                    finding.get("status"),
                    finding.get("severity"),
                    finding.get("title"),
                    _json_value(finding.get("evidence")),
                    finding.get("recommendation"),
                    finding.get("source_assessment_file"),
                    json.dumps(finding),
                ),
            )

    return assessment_id, len(canonical_findings)


def latest_assessment_id() -> str | None:
    with psycopg.connect(DATABASE_URL) as conn:
        ensure_schema(conn)
        row = conn.execute(
            """
            SELECT assessment_id
            FROM tenantiq_assessments
            ORDER BY imported_at DESC, assessment_id DESC
            LIMIT 1
            """
        ).fetchone()
    return str(row[0]) if row else None


def load_finding_from_db(assessment_id: str, check_id: str) -> dict[str, Any] | None:
    with psycopg.connect(DATABASE_URL) as conn:
        ensure_schema(conn)
        row = conn.execute(
            """
            SELECT check_id, workload, category, status, severity, title,
                   evidence, recommendation, source_assessment_file, raw
            FROM tenantiq_assessment_findings
            WHERE assessment_id = %s AND check_id = %s
            """,
            (assessment_id, check_id),
        ).fetchone()

    if not row:
        return None

    keys = [
        "check_id", "workload", "category", "status", "severity", "title",
        "evidence", "recommendation", "source_assessment_file", "raw",
    ]
    return {key: value for key, value in zip(keys, row) if value not in (None, "")}


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Persist a TenantIQ assessment into PostgreSQL.")
    parser.add_argument("assessment_file")
    args = parser.parse_args()

    assessment_id, count = import_assessment(args.assessment_file)
    print(f"Imported assessment {assessment_id} with {count} canonical findings.")
