$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Site Creation Controls health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOTenant -ErrorAction SilentlyContinue)) {
        throw "Get-SPOTenant is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online site creation controls..." -ForegroundColor Cyan

    try {
        $Tenant = Get-SPOTenant -ErrorAction Stop
    }
    catch {
        throw "Unable to retrieve SharePoint Online tenant settings. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
    }

    function Get-TenantIQProperty {
        param(
            [Parameter(Mandatory)]$Object,
            [Parameter(Mandatory)][string[]]$Names
        )

        foreach ($Name in $Names) {
            $Property = $Object.PSObject.Properties[$Name]
            if ($null -ne $Property) {
                return $Property.Value
            }
        }

        return $null
    }

    function Format-TenantIQValue {
        param($Value)

        if ($null -eq $Value) {
            return "Not returned"
        }

        if ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) {
            return "Not configured"
        }

        return [string]$Value
    }

    $SelfServiceSiteCreationDisabled = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("SelfServiceSiteCreationDisabled")

    $SiteCreationMode = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("SiteCreationMode")

    $DisplayStartASiteOption = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("DisplayStartASiteOption")

    $StartASiteFormUrl = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("StartASiteFormUrl")

    $DefaultTimeZoneId = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("DefaultTimeZoneId")

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Site Creation Controls" -ForegroundColor Cyan
    Write-Host "---------------------"
    Write-Host ""
    Write-Host "Self-Service Site Creation Disabled : $(Format-TenantIQValue $SelfServiceSiteCreationDisabled)"
    Write-Host "Site Creation Mode                  : $(Format-TenantIQValue $SiteCreationMode)"
    Write-Host "Display Start-A-Site Option         : $(Format-TenantIQValue $DisplayStartASiteOption)"
    Write-Host "Custom Start-A-Site Form URL        : $(Format-TenantIQValue $StartASiteFormUrl)"
    Write-Host "Default Time Zone ID                : $(Format-TenantIQValue $DefaultTimeZoneId)"

    $Issues = @()

    if ($SelfServiceSiteCreationDisabled -eq $false) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "Self-service SharePoint site creation is enabled."
        }
    }

    if ($DisplayStartASiteOption -eq $true -and
        [string]::IsNullOrWhiteSpace([string]$StartASiteFormUrl)) {

        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "The Start-A-Site option is displayed and no custom site-request form URL is configured."
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "SharePoint Online site creation controls were reviewed and no broad self-service site-creation conditions evaluated by this check were detected."
        $Recommendation = "Continue reviewing site creation governance and ensure any approved self-service process aligns with Microsoft 365 group creation and lifecycle controls."

        Write-Host ""
        Write-Host "PASS  Site creation controls appear healthy." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = (@($Issues | ForEach-Object { $_.Finding }) -join " ")
        $Recommendation = "Review whether unrestricted self-service site creation is appropriate for the organization. Consider disabling SharePoint self-service site creation or routing users through an approved request/provisioning process if stronger governance is required."

        Write-Host ""
        Write-Host "Site Creation Findings" -ForegroundColor Cyan
        Write-Host "----------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Site creation controls require review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Site Creation Controls" `
        -Category "Governance" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Creation Controls health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Creation Controls health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Site Creation Controls assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Site Creation Controls" `
        -Category "Governance" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
