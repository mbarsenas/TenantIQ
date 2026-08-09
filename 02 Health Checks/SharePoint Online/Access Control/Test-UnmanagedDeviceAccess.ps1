$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Unmanaged Device Access health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOTenant -ErrorAction SilentlyContinue)) {
        throw "Get-SPOTenant is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online unmanaged device access configuration..." -ForegroundColor Cyan

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

        $Text = [string]$Value
        if ([string]::IsNullOrWhiteSpace($Text)) {
            return "Not configured"
        }

        return $Text
    }

    $ConditionalAccessPolicy = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("ConditionalAccessPolicy")

    $AllowDownloadingNonWebViewableFiles = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("AllowDownloadingNonWebViewableFiles")

    $LimitedAccessFileType = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("LimitedAccessFileType")

    $AllowEditing = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("AllowEditing")

    $ReadOnlyForUnmanagedDevices = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("ReadOnlyForUnmanagedDevices")

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Unmanaged Device Access" -ForegroundColor Cyan
    Write-Host "-----------------------"
    Write-Host ""
    Write-Host "Conditional Access Policy             : $(Format-TenantIQValue $ConditionalAccessPolicy)"
    Write-Host "Allow Download Non-Web-Viewable Files : $(Format-TenantIQValue $AllowDownloadingNonWebViewableFiles)"
    Write-Host "Limited Access File Type               : $(Format-TenantIQValue $LimitedAccessFileType)"
    Write-Host "Allow Editing                          : $(Format-TenantIQValue $AllowEditing)"
    Write-Host "Read Only For Unmanaged Devices        : $(Format-TenantIQValue $ReadOnlyForUnmanagedDevices)"

    $Issues = @()
    $PolicyText = [string]$ConditionalAccessPolicy

    switch ($PolicyText) {
        "AllowFullAccess" {
            $Issues += [PSCustomObject]@{
                Severity = "Medium"
                Finding  = "SharePoint Online permits full access from unmanaged devices."
            }
        }

        "AllowLimitedAccess" {
            if ($AllowDownloadingNonWebViewableFiles -eq $true) {
                $Issues += [PSCustomObject]@{
                    Severity = "Medium"
                    Finding  = "Unmanaged devices receive limited access, but downloading non-web-viewable files is allowed."
                }
            }
        }

        "BlockAccess" {
            # Strongest SharePoint unmanaged-device posture.
        }

        default {
            if ([string]::IsNullOrWhiteSpace($PolicyText)) {
                $Issues += [PSCustomObject]@{
                    Severity = "Low"
                    Finding  = "TenantIQ could not determine the SharePoint Online unmanaged-device ConditionalAccessPolicy value."
                }
            }
            else {
                $Issues += [PSCustomObject]@{
                    Severity = "Low"
                    Finding  = "The unmanaged-device ConditionalAccessPolicy returned an unrecognized value: '$PolicyText'."
                }
            }
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"

        if ($PolicyText -eq "BlockAccess") {
            $Finding = "SharePoint Online blocks access from unmanaged devices."
            $Recommendation = "Continue validating that the SharePoint unmanaged-device policy aligns with Microsoft Entra Conditional Access and business requirements."
        }
        else {
            $Finding = "SharePoint Online limits access from unmanaged devices and no risky download exception was detected."
            $Recommendation = "Continue reviewing unmanaged-device restrictions and ensure Microsoft Entra Conditional Access policies enforce the intended device requirements."
        }

        Write-Host ""
        Write-Host "PASS  Unmanaged device access configuration appears healthy." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"

        if (@($Issues | Where-Object Severity -eq "Medium").Count -gt 0) {
            $Severity = "Medium"
        }
        else {
            $Severity = "Low"
        }

        $Finding = (@($Issues | ForEach-Object { $_.Finding }) -join " ")
        $Recommendation = "Review SharePoint Online unmanaged-device access. Consider BlockAccess or AllowLimitedAccess based on business requirements, and pair the SharePoint setting with Microsoft Entra Conditional Access policies targeting unmanaged devices."

        Write-Host ""
        Write-Host "Unmanaged Device Access Findings" -ForegroundColor Cyan
        Write-Host "--------------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Unmanaged device access configuration requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Unmanaged Device Access" `
        -Category "Access Control" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Unmanaged Device Access health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Unmanaged Device Access health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Unmanaged Device Access assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Unmanaged Device Access" `
        -Category "Access Control" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
