# TenantIQ

TenantIQ v1.1.0 is a read-only Microsoft 365 assessment platform for administrators, internal IT teams, consultants, and MSP engineers.

## Production scope

- 416 registered controls
- 8 Microsoft 365 workloads
- Signed customer licenses with startup enforcement
- Essentials licensing for 1 Microsoft 365 tenant
- Professional licensing for up to 5 Microsoft 365 tenants
- Workload CSV exports and an Executive Portfolio Report
- TenantIQ365 Support Tool and redacted support bundles

## Workloads

1. Exchange Online
2. Entra ID
3. SharePoint Online
4. Microsoft Teams
5. OneDrive
6. Microsoft Intune
7. Microsoft Defender
8. Microsoft Purview

## Customer startup

1. Run `Install-TenantIQPrerequisites.ps1`.
2. Run `Start-TenantIQ.ps1`.
3. Complete Microsoft authentication when prompted.
4. Run the required workloads and generate the Portfolio Report from option 9.

TenantIQ performs assessment and reporting only. It does not automatically remediate or modify the customer tenant.

## Release validation

The customer package is built by `Build-TenantIQPackage.ps1` and must pass both:

- `Test-TenantIQReleasePackage.ps1`
- `Test-TenantIQReleaseCandidate.ps1`

Customer-specific packages include a cryptographically signed `TenantIQ-License.json`. Private signing keys, customer deliveries, generated output, and local runtime state are excluded from source control.

## Requirements

- Windows
- PowerShell 7 or later
- Required Microsoft 365 PowerShell modules installed by the prerequisite installer
- Appropriate read-only or reporting permissions for the workloads being assessed

See [QUICKSTART.md](QUICKSTART.md), [CUSTOMER-README.md](CUSTOMER-README.md), and [RELEASE-CHECKLIST.md](RELEASE-CHECKLIST.md) for operational details.
