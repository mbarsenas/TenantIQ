from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Any


CHECK_ID_ALIASES = {
    # Entra ID
    "mfa registration": "ENTRA-MFA-001",
    "mfa registration coverage": "ENTRA-MFA-001",
    "multifactor authentication registration": "ENTRA-MFA-001",
    "multi-factor authentication registration": "ENTRA-MFA-001",
}


def _normalize_key(value: str) -> str:
    return "".join(ch for ch in value.strip().lower() if ch.isalnum())


def _normalize_text(value: Any) -> str:
    return " ".join(str(value or "").strip().lower().split())


def _first_present(row: dict[str, Any], *names: str) -> Any:
    normalized = {_normalize_key(str(k)): v for k, v in row.items()}
    for name in names:
        key = _normalize_key(name)
        if key in normalized and normalized[key] not in (None, ""):
            return normalized[key]
    return None


def _infer_check_id(row: dict[str, Any], title: Any) -> str | None:
    explicit = _first_present(row, "check_id", "checkid", "id", "controlid")
    if explicit:
        return str(explicit).strip()

    normalized_title = _normalize_text(title)
    if normalized_title in CHECK_ID_ALIASES:
        return CHECK_ID_ALIASES[normalized_title]

    return None


def normalize_finding(row: dict[str, Any]) -> dict[str, Any]:
    status = _first_present(row, "status", "result", "state")
    workload = _first_present(row, "workload", "module", "service")
    category = _first_present(row, "category", "area")
    title = _first_present(row, "title", "check", "checkname", "name", "finding")
    evidence = _first_present(row, "evidence", "details", "detail", "observed", "output")
    recommendation = _first_present(row, "recommendation", "remediation", "action")
    severity = _first_present(row, "severity", "risk", "priority")
    check_id = _infer_check_id(row, title)

    result: dict[str, Any] = {
        "check_id": check_id,
        "status": status,
        "workload": workload,
        "category": category,
        "title": title,
        "evidence": evidence,
        "recommendation": recommendation,
        "severity": severity,
        "raw": row,
    }
    return {k: v for k, v in result.items() if v not in (None, "")}


def _read_csv_rows(path: Path) -> list[dict[str, Any]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        return [dict(row) for row in csv.DictReader(handle)]


def _looks_like_portfolio(rows: list[dict[str, Any]]) -> bool:
    if not rows:
        return False
    normalized_headers = {_normalize_key(str(key)) for key in rows[0].keys()}
    required = {"workload", "file"}
    summary_markers = {"total", "pass", "warning", "fail", "info", "score"}
    return required.issubset(normalized_headers) and bool(summary_markers & normalized_headers)


def _load_portfolio(path: Path, rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    missing: list[str] = []

    for row in rows:
        referenced = _first_present(row, "file", "assessmentfile", "resultfile")
        if not referenced:
            continue

        child_path = Path(str(referenced))
        if not child_path.is_absolute():
            child_path = path.parent / child_path

        if not child_path.exists():
            missing.append(str(child_path))
            continue

        child_findings = load_assessment(str(child_path), follow_portfolio=False)
        portfolio_workload = _first_present(row, "workload", "module", "service")
        for finding in child_findings:
            if portfolio_workload and "workload" not in finding:
                finding["workload"] = portfolio_workload
            finding["source_assessment_file"] = str(child_path)
            finding["portfolio_file"] = str(path)
        findings.extend(child_findings)

    if findings:
        return findings

    if missing:
        raise SystemExit(
            "Portfolio assessment referenced workload files that were not found: "
            + "; ".join(missing[:5])
        )

    raise SystemExit("Portfolio assessment did not reference any readable workload assessment files.")


def load_assessment(path: str, follow_portfolio: bool = True) -> list[dict[str, Any]]:
    assessment_path = Path(path)
    if not assessment_path.exists():
        raise SystemExit(f"Assessment file not found: {assessment_path}")

    suffix = assessment_path.suffix.lower()
    if suffix == ".json":
        data = json.loads(assessment_path.read_text(encoding="utf-8"))
        if isinstance(data, dict):
            for key in ("findings", "results", "checks", "items"):
                if isinstance(data.get(key), list):
                    data = data[key]
                    break
            else:
                data = [data]
        if not isinstance(data, list):
            raise SystemExit("Assessment JSON must contain an object or list of objects.")
        return [normalize_finding(item) for item in data if isinstance(item, dict)]

    if suffix == ".csv":
        rows = _read_csv_rows(assessment_path)
        if follow_portfolio and _looks_like_portfolio(rows):
            return _load_portfolio(assessment_path, rows)
        return [normalize_finding(row) for row in rows]

    raise SystemExit("Assessment input currently supports .csv and .json files.")


def select_finding(findings: list[dict[str, Any]], check_id: str) -> dict[str, Any]:
    requested = check_id.strip().lower()
    for finding in findings:
        candidate = str(finding.get("check_id", "")).strip().lower()
        if candidate == requested:
            return finding

    known = sorted(
        {
            str(finding.get("check_id"))
            for finding in findings
            if finding.get("check_id")
        }
    )
    if known:
        raise SystemExit(
            f"Check ID not found in assessment file: {check_id}. "
            f"Mapped check IDs present: {', '.join(known)}"
        )

    raise SystemExit(
        f"Check ID not found in assessment file: {check_id}. "
        "No rows in this assessment currently map to canonical TenantIQ RAG check IDs."
    )
