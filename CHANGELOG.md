# TenantIQ Changelog

## 1.0.0 — Production

Initial validated TenantIQ production baseline.

### Assessment coverage

- 416 registered controls across 8 Microsoft 365 workloads.
- Exchange Online — 50 controls.
- Entra ID — 66 controls.
- SharePoint Online — 50 controls.
- Microsoft Teams — 50 controls.
- OneDrive — 50 controls.
- Microsoft Intune — 50 controls.
- Microsoft Defender — 50 controls.
- Microsoft Purview — 50 controls.

### Reporting

- Standardized PASS, WARNING, FAIL, INFO, and NOT EVALUATED result model.
- Workload CSV exports.
- Executive Portfolio Report in HTML and CSV formats.
- Portfolio scoring based on scored controls only.
- Priority findings and recommended next steps.

### Runtime and authentication

- PowerShell 7+ customer launcher.
- Prerequisite validation.
- Isolated workload execution where required to reduce Microsoft authentication-library conflicts.
- Guided first-run onboarding.

### Packaging

- Customer prerequisite installer.
- Customer package builder.
- Quick Start and customer README documentation.
- Complete Help Center documentation.
- Demo and YouTube production runbooks.

### Release management

- Version metadata stored in TenantIQ.json.
- Get-TenantIQVersion.ps1 for support/build identification.
- Set-TenantIQVersion.ps1 for controlled semantic-version updates.
- Customer packages include PACKAGE-INFO.json and build integrity metadata.
