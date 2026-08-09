$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Custom Directory Roles health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "RoleManagement.Read.Directory"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with directory role read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope -NoWelcome
    }

    function Get-TenantIQGraphCollection {
        param([Parameter(Mandatory)][string]$Uri)

        $Items = @()
        $NextUri = $Uri

        while ($NextUri) {
            $Response = Invoke-MgGraphRequest -Method GET -Uri $NextUri -ErrorAction Stop

            if ($Response -is [System.Collections.IDictionary]) {
                if ($Response.Contains("value")) {
                    $Items += @($Response["value"])
                }

                $NextUri = if ($Response.Contains("@odata.nextLink")) {
                    [string]$Response["@odata.nextLink"]
                }
                else {
                    $null
                }
            }
            else {
                $Items += @($Response.value)
                $NextUri = [string]$Response.'@odata.nextLink'
            }
        }

        return @($Items)
    }

    Write-Host ""
    Write-Host "Retrieving Entra custom directory role definitions..." -ForegroundColor Cyan

    $RoleDefinitions = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?`$select=id,displayName,description,isBuiltIn,isEnabled,templateId,version,rolePermissions"
    )

    $RoleAssignments = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$select=id,principalId,roleDefinitionId,directoryScopeId"
    )

    $CustomRoles = @(
        $RoleDefinitions | Where-Object { $_.isBuiltIn -eq $false }
    )

    $Inventory = @(
        foreach ($Role in $CustomRoles) {
            $Assignments = @(
                $RoleAssignments | Where-Object {
                    [string]$_.roleDefinitionId -eq [string]$Role.id
                }
            )

            $AllowedActions = @()
            foreach ($PermissionBlock in @($Role.rolePermissions)) {
                $AllowedActions += @($PermissionBlock.allowedResourceActions)
            }

            $AllowedActions = @(
                $AllowedActions |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
                Sort-Object -Unique
            )

            $BroadPermissionPatterns = @(
                "microsoft.directory/*",
                "microsoft.directory/*/allProperties/*",
                "microsoft.directory/roleAssignments/*",
                "microsoft.directory/roleDefinitions/*"
            )

            $BroadPermissionHits = @(
                $AllowedActions | Where-Object {
                    $Action = [string]$_

                    foreach ($Pattern in $BroadPermissionPatterns) {
                        if ($Action -like $Pattern) {
                            return $true
                        }
                    }

                    return $false
                }
            )

            [PSCustomObject]@{
                DisplayName         = [string]$Role.displayName
                Enabled             = [bool]$Role.isEnabled
                AssignmentCount     = $Assignments.Count
                PermissionCount     = $AllowedActions.Count
                BroadPermissionHits = $BroadPermissionHits.Count
                Version             = [string]$Role.version
                Description         = [string]$Role.description
            }
        }
    )

    $EnabledCustomRoles = @(
        $Inventory | Where-Object { $_.Enabled -eq $true }
    )

    $DisabledCustomRoles = @(
        $Inventory | Where-Object { $_.Enabled -eq $false }
    )

    $AssignedCustomRoles = @(
        $Inventory | Where-Object { $_.AssignmentCount -gt 0 }
    )

    $UnassignedCustomRoles = @(
        $Inventory | Where-Object { $_.AssignmentCount -eq 0 }
    )

    $BroadCustomRoles = @(
        $Inventory | Where-Object { $_.BroadPermissionHits -gt 0 }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Custom Directory Roles" -ForegroundColor Cyan
    Write-Host "----------------------"
    Write-Host ""
    Write-Host "Role Definitions Reviewed : $($RoleDefinitions.Count)"
    Write-Host "Custom Roles              : $($Inventory.Count)"
    Write-Host "Enabled Custom Roles      : $($EnabledCustomRoles.Count)"
    Write-Host "Disabled Custom Roles     : $($DisabledCustomRoles.Count)"
    Write-Host "Assigned Custom Roles     : $($AssignedCustomRoles.Count)"
    Write-Host "Unassigned Custom Roles   : $($UnassignedCustomRoles.Count)"
    Write-Host "Broad-Permission Roles    : $($BroadCustomRoles.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Custom Directory Role Inventory" -ForegroundColor Cyan
        Write-Host "-------------------------------"

        $Inventory |
            Sort-Object DisplayName |
            Format-Table `
                DisplayName,
                Enabled,
                AssignmentCount,
                PermissionCount,
                BroadPermissionHits,
                Version `
                -AutoSize
    }

    $Stopwatch.Stop()

    if ($Inventory.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No custom Microsoft Entra directory roles are configured."
        $Recommendation = "No action is required. Continue using built-in roles where they meet requirements, and create custom roles only when a narrower permission model is necessary."

        Write-Host ""
        Write-Host "PASS  No custom directory roles are configured." -ForegroundColor Green
    }
    elseif ($BroadCustomRoles.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "High"
        $Finding = "$($BroadCustomRoles.Count) custom directory role(s) contain broad directory or role-management permission patterns."
        $Recommendation = "Review broad custom role permissions and reduce them to the minimum resource actions required. Verify assignments and scope for each affected custom role."

        Write-Host ""
        Write-Host "WARNING  Broad custom directory role permissions require review." -ForegroundColor Yellow
    }
    elseif ($UnassignedCustomRoles.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($UnassignedCustomRoles.Count) custom directory role(s) currently have no active role assignments."
        $Recommendation = "Review unassigned custom roles and remove obsolete definitions if they are no longer required."

        Write-Host ""
        Write-Host "WARNING  Unassigned custom directory roles require review." -ForegroundColor Yellow
    }
    elseif ($DisabledCustomRoles.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($DisabledCustomRoles.Count) custom directory role(s) are disabled."
        $Recommendation = "Review disabled custom roles and remove stale role definitions when they are no longer required."

        Write-Host ""
        Write-Host "WARNING  Disabled custom directory roles require review." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) custom directory role(s) were reviewed with active assignments and no broad permission patterns detected by this check."
        $Recommendation = "Continue periodically reviewing custom role permissions, assignments, and scope to preserve least privilege."

        Write-Host ""
        Write-Host "PASS  Custom directory role configuration appears healthy." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Custom Directory Roles" `
        -Category "Privileged Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Custom Directory Roles health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Custom Directory Roles health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Custom Directory Roles assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Custom Directory Roles" `
        -Category "Privileged Access" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify RoleManagement.Read.Directory consent, Microsoft Graph connectivity, and a supported Entra role such as Directory Readers, Global Reader, or Privileged Role Administrator." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
