from __future__ import annotations

import os
from typing import Literal

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from assessment_insights import answer as answer_insights
from assessment_store import latest_assessment_id, load_finding_from_db
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

app = FastAPI(
    title="TenantIQ Knowledge Assistant API",
    version="1.1.0",
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


@app.get("/", response_model=RootResponse)
def root() -> RootResponse:
    return RootResponse(
        service="TenantIQ Knowledge Assistant API",
        version="1.1.0",
        status="ok",
        health="/health",
        docs="/docs",
        ask="POST /ask",
    )


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok", service="tenantiq-rag", version="1.1.0")


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
    port = int(os.getenv("TENANTIQ_API_PORT", "8787"))
    uvicorn.run("api:app", host=host, port=port, reload=False)
