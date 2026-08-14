from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from assessment_loader import load_assessment, select_finding
from retrieve import answer, retrieve


@dataclass
class EvaluationCase:
    name: str
    question: str
    check_id: str | None = None
    workload: str | None = None
    assessment_file: str | None = None
    finding_file: str | None = None
    must_contain: list[str] | None = None
    must_not_contain: list[str] | None = None
    expect_grounded_refusal: bool = False


def _load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise SystemExit(f"Evaluation file is not valid JSON: {exc}") from exc


def load_cases(path: str) -> list[EvaluationCase]:
    source = Path(path)
    if not source.exists():
        raise SystemExit(f"Evaluation file not found: {source}")

    data = _load_json(source)
    if not isinstance(data, list):
        raise SystemExit("Evaluation file must contain a JSON array.")

    cases: list[EvaluationCase] = []
    for index, item in enumerate(data, start=1):
        if not isinstance(item, dict):
            raise SystemExit(f"Evaluation case {index} must be a JSON object.")
        if not item.get("question"):
            raise SystemExit(f"Evaluation case {index} is missing question.")

        cases.append(
            EvaluationCase(
                name=str(item.get("name") or f"case-{index}"),
                question=str(item["question"]),
                check_id=item.get("check_id"),
                workload=item.get("workload"),
                assessment_file=item.get("assessment_file"),
                finding_file=item.get("finding_file"),
                must_contain=list(item.get("must_contain") or []),
                must_not_contain=list(item.get("must_not_contain") or []),
                expect_grounded_refusal=bool(item.get("expect_grounded_refusal", False)),
            )
        )
    return cases


def load_finding_file(path: str | None) -> dict[str, Any] | None:
    if not path:
        return None
    source = Path(path)
    if not source.exists():
        raise SystemExit(f"Finding file not found: {source}")
    data = _load_json(source)
    if not isinstance(data, dict):
        raise SystemExit(f"Finding file must contain a JSON object: {source}")
    return data


def resolve_finding(case: EvaluationCase) -> dict[str, Any] | None:
    if case.finding_file and case.assessment_file:
        raise SystemExit(f"{case.name}: use finding_file or assessment_file, not both.")

    if case.finding_file:
        return load_finding_file(case.finding_file)

    if case.assessment_file:
        if not case.check_id:
            raise SystemExit(f"{case.name}: assessment_file requires check_id.")
        return select_finding(load_assessment(case.assessment_file), case.check_id)

    return None


def run_case(case: EvaluationCase) -> dict[str, Any]:
    finding = resolve_finding(case)
    matches = retrieve(case.question, workload=case.workload, check_id=case.check_id)
    response = answer(
        case.question,
        workload=case.workload,
        check_id=case.check_id,
        finding=finding,
    )

    response_lower = response.lower()
    failures: list[str] = []

    if case.expect_grounded_refusal:
        expected = "TenantIQ does not have enough grounded information"
        if expected.lower() not in response_lower:
            failures.append("expected grounded refusal")
    else:
        if not matches:
            failures.append("retrieval returned no matches")

    for phrase in case.must_contain or []:
        if phrase.lower() not in response_lower:
            failures.append(f"missing required phrase: {phrase}")

    for phrase in case.must_not_contain or []:
        if phrase.lower() in response_lower:
            failures.append(f"contained forbidden phrase: {phrase}")

    return {
        "name": case.name,
        "passed": not failures,
        "check_id": case.check_id,
        "workload": case.workload,
        "retrieval_count": len(matches),
        "sources": [match.source_path for match in matches],
        "failures": failures,
        "answer": response,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Run TenantIQ RAG grounding evaluations.")
    parser.add_argument(
        "--cases",
        default=str(Path(__file__).with_name("examples") / "rag-evaluation-cases.json"),
        help="Path to JSON evaluation cases.",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Optional path to write the full JSON evaluation report.",
    )
    args = parser.parse_args()

    cases = load_cases(args.cases)
    results = [run_case(case) for case in cases]

    passed = sum(1 for result in results if result["passed"])
    total = len(results)

    for result in results:
        status = "PASS" if result["passed"] else "FAIL"
        print(f"[{status}] {result['name']}")
        print(f"  retrieval_count: {result['retrieval_count']}")
        if result["sources"]:
            print(f"  sources: {', '.join(result['sources'])}")
        for failure in result["failures"]:
            print(f"  - {failure}")

    print(f"\nTenantIQ RAG evaluation: {passed}/{total} passed")

    if args.output:
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(
            json.dumps(
                {
                    "passed": passed,
                    "total": total,
                    "results": results,
                },
                indent=2,
            ),
            encoding="utf-8",
        )
        print(f"Report written to {output}")

    if passed != total:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
