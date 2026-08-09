$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Legacy Authentication health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOTenant -ErrorAction SilentlyContinue)) {
        throw "Get-SPOTenant is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online legacy authentication configuration..." -ForegroundColor Cyan

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

    $LegacyAuthProtocolsEnabled = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("LegacyAuthProtocolsEnabled")

    $LegacyBrowserAuthProtocolsEnabled = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("LegacyBrowserAuthProtocolsEnabled")

    $AllowLegacyBrowserAuthProtocolsEnabledSetting = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("AllowLegacyBrowserAuthProtocolsEnabledSetting")

    $OfficeClientADALDisabled = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("OfficeClientADALDisabled")

    $DisableCustomAppAuthentication = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("DisableCustomAppAuthentication")

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Legacy Authentication" -ForegroundColor Cyan
    Write-Host "---------------------"
    Write-Host ""
    Write-Host "Legacy Auth Protocols Enabled          : $(Format-TenantIQValue $LegacyAuthProtocolsEnabled)"
    Write-Host "Legacy Browser Auth Enabled            : $(Format-TenantIQValue $LegacyBrowserAuthProtocolsEnabled)"
    Write-Host "Legacy Browser Setting Allowed         : $(Format-TenantIQValue $AllowLegacyBrowserAuthProtocolsEnabledSetting)"
    Write-Host "Office Client ADAL Disabled            : $(Format-TenantIQValue $OfficeClientADALDisabled)"
    Write-Host "Custom App Authentication Disabled     : $(Format-TenantIQValue $DisableCustomAppAuthentication)"

    $Issues = @()

    if ($LegacyAuthProtocolsEnabled -eq $true) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "SharePoint Online legacy authentication protocols are enabled."
        }
    }

    if ($LegacyBrowserAuthProtocolsEnabled -eq $true) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "Legacy browser authentication protocols are enabled for SharePoint Online."
        }
    }

    if ($OfficeClientADALDisabled -eq $true) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "Office Client ADAL is disabled, which can force older/non-modern authentication behavior."
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "SharePoint Online legacy authentication settings were reviewed and no enabled legacy authentication paths evaluated by this check were detected."
        $Recommendation = "Continue monitoring legacy and modern authentication settings, and validate older clients or third-party integrations before changing tenant authentication controls."

        Write-Host ""
        Write-Host "PASS  Legacy authentication configuration appears healthy." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"

        if (@($Issues | Where-Object Severity -eq "High").Count -gt 0) {
            $Severity = "High"
        }
        else {
            $Severity = "Medium"
        }

        $Finding = (@($Issues | ForEach-Object { $_.Finding }) -join " ")
        $Recommendation = "Review SharePoint Online legacy authentication dependencies and plan to disable non-modern authentication where business compatibility permits. Test older Office clients, third-party applications, and automation before changing the tenant setting."

        Write-Host ""
        Write-Host "Legacy Authentication Findings" -ForegroundColor Cyan
        Write-Host "------------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Legacy authentication configuration requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Legacy Authentication" `
        -Category "Access Control" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Legacy Authentication health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Legacy Authentication health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Legacy Authentication assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Legacy Authentication" `
        -Category "Access Control" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
