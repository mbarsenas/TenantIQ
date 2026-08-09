$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Guest Invitation Restrictions health check." `
    -Level INFO

try {

    $RequiredCommands = @(
        "Get-MgContext"
        "Connect-MgGraph"
        "Invoke-MgGraphRequest"
    )

    foreach ($Command in $RequiredCommands) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available. Install or repair Microsoft.Graph.Authentication."
        }
    }

    $RequiredScope = "Policy.Read.All"
    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext -or $GraphContext.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with policy read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope
    }

    Write-Host ""
    Write-Host "Retrieving Entra external collaboration settings..." -ForegroundColor Cyan

    $Policy = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy" `
        -ErrorAction Stop

    $InviteSetting = [string]$Policy.allowInvitesFrom
    $GuestUserRoleId = [string]$Policy.guestUserRoleId
    $GuestUserRoleTemplateId = [string]$Policy.guestUserRoleId

    $InviteDescription = switch ($InviteSetting) {
        "none" {
            "Guest invitations are disabled."
        }
        "adminsAndGuestInviters" {
            "Only administrators and users assigned the Guest Inviter role can invite guests."
        }
        "adminsGuestInvitersAndAllMembers" {
            "Administrators, Guest Inviters, and member users can invite guests."
        }
        "everyone" {
            "Anyone in the organization, including guests where otherwise permitted, can invite guest users."
        }
        default {
            if ([string]::IsNullOrWhiteSpace($InviteSetting)) {
                "The guest invitation setting could not be determined."
            }
            else {
                "Guest invitation setting: $InviteSetting"
            }
        }
    }

    $GuestRoleDescription = switch ($GuestUserRoleTemplateId) {
        "10dae51f-b6af-4016-8d66-8c2a99b929b3" {
            "Guest User"
        }
        "2af84b1e-32c8-42b7-82bc-daa82404023b" {
            "Restricted Guest User"
        }
        "a0b1b346-4d3e-4e8b-98f8-753987be4970" {
            "User"
        }
        default {
            if ([string]::IsNullOrWhiteSpace($GuestUserRoleTemplateId)) {
                "Unknown"
            }
            else {
                $GuestUserRoleTemplateId
            }
        }
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Guest Invitation Restrictions" -ForegroundColor Cyan
    Write-Host "-----------------------------"
    Write-Host ""

    Write-Host "Guest Invitation Setting : " -NoNewline

    switch ($InviteSetting) {
        "none" {
            Write-Host $InviteSetting -ForegroundColor Green
        }
        "adminsAndGuestInviters" {
            Write-Host $InviteSetting -ForegroundColor Green
        }
        "adminsGuestInvitersAndAllMembers" {
            Write-Host $InviteSetting -ForegroundColor Yellow
        }
        "everyone" {
            Write-Host $InviteSetting -ForegroundColor Red
        }
        default {
            Write-Host $InviteSetting -ForegroundColor Yellow
        }
    }

    Write-Host "Guest Default Role       : $GuestRoleDescription"
    Write-Host "Guest Role Template ID   : $GuestUserRoleTemplateId"
    Write-Host ""
    Write-Host "Configuration"
    Write-Host "-------------"
    Write-Host $InviteDescription
    Write-Host ""

    $Stopwatch.Stop()

    switch ($InviteSetting) {

        "everyone" {

            $Status = "WARNING"
            $Severity = "High"

            $Finding = "Guest invitations are configured so that everyone can invite external users."

            $Recommendation = "Restrict guest invitations to administrators and designated Guest Inviter users unless broad member-driven guest invitations are explicitly required and governed."

            Write-Host "WARNING  Guest invitation permissions are broadly delegated." -ForegroundColor Yellow
        }

        "adminsGuestInvitersAndAllMembers" {

            $Status = "WARNING"
            $Severity = "Medium"

            $Finding = "All member users are permitted to invite external guest users."

            $Recommendation = "Review whether all member users require guest invitation capability. Consider restricting invitations to administrators and designated Guest Inviters."

            Write-Host "WARNING  All member users can invite guests." -ForegroundColor Yellow
        }

        "adminsAndGuestInviters" {

            $Status = "PASS"
            $Severity = "None"

            $Finding = "Guest invitations are restricted to administrators and designated Guest Inviter users."

            $Recommendation = "Continue periodically reviewing Guest Inviter assignments and external collaboration governance."

            Write-Host "PASS  Guest invitation permissions are appropriately restricted." -ForegroundColor Green
        }

        "none" {

            $Status = "PASS"
            $Severity = "None"

            $Finding = "Guest invitations are disabled."

            $Recommendation = "No immediate remediation is required. Confirm this restrictive configuration remains aligned with collaboration requirements."

            Write-Host "PASS  Guest invitations are disabled." -ForegroundColor Green
        }

        default {

            $Status = "WARNING"
            $Severity = "Medium"

            $Finding = "TenantIQ could not classify the guest invitation setting '$InviteSetting'."

            $Recommendation = "Review the Entra external collaboration authorization policy and verify who is permitted to invite guest users."

            Write-Host "WARNING  Guest invitation configuration requires manual review." -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Guest Invitation Restrictions" `
        -Category "External Identities" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Guest Invitation Restrictions health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Guest Invitation Restrictions health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Guest Invitation Restrictions assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Guest Invitation Restrictions" `
        -Category "External Identities" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Policy.Read.All is consented and Microsoft.Graph.Authentication is available." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
