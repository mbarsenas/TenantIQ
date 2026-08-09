$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Application Credentials health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph commands
    # ============================================================

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

    # ============================================================
    # Verify Graph connection and permissions
    # ============================================================

    $RequiredScope = "Application.Read.All"
    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext -or $GraphContext.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with application read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope
    }

    # ============================================================
    # Helper: Retrieve paged Graph collection
    # ============================================================

    function Get-TenantIQGraphCollection {
        param(
            [Parameter(Mandatory)]
            [string]$Uri
        )

        $Items = @()
        $NextUri = $Uri

        while (-not [string]::IsNullOrWhiteSpace($NextUri)) {
            $Response = Invoke-MgGraphRequest -Method GET -Uri $NextUri -ErrorAction Stop

            if ($Response -is [System.Collections.IDictionary]) {
                if ($Response.Contains("value")) {
                    $Items += @($Response["value"])
                }

                if ($Response.Contains("@odata.nextLink")) {
                    $NextUri = [string]$Response["@odata.nextLink"]
                }
                else {
                    $NextUri = $null
                }
            }
            else {
                $Items += @($Response.value)
                $NextUri = [string]$Response.'@odata.nextLink'
            }
        }

        return @($Items)
    }

    # ============================================================
    # Retrieve application registrations and credentials
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra application registration credentials..." -ForegroundColor Cyan

    $Uri = "https://graph.microsoft.com/v1.0/applications?`$select=id,appId,displayName,passwordCredentials,keyCredentials"

    $Applications = @(
        Get-TenantIQGraphCollection -Uri $Uri
    )

    $Now = Get-Date
    $WarningDate = $Now.AddDays(30)
    $CredentialInventory = @()

    foreach ($Application in $Applications) {

        foreach ($Credential in @($Application.passwordCredentials)) {

            $EndDate = $null
            if ($Credential.endDateTime) {
                $EndDate = [datetime]$Credential.endDateTime
            }

            $DaysRemaining = $null
            $State = "Valid"

            if ($EndDate) {
                $DaysRemaining = [math]::Floor(($EndDate - $Now).TotalDays)

                if ($EndDate -lt $Now) {
                    $State = "Expired"
                }
                elseif ($EndDate -le $WarningDate) {
                    $State = "Expiring"
                }
            }
            else {
                $State = "NoExpiration"
            }

            $CredentialInventory += [PSCustomObject]@{
                Application    = [string]$Application.displayName
                AppId          = [string]$Application.appId
                CredentialType = "Secret"
                DisplayName    = [string]$Credential.displayName
                StartDateTime  = $Credential.startDateTime
                EndDateTime    = $Credential.endDateTime
                DaysRemaining  = $DaysRemaining
                State          = $State
            }
        }

        foreach ($Credential in @($Application.keyCredentials)) {

            $EndDate = $null
            if ($Credential.endDateTime) {
                $EndDate = [datetime]$Credential.endDateTime
            }

            $DaysRemaining = $null
            $State = "Valid"

            if ($EndDate) {
                $DaysRemaining = [math]::Floor(($EndDate - $Now).TotalDays)

                if ($EndDate -lt $Now) {
                    $State = "Expired"
                }
                elseif ($EndDate -le $WarningDate) {
                    $State = "Expiring"
                }
            }
            else {
                $State = "NoExpiration"
            }

            $CredentialInventory += [PSCustomObject]@{
                Application    = [string]$Application.displayName
                AppId          = [string]$Application.appId
                CredentialType = "Certificate"
                DisplayName    = [string]$Credential.displayName
                StartDateTime  = $Credential.startDateTime
                EndDateTime    = $Credential.endDateTime
                DaysRemaining  = $DaysRemaining
                State          = $State
            }
        }
    }

    # ============================================================
    # Calculate findings
    # ============================================================

    $AppsWithCredentials = @(
        $CredentialInventory |
        Select-Object -ExpandProperty AppId -Unique
    )

    $Secrets = @(
        $CredentialInventory |
        Where-Object { $_.CredentialType -eq "Secret" }
    )

    $Certificates = @(
        $CredentialInventory |
        Where-Object { $_.CredentialType -eq "Certificate" }
    )

    $ExpiredCredentials = @(
        $CredentialInventory |
        Where-Object { $_.State -eq "Expired" }
    )

    $ExpiringCredentials = @(
        $CredentialInventory |
        Where-Object { $_.State -eq "Expiring" }
    )

    $NoExpirationCredentials = @(
        $CredentialInventory |
        Where-Object { $_.State -eq "NoExpiration" }
    )

    # ============================================================
    # Console output
    # ============================================================

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Application Credentials" -ForegroundColor Cyan
    Write-Host "-----------------------"
    Write-Host ""

    Write-Host "Application Registrations Reviewed : $($Applications.Count)"
    Write-Host "Apps With Credentials              : $($AppsWithCredentials.Count)"
    Write-Host "Client Secrets                     : $($Secrets.Count)"
    Write-Host "Certificates                       : $($Certificates.Count)"

    Write-Host "Expired Credentials                : " -NoNewline
    if ($ExpiredCredentials.Count -gt 0) {
        Write-Host $ExpiredCredentials.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Expiring Within 30 Days            : " -NoNewline
    if ($ExpiringCredentials.Count -gt 0) {
        Write-Host $ExpiringCredentials.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Credentials Without Expiration     : " -NoNewline
    if ($NoExpirationCredentials.Count -gt 0) {
        Write-Host $NoExpirationCredentials.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host ""

    # ============================================================
    # Display credentials requiring attention
    # ============================================================

    $ReviewCredentials = @(
        $CredentialInventory |
        Where-Object { $_.State -in @("Expired", "Expiring", "NoExpiration") } |
        Sort-Object EndDateTime
    )

    if ($ReviewCredentials.Count -gt 0) {

        Write-Host "Credential Review Inventory" -ForegroundColor Cyan
        Write-Host "---------------------------"

        $ReviewCredentials |
            Format-Table `
                Application,
                CredentialType,
                DisplayName,
                EndDateTime,
                DaysRemaining,
                State `
                -AutoSize

        Write-Host ""
    }

    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($ExpiredCredentials.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"
        $Finding = "$($ExpiredCredentials.Count) expired credential(s) were found across Entra application registrations."
        $Recommendation = "Review expired application credentials. Rotate credentials still required by active workloads and remove obsolete credentials after confirming they are no longer used."

        Write-Host "FAIL  Expired application credentials were detected." -ForegroundColor Red
    }
    elseif ($ExpiringCredentials.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($ExpiringCredentials.Count) application credential(s) expire within 30 days."
        $Recommendation = "Plan credential rotation before expiration and validate dependent applications after replacement credentials are deployed."

        Write-Host "WARNING  Application credentials are approaching expiration." -ForegroundColor Yellow
    }
    elseif ($NoExpirationCredentials.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($NoExpirationCredentials.Count) application credential(s) do not expose an expiration date."
        $Recommendation = "Review credentials without expiration metadata and prefer bounded credential lifetimes, managed identities, or workload identity federation where supported."

        Write-Host "WARNING  Application credentials without expiration require review." -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($CredentialInventory.Count) application registration credential(s) were reviewed with no expired credentials or credentials expiring within 30 days detected."
        $Recommendation = "Continue monitoring application credential expiration and prefer managed identities or workload identity federation where supported."

        Write-Host "PASS  Application credential expiration posture appears healthy." -ForegroundColor Green
    }

    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Application Credentials" `
        -Category "Applications" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Application Credentials health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Application Credentials health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Application Credentials assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Application Credentials" `
        -Category "Applications" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Application.Read.All is consented and Microsoft.Graph.Authentication is available." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}