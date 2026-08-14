from __future__ import annotations

import argparse
import json
import os
from typing import Any

from dotenv import load_dotenv
from openai import OpenAI

from assessment_store import latest_assessment_id
from assessment_summary import load_findings, summarize

load_dotenv()

CHAT_MODEL = os.getenv("OPENAI_CHAT_MODEL", "gpt-5")
client = OpenAI()

SYSTEM_PROMPT = """You are the TenantIQ Microsoft 365 assessment assistant.
Use only the supplied stored TenantIQ assessment summary and finding evidence.
Your job is to identify the most important tenant-wide risks, explain why they matter, and recommend a prioritized remediation sequence.
Do not invent missing counts, settings, identities, dates, policies, or configuration details.
Do not claim to execute changes or that remediation has been performed.
If evidence is insufficient for a claim, say so.
Keep tenant-specific claims tied to the supplied findings.
"""


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

    return {
        "assessment_id": assessment_id,
        "finding_count": summary.get("finding_count", 0),
        "status_counts": summary.get("status_counts", {}),
        "severity_counts": summary.get("severity_counts", {}),
        "workloads": summary.get("workloads", {}),
        "priority_findings": priority_findings,
    }


def answer(question: str, assessment_id: str) -> str:
    payload = build_payload(assessment_id)
    response = client.responses.create(
        model=CHAT_MODEL,
        instructions=SYSTEM_PROMPT,
        input=(
            "Stored TenantIQ assessment summary and evidence:\n\n"
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
