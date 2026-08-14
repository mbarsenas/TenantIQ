---
check_id: ENTRA-ID-002
workload: Entra ID
category: Identity Governance
severity: High
source_check_path: 02 Health Checks/Entra ID
content_type: finding-guidance
---

# Default User Permissions

TenantIQ uses this finding to evaluate whether default member-user permissions are appropriately restricted for the tenant's governance model.

## Why it matters

Broad default permissions can allow standard users to perform directory or application actions that are unnecessary for their role. This increases governance overhead and can create additional paths for misuse if an account is compromised.

## Evidence to review

Review the assessment evidence for user-default permissions such as:

- Permission to register applications
- Permission to create security or Microsoft 365 groups
- Permission to read or enumerate directory information beyond business need
- Other default member capabilities returned by the assessment

## Recommended remediation

- Apply least privilege to default member-user capabilities.
- Restrict application registration to approved roles or governed workflows when broad self-service registration is not required.
- Restrict group creation when governance requirements call for controlled provisioning.
- Preserve required user productivity capabilities while removing unnecessary tenant-wide defaults.
- Record business-approved exceptions and review them on a recurring basis.

## Interpretation

TenantIQ should tie its explanation to the actual default permissions returned in the assessment. A WARNING means the observed defaults should be reviewed against the tenant's governance baseline; it does not mean every enabled self-service capability is inherently unsafe.
