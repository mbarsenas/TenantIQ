from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from typing import Any

import psycopg
from dotenv import load_dotenv

from assessment_store import DATABASE_URL, ensure_schema, latest_assessment_id
from check_catalog import CHECK_BY_ID

load_dotenv()


def _normalized_workload(finding: dict[str, Any]) -> str:
    workload = str(finding.get("workload") or "").strip()
    if workload and workload.lower() != "unknown":
        return workload

    check_id = str(finding.get("check_id") or "").strip().upper()
    definition = CHECK_BY_ID.get(check_id)
    if definition:
        return definition.workload

    return "Unknown"


def _raw_evidence(raw: Any) -> Any:
    if not isinstance(raw, dict):
        return None

    # Current rows store the normalized finding object in raw, with the
    # original assessment CSV row nested under raw["raw"]. Older rows may
    # instead contain the original row directly. Recover tenant-specific
    # evidence from either shape so previously imported assessments do not
    # need to be uploaded again.
    candidates: list[dict[str, Any]] = [raw]
    nested = raw.get("raw")
    if isinstance(nested, dict):
        candidates.insert(0, nested)

    for candidate in candidates:
        for key in ("Evidence", "evidence", "Details", "details", "Observed", "observed", "Output", "output", "Finding", "finding"):
            value = candidate.get(key)
            if value not in (None, "", [], {}):
                return value
    return None


def load_findings(assessment_id: str) -> list[dict[str, Any]]:
    with psycopg.connect(DATABASE_URL) as conn:
        ensure_schema(conn)
        rows = conn.execute(
            """
            SELECT check_id, workload, category, status, severity, title,
                   evidence, recommendation, source_assessment_file, raw
            FROM tenantiq_assessment_findings
            WHERE assessment_id = %s
            ORDER BY workload NULLS LAST, category NULLS LAST, check_id
            """,
            (assessment_id,),
        ).fetchall()

    keys = [
        "check_id", "workload", "category", "status", "severity", "title",
        "evidence", "recommendation", "source_assessment_file", "raw",
    ]
    findings = [
        {key: value for key, value in zip(keys, row) if value not in (None, "")}
        for row in rows
    ]

    for finding in findings:
        if finding.get("evidence") in (None, "", [], {}):
            recovered = _raw_evidence(finding.get("raw"))
            if recovered not in (None, "", [], {}):
                finding["evidence"] = recovered
        finding.pop("raw", None)
        finding["workload"] = _normalized_workload(finding)

    return findings


def summarize(findings: list[dict[str, Any]]) -> dict[str, Any]:
    status_counts = Counter(str(f.get("status", "Unknown")) for f in findings)
    severity_counts = Counter(str(f.get("severity", "Unknown")) for f in findings)
    workload_counts: dict[str, Counter[str]] = defaultdict(Counter)

    for finding in findings:
        workload = _normalized_workload(finding)
        status = str(finding.get("status", "Unknown"))
        workload_counts[workload][status] += 1

    priority_order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3, "Unknown": 4}
    failing = [
        finding for finding in findings
        if str(finding.get("status", "")).strip().lower() in {"fail", "failed", "warning", "warn"}
    ]
    failing.sort(
        key=lambda f: (
            priority_order.get(str(f.get("severity", "Unknown")), 4),
            _normalized_workload(f),
            str(f.get("check_id", "")),
        )
    )

    return {
        "finding_count": len(findings),
        "status_counts": dict(status_counts),
        "severity_counts": dict(severity_counts),
        "workloads": {name: dict(counts) for name, counts in sorted(workload_counts.items())},
        "priority_findings": failing[:10],
    }


def print_text(assessment_id: str, summary: dict[str, Any]) -> None:
    print(f"Assessment: {assessment_id}")
    print(f"Canonical findings: {summary['finding_count']}")
    print("\nStatus counts:")
    for status, count in sorted(summary["status_counts"].items()):
        print(f"  {status}: {count}")

    print("\nWorkload status:")
    for workload, counts in summary["workloads"].items():
        compact = ", ".join(f"{status}={count}" for status, count in sorted(counts.items()))
        print(f"  {workload}: {compact}")

    print("\nPriority findings:")
    priority_findings = summary["priority_findings"]
    if not priority_findings:
        print("  No FAIL/WARNING findings were stored for this assessment.")
        return

    for finding in priority_findings:
        severity = finding.get("severity", "Unknown")
        status = finding.get("status", "Unknown")
        check_id = finding.get("check_id", "Unknown")
        title = finding.get("title", check_id)
        workload = _normalized_workload(finding)
        print(f"  [{severity}] [{status}] {workload} - {check_id} - {title}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Summarize findings stored for a TenantIQ assessment.")
    parser.add_argument("--assessment-id", default=None)
    parser.add_argument("--latest-stored-assessment", action="store_true")
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args()

    if args.assessment_id and args.latest_stored_assessment:
        raise SystemExit("Use either --assessment-id or --latest-stored-assessment, not both.")

    assessment_id = args.assessment_id
    if args.latest_stored_assessment or not assessment_id:
        assessment_id = latest_assessment_id()
        if not assessment_id:
            raise SystemExit("No TenantIQ assessments are stored in PostgreSQL yet.")

    findings = load_findings(assessment_id)
    if not findings:
        raise SystemExit(f"No findings stored for assessment {assessment_id}.")

    summary = summarize(findings)
    if args.as_json:
        print(json.dumps({"assessment_id": assessment_id, **summary}, indent=2, default=str))
    else:
        print_text(assessment_id, summary)


if __name__ == "__main__":
    main()
