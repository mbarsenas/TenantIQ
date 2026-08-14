from __future__ import annotations

import json
import os
import re
import tempfile
from pathlib import Path
from typing import Any, Literal

from dotenv import load_dotenv
from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from assessment_insights import answer as answer_insights
from assessment_loader import load_assessment
from assessment_store import (
    assessment_metadata,
    import_assessment,
    latest_assessment_id,
    list_assessments,
    load_finding_from_db,
)
from assessment_summary import load_findings
from assistant import detect_check_id, route_question
from check_catalog import CHECKS, canonical_check_id
from retrieve import answer as answer_check

load_dotenv()

DEFAULT_ORIGINS = (
    "http://localhost:3000",
    "http://127.0.0.1:3000",
)
configured_origins = tuple(
    origin.strip()
    for origin in os.getenv("TENANTIQ_ALLOWED_ORIGINS", "").split(",")
    if origin.strip()
)
ALLOWED_ORIGINS = configured_origins or DEFAULT_ORIGINS

MAX_UPLOAD_BYTES = int(os.getenv("TENANTIQ_MAX_ASSESSMENT_UPLOAD_BYTES", str(20 * 1024 * 1024)))
ALLOWED_UPLOAD_SUFFIXES = {".csv", ".json"}
ALLOWED_STATUSES = {"PASS", "FAIL", "WARNING", "INFO", "NOT EVALUATED", "NOT_EVALUATED", "SKIPPED", "ERROR"}
ALLOWED_SEVERITIES = {"CRITICAL", "HIGH", "MEDIUM", "LOW", "INFO", "NONE"}
CANONICAL_CHECK_IDS = {item.check_id for item in CHECKS}
CANONICAL_WORKLOADS = {item.workload for item in CHECKS}
MIN_CANONICAL_RATIO = float(os.getenv("TENANTIQ_UPLOAD_MIN_CANONICAL_RATIO", "0.6"))
CHECK_ID_PATTERN = re.compile(r"\b(?:ENTRA|EXO|SPO|TEAMS|ONEDRIVE|INTUNE|DEFENDER|PUR)-[A-Z0-9]+-\d{3}\b", re.IGNORECASE)

app = FastAPI(
    title="TenantIQ Knowledge Assistant API",
    version="1.5.0",
    description="Read-only API for grounded TenantIQ Microsoft 365 assessment questions.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=list(ALLOWED_ORIGINS),
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type"],
)


class AskRequest(BaseModel):
    question: str = Field(min_length=1, max_length=4000)
    assessment_id: str | None = None
    check_id: str | None = None


class AskResponse(BaseModel):
    assessment_id: str
    route: Literal["specific_finding", "tenant_wide"]
    check_id: str | None = None
    answer: str
    finding_count: int = 0
    check_ids: list[str] = Field(default_factory=list)
    sources: list[str] = Field(default_factory=list)


class HealthResponse(BaseModel):
    status: Literal["ok"]
    service: str
    version: str


class RootResponse(BaseModel):
    service: str
    version: str
    status: Literal["ok"]
    health: str
    docs: str
    ask: str
    assessments: str
    latest_assessment: str
    upload_assessment: str


class AssessmentSummary(BaseModel):
    assessment_id: str
    source_name: str | None = None
    imported_at: str | None = None
    finding_count: int
    metadata: dict[str, Any] = Field(default_factory=dict)


class AssessmentUploadResponse(AssessmentSummary):
    imported: Literal[True] = True


def _normalized_status(value: Any) -> str:
    return str(value or "").strip().upper().replace("_", " ")


def _normalized_severity(value: Any) -> str:
    return str(value or "").strip().upper()


def _answer_sources(answer: str) -> list[str]:
    match = re.search(r"(?:^|\n)Sources\s*\n(?P<body>.*)$", answer, flags=re.IGNORECASE | re.DOTALL)
    if not match:
        return []
    sources: list[str] = []
    for raw_line in match.group("body").splitlines():
        source = raw_line.strip().lstrip("-•").strip()
        if source and source not in sources:
            sources.append(source)
    return sources


def _answer_check_ids(answer: str, finding_check_ids: set[str]) -> list[str]:
    check_ids: list[str] = []
    for candidate in CHECK_ID_PATTERN.findall(answer):
        normalized = candidate.upper()
        if normalized in finding_check_ids and normalized not in check_ids:
            check_ids.append(normalized)
    return check_ids


def _assessment_evidence(assessment_id: str, answer: str, explicit_check_id: str | None = None) -> tuple[int, list[str], list[str]]:
    findings = load_findings(assessment_id)
    finding_check_ids = {
        str(finding.get("check_id") or "").strip().upper()
        for finding in findings
        if finding.get("check_id")
    }
    check_ids = _answer_check_ids(answer, finding_check_ids)
    if explicit_check_id:
        normalized = explicit_check_id.upper()
        if normalized in finding_check_ids and normalized not in check_ids:
            check_ids.insert(0, normalized)
    return len(findings), check_ids, _answer_sources(answer)


def _validate_tenantiq_assessment(path: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    try:
        findings = load_assessment(str(path), follow_portfolio=False)
    except (SystemExit, json.JSONDecodeError, UnicodeDecodeError) as exc:
        raise HTTPException(status_code=400, detail=f"Invalid TenantIQ assessment format: {exc}") from exc

    if not findings:
        raise HTTPException(status_code=400, detail="Uploaded file does not contain any TenantIQ assessment findings.")
    if len(findings) > 5000:
        raise HTTPException(status_code=400, detail="Uploaded assessment contains an unexpected number of findings.")

    canonical_count = 0
    invalid_statuses: set[str] = set()
    invalid_severities: set[str] = set()
    unknown_workloads: set[str] = set()
    missing_core_fields = 0

    for finding in findings:
        check_id = str(finding.get("check_id") or "").strip()
        workload = str(finding.get("workload") or "").strip()
        title = str(finding.get("title") or "").strip()
        status = _normalized_status(finding.get("status"))
        severity = _normalized_severity(finding.get("severity"))

        canonical = canonical_check_id(check_id) if check_id else None
        if canonical and canonical in CANONICAL_CHECK_IDS:
            canonical_count += 1

        if not title or not status or not (check_id or canonical):
            missing_core_fields += 1

        if status and status not in {item.replace("_", " ") for item in ALLOWED_STATUSES}:
            invalid_statuses.add(status)
        if severity and severity not in ALLOWED_SEVERITIES:
            invalid_severities.add(severity)
        if workload and workload not in CANONICAL_WORKLOADS:
            unknown_workloads.add(workload)

    canonical_ratio = canonical_count / len(findings)
    if canonical_count == 0:
        raise HTTPException(
            status_code=400,
            detail="This file is not a recognized TenantIQ assessment. No canonical TenantIQ check IDs were found.",
        )
    if canonical_ratio < MIN_CANONICAL_RATIO:
        raise HTTPException(
            status_code=400,
            detail=(
                "This file does not look like a valid TenantIQ assessment. "
                f"Only {canonical_count} of {len(findings)} findings mapped to TenantIQ checks."
            ),
        )
    if missing_core_fields > max(3, int(len(findings) * 0.1)):
        raise HTTPException(
            status_code=400,
            detail="This file is missing required TenantIQ finding fields such as check ID, title, or status.",
        )
    if invalid_statuses:
        raise HTTPException(
            status_code=400,
            detail="Unsupported TenantIQ status value(s): " + ", ".join(sorted(invalid_statuses)[:8]),
        )
    if invalid_severities:
        raise HTTPException(
            status_code=400,
            detail="Unsupported TenantIQ severity value(s): " + ", ".join(sorted(invalid_severities)[:8]),
        )
    if unknown_workloads:
        raise HTTPException(
            status_code=400,
            detail="Unsupported TenantIQ workload value(s): " + ", ".join(sorted(unknown_workloads)[:8]),
        )

    return findings, {
        "validated": True,
        "canonical_findings": canonical_count,
        "canonical_ratio": round(canonical_ratio, 4),
    }


@app.get("/", response_model=RootResponse)
def root() -> RootResponse:
    return RootResponse(
        service="TenantIQ Knowledge Assistant API",
        version="1.5.0",
        status="ok",
        health="/health",
        docs="/docs",
        ask="POST /ask",
        assessments="/assessments",
        latest_assessment="/assessments/latest",
        upload_assessment="POST /assessments/upload",
    )


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok", service="tenantiq-rag", version="1.5.0")


@app.get("/assessments", response_model=list[AssessmentSummary])
def assessments(limit: int = Query(default=25, ge=1, le=100)) -> list[AssessmentSummary]:
    return [AssessmentSummary(**item) for item in list_assessments(limit=limit)]


@app.get("/assessments/latest", response_model=AssessmentSummary)
def latest_assessment() -> AssessmentSummary:
    assessment_id = latest_assessment_id()
    if not assessment_id:
        raise HTTPException(status_code=404, detail="No TenantIQ assessments are stored in PostgreSQL yet.")
    item = assessment_metadata(assessment_id)
    if not item:
        raise HTTPException(status_code=404, detail="Latest TenantIQ assessment could not be loaded.")
    return AssessmentSummary(**item)


@app.post("/assessments/upload", response_model=AssessmentUploadResponse)
async def upload_assessment(file: UploadFile = File(...)) -> AssessmentUploadResponse:
    original_name = Path(file.filename or "assessment.csv").name
    suffix = Path(original_name).suffix.lower()
    if suffix not in ALLOWED_UPLOAD_SUFFIXES:
        raise HTTPException(status_code=400, detail="TenantIQ assessment uploads must be CSV or JSON files.")

    contents = await file.read(MAX_UPLOAD_BYTES + 1)
    if not contents:
        raise HTTPException(status_code=400, detail="Uploaded assessment file is empty.")
    if len(contents) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="Uploaded assessment file exceeds the TenantIQ size limit.")

    temp_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(prefix="tenantiq-upload-", suffix=suffix, delete=False) as handle:
            handle.write(contents)
            temp_path = Path(handle.name)

        _, validation_metadata = _validate_tenantiq_assessment(temp_path)
        stored_metadata = {
            **validation_metadata,
            "original_filename": original_name,
        }
        assessment_id, finding_count = import_assessment(str(temp_path), metadata=stored_metadata)
        item = assessment_metadata(assessment_id)
        if not item:
            raise RuntimeError("Imported TenantIQ assessment metadata could not be loaded.")
        item["finding_count"] = finding_count
        return AssessmentUploadResponse(**item)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"TenantIQ could not import this assessment: {exc}") from exc
    finally:
        if temp_path:
            temp_path.unlink(missing_ok=True)


@app.post("/ask", response_model=AskResponse)
def ask(request: AskRequest) -> AskResponse:
    question = request.question.strip()
    assessment_id = request.assessment_id or latest_assessment_id()
    if not assessment_id:
        raise HTTPException(status_code=409, detail="No TenantIQ assessments are stored in PostgreSQL yet.")

    route, detected_check_id = route_question(question, explicit_check_id=request.check_id)

    if route == "check":
        check_id = detected_check_id or detect_check_id(question)
        if not check_id:
            raise HTTPException(status_code=400, detail="A specific-finding request requires a check ID.")

        finding = load_finding_from_db(assessment_id, check_id)
        if not finding:
            raise HTTPException(
                status_code=404,
                detail=f"Finding not found for assessment {assessment_id} and check {check_id}.",
            )

        result = answer_check(question, check_id=check_id, finding=finding)
        finding_count, check_ids, sources = _assessment_evidence(assessment_id, result, explicit_check_id=check_id)
        return AskResponse(
            assessment_id=assessment_id,
            route="specific_finding",
            check_id=check_id,
            answer=result,
            finding_count=finding_count,
            check_ids=check_ids,
            sources=sources,
        )

    result = answer_insights(question, assessment_id, progress=None)
    finding_count, check_ids, sources = _assessment_evidence(assessment_id, result)
    return AskResponse(
        assessment_id=assessment_id,
        route="tenant_wide",
        check_id=None,
        answer=result,
        finding_count=finding_count,
        check_ids=check_ids,
        sources=sources,
    )


if __name__ == "__main__":
    import uvicorn

    host = os.getenv("TENANTIQ_API_HOST", "127.0.0.1")
    port = int(os.getenv("PORT") or os.getenv("TENANTIQ_API_PORT", "8787"))
    uvicorn.run("api:app", host=host, port=port, reload=False)
