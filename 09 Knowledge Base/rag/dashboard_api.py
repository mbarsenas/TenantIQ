from __future__ import annotations

from typing import Any

from fastapi import Header, HTTPException

from api import app, _customer_id
from assessment_store import assessment_metadata
from assessment_summary import load_findings, summarize


@app.get("/assessments/{assessment_id}/summary")
def assessment_posture_summary(
    assessment_id: str,
    x_tenantiq_customer_id: str | None = Header(default=None),
    x_tenantiq_identity_signature: str | None = Header(default=None),
) -> dict[str, Any]:
    customer = _customer_id(x_tenantiq_customer_id, x_tenantiq_identity_signature)
    item = assessment_metadata(assessment_id, customer_id=customer)
    if not item:
        raise HTTPException(status_code=404, detail="Assessment not found for this customer.")

    findings = load_findings(assessment_id)
    summary = summarize(findings)
    return {
        "assessment_id": assessment_id,
        "source_name": item.get("source_name"),
        "imported_at": item.get("imported_at"),
        "finding_count": summary.get("finding_count", 0),
        "status_counts": summary.get("status_counts", {}),
        "severity_counts": summary.get("severity_counts", {}),
        "workloads": summary.get("workloads", {}),
        "priority_findings": summary.get("priority_findings", []),
    }
