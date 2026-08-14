---
check_id: ENTRA-AUTH-002
workload: Entra ID
category: Authentication
severity: High
content_type: finding-guidance
---

# Authentication Methods Policy

TenantIQ uses this finding to evaluate whether the tenant's authentication methods policy supports a strong, modern authentication posture.

## Why it matters

A policy that relies heavily on weaker methods can make phishing, SIM-swap, and social-engineering attacks more effective. The authentication methods policy should align allowed methods with the tenant's identity risk model and Conditional Access design.

## Evidence to review

TenantIQ should review evidence such as:

- Enabled authentication methods
- Availability of phishing-resistant methods
- Continued use of SMS, voice, or email-based methods where applicable
- Targeting and rollout scope
- Alignment with Conditional Access and privileged account requirements

## Recommended remediation

- Introduce phishing-resistant methods such as FIDO2/passkeys or certificate-based authentication where appropriate.
- Review continued reliance on SMS, voice, or email-based methods.
- Align method availability with Conditional Access and privileged identity requirements.
- Roll out stronger methods in a controlled sequence and validate user readiness.

## Interpretation

A warning indicates the configured authentication methods policy should be strengthened. TenantIQ should describe the policy state found in the assessment and should not assume unsupported methods are actively used unless the evidence shows that.
