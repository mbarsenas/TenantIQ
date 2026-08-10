$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Enterprise Application Permissions health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph cmdlets
    # ============================================================

    $RequiredCommands = @(
        "Get-MgServicePrincipal"
        "Get-MgServicePrincipalAppRoleAssignment"
        "Get-MgOauth2PermissionGrant"
    )

    foreach ($Command in $RequiredCommands) {

        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {

            throw "Required Microsoft Graph cmdlet '$Command' is not available. Install or repair the Microsoft Graph PowerShell SDK."
        }
    }


    # ============================================================
    # Verify Graph connection and permissions
    # ============================================================

    $RequiredScope = "Directory.Read.All"

    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext -or $GraphContext.Scopes -notcontains $RequiredScope) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with directory read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes $RequiredScope

        $GraphContext = Get-MgContext -ErrorAction Stop
    }

    $TenantId = [string]$GraphContext.TenantId


    # ============================================================
    # Retrieve enterprise applications / service principals
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving enterprise application permission grants..." `
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
                AppRoles,
                Oauth2PermissionScopes `
            -ErrorAction Stop
    )

    $ServicePrincipalMap = @{}

    foreach ($SP in $ServicePrincipals) {
        $ServicePrincipalMap[$SP.Id] = $SP
    }

    $EnterpriseApplications = @(
        $ServicePrincipals |
        Where-Object {
            $_.ServicePrincipalType -eq "Application"
        }
    )


    # ============================================================
    # High-impact permission catalog
    # ============================================================

    $CriticalApplicationPermissions = @(
        "RoleManagement.ReadWrite.Directory"
        "Directory.ReadWrite.All"
        "Application.ReadWrite.All"
        "AppRoleAssignment.ReadWrite.All"
        "DelegatedPermissionGrant.ReadWrite.All"
        "User.ReadWrite.All"
        "Group.ReadWrite.All"
        "GroupMember.ReadWrite.All"
        "Policy.ReadWrite.ConditionalAccess"
        "DeviceManagementConfiguration.ReadWrite.All"
        "DeviceManagementManagedDevices.ReadWrite.All"
        "Mail.ReadWrite"
        "Mail.Send"
        "Files.ReadWrite.All"
        "Sites.FullControl.All"
        "Sites.ReadWrite.All"
        "SecurityEvents.ReadWrite.All"
        "AuditLog.ReadWrite.All"
    )

    $HighApplicationPermissions = @(
        "Directory.Read.All"
        "User.Read.All"
        "Group.Read.All"
        "GroupMember.Read.All"
        "Application.Read.All"
        "RoleManagement.Read.Directory"
        "Policy.Read.All"
        "Mail.Read"
        "Files.Read.All"
        "Sites.Read.All"
        "Calendars.ReadWrite"
        "Contacts.ReadWrite"
    )

    $CriticalDelegatedPermissions = @(
        "RoleManagement.ReadWrite.Directory"
        "Directory.ReadWrite.All"
        "Application.ReadWrite.All"
        "AppRoleAssignment.ReadWrite.All"
        "DelegatedPermissionGrant.ReadWrite.All"
        "User.ReadWrite.All"
        "Group.ReadWrite.All"
        "Policy.ReadWrite.ConditionalAccess"
        "Mail.ReadWrite"
        "Mail.Send"
        "Files.ReadWrite.All"
        "Sites.FullControl.All"
        "Sites.ReadWrite.All"
    )

    $HighDelegatedPermissions = @(
        "Directory.Read.All"
        "User.Read.All"
        "Group.Read.All"
        "Application.Read.All"
        "RoleManagement.Read.Directory"
        "Policy.Read.All"
        "Mail.Read"
        "Files.Read.All"
        "Sites.Read.All"
    )


    # ============================================================
    # Retrieve delegated grants once
    # ============================================================

    $DelegatedGrants = @(
        Get-MgOauth2PermissionGrant `
            -All `
            -ErrorAction Stop
    )


    # ============================================================
    # Analyze enterprise applications
    # ============================================================

    $PermissionFindings = @()

    foreach ($EnterpriseApp in $EnterpriseApplications) {

        $IsTenantOwned = (
            -not [string]::IsNullOrWhiteSpace([string]$EnterpriseApp.AppOwnerOrganizationId) -and
            [string]$EnterpriseApp.AppOwnerOrganizationId -eq $TenantId
        )

        # --------------------------------------------------------
        # Application permissions
        # --------------------------------------------------------

        $AppRoleAssignments = @()

        try {

            $AppRoleAssignments = @(
                Get-MgServicePrincipalAppRoleAssignment `
                    -ServicePrincipalId $EnterpriseApp.Id `
                    -All `
                    -ErrorAction Stop
            )
        }
        catch {

            Write-ExchangeAILog `
                -Message "Unable to retrieve application permissions for '$($EnterpriseApp.DisplayName)'. $($_.Exception.Message)" `
                -Level WARNING
        }

        foreach ($Assignment in $AppRoleAssignments) {

            $ResourceSP = $ServicePrincipalMap[$Assignment.ResourceId]
            $PermissionName = [string]$Assignment.AppRoleId

            if ($ResourceSP) {

                $MatchedRole = @(
                    $ResourceSP.AppRoles |
                    Where-Object {
                        $_.Id -eq $Assignment.AppRoleId
                    }
                ) | Select-Object -First 1

                if ($MatchedRole -and -not [string]::IsNullOrWhiteSpace([string]$MatchedRole.Value)) {
                    $PermissionName = [string]$MatchedRole.Value
                }
            }

            $RiskLevel = "Standard"

            if ($CriticalApplicationPermissions -contains $PermissionName) {
                $RiskLevel = "Critical"
            }
            elseif ($HighApplicationPermissions -contains $PermissionName) {
                $RiskLevel = "High"
            }

            $PermissionFindings += [PSCustomObject]@{
                Application        = $EnterpriseApp.DisplayName
                ApplicationId      = $EnterpriseApp.AppId
                AccountEnabled     = $EnterpriseApp.AccountEnabled
                TenantOwned        = $IsTenantOwned
                Publisher          = $EnterpriseApp.PublisherName
                PermissionType     = "Application"
                Resource           = $Assignment.ResourceDisplayName
                Permission         = $PermissionName
                ConsentType        = "Application"
                RiskLevel          = $RiskLevel
            }
        }


        # --------------------------------------------------------
        # Delegated permissions
        # --------------------------------------------------------

        $AppDelegatedGrants = @(
            $DelegatedGrants |
            Where-Object {
                $_.ClientId -eq $EnterpriseApp.Id
            }
        )

        foreach ($Grant in $AppDelegatedGrants) {

            $ResourceSP = $ServicePrincipalMap[$Grant.ResourceId]

            if ($ResourceSP) {
                $ResourceName = $ResourceSP.DisplayName
            }
            else {
                $ResourceName = [string]$Grant.ResourceId
            }

            $Scopes = @(
                ([string]$Grant.Scope -split "\s+") |
                Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_)
                }
            )

            foreach ($Scope in $Scopes) {

                $RiskLevel = "Standard"

                if ($CriticalDelegatedPermissions -contains $Scope) {
                    $RiskLevel = "Critical"
                }
                elseif ($HighDelegatedPermissions -contains $Scope) {
                    $RiskLevel = "High"
                }

                $ConsentType = [string]$Grant.ConsentType

                if ($ConsentType -eq "AllPrincipals") {
                    $ConsentLabel = "Admin Consent"
                }
                else {
                    $ConsentLabel = "User Consent"
                }

                $PermissionFindings += [PSCustomObject]@{
                    Application        = $EnterpriseApp.DisplayName
                    ApplicationId      = $EnterpriseApp.AppId
                    AccountEnabled     = $EnterpriseApp.AccountEnabled
                    TenantOwned        = $IsTenantOwned
                    Publisher          = $EnterpriseApp.PublisherName
                    PermissionType     = "Delegated"
                    Resource           = $ResourceName
                    Permission         = $Scope
                    ConsentType        = $ConsentLabel
                    RiskLevel          = $RiskLevel
                }
            }
        }
    }


    # ============================================================
    # Calculate findings
    # ============================================================

    $ApplicationsWithPermissions = @(
        $PermissionFindings |
        Select-Object ApplicationId -Unique
    )

    $ApplicationPermissions = @(
        $PermissionFindings |
        Where-Object {
            $_.PermissionType -eq "Application"
        }
    )

    $DelegatedPermissions = @(
        $PermissionFindings |
        Where-Object {
            $_.PermissionType -eq "Delegated"
        }
    )

    $AdminConsentedDelegated = @(
        $DelegatedPermissions |
        Where-Object {
            $_.ConsentType -eq "Admin Consent"
        }
    )

    $CriticalPermissions = @(
        $PermissionFindings |
        Where-Object {
            $_.RiskLevel -eq "Critical"
        }
    )

    $HighPermissions = @(
        $PermissionFindings |
        Where-Object {
            $_.RiskLevel -eq "High"
        }
    )

    $CriticalThirdParty = @(
        $CriticalPermissions |
        Where-Object {
            $_.TenantOwned -eq $false
        }
    )

    $HighThirdParty = @(
        $HighPermissions |
        Where-Object {
            $_.TenantOwned -eq $false
        }
    )

    $DisabledAppsWithPermissions = @(
        $PermissionFindings |
        Where-Object {
            $_.AccountEnabled -eq $false
        } |
        Select-Object ApplicationId -Unique
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

    Write-Host "Enterprise Application Permissions" `
        -ForegroundColor Cyan

    Write-Host "----------------------------------"
    Write-Host ""

    Write-Host "Enterprise Applications Reviewed : $($EnterpriseApplications.Count)"
    Write-Host "Apps With Permission Grants      : $($ApplicationsWithPermissions.Count)"
    Write-Host "Application Permissions          : $($ApplicationPermissions.Count)"
    Write-Host "Delegated Permissions            : $($DelegatedPermissions.Count)"
    Write-Host "Admin-Consented Delegated        : $($AdminConsentedDelegated.Count)"

    Write-Host "Critical Permission Grants       : " -NoNewline
    if ($CriticalPermissions.Count -gt 0) {
        Write-Host $CriticalPermissions.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "High Permission Grants           : " -NoNewline
    if ($HighPermissions.Count -gt 0) {
        Write-Host $HighPermissions.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Critical Third-Party Grants      : " -NoNewline
    if ($CriticalThirdParty.Count -gt 0) {
        Write-Host $CriticalThirdParty.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "High Third-Party Grants          : " -NoNewline
    if ($HighThirdParty.Count -gt 0) {
        Write-Host $HighThirdParty.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Disabled Apps With Permissions   : " -NoNewline
    if ($DisabledAppsWithPermissions.Count -gt 0) {
        Write-Host $DisabledAppsWithPermissions.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host ""


    # ============================================================
    # Display high-impact permissions
    # ============================================================

    $HighImpactPermissions = @(
        $PermissionFindings |
        Where-Object {
            $_.RiskLevel -in @(
                "Critical"
                "High"
            )
        }
    )

    if ($HighImpactPermissions.Count -gt 0) {

        Write-Host "High-Impact Permission Inventory" `
            -ForegroundColor Cyan

        Write-Host "--------------------------------"

        $HighImpactPermissions |
            Sort-Object `
                @{Expression = {
                    if ($_.RiskLevel -eq "Critical") { 0 } else { 1 }
                }},
                Application,
                Permission |
            Format-Table `
                Application,
                TenantOwned,
                PermissionType,
                Resource,
                Permission,
                ConsentType,
                RiskLevel `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($CriticalThirdParty.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$($CriticalThirdParty.Count) critical high-impact permission grant(s) were detected on non-tenant-owned enterprise applications."

        $Recommendation = "Immediately review critical third-party application permissions and admin consent. Remove grants that are unnecessary and validate application ownership, publisher trust, and business justification."

        Write-Host "FAIL  Critical third-party application permissions were detected." `
            -ForegroundColor Red
    }
    elseif ($CriticalPermissions.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "$($CriticalPermissions.Count) critical high-impact enterprise application permission grant(s) were detected."

        $Recommendation = "Review critical application permissions for least privilege, ownership, business justification, and continued need."

        Write-Host "WARNING  Critical application permissions require review." `
            -ForegroundColor Yellow
    }
    elseif ($HighThirdParty.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "$($HighThirdParty.Count) high-impact permission grant(s) were detected on non-tenant-owned enterprise applications."

        $Recommendation = "Review high-impact third-party application permissions, admin consent, publisher trust, and continued business need."

        Write-Host "WARNING  High-impact third-party permissions require review." `
            -ForegroundColor Yellow
    }
    elseif ($HighPermissions.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($HighPermissions.Count) high-impact enterprise application permission grant(s) were detected."

        $Recommendation = "Review high-impact permission grants and confirm that each application follows least privilege."

        Write-Host "WARNING  High-impact application permissions require review." `
            -ForegroundColor Yellow
    }
    elseif ($DisabledAppsWithPermissions.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($DisabledAppsWithPermissions.Count) disabled enterprise application(s) still have recorded permission grants."

        $Recommendation = "Review disabled enterprise applications and remove stale permission grants when the applications are no longer required."

        Write-Host "WARNING  Disabled applications retain permission grants." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($ApplicationsWithPermissions.Count) enterprise application(s) with permission grants were reviewed, with no configured critical or high-impact permissions requiring immediate attention."

        $Recommendation = "Continue periodic enterprise application consent reviews and maintain least-privilege OAuth permission practices."

        Write-Host "PASS  Enterprise application permission posture appears healthy." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Enterprise Application Permissions" `
        -Category "Applications" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Enterprise Application Permissions health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Enterprise Application Permissions health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Enterprise Application Permissions assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Enterprise Application Permissions" `
        -Category "Applications" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Applications and Microsoft.Graph.Identity.SignIns are available and ensure Directory.Read.All is consented." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}