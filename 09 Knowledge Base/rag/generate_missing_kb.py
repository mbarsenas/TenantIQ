from __future__ import annotations

import re
from pathlib import Path

from check_catalog import CHECKS

ROOT = Path(__file__).resolve().parents[2]
KB_ROOT = ROOT / "09 Knowledge Base" / "workloads"

WORKLOAD_DIR = {
    "Entra ID": "entra",
    "Exchange Online": "exchange",
    "SharePoint Online": "sharepoint",
    "Microsoft Teams": "teams",
    "OneDrive": "onedrive",
    "Microsoft Intune": "intune",
    "Microsoft Defender": "defender",
    "Microsoft Purview": "purview",
}

GENERIC_SEVERITY = "Medium"


def slugify(value: str) -> str:
    value = value.strip().lower()
    value = value.replace("microsoft 365", "m365")
    value = re.sub(r"[^a-z0-9]+", "-", value)
    return value.strip("-") or "tenant-check"


def title_for_check(check) -> str:
    if check.aliases:
        return check.aliases[0].strip().title()
    return check.check_id


def existing_check_ids() -> set[str]:
    ids: set[str] = set()
    for path in KB_ROOT.rglob("*.md"):
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            text = path.read_text(encoding="utf-8-sig")
        match = re.search(r"(?m)^check_id:\s*([^\s]+)\s*$", text)
        if match:
            ids.add(match.group(1).strip())
    return ids


def build_document(check) -> str:
    title = title_for_check(check)
    aliases = ", ".join(check.aliases[:4]) if check.aliases else title
    return f'''---
check_id: {check.check_id}
workload: {check.workload}
category: TenantIQ Assessment
severity: {GENERIC_SEVERITY}
content_type: finding-guidance
---

# {title}

TenantIQ uses **{check.check_id}** to assess **{title.lower()}** in {check.workload}. This guidance is intentionally evidence-bound: the assistant should explain only what the uploaded TenantIQ assessment actually observed and should not infer tenant configuration that is not present in the finding evidence.

## What this check represents

This check evaluates the TenantIQ control represented by: {aliases}.

A FAIL or WARNING means the observed configuration, coverage, inventory, or governance state requires review against the organization's approved Microsoft 365 security, compliance, operational, or governance baseline.

## Why it matters

Weak or incomplete configuration in this area can create avoidable security, compliance, governance, reliability, or operational risk. The exact impact depends on the evidence returned by the assessment, so TenantIQ should tie any risk statement directly to the reported status, severity, evidence, and recommendation.

## Evidence to review

Review the assessment fields for this finding, including:

- Check ID and title
- Workload and category
- Status and severity
- TenantIQ evidence returned by the health check
- Any counts, policy names, configuration values, objects, or scope information explicitly present in the evidence
- The TenantIQ recommendation attached to the finding

## Recommended remediation approach

- Confirm the finding is in scope for the tenant and workload.
- Validate the reported evidence in the relevant Microsoft 365 admin experience or API before making changes.
- Apply the least-privilege and least-exposure configuration that satisfies the organization's business requirements.
- Document approved exceptions and ownership where the recommended baseline is intentionally not applied.
- Re-run the TenantIQ assessment after remediation to verify the finding state changed as expected.

## Interpretation guardrails

- Do not claim remediation has been performed.
- Do not invent missing tenant settings, identities, counts, policy names, or attack paths.
- If the assessment evidence is incomplete, state that additional validation is required.
- Prefer the finding's own TenantIQ recommendation when it is more specific than this general guidance.
'''


def main() -> None:
    existing = existing_check_ids()
    created = 0
    skipped = 0

    for check in CHECKS:
        if check.check_id in existing:
            skipped += 1
            continue

        workload_dir = WORKLOAD_DIR.get(check.workload)
        if not workload_dir:
            print(f"Skipping unsupported workload mapping: {check.workload} ({check.check_id})")
            continue

        directory = KB_ROOT / workload_dir
        directory.mkdir(parents=True, exist_ok=True)

        filename = f"{slugify(title_for_check(check))}-{check.check_id.lower()}.md"
        path = directory / filename
        path.write_text(build_document(check), encoding="utf-8")
        created += 1
        print(f"Created {path.relative_to(ROOT).as_posix()}")

    print(f"\nTenantIQ KB generation complete: {created} created, {skipped} already covered.")


if __name__ == "__main__":
    main()
