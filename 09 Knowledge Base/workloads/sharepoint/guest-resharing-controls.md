---
check_id: SPO-SHR-006
workload: SharePoint Online
category: Sharing
severity: High
source_check_path: 02 Health Checks/SharePoint Online/Sharing/Test-GuestResharingControls.ps1
content_type: finding-guidance
---

# Guest Resharing Controls

TenantIQ uses this finding to evaluate whether external guests can extend access to SharePoint Online content beyond the audience originally approved by an internal owner.

Guest resharing can support legitimate collaboration, but it weakens centralized control when external recipients are able to invite or share with additional users without an internal approval step.

## Why it matters

Unrestricted guest resharing can expand the external audience over time, reduce owner awareness, and make access governance harder to enforce for sensitive or regulated content.

## Evidence to review

Review the assessment evidence for:

- Whether guests can share items they do not own
- Whether guests can invite additional users
- Tenant and site-level sharing behavior
- Existing business processes for external collaboration
- Sites containing sensitive or regulated information

## Recommended remediation

- Restrict guest resharing where business workflows do not require it.
- Require internal owners to approve expansion of external access for sensitive sites.
- Use authenticated guest access and owner-managed permissions for high-value content.
- Document exceptions where partner-led resharing is necessary.
- Review site-specific settings before applying tenant-wide restrictions.

## Interpretation

TenantIQ should describe the configured resharing controls observed in the assessment. Do not claim that guests have actually reshared content unless the assessment contains evidence of that activity.
