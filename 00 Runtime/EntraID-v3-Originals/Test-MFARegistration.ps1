# TenantIQ Entra ID Hardening v2
# Control: MFA Registration
# v2 policy: preserve existing PASS/WARNING/FAIL thresholds; improve evidence transparency.
# Do not downgrade a finding without contradictory tenant evidence.

function Format-TenantIQEntraEvidence {
    param([hashtable]$Evidence)
    $Parts = foreach ($Key in $Evidence.Keys) {
        $Value = $Evidence[$Key]
        if ($null -ne $Value -and "$Value" -ne "") { "$Key=$Value" }
    }
    if (@($Parts).Count -eq 0) { return "" }
    return " Evidence: " + ($Parts -join "; ") + "."
}

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID MFA Registration health check." `
    -Level INFO

try {

    if (-not (Get-Command Get-MgReportAuthenticationMethodUserRegistrationDetail -ErrorAction SilentlyContinue)) {

        throw "Microsoft.Graph.Reports is not installed. Run: Install-Module Microsoft.Graph.Reports -Scope CurrentUser"
    }

    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes "AuditLog.Read.All"
    }
    elseif ($GraphContext.Scopes -notcontains "AuditLog.Read.All") {

        Write-Host ""
        Write-Host "Reconnecting to Microsoft Graph with AuditLog.Read.All..." -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes "AuditLog.Read.All"
    }

    Write-Host ""
    Write-Host "Retrieving MFA registration data..." -ForegroundColor Cyan

    $Registration = @(
        Get-MgReportAuthenticationMethodUserRegistrationDetail `
            -All `
            -ErrorAction Stop
    )

    $Members = @(
        $Registration |
        Where-Object {
            $_.UserType -eq "member"
        }
    )

    $TotalUsers = $Members.Count

    $MFARegistered = @(
        $Members |
        Where-Object {
            $_.IsMfaRegistered -eq $true
        }
    )

    $MFANotRegistered = @(
        $Members |
        Where-Object {
            $_.IsMfaRegistered -ne $true
        }
    )

    $MFACapable = @(
        $Members |
        Where-Object {
            $_.IsMfaCapable -eq $true
        }
    )

    $PasswordlessCapable = @(
        $Members |
        Where-Object {
            $_.IsPasswordlessCapable -eq $true
        }
    )

    if ($TotalUsers -gt 0) {

        $MFARegistrationPercent = [math]::Round(
            ($MFARegistered.Count / $TotalUsers) * 100
        )

    }
    else {

        $MFARegistrationPercent = 0
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "MFA Registration" -ForegroundColor Cyan
    Write-Host "----------------"
    Write-Host ""

    Write-Host "Member Users          : $TotalUsers"

    Write-Host "MFA Registered        : " -NoNewline
    Write-Host $MFARegistered.Count -ForegroundColor Green

    Write-Host "MFA Not Registered    : " -NoNewline

    if ($MFANotRegistered.Count -gt 0) {
        Write-Host $MFANotRegistered.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "MFA Capable           : $($MFACapable.Count)"
    Write-Host "Passwordless Capable  : $($PasswordlessCapable.Count)"
    Write-Host "Registration Coverage : $MFARegistrationPercent%"
    Write-Host ""

    if ($MFANotRegistered.Count -gt 0) {

        Write-Host "Users Not Registered for MFA" -ForegroundColor Yellow
        Write-Host "----------------------------"

        $MFANotRegistered |
            Select-Object `
                UserDisplayName,
                UserPrincipalName,
                IsAdmin,
                IsMfaCapable,
                MethodsRegistered |
            Format-Table -AutoSize

        Write-Host ""
    }

    $Stopwatch.Stop()

    if ($MFANotRegistered.Count -eq 0 -and $TotalUsers -gt 0) {

        $Status = "PASS"
        $Severity = "None"
        $Finding = "All $TotalUsers member accounts are registered for MFA."
        $Recommendation = "No immediate action required."

        Write-Host "PASS  All member accounts are registered for MFA." -ForegroundColor Green

    }
    elseif ($MFARegistrationPercent -ge 95) {

        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($MFANotRegistered.Count) of $TotalUsers member accounts are not registered for MFA. MFA registration coverage is $MFARegistrationPercent%."
        $Recommendation = "Review the remaining accounts and complete MFA registration where appropriate."

        Write-Host "WARNING  MFA registration is not complete for all member accounts." -ForegroundColor Yellow

    }
    else {

        $Status = "FAIL"
        $Severity = "High"
        $Finding = "$($MFANotRegistered.Count) of $TotalUsers member accounts are not registered for MFA. MFA registration coverage is $MFARegistrationPercent%."
        $Recommendation = "Prioritize MFA registration for member accounts and review Conditional Access enforcement."

        Write-Host "FAIL  MFA registration coverage requires attention." -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "MFA Registration" `
        -Category "Authentication" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID MFA Registration health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO

}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID MFA Registration health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "MFA Registration assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "MFA Registration" `
        -Category "Authentication" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Reports is installed, AuditLog.Read.All consent is granted, and the signed-in account has a supported Entra role." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}