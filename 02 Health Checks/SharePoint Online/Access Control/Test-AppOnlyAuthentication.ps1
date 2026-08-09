$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online App-Only Authentication health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOTenant -ErrorAction SilentlyContinue)) {
        throw "Get-SPOTenant is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online app-only authentication configuration..." -ForegroundColor Cyan

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

        return [string]$Value
    }

    $DisableCustomAppAuthentication = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("DisableCustomAppAuthentication")

    $DisableCustomAppAuthenticationValue = $null

    if ($null -ne $DisableCustomAppAuthentication) {
        try {
            $DisableCustomAppAuthenticationValue = [bool]$DisableCustomAppAuthentication
        }
        catch {
            $DisableCustomAppAuthenticationValue = $null
        }
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "App-Only Authentication" -ForegroundColor Cyan
    Write-Host "-----------------------"
    Write-Host ""
    Write-Host "Disable Custom App Authentication : $(Format-TenantIQValue $DisableCustomAppAuthentication)"
    Write-Host "ACS App-Only Access Enabled       : $(if ($null -eq $DisableCustomAppAuthenticationValue) { 'Unknown' } elseif ($DisableCustomAppAuthenticationValue) { 'False' } else { 'True' })"

    $Issues = @()

    if ($DisableCustomAppAuthenticationValue -eq $false) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "Legacy SharePoint Azure ACS app-only authentication is enabled."
        }
    }
    elseif ($null -eq $DisableCustomAppAuthenticationValue) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "TenantIQ could not determine the DisableCustomAppAuthentication setting."
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "Legacy SharePoint Azure ACS app-only authentication is disabled."
        $Recommendation = "Continue using Microsoft Entra ID application authentication for SharePoint Online integrations and avoid re-enabling legacy ACS app-only authentication."

        Write-Host ""
        Write-Host "PASS  Legacy ACS app-only authentication is disabled." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"

        if (@($Issues | Where-Object Severity -eq "High").Count -gt 0) {
            $Severity = "High"
        }
        else {
            $Severity = "Low"
        }

        $Finding = (@($Issues | ForEach-Object { $_.Finding }) -join " ")
        $Recommendation = "Review applications that depend on SharePoint Azure ACS app-only authentication and migrate them to Microsoft Entra ID application authentication. Keep DisableCustomAppAuthentication set to True once legacy dependencies have been removed."

        Write-Host ""
        Write-Host "App-Only Authentication Findings" -ForegroundColor Cyan
        Write-Host "--------------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  App-only authentication configuration requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "App-Only Authentication" `
        -Category "Access Control" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online App-Only Authentication health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online App-Only Authentication health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "App-Only Authentication assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "App-Only Authentication" `
        -Category "Access Control" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
