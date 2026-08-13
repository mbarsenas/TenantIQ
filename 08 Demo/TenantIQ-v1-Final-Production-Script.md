# TenantIQ v1.0 — Final Demo Production Script

**Runtime target:** 6:00–6:30  
**Format:** 16:9, 1920x1080 or higher, 30 fps  
**Product baseline:** TenantIQ v1.0 validated build  
**Coverage:** 416 registered controls across 8 Microsoft 365 workloads

This is the production script. Record the TenantIQ screen clips exactly as described, then assemble them with the AI-presenter intro/outro.

---

## 00:00–00:25 — AI Presenter Opening

### Picture
AI presenter centered on the TenantIQ dark technology background. TenantIQ logo appears beside the presenter.

### On-screen copy

**TenantIQ**  
Microsoft 365 Assessment Platform

**416 Controls · 8 Workloads · Read-Only Assessment**

### Voiceover

Microsoft 365 is powerful, but understanding security, configuration, governance, and operational posture across an entire tenant can take hours of manual investigation. TenantIQ makes that assessment repeatable. It evaluates eight Microsoft 365 workloads using four hundred sixteen registered controls and turns the evidence into technical findings and an executive assessment.

### Transition
Logo sting or quick dissolve into PowerShell.

---

## 00:25–00:55 — Start TenantIQ

### Capture
Use the packaged TenantIQ v1.0 build.

Open PowerShell 7 and run:

```powershell
.\Start-TenantIQ.ps1
```

Capture the Environment Validation screen for approximately 4 seconds, then cut to the clean main menu.

### Voiceover

TenantIQ runs from PowerShell 7. At startup, it validates the Microsoft administrative dependencies required by the platform before opening the assessment menu.

### Overlay while main menu is visible

**8 Microsoft 365 Workloads**

Exchange Online · Entra ID · SharePoint Online · Microsoft Teams · OneDrive · Microsoft Intune · Microsoft Defender · Microsoft Purview

---

## 00:55–01:25 — Product Coverage

### Picture
Hold on the real TenantIQ main menu. Slowly zoom toward the workload list.

### Voiceover

TenantIQ v1.0 assesses Exchange Online, Entra ID, SharePoint Online, Microsoft Teams, OneDrive, Microsoft Intune, Microsoft Defender, and Microsoft Purview. Entra ID contains sixty-six registered controls, with fifty controls in each of the other seven workloads, for a total of four hundred sixteen.

### Overlay

**416 REGISTERED CONTROLS**

- Exchange Online — 50
- Entra ID — 66
- SharePoint Online — 50
- Teams — 50
- OneDrive — 50
- Intune — 50
- Defender — 50
- Purview — 50

---

## 01:25–01:50 — Read-Only Positioning

### Picture
Remain on the main menu or use a clean TenantIQ branded interstitial.

### Voiceover

TenantIQ is an assessment and reporting platform. It reads supported Microsoft 365 administrative evidence and evaluates that evidence against registered controls. It does not automatically remediate or modify the customer's tenant.

### Overlay

**READ-ONLY ASSESSMENT**  
Evidence → Analysis → Findings → Recommendations

---

## 01:50–02:50 — Run Entra ID Assessment

### Capture
From the main menu enter:

```text
2
```

Capture the beginning of the Entra ID assessment.

Do not expose account names, email addresses, tenant IDs, MFA approval screens, tokens, or browser profile information.

Record approximately 10 seconds of early controls. Cut ahead to later controls. Use a 4x–8x speed ramp for a short middle sequence if desired. End on the completed assessment summary/output.

### Voiceover

Let's look at Entra ID. TenantIQ establishes the required Microsoft authentication context, collects supported tenant evidence, and evaluates sixty-six Entra ID controls. The controls cover areas such as identity configuration, authentication, access, governance, applications, and security posture. Long-running collection is shown here at increased speed; the underlying assessment is running normally.

### Small lower-third

**Entra ID Assessment · 66 Controls**

---

## 02:50–03:25 — Result Model

### Picture
Use sanitized assessment output or a sanitized CSV/result view.

### Voiceover

Every control is normalized into a standard result model. PASS means the evaluated configuration met the control criteria. WARNING identifies something that deserves review. FAIL identifies a condition that did not meet the criteria. INFO and NOT EVALUATED retain useful context or evidence limitations without artificially changing the posture score.

### Overlay

PASS = Full Credit  
WARNING = Half Credit  
FAIL = No Credit  
INFO / NOT EVALUATED = Unscored Context

---

## 03:25–04:00 — Real MFA Finding

### Picture
Show the sanitized Entra ID MFA Registration finding from the validated demo assessment. Hide identities; show only aggregate evidence.

Use the validated finding wording/data available in the current demo output rather than fabricating a new value.

### Voiceover

Here's an example from the assessment. TenantIQ identified an MFA registration coverage gap among member accounts. Instead of showing only a red status, TenantIQ provides the finding, supporting evidence, severity, and a recommended action. That gives the administrator something concrete to investigate while leaving remediation under the customer's change-control process.

### Overlay

**Finding → Evidence → Recommendation**

---

## 04:00–04:25 — Generate Portfolio Report

### Capture
Return to the main menu and enter:

```text
9
```

Capture the real report-generation output showing HTML and CSV creation.

### Voiceover

Once workload assessments are available, option nine builds the TenantIQ Portfolio Report. TenantIQ selects the latest available assessment for each workload and consolidates the results into an executive HTML report and supporting CSV.

---

## 04:25–05:35 — Executive Assessment Walkthrough

### Picture sequence
Use the actual validated TenantIQ Executive Assessment.

Show each section for 8–12 seconds:

1. Header and Portfolio Posture Score.
2. Coverage: 8 / 8 workloads.
3. Assessment Snapshot.
4. Workload Posture table.
5. Priority Findings.
6. Recommended Next Steps.

### Voiceover

The Portfolio Report turns the workload results into a single executive view. At the top is the overall portfolio posture and assessment coverage. The Assessment Snapshot separates total controls, scored outcomes, and unscored contextual evidence. Workload Posture makes it easy to see where attention is concentrated across Microsoft 365. Priority Findings then brings the most important failures and warnings forward, with supporting recommendations. Finally, Recommended Next Steps provides a practical remediation sequence and encourages reassessment after approved changes are made.

### Overlay during Snapshot

**416 Total Controls**

Use the actual current report values for PASS, WARNING, FAIL, INFO, scored controls, and posture score. Do not hard-code old values into the video if a new assessment has changed them.

---

## 05:35–05:55 — Repeatable Assessment Message

### Picture
Slow pan/scroll across Priority Findings into Recommended Next Steps.

### Voiceover

That creates a repeatable assessment cycle: collect current evidence, identify risk, prioritize remediation, make approved changes, and run TenantIQ again to document posture improvement.

### Overlay

**Assess → Prioritize → Remediate → Reassess**

---

## 05:55–06:20 — AI Presenter Closing

### Picture
Return to AI presenter and TenantIQ branding.

### Voiceover

TenantIQ turns Microsoft 365 complexity into a structured, evidence-driven assessment. Eight workloads. Four hundred sixteen registered controls. Technical findings for administrators and one consolidated view for decision-makers. TenantIQ — Microsoft 365 assessment with clarity.

### Final card

**TenantIQ**  
Microsoft 365 Assessment Platform

**416 Controls · 8 Workloads · One Portfolio View**

`tenantiq365.com`

---

# Exact Screen Captures Needed

Record these as individual clips. Do not try to record the entire demo in one take.

1. `01-startup-validation.mp4` — Start-TenantIQ.ps1 and dependency validation.
2. `02-main-menu.mp4` — clean static main menu.
3. `03-entra-start.mp4` — select option 2 and begin Entra assessment.
4. `04-entra-progress.mp4` — controls running with no sensitive data visible.
5. `05-entra-complete.mp4` — completed assessment/output.
6. `06-mfa-finding.mp4` — sanitized MFA finding/evidence/recommendation.
7. `07-portfolio-generate.mp4` — option 9 and generated HTML/CSV paths.
8. `08-report-header.mp4` — Executive Assessment header, posture, 8/8 coverage.
9. `09-report-snapshot.mp4` — Assessment Snapshot.
10. `10-workload-posture.mp4` — Workload Posture table.
11. `11-priority-findings.mp4` — Priority Findings.
12. `12-next-steps.mp4` — Recommended Next Steps.

# Capture Rules

- 1920x1080 minimum.
- 30 fps is sufficient.
- Keep PowerShell text large and readable.
- Disable desktop notifications.
- Close email, Teams, browsers, and unrelated terminals unless required for the shot.
- Never show a password, access token, refresh token, client secret, tenant ID, private customer domain, or identifiable user list.
- Crop or blur Microsoft authentication screens if necessary.
- Do not modify a TenantIQ control merely to create a prettier demo result.
- Use the validated packaged v1.0 build.

# AI Presenter Direction

Presenter style: professional Microsoft/cloud technology spokesperson; approachable rather than sales-heavy.

Wardrobe: dark charcoal or black quarter-zip/polo with subtle TenantIQ branding.

Background: dark navy technology environment with restrained cyan/green TenantIQ accents.

Delivery: confident, technical, conversational; approximately 145–155 words per minute.

Use the presenter only for the opening and closing. The center of the video should show the real TenantIQ product.

# YouTube Publication Package

## Title

**TenantIQ Demo: Assess Microsoft 365 Across 8 Workloads and 416 Controls**

## Description

TenantIQ is a read-only Microsoft 365 assessment platform designed to evaluate configuration, security, governance, and operational posture across eight Microsoft 365 workloads.

TenantIQ v1.0 includes 416 registered controls across Exchange Online, Entra ID, SharePoint Online, Microsoft Teams, OneDrive, Microsoft Intune, Microsoft Defender, and Microsoft Purview.

In this demo, you'll see TenantIQ launch, run a real workload assessment, identify an actionable identity finding, and consolidate workload results into the TenantIQ Executive Assessment and Portfolio Report.

TenantIQ does not automatically remediate Microsoft 365 configuration. Findings and recommendations are designed for administrator review and established change-management processes.

Learn more: tenantiq365.com

## Chapters

00:00 TenantIQ overview
00:25 Starting TenantIQ
00:55 8-workload coverage
01:25 Read-only assessment model
01:50 Entra ID assessment
02:50 Understanding TenantIQ results
03:25 MFA finding example
04:00 Generating the Portfolio Report
04:25 Executive Assessment walkthrough
05:35 Repeatable assessment cycle
05:55 TenantIQ closing

## Thumbnail

Main copy:

**416 MICROSOFT 365 CHECKS**  
**ONE ASSESSMENT**

Secondary badge:

**8 WORKLOADS**

Use the TenantIQ logo and a cropped view of the Executive Assessment posture panel. Avoid tiny console text on the thumbnail.

# Final QA Before Upload

- Every product-count reference says 416, not 350+.
- Every workload-count reference says 8.
- The video uses the packaged validated v1.0 build.
- No credentials or tenant-identifying data are visible.
- No customer production data is visible.
- Portfolio numbers shown in narration match the report visible on screen.
- Captions spell Entra ID, Intune, Defender, Purview, SharePoint, and TenantIQ correctly.
- Website CTA is `tenantiq365.com`.
- Audio is clear on phone speakers as well as headphones.
- Final export is 1080p or higher.
