$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Conditional Access Integration health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOTenant -ErrorAction SilentlyContinue)) {
        throw "Get-SPOTenant is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online Conditional Access integration configuration..." -ForegroundColor Cyan

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

        if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
            return "Not returned"
        }

        return [string]$Value
    }

    $ConditionalAccessPolicy = Get-TenantIQProperty -Object $Tenant -Names @("ConditionalAccessPolicy")
    $AllowDownloadingNonWebViewableFiles = Get-TenantIQProperty -Object $Tenant -Names @("AllowDownloadingNonWebViewableFiles")
    $LimitedAccessFileType = Get-TenantIQProperty -Object $Tenant -Names @("LimitedAccessFileType")
    $AllowEditing = Get-TenantIQProperty -Object $Tenant -Names @("AllowEditing")
    $ReadOnlyForUnmanagedDevices = Get-TenantIQProperty -Object $Tenant -Names @("ReadOnlyForUnmanagedDevices")

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Conditional Access Integration" -ForegroundColor Cyan
    Write-Host "------------------------------"
    Write-Host ""
    Write-Host "SharePoint CA Policy                 : $(Format-TenantIQValue $ConditionalAccessPolicy)"
    Write-Host "Allow Non-Web-Viewable Downloads    : $(Format-TenantIQValue $AllowDownloadingNonWebViewableFiles)"
    Write-Host "Limited Access File Type            : $(Format-TenantIQValue $LimitedAccessFileType)"
    Write-Host "Allow Editing                       : $(Format-TenantIQValue $AllowEditing)"
    Write-Host "Read Only For Unmanaged Devices     : $(Format-TenantIQValue $ReadOnlyForUnmanagedDevices)"

    $Issues = @()

    switch ([string]$ConditionalAccessPolicy) {
        "BlockAccess" {
            # Strongest SharePoint unmanaged-device posture.
        }

        "AllowLimitedAccess" {
            if ($AllowDownloadingNonWebViewableFiles -eq $true) {
                $Issues += [PSCustomObject]@{
                    Severity = "Medium"
                    Finding  = "SharePoint uses limited access for unmanaged devices, but downloading non-web-viewable files is allowed."
                }
            }

            if ($AllowEditing -eq $true) {
                $Issues += [PSCustomObject]@{
                    Severity = "Low"
                    Finding  = "SharePoint uses limited access for unmanaged devices while browser editing is allowed."
                }
            }
        }

        "AllowFullAccess" {
            $Issues += [PSCustomObject]@{
                Severity = "Medium"
                Finding  = "SharePoint Online is configured to allow full access from unmanaged devices rather than applying a SharePoint limited-access or block-access posture."
            }
        }

        default {
            $Issues += [PSCustomObject]@{
                Severity = "Medium"
                Finding  = "TenantIQ could not determine a recognized SharePoint Conditional Access policy value."
            }
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "SharePoint Online Conditional Access integration settings evaluated by this check are configured with a restrictive unmanaged-device access posture."
        $Recommendation = "Continue validating SharePoint unmanaged-device controls alongside Microsoft Entra Conditional Access policies to ensure the intended users, applications, and device states are actually targeted."

        Write-Host ""
        Write-Host "PASS  SharePoint Online Conditional Access integration appears healthy." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"

        if (@($Issues | Where-Object Severity -eq "High").Count -gt 0) {
            $Severity = "High"
        }
        elseif (@($Issues | Where-Object Severity -eq "Medium").Count -gt 0) {
            $Severity = "Medium"
        }
        else {
            $Severity = "Low"
        }

        $Finding = (@($Issues | ForEach-Object { $_.Finding }) -join " ")
        $Recommendation = "Review SharePoint Online unmanaged-device access together with Microsoft Entra Conditional Access. Where appropriate, use BlockAccess or AllowLimitedAccess and verify that Entra Conditional Access policies target SharePoint Online and the intended device conditions."

        Write-Host ""
        Write-Host "Conditional Access Integration Findings" -ForegroundColor Cyan
        Write-Host "---------------------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Conditional Access integration requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Conditional Access Integration" `
        -Category "Access Control" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Conditional Access Integration health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Conditional Access Integration health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Conditional Access Integration assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Conditional Access Integration" `
        -Category "Access Control" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
