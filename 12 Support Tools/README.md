# TenantIQ Support Tools

This folder is the permanent TenantIQ troubleshooting entry point. Operational scripts remain in their existing locations so production workflows and relative paths are not disturbed; the support console references those authoritative tools.

## Start the console

From the TenantIQ repository root:

```powershell
.\12 Support Tools\Start-TenantIQSupportTools.ps1
```

The console groups support actions into:

- System and environment checks
- Workload isolation and evidence diagnostics
- Release/customer package validation
- RAG and assessment service checks
- Support bundle creation
- Licensed tenant allowance verification

## Tenant allowance verification

The support console exposes the Essentials/Professional tenant-limit self-test as option 22. It runs the authoritative customer-package test without duplicating its enforcement logic.

Direct usage from the repository root:

```powershell
.\12 Support Tools\Test-TenantIQTenantAllowance.ps1
```

## Support bundle

`New-TenantIQSupportBundle.ps1` creates a timestamped ZIP under `Support Bundles\` containing troubleshooting metadata such as:

- TenantIQ version/release channel
- PowerShell and operating-system details
- Git branch/status and recent commits
- Installed PowerShell module inventory
- Prerequisite check output
- TenantIQ version and license-status command output
- Recent assessment/output file inventory
- Runtime evidence file inventory
- Environment-variable configuration status

Secret values are deliberately not collected. Environment variables are recorded only as `Configured` or `Missing`. Before the ZIP is created, every collected text file is automatically scanned and redacted for passwords, secrets, tokens, API keys, authorization headers, connection strings, sensitive URL parameters, common provider-token formats, JWTs, and private-key blocks. A `REDACTION-REPORT.txt` file is included in each bundle.

By default, tenant-access probes are not run and assessment CSVs are not copied. The console asks before enabling either option because tenant-access probes can trigger Microsoft 365 authentication and assessment CSVs may contain customer data.

Direct usage:

```powershell
.\12 Support Tools\New-TenantIQSupportBundle.ps1
```

Optional:

```powershell
.\12 Support Tools\New-TenantIQSupportBundle.ps1 -IncludeTenantAccess
.\12 Support Tools\New-TenantIQSupportBundle.ps1 -IncludeRecentAssessmentOutput
```

Redaction verification:

```powershell
.\12 Support Tools\New-TenantIQSupportBundle.ps1 -RedactionSelfTest
```

## Operational-script rule

Do not move the authoritative assessment, fulfillment, package-validation, or runtime scripts into this directory unless every invoking workflow and relative path is deliberately updated and tested. The console should reference the operational source of truth instead of creating stale duplicate logic.
