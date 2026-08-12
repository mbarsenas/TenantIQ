function Export-TenantIQPortfolioReport {
    param(
        [string]$OutputPath
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

        if (-not $Latest) {
            continue
        }

        try {
            $Rows = @(Import-Csv -Path $Latest.FullName -ErrorAction Stop)
        }
        catch {
            continue
        }

        if ($Rows.Count -eq 0) {
            continue
        }

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
            Workload     = $Workload.Name
            File         = $Latest.Name
            RunDate      = $Latest.LastWriteTime
            Total        = $TotalCount
            Pass         = $PassCount
            Warning      = $WarningCount
            Fail         = $FailCount
            Info         = $InfoCount
            Score        = $Score
            Results      = $Rows
        }
    }

    if ($Snapshots.Count -eq 0) {
        Write-Host "No TenantIQ workload assessment CSV files were found in $OutputPath." -ForegroundColor Yellow
        return
    }

    $PortfolioScored = ($Snapshots | Measure-Object -Property Pass -Sum).Sum +
        ($Snapshots | Measure-Object -Property Warning -Sum).Sum +
        ($Snapshots | Measure-Object -Property Fail -Sum).Sum

    $PortfolioPass = ($Snapshots | Measure-Object -Property Pass -Sum).Sum
    $PortfolioWarning = ($Snapshots | Measure-Object -Property Warning -Sum).Sum
    $PortfolioFail = ($Snapshots | Measure-Object -Property Fail -Sum).Sum
    $PortfolioInfo = ($Snapshots | Measure-Object -Property Info -Sum).Sum
    $PortfolioTotal = ($Snapshots | Measure-Object -Property Total -Sum).Sum

    $PortfolioScore = if ($PortfolioScored -gt 0) {
        [math]::Round((($PortfolioPass + ($PortfolioWarning * 0.5)) / $PortfolioScored) * 100)
    }
    else { 100 }

    $RiskLevel = if ($PortfolioFail -gt 0) { 'High Risk' }
        elseif ($PortfolioWarning -gt 0) { 'Needs Attention' }
        else { 'Healthy' }

    $CriticalFindings = @(
        foreach ($Snapshot in $Snapshots) {
            foreach ($Row in @($Snapshot.Results | Where-Object { $_.Status -eq 'FAIL' })) {
                [pscustomobject]@{
                    Workload = $Snapshot.Workload
                    Check = $Row.Check
                    Severity = $Row.Severity
                    Finding = $Row.Finding
                    Recommendation = $Row.Recommendation
                }
            }
        }
    )

    $WarningFindings = @(
        foreach ($Snapshot in $Snapshots) {
            foreach ($Row in @($Snapshot.Results | Where-Object { $_.Status -eq 'WARNING' })) {
                [pscustomobject]@{
                    Workload = $Snapshot.Workload
                    Check = $Row.Check
                    Severity = $Row.Severity
                    Finding = $Row.Finding
                    Recommendation = $Row.Recommendation
                }
            }
        }
    )

    $TopFindings = @($CriticalFindings + $WarningFindings | Select-Object -First 15)

    $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $HtmlPath = Join-Path $OutputPath "TenantIQ-Portfolio-Assessment-$Timestamp.html"
    $CsvPath = Join-Path $OutputPath "TenantIQ-Portfolio-Assessment-$Timestamp.csv"

    $Snapshots |
        Select-Object Workload,RunDate,Total,Pass,Warning,Fail,Info,Score,File |
        Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

    $WorkloadRows = foreach ($Snapshot in $Snapshots) {
        $Class = if ($Snapshot.Fail -gt 0) { 'bad' } elseif ($Snapshot.Warning -gt 0) { 'warn' } else { 'good' }
        "<tr><td>$([System.Net.WebUtility]::HtmlEncode($Snapshot.Workload))</td><td>$($Snapshot.Total)</td><td>$($Snapshot.Pass)</td><td>$($Snapshot.Warning)</td><td>$($Snapshot.Fail)</td><td>$($Snapshot.Info)</td><td class='$Class'>$($Snapshot.Score)%</td><td>$($Snapshot.RunDate.ToString('yyyy-MM-dd HH:mm'))</td></tr>"
    }

    $FindingRows = if ($TopFindings.Count -eq 0) {
        '<tr><td colspan="5">No FAIL or WARNING findings were present in the latest workload assessments.</td></tr>'
    }
    else {
        foreach ($Finding in $TopFindings) {
            $Status = if ($CriticalFindings -contains $Finding) { 'FAIL' } else { 'WARNING' }
            "<tr><td>$Status</td><td>$([System.Net.WebUtility]::HtmlEncode([string]$Finding.Workload))</td><td>$([System.Net.WebUtility]::HtmlEncode([string]$Finding.Check))</td><td>$([System.Net.WebUtility]::HtmlEncode([string]$Finding.Finding))</td><td>$([System.Net.WebUtility]::HtmlEncode([string]$Finding.Recommendation))</td></tr>"
        }
    }

    $Generated = Get-Date -Format 'MMMM dd, yyyy hh:mm tt'
    $Html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>TenantIQ Portfolio Assessment</title>
<style>
body{margin:0;background:#f4f7fb;color:#1f2937;font-family:"Segoe UI",Arial,sans-serif}.header{background:#0f172a;color:white;padding:28px 40px}.wrap{max-width:1200px;margin:0 auto}.title{font-size:30px;font-weight:700}.sub{opacity:.8;margin-top:6px}.score{font-size:42px;font-weight:700;margin-top:10px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:14px;margin:26px 0}.card{background:white;border-radius:14px;padding:18px;box-shadow:0 5px 16px rgba(15,23,42,.08)}.card .n{font-size:28px;font-weight:700}.section{background:white;border-radius:14px;padding:22px;margin:22px 0;box-shadow:0 5px 16px rgba(15,23,42,.08)}table{width:100%;border-collapse:collapse;font-size:14px}th,td{text-align:left;padding:11px;border-bottom:1px solid #e2e8f0;vertical-align:top}th{background:#f8fafc}.good{color:#15803d;font-weight:700}.warn{color:#b45309;font-weight:700}.bad{color:#b91c1c;font-weight:700}.meta{font-size:13px;color:#64748b}.risk{display:inline-block;padding:6px 10px;border-radius:999px;background:#e2e8f0;color:#0f172a;font-weight:600}</style>
</head>
<body>
<div class="header"><div class="wrap"><div class="title">TenantIQ Microsoft 365 Portfolio Assessment</div><div class="sub">Consolidated view of the latest available workload assessments</div><div class="score">$PortfolioScore%</div><div class="risk">$RiskLevel</div></div></div>
<div class="wrap">
<div class="grid">
<div class="card"><div class="n">$($Snapshots.Count)</div><div>Workloads</div></div>
<div class="card"><div class="n">$PortfolioTotal</div><div>Total Controls</div></div>
<div class="card"><div class="n">$PortfolioPass</div><div>PASS</div></div>
<div class="card"><div class="n">$PortfolioWarning</div><div>WARNING</div></div>
<div class="card"><div class="n">$PortfolioFail</div><div>FAIL</div></div>
<div class="card"><div class="n">$PortfolioInfo</div><div>INFO</div></div>
</div>
<div class="section"><h2>Executive Summary</h2><p>TenantIQ found $PortfolioFail failing control(s) and $PortfolioWarning warning control(s) across the latest $($Snapshots.Count) workload assessment(s). The consolidated posture score is $PortfolioScore%. INFO findings are treated as contextual evidence and are excluded from scored-control math.</p><p class="meta">Generated: $Generated</p></div>
<div class="section"><h2>Workload Scores</h2><table><thead><tr><th>Workload</th><th>Total</th><th>PASS</th><th>WARNING</th><th>FAIL</th><th>INFO</th><th>Score</th><th>Latest Run</th></tr></thead><tbody>$($WorkloadRows -join "`n")</tbody></table></div>
<div class="section"><h2>Top Actionable Findings</h2><table><thead><tr><th>Status</th><th>Workload</th><th>Check</th><th>Finding</th><th>Recommendation</th></tr></thead><tbody>$($FindingRows -join "`n")</tbody></table></div>
</div>
</body>
</html>
"@

    Set-Content -Path $HtmlPath -Value $Html -Encoding UTF8

    Write-Host ""
    Write-Host "TenantIQ portfolio report generated." -ForegroundColor Green
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
