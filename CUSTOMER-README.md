# TenantIQ v1.1.0

TenantIQ is a read-only Microsoft 365 assessment platform that evaluates configuration, security, governance, and operational posture across eight Microsoft 365 workloads.

## Coverage

TenantIQ v1.1.0 contains 416 registered controls:

- Exchange Online — 50
- Entra ID — 66
- SharePoint Online — 50
- Microsoft Teams — 50
- OneDrive — 50
- Microsoft Intune — 50
- Microsoft Defender — 50
- Microsoft Purview — 50

## First Run

Open PowerShell 7 in the extracted TenantIQ folder.

Install missing required PowerShell modules:

```powershell
.\Install-TenantIQPrerequisites.ps1
```

Then launch TenantIQ:

```powershell
.\Start-TenantIQ.ps1
```

Do not use `TenantIQ.ps1` as the normal customer launch command.

## Recommended Assessment Workflow

Run workloads 1 through 8. Complete Microsoft authentication when prompted and allow each workload to export its assessment CSV.

After the workload assessments are complete, select **9 — Portfolio Report** to generate the customer-facing executive assessment.

Output is written to the `06 Output` directory.

## Result Model

TenantIQ uses five result states:

- **PASS** — evaluated configuration meets the control criteria.
- **WARNING** — evaluated condition warrants review or improvement.
- **FAIL** — evaluated configuration does not meet the control criteria.
- **INFO** — contextual evidence that is not scored.
- **NOT EVALUATED** — required evidence was unavailable or unsupported; the result is not scored.

Portfolio scoring gives PASS full credit, WARNING half credit, and FAIL no credit. INFO and NOT EVALUATED remain visible as unscored context.

## Read-Only Assessment Model

TenantIQ collects supported Microsoft 365 administrative evidence and produces findings and recommendations. It does not automatically remediate or modify tenant configuration.

Recommendations must be reviewed against the customer's architecture, licensing, exceptions, security requirements, and change-management process before production changes are made.

## Authentication

TenantIQ uses Microsoft-supported administrative PowerShell and Microsoft Graph authentication. Some workloads intentionally use isolated PowerShell processes to avoid authentication-library conflicts. Multiple Microsoft sign-in prompts during a full assessment can therefore be expected.

TenantIQ does not require Microsoft 365 passwords to be stored in its configuration files.

## Documentation

From the TenantIQ main menu select **10 — Help / Documentation** for product guidance covering prerequisites, Microsoft 365 connections, assessments, results, reports, and troubleshooting.

`QUICKSTART.md` provides the short deployment workflow.

## Support Diagnostics

When reporting a problem, record:

1. TenantIQ version.
2. PowerShell version from `$PSVersionTable.PSVersion`.
3. The workload selected.
4. The exact console error.
5. Whether Microsoft authentication completed successfully.
6. Whether the issue occurs from a fresh PowerShell 7 session.

Do not send passwords, access tokens, refresh tokens, client secrets, private keys, or other credentials with support information.

## Important

TenantIQ assessment results represent evidence available to its registered controls at assessment time. They are not a guarantee that a Microsoft 365 tenant is completely secure, compliant, or free of operational risk.
