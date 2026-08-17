# TenantIQ Changelog

## 1.1.0 — Production

Stabilization and customer-package refresh based on the latest validated TenantIQ assessment engine.

### Licensed tenant allowance

- Enforces the signed `MaxTenants` allowance before workload assessments begin.
- Essentials permits one registered Microsoft 365 tenant; Professional permits up to five.
- Reassessing a registered tenant does not consume another tenant slot.
- The same centralized guard covers all eight workload launch paths without changing assessment controls.
- The main menu displays the registered tenant count, and release validation runs a six-case allowance self-test.

### Runtime and assessment stability

- Preserves 416 registered controls across all 8 Microsoft 365 workloads.
- Includes the corrected Microsoft Defender preset-security policy evaluation.
- Includes the latest isolated workload execution fixes used to reduce Microsoft Graph and Exchange Online authentication conflicts.
- Includes stabilized submenu navigation and launcher behavior.
- Includes the current PowerShell integrity protections validated before packaging.

### Release validation

- Customer package continues to require release-package validation before delivery.
- Customer package continues to require release-candidate smoke testing before delivery.
- Package metadata, SHA256 manifest, ZIP sidecar hash, signed-license public key, and version metadata are verified during the build.

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
