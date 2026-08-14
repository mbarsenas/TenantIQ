---
check_id: ENTRA-AUTH-001
workload: Entra ID
category: Authentication
severity: High
content_type: finding-guidance
---

# Authentication Methods

TenantIQ uses this finding to evaluate whether users have approved authentication methods registered for secure sign-in and recovery.

## Why it matters

Users without suitable registered methods can remain dependent on passwords or weaker recovery and authentication options. This can increase exposure to phishing, password spraying, credential stuffing, SIM-based attacks, and account takeover.

## Evidence to review

TenantIQ should review evidence such as:

- Users with registered authentication methods
- Users lacking approved methods
- Method types in use
- Coverage of phishing-resistant methods where available
- Exceptions for emergency access and non-user identities

## Recommended remediation

- Review affected accounts and require registration of approved authentication methods.
- Prefer stronger methods that align with the organization's authentication policy.
- Treat emergency access and non-user identities according to their documented design.
- Reassess registration coverage after remediation.

## Interpretation

A failed finding indicates the observed authentication method posture does not meet the TenantIQ baseline. TenantIQ should explain only the method gaps present in the assessment evidence.
