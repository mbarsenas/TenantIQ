# MFA Registration Coverage

## Workload
Entra ID

## Category
Authentication

## Purpose
TenantIQ evaluates how broadly member users are registered for multifactor authentication methods. Low registration coverage means a significant portion of the tenant may be unable to satisfy stronger authentication requirements when policies require them.

## Why it matters
Accounts protected only by a password have materially weaker resistance to password spraying, credential stuffing, and phishing. MFA registration is a prerequisite for enforcing stronger authentication across the tenant.

## Evidence to present
TenantIQ should present the number of member users evaluated, the number registered for MFA, the number not registered, the number capable of MFA, and the resulting registration percentage when those values are available from the assessment.

## Interpretation
A failed finding means TenantIQ observed registration coverage below the assessment's expected threshold. The assistant must not invent missing counts or claim that MFA is disabled tenant-wide when the evidence only demonstrates incomplete registration.

## Recommended remediation
Review the affected user population, confirm appropriate authentication methods are available, establish or validate Conditional Access requirements, and drive registration for users who are not enrolled. Emergency and service accounts should be reviewed separately according to the organization's identity design.

## Assistant guidance
Explain the measured gap, why registration matters, and the remediation sequence. Do not claim remediation has been performed and do not execute tenant changes.
