---
check_id: ENTRA-APP-007
workload: Entra ID
category: Applications
severity: High
content_type: finding-guidance
---

# Enterprise Application Permissions

TenantIQ uses this finding to evaluate whether enterprise applications and service principals have permissions that require security or governance review.

## Why it matters

Broad or unnecessary delegated and application permissions can expose Microsoft 365 data and directory resources beyond the application's actual business need. Admin consent can make these permissions effective tenant-wide and can create persistent access that does not depend on an interactive user sign-in.

## Evidence to review

TenantIQ should review evidence such as:

- High-impact delegated or application permissions
- Admin-consented permissions
- Publisher verification or trust indicators where available
- Application ownership
- Business justification
- Whether granted permissions are still required

## Recommended remediation

- Review critical third-party application permissions and admin consent.
- Remove grants that are unnecessary.
- Validate application ownership, publisher trust, and business justification.
- Prefer least-privilege permissions for approved integrations.
- Establish recurring access reviews for high-impact enterprise applications.

## Interpretation

A failed finding indicates TenantIQ observed permissions that require immediate review based on the assessment evidence. TenantIQ should not state that an application is malicious or compromised unless the assessment explicitly supports that conclusion.
