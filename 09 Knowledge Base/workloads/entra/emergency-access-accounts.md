---
check_id: ENTRA-ID-005
workload: Entra ID
category: Identity Hygiene
severity: High
source_check_path: 02 Health Checks/Entra ID
content_type: finding-guidance
---

# Emergency Access Accounts

TenantIQ uses this finding to evaluate whether dedicated emergency-access identities are present and aligned with resilient tenant-access practices.

## Why it matters

Emergency-access accounts provide a recovery path when normal administrator access is disrupted by Conditional Access, federation, MFA service dependencies, or configuration mistakes. Poorly designed or poorly monitored emergency accounts can create either an availability gap or an unnecessary privileged-access risk.

## Evidence to review

Review the assessment evidence for:

- Presence of dedicated emergency-access accounts
- Cloud-only identity design when returned by the assessment
- Privileged role assignment
- Authentication method and sign-in characteristics
- Monitoring or alerting indicators returned by the check
- Whether the accounts appear to be used only for emergency scenarios

## Recommended remediation

- Maintain dedicated emergency-access accounts appropriate for the tenant's administrative resilience requirements.
- Keep emergency identities separate from normal administrator accounts and daily-use workflows.
- Protect credentials using documented, controlled storage and access procedures.
- Monitor sign-ins and alert on use of emergency-access identities.
- Test the recovery procedure periodically without turning the emergency account into a routine administration path.
- Review Conditional Access exclusions only to the extent necessary for the emergency-access design.

## Interpretation

TenantIQ should explain the emergency-access posture reflected in the assessment evidence. A WARNING means the observed design should be reviewed; it does not mean the emergency identities are currently compromised or misused.
