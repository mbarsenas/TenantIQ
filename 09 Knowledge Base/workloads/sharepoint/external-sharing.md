# SharePoint Online External Sharing

Workload: SharePoint Online
Category: Sharing and Access
Content type: finding-guidance

## What TenantIQ evaluates
TenantIQ evaluates SharePoint Online sharing configuration for conditions that can broaden access beyond the intended audience, including tenant-level and site-level external sharing behavior.

## Why it matters
Overly permissive external sharing can expose business data to unintended recipients or allow sharing patterns that conflict with organizational governance. Overly restrictive configuration can also disrupt legitimate collaboration, so findings should be evaluated against the organization's approved sharing model.

## Evidence to review
Review the TenantIQ evidence for the affected tenant or sites, the configured sharing capability, and whether the configuration aligns with the organization's collaboration and data-governance requirements.

## Recommended remediation approach
1. Identify the sites or tenant settings associated with the finding.
2. Confirm the intended external collaboration model.
3. Reduce sharing scope where it exceeds the approved model.
4. Review guest access and existing external sharing relationships where applicable.
5. Document intentional exceptions and ownership.

## TenantIQ assistant behavior
The assistant may explain exposure, governance implications, and remediation considerations. It must not claim that it changed SharePoint settings or revoked access.
