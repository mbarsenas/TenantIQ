---
check_id: ENTRA-IDP-004
workload: Entra ID
category: Identity Protection
severity: High
source_check_path: 02 Health Checks/Entra ID
content_type: finding-guidance
---

# Risky Users

TenantIQ uses this finding to surface Microsoft Entra ID user-risk signals returned by the assessment.

## Why it matters

A user marked as risky may have indicators associated with credential compromise or suspicious identity activity. Risk signals should be investigated promptly because unresolved user risk can affect access decisions and may indicate that the identity requires containment or remediation.

## Evidence to review

Review the assessment evidence for:

- Affected user identities
- User risk level and risk state
- Related risk detections when available
- Recent sign-in context when returned by the assessment
- Whether Conditional Access or identity-protection controls are expected to respond to the observed risk

## Recommended remediation

- Investigate the specific user-risk detections and confirm whether the activity is legitimate.
- Follow the organization's identity incident-response process for suspected compromise.
- Revoke active sessions or credentials when supported by the incident findings and organizational procedure.
- Require appropriate authentication remediation, such as password reset or stronger authentication registration, when warranted.
- Confirm identity-protection and Conditional Access policies are operating as intended.

## Interpretation

TenantIQ should report only the risk indicators present in the assessment. A risky-user finding is a signal requiring investigation; it is not proof that the account has been compromised.
