---
check_id: ENTRA-ID-001
workload: Entra ID
category: Identity Governance
severity: High
source_check_path: 02 Health Checks/Entra ID
content_type: finding-guidance
---

# Authorization Policy

TenantIQ uses this finding to evaluate tenant-wide authorization defaults that influence user capabilities, guest behavior, and application consent exposure.

## Why it matters

Overly permissive authorization defaults can expand what standard users or guests are allowed to do across Microsoft Entra ID. Weak defaults can also increase application-consent exposure and make identity governance harder to enforce consistently.

## Evidence to review

Review the assessment evidence for settings related to:

- Default user permissions
- Guest user access restrictions
- User application registration capabilities
- Application consent defaults
- Other tenant-wide authorization policy values returned by the check

## Recommended remediation

- Review the tenant authorization policy against the organization's least-privilege requirements.
- Restrict risky application-consent behavior unless there is a documented business requirement.
- Ensure guest defaults are intentionally configured and aligned with external collaboration policy.
- Limit broad user capabilities that are not required for normal business operations.
- Document approved exceptions and review them periodically.

## Interpretation

TenantIQ should describe only the specific authorization settings present in the assessment evidence. A FAIL indicates one or more observed settings do not meet the expected TenantIQ baseline; it does not by itself prove compromise or misuse.
