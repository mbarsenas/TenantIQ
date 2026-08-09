$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Application Proxy health check." `
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
    # Retrieve service principals with Application Proxy settings
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra Application Proxy configuration..." `
        -ForegroundColor Cyan

    $ServicePrincipals = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$select=id,displayName,accountEnabled,servicePrincipalType,onPremisesPublishing"
    )

    $PublishedApplications = @(
        $ServicePrincipals |
        Where-Object {
            $null -ne $_.onPremisesPublishing
        }
    )


    # ============================================================
    # Normalize inventory
    # ============================================================

    $Inventory = @()

    foreach ($App in $PublishedApplications) {

        $Publishing = $App.onPremisesPublishing

        $ExternalUrl = [string]$Publishing.externalUrl
        $InternalUrl = [string]$Publishing.internalUrl
        $IsOnPremPublishingEnabled = [bool]$Publishing.isOnPremPublishingEnabled
        $IsHttpOnlyCookieEnabled = [bool]$Publishing.isHttpOnlyCookieEnabled
        $IsSecureCookieEnabled = [bool]$Publishing.isSecureCookieEnabled
        $IsPersistentCookieEnabled = [bool]$Publishing.isPersistentCookieEnabled
        $ExternalAuthenticationType = [string]$Publishing.externalAuthenticationType

        $Inventory += [PSCustomObject]@{
            DisplayName                 = [string]$App.displayName
            AccountEnabled              = [bool]$App.accountEnabled
            PublishingEnabled           = $IsOnPremPublishingEnabled
            ExternalAuthenticationType  = $ExternalAuthenticationType
            ExternalUrl                 = $ExternalUrl
            InternalUrl                 = $InternalUrl
            HttpOnlyCookie              = $IsHttpOnlyCookieEnabled
            SecureCookie                = $IsSecureCookieEnabled
            PersistentCookie            = $IsPersistentCookieEnabled
        }
    }


    # ============================================================
    # Findings
    # ============================================================

    $EnabledPublishedApps = @(
        $Inventory |
        Where-Object {
            $_.AccountEnabled -eq $true -and
            $_.PublishingEnabled -eq $true
        }
    )

    $DisabledPublishedApps = @(
        $Inventory |
        Where-Object {
            $_.AccountEnabled -eq $false -or
            $_.PublishingEnabled -eq $false
        }
    )

    $PassthroughApps = @(
        $EnabledPublishedApps |
        Where-Object {
            $_.ExternalAuthenticationType -match "passthru|passthrough"
        }
    )

    $InsecureCookieApps = @(
        $EnabledPublishedApps |
        Where-Object {
            $_.SecureCookie -ne $true -or
            $_.HttpOnlyCookie -ne $true
        }
    )

    $PersistentCookieApps = @(
        $EnabledPublishedApps |
        Where-Object {
            $_.PersistentCookie -eq $true
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

    Write-Host "Application Proxy" -ForegroundColor Cyan
    Write-Host "-----------------"
    Write-Host ""

    Write-Host "Published Applications        : $($Inventory.Count)"
    Write-Host "Enabled Published Apps        : $($EnabledPublishedApps.Count)"
    Write-Host "Disabled Published Apps       : $($DisabledPublishedApps.Count)"

    Write-Host "Passthrough Authentication    : " -NoNewline
    if ($PassthroughApps.Count -gt 0) {
        Write-Host $PassthroughApps.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Cookie Hardening Issues       : " -NoNewline
    if ($InsecureCookieApps.Count -gt 0) {
        Write-Host $InsecureCookieApps.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Persistent Cookie Apps        : " -NoNewline
    if ($PersistentCookieApps.Count -gt 0) {
        Write-Host $PersistentCookieApps.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host ""


    # ============================================================
    # Display inventory
    # ============================================================

    if ($Inventory.Count -gt 0) {

        Write-Host "Application Proxy Inventory" -ForegroundColor Cyan
        Write-Host "---------------------------"

        $Inventory |
            Sort-Object DisplayName |
            Format-Table `
                DisplayName,
                AccountEnabled,
                PublishingEnabled,
                ExternalAuthenticationType,
                HttpOnlyCookie,
                SecureCookie,
                PersistentCookie `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    #
    # No Application Proxy apps is not a problem. This check only
    # evaluates posture when Application Proxy is actually in use.
    # ============================================================

    $Stopwatch.Stop()

    if ($Inventory.Count -eq 0) {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "No Microsoft Entra Application Proxy published applications were detected."

        $Recommendation = "No Application Proxy remediation is required. Reassess if on-premises applications are later published through Entra Application Proxy."

        Write-Host "PASS  No Application Proxy applications are configured." `
            -ForegroundColor Green
    }
    elseif ($PassthroughApps.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "$($PassthroughApps.Count) enabled Application Proxy application(s) use passthrough authentication."

        $Recommendation = "Review passthrough-published applications and use Microsoft Entra preauthentication where application compatibility permits so Conditional Access and identity protections can be enforced before traffic reaches the application."

        Write-Host "WARNING  Application Proxy passthrough authentication requires review." `
            -ForegroundColor Yellow
    }
    elseif ($InsecureCookieApps.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($InsecureCookieApps.Count) enabled Application Proxy application(s) do not have both Secure and HttpOnly cookie protections enabled."

        $Recommendation = "Review Application Proxy cookie settings and enable Secure and HttpOnly protections where supported."

        Write-Host "WARNING  Application Proxy cookie hardening requires review." `
            -ForegroundColor Yellow
    }
    elseif ($PersistentCookieApps.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "$($PersistentCookieApps.Count) enabled Application Proxy application(s) use persistent cookies."

        $Recommendation = "Review whether persistent cookies are required and confirm session persistence aligns with the application's security requirements."

        Write-Host "WARNING  Persistent Application Proxy cookies require review." `
            -ForegroundColor Yellow
    }
    elseif ($DisabledPublishedApps.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "$($DisabledPublishedApps.Count) Application Proxy application(s) are disabled or no longer actively published."

        $Recommendation = "Review disabled Application Proxy definitions and remove stale published application configurations when they are no longer required."

        Write-Host "WARNING  Disabled Application Proxy applications require review." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($EnabledPublishedApps.Count) enabled Application Proxy application(s) were reviewed with no passthrough authentication or cookie-hardening issues detected."

        $Recommendation = "Continue reviewing Application Proxy preauthentication, session settings, and published application inventory."

        Write-Host "PASS  Application Proxy posture appears healthy." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Application Proxy" `
        -Category "Applications" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Application Proxy health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Application Proxy health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Application Proxy assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Application Proxy" `
        -Category "Applications" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Application.Read.All is consented and that Microsoft.Graph.Authentication is available." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}