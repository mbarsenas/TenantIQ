---
check_id: SPO-SHR-002
workload: SharePoint Online
category: Sharing
severity: High
source_check_path: 02 Health Checks/SharePoint Online/Sharing/Test-DefaultSharingLinkConfiguration.ps1
content_type: finding-guidance
---

# Default Sharing Link Configuration

TenantIQ uses this finding to evaluate the default link type and permission behavior presented to users when sharing SharePoint Online content.

The default sharing option influences user behavior at scale. A permissive default can make broad sharing the path of least resistance even when more restrictive options are available.

## Why it matters

Default link settings that favor anonymous or overly broad access can increase accidental oversharing and reduce accountability for external access.

## Evidence to review

Review assessment evidence for:

- Default sharing-link type
- Default link permission level
- Tenant and site sharing settings
- Whether users can select more restrictive alternatives
- Any documented business requirement for broad defaults

## Recommended remediation

- Prefer authenticated or organization-scoped defaults where practical.
- Use view-only defaults when edit access is not routinely required.
- Keep broader link types available only when there is a justified collaboration need.
- Validate site-specific exceptions before applying tenant-wide changes.
- Communicate sharing behavior changes to content owners and support teams.

## Interpretation

TenantIQ should report the configured default observed in the assessment and explain its risk implications without assuming that every generated link uses that default.
