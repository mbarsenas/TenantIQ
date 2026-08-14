---
check_id: ENTRA-MFA-001
workload: Entra ID
category: Authentication
severity: High
source_check_path: 02 Health Checks/Entra ID/Authentication/Test-MFARegistration.ps1
content_type: finding-guidance
---

# MFA Registration Coverage

TenantIQ uses this finding to evaluate whether member users are registered for multi-factor authentication methods.

Low registration coverage means a meaningful portion of the user population may still depend primarily on password-based authentication. That increases exposure to phishing, password spraying, credential stuffing, and other credential-based attacks.

## Why it matters

MFA registration is a prerequisite for reliably enforcing stronger authentication. If a user is not registered for an acceptable MFA method, a policy that requires MFA can create user disruption or force administrators to introduce exceptions that reduce the tenant's security posture.

## Evidence to review

TenantIQ should evaluate values such as:

- Total member users
- MFA registered users
- MFA not registered users
- MFA capable users
- Passwordless capable users
- Registration coverage percentage

## Recommended remediation

- Identify users who are not registered for MFA.
- Confirm approved authentication methods are available for those users.
- Validate Conditional Access requirements for MFA.
- Drive registration for unenrolled users.
- Review emergency access and service identities separately according to the organization's identity design.

## Interpretation

A failed finding indicates the observed registration coverage does not meet the TenantIQ check's expected security posture. TenantIQ should explain the evidence returned by the assessment rather than inventing tenant-specific counts that are not present in the assessment data.
