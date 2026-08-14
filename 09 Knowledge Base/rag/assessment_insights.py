from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import threading
import time
from typing import Any, Callable

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


class ConsoleProgress:
    def __init__(self, label: str = "TenantIQ insights") -> None:
        self.label = label
        self._stop = threading.Event()
        self._thread: threading.Thread | None = None
        self._phase = "Starting"
        self._percent = 0
        self._lock = threading.Lock()
        self._last_render_width = 0
        self._windows_console = os.name == "nt" and sys.stdout.isatty()
        self._kernel32 = None
        self._stdout_handle = None
        self._default_attributes = None
        self._init_windows_console()

    def _init_windows_console(self) -> None:
        if not self._windows_console:
            return
        try:
            import ctypes

            self._kernel32 = ctypes.windll.kernel32
            self._stdout_handle = self._kernel32.GetStdHandle(-11)

            class CONSOLE_SCREEN_BUFFER_INFO(ctypes.Structure):
                _fields_ = [
                    ("dwSize", ctypes.c_short * 2),
                    ("dwCursorPosition", ctypes.c_short * 2),
                    ("wAttributes", ctypes.c_ushort),
                    ("srWindow", ctypes.c_short * 4),
                    ("dwMaximumWindowSize", ctypes.c_short * 2),
                ]

            info = CONSOLE_SCREEN_BUFFER_INFO()
            if self._kernel32.GetConsoleScreenBufferInfo(self._stdout_handle, ctypes.byref(info)):
                self._default_attributes = int(info.wAttributes)
        except Exception:
            self._kernel32 = None
            self._stdout_handle = None
            self._default_attributes = None

    def _set_color(self, color: str) -> None:
        if not self._windows_console or not self._kernel32 or self._stdout_handle is None:
            return
        attributes = {
            "yellow": 14,
            "green": 10,
            "red": 12,
        }.get(color)
        if attributes is not None:
            self._kernel32.SetConsoleTextAttribute(self._stdout_handle, attributes)

    def _reset_color(self) -> None:
        if (
            self._windows_console
            and self._kernel32
            and self._stdout_handle is not None
            and self._default_attributes is not None
        ):
            self._kernel32.SetConsoleTextAttribute(
                self._stdout_handle,
                self._default_attributes,
            )

    def start(self) -> None:
        if not sys.stdout.isatty():
            print(f"{self.label}: starting...")
            return
        self._thread = threading.Thread(target=self._animate, daemon=True)
        self._thread.start()

    def update(self, phase: str, percent: int) -> None:
        with self._lock:
            self._phase = phase
            self._percent = max(0, min(100, percent))
        if not sys.stdout.isatty():
            print(f"{self.label}: {self._percent:3d}% - {self._phase}")

    def finish(self, phase: str = "Complete") -> None:
        with self._lock:
            self._phase = phase
            self._percent = 100
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=1)
        if sys.stdout.isatty():
            self._render(final=True)
            print()
        else:
            print(f"{self.label}: 100% - {self._phase}")

    def _animate(self) -> None:
        while not self._stop.is_set():
            self._render()
            time.sleep(0.15)

    def _render(self, final: bool = False) -> None:
        with self._lock:
            percent = self._percent
            phase = self._phase

        terminal_width = shutil.get_terminal_size(fallback=(120, 20)).columns
        bar_width = 28
        filled = int(bar_width * percent / 100)
        if percent < 100 and filled < bar_width:
            bar = "=" * filled + ">" + " " * max(0, bar_width - filled - 1)
        else:
            bar = "=" * bar_width

        prefix = f"{self.label}: [{bar}] {percent:3d}%  "
        max_phase_width = max(8, terminal_width - len(prefix) - 1)
        display_phase = phase
        if len(display_phase) > max_phase_width:
            display_phase = display_phase[: max(5, max_phase_width - 3)] + "..."

        line = prefix + display_phase
        padded_width = max(self._last_render_width, len(line))
        padded_line = line.ljust(padded_width)
        self._last_render_width = len(line)

        color = "red" if final and phase == "Failed" else "green" if final else "yellow"

        # PowerShell/Windows terminals can display raw ANSI escape sequences when
        # VT processing is disabled. Use native console attributes on Windows and
        # avoid embedding ANSI codes in the output entirely.
        self._set_color(color)
        print("\r" + (" " * padded_width) + "\r" + padded_line, end="", flush=True)
        self._reset_color()


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


def build_payload(
    assessment_id: str,
    progress: Callable[[str, int], None] | None = None,
) -> dict[str, Any]:
    if progress:
        progress("Loading stored findings", 10)
    findings = load_findings(assessment_id)
    if not findings:
        raise SystemExit(f"No findings stored for assessment {assessment_id}.")

    if progress:
        progress("Summarizing assessment", 20)
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
    total = max(1, len(priority_findings))
    for index, finding in enumerate(priority_findings, start=1):
        check_id = finding.get("check_id", "Unknown")
        percent = 25 + int((index / total) * 50)
        if progress:
            progress(f"Retrieving knowledge for {check_id} ({index}/{total})", percent)
        grounded_priority_findings.append(
            {
                "finding": finding,
                "knowledge_context": _knowledge_for_finding(finding),
            }
        )

    if progress:
        progress("Preparing grounded prompt", 80)
    return {
        "assessment_id": assessment_id,
        "finding_count": summary.get("finding_count", 0),
        "status_counts": summary.get("status_counts", {}),
        "severity_counts": summary.get("severity_counts", {}),
        "workloads": summary.get("workloads", {}),
        "priority_findings": grounded_priority_findings,
    }


def answer(
    question: str,
    assessment_id: str,
    progress: Callable[[str, int], None] | None = None,
) -> str:
    payload = build_payload(assessment_id, progress=progress)
    if progress:
        progress("Generating TenantIQ insights", 90)
    response = client.responses.create(
        model=CHAT_MODEL,
        instructions=SYSTEM_PROMPT,
        input=(
            "Stored TenantIQ assessment summary, finding evidence, and grounded knowledge:\n\n"
            + json.dumps(payload, indent=2, default=str)
            + f"\n\nUser question:\n{question}"
        ),
    )
    if progress:
        progress("Finalizing response", 98)
    return response.output_text


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Ask tenant-wide questions against a stored TenantIQ assessment."
    )
    parser.add_argument("question")
    parser.add_argument("--assessment-id", default=None)
    parser.add_argument("--latest-stored-assessment", action="store_true")
    parser.add_argument(
        "--no-progress",
        action="store_true",
        help="Disable the console progress bar.",
    )
    args = parser.parse_args()

    if args.assessment_id and args.latest_stored_assessment:
        raise SystemExit("Use either --assessment-id or --latest-stored-assessment, not both.")

    assessment_id = args.assessment_id
    if args.latest_stored_assessment or not assessment_id:
        assessment_id = latest_assessment_id()
        if not assessment_id:
            raise SystemExit("No TenantIQ assessments are stored in PostgreSQL yet.")
        print(f"Using latest stored assessment: {assessment_id}")

    progress = None if args.no_progress else ConsoleProgress()
    if progress:
        progress.start()

    try:
        result = answer(
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
