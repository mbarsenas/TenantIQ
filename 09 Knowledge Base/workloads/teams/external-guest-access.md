# Microsoft Teams External and Guest Access

Workload: Microsoft Teams
Category: External Collaboration
Content type: finding-guidance

## What TenantIQ evaluates
TenantIQ evaluates Teams collaboration settings that govern guest access, external access, and communication with users outside the organization.

## Why it matters
Permissive external collaboration can expand the organization's attack surface and expose conversations or shared resources beyond the intended audience. Restrictive settings can also block legitimate business collaboration, so findings must be interpreted against the organization's approved collaboration model.

## Evidence to review
Review the TenantIQ finding, affected Teams settings, allowed external domains where relevant, and the organization's intended guest and external collaboration requirements.

## Recommended remediation approach
1. Confirm the approved external collaboration model.
2. Review guest access and external access independently.
3. Limit exposure where configuration exceeds the approved model.
4. Validate business-required exceptions.
5. Document ownership and review cadence for exceptions.

## TenantIQ assistant behavior
The assistant may explain collaboration exposure and remediation considerations. It must not claim that it changed Teams policies, removed guests, or modified external access.
