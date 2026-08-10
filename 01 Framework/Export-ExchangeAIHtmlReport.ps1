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

switch ($Workload) {

    "Exchange Online" {

        try {

            $Org = Get-OrganizationConfig -ErrorAction Stop

            if ([string]::IsNullOrWhiteSpace($Org.DisplayName)) {

                $Tenant = (
                    Get-AcceptedDomain |
                    Where-Object { $_.Default -eq $true }
                ).DomainName

            }
            else {

                $Tenant = $Org.DisplayName
            }

        }
        catch {

            $Tenant = "Unknown Tenant"
        }

        $WorkloadSlug = "ExchangeOnline"
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
            else {

                $Tenant = "Unknown Tenant"
            }

        }
        catch {

            $Tenant = "Unknown Tenant"
        }

        $WorkloadSlug = "EntraID"
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
        catch {

            $Tenant = "SharePoint Online Tenant"
        }

        $WorkloadSlug = "SharePointOnline"
    }
}

    $Passed = @(
        $Results |
        Where-Object { $_.Status -eq "PASS" }
    ).Count

    $Warnings = @(
        $Results |
        Where-Object { $_.Status -eq "WARNING" }
    ).Count

    $Failed = @(
        $Results |
        Where-Object { $_.Status -eq "FAIL" }
    ).Count

    $Total = $Results.Count

    if ($Total -eq 0) {
        $Score = 0
    }
    else {
        $Score = [math]::Round(($Passed / $Total) * 100)
    }

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

    $Results |
        Export-Csv `
        -Path $CsvReportPath `
        -NoTypeInformation `
        -Encoding UTF8

    $HighestPriority = @(
        $Results |
        Where-Object { $_.Status -eq "FAIL" } |
        Select-Object -First 1
    )

    if ($HighestPriority.Count -eq 0) {

        $HighestPriority = @(
            $Results |
            Where-Object { $_.Status -eq "WARNING" } |
            Select-Object -First 1
        )
    }

    if ($HighestPriority.Count -gt 0) {

        $PriorityCheck = [System.Net.WebUtility]::HtmlEncode(
            [string]$HighestPriority[0].Check
        )

        $PriorityFinding = [System.Net.WebUtility]::HtmlEncode(
            [string]$HighestPriority[0].Finding
        )

        $PriorityRecommendation = [System.Net.WebUtility]::HtmlEncode(
            [string]$HighestPriority[0].Recommendation
        )
    }
    else {

        $PriorityCheck = "None"
        $PriorityFinding = "No significant issues were identified."
        $PriorityRecommendation = "No immediate corrective action is required."
    }

    $CategoryCards = ""

    $Categories = @(
        $Results |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.Category)
        } |
        Group-Object Category
    )

    foreach ($Category in $Categories) {

        $CategoryPassed = @(
            $Category.Group |
            Where-Object { $_.Status -eq "PASS" }
        ).Count

        $CategoryTotal = $Category.Group.Count

        if ($CategoryTotal -eq 0) {
            $CategoryScore = 0
        }
        else {
            $CategoryScore = [math]::Round(
                ($CategoryPassed / $CategoryTotal) * 100
            )
        }

        if ($CategoryScore -ge 90) {
            $CategoryClass = "good"
        }
        elseif ($CategoryScore -ge 70) {
            $CategoryClass = "warning"
        }
        else {
            $CategoryClass = "critical"
        }

        $CategoryName = [System.Net.WebUtility]::HtmlEncode(
            [string]$Category.Name
        )

        $CategoryCards += @"
<div class="category-card">
    <div class="category-name">$CategoryName</div>
    <div class="category-score $CategoryClass">$CategoryScore%</div>
</div>
"@
    }

    $FindingRows = ""

    foreach ($Result in $Results) {

        $Check = [System.Net.WebUtility]::HtmlEncode([string]$Result.Check)
        $Category = [System.Net.WebUtility]::HtmlEncode([string]$Result.Category)
        $Status = [System.Net.WebUtility]::HtmlEncode([string]$Result.Status)
        $Severity = [System.Net.WebUtility]::HtmlEncode([string]$Result.Severity)
        $Finding = [System.Net.WebUtility]::HtmlEncode([string]$Result.Finding)
        $Recommendation = [System.Net.WebUtility]::HtmlEncode([string]$Result.Recommendation)

        switch ($Result.Status) {

            "PASS" {
                $StatusClass = "status-pass"
            }

            "WARNING" {
                $StatusClass = "status-warning"
            }

            "FAIL" {
                $StatusClass = "status-fail"
            }

            default {
                $StatusClass = ""
            }
        }

        $FindingRows += @"
<tr>
    <td>$Check</td>
    <td>$Category</td>
    <td><span class="$StatusClass">$Status</span></td>
    <td>$Severity</td>
    <td>$Finding</td>
    <td>$Recommendation</td>
</tr>
"@
    }

    $PriorityFindings = ""

    $PriorityResults = @(
        $Results |
        Where-Object {
            $_.Status -eq "FAIL" -or
            $_.Status -eq "WARNING"
        }
    )

    if ($PriorityResults.Count -eq 0) {

        $PriorityFindings = @"
<div class="success-message">
    No critical findings were detected.
</div>
"@
    }
    else {

        foreach ($Result in $PriorityResults) {

            $Check = [System.Net.WebUtility]::HtmlEncode([string]$Result.Check)
            $Finding = [System.Net.WebUtility]::HtmlEncode([string]$Result.Finding)
            $Recommendation = [System.Net.WebUtility]::HtmlEncode([string]$Result.Recommendation)

            if ($Result.Status -eq "FAIL") {

                $FindingClass = "finding-fail"
                $FindingLabel = "FAIL"

            }
            else {

                $FindingClass = "finding-warning"
                $FindingLabel = "WARNING"
            }

            $PriorityFindings += @"
<div class="finding $FindingClass">
    <div class="finding-title">[$FindingLabel] $Check</div>
    <div class="finding-text">$Finding</div>
    <div class="finding-recommendation">
        Recommendation: $Recommendation
    </div>
</div>
"@
        }
    }

    $AssessmentDate = Get-Date -Format "MMMM dd, yyyy hh:mm tt"

    $EncodedTenant = [System.Net.WebUtility]::HtmlEncode(
        [string]$Tenant
    )

    $Html = @"
<!DOCTYPE html>
<html lang="en">

<head>

<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<title>TenantIQ - $Workload Assessment Report</title>

<style>

* {
    box-sizing: border-box;
}

html {
    scroll-behavior: smooth;
}

body {
    margin: 0;
    background: #f4f7fb;
    color: #1f2937;
    font-family: "Segoe UI", Arial, sans-serif;
}

.header {
    background: #0078d4;
    color: white;
    padding: 30px 50px;
}

.header-inner {
    max-width: 1300px;
    margin: auto;
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 20px;
}

.brand {
    font-size: 32px;
    font-weight: 700;
}

.subtitle {
    margin-top: 5px;
    opacity: 0.9;
    font-size: 16px;
}

.report-subtitle {
    margin-top: 7px;
    opacity: 0.78;
    font-size: 13px;
    letter-spacing: 0.2px;
}

.risk-badge {
    display: inline-block;
    margin-top: 8px;
    padding: 5px 10px;
    border-radius: 999px;
    background: rgba(255,255,255,.16);
    font-size: 13px;
    font-weight: 600;
}

.header-score {
    text-align: right;
}

.header-score-label {
    font-size: 13px;
    opacity: 0.8;
}

.header-score-value {
    font-size: 32px;
    font-weight: 700;
}

.toolbar {
    background: white;
    border-bottom: 1px solid #dbe3ec;
    position: sticky;
    top: 0;
    z-index: 1000;
}

.toolbar-inner {
    max-width: 1300px;
    margin: auto;
    padding: 12px 25px;
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
}

.button {
    display: inline-block;
    padding: 10px 16px;
    border-radius: 10px;
    border: 0;
    background: #0078d4;
    color: white;
    text-decoration: none;
    font-family: inherit;
    font-size: 14px;
    cursor: pointer;
}

.button:hover {
    background: #106ebe;
}

.button-secondary {
    background: #475569;
}

.button-secondary:hover {
    background: #334155;
}

.container {
    max-width: 1300px;
    margin: 30px auto;
    padding: 0 25px 50px 25px;
}

.tenant-info,
.executive-summary {
    background: white;
    border-radius: 16px;
    padding: 22px;
    margin-bottom: 25px;
    box-shadow: 0 6px 18px rgba(0,0,0,.08);
}

.tenant-info {
    line-height: 1.8;
}

.executive-summary {
    border-left: 5px solid #0078d4;
}

.executive-title {
    font-size: 22px;
    font-weight: 700;
    margin-bottom: 14px;
}

.executive-text {
    line-height: 1.7;
    color: #334155;
}

.priority-box {
    background: #f8fafc;
    border-radius: 8px;
    padding: 16px;
    margin-top: 18px;
}

.priority-label {
    font-size: 13px;
    color: #64748b;
    text-transform: uppercase;
    font-weight: 700;
    margin-bottom: 5px;
}

.priority-value {
    font-weight: 600;
    margin-bottom: 10px;
}

.cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 18px;
    margin-bottom: 30px;
}

.card {
    background: white;
    border-radius: 16px;
    padding: 22px;
    box-shadow: 0 6px 18px rgba(0,0,0,.08);
}

.card-label {
    font-size: 14px;
    color: #64748b;
}

.card-value {
    font-size: 34px;
    font-weight: 700;
    margin-top: 8px;
}

.good {
    color: #15803d;
}

.warning {
    color: #ca8a04;
}

.critical {
    color: #dc2626;
}

.section-title {
    margin-top: 35px;
    margin-bottom: 15px;
    font-size: 22px;
    font-weight: 600;
}

.category-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 15px;
}

.category-card {
    background: white;
    padding: 20px;
    border-radius: 16px;
    box-shadow: 0 6px 18px rgba(0,0,0,.07);
}

.category-name {
    color: #475569;
}

.category-score {
    font-size: 28px;
    font-weight: 700;
    margin-top: 8px;
}

.finding {
    background: white;
    border-radius: 8px;
    padding: 18px;
    margin-bottom: 12px;
    box-shadow: 0 2px 6px rgba(0,0,0,.06);
}

.finding-fail {
    border-left: 5px solid #dc2626;
}

.finding-warning {
    border-left: 5px solid #ca8a04;
}

.finding-title {
    font-weight: 700;
    margin-bottom: 7px;
}

.finding-text {
    margin-bottom: 8px;
}

.finding-recommendation {
    color: #475569;
}

.success-message {
    background: #ecfdf5;
    border-left: 5px solid #16a34a;
    padding: 18px;
    border-radius: 8px;
}

.table-wrapper {
    overflow-x: auto;
}

table {
    width: 100%;
    border-collapse: collapse;
    background: white;
    box-shadow: 0 2px 8px rgba(0,0,0,.07);
}

th {
    background: #e8eef5;
    text-align: left;
    padding: 12px;
    font-size: 13px;
}

td {
    padding: 12px;
    border-top: 1px solid #e5e7eb;
    vertical-align: top;
    font-size: 13px;
}

.status-pass {
    color: #15803d;
    font-weight: 700;
}

.status-warning {
    color: #ca8a04;
    font-weight: 700;
}

.status-fail {
    color: #dc2626;
    font-weight: 700;
}

.footer {
    text-align: center;
    margin-top: 40px;
    color: #64748b;
    font-size: 12px;
}

@media print {

    body {
        background: white;
        -webkit-print-color-adjust: exact;
        print-color-adjust: exact;
    }

    .toolbar {
        display: none;
    }

    .container {
        max-width: none;
        margin: 0;
        padding: 20px;
    }

    .header {
        padding: 20px;
    }

    .card,
    .category-card,
    .finding,
    .tenant-info,
    .executive-summary,
    table {
        box-shadow: none;
    }

    .card,
    .category-card,
    .finding,
    .tenant-info,
    .executive-summary {
        break-inside: avoid;
    }

    tr {
        break-inside: avoid;
    }

    @page {
        size: auto;
        margin: 0.5in;
    }
}

</style>

</head>

<body id="top">

<div class="header">

<div class="header-inner">

<div>
    <div class="brand">TenantIQ</div>
    <div class="subtitle">Microsoft 365 Assessment Platform</div>
    <div class="report-subtitle">$Workload Assessment Report</div>
</div>

<div class="header-score">
    <div class="header-score-label">Overall Health</div>
    <div class="header-score-value">$Score%</div>
    <div class="risk-badge">$RiskLevel</div>
</div>

</div>

</div>

<div class="toolbar">

<div class="toolbar-inner">

<button class="button" onclick="window.print()">
Print / Export PDF
</button>

<a class="button" href="$CsvFileName" download>
Export CSV
</a>

<a class="button button-secondary" href="#top">
Back to Top
</a>

</div>

</div>

<div class="container">

<div class="tenant-info">
    <strong>Tenant:</strong> $EncodedTenant<br>
    <strong>Assessment Date:</strong> $AssessmentDate<br>
    <strong>Platform:</strong> $Workload<br>
    <strong>TenantIQ Version:</strong> $ProductVersion
</div>

<div class="executive-summary">

<div class="executive-title">
Executive Summary
</div>

<div class="executive-text">

TenantIQ completed <strong>$Total $Workload health checks</strong> for tenant
<strong>$EncodedTenant</strong>.

The tenant received an overall health score of
<strong class="$ScoreClass">$Score%</strong>
and is currently classified as
<strong>$Posture</strong>.

<br><br>

<strong>$Passed</strong> checks passed,
<strong>$Warnings</strong> generated warnings,
and <strong>$Failed</strong> failed.

</div>

<div class="priority-box">

<div class="priority-label">
Highest Priority Finding
</div>

<div class="priority-value">
$PriorityCheck
</div>

<div>
$PriorityFinding
</div>

<br>

<div class="priority-label">
Recommended Next Action
</div>

<div>
$PriorityRecommendation
</div>

</div>

</div>

<div class="cards">

<div class="card">
    <div class="card-label">Overall Health</div>
    <div class="card-value $ScoreClass">$Score%</div>
</div>

<div class="card">
    <div class="card-label">Checks Completed</div>
    <div class="card-value">$Total</div>
</div>

<div class="card">
    <div class="card-label">Passed</div>
    <div class="card-value good">$Passed</div>
</div>

<div class="card">
    <div class="card-label">Warnings</div>
    <div class="card-value warning">$Warnings</div>
</div>

<div class="card">
    <div class="card-label">Failed</div>
    <div class="card-value critical">$Failed</div>
</div>

</div>

<div class="section-title">Category Scores</div>

<div class="category-grid">
$CategoryCards
</div>

<div class="section-title">Priority Findings</div>

$PriorityFindings

<div class="section-title">Detailed Assessment Results</div>

<div class="table-wrapper">

<table>

<thead>
<tr>
<th>Check</th>
<th>Category</th>
<th>Status</th>
<th>Severity</th>
<th>Finding</th>
<th>Recommendation</th>
</tr>
</thead>

<tbody>
$FindingRows
</tbody>

</table>

</div>

<div class="footer">
TenantIQ v$ProductVersion | Microsoft 365 Assessment Platform | $Workload
</div>

</div>

</body>

</html>
"@

    $Html |
        Out-File `
        -FilePath $HtmlReportPath `
        -Encoding UTF8

    Write-Host ""
    Write-Host "TenantIQ HTML Report Created" -ForegroundColor Green
    Write-Host $HtmlReportPath -ForegroundColor Cyan

    Write-Host ""
    Write-Host "TenantIQ CSV Report Created" -ForegroundColor Green
    Write-Host $CsvReportPath -ForegroundColor Cyan

    Start-Process $HtmlReportPath

    return $HtmlReportPath
} 	