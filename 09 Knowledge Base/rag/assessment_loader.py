from __future__ import annotations

import csv
import json
from pathlib import Path
from typing import Any


def _normalize_key(value: str) -> str:
    return "".join(ch for ch in value.strip().lower() if ch.isalnum())


def _first_present(row: dict[str, Any], *names: str) -> Any:
    normalized = {_normalize_key(str(k)): v for k, v in row.items()}
    for name in names:
        key = _normalize_key(name)
        if key in normalized and normalized[key] not in (None, ""):
            return normalized[key]
    return None


def normalize_finding(row: dict[str, Any]) -> dict[str, Any]:
    check_id = _first_present(row, "check_id", "checkid", "id", "controlid")
    status = _first_present(row, "status", "result", "state")
    workload = _first_present(row, "workload", "module", "service")
    category = _first_present(row, "category", "area")
    title = _first_present(row, "title", "check", "checkname", "name", "finding")
    evidence = _first_present(row, "evidence", "details", "detail", "observed", "output")
    recommendation = _first_present(row, "recommendation", "remediation", "action")
    severity = _first_present(row, "severity", "risk", "priority")

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
    raise SystemExit(f"Check ID not found in assessment file: {check_id}")
