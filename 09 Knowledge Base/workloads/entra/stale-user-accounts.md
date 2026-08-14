---
check_id: ENTRA-ID-008
workload: Entra ID
category: Identity Hygiene
severity: High
source_check_path: 02 Health Checks/Entra ID
content_type: finding-guidance
---

# Stale User Accounts

TenantIQ uses this finding to identify enabled user accounts that appear inactive based on the evidence returned by the assessment.

## Why it matters

Long-inactive enabled accounts increase identity attack surface because they may retain licenses, group memberships, application access, or privileged assignments while receiving less day-to-day scrutiny. If an inactive identity is no longer required, leaving it enabled creates unnecessary exposure.

## Evidence to review

Review the assessment evidence for:

- Account enabled state
- Last sign-in or activity indicators returned by the check
- User type and business ownership
- Group or role assignments when available
- Whether the account is expected to remain active, such as service, emergency, or special-purpose identities

## Recommended remediation

- Validate business ownership and current need for each stale enabled account.
- Disable or remove identities that are no longer required, following organizational offboarding and retention processes.
- Review privileged roles, group memberships, licenses, and application access before final removal.
- Treat service, emergency-access, and other non-human identities according to their documented lifecycle controls.
- Establish a recurring stale-account review process.

## Interpretation

A FAIL indicates TenantIQ observed enabled accounts meeting the check's inactivity criteria. TenantIQ should not assume an account is malicious or abandoned without validating the assessment evidence and business context.
