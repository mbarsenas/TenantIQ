$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Service Principals health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph cmdlets
    # ============================================================

    $RequiredCommands = @(
        "Get-MgServicePrincipal"
        "Get-MgServicePrincipalOwner"
        "Get-MgRoleManagementDirectoryRoleAssignment"
    )

    foreach ($Command in $RequiredCommands) {

        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {

            throw "Required Microsoft Graph cmdlet '$Command' is not available. Install or repair the Microsoft Graph PowerShell SDK."
        }
    }


    # ============================================================
    # Verify Graph connection and permissions
    # ============================================================

    $RequiredScopes = @(
        "Application.Read.All"
        "RoleManagement.Read.Directory"
    )

    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue
    $ReconnectRequired = $false

    if (-not $GraphContext) {

        $ReconnectRequired = $true
    }
    else {

        foreach ($Scope in $RequiredScopes) {

            if ($GraphContext.Scopes -notcontains $Scope) {

                $ReconnectRequired = $true
                break
            }
        }
    }

    if ($ReconnectRequired) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with application read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes $RequiredScopes

        $GraphContext = Get-MgContext -ErrorAction Stop
    }

    $TenantId = [string]$GraphContext.TenantId


    # ============================================================
    # Retrieve service principals
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra service principals..." `
        -ForegroundColor Cyan

    $ServicePrincipals = @(
        Get-MgServicePrincipal `
            -All `
            -Property `
                Id,
                AppId,
                DisplayName,
                AccountEnabled,
                ServicePrincipalType,
                AppOwnerOrganizationId,
                PublisherName,
                PasswordCredentials,
                KeyCredentials `
            -ErrorAction Stop
    )


    # ============================================================
    # Focus assessment on tenant-owned application identities
    # ============================================================

    $ApplicationServicePrincipals = @(
        $ServicePrincipals |
        Where-Object {
            $_.ServicePrincipalType -eq "Application"
        }
    )

    $TenantOwnedServicePrincipals = @(
        $ApplicationServicePrincipals |
        Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.AppOwnerOrganizationId) -and
            [string]$_.AppOwnerOrganizationId -eq $TenantId
        }
    )


    # ============================================================
    # Retrieve directory role assignments to service principals
    # ============================================================

    $RoleAssignments = @(
        Get-MgRoleManagementDirectoryRoleAssignment `
            -All `
            -ErrorAction Stop
    )

    $RoleAssignmentPrincipalIds = @(
        $RoleAssignments |
        Select-Object -ExpandProperty PrincipalId -Unique
    )


    # ============================================================
    # Analyze tenant-owned service principals
    # ============================================================

    $Now = Get-Date
    $WarningDate = $Now.AddDays(30)

    $Assessment = @()

    foreach ($ServicePrincipal in $TenantOwnedServicePrincipals) {

        $Owners = @()

        try {

            $Owners = @(
                Get-MgServicePrincipalOwner `
                    -ServicePrincipalId $ServicePrincipal.Id `
                    -All `
                    -ErrorAction Stop
            )
        }
        catch {

            Write-ExchangeAILog `
                -Message "Unable to retrieve owners for service principal '$($ServicePrincipal.DisplayName)'. $($_.Exception.Message)" `
                -Level WARNING
        }

        $PasswordCredentials = @(
            $ServicePrincipal.PasswordCredentials
        )

        $KeyCredentials = @(
            $ServicePrincipal.KeyCredentials
        )

        $ExpiredPasswordCredentials = @(
            $PasswordCredentials |
            Where-Object {
                $null -ne $_.EndDateTime -and
                [datetime]$_.EndDateTime -lt $Now
            }
        )

        $ExpiringPasswordCredentials = @(
            $PasswordCredentials |
            Where-Object {
                $null -ne $_.EndDateTime -and
                [datetime]$_.EndDateTime -ge $Now -and
                [datetime]$_.EndDateTime -le $WarningDate
            }
        )

        $ExpiredKeyCredentials = @(
            $KeyCredentials |
            Where-Object {
                $null -ne $_.EndDateTime -and
                [datetime]$_.EndDateTime -lt $Now
            }
        )

        $ExpiringKeyCredentials = @(
            $KeyCredentials |
            Where-Object {
                $null -ne $_.EndDateTime -and
                [datetime]$_.EndDateTime -ge $Now -and
                [datetime]$_.EndDateTime -le $WarningDate
            }
        )

        $Assessment += [PSCustomObject]@{

            Id                        = $ServicePrincipal.Id
            DisplayName               = $ServicePrincipal.DisplayName
            AppId                     = $ServicePrincipal.AppId
            AccountEnabled            = $ServicePrincipal.AccountEnabled
            PublisherName             = $ServicePrincipal.PublisherName
            OwnerCount                = $Owners.Count
            PasswordCredentialCount   = $PasswordCredentials.Count
            KeyCredentialCount        = $KeyCredentials.Count
            ExpiredCredentials        = (
                $ExpiredPasswordCredentials.Count +
                $ExpiredKeyCredentials.Count
            )
            ExpiringCredentials       = (
                $ExpiringPasswordCredentials.Count +
                $ExpiringKeyCredentials.Count
            )
            HasDirectoryRole          = (
                $RoleAssignmentPrincipalIds -contains $ServicePrincipal.Id
            )
        }
    }


    # ============================================================
    # Calculate findings
    # ============================================================

    $EnabledTenantOwned = @(
        $Assessment |
        Where-Object {
            $_.AccountEnabled -eq $true
        }
    )

    $DisabledTenantOwned = @(
        $Assessment |
        Where-Object {
            $_.AccountEnabled -eq $false
        }
    )

    $OwnerlessServicePrincipals = @(
        $EnabledTenantOwned |
        Where-Object {
            $_.OwnerCount -eq 0
        }
    )

    $ExpiredCredentialServicePrincipals = @(
        $EnabledTenantOwned |
        Where-Object {
            $_.ExpiredCredentials -gt 0
        }
    )

    $ExpiringCredentialServicePrincipals = @(
        $EnabledTenantOwned |
        Where-Object {
            $_.ExpiringCredentials -gt 0
        }
    )

    $PrivilegedServicePrincipals = @(
        $Assessment |
        Where-Object {
            $_.HasDirectoryRole -eq $true
        }
    )

    $PrivilegedOwnerless = @(
        $PrivilegedServicePrincipals |
        Where-Object {
            $_.AccountEnabled -eq $true -and
            $_.OwnerCount -eq 0
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

    Write-Host "Service Principals" -ForegroundColor Cyan
    Write-Host "------------------"
    Write-Host ""

    Write-Host "All Service Principals          : $($ServicePrincipals.Count)"
    Write-Host "Application Service Principals  : $($ApplicationServicePrincipals.Count)"
    Write-Host "Tenant-Owned Service Principals : $($Assessment.Count)"
    Write-Host "Enabled Tenant-Owned            : $($EnabledTenantOwned.Count)"
    Write-Host "Disabled Tenant-Owned           : $($DisabledTenantOwned.Count)"

    Write-Host "Ownerless Enabled               : " -NoNewline
    if ($OwnerlessServicePrincipals.Count -gt 0) {
        Write-Host $OwnerlessServicePrincipals.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Expired Credential Findings     : " -NoNewline
    if ($ExpiredCredentialServicePrincipals.Count -gt 0) {
        Write-Host $ExpiredCredentialServicePrincipals.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Credentials Expiring <= 30 Days : " -NoNewline
    if ($ExpiringCredentialServicePrincipals.Count -gt 0) {
        Write-Host $ExpiringCredentialServicePrincipals.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Directory-Role Service Principals: " -NoNewline
    if ($PrivilegedServicePrincipals.Count -gt 0) {
        Write-Host $PrivilegedServicePrincipals.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Privileged + Ownerless           : " -NoNewline
    if ($PrivilegedOwnerless.Count -gt 0) {
        Write-Host $PrivilegedOwnerless.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host ""


    # ============================================================
    # Display noteworthy service principals
    # ============================================================

    $Noteworthy = @(
        $Assessment |
        Where-Object {
            $_.OwnerCount -eq 0 -or
            $_.ExpiredCredentials -gt 0 -or
            $_.ExpiringCredentials -gt 0 -or
            $_.HasDirectoryRole -eq $true
        }
    )

    if ($Noteworthy.Count -gt 0) {

        Write-Host "Service Principal Findings" `
            -ForegroundColor Cyan

        Write-Host "--------------------------"

        $Noteworthy |
            Sort-Object `
                @{Expression = { if ($_.HasDirectoryRole) { 0 } else { 1 } }},
                DisplayName |
            Format-Table `
                DisplayName,
                AccountEnabled,
                OwnerCount,
                ExpiredCredentials,
                ExpiringCredentials,
                HasDirectoryRole `
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

        $Finding = "No tenant-owned application service principals were detected."

        $Recommendation = "Confirm application inventory visibility and verify that Application.Read.All permission is available."

        Write-Host "WARNING  No tenant-owned service principals were detected." `
            -ForegroundColor Yellow
    }
    elseif ($PrivilegedOwnerless.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$($PrivilegedOwnerless.Count) enabled service principal(s) with Entra directory role assignments have no detected owners."

        $Recommendation = "Immediately review privileged service principals, assign accountable owners where appropriate, validate continued business need, and remove unnecessary directory role assignments."

        Write-Host "FAIL  Privileged service principals without owners were detected." `
            -ForegroundColor Red
    }
    elseif ($ExpiredCredentialServicePrincipals.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "$($ExpiredCredentialServicePrincipals.Count) enabled tenant-owned service principal(s) contain expired password or certificate credentials."

        $Recommendation = "Review expired credentials, remove stale credentials, and validate that active application authentication paths are documented and monitored."

        Write-Host "WARNING  Expired service principal credentials were detected." `
            -ForegroundColor Yellow
    }
    elseif ($ExpiringCredentialServicePrincipals.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($ExpiringCredentialServicePrincipals.Count) enabled tenant-owned service principal(s) have credentials expiring within 30 days."

        $Recommendation = "Rotate or renew expiring credentials before expiration and verify application owners are aware of the upcoming credential lifecycle event."

        Write-Host "WARNING  Service principal credentials are approaching expiration." `
            -ForegroundColor Yellow
    }
    elseif ($OwnerlessServicePrincipals.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($OwnerlessServicePrincipals.Count) enabled tenant-owned service principal(s) have no detected owners."

        $Recommendation = "Review ownerless service principals, confirm business ownership, and remove unused application identities."

        Write-Host "WARNING  Ownerless service principals require review." `
            -ForegroundColor Yellow
    }
    elseif ($PrivilegedServicePrincipals.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($PrivilegedServicePrincipals.Count) service principal(s) currently hold Entra directory role assignments."

        $Recommendation = "Review privileged service principals for least privilege, accountable ownership, credential hygiene, and continued business need."

        Write-Host "WARNING  Privileged service principals require review." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($Assessment.Count) tenant-owned service principal(s) were reviewed with no ownerless enabled identities, expiring credentials, expired credentials, or directory role assignments requiring immediate review."

        $Recommendation = "Continue periodic service principal ownership, credential lifecycle, and privilege reviews."

        Write-Host "PASS  Service principal posture appears healthy." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Service Principals" `
        -Category "Applications" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Service Principals health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Service Principals health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Service Principals assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Service Principals" `
        -Category "Applications" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Applications and Microsoft.Graph.Identity.Governance are available and ensure Application.Read.All and RoleManagement.Read.Directory are consented." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}