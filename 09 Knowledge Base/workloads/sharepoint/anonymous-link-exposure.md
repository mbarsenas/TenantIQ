---
check_id: SPO-SHR-001
workload: SharePoint Online
category: Sharing
severity: High
source_check_path: 02 Health Checks/SharePoint Online/Sharing/Test-AnonymousLinkExposure.ps1
content_type: finding-guidance
---

# Anonymous Link Exposure

TenantIQ uses this finding to evaluate whether SharePoint Online content can be shared using anonymous links that do not require recipient authentication.

Anonymous links can be appropriate for narrowly controlled business scenarios, but they reduce identity-based accountability because access can be granted to anyone who receives the link.

## Why it matters

Broad or long-lived anonymous sharing can increase the chance of unintended data exposure. Links may be forwarded outside the intended audience, and access is harder to attribute to a specific external identity.

## Evidence to review

Review the assessment evidence for the tenant and affected sites, including:

- Whether anonymous or Anyone links are permitted
- Default sharing-link behavior
- Link expiration controls
- Site-level sharing configuration
- Business justification for anonymous sharing

## Recommended remediation

- Restrict anonymous sharing where it is not explicitly required.
- Prefer authenticated guest or organization-specific sharing for sensitive collaboration.
- Configure expiration and permission limits for anonymous links that must remain available.
- Review high-value or sensitive sites separately before changing tenant-wide settings.
- Validate business workflows before tightening sharing controls.

## Interpretation

TenantIQ should describe the observed sharing posture from the assessment evidence. Do not claim that anonymous links are actively exposing data unless the assessment provides evidence of actual exposure.
