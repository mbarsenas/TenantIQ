$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID User Accounts health check." `
    -Level INFO

try {

    # Verify required Microsoft Graph commands are available
    if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {

        Write-Host ""
        Write-Host "Microsoft Graph PowerShell is not installed." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Install it with:" -ForegroundColor Yellow
        Write-Host "Install-Module Microsoft.Graph -Scope CurrentUser" -ForegroundColor Cyan

        throw "Microsoft Graph PowerShell is not installed."
    }

    if (-not (Get-Command Get-MgUser -ErrorAction SilentlyContinue)) {

        Write-Host ""
        Write-Host "Microsoft.Graph.Users module is not available." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Install it with:" -ForegroundColor Yellow
        Write-Host "Install-Module Microsoft.Graph.Users -Scope CurrentUser" -ForegroundColor Cyan

        throw "Microsoft.Graph.Users module is not installed."
    }

    # Check for an existing Microsoft Graph connection
    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Cyan
        Write-Host ""

        Connect-MgGraph `
            -Scopes "User.Read.All"
    }
    else {

        Write-Host ""
        Write-Host "Microsoft Graph connection detected." -ForegroundColor Green
        Write-Host "Account : $($GraphContext.Account)"
        Write-Host "Tenant  : $($GraphContext.TenantId)"
        Write-Host ""
    }

    Write-ExchangeAILog `
        -Message "Microsoft Graph connection established." `
        -Level INFO

    # Retrieve Entra ID users
    $Users = @(
        Get-MgUser `
            -All `
            -Property Id,DisplayName,UserPrincipalName,UserType,AccountEnabled `
            -ErrorAction Stop
    )

    $TotalUsers = $Users.Count

    $EnabledUsers = @(
        $Users |
        Where-Object {
            $_.AccountEnabled -eq $true
        }
    ).Count

    $DisabledUsers = @(
        $Users |
        Where-Object {
            $_.AccountEnabled -eq $false
        }
    ).Count

    $MemberUsers = @(
        $Users |
        Where-Object {
            $_.UserType -eq "Member"
        }
    ).Count

    $GuestUsers = @(
        $Users |
        Where-Object {
            $_.UserType -eq "Guest"
        }
    ).Count

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "User Account Summary" -ForegroundColor Cyan
    Write-Host "--------------------"
    Write-Host ""

    Write-Host "Total Users    : " -NoNewline
    Write-Host $TotalUsers -ForegroundColor Cyan

    Write-Host "Enabled Users  : " -NoNewline
    Write-Host $EnabledUsers -ForegroundColor Green

    Write-Host "Disabled Users : " -NoNewline
    Write-Host $DisabledUsers -ForegroundColor Yellow

    Write-Host "Member Users   : " -NoNewline
    Write-Host $MemberUsers

    Write-Host "Guest Users    : " -NoNewline
    Write-Host $GuestUsers

    Write-Host ""

    $Stopwatch.Stop()

    $Finding = "Tenant contains $TotalUsers users: $EnabledUsers enabled, $DisabledUsers disabled, $MemberUsers members, and $GuestUsers guests."

    if ($DisabledUsers -gt 0 -or $GuestUsers -gt 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Recommendation = "Review disabled and guest accounts regularly and remove accounts that no longer have a business requirement."

        Write-Host "WARNING  Account review recommended." -ForegroundColor Yellow

    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Recommendation = "No immediate action required."

        Write-Host "PASS  No disabled or guest accounts were detected." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "User Account Summary" `
        -Category "Entra ID" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID User Accounts health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO

}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID User Accounts health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Entra ID User Accounts assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "User Account Summary" `
        -Category "Entra ID" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft Graph PowerShell is installed and that the account has User.Read.All permission." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}