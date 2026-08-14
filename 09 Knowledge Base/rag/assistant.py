from __future__ import annotations

import argparse
import re
from typing import Optional

from assessment_insights import ConsoleProgress, answer as answer_insights
from assessment_store import latest_assessment_id, load_finding_from_db
from retrieve import answer as answer_check

CHECK_ID_PATTERN = re.compile(r"\b([A-Z]{2,10}-[A-Z0-9]+(?:-[A-Z0-9]+)+)\b", re.IGNORECASE)
TENANT_WIDE_HINTS = (
    "biggest problem",
    "biggest risk",
    "top risk",
    "what should be fixed first",
    "prioritize",
    "priority",
    "tenant-wide",
    "tenant wide",
    "overall tenant",
    "overall risk",
    "summary",
    "summarize the tenant",
    "health of this tenant",
)


def detect_check_id(question: str) -> Optional[str]:
    match = CHECK_ID_PATTERN.search(question)
    return match.group(1).upper() if match else None


def is_tenant_wide_question(question: str) -> bool:
    lowered = question.lower()
    return any(hint in lowered for hint in TENANT_WIDE_HINTS)


def route_question(question: str, explicit_check_id: str | None = None) -> tuple[str, str | None]:
    check_id = explicit_check_id or detect_check_id(question)
    if check_id:
        return "check", check_id
    if is_tenant_wide_question(question):
        return "tenant", None
    return "tenant", None


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Unified TenantIQ assessment assistant."
    )
    parser.add_argument("question")
    parser.add_argument("--check-id", default=None)
    parser.add_argument("--assessment-id", default=None)
    parser.add_argument("--no-progress", action="store_true")
    args = parser.parse_args()

    assessment_id = args.assessment_id or latest_assessment_id()
    if not assessment_id:
        raise SystemExit("No TenantIQ assessments are stored in PostgreSQL yet.")

    route, check_id = route_question(args.question, explicit_check_id=args.check_id)
    print(f"Using stored assessment: {assessment_id}")
    print(f"TenantIQ route: {'specific finding' if route == 'check' else 'tenant-wide insights'}")

    if route == "check":
        assert check_id is not None
        finding = load_finding_from_db(assessment_id, check_id)
        if not finding:
            raise SystemExit(
                f"Finding not found in PostgreSQL for assessment {assessment_id} and check {check_id}."
            )
        print(answer_check(args.question, check_id=check_id, finding=finding))
        return

    progress = None if args.no_progress else ConsoleProgress(label="TenantIQ assistant")
    if progress:
        progress.start()

    try:
        result = answer_insights(
            args.question,
            assessment_id,
            progress=progress.update if progress else None,
        )
    except Exception:
        if progress:
            progress.finish("Failed")
        raise

    if progress:
        progress.finish()
    print(result)


if __name__ == "__main__":
    main()
