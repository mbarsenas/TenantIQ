# TenantIQ v1.0 Release Checklist

Use this checklist before distributing a TenantIQ customer package.

## Source Baseline

- Confirm the validated baseline branch exists: `baseline/tenantiq-v1.0-validated`.
- Confirm `main` contains only intentional productization changes after the validated assessment baseline.
- Do not modify frozen workload evaluators during release packaging unless a verified regression requires it.

## Product Metadata

- Confirm `TenantIQ.json` reports the intended version and release channel.
- Confirm the customer package displays the expected version at startup.
- Confirm support/company metadata is populated if required for the distribution channel.

## Environment Validation

From PowerShell 7:

```powershell
.\Install-TenantIQPrerequisites.ps1
.\Start-TenantIQ.ps1
```

Confirm all required dependencies display `[OK]` before the main menu opens.

## Functional Acceptance

Run a clean acceptance assessment from the customer package:

1. Exchange Online
2. Entra ID
3. SharePoint Online
4. Microsoft Teams
5. OneDrive
6. Microsoft Intune
7. Microsoft Defender
8. Microsoft Purview
9. Portfolio Report

For each workload confirm:

- Authentication completes or an existing valid session is used as designed.
- The assessment reaches completion without a runtime exception.
- A workload CSV is created under `06 Output`.
- PASS/WARNING/FAIL/INFO/NOT EVALUATED values are represented correctly.
- Legitimate tenant findings are not confused with runtime failures.

## Portfolio Validation

Confirm the Portfolio Report:

- Includes the latest available CSV for each assessed workload.
- Reconciles Total Controls with PASS + WARNING + FAIL + unscored context.
- Excludes INFO and NOT EVALUATED from scored-control math.
- Uses the posture bands documented in the Help Center.
- Shows Priority Findings and Recommended Next Steps.
- Generates both HTML and CSV output.

For the validated v1.0 control registry, a complete eight-workload assessment contains 416 controls.

## Documentation Validation

From menu option `[10] Help / Documentation`, verify:

- Getting Started
- Prerequisites
- Connecting to Microsoft 365
- Running Assessments
- Understanding Results
- Reports
- Troubleshooting

Also confirm `QUICKSTART.md` is present in the package root.

## Package Build

Build the customer ZIP with:

```powershell
.\Build-TenantIQPackage.ps1
```

Expected output:

```text
dist\TenantIQ-v1.0.0\
dist\TenantIQ-v1.0.0.zip
```

The customer package must not include prior customer assessment CSVs, generated portfolio reports, Git metadata, temporary files, logs, or development backup files.

## Clean-Machine Test

Extract the ZIP into a new directory on a Windows workstation and verify:

```powershell
.\Install-TenantIQPrerequisites.ps1
.\Start-TenantIQ.ps1
```

Do not run the final release only from the development repository. The ZIP itself is the release artifact and must be tested.

## Security Review

Before distribution, verify the package contains no:

- Passwords
- Access or refresh tokens
- Client secrets
- Private keys
- Customer tenant identifiers that should not be distributed
- Customer-generated assessment reports
- Developer-specific credentials

TenantIQ should use Microsoft interactive authentication rather than embedded credentials.

## Release Approval

A release is ready when:

- Prerequisite installation works.
- Startup validation works.
- Workloads 1 through 8 complete on the acceptance tenant.
- Portfolio Report completes and totals reconcile.
- Customer documentation is present.
- The generated ZIP passes a clean-machine smoke test.

Record the release commit SHA and retain the validated ZIP as the v1.0 release artifact.
