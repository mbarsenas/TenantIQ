# TenantIQ Quick Start

TenantIQ is a read-only Microsoft 365 assessment platform covering eight workloads and 416 registered controls.

## 1. Requirements

Use a Windows administrative workstation with PowerShell 7 or later.

Check PowerShell:

```powershell
$PSVersionTable.PSVersion
```

## 2. Install PowerShell prerequisites

From the TenantIQ directory, run:

```powershell
.\Install-TenantIQPrerequisites.ps1
```

To also install the optional PnP.PowerShell dependency:

```powershell
.\Install-TenantIQPrerequisites.ps1 -IncludeOptional
```

The installer uses CurrentUser scope and installs only missing modules.

## 3. Start TenantIQ

```powershell
.\Start-TenantIQ.ps1
```

The launcher validates the runtime and required PowerShell modules before opening the product.

## 4. Run assessments

Run the Microsoft 365 workloads from the main menu:

1. Exchange Online - 50 controls
2. Entra ID - 66 controls
3. SharePoint Online - 50 controls
4. Microsoft Teams - 50 controls
5. OneDrive - 50 controls
6. Microsoft Intune - 50 controls
7. Microsoft Defender - 50 controls
8. Microsoft Purview - 50 controls

Complete Microsoft authentication when prompted. Some workloads use isolated PowerShell processes, so multiple sign-in prompts during a complete tenant assessment are expected.

## 5. Generate the executive report

After running the desired workloads, select:

```text
[9] Portfolio Report
```

TenantIQ uses the latest available workload CSV for each supported workload and generates a consolidated HTML executive assessment plus CSV summary under `06 Output`.

## Result scoring

Scored controls:

- PASS = full credit
- WARNING = half credit
- FAIL = no credit

INFO and NOT EVALUATED are retained as unscored context.

Portfolio posture labels:

- 90-100: Strong Posture
- 75-89: Needs Attention
- 60-74: Elevated Risk
- 0-59: High Risk

## Output

Assessment and portfolio files are written under:

```text
06 Output
```

Do not mix workload CSV files from different Microsoft 365 tenants in the same output set before generating a Portfolio Report.

## Help

Use menu option `[10] Help / Documentation` for prerequisites, connections, assessments, result interpretation, reporting, and troubleshooting guidance.

TenantIQ recommendations are assessment guidance. Validate findings against customer architecture, licensing, exceptions, security requirements, and change-management procedures before making production configuration changes.
