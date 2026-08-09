$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID App Registrations health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph cmdlets
    # ============================================================

    $RequiredCommands = @(
        "Get-MgApplication"
        "Get-MgApplicationOwner"
    )

    foreach ($Command in $RequiredCommands) {

        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {

            throw "Required Microsoft Graph cmdlet '$Command' is not available. Install or repair Microsoft.Graph.Applications."
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

        Connect-MgGraph `
            -Scopes $RequiredScope
    }


    # ============================================================
    # Retrieve app registrations
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra app registrations..." `
        -ForegroundColor Cyan

    $Applications = @(
        Get-MgApplication `
            -All `
            -Property `
                Id,
                AppId,
                DisplayName,
                SignInAudience,
                PublisherDomain,
                CreatedDateTime,
                PasswordCredentials,
                KeyCredentials `
            -ErrorAction Stop
    )


    # ============================================================
    # Analyze app registrations
    # ============================================================

    $Now = Get-Date
    $WarningDate = $Now.AddDays(30)

    $Assessment = @()

    foreach ($Application in $Applications) {

        $Owners = @()

        try {

            $Owners = @(
                Get-MgApplicationOwner `
                    -ApplicationId $Application.Id `
                    -All `
                    -ErrorAction Stop
            )
        }
        catch {

            Write-ExchangeAILog `
                -Message "Unable to retrieve owners for app registration '$($Application.DisplayName)'. $($_.Exception.Message)" `
                -Level WARNING
        }

        $PasswordCredentials = @(
            $Application.PasswordCredentials
        )

        $KeyCredentials = @(
            $Application.KeyCredentials
        )

        $ExpiredPasswords = @(
            $PasswordCredentials |
            Where-Object {
                $null -ne $_.EndDateTime -and
                [datetime]$_.EndDateTime -lt $Now
            }
        )

        $ExpiringPasswords = @(
            $PasswordCredentials |
            Where-Object {
                $null -ne $_.EndDateTime -and
                [datetime]$_.EndDateTime -ge $Now -and
                [datetime]$_.EndDateTime -le $WarningDate
            }
        )

        $ExpiredCertificates = @(
            $KeyCredentials |
            Where-Object {
                $null -ne $_.EndDateTime -and
                [datetime]$_.EndDateTime -lt $Now
            }
        )

        $ExpiringCertificates = @(
            $KeyCredentials |
            Where-Object {
                $null -ne $_.EndDateTime -and
                [datetime]$_.EndDateTime -ge $Now -and
                [datetime]$_.EndDateTime -le $WarningDate
            }
        )

        $Assessment += [PSCustomObject]@{

            Id                         = $Application.Id
            DisplayName                = $Application.DisplayName
            AppId                      = $Application.AppId
            SignInAudience             = $Application.SignInAudience
            PublisherDomain            = $Application.PublisherDomain
            CreatedDateTime            = $Application.CreatedDateTime
            OwnerCount                 = $Owners.Count
            PasswordCredentialCount    = $PasswordCredentials.Count
            CertificateCredentialCount = $KeyCredentials.Count
            ExpiredPasswords           = $ExpiredPasswords.Count
            ExpiringPasswords          = $ExpiringPasswords.Count
            ExpiredCertificates        = $ExpiredCertificates.Count
            ExpiringCertificates       = $ExpiringCertificates.Count
            ExpiredCredentials         = (
                $ExpiredPasswords.Count +
                $ExpiredCertificates.Count
            )
            ExpiringCredentials        = (
                $ExpiringPasswords.Count +
                $ExpiringCertificates.Count
            )
        }
    }


    # ============================================================
    # Calculate findings
    # ============================================================

    $OwnerlessApplications = @(
        $Assessment |
        Where-Object {
            $_.OwnerCount -eq 0
        }
    )

    $ExpiredCredentialApplications = @(
        $Assessment |
        Where-Object {
            $_.ExpiredCredentials -gt 0
        }
    )

    $ExpiringCredentialApplications = @(
        $Assessment |
        Where-Object {
            $_.ExpiringCredentials -gt 0
        }
    )

    $PasswordBasedApplications = @(
        $Assessment |
        Where-Object {
            $_.PasswordCredentialCount -gt 0
        }
    )

    $CertificateBasedApplications = @(
        $Assessment |
        Where-Object {
            $_.CertificateCredentialCount -gt 0
        }
    )

    $NoCredentialApplications = @(
        $Assessment |
        Where-Object {
            $_.PasswordCredentialCount -eq 0 -and
            $_.CertificateCredentialCount -eq 0
        }
    )

    $MultiTenantApplications = @(
        $Assessment |
        Where-Object {
            $_.SignInAudience -in @(
                "AzureADMultipleOrgs"
                "AzureADandPersonalMicrosoftAccount"
                "PersonalMicrosoftAccount"
            )
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

    Write-Host "App Registrations" -ForegroundColor Cyan
    Write-Host "-----------------"
    Write-Host ""

    Write-Host "Total App Registrations        : $($Assessment.Count)"

    Write-Host "Ownerless Applications         : " -NoNewline
    if ($OwnerlessApplications.Count -gt 0) {
        Write-Host $OwnerlessApplications.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Expired Credential Findings    : " -NoNewline
    if ($ExpiredCredentialApplications.Count -gt 0) {
        Write-Host $ExpiredCredentialApplications.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Credentials Expiring <= 30 Days: " -NoNewline
    if ($ExpiringCredentialApplications.Count -gt 0) {
        Write-Host $ExpiringCredentialApplications.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Using Password Credentials     : $($PasswordBasedApplications.Count)"
    Write-Host "Using Certificate Credentials  : $($CertificateBasedApplications.Count)"
    Write-Host "No Credentials Configured      : $($NoCredentialApplications.Count)"
    Write-Host "Multi-Tenant Registrations     : $($MultiTenantApplications.Count)"
    Write-Host ""


    # ============================================================
    # Display noteworthy app registrations
    # ============================================================

    $NoteworthyApplications = @(
        $Assessment |
        Where-Object {
            $_.OwnerCount -eq 0 -or
            $_.ExpiredCredentials -gt 0 -or
            $_.ExpiringCredentials -gt 0
        }
    )

    if ($NoteworthyApplications.Count -gt 0) {

        Write-Host "App Registration Findings" `
            -ForegroundColor Cyan

        Write-Host "-------------------------"

        $NoteworthyApplications |
            Sort-Object `
                @{Expression = { if ($_.ExpiredCredentials -gt 0) { 0 } else { 1 } }},
                @{Expression = { if ($_.ExpiringCredentials -gt 0) { 0 } else { 1 } }},
                DisplayName |
            Format-Table `
                DisplayName,
                OwnerCount,
                PasswordCredentialCount,
                CertificateCredentialCount,
                ExpiredCredentials,
                ExpiringCredentials,
                SignInAudience `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($Assessment.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "No Entra application registrations were detected."

        $Recommendation = "Confirm application registration visibility and verify Application.Read.All permission is available."

        Write-Host "WARNING  No application registrations were detected." `
            -ForegroundColor Yellow
    }
    elseif ($ExpiredCredentialApplications.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$($ExpiredCredentialApplications.Count) application registration(s) contain expired password or certificate credentials."

        $Recommendation = "Review expired application credentials, remove stale credentials, and validate active authentication methods and ownership."

        Write-Host "FAIL  Expired application credentials were detected." `
            -ForegroundColor Red
    }
    elseif ($ExpiringCredentialApplications.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "$($ExpiringCredentialApplications.Count) application registration(s) have credentials expiring within 30 days."

        $Recommendation = "Rotate or renew expiring application credentials before expiration and notify the responsible application owners."

        Write-Host "WARNING  Application credentials are approaching expiration." `
            -ForegroundColor Yellow
    }
    elseif ($OwnerlessApplications.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($OwnerlessApplications.Count) application registration(s) have no detected owners."

        $Recommendation = "Review ownerless app registrations, assign accountable owners where appropriate, and remove obsolete registrations."

        Write-Host "WARNING  Ownerless app registrations require review." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($Assessment.Count) application registration(s) were reviewed with no expired credentials, near-term credential expirations, or ownerless registrations detected."

        $Recommendation = "Continue periodic application ownership and credential lifecycle reviews."

        Write-Host "PASS  App registration posture appears healthy." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "App Registrations" `
        -Category "Applications" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID App Registrations health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID App Registrations health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "App Registrations assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "App Registrations" `
        -Category "Applications" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Applications is available and ensure Application.Read.All is consented." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}