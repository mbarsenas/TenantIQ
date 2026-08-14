from __future__ import annotations

import os
import tempfile
from pathlib import Path
from typing import Any, Literal

from dotenv import load_dotenv
from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from assessment_insights import answer as answer_insights
from assessment_store import (
    assessment_metadata,
    import_assessment,
    latest_assessment_id,
    list_assessments,
    load_finding_from_db,
)
from assistant import detect_check_id, route_question
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

app = FastAPI(
    title="TenantIQ Knowledge Assistant API",
    version="1.3.0",
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


@app.get("/", response_model=RootResponse)
def root() -> RootResponse:
    return RootResponse(
        service="TenantIQ Knowledge Assistant API",
        version="1.3.0",
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
    return HealthResponse(status="ok", service="tenantiq-rag", version="1.3.0")


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

        assessment_id, finding_count = import_assessment(str(temp_path))
        item = assessment_metadata(assessment_id)
        if not item:
            raise RuntimeError("Imported TenantIQ assessment metadata could not be loaded.")

        # Preserve the customer's original filename instead of the temporary server filename.
        item["source_name"] = original_name
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
        return AskResponse(
            assessment_id=assessment_id,
            route="specific_finding",
            check_id=check_id,
            answer=result,
        )

    result = answer_insights(question, assessment_id, progress=None)
    return AskResponse(
        assessment_id=assessment_id,
        route="tenant_wide",
        check_id=None,
        answer=result,
    )


if __name__ == "__main__":
    import uvicorn

    host = os.getenv("TENANTIQ_API_HOST", "127.0.0.1")
    port = int(os.getenv("PORT") or os.getenv("TENANTIQ_API_PORT", "8787"))
    uvicorn.run("api:app", host=host, port=port, reload=False)
