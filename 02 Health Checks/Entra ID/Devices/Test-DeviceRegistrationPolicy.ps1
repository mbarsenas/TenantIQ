$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Device Registration Policy health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "Policy.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with policy read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope -NoWelcome
    }

    Write-Host ""
    Write-Host "Retrieving Entra device registration policy..." -ForegroundColor Cyan

    $Policy = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/policies/deviceRegistrationPolicy" `
        -ErrorAction Stop

    $UserDeviceQuota = $Policy.userDeviceQuota
    $LocalAdmin = [string]$Policy.azureADRegistration.localAdmins
    $MfaState = [string]$Policy.multiFactorAuthConfiguration

    $AllowedUsers = @($Policy.azureADRegistration.allowedToRegister.users)
    $AllowedGroups = @($Policy.azureADRegistration.allowedToRegister.groups)

    $AllowedUsersText = if ($AllowedUsers.Count -gt 0) {
        ($AllowedUsers -join ", ")
    } else {
        "None"
    }

    $AllowedGroupsText = if ($AllowedGroups.Count -gt 0) {
        ($AllowedGroups -join ", ")
    } else {
        "None"
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Device Registration Policy" -ForegroundColor Cyan
    Write-Host "--------------------------"
    Write-Host ""
    Write-Host "User Device Quota              : $UserDeviceQuota"
    Write-Host "Registration MFA Configuration : $MfaState"
    Write-Host "Local Admin Configuration      : $LocalAdmin"
    Write-Host "Allowed Users                  : $AllowedUsersText"
    Write-Host "Allowed Groups                 : $AllowedGroupsText"

    $Stopwatch.Stop()

    $Issues = @()

    if ($MfaState -eq "notRequired") {
        $Issues += "MFA is not required by the device registration policy."
    }

    if ($LocalAdmin -eq "all") {
        $Issues += "All registering users may become local administrators on Microsoft Entra joined devices."
    }

    if ($null -ne $UserDeviceQuota -and [int]$UserDeviceQuota -gt 20) {
        $Issues += "The per-user device registration quota is greater than 20."
    }

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "The Entra device registration policy was reviewed and no high-risk configuration conditions evaluated by this check were detected."
        $Recommendation = "Continue reviewing device registration scope, MFA enforcement, local administrator behavior, and device quotas alongside Conditional Access and Intune controls."

        Write-Host ""
        Write-Host "PASS  Device registration policy configuration appears healthy." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"
        $Severity = if ($MfaState -eq "notRequired" -and $LocalAdmin -eq "all") { "High" } else { "Medium" }
        $Finding = ($Issues -join " ")
        $Recommendation = "Review Entra device registration settings. Require strong authentication for device registration where appropriate, restrict local administrator rights, and use a reasonable per-user device quota."

        Write-Host ""
        Write-Host "Device Registration Findings" -ForegroundColor Cyan
        Write-Host "----------------------------"
        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $Issue" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Device registration policy requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Device Registration Policy" `
        -Category "Devices" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Device Registration Policy health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Device Registration Policy health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Device Registration Policy assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Device Registration Policy" `
        -Category "Devices" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Policy.Read.All consent, Microsoft Graph connectivity, and access to the device registration policy." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
