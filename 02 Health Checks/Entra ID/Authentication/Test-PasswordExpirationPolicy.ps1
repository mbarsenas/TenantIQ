$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Password Expiration Policy health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph cmdlet
    # ============================================================

    if (-not (Get-Command Get-MgDomain -ErrorAction SilentlyContinue)) {

        throw "Get-MgDomain is not available. Install or repair Microsoft.Graph.Identity.DirectoryManagement."
    }


    # ============================================================
    # Verify Graph connection and permission
    # ============================================================

    $RequiredScope = "Domain.Read.All"

    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext -or $GraphContext.Scopes -notcontains $RequiredScope) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with domain read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes $RequiredScope
    }


    # ============================================================
    # Retrieve tenant domains
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra password expiration policy..." `
        -ForegroundColor Cyan

    $Domains = @(
        Get-MgDomain `
            -All `
            -ErrorAction Stop
    )

    $VerifiedDomains = @(
        $Domains |
        Where-Object {
            $_.IsVerified -eq $true
        }
    )

    $ManagedDomains = @(
        $VerifiedDomains |
        Where-Object {
            $_.AuthenticationType -eq "Managed"
        }
    )


    # ============================================================
    # Normalize domain password policy
    # ============================================================

    $NeverExpireValue = [int64]2147483647

    $DomainAssessment = @()

    foreach ($Domain in $ManagedDomains) {

        $ValidityDays = $Domain.PasswordValidityPeriodInDays
        $NotificationDays = $Domain.PasswordNotificationWindowInDays

        $NeverExpires = $false

        if ($null -eq $ValidityDays) {

            # Microsoft Entra defaults newer tenants to no expiration.
            $NeverExpires = $true
        }
        elseif ([int64]$ValidityDays -ge $NeverExpireValue) {

            $NeverExpires = $true
        }

        $DomainAssessment += [PSCustomObject]@{

            DomainName             = $Domain.Id
            IsDefault              = $Domain.IsDefault
            AuthenticationType     = $Domain.AuthenticationType
            PasswordValidityDays   = $ValidityDays
            NotificationWindowDays = $NotificationDays
            NeverExpires           = $NeverExpires
        }
    }


    # ============================================================
    # Calculate findings
    # ============================================================

    $DefaultManagedDomain = @(
        $DomainAssessment |
        Where-Object {
            $_.IsDefault -eq $true
        }
    ) | Select-Object -First 1

    $ExpiringDomains = @(
        $DomainAssessment |
        Where-Object {
            $_.NeverExpires -eq $false
        }
    )

    $NeverExpireDomains = @(
        $DomainAssessment |
        Where-Object {
            $_.NeverExpires -eq $true
        }
    )


    # ============================================================
    # Console output
    # ============================================================

    Write-Host ""
    Write-Host "==========================================================" `
        -ForegroundColor Cyan

    Write-Host "              TenantIQ Entra ID Assessment" `
        -ForegroundColor Cyan

    Write-Host "==========================================================" `
        -ForegroundColor Cyan

    Write-Host ""

    Write-Host "Password Expiration Policy" `
        -ForegroundColor Cyan

    Write-Host "--------------------------"
    Write-Host ""

    Write-Host "Verified Domains          : $($VerifiedDomains.Count)"
    Write-Host "Managed Domains           : $($ManagedDomains.Count)"

    Write-Host "Never-Expire Domains      : " -NoNewline
    if ($NeverExpireDomains.Count -gt 0) {
        Write-Host $NeverExpireDomains.Count -ForegroundColor Green
    }
    else {
        Write-Host "0" -ForegroundColor Yellow
    }

    Write-Host "Expiring Password Domains : " -NoNewline
    if ($ExpiringDomains.Count -gt 0) {
        Write-Host $ExpiringDomains.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    if ($DefaultManagedDomain) {

        Write-Host ""
        Write-Host "Default Managed Domain    : $($DefaultManagedDomain.DomainName)"

        if ($DefaultManagedDomain.NeverExpires) {

            Write-Host "Default Password Expiry   : Never" `
                -ForegroundColor Green
        }
        else {

            Write-Host "Default Password Expiry   : $($DefaultManagedDomain.PasswordValidityDays) days" `
                -ForegroundColor Yellow
        }
    }

    Write-Host ""


    # ============================================================
    # Display domain policy inventory
    # ============================================================

    if ($DomainAssessment.Count -gt 0) {

        Write-Host "Managed Domain Password Policy Inventory" `
            -ForegroundColor Cyan

        Write-Host "----------------------------------------"

        $DomainAssessment |
            Sort-Object `
                @{Expression = { if ($_.IsDefault) { 0 } else { 1 } }},
                DomainName |
            Format-Table `
                DomainName,
                IsDefault,
                AuthenticationType,
                PasswordValidityDays,
                NotificationWindowDays,
                NeverExpires `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($VerifiedDomains.Count -eq 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "No verified Entra domains were returned."

        $Recommendation = "Verify domain visibility and ensure Domain.Read.All is consented."

        Write-Host "FAIL  No verified Entra domains were detected." `
            -ForegroundColor Red
    }
    elseif ($ManagedDomains.Count -eq 0) {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "No managed Entra domains were detected. Password expiration for federated domains is governed by the external identity provider or on-premises authority."

        $Recommendation = "Review password policy at the authoritative identity provider for federated domains."

        Write-Host "PASS  No managed Entra domains require cloud password expiration assessment." `
            -ForegroundColor Green
    }
    elseif ($ExpiringDomains.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $DomainList = (
            $ExpiringDomains.DomainName |
            Sort-Object
        ) -join ", "

        $Finding = "$($ExpiringDomains.Count) managed domain(s) use periodic password expiration: $DomainList."

        $Recommendation = "Review whether periodic password expiration is still required. Microsoft recommends that cloud-only passwords not be forced to expire periodically unless a specific risk or compliance requirement justifies it."

        Write-Host "WARNING  Periodic password expiration is configured." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($ManagedDomains.Count) managed domain(s) were reviewed and all are configured for non-expiring cloud password policy."

        $Recommendation = "Continue using modern controls such as MFA, Conditional Access, password protection, and risk-based remediation rather than routine password expiration."

        Write-Host "PASS  Managed domain password expiration policy aligns with modern guidance." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Password Expiration Policy" `
        -Category "Authentication" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Password Expiration Policy health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Password Expiration Policy health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Password Expiration Policy assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Password Expiration Policy" `
        -Category "Authentication" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Identity.DirectoryManagement is available and ensure Domain.Read.All is consented." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}