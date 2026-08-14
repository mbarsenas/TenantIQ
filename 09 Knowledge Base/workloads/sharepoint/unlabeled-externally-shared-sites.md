---
check_id: SPO-GOV-006
workload: SharePoint Online
category: Governance
severity: High
source_check_path: 02 Health Checks/SharePoint Online/Governance/Test-UnlabeledExternallySharedSites.ps1
content_type: finding-guidance
---

# Unlabeled Externally Shared Sites

TenantIQ uses this finding to identify SharePoint sites that are externally shared or externally shareable but do not have an appropriate sensitivity label applied.

## Why it matters

External collaboration increases the importance of consistent site governance. When an externally shared site is unlabeled, administrators may have less assurance that collaboration, privacy, unmanaged-device, and sharing controls align with the intended sensitivity of the site.

## Evidence to review

TenantIQ should review evidence such as:

- Sites that allow or currently use external sharing
- Whether those sites have sensitivity labels applied
- The site owner or business purpose where available
- Whether unlabeled sites are temporary, exempted, or unmanaged
- Whether the organization’s label policy includes container settings relevant to external collaboration

## Recommended remediation

- Prioritize externally shared or externally shareable sites that have no sensitivity label.
- Validate business ownership and collaboration requirements before applying a label.
- Apply an appropriate sensitivity label according to the organization’s information-protection design.
- Review externally shared content and guest access on affected sites where risk warrants it.
- Establish a recurring review for newly created or newly shared sites.

## Interpretation

A warning or failed finding means TenantIQ observed externally collaborative sites without the expected labeling coverage. TenantIQ should use the assessment evidence to identify the affected population and should not infer the sensitivity classification of any site when that information is not present.
