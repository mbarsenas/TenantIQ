---
check_id: SPO-SHR-008
workload: SharePoint Online
category: Sharing
severity: High
source_check_path: 02 Health Checks/SharePoint Online/Sharing/Test-SharingDomainRestrictions.ps1
content_type: finding-guidance
---

# Sharing Domain Restrictions

TenantIQ uses this finding to evaluate whether SharePoint Online external sharing is constrained with domain allow or block controls where the organization’s collaboration model requires them.

Domain restrictions can reduce exposure to untrusted or unintended external organizations while preserving approved partner collaboration.

## Why it matters

Without appropriate domain governance, users may be able to share content with external domains that have not been reviewed or approved, increasing the chance of unintended data disclosure.

## Evidence to review

Review the assessment evidence for:

- Whether external sharing domain restrictions are configured
- Whether the tenant uses an allow-list or block-list approach
- Approved partner domains
- Site-level external sharing exceptions
- Business workflows that require broad external collaboration

## Recommended remediation

- Define approved or prohibited domains according to the organization’s collaboration requirements.
- Prefer an allow-list for highly controlled or regulated environments where practical.
- Maintain a documented process for adding and removing partner domains.
- Review site-specific exceptions before enforcing stricter tenant-wide controls.
- Reassess domain restrictions as partner relationships change.

## Interpretation

TenantIQ should report the configured domain restriction posture from the assessment. Do not claim that content has been shared with an untrusted domain unless the assessment provides evidence of that sharing activity.
