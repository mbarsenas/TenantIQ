from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
import threading
import time
from typing import Any, Callable

import psycopg
from dotenv import load_dotenv
from openai import OpenAI

from assessment_store import latest_assessment_id
from assessment_summary import load_findings, summarize
from retrieve import retrieve

load_dotenv()

CHAT_MODEL = os.getenv("OPENAI_CHAT_MODEL", "gpt-5")
DATABASE_URL = os.environ["DATABASE_URL"]
client = OpenAI()

SYSTEM_PROMPT = """You are the TenantIQ Microsoft 365 assessment assistant.
Use only the supplied stored TenantIQ assessment summary, tenant finding evidence, and TenantIQ knowledge context.
Your job is to identify the most important tenant-wide risks, explain why they matter, and recommend a prioritized remediation sequence.

Grounding rules:
- Never invent counts, settings, identities, domains, dates, policies, attack paths, commands, portal locations, or configuration details.
- Every tenant-specific claim must be traceable to the supplied finding evidence.
- Do not claim a remediation was executed or completed.
- If a requested detail is not present in finding evidence or grounded TenantIQ knowledge, explicitly say it is not available from the assessment.
- Prefer the exact recommendation from the TenantIQ finding when one exists.
- Only include Microsoft 365 admin locations, PowerShell commands, or implementation steps when they are explicitly supported by the supplied TenantIQ knowledge context.

Evidence rules:
- The Evidence line MUST use the finding.evidence value when it is present. Do not replace concrete evidence with a generic sentence such as 'the assessment marks this check as FAIL'.
- Preserve useful counts, enabled/disabled states, policy values, protocol states, and affected-object details exactly as supplied in finding.evidence.
- Tightly paraphrase only for readability; never discard a concrete count or configuration state that materially explains why the check fired.
- If finding.evidence is absent, say 'No detailed evidence was supplied for this finding.' Do not manufacture evidence from the title, status, or severity.

Validation rules:
- First look for explicit validation or verification guidance in the grounded TenantIQ knowledge context.
- When explicit validation guidance exists, provide the concrete supported verification step.
- When it does not exist, do not invent a portal path, command, expected value, or implementation procedure.
- It is always acceptable to recommend rerunning the same TenantIQ assessment/check after an approved remediation and confirming that the finding no longer reports the same risk state.

For tenant-wide prioritization questions, use this response structure:
Executive summary
- State how many findings were reviewed and summarize the FAIL/WARNING/High-severity posture when provided.

Priority findings
For each of the top findings, provide:
1. <Check ID> — <Title> (<Status>, <Severity>)
   Evidence: surface the concrete tenant-specific finding.evidence, retaining material counts and configuration states.
   Why it matters: explain the operational/security/compliance impact, grounded in the finding or TenantIQ knowledge.
   Recommended remediation: state the supported remediation action.
   Validation: give supported validation guidance; otherwise recommend rerunning the same TenantIQ control after remediation and confirming the risk state changed.

Recommended order of operations
- Give a short prioritized sequence and explain dependencies only when supported.

Important:
- Keep the answer operational and concise, but retain exact Check IDs and concrete assessment evidence.
- Do not treat INFO or PASS findings as problems unless the user asks about them.
- Do not convert a WARNING into a FAIL or change a severity.
- Do not manufacture affected-object names. If evidence only provides counts, use the counts.
- Include a short Sources section listing only TenantIQ knowledge source paths that appear in the supplied grounded knowledge context.
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
        self._phase_started = time.monotonic()
        self._init_windows_console()

    def _init_windows_console(self) -> None:
        if not self._windows_console:
            return
        try:
            import ctypes
            self._kernel32 = ctypes.windll.kernel32
            self._stdout_handle = self._kernel32.GetStdHandle(-11)
            class CONSOLE_SCREEN_BUFFER_INFO(ctypes.Structure):
                _fields_ = [("dwSize", ctypes.c_short * 2),("dwCursorPosition", ctypes.c_short * 2),("wAttributes", ctypes.c_ushort),("srWindow", ctypes.c_short * 4),("dwMaximumWindowSize", ctypes.c_short * 2)]
            info = CONSOLE_SCREEN_BUFFER_INFO()
            if self._kernel32.GetConsoleScreenBufferInfo(self._stdout_handle, ctypes.byref(info)):
                self._default_attributes = int(info.wAttributes)
        except Exception:
            self._kernel32 = self._stdout_handle = self._default_attributes = None

    def _set_color(self, color: str) -> None:
        if not self._windows_console or not self._kernel32 or self._stdout_handle is None: return
        attributes = {"yellow": 14, "green": 10, "red": 12}.get(color)
        if attributes is not None: self._kernel32.SetConsoleTextAttribute(self._stdout_handle, attributes)

    def _reset_color(self) -> None:
        if self._windows_console and self._kernel32 and self._stdout_handle is not None and self._default_attributes is not None:
            self._kernel32.SetConsoleTextAttribute(self._stdout_handle, self._default_attributes)

    def start(self) -> None:
        if not sys.stdout.isatty(): print(f"{self.label}: starting..."); return
        self._thread = threading.Thread(target=self._animate, daemon=True); self._thread.start()

    def update(self, phase: str, percent: int) -> None:
        with self._lock:
            if phase != self._phase: self._phase_started = time.monotonic()
            self._phase = phase; self._percent = max(0, min(100, percent))
        if not sys.stdout.isatty(): print(f"{self.label}: {self._percent:3d}% - {self._phase}")

    def finish(self, phase: str = "Complete") -> None:
        with self._lock: self._phase = phase; self._percent = 100
        self._stop.set()
        if self._thread: self._thread.join(timeout=1)
        if sys.stdout.isatty(): self._render(final=True); print()
        else: print(f"{self.label}: 100% - {self._phase}")

    def _animate(self) -> None:
        while not self._stop.is_set(): self._render(); time.sleep(0.15)

    def _render(self, final: bool = False) -> None:
        with self._lock: percent, phase, phase_started = self._percent, self._phase, self._phase_started
        terminal_width = shutil.get_terminal_size(fallback=(120, 20)).columns; bar_width = 28; filled = int(bar_width * percent / 100)
        bar = "=" * filled + (">" + " " * max(0, bar_width-filled-1) if percent < 100 and filled < bar_width else "=" * max(0, bar_width-filled))
        elapsed = int(time.monotonic() - phase_started); phase_with_time = phase if final else f"{phase} ({elapsed}s)"
        prefix = f"{self.label}: [{bar}] {percent:3d}%  "; max_phase_width = max(8, terminal_width-len(prefix)-1); display_phase = phase_with_time
        if len(display_phase) > max_phase_width: display_phase = display_phase[:max(5,max_phase_width-3)] + "..."
        line = prefix + display_phase; padded_width = max(self._last_render_width, len(line)); padded_line = line.ljust(padded_width); self._last_render_width = len(line)
        color = "red" if final and phase == "Failed" else "green" if final else "yellow"; self._set_color(color); print("\r"+(" "*padded_width)+"\r"+padded_line,end="",flush=True); self._reset_color()


def _trim_text(value: Any, limit: int) -> Any:
    if not isinstance(value, str): return value
    text = value.strip()
    if len(text) <= limit: return text
    return text[:max(0,limit-3)].rstrip()+"..."


def _compact_finding(finding: dict[str, Any]) -> dict[str, Any]:
    keep = ("check_id","workload","category","status","severity","title","evidence","recommendation")
    compact: dict[str, Any] = {}
    for key in keep:
        if key not in finding or finding[key] in (None, ""): continue
        value = finding[key]
        if key == "evidence": value = _trim_text(value, 1400)
        elif key == "recommendation": value = _trim_text(value, 800)
        elif key == "title": value = _trim_text(value, 180)
        compact[key] = value
    return compact


def _knowledge_index_available() -> bool:
    try:
        with psycopg.connect(DATABASE_URL) as conn:
            row = conn.execute("SELECT to_regclass('public.tenantiq_knowledge_chunks')").fetchone()
            if not row or row[0] is None: return False
            count = conn.execute("SELECT COUNT(*) FROM tenantiq_knowledge_chunks").fetchone(); return bool(count and count[0])
    except Exception: return False


def _knowledge_for_finding(finding: dict[str, Any]) -> list[dict[str, Any]]:
    if not _knowledge_index_available(): return []
    check_id = str(finding.get("check_id", "")).strip()
    if not check_id: return []
    question = f"For TenantIQ check {check_id} ({finding.get('title','')}), provide risk, remediation, verification, validation, expected post-remediation state, and any supported Microsoft 365 administrative guidance."
    try:
        matches = retrieve(question, workload=str(finding.get("workload")) if finding.get("workload") else None, check_id=check_id, limit=3)
    except Exception: return []
    return [{"source_path": m.source_path, "workload": m.workload, "content": _trim_text(m.content, 2000)} for m in matches]


def _source_paths(payload: dict[str, Any]) -> list[str]:
    sources: list[str] = []
    for item in payload.get("priority_findings", []) or []:
        for knowledge in item.get("knowledge_context", []) or []:
            source_path = str(knowledge.get("source_path") or "").strip()
            if source_path and source_path not in sources: sources.append(source_path)
    return sources


def _append_sources(answer_text: str, payload: dict[str, Any]) -> str:
    sources = _source_paths(payload)
    if not sources: return answer_text.rstrip()
    if "\nsources\n" in f"\n{answer_text.lower()}\n": return answer_text.rstrip()
    return answer_text.rstrip()+"\n\nSources\n"+"\n".join(f"- {s}" for s in sources)


def build_payload(assessment_id: str, progress: Callable[[str, int], None] | None = None) -> dict[str, Any]:
    if progress: progress("Loading stored findings",10)
    findings = load_findings(assessment_id)
    if not findings: raise RuntimeError(f"No findings stored for assessment {assessment_id}.")
    if progress: progress("Summarizing assessment",20)
    summary = summarize(findings)
    priority_ids = {str(item.get("check_id")) for item in summary.get("priority_findings",[]) if item.get("check_id")}
    priority_findings = [f for f in findings if str(f.get("check_id")) in priority_ids]
    grounded = []; total = max(1,len(priority_findings))
    for index,finding in enumerate(priority_findings,start=1):
        check_id = finding.get("check_id","Unknown"); percent = 25+int((index/total)*50)
        if progress: progress(f"Retrieving knowledge for {check_id} ({index}/{total})",percent)
        grounded.append({"finding":_compact_finding(finding),"knowledge_context":_knowledge_for_finding(finding)})
    if progress: progress("Preparing compact grounded prompt",80)
    return {"assessment_id":assessment_id,"finding_count":summary.get("finding_count",0),"status_counts":summary.get("status_counts",{}),"severity_counts":summary.get("severity_counts",{}),"workloads":summary.get("workloads",{}),"priority_findings":grounded}


def _deterministic_answer(payload: dict[str, Any]) -> str:
    finding_count=payload.get("finding_count",0); status_counts=payload.get("status_counts",{}) or {}; severity_counts=payload.get("severity_counts",{}) or {}; priority_findings=payload.get("priority_findings",[]) or []
    fail_count=status_counts.get("FAIL",0); warning_count=status_counts.get("WARNING",0); high_count=severity_counts.get("High",0) or severity_counts.get("HIGH",0)
    lines=["Executive summary","",f"TenantIQ reviewed {finding_count} findings. Current risk posture: {fail_count} FAIL, {warning_count} WARNING, {high_count} High-severity findings."]
    if priority_findings:
        lines.extend(["","Priority findings"])
        for index,item in enumerate(priority_findings[:5],start=1):
            finding=item.get("finding",{}) or {}; check_id=finding.get("check_id","Unknown"); title=finding.get("title") or "Untitled finding"; status=finding.get("status") or "Unknown"; severity=finding.get("severity") or "Unknown"
            lines.extend(["",f"{index}. {check_id} — {title} ({status}, {severity})"])
            evidence=finding.get("evidence")
            lines.append(f"Evidence: {_trim_text(evidence,900)}" if evidence else "Evidence: No detailed evidence was supplied for this finding.")
            recommendation=finding.get("recommendation")
            if recommendation: lines.append(f"Recommended remediation: {_trim_text(recommendation,600)}")
            lines.append(f"Validation: After the approved remediation, rerun TenantIQ check {check_id} and confirm it no longer reports the same risk state. Use any additional verification steps documented in the TenantIQ knowledge source for this control.")
    lines.extend(["","Recommended order of operations","","Address High-severity FAIL findings first, then High-severity WARNING findings, followed by remaining FAIL/WARNING findings based on business impact and supported change dependencies. Preserve change control and rerun TenantIQ after remediation to validate the resulting state."])
    return _append_sources("\n".join(lines),payload)


def _responses_answer(user_input: str) -> str:
    response=client.responses.create(model=CHAT_MODEL,instructions=SYSTEM_PROMPT,input=user_input,max_output_tokens=3400)
    direct=getattr(response,"output_text",None)
    if isinstance(direct,str) and direct.strip(): return direct.strip()
    parts=[]
    for item in getattr(response,"output",None) or []:
        for block in getattr(item,"content",None) or []:
            text=getattr(block,"text",None)
            if isinstance(text,str) and text.strip(): parts.append(text.strip()); continue
            value=getattr(text,"value",None) if text is not None else None
            if isinstance(value,str) and value.strip(): parts.append(value.strip())
    return "\n\n".join(parts).strip()


def answer(question: str, assessment_id: str, progress: Callable[[str,int],None] | None=None) -> str:
    payload=build_payload(assessment_id,progress=progress)
    if progress: progress("Generating TenantIQ insights",90)
    user_input="Stored TenantIQ assessment summary, finding evidence, and grounded knowledge:\n\n"+json.dumps(payload,separators=(",",":"),default=str)+f"\n\nUser question:\n{question}"
    try:
        content=_responses_answer(user_input)
        if content:
            if progress: progress("Finalizing response",98)
            return _append_sources(content,payload)
    except Exception: pass
    if progress: progress("Using deterministic grounded summary",98)
    return _deterministic_answer(payload)


def main() -> None:
    parser=argparse.ArgumentParser(description="Ask tenant-wide questions against a stored TenantIQ assessment.")
    parser.add_argument("question"); parser.add_argument("--assessment-id",default=None); parser.add_argument("--latest-stored-assessment",action="store_true"); parser.add_argument("--no-progress",action="store_true",help="Disable the console progress bar."); args=parser.parse_args()
    if args.assessment_id and args.latest_stored_assessment: raise SystemExit("Use either --assessment-id or --latest-stored-assessment, not both.")
    assessment_id=args.assessment_id
    if args.latest_stored_assessment or not assessment_id:
        assessment_id=latest_assessment_id()
        if not assessment_id: raise SystemExit("No TenantIQ assessments are stored in PostgreSQL yet.")
        print(f"Using latest stored assessment: {assessment_id}")
    progress=None if args.no_progress else ConsoleProgress()
    if progress: progress.start()
    try: result=answer(args.question,assessment_id,progress=progress.update if progress else None)
    except Exception:
        if progress: progress.finish("Failed")
        raise
    if progress: progress.finish()
    print(result)


if __name__ == "__main__": main()
