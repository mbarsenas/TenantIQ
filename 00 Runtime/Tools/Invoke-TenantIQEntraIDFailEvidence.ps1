param(
    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"
$Stage = "Startup"
$CurrentUri = $null

function Write-CollectorFailure {
    param(
        [string]$Stage,
        [string]$Message,
        [string]$Uri,
        [string]$ExceptionType
    )

    [ordered]@{
        Success       = $false
        Stage         = $Stage
        Uri           = $Uri
        Error         = $Message
        ExceptionType = $ExceptionType
        GeneratedAt   = (Get-Date).ToString("o")
    } |
        ConvertTo-Json -Depth 20 |
        Set-Content -Path $OutputPath -Encoding UTF8
}


function ConvertTo-TenantIQGraphObject {
    param($InputObject)

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $Ordered = [ordered]@{}

        foreach ($Key in $InputObject.Keys) {
            $Value = $InputObject[$Key]

            if ($Value -is [System.Collections.IDictionary]) {
                $Ordered[$Key] = ConvertTo-TenantIQGraphObject -InputObject $Value
            }
            elseif ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
                $Ordered[$Key] = @(
                    foreach ($Item in $Value) {
                        ConvertTo-TenantIQGraphObject -InputObject $Item
                    }
                )
            }
            else {
                $Ordered[$Key] = $Value
            }
        }

        return [PSCustomObject]$Ordered
    }

    return $InputObject
}

function ConvertTo-TenantIQGraphCollection {
    param([object[]]$Items)

    return @(
        foreach ($Item in @($Items)) {
            ConvertTo-TenantIQGraphObject -InputObject $Item
        }
    )
}

function Get-AllGraph {
    param(
        [Parameter(Mandatory)][string]$Uri
    )

    $All = @()

    do {
        $script:CurrentUri = $Uri

        $Response = Invoke-MgGraphRequest `
            -Method GET `
            -Uri $Uri `
            -ErrorAction Stop

        $HasValue = $false
        $Values = @()
        $NextLink = $null

        # Invoke-MgGraphRequest commonly returns a hashtable/dictionary in
        # Windows PowerShell. PSObject.Properties["value"] is not reliable
        # for that shape, so explicitly support both dictionary and object
        # responses.
        if ($Response -is [System.Collections.IDictionary]) {
            if ($Response.Contains("value")) {
                $HasValue = $true
                $Values = @($Response["value"])
            }
            if ($Response.Contains("@odata.nextLink")) {
                $NextLink = [string]$Response["@odata.nextLink"]
            }
        }
        else {
            $ValueProperty = $Response.PSObject.Properties["value"]
            if ($null -ne $ValueProperty) {
                $HasValue = $true
                $Values = @($ValueProperty.Value)
            }

            $NextProperty = $Response.PSObject.Properties["@odata.nextLink"]
            if ($null -ne $NextProperty) {
                $NextLink = [string]$NextProperty.Value
            }
        }

        if ($HasValue) {
            $All += $Values
            $Uri = $NextLink
        }
        else {
            $All += @($Response)
            $Uri = $null
        }
    }
    while (-not [string]::IsNullOrWhiteSpace($Uri))

    return $All
}

try {
    $Stage = "Import Microsoft.Graph.Authentication"
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

    $Stage = "Connect Microsoft Graph"
    Connect-MgGraph `
        -Scopes @(
            "Directory.Read.All",
            "Policy.Read.All",
            "AuditLog.Read.All",
            "User.Read.All",
            "Application.Read.All",
            "DelegatedPermissionGrant.Read.All",
            "RoleManagement.Read.Directory"
        ) `
        -ContextScope Process `
        -NoWelcome `
        -ErrorAction Stop

    $Stage = "Authorization Policy"
    $script:CurrentUri = "/v1.0/policies/authorizationPolicy"
    $AuthorizationPolicy = Invoke-MgGraphRequest `
        -Method GET `
        -Uri $script:CurrentUri `
        -ErrorAction Stop

    $Stage = "Users and sign-in activity"

    # Microsoft Graph caps user collection page size at 500 whenever
    # signInActivity is selected. Values above 500 can return BadRequest.
    $Users = @(
        ConvertTo-TenantIQGraphCollection -Items @(
            Get-AllGraph `
                -Uri "/v1.0/users?`$select=id,userPrincipalName,displayName,userType,accountEnabled,createdDateTime,signInActivity&`$top=500"
        )
    )

    $Stage = "Directory role assignments"

    # Retrieve role assignments first, then resolve the Global Administrator
    # definition and principals separately. This avoids depending on a complex
    # multi-relationship $expand during evidence collection.
    $RoleAssignments = @(
        ConvertTo-TenantIQGraphCollection -Items @(
            Get-AllGraph `
                -Uri "/v1.0/roleManagement/directory/roleAssignments?`$top=999"
        )
    )

    # The LIST roleDefinitions endpoint supports $filter and $expand,
    # but not the $select query used in v3.2. Query the one definition we
    # actually need by its well-known template ID.
    $script:CurrentUri = "/v1.0/roleManagement/directory/roleDefinitions?`$filter=templateId%20eq%20'62e90394-69f5-4237-9190-012177145e10'"

    $RoleDefinitionResponse = Invoke-MgGraphRequest `
        -Method GET `
        -Uri $script:CurrentUri `
        -ErrorAction Stop

    $RoleDefinitionValues = @()

    if ($RoleDefinitionResponse -is [System.Collections.IDictionary]) {
        if ($RoleDefinitionResponse.Contains("value")) {
            $RoleDefinitionValues = @($RoleDefinitionResponse["value"])
        }
    }
    elseif ($null -ne $RoleDefinitionResponse.PSObject.Properties["value"]) {
        $RoleDefinitionValues = @($RoleDefinitionResponse.PSObject.Properties["value"].Value)
    }

    $GlobalAdminDefinition = @(
        $RoleDefinitionValues |
        Select-Object -First 1
    )

    $GlobalAdminAssignments = @()

    if ($GlobalAdminDefinition) {
        $GAAssignments = @(
            $RoleAssignments |
            Where-Object {
                $_.roleDefinitionId -eq $GlobalAdminDefinition.id -or
                $_.roleDefinitionId -eq $GlobalAdminDefinition.templateId
            }
        )

        foreach ($Assignment in $GAAssignments) {
            $Principal = $null

            try {
                $Stage = "Resolve Global Administrator principal $($Assignment.principalId)"
                $script:CurrentUri = "/v1.0/directoryObjects/$($Assignment.principalId)"
                $Principal = Invoke-MgGraphRequest `
                    -Method GET `
                    -Uri $script:CurrentUri `
                    -ErrorAction Stop
            }
            catch {
                # Keep the role assignment evidence even if a deleted/stale
                # principal cannot be resolved.
            }

            $GlobalAdminAssignments += [PSCustomObject]@{
                PrincipalId  = $Assignment.principalId
                PrincipalType = if ($Principal.'@odata.type') { $Principal.'@odata.type' } else { "Unknown" }
                DisplayName  = $Principal.displayName
                UPN          = $Principal.userPrincipalName
            }
        }
    }

    $Stage = "Service principals"
    $ServicePrincipals = @(
        ConvertTo-TenantIQGraphCollection -Items @(
            Get-AllGraph `
                -Uri "/v1.0/servicePrincipals?`$select=id,appId,displayName,appOwnerOrganizationId,servicePrincipalType,verifiedPublisher&`$top=999"
        )
    )

    $Stage = "OAuth2 permission grants"
    $OAuth2PermissionGrants = @(
        ConvertTo-TenantIQGraphCollection -Items @(
            Get-AllGraph `
                -Uri "/v1.0/oauth2PermissionGrants?`$top=999"
        )
    )

    $Stage = "Enterprise application permission details"

    $ServicePrincipalById = @{}
    foreach ($SP in $ServicePrincipals) {
        if ($SP.id) {
            $ServicePrincipalById[[string]$SP.id] = $SP
        }
    }

    $DelegatedGrantDetails = @()

    foreach ($Grant in $OAuth2PermissionGrants) {
        $Client = $null
        $Resource = $null

        if ($Grant.clientId -and $ServicePrincipalById.ContainsKey([string]$Grant.clientId)) {
            $Client = $ServicePrincipalById[[string]$Grant.clientId]
        }

        if ($Grant.resourceId -and $ServicePrincipalById.ContainsKey([string]$Grant.resourceId)) {
            $Resource = $ServicePrincipalById[[string]$Grant.resourceId]
        }

        $Scopes = @(
            ([string]$Grant.scope -split '\s+' | Where-Object { $_ })
        )

        foreach ($Scope in $Scopes) {
            $DelegatedGrantDetails += [PSCustomObject]@{
                ClientServicePrincipalId = $Grant.clientId
                ClientDisplayName        = $Client.displayName
                ClientAppId              = $Client.appId
                ClientOwnerOrganizationId = $Client.appOwnerOrganizationId
                ClientPublisher          = $Client.verifiedPublisher.displayName
                ResourceServicePrincipalId = $Grant.resourceId
                ResourceDisplayName      = $Resource.displayName
                ResourceAppId            = $Resource.appId
                ConsentType              = $Grant.consentType
                PrincipalId              = $Grant.principalId
                PermissionType           = "Delegated"
                Permission                = $Scope
            }
        }
    }

    $ApplicationGrantDetails = @()

    # Microsoft Graph JSON batching allows up to 20 requests per batch.
    # Querying each of ~300 service principals sequentially makes the
    # evidence collector appear hung, so v5.1 batches appRoleAssignments.
    $BatchSize = 20
    $ClientSPs = @($ServicePrincipals | Where-Object { $_.id })
    $TotalClients = $ClientSPs.Count
    $BatchNumber = 0
    $TotalBatches = [math]::Ceiling($TotalClients / $BatchSize)

    Write-Host ""
    Write-Host "Collecting application permissions in Graph batches..." -ForegroundColor Cyan
    Write-Host "Service principals: $TotalClients | Batches: $TotalBatches" -ForegroundColor DarkGray
    Write-Host ""

    for ($Offset = 0; $Offset -lt $TotalClients; $Offset += $BatchSize) {
        $BatchNumber++
        $Upper = [math]::Min($Offset + $BatchSize - 1, $TotalClients - 1)
        $CurrentClients = @($ClientSPs[$Offset..$Upper])

        Write-Host ("Batch {0}/{1} - service principals {2}-{3}" -f `
            $BatchNumber, $TotalBatches, ($Offset + 1), ($Upper + 1)) -ForegroundColor DarkGray

        $Requests = @()
        $RequestMap = @{}

        $RequestId = 1

        foreach ($ClientSP in $CurrentClients) {
            $Id = [string]$RequestId

            $Requests += [ordered]@{
                id     = $Id
                method = "GET"
                url    = "/servicePrincipals/$($ClientSP.id)/appRoleAssignments?`$top=999"
            }

            $RequestMap[$Id] = $ClientSP
            $RequestId++
        }

        $BatchBody = @{
            requests = $Requests
        } | ConvertTo-Json -Depth 12

        $Stage = "Application role assignment batch $BatchNumber of $TotalBatches"
        $script:CurrentUri = "/v1.0/`$batch"

        try {
            $BatchResponse = Invoke-MgGraphRequest `
                -Method POST `
                -Uri $script:CurrentUri `
                -Body $BatchBody `
                -ContentType "application/json" `
                -ErrorAction Stop

            $Responses = @()

            if ($BatchResponse -is [System.Collections.IDictionary]) {
                if ($BatchResponse.Contains("responses")) {
                    $Responses = @($BatchResponse["responses"])
                }
            }
            elseif ($null -ne $BatchResponse.PSObject.Properties["responses"]) {
                $Responses = @($BatchResponse.PSObject.Properties["responses"].Value)
            }

            $Responses = @(
                ConvertTo-TenantIQGraphCollection -Items $Responses
            )

            foreach ($ResponseItem in $Responses) {
                $ResponseId = [string]$ResponseItem.id
                $ClientSP = $RequestMap[$ResponseId]

                if ($null -eq $ClientSP) {
                    continue
                }

                # Some individual batch items can fail (deleted/inaccessible SPs).
                # Preserve the rest of the batch instead of aborting the collector.
                if ([int]$ResponseItem.status -lt 200 -or [int]$ResponseItem.status -ge 300) {
                    continue
                }

                $Body = ConvertTo-TenantIQGraphObject -InputObject $ResponseItem.body
                $Assignments = @()

                if ($Body -is [System.Collections.IDictionary]) {
                    if ($Body.Contains("value")) {
                        $Assignments = @($Body["value"])
                    }
                }
                elseif ($null -ne $Body.PSObject.Properties["value"]) {
                    $Assignments = @($Body.PSObject.Properties["value"].Value)
                }

                $Assignments = @(
                    ConvertTo-TenantIQGraphCollection -Items $Assignments
                )

                foreach ($Assignment in $Assignments) {
                    $Resource = $null

                    if ($Assignment.resourceId -and $ServicePrincipalById.ContainsKey([string]$Assignment.resourceId)) {
                        $Resource = $ServicePrincipalById[[string]$Assignment.resourceId]
                    }

                    $PermissionValue = [string]$Assignment.appRoleId

                    if ($Resource -and $Resource.appRoles) {
                        $RoleMatch = @(
                            $Resource.appRoles |
                            Where-Object { [string]$_.id -eq [string]$Assignment.appRoleId } |
                            Select-Object -First 1
                        )

                        if ($RoleMatch) {
                            $PermissionValue = [string]$RoleMatch.value
                        }
                    }

                    $ApplicationGrantDetails += [PSCustomObject]@{
                        ClientServicePrincipalId   = $ClientSP.id
                        ClientDisplayName          = $ClientSP.displayName
                        ClientAppId                = $ClientSP.appId
                        ClientOwnerOrganizationId  = $ClientSP.appOwnerOrganizationId
                        ClientPublisher            = $ClientSP.verifiedPublisher.displayName
                        ResourceServicePrincipalId = $Assignment.resourceId
                        ResourceDisplayName        = $Resource.displayName
                        ResourceAppId              = $Resource.appId
                        ConsentType                = "Application"
                        PrincipalId                = $Assignment.principalId
                        PermissionType             = "Application"
                        Permission                 = $PermissionValue
                    }
                }
            }
        }
        catch {
            # Keep staged diagnostics but do not fail the entire collector because
            # one application-permission batch failed. Delegated permission evidence
            # and other batches remain valuable.
            Write-Host ("[WARNING] Graph batch {0} failed: {1}" -f $BatchNumber, $_.Exception.Message) `
                -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host ("[OK] Application permission batching complete. {0} assignment(s) collected." -f `
        $ApplicationGrantDetails.Count) -ForegroundColor Green
    Write-Host ""

    $Stage = "Build evidence"

    $MemberUsers = @(
        $Users |
        Where-Object {
            $_.userType -eq "Member"
        }
    )

    $Stale180 = @(
        $MemberUsers |
        Where-Object {
            if ($_.accountEnabled -ne $true) {
                return $false
            }

            $LastSuccessful = $_.signInActivity.lastSuccessfulSignInDateTime

            if (-not $LastSuccessful) {
                return $true
            }

            try {
                return (
                    ((Get-Date).ToUniversalTime() - ([datetime]$LastSuccessful).ToUniversalTime()).TotalDays -ge 180
                )
            }
            catch {
                return $true
            }
        }
    )

    $Evidence = [ordered]@{
        Success     = $true
        Stage       = "Complete"
        GeneratedAt = (Get-Date).ToString("o")
        TenantId    = (Get-MgContext).TenantId

        AuthorizationPolicy = [ordered]@{
            allowedToSignUpEmailBasedSubscriptions = $AuthorizationPolicy.allowedToSignUpEmailBasedSubscriptions
            allowedToUseSSPR                       = $AuthorizationPolicy.allowedToUseSSPR
            allowInvitesFrom                       = $AuthorizationPolicy.allowInvitesFrom
            defaultUserRolePermissions             = $AuthorizationPolicy.defaultUserRolePermissions
            guestUserRoleId                        = $AuthorizationPolicy.guestUserRoleId
        }

        GlobalAdministrators = [ordered]@{
            Count       = $GlobalAdminAssignments.Count
            Assignments = $GlobalAdminAssignments
        }

        StaleUsers180Days = [ordered]@{
            Count = $Stale180.Count
            Users = @(
                foreach ($User in $Stale180) {
                    [PSCustomObject]@{
                        Id                   = $User.id
                        DisplayName          = $User.displayName
                        UserPrincipalName    = $User.userPrincipalName
                        AccountEnabled       = $User.accountEnabled
                        CreatedDateTime      = $User.createdDateTime
                        LastSuccessfulSignIn = $User.signInActivity.lastSuccessfulSignInDateTime
                    }
                }
            )
        }

        EnterpriseApps = [ordered]@{
            ServicePrincipalCount       = $ServicePrincipals.Count
            OAuth2PermissionGrantCount  = $OAuth2PermissionGrants.Count
            DelegatedPermissionCount    = $DelegatedGrantDetails.Count
            ApplicationPermissionCount  = $ApplicationGrantDetails.Count
            DelegatedPermissions        = $DelegatedGrantDetails
            ApplicationPermissions      = $ApplicationGrantDetails
        }

        MemberUserCount = $MemberUsers.Count
    }

    $Evidence |
        ConvertTo-Json -Depth 30 |
        Set-Content -Path $OutputPath -Encoding UTF8

    exit 0
}
catch {
    Write-CollectorFailure `
        -Stage $Stage `
        -Message $_.Exception.Message `
        -Uri $script:CurrentUri `
        -ExceptionType $_.Exception.GetType().FullName

    exit 1
}
