---
check_id: OD-SYNC-002
workload: OneDrive
category: TenantIQ Assessment
severity: Medium
content_type: finding-guidance
---

# Files On Demand Configuration

TenantIQ uses **OD-SYNC-002** to assess **files on demand configuration** in OneDrive. This guidance is intentionally evidence-bound: the assistant should explain only what the uploaded TenantIQ assessment actually observed and should not infer tenant configuration that is not present in the finding evidence.

## What this check represents

This check evaluates the TenantIQ control represented by: files on demand configuration, files on-demand configuration.

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
