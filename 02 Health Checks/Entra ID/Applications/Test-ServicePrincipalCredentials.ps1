$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Service Principal Credentials health check." `
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
        Write-Host "Connecting to Microsoft Graph with application read permissions..." `
            -ForegroundColor Cyan

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

            $Response = Invoke-MgGraphRequest `
                -Method GET `
                -Uri $NextUri `
                -ErrorAction Stop

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
    # Retrieve service principals and credential metadata
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra service principal credentials..." `
        -ForegroundColor Cyan

    $Uri = "https://graph.microsoft.com/v1.0/servicePrincipals?`$select=id,appId,displayName,accountEnabled,servicePrincipalType,passwordCredentials,keyCredentials"

    $ServicePrincipals = @(
        Get-TenantIQGraphCollection -Uri $Uri
    )

    $Now = Get-Date
    $WarningDate = $Now.AddDays(30)

    $CredentialInventory = @()


    # ============================================================
    # Build credential inventory
    # ============================================================

    foreach ($ServicePrincipal in $ServicePrincipals) {

        $PasswordCredentials = @($ServicePrincipal.passwordCredentials)

        foreach ($Credential in $PasswordCredentials) {

            $EndDate = $null

            if ($Credential.endDateTime) {
                $EndDate = [datetime]$Credential.endDateTime
            }

            $DaysRemaining = $null

            if ($EndDate) {
                $DaysRemaining = [math]::Floor(($EndDate - $Now).TotalDays)
            }

            $State = "Valid"

            if ($EndDate -and $EndDate -lt $Now) {
                $State = "Expired"
            }
            elseif ($EndDate -and $EndDate -le $WarningDate) {
                $State = "Expiring"
            }

            $CredentialInventory += [PSCustomObject]@{
                Application       = [string]$ServicePrincipal.displayName
                AppId             = [string]$ServicePrincipal.appId
                AccountEnabled    = [bool]$ServicePrincipal.accountEnabled
                CredentialType    = "Secret"
                DisplayName       = [string]$Credential.displayName
                StartDateTime     = $Credential.startDateTime
                EndDateTime       = $Credential.endDateTime
                DaysRemaining     = $DaysRemaining
                State             = $State
            }
        }


        $KeyCredentials = @($ServicePrincipal.keyCredentials)

        foreach ($Credential in $KeyCredentials) {

            $EndDate = $null

            if ($Credential.endDateTime) {
                $EndDate = [datetime]$Credential.endDateTime
            }

            $DaysRemaining = $null

            if ($EndDate) {
                $DaysRemaining = [math]::Floor(($EndDate - $Now).TotalDays)
            }

            $State = "Valid"

            if ($EndDate -and $EndDate -lt $Now) {
                $State = "Expired"
            }
            elseif ($EndDate -and $EndDate -le $WarningDate) {
                $State = "Expiring"
            }

            $CredentialInventory += [PSCustomObject]@{
                Application       = [string]$ServicePrincipal.displayName
                AppId             = [string]$ServicePrincipal.appId
                AccountEnabled    = [bool]$ServicePrincipal.accountEnabled
                CredentialType    = "Certificate"
                DisplayName       = [string]$Credential.displayName
                StartDateTime     = $Credential.startDateTime
                EndDateTime       = $Credential.endDateTime
                DaysRemaining     = $DaysRemaining
                State             = $State
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
        Where-Object {
            $_.CredentialType -eq "Secret"
        }
    )

    $Certificates = @(
        $CredentialInventory |
        Where-Object {
            $_.CredentialType -eq "Certificate"
        }
    )

    $ExpiredCredentials = @(
        $CredentialInventory |
        Where-Object {
            $_.State -eq "Expired"
        }
    )

    $ExpiringCredentials = @(
        $CredentialInventory |
        Where-Object {
            $_.State -eq "Expiring"
        }
    )

    $ExpiredEnabledCredentials = @(
        $ExpiredCredentials |
        Where-Object {
            $_.AccountEnabled -eq $true
        }
    )

    $ExpiringEnabledCredentials = @(
        $ExpiringCredentials |
        Where-Object {
            $_.AccountEnabled -eq $true
        }
    )


    # ============================================================
    # Console output
    # ============================================================

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Service Principal Credentials" -ForegroundColor Cyan
    Write-Host "-----------------------------"
    Write-Host ""

    Write-Host "Service Principals Reviewed    : $($ServicePrincipals.Count)"
    Write-Host "Apps With Credentials          : $($AppsWithCredentials.Count)"
    Write-Host "Client Secrets                 : $($Secrets.Count)"
    Write-Host "Certificates                   : $($Certificates.Count)"

    Write-Host "Expired Credentials            : " -NoNewline
    if ($ExpiredCredentials.Count -gt 0) {
        Write-Host $ExpiredCredentials.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Expiring Within 30 Days        : " -NoNewline
    if ($ExpiringCredentials.Count -gt 0) {
        Write-Host $ExpiringCredentials.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Expired On Enabled SPs         : " -NoNewline
    if ($ExpiredEnabledCredentials.Count -gt 0) {
        Write-Host $ExpiredEnabledCredentials.Count -ForegroundColor Red
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
        Where-Object {
            $_.State -in @("Expired", "Expiring")
        } |
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
                AccountEnabled,
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

    if ($ExpiredEnabledCredentials.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$($ExpiredEnabledCredentials.Count) expired service principal credential(s) were found on enabled service principals."

        $Recommendation = "Review expired credentials on enabled service principals. Rotate credentials still required by active workloads and remove obsolete credentials after confirming they are no longer used."

        Write-Host "FAIL  Expired credentials exist on enabled service principals." `
            -ForegroundColor Red
    }
    elseif ($ExpiringEnabledCredentials.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($ExpiringEnabledCredentials.Count) service principal credential(s) on enabled service principals expire within 30 days."

        $Recommendation = "Plan credential rotation before expiration and validate dependent applications after the replacement credential is deployed."

        Write-Host "WARNING  Service principal credentials are approaching expiration." `
            -ForegroundColor Yellow
    }
    elseif ($ExpiredCredentials.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "$($ExpiredCredentials.Count) expired credential(s) were found, but they are not associated with currently enabled service principals."

        $Recommendation = "Review and remove stale credentials and obsolete service principal objects when they are no longer required."

        Write-Host "WARNING  Stale expired service principal credentials require cleanup." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($CredentialInventory.Count) service principal credential(s) were reviewed with no expired credentials or credentials expiring within 30 days detected."

        $Recommendation = "Continue monitoring application credential expiration and use managed identities or workload identity federation where supported to reduce long-lived credential use."

        Write-Host "PASS  Service principal credential expiration posture appears healthy." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Service Principal Credentials" `
        -Category "Applications" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Service Principal Credentials health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Service Principal Credentials health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Service Principal Credentials assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Service Principal Credentials" `
        -Category "Applications" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Application.Read.All is consented and Microsoft.Graph.Authentication is available." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}