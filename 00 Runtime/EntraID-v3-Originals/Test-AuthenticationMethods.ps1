# TenantIQ Entra ID Hardening v2
# Control: Authentication Methods
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
    -Message "Starting Entra ID Authentication Methods health check." `
    -Level INFO

try {

    if (-not (Get-Command Get-MgReportAuthenticationMethodUserRegistrationDetail -ErrorAction SilentlyContinue)) {

        throw "Microsoft.Graph.Reports is not available. Install or repair the Microsoft Graph PowerShell SDK."
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
    Write-Host "Retrieving authentication method registration data..." -ForegroundColor Cyan

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

    $UsersWithMethods = @(
        $Members |
        Where-Object {
            @($_.MethodsRegistered).Count -gt 0
        }
    )

    $UsersWithoutMethods = @(
        $Members |
        Where-Object {
            @($_.MethodsRegistered).Count -eq 0
        }
    )

    $PasswordlessCapable = @(
        $Members |
        Where-Object {
            $_.IsPasswordlessCapable -eq $true
        }
    )

    $MfaCapable = @(
        $Members |
        Where-Object {
            $_.IsMfaCapable -eq $true
        }
    )

    $MethodCounts = @{}

    foreach ($User in $Members) {

        foreach ($Method in @($User.MethodsRegistered)) {

            if ([string]::IsNullOrWhiteSpace($Method)) {
                continue
            }

            if ($MethodCounts.ContainsKey($Method)) {
                $MethodCounts[$Method]++
            }
            else {
                $MethodCounts[$Method] = 1
            }
        }
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Authentication Methods" -ForegroundColor Cyan
    Write-Host "----------------------"
    Write-Host ""

    Write-Host "Member Users             : $TotalUsers"
    Write-Host "Users With Methods       : $($UsersWithMethods.Count)"
    Write-Host "Users Without Methods    : $($UsersWithoutMethods.Count)"
    Write-Host "MFA Capable              : $($MfaCapable.Count)"
    Write-Host "Passwordless Capable     : $($PasswordlessCapable.Count)"
    Write-Host ""

    if ($MethodCounts.Count -gt 0) {

        Write-Host "Registered Method Usage" -ForegroundColor Cyan
        Write-Host "-----------------------"

        $MethodCounts.GetEnumerator() |
            Sort-Object Value -Descending |
            ForEach-Object {

                Write-Host "$($_.Key) : $($_.Value)"
            }

        Write-Host ""
    }

    if ($UsersWithoutMethods.Count -gt 0) {

        Write-Host "Users Without Registered Authentication Methods" -ForegroundColor Yellow
        Write-Host "-----------------------------------------------"

        $UsersWithoutMethods |
            Select-Object `
                UserDisplayName,
                UserPrincipalName,
                IsAdmin |
            Format-Table -AutoSize

        Write-Host ""
    }

    $Stopwatch.Stop()

    if ($TotalUsers -eq 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "No member accounts were returned by the authentication methods registration report."

        $Recommendation = "Verify Microsoft Graph permissions and confirm that Entra ID member accounts are present."

        Write-Host "WARNING  No member accounts were returned." -ForegroundColor Yellow

    }
    elseif ($UsersWithoutMethods.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$($UsersWithoutMethods.Count) of $TotalUsers member accounts have no registered authentication methods."

        $Recommendation = "Review affected accounts and require registration of approved authentication methods."

        Write-Host "FAIL  One or more member accounts have no registered authentication methods." -ForegroundColor Red

    }
    elseif ($PasswordlessCapable.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "All member accounts have registered authentication methods, but no accounts are currently passwordless capable."

        $Recommendation = "Consider enabling and promoting phishing-resistant passwordless authentication methods where appropriate."

        Write-Host "WARNING  Authentication methods exist, but no users are passwordless capable." -ForegroundColor Yellow

    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "All $TotalUsers member accounts have at least one registered authentication method."

        $Recommendation = "Continue reviewing authentication method adoption and promote phishing-resistant methods where appropriate."

        Write-Host "PASS  All member accounts have registered authentication methods." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Authentication Methods" `
        -Category "Authentication" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Authentication Methods health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO

}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Authentication Methods health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Authentication Methods assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Authentication Methods" `
        -Category "Authentication" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft Graph PowerShell is installed, AuditLog.Read.All is consented, and the signed-in account has sufficient Entra reporting permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}