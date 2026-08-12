function Export-TenantIQPortfolioReport {
    param(
        [string]$OutputPath,
        [string]$CustomerName = "Customer",
        [string]$PreparedBy = "TenantIQ"
    )

    $RootPath = Split-Path $PSScriptRoot -Parent
    $DefaultOutputPath = Join-Path $RootPath "06 Output"

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = $DefaultOutputPath
    }

    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    $Workloads = @(
        [pscustomobject]@{ Name = "Exchange Online";       Slug = "ExchangeOnline" },
        [pscustomobject]@{ Name = "Entra ID";              Slug = "EntraID" },
        [pscustomobject]@{ Name = "SharePoint Online";      Slug = "SharePointOnline" },
        [pscustomobject]@{ Name = "Microsoft Teams";        Slug = "MicrosoftTeams" },
        [pscustomobject]@{ Name = "OneDrive";               Slug = "OneDrive" },
        [pscustomobject]@{ Name = "Microsoft Intune";       Slug = "MicrosoftIntune" },
        [pscustomobject]@{ Name = "Microsoft Defender";     Slug = "MicrosoftDefender" },
        [pscustomobject]@{ Name = "Microsoft Purview";      Slug = "MicrosoftPurview" }
    )

    $Snapshots = @()
    foreach ($Workload in $Workloads) {
        $Pattern = "TenantIQ-$($Workload.Slug)-Assessment-*.csv"
        $Latest = Get-ChildItem -Path $OutputPath -Filter $Pattern -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if (-not $Latest) { continue }

        try {
            $Rows = @(Import-Csv -Path $Latest.FullName -ErrorAction Stop)
        }
        catch { continue }

        if ($Rows.Count -eq 0) { continue }

        $PassCount = @($Rows | Where-Object { $_.Status -eq 'PASS' }).Count
        $WarningCount = @($Rows | Where-Object { $_.Status -eq 'WARNING' }).Count
        $FailCount = @($Rows | Where-Object { $_.Status -eq 'FAIL' }).Count
        $InfoCount = @($Rows | Where-Object { $_.Status -eq 'INFO' }).Count
        $TotalCount = $Rows.Count
        $ScoredCount = $PassCount + $WarningCount + $FailCount
        $Score = if ($ScoredCount -gt 0) {
            [math]::Round((($PassCount + ($WarningCount * 0.5)) / $ScoredCount) * 100)
        }
        else { 100 }

        $Snapshots += [pscustomobject]@{
            Workload = $Workload.Name
            File = $Latest.Name
            RunDate = $Latest.LastWriteTime
            Total = $TotalCount
            Pass = $PassCount
            Warning = $WarningCount
            Fail = $FailCount
            Info = $InfoCount
            Score = $Score
            Results = $Rows
        }
    }

    if ($Snapshots.Count -eq 0) {
        Write-Host "No TenantIQ workload assessment CSV files were found in $OutputPath." -ForegroundColor Yellow
        return
    }

    $PortfolioPass = ($Snapshots | Measure-Object -Property Pass -Sum).Sum
    $PortfolioWarning = ($Snapshots | Measure-Object -Property Warning -Sum).Sum
    $PortfolioFail = ($Snapshots | Measure-Object -Property Fail -Sum).Sum
    $PortfolioInfo = ($Snapshots | Measure-Object -Property Info -Sum).Sum
    $PortfolioTotal = ($Snapshots | Measure-Object -Property Total -Sum).Sum
    $PortfolioScored = $PortfolioPass + $PortfolioWarning + $PortfolioFail

    $PortfolioScore = if ($PortfolioScored -gt 0) {
        [math]::Round((($PortfolioPass + ($PortfolioWarning * 0.5)) / $PortfolioScored) * 100)
    }
    else { 100 }

    $RiskLevel = if ($PortfolioFail -gt 0) { 'High Risk' }
        elseif ($PortfolioWarning -gt 0) { 'Needs Attention' }
        else { 'Healthy' }

    $RiskClass = if ($PortfolioFail -gt 0) { 'risk-high' }
        elseif ($PortfolioWarning -gt 0) { 'risk-medium' }
        else { 'risk-low' }

    $AllActionable = @(
        foreach ($Snapshot in $Snapshots) {
            foreach ($Row in @($Snapshot.Results | Where-Object { $_.Status -in @('FAIL','WARNING') })) {
                [pscustomobject]@{
                    Workload = $Snapshot.Workload
                    Status = $Row.Status
                    Check = $Row.Check
                    Severity = $Row.Severity
                    Finding = $Row.Finding
                    Recommendation = $Row.Recommendation
                }
            }
        }
    )

    $SeverityRank = @{ Critical = 1; High = 2; Medium = 3; Low = 4; None = 5 }
    $TopFindings = @(
        $AllActionable |
        Sort-Object @{Expression={ if ($_.Status -eq 'FAIL') { 0 } else { 1 } }}, @{Expression={ if ($SeverityRank.ContainsKey([string]$_.Severity)) { $SeverityRank[[string]$_.Severity] } else { 9 } }} |
        Select-Object -First 12
    )

    $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $HtmlPath = Join-Path $OutputPath "TenantIQ-Portfolio-Assessment-$Timestamp.html"
    $CsvPath = Join-Path $OutputPath "TenantIQ-Portfolio-Assessment-$Timestamp.csv"

    $Snapshots |
        Select-Object Workload,RunDate,Total,Pass,Warning,Fail,Info,Score,File |
        Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

    $EncodedCustomer = [System.Net.WebUtility]::HtmlEncode($CustomerName)
    $EncodedPreparedBy = [System.Net.WebUtility]::HtmlEncode($PreparedBy)

    $WorkloadRows = foreach ($Snapshot in $Snapshots) {
        $Class = if ($Snapshot.Fail -gt 0) { 'score-bad' } elseif ($Snapshot.Warning -gt 0) { 'score-warn' } else { 'score-good' }
        $Name = [System.Net.WebUtility]::HtmlEncode([string]$Snapshot.Workload)
        "<tr><td><strong>$Name</strong></td><td>$($Snapshot.Total)</td><td>$($Snapshot.Pass)</td><td>$($Snapshot.Warning)</td><td>$($Snapshot.Fail)</td><td>$($Snapshot.Info)</td><td class='$Class'>$($Snapshot.Score)%</td><td>$($Snapshot.RunDate.ToString('yyyy-MM-dd HH:mm'))</td></tr>"
    }

    $FindingCards = if ($TopFindings.Count -eq 0) {
        '<div class="empty-state">No FAIL or WARNING findings were present in the latest workload assessments.</div>'
    }
    else {
        foreach ($Finding in $TopFindings) {
            $StatusClass = if ($Finding.Status -eq 'FAIL') { 'finding-fail' } else { 'finding-warning' }
            $Workload = [System.Net.WebUtility]::HtmlEncode([string]$Finding.Workload)
            $Check = [System.Net.WebUtility]::HtmlEncode([string]$Finding.Check)
            $Severity = [System.Net.WebUtility]::HtmlEncode([string]$Finding.Severity)
            $FindingText = [System.Net.WebUtility]::HtmlEncode([string]$Finding.Finding)
            $Recommendation = [System.Net.WebUtility]::HtmlEncode([string]$Finding.Recommendation)
            @"
<div class="finding-card $StatusClass">
  <div class="finding-head"><span class="status-pill">$($Finding.Status)</span><span class="severity">$Severity</span></div>
  <div class="finding-title">$Workload — $Check</div>
  <div class="finding-text">$FindingText</div>
  <div class="recommendation"><strong>Recommended action:</strong> $Recommendation</div>
</div>
"@
        }
    }

    $CoverageText = if ($Snapshots.Count -eq 8) { 'All eight Microsoft 365 workload assessments are represented.' }
        else { "$($Snapshots.Count) of 8 workload assessments were available at report generation time." }

    $ExecutiveText = if ($PortfolioFail -gt 0) {
        "TenantIQ identified $PortfolioFail failing control(s) and $PortfolioWarning warning control(s) across the latest available Microsoft 365 assessments. Immediate attention should begin with FAIL findings, followed by high-severity warnings."
    }
    elseif ($PortfolioWarning -gt 0) {
        "No failing controls were detected. TenantIQ identified $PortfolioWarning warning control(s) that should be reviewed as part of security, governance, and operational hardening."
    }
    else {
        "No failing or warning controls were detected in the latest available workload assessments. Continue periodic review to maintain the current posture."
    }

    $Generated = Get-Date -Format 'MMMM dd, yyyy hh:mm tt'

    $Html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>TenantIQ Microsoft 365 Assessment - $EncodedCustomer</title>
<style>
:root{--navy:#0b1220;--slate:#334155;--muted:#64748b;--line:#e2e8f0;--bg:#f5f7fb;--white:#fff;--blue:#2563eb;--green:#15803d;--amber:#b45309;--red:#b91c1c}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:#1e293b;font-family:"Segoe UI",Arial,sans-serif;line-height:1.5}.hero{background:linear-gradient(135deg,#0b1220,#172554);color:#fff;padding:42px 28px}.wrap{max-width:1180px;margin:0 auto}.brand-row{display:flex;justify-content:space-between;gap:24px;align-items:flex-start;flex-wrap:wrap}.brand{font-size:34px;font-weight:800;letter-spacing:-.5px}.eyebrow{text-transform:uppercase;letter-spacing:1.4px;font-size:12px;font-weight:700;opacity:.72}.subtitle{font-size:18px;margin-top:8px;opacity:.9}.hero-score{text-align:right}.hero-score .label{font-size:12px;text-transform:uppercase;letter-spacing:1px;opacity:.7}.hero-score .value{font-size:48px;font-weight:800}.risk-badge{display:inline-block;margin-top:8px;padding:7px 12px;border-radius:999px;font-weight:700;font-size:13px}.risk-high{background:#fee2e2;color:#991b1b}.risk-medium{background:#fef3c7;color:#92400e}.risk-low{background:#dcfce7;color:#166534}.meta-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px;margin-top:28px}.meta-item{background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.1);border-radius:12px;padding:12px 14px}.meta-label{font-size:11px;text-transform:uppercase;letter-spacing:.8px;opacity:.65}.meta-value{font-weight:600;margin-top:3px}.content{padding:28px 22px 50px}.section{background:#fff;border:1px solid var(--line);border-radius:16px;padding:24px;margin-bottom:22px;box-shadow:0 8px 28px rgba(15,23,42,.05)}h2{margin:0 0 8px;font-size:22px}h3{margin:0}.section-sub{color:var(--muted);margin:0 0 18px}.metric-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}.metric{border:1px solid var(--line);border-radius:14px;padding:16px;background:#fafcff}.metric .num{font-size:29px;font-weight:800}.metric .lab{font-size:12px;text-transform:uppercase;letter-spacing:.7px;color:var(--muted);margin-top:3px}.executive{font-size:16px;color:#334155}.coverage{margin-top:12px;padding:12px 14px;border-radius:10px;background:#eff6ff;color:#1e40af}.table-wrap{overflow-x:auto}table{width:100%;border-collapse:collapse;font-size:14px}th,td{text-align:left;padding:11px 10px;border-bottom:1px solid var(--line);vertical-align:top}th{font-size:12px;text-transform:uppercase;letter-spacing:.5px;color:#475569;background:#f8fafc}.score-good{color:var(--green);font-weight:800}.score-warn{color:var(--amber);font-weight:800}.score-bad{color:var(--red);font-weight:800}.findings{display:grid;gap:12px}.finding-card{border:1px solid var(--line);border-left-width:5px;border-radius:12px;padding:16px;background:#fff}.finding-fail{border-left-color:var(--red)}.finding-warning{border-left-color:var(--amber)}.finding-head{display:flex;gap:8px;align-items:center;margin-bottom:8px}.status-pill{font-size:11px;font-weight:800;padding:4px 8px;border-radius:999px;background:#e2e8f0}.severity{font-size:12px;color:var(--muted)}.finding-title{font-size:16px;font-weight:750;margin-bottom:6px}.finding-text{color:#475569}.recommendation{margin-top:10px;padding-top:10px;border-top:1px solid var(--line);color:#334155}.empty-state{padding:16px;border-radius:12px;background:#f0fdf4;color:#166534}.footer{color:#64748b;font-size:12px;padding:0 22px 34px;text-align:center}.print-note{margin-top:8px}@media print{body{background:#fff}.hero{padding:26px}.content{padding:18px}.section{box-shadow:none;break-inside:avoid}.finding-card{break-inside:avoid}.footer{padding-bottom:0}}
</style>
</head>
<body>
<header class="hero">
  <div class="wrap">
    <div class="brand-row">
      <div>
        <div class="eyebrow">Microsoft 365 Security & Governance Assessment</div>
        <div class="brand">TenantIQ Executive Assessment</div>
        <div class="subtitle">Customer-facing portfolio summary across the latest available workload assessments</div>
      </div>
      <div class="hero-score">
        <div class="label">Portfolio posture score</div>
        <div class="value">$PortfolioScore%</div>
        <div class="risk-badge $RiskClass">$RiskLevel</div>
      </div>
    </div>
    <div class="meta-grid">
      <div class="meta-item"><div class="meta-label">Customer</div><div class="meta-value">$EncodedCustomer</div></div>
      <div class="meta-item"><div class="meta-label">Prepared By</div><div class="meta-value">$EncodedPreparedBy</div></div>
      <div class="meta-item"><div class="meta-label">Generated</div><div class="meta-value">$Generated</div></div>
      <div class="meta-item"><div class="meta-label">Coverage</div><div class="meta-value">$($Snapshots.Count) / 8 workloads</div></div>
    </div>
  </div>
</header>
<main class="content"><div class="wrap">
  <section class="section">
    <h2>Executive Summary</h2>
    <p class="executive">$ExecutiveText</p>
    <div class="coverage">$CoverageText INFO findings are retained as contextual evidence and excluded from scored-control math.</div>
  </section>

  <section class="section">
    <h2>Assessment Snapshot</h2>
    <p class="section-sub">Consolidated control outcomes from the latest workload CSVs available in TenantIQ.</p>
    <div class="metric-grid">
      <div class="metric"><div class="num">$PortfolioTotal</div><div class="lab">Total Controls</div></div>
      <div class="metric"><div class="num">$PortfolioPass</div><div class="lab">Pass</div></div>
      <div class="metric"><div class="num">$PortfolioWarning</div><div class="lab">Warning</div></div>
      <div class="metric"><div class="num">$PortfolioFail</div><div class="lab">Fail</div></div>
      <div class="metric"><div class="num">$PortfolioInfo</div><div class="lab">Info</div></div>
      <div class="metric"><div class="num">$PortfolioScored</div><div class="lab">Scored Controls</div></div>
    </div>
  </section>

  <section class="section">
    <h2>Workload Posture</h2>
    <p class="section-sub">Score formula: PASS = full credit, WARNING = half credit, FAIL = no credit, INFO = unscored context.</p>
    <div class="table-wrap"><table><thead><tr><th>Workload</th><th>Total</th><th>PASS</th><th>WARNING</th><th>FAIL</th><th>INFO</th><th>Score</th><th>Latest Run</th></tr></thead><tbody>$($WorkloadRows -join "`n")</tbody></table></div>
  </section>

  <section class="section">
    <h2>Priority Findings</h2>
    <p class="section-sub">Highest-priority FAIL and WARNING findings, ordered for remediation review.</p>
    <div class="findings">$($FindingCards -join "`n")</div>
  </section>

  <section class="section">
    <h2>Recommended Next Steps</h2>
    <p>1. Address FAIL findings first, beginning with critical and high-severity controls.</p>
    <p>2. Review WARNING findings for policy, security, governance, and lifecycle improvement opportunities.</p>
    <p>3. Validate INFO findings where licensing, API coverage, or tenant applicability may affect interpretation.</p>
    <p>4. Re-run TenantIQ after remediation to document posture improvement and establish a repeatable assessment baseline.</p>
  </section>
</div></main>
<footer class="footer">TenantIQ assessment output is intended to support Microsoft 365 review and remediation planning. Validate recommendations against organizational requirements before making production changes.<div class="print-note">Tip: use your browser Print command to save this report as PDF.</div></footer>
</body>
</html>
"@

    Set-Content -Path $HtmlPath -Value $Html -Encoding UTF8

    Write-Host ""
    Write-Host "TenantIQ customer-facing portfolio report generated." -ForegroundColor Green
    Write-Host "HTML: $HtmlPath" -ForegroundColor Cyan
    Write-Host "CSV : $CsvPath" -ForegroundColor Cyan

    [pscustomobject]@{
        HtmlPath = $HtmlPath
        CsvPath = $CsvPath
        Score = $PortfolioScore
        Workloads = $Snapshots.Count
        TotalControls = $PortfolioTotal
        Pass = $PortfolioPass
        Warning = $PortfolioWarning
        Fail = $PortfolioFail
        Info = $PortfolioInfo
    }
}
