---
check_id: ENTRA-EXT-002
workload: Entra ID
category: External Identities
severity: High
content_type: finding-guidance
---

# Guest Invitation Restrictions

TenantIQ uses this finding to evaluate who is allowed to invite external guest users into the tenant.

## Why it matters

Broad member-driven guest invitations can increase external identity sprawl and make it harder to ensure every guest relationship has clear ownership and business justification. Restricting invitation rights can strengthen governance when external collaboration is centrally managed.

## Evidence to review

TenantIQ should review evidence such as:

- Who can invite guest users
- Whether invitation rights are limited to administrators or designated Guest Inviter users
- Whether broad member-driven invitations are enabled
- Whether external collaboration has documented governance and review processes

## Recommended remediation

- Restrict guest invitations to administrators and designated Guest Inviter users unless broader invitations are explicitly required.
- Document business justification for broader invitation rights.
- Establish ownership and recurring review of guest accounts and external collaboration settings.
- Align guest invitation policy with cross-tenant access and external sharing governance.

## Interpretation

A warning indicates the guest invitation policy is broader than the TenantIQ baseline. TenantIQ should describe the configured policy and avoid claiming specific guest misuse unless the assessment evidence supports it.
