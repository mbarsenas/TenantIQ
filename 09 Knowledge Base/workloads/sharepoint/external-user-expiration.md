---
check_id: SPO-SHR-005
workload: SharePoint Online
category: Sharing
severity: High
source_check_path: 02 Health Checks/SharePoint Online/Sharing/Test-ExternalUserExpiration.ps1
content_type: finding-guidance
---

# External User Expiration

TenantIQ uses this finding to evaluate whether external access to SharePoint Online is governed with expiration controls appropriate to the organization’s collaboration model.

External users often support legitimate partner and vendor collaboration, but access that remains indefinitely can outlive the business relationship that originally justified it.

## Why it matters

Without expiration or periodic revalidation, stale external access can accumulate and increase the risk of unauthorized access to collaboration content.

## Evidence to review

Review the assessment evidence for:

- Whether guest or external user expiration is configured
- The configured expiration period
- Site-level exceptions or overrides
- Business processes for renewing legitimate external access
- Whether long-lived collaboration scenarios are documented

## Recommended remediation

- Configure expiration or periodic access review for external users where appropriate.
- Align expiration periods with partner and vendor engagement lifecycles.
- Require content owners to revalidate continued access before renewal.
- Handle documented long-term collaboration exceptions explicitly.
- Review sensitive sites for tighter external access governance.

## Interpretation

TenantIQ should report the configured expiration posture from the assessment. Do not infer that every existing guest is stale unless the assessment includes evidence about account age or activity.
