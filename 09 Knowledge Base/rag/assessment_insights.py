from __future__ import annotations

import argparse
import json
import os
from typing import Any

from dotenv import load_dotenv
from openai import OpenAI

from assessment_store import latest_assessment_id
from assessment_summary import load_findings, summarize
from retrieve import retrieve

load_dotenv()

CHAT_MODEL = os.getenv("OPENAI_CHAT_MODEL", "gpt-5")
client = OpenAI()

SYSTEM_PROMPT = """You are the TenantIQ Microsoft 365 assessment assistant.
Use only the supplied stored TenantIQ assessment summary, tenant finding evidence, and TenantIQ knowledge context.
Your job is to identify the most important tenant-wide risks, explain why they matter, and recommend a prioritized remediation sequence.
Do not invent missing counts, settings, identities, dates, policies, attack paths, or configuration details.
Do not claim to execute changes or that remediation has been performed.
Do not infer technical details that are not explicitly present in the finding evidence or TenantIQ knowledge context.
If evidence or knowledge is insufficient for a claim, say so.
Keep tenant-specific claims tied to the supplied findings.
Prefer remediation language already supported by the supplied TenantIQ knowledge.
Include a short Sources section listing the TenantIQ knowledge source paths actually used.
"""


def _knowledge_for_finding(finding: dict[str, Any]) -> list[dict[str, Any]]:
    check_id = str(finding.get("check_id", "")).strip()
    if not check_id:
        return []

    question = (
        f"Explain the risk and recommended remediation for TenantIQ check {check_id}: "
        f"{finding.get('title', '')}"
    )
    matches = retrieve(
        question,
        workload=str(finding.get("workload")) if finding.get("workload") else None,
        check_id=check_id,
        limit=3,
    )
    return [
        {
            "source_path": match.source_path,
            "workload": match.workload,
            "content": match.content,
        }
        for match in matches
    ]


def build_payload(assessment_id: str) -> dict[str, Any]:
    findings = load_findings(assessment_id)
    if not findings:
        raise SystemExit(f"No findings stored for assessment {assessment_id}.")

    summary = summarize(findings)
    priority_ids = {
        str(item.get("check_id"))
        for item in summary.get("priority_findings", [])
        if item.get("check_id")
    }
    priority_findings = [
        finding for finding in findings
        if str(finding.get("check_id")) in priority_ids
    ]

    grounded_priority_findings: list[dict[str, Any]] = []
    for finding in priority_findings:
        grounded_priority_findings.append(
            {
                "finding": finding,
                "knowledge_context": _knowledge_for_finding(finding),
            }
        )

    return {
        "assessment_id": assessment_id,
        "finding_count": summary.get("finding_count", 0),
        "status_counts": summary.get("status_counts", {}),
        "severity_counts": summary.get("severity_counts", {}),
        "workloads": summary.get("workloads", {}),
        "priority_findings": grounded_priority_findings,
    }


def answer(question: str, assessment_id: str) -> str:
    payload = build_payload(assessment_id)
    response = client.responses.create(
        model=CHAT_MODEL,
        instructions=SYSTEM_PROMPT,
        input=(
            "Stored TenantIQ assessment summary, finding evidence, and grounded knowledge:\n\n"
            + json.dumps(payload, indent=2, default=str)
            + f"\n\nUser question:\n{question}"
        ),
    )
    return response.output_text


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Ask tenant-wide questions against a stored TenantIQ assessment."
    )
    parser.add_argument("question")
    parser.add_argument("--assessment-id", default=None)
    parser.add_argument("--latest-stored-assessment", action="store_true")
    args = parser.parse_args()

    if args.assessment_id and args.latest_stored_assessment:
        raise SystemExit("Use either --assessment-id or --latest-stored-assessment, not both.")

    assessment_id = args.assessment_id
    if args.latest_stored_assessment or not assessment_id:
        assessment_id = latest_assessment_id()
        if not assessment_id:
            raise SystemExit("No TenantIQ assessments are stored in PostgreSQL yet.")
        print(f"Using latest stored assessment: {assessment_id}")

    print(answer(args.question, assessment_id))


if __name__ == "__main__":
    main()
