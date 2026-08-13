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


def load_assessment(path: str) -> list[dict[str, Any]]:
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
        with assessment_path.open("r", encoding="utf-8-sig", newline="") as handle:
            return [normalize_finding(dict(row)) for row in csv.DictReader(handle)]

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
