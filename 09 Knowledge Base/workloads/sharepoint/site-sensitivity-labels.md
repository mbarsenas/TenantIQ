---
check_id: SPO-GOV-004
workload: SharePoint Online
category: Governance
severity: High
source_check_path: 02 Health Checks/SharePoint Online/Governance/Test-SiteSensitivityLabels.ps1
content_type: finding-guidance
---

# Site Sensitivity Labels

TenantIQ uses this finding to assess whether SharePoint sites are governed with sensitivity labels that align collaboration controls with the organization’s information-protection strategy.

## Why it matters

Sensitivity labels can help standardize protections for sites and Microsoft 365 groups, especially when collaboration settings should reflect the sensitivity of the content and business use case. Missing or inconsistent labels can leave externally shared or high-impact sites without a consistent governance baseline.

## Evidence to review

TenantIQ should review evidence such as:

- Whether eligible SharePoint sites have sensitivity labels applied
- Whether label coverage is consistent for externally shared or externally shareable sites
- Whether the labels in use align with expected container governance controls
- Whether unlabeled sites represent deliberate exceptions or unmanaged gaps

## Recommended remediation

- Identify unlabeled sites that are externally shared or otherwise high impact.
- Confirm the organization’s container-label design and intended policy outcomes.
- Apply appropriate sensitivity labels to in-scope sites after validating business ownership and collaboration requirements.
- Review label-driven controls such as external sharing, privacy, and unmanaged-device behavior where applicable.
- Establish a recurring governance process for new and changed sites.

## Interpretation

A warning or failed finding indicates TenantIQ observed a governance gap in site labeling. TenantIQ should describe the actual site-label evidence returned by the assessment and should not claim that a particular label or policy must be used unless that requirement is supported by the organization’s design or the stored TenantIQ evidence.
