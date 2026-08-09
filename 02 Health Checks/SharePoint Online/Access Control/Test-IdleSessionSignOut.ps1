$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Idle Session Sign-Out health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOBrowserIdleSignOut -ErrorAction SilentlyContinue)) {
        throw "Get-SPOBrowserIdleSignOut is not available. Update/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online idle session sign-out configuration..." -ForegroundColor Cyan

    try {
        $Policy = Get-SPOBrowserIdleSignOut -ErrorAction Stop
    }
    catch {
        throw "Unable to retrieve the SharePoint Online idle session sign-out policy. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
    }

    function Format-TenantIQTimeSpan {
        param($Value)

        if ($null -eq $Value) {
            return "Not returned"
        }

        try {
            $Span = [TimeSpan]$Value
            return "{0}d {1}h {2}m" -f $Span.Days, $Span.Hours, $Span.Minutes
        }
        catch {
            return [string]$Value
        }
    }

    $Enabled = $Policy.Enabled
    $WarnAfter = $Policy.WarnAfter
    $SignOutAfter = $Policy.SignOutAfter

    $WarnMinutes = $null
    $SignOutMinutes = $null

    if ($null -ne $WarnAfter) {
        try { $WarnMinutes = [math]::Round(([TimeSpan]$WarnAfter).TotalMinutes, 2) } catch {}
    }

    if ($null -ne $SignOutAfter) {
        try { $SignOutMinutes = [math]::Round(([TimeSpan]$SignOutAfter).TotalMinutes, 2) } catch {}
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Idle Session Sign-Out" -ForegroundColor Cyan
    Write-Host "---------------------"
    Write-Host ""
    Write-Host "Policy Enabled    : $Enabled"
    Write-Host "Warn After        : $(Format-TenantIQTimeSpan $WarnAfter)"
    Write-Host "Sign Out After    : $(Format-TenantIQTimeSpan $SignOutAfter)"
    Write-Host "Warn After Minutes: $WarnMinutes"
    Write-Host "Sign Out Minutes  : $SignOutMinutes"

    $Issues = @()

    if ($Enabled -ne $true) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "SharePoint Online idle session sign-out is disabled."
        }
    }
    else {
        if ($null -eq $WarnMinutes -or $WarnMinutes -le 0) {
            $Issues += [PSCustomObject]@{
                Severity = "Medium"
                Finding  = "Idle session sign-out is enabled, but a valid warning interval was not detected."
            }
        }

        if ($null -eq $SignOutMinutes -or $SignOutMinutes -le 0) {
            $Issues += [PSCustomObject]@{
                Severity = "High"
                Finding  = "Idle session sign-out is enabled, but a valid sign-out interval was not detected."
            }
        }

        if ($null -ne $WarnMinutes -and
            $null -ne $SignOutMinutes -and
            $WarnMinutes -ge $SignOutMinutes) {

            $Issues += [PSCustomObject]@{
                Severity = "High"
                Finding  = "The idle warning interval is greater than or equal to the sign-out interval."
            }
        }

        if ($null -ne $SignOutMinutes -and $SignOutMinutes -gt 720) {
            $Issues += [PSCustomObject]@{
                Severity = "Low"
                Finding  = "The configured idle sign-out interval exceeds 12 hours and may provide limited session-risk reduction."
            }
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "SharePoint Online idle session sign-out is enabled with valid warning and sign-out intervals."
        $Recommendation = "Continue reviewing idle-session intervals against organizational security, user experience, and Microsoft Entra session-management requirements."

        Write-Host ""
        Write-Host "PASS  Idle session sign-out configuration appears healthy." -ForegroundColor Green
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
        $Recommendation = "Review SharePoint Online idle session sign-out. Enable the policy where appropriate and configure a warning interval that occurs before a reasonable sign-out interval. Coordinate this control with Microsoft Entra Conditional Access session controls."

        Write-Host ""
        Write-Host "Idle Session Sign-Out Findings" -ForegroundColor Cyan
        Write-Host "------------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Idle session sign-out configuration requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Idle Session Sign-Out" `
        -Category "Access Control" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Idle Session Sign-Out health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Idle Session Sign-Out health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Idle Session Sign-Out assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Idle Session Sign-Out" `
        -Category "Access Control" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is current, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
