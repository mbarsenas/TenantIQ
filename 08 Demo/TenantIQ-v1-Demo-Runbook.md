# TenantIQ v1.0 Demo & YouTube Runbook

This runbook defines the customer-facing TenantIQ v1.0 product demonstration. The assessment engine is treated as frozen during recording.

## Demo Objective

Show a Microsoft 365 administrator or decision-maker how TenantIQ moves from tenant evidence to actionable assessment findings and an executive portfolio report.

Core message:

> TenantIQ provides a repeatable, read-only assessment of Microsoft 365 configuration, security, governance, and operational posture across eight workloads and 416 registered controls.

## Target Video Length

Approximately 5-7 minutes.

## Recording Safety

Before recording:

- Use a demo/test Microsoft 365 tenant only.
- Hide email addresses, tenant IDs, user principal names, subscription IDs, access tokens, browser profiles, and other customer-identifying information.
- Close unrelated applications and notifications.
- Do not record passwords or MFA approval details.
- Use the packaged TenantIQ v1.0 build rather than the development working tree.
- Have a completed Portfolio Report ready before recording so the final report segment is predictable.

## Scene 1 - Opening / AI Presenter

Target: 20-30 seconds.

Visual:

- TenantIQ logo/product branding.
- AI presenter on a clean technology-themed background.
- Optional brief animation showing Microsoft 365 workload names.

Narration:

"Microsoft 365 environments grow quickly, and understanding configuration, security, governance, and operational posture across the entire tenant can require hours of manual investigation. TenantIQ was built to make that assessment repeatable. TenantIQ evaluates eight Microsoft 365 workloads using 416 registered controls and converts the evidence into technical findings and an executive portfolio report."

On-screen text:

- 8 Microsoft 365 workloads
- 416 registered controls
- Read-only assessment
- Evidence-driven findings

## Scene 2 - Launch TenantIQ

Target: 30-45 seconds.

Visual:

Open PowerShell 7 in the extracted customer package and run:

```powershell
.\Start-TenantIQ.ps1
```

Show prerequisite validation briefly, then the main menu.

Narration:

"TenantIQ runs from PowerShell 7 and validates its required Microsoft administrative dependencies before the assessment platform opens. The customer-facing menu provides assessments for Exchange Online, Entra ID, SharePoint Online, Teams, OneDrive, Intune, Defender, and Purview."

Pause on the menu long enough for viewers to see the eight workloads.

## Scene 3 - Explain the Assessment Model

Target: 30 seconds.

Visual:

Main TenantIQ menu.

Narration:

"TenantIQ is designed as an assessment and reporting platform. It collects supported administrative evidence and evaluates registered controls. It does not automatically remediate or change Microsoft 365 configuration. Recommendations remain subject to the customer's architecture, security requirements, licensing, and change-management process."

On-screen text:

READ-ONLY ASSESSMENT

## Scene 4 - Run a Workload Assessment

Target: 60-90 seconds.

Recommended demo workload: Entra ID.

Visual:

Select:

```text
2
```

Show Microsoft authentication only after ensuring no sensitive account information will be exposed.

Then show several assessment controls progressing. Do not make the viewer watch the entire run in real time. Use an edit/cut or speed-up between early progress and completion.

Narration:

"Each workload establishes the Microsoft authentication context it needs, collects supported tenant evidence, and evaluates its registered controls. Entra ID contains 66 controls in TenantIQ v1.0. Other workloads contain 50 controls each. Some workloads intentionally use isolated PowerShell processes to avoid conflicts between Microsoft authentication libraries."

## Scene 5 - Explain Results

Target: 45-60 seconds.

Visual:

Show completed assessment output or a sanitized workload CSV/report view.

Narration:

"TenantIQ standardizes results into PASS, WARNING, FAIL, INFO, and NOT EVALUATED. PASS, WARNING, and FAIL contribute to posture scoring. INFO and NOT EVALUATED remain visible as contextual evidence without distorting the score. A FAIL represents a tenant finding, not a failure of the TenantIQ application itself."

On-screen text:

- PASS = full credit
- WARNING = half credit
- FAIL = no credit
- INFO / NOT EVALUATED = unscored context

## Scene 6 - Show a Real Finding

Target: 45-60 seconds.

Recommended finding: sanitized Entra ID MFA Registration finding from the demo tenant.

Visual:

Show the finding, evidence, and recommended action without exposing user identities.

Narration:

"The value is not simply a red or green status. TenantIQ retains the finding, supporting evidence, severity, and recommended action where available. Here, the assessment identified an MFA registration coverage gap. This gives the administrator a concrete condition to investigate and a remediation direction while leaving the actual production change under administrator control."

## Scene 7 - Generate the Portfolio Report

Target: 30-45 seconds.

Visual:

Return to the main menu and select:

```text
9
```

Show the generated HTML and CSV paths.

Narration:

"After the workload assessments are complete, TenantIQ consolidates the latest results into a customer-facing Portfolio Report. This provides a single view across all eight supported Microsoft 365 workloads."

## Scene 8 - Executive Assessment

Target: 60-90 seconds.

Visual sequence:

1. TenantIQ Executive Assessment header.
2. Portfolio posture score and label.
3. Assessment Snapshot.
4. Workload Posture table.
5. Priority Findings.
6. Recommended Next Steps.

Narration:

"The executive assessment summarizes overall posture, assessment coverage, scored and unscored controls, and individual workload posture. Priority findings bring the most important FAIL and WARNING results forward for remediation review. The report then provides recommended next steps so the assessment can become part of a repeatable improvement cycle."

## Scene 9 - Closing / AI Presenter

Target: 20-30 seconds.

Visual:

Return to AI presenter with TenantIQ branding and website/product CTA.

Narration:

"TenantIQ turns Microsoft 365 assessment evidence into a repeatable technical and executive view of tenant posture. Eight workloads. Four hundred sixteen registered controls. One consolidated assessment workflow. TenantIQ."

Suggested on-screen CTA:

TenantIQ
Microsoft 365 Assessment Platform

## Recording Shot List

Capture these clips separately so editing is easier:

1. Clean TenantIQ main-menu launch.
2. Startup prerequisite validation.
3. Main menu static shot.
4. Entra ID selection.
5. Authentication transition with sensitive information hidden.
6. First 5-10 assessment controls running.
7. Later assessment progress.
8. Completed workload summary.
9. Sanitized MFA finding/evidence.
10. Portfolio Report generation from option 9.
11. Executive Assessment header and score.
12. Assessment Snapshot.
13. Workload Posture table.
14. Priority Findings.
15. Recommended Next Steps.
16. Clean closing product shot.

## Editing Guidance

- Record console footage at 1080p or higher.
- Keep the TenantIQ console large enough for control names to remain readable on YouTube.
- Cut dead authentication/loading time.
- Speed up long assessment sequences rather than implying they complete instantly.
- Use subtle zooms when moving from Portfolio Score to Workload Posture to Priority Findings.
- Never zoom into customer-identifying evidence.
- Keep background music below narration.
- Use captions for technical terms such as Entra ID, Microsoft Graph, MFA, and Purview.

## Suggested YouTube Title

TenantIQ Demo - Microsoft 365 Assessment Across 8 Workloads and 416 Controls

## Suggested Description

TenantIQ is a read-only Microsoft 365 assessment platform that evaluates configuration, security, governance, and operational posture across Exchange Online, Entra ID, SharePoint Online, Microsoft Teams, OneDrive, Microsoft Intune, Microsoft Defender, and Microsoft Purview.

TenantIQ v1.0 contains 416 registered controls and produces workload-level findings plus a consolidated executive Portfolio Report.

This video demonstrates the TenantIQ assessment workflow using a test Microsoft 365 tenant. No customer credentials or production tenant information are shown.

## Suggested Chapters

00:00 What is TenantIQ?
00:30 Starting TenantIQ
01:00 Microsoft 365 workload coverage
01:30 Running an assessment
03:00 Understanding findings
04:00 Portfolio Report
05:15 Executive assessment
06:15 Closing

## Thumbnail Copy

Primary:

MICROSOFT 365
416 CHECKS
ONE ASSESSMENT

Alternative:

HOW HEALTHY IS YOUR
MICROSOFT 365 TENANT?

## Demo Acceptance Criteria

The final video should visibly demonstrate:

- TenantIQ v1.0 branding.
- PowerShell 7 startup.
- Eight workload menu.
- 416-control product coverage statement.
- At least one real workload assessment.
- A real sanitized finding with evidence/recommendation.
- Portfolio Report generation.
- Executive posture score.
- Workload posture.
- Priority findings.
- Recommended next steps.
- Read-only assessment positioning.

Do not modify assessment controls solely to make the demo look better. The demo must represent the validated TenantIQ v1.0 product.
