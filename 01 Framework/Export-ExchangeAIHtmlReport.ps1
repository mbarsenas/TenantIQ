function Export-ExchangeAIHtmlReport {

    param(
        [ValidateSet("Exchange Online","Entra ID","SharePoint Online","Microsoft Teams","OneDrive","Microsoft Intune","Microsoft Defender","Microsoft Purview")]
        [string]$Workload = "Exchange Online"
    )

    $Results = @($Global:ExchangeAIResults)

    if ($Results.Count -eq 0) {
        Write-Host "No health check results are available for the HTML report." -ForegroundColor Yellow
        return
    }

    $RootPath = Split-Path $PSScriptRoot -Parent
    $OutputPath = Join-Path $RootPath "06 Output"

    $Config = Get-ExchangeAIConfig
    $ProductName = $Config.Name
    $ProductVersion = $Config.Version
    $ProductDescription = $Config.Description

    if (-not (Test-Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    $Tenant = "Unknown Tenant"
    $WorkloadSlug = switch ($Workload) {
        "Exchange Online"   { "ExchangeOnline" }
        "Entra ID"          { "EntraID" }
        "SharePoint Online" { "SharePointOnline" }
        "Microsoft Teams"   { "MicrosoftTeams" }
        "OneDrive"          { "OneDrive" }
        "Microsoft Intune"  { "MicrosoftIntune" }
        "Microsoft Defender"{ "MicrosoftDefender" }
        "Microsoft Purview" { "MicrosoftPurview" }
    }

    switch ($Workload) {
        "Exchange Online" {
            try {
                $Org = Get-OrganizationConfig -ErrorAction Stop
                if ([string]::IsNullOrWhiteSpace($Org.DisplayName)) {
                    $Tenant = ((Get-AcceptedDomain | Where-Object { $_.Default -eq $true }).DomainName)
                }
                else {
                    $Tenant = $Org.DisplayName
                }
            }
            catch { $Tenant = "Unknown Tenant" }
        }

        "Entra ID" {
            try {
                $GraphContext = Get-MgContext -ErrorAction Stop
                if (-not [string]::IsNullOrWhiteSpace($GraphContext.Account)) {
                    $Tenant = ($GraphContext.Account -split "@")[-1]
                }
                elseif (-not [string]::IsNullOrWhiteSpace($GraphContext.TenantId)) {
                    $Tenant = $GraphContext.TenantId
                }
            }
            catch { $Tenant = "Unknown Tenant" }
        }

        "SharePoint Online" {
            try {
                $SpoTenant = Get-SPOTenant -ErrorAction Stop
                if ($SpoTenant.DisplayName) {
                    $Tenant = [string]$SpoTenant.DisplayName
                }
                elseif ($SpoTenant.RootSiteUrl) {
                    $Tenant = ([uri]$SpoTenant.RootSiteUrl).Host
                }
                else {
                    $Tenant = "SharePoint Online Tenant"
                }
            }
            catch { $Tenant = "SharePoint Online Tenant" }
        }

        "Microsoft Teams" {
            try {
                $TeamsTenant = Get-CsTenant -ErrorAction Stop
                if ($TeamsTenant.DisplayName) { $Tenant = [string]$TeamsTenant.DisplayName }
                elseif ($TeamsTenant.TenantId) { $Tenant = [string]$TeamsTenant.TenantId }
            }
            catch { $Tenant = "Microsoft Teams Tenant" }
        }

        "OneDrive" {
            try {
                $SpoTenant = Get-SPOTenant -ErrorAction Stop
                if ($SpoTenant.DisplayName) { $Tenant = [string]$SpoTenant.DisplayName }
                else { $Tenant = "OneDrive Tenant" }
            }
            catch { $Tenant = "OneDrive Tenant" }
        }

        default {
            try {
                if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
                    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue
                    if ($GraphContext -and $GraphContext.Account) {
                        $Tenant = ($GraphContext.Account -split "@")[-1]
                    }
                    elseif ($GraphContext -and $GraphContext.TenantId) {
                        $Tenant = [string]$GraphContext.TenantId
                    }
                }
            }
            catch {}
        }
    }

    $Passed = @($Results | Where-Object { $_.Status -eq "PASS" }).Count
    $Warnings = @($Results | Where-Object { $_.Status -eq "WARNING" }).Count
    $Failed = @($Results | Where-Object { $_.Status -eq "FAIL" }).Count
    $Total = $Results.Count

    if ($Total -eq 0) { $Score = 0 } else { $Score = [math]::Round(($Passed / $Total) * 100) }

    if ($Score -ge 90) {
        $ScoreClass = "good"
        $Posture = "Healthy"
        $RiskLevel = "Low Risk"
    }
    elseif ($Score -ge 70) {
        $ScoreClass = "warning"
        $Posture = "Needs Attention"
        $RiskLevel = "Medium Risk"
    }
    else {
        $ScoreClass = "critical"
        $Posture = "At Risk"
        $RiskLevel = "High Risk"
    }

    $Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $HtmlFileName = "TenantIQ-$WorkloadSlug-Assessment-$Timestamp.html"
    $CsvFileName  = "TenantIQ-$WorkloadSlug-Assessment-$Timestamp.csv"
    $HtmlReportPath = Join-Path $OutputPath $HtmlFileName
    $CsvReportPath  = Join-Path $OutputPath $CsvFileName

    $Results | Export-Csv -Path $CsvReportPath -NoTypeInformation -Encoding UTF8

    $HighestPriority = @($Results | Where-Object { $_.Status -eq "FAIL" } | Select-Object -First 1)
    if ($HighestPriority.Count -eq 0) {
        $HighestPriority = @($Results | Where-Object { $_.Status -eq "WARNING" } | Select-Object -First 1)
    }

    if ($HighestPriority.Count -gt 0) {
        $PriorityCheck = [System.Net.WebUtility]::HtmlEncode([string]$HighestPriority[0].Check)
        $PriorityFinding = [System.Net.WebUtility]::HtmlEncode([string]$HighestPriority[0].Finding)
        $PriorityRecommendation = [System.Net.WebUtility]::HtmlEncode([string]$HighestPriority[0].Recommendation)
    }
    else {
        $PriorityCheck = "None"
        $PriorityFinding = "No significant issues were identified."
        $PriorityRecommendation = "No immediate corrective action is required."
    }

    $CategoryCards = ""
    $Categories = @($Results | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Category) } | Group-Object Category)

    foreach ($Category in $Categories) {
        $CategoryPassed = @($Category.Group | Where-Object { $_.Status -eq "PASS" }).Count
        $CategoryTotal = $Category.Group.Count
        if ($CategoryTotal -eq 0) { $CategoryScore = 0 } else { $CategoryScore = [math]::Round(($CategoryPassed / $CategoryTotal) * 100) }
        if ($CategoryScore -ge 90) { $CategoryClass = "good" }
        elseif ($CategoryScore -ge 70) { $CategoryClass = "warning" }
        else { $CategoryClass = "critical" }
        $CategoryName = [System.Net.WebUtility]::HtmlEncode([string]$Category.Name)
        $CategoryCards += "<div class=\"category-card\"><div class=\"category-name\">$CategoryName</div><div class=\"category-score $CategoryClass\">$CategoryScore%</div></div>"
    }

    $FindingRows = ""
    foreach ($Result in $Results) {
        $Check = [System.Net.WebUtility]::HtmlEncode([string]$Result.Check)
        $Category = [System.Net.WebUtility]::HtmlEncode([string]$Result.Category)
        $Status = [System.Net.WebUtility]::HtmlEncode([string]$Result.Status)
        $Severity = [System.Net.WebUtility]::HtmlEncode([string]$Result.Severity)
        $Finding = [System.Net.WebUtility]::HtmlEncode([string]$Result.Finding)
        $Recommendation = [System.Net.WebUtility]::HtmlEncode([string]$Result.Recommendation)
        $StatusClass = switch ($Result.Status) {
            "PASS" { "status-pass" }
            "WARNING" { "status-warning" }
            "FAIL" { "status-fail" }
            default { "" }
        }
        $FindingRows += "<tr><td>$Check</td><td>$Category</td><td><span class=\"$StatusClass\">$Status</span></td><td>$Severity</td><td>$Finding</td><td>$Recommendation</td></tr>"
    }

    $PriorityFindings = ""
    $PriorityResults = @($Results | Where-Object { $_.Status -eq "FAIL" -or $_.Status -eq "WARNING" })
    if ($PriorityResults.Count -eq 0) {
        $PriorityFindings = "<div class=\"success-message\">No critical findings were detected.</div>"
    }
    else {
        foreach ($Result in $PriorityResults) {
            $Check = [System.Net.WebUtility]::HtmlEncode([string]$Result.Check)
            $Finding = [System.Net.WebUtility]::HtmlEncode([string]$Result.Finding)
            $Recommendation = [System.Net.WebUtility]::HtmlEncode([string]$Result.Recommendation)
            if ($Result.Status -eq "FAIL") { $FindingClass = "finding-fail"; $FindingLabel = "FAIL" }
            else { $FindingClass = "finding-warning"; $FindingLabel = "WARNING" }
            $PriorityFindings += "<div class=\"finding $FindingClass\"><div class=\"finding-title\">[$FindingLabel] $Check</div><div class=\"finding-text\">$Finding</div><div class=\"finding-recommendation\">Recommendation: $Recommendation</div></div>"
        }
    }

    $AssessmentDate = Get-Date -Format "MMMM dd, yyyy hh:mm tt"
    $EncodedTenant = [System.Net.WebUtility]::HtmlEncode([string]$Tenant)

    $Html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>TenantIQ - $Workload Assessment Report</title>
<style>
*{box-sizing:border-box}body{margin:0;background:#f4f7fb;color:#1f2937;font-family:"Segoe UI",Arial,sans-serif}.header{background:#0078d4;color:white;padding:30px 50px}.header-inner{max-width:1300px;margin:auto;display:flex;justify-content:space-between;align-items:center;gap:20px}.brand{font-size:32px;font-weight:700}.subtitle{margin-top:5px;opacity:.9;font-size:16px}.report-subtitle{margin-top:7px;opacity:.78;font-size:13px}.risk-badge{display:inline-block;margin-top:8px;padding:5px 10px;border-radius:999px;background:rgba(255,255,255,.16);font-size:13px;font-weight:600}.header-score{text-align:right}.header-score-label{font-size:13px;opacity:.8}.header-score-value{font-size:32px;font-weight:700}.container{max-width:1300px;margin:30px auto;padding:0 25px 50px}.tenant-info,.executive-summary{background:white;border-radius:16px;padding:22px;margin-bottom:25px;box-shadow:0 6px 18px rgba(0,0,0,.08)}.executive-summary{border-left:5px solid #0078d4}.executive-title{font-size:22px;font-weight:700;margin-bottom:14px}.priority-box{background:#f8fafc;border-radius:8px;padding:16px;margin-top:18px}.category-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:14px;margin:20px 0}.category-card{background:white;border-radius:12px;padding:18px;box-shadow:0 4px 12px rgba(0,0,0,.07)}.category-name{font-weight:600}.category-score{font-size:26px;font-weight:700;margin-top:8px}.good,.status-pass{color:#15803d}.warning,.status-warning{color:#b45309}.critical,.status-fail{color:#b91c1c}.finding{background:white;border-radius:12px;padding:18px;margin:12px 0;box-shadow:0 4px 12px rgba(0,0,0,.06)}.finding-fail{border-left:5px solid #b91c1c}.finding-warning{border-left:5px solid #b45309}.finding-title{font-weight:700}.finding-text{margin-top:8px}.finding-recommendation{margin-top:10px;color:#334155}.success-message{background:#ecfdf5;color:#166534;border-radius:10px;padding:16px}.table-wrap{overflow-x:auto;background:white;border-radius:16px;box-shadow:0 6px 18px rgba(0,0,0,.08)}table{width:100%;border-collapse:collapse;font-size:14px}th,td{text-align:left;padding:11px;border-bottom:1px solid #e2e8f0;vertical-align:top}th{background:#f8fafc}.footer{text-align:center;color:#64748b;font-size:12px;padding:24px}@media print{body{background:white}.header{padding:20px}.container{padding:0}.tenant-info,.executive-summary,.table-wrap{box-shadow:none}}
</style>
</head>
<body>
<div class="header"><div class="header-inner"><div><div class="brand">$ProductName</div><div class="subtitle">$Workload Assessment</div><div class="report-subtitle">$ProductDescription v$ProductVersion</div><div class="risk-badge">$RiskLevel</div></div><div class="header-score"><div class="header-score-label">Health Score</div><div class="header-score-value">$Score%</div></div></div></div>
<div class="container">
<div class="tenant-info"><strong>Tenant:</strong> $EncodedTenant<br><strong>Assessment Date:</strong> $AssessmentDate<br><strong>Posture:</strong> $Posture</div>
<div class="executive-summary"><div class="executive-title">Executive Summary</div><div>TenantIQ evaluated $Total controls for $Workload. $Passed passed, $Warnings produced warnings, and $Failed failed.</div><div class="priority-box"><strong>Highest Priority:</strong> $PriorityCheck<br><br>$PriorityFinding<br><br><strong>Recommendation:</strong> $PriorityRecommendation</div></div>
<div class="category-grid">$CategoryCards</div>
<h2>Priority Findings</h2>$PriorityFindings
<h2>All Findings</h2><div class="table-wrap"><table><thead><tr><th>Check</th><th>Category</th><th>Status</th><th>Severity</th><th>Finding</th><th>Recommendation</th></tr></thead><tbody>$FindingRows</tbody></table></div>
</div>
<div class="footer">Generated by $ProductName v$ProductVersion</div>
</body>
</html>
"@

    Set-Content -Path $HtmlReportPath -Value $Html -Encoding UTF8

    Write-Host ""
    Write-Host "TenantIQ report generated." -ForegroundColor Green
    Write-Host "HTML: $HtmlReportPath" -ForegroundColor Cyan
    Write-Host "CSV : $CsvReportPath" -ForegroundColor Cyan

    [pscustomobject]@{
        HtmlPath = $HtmlReportPath
        CsvPath = $CsvReportPath
        Workload = $Workload
        Score = $Score
    }
}
