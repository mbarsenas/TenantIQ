# Standalone compatibility helpers
if (-not (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue)) {
    function Write-ExchangeAILog {
        param(
            [Parameter(Mandatory)][string]$Message,
            [ValidateSet("INFO","WARNING","ERROR")][string]$Level = "INFO"
        )

        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$Timestamp] [$Level] $Message"
    }
}

if (-not (Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue)) {
    function New-HealthCheckResult {
        param(
            [Parameter(Mandatory)][string]$Check,
            [Parameter(Mandatory)][string]$Category,
            [Parameter(Mandatory)][string]$Status,
            [Parameter(Mandatory)][string]$Severity,
            [Parameter(Mandatory)][string]$Finding,
            [Parameter(Mandatory)][string]$Recommendation,
            [double]$Duration = 0
        )

        if (-not (Get-Variable ExchangeAIResults -Scope Global -ErrorAction SilentlyContinue)) {
            $Global:ExchangeAIResults = @()
        }

        $Result = [PSCustomObject]@{
            Check          = $Check
            Category       = $Category
            Status         = $Status
            Severity       = $Severity
            Finding        = $Finding
            Recommendation = $Recommendation
            Duration       = $Duration
        }

        $Global:ExchangeAIResults += $Result
        return $Result
    }
}

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Microsoft 365 Group Site Ownership health check." -Level INFO

try {
    # Load the Microsoft modules required by this cross-workload check.
    try {
        if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
        }
    }
    catch {
        throw "Unable to load Microsoft.Online.SharePoint.PowerShell. $($_.Exception.Message)"
    }

    try {
        if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue) -or
            -not (Get-Command Get-MgContext -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
        }

        if (-not (Get-Command Get-MgGroup -ErrorAction SilentlyContinue) -or
            -not (Get-Command Get-MgGroupOwner -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Graph.Groups -ErrorAction Stop
        }
    }
    catch {
        throw "Unable to load the Microsoft Graph Authentication/Groups modules. Install Microsoft.Graph or Microsoft.Graph.Groups and Microsoft.Graph.Authentication. $($_.Exception.Message)"
    }

    foreach ($Command in @("Get-SPOSite","Connect-MgGraph","Get-MgContext","Get-MgGroup","Get-MgGroupOwner")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "$Command is still unavailable after module import. Verify the required Microsoft 365 PowerShell modules are installed."
        }
    }

    Write-Host ""
    Write-Host "Retrieving Microsoft 365 Group-connected SharePoint sites..." -ForegroundColor Cyan

    try {
        $Sites = @(Get-SPOSite -Limit All -GroupIdDefined $true -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve Microsoft 365 Group-connected SharePoint sites. Verify the SharePoint Online connection with Connect-SPOService. $($_.Exception.Message)"
    }

    # Ensure Microsoft Graph is connected with a scope capable of reading group owners.
    $GraphContext = $null
    if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
        $GraphContext = Get-MgContext -ErrorAction SilentlyContinue
    }

    $RequiredScopes = @("GroupMember.Read.All")
    $HasRequiredScope = $false

    if ($GraphContext) {
        $CurrentScopes = @($GraphContext.Scopes)
        if ($CurrentScopes -contains "GroupMember.Read.All" -or
            $CurrentScopes -contains "Group.Read.All" -or
            $CurrentScopes -contains "Directory.Read.All" -or
            $CurrentScopes -contains "Group.ReadWrite.All" -or
            $CurrentScopes -contains "Directory.ReadWrite.All") {
            $HasRequiredScope = $true
        }
    }

    if (-not $GraphContext -or -not $HasRequiredScope) {
        Write-Host ""
        Write-Host "Microsoft Graph group-owner permissions are required." -ForegroundColor Yellow
        Write-Host "Launching Microsoft Graph sign-in..." -ForegroundColor Cyan
        Write-Host ""

        try {
            Connect-MgGraph -Scopes $RequiredScopes -NoWelcome -ErrorAction Stop
            $GraphContext = Get-MgContext -ErrorAction Stop
        }
        catch {
            throw "Unable to connect to Microsoft Graph with GroupMember.Read.All. $($_.Exception.Message)"
        }
    }

    function Get-TenantIQPropertyValue {
        param(
            [Parameter(Mandatory)]$Object,
            [Parameter(Mandatory)][string[]]$Names
        )

        foreach ($Name in $Names) {
            $Property = $Object.PSObject.Properties[$Name]
            if ($null -ne $Property) {
                return $Property.Value
            }
        }

        return $null
    }

    function Test-TenantIQGuid {
        param($Value)

        if ($null -eq $Value) {
            return $false
        }

        $Parsed = [guid]::Empty
        return [guid]::TryParse([string]$Value, [ref]$Parsed)
    }

    function Resolve-TenantIQOwner {
        param($Owner)

        $OwnerId = [string]$Owner.Id
        $OwnerType = [string](Get-TenantIQPropertyValue -Object $Owner -Names @("OdataType","@odata.type"))

        $DisplayName = $null
        $UserPrincipalName = $null
        $AppId = $null

        if ($Owner.AdditionalProperties) {
            if ($Owner.AdditionalProperties.ContainsKey("displayName")) {
                $DisplayName = [string]$Owner.AdditionalProperties["displayName"]
            }

            if ($Owner.AdditionalProperties.ContainsKey("userPrincipalName")) {
                $UserPrincipalName = [string]$Owner.AdditionalProperties["userPrincipalName"]
            }

            if ($Owner.AdditionalProperties.ContainsKey("appId")) {
                $AppId = [string]$Owner.AdditionalProperties["appId"]
            }

            if ($Owner.AdditionalProperties.ContainsKey("@odata.type")) {
                $OwnerType = [string]$Owner.AdditionalProperties["@odata.type"]
            }
        }

        if (-not $DisplayName) {
            $DisplayName = [string](Get-TenantIQPropertyValue -Object $Owner -Names @("DisplayName"))
        }

        if (-not $UserPrincipalName) {
            $UserPrincipalName = [string](Get-TenantIQPropertyValue -Object $Owner -Names @("UserPrincipalName"))
        }

        if (-not $AppId) {
            $AppId = [string](Get-TenantIQPropertyValue -Object $Owner -Names @("AppId"))
        }

        $IsUser = $false
        $IsServicePrincipal = $false

        if ($OwnerType -match "user") {
            $IsUser = $true
        }
        elseif ($OwnerType -match "servicePrincipal") {
            $IsServicePrincipal = $true
        }
        elseif (-not [string]::IsNullOrWhiteSpace($UserPrincipalName)) {
            $IsUser = $true
        }
        elseif (-not [string]::IsNullOrWhiteSpace($AppId)) {
            $IsServicePrincipal = $true
        }

        $Label = $null

        if ($IsUser) {
            if ($UserPrincipalName) {
                $Label = $UserPrincipalName
            }
            elseif ($DisplayName) {
                $Label = $DisplayName
            }
            else {
                $Label = $OwnerId
            }
        }
        elseif ($IsServicePrincipal) {
            if ($DisplayName) {
                $Label = "$DisplayName [ServicePrincipal]"
            }
            else {
                $Label = "$OwnerId [ServicePrincipal]"
            }
        }
        else {
            if ($DisplayName) {
                $Label = "$DisplayName [DirectoryObject]"
            }
            else {
                $Label = "$OwnerId [DirectoryObject]"
            }
        }

        return [PSCustomObject]@{
            Id                  = $OwnerId
            Type                = if ($IsUser) { "User" } elseif ($IsServicePrincipal) { "ServicePrincipal" } else { "DirectoryObject" }
            DisplayName         = $DisplayName
            UserPrincipalName   = $UserPrincipalName
            Label               = $Label
            IsHumanUser         = $IsUser
            IsServicePrincipal  = $IsServicePrincipal
        }
    }

    $Inventory = @()
    $UnresolvedSites = @()
    $ExcludedTeamsChannelSites = @()

    foreach ($Site in $Sites) {
        if ([string]$Site.Template -like "TEAMCHANNEL#*") {
            $ExcludedTeamsChannelSites += [PSCustomObject]@{
                Url      = [string]$Site.Url
                Template = [string]$Site.Template
                Reason   = "Teams channel site ownership is governed through the associated Team/channel and is excluded from Microsoft 365 Group site ownership scoring."
            }
            continue
        }
        $GroupId = Get-TenantIQPropertyValue -Object $Site -Names @("GroupId")

        if (-not (Test-TenantIQGuid $GroupId)) {
            try {
                $DetailedSite = Get-SPOSite -Identity $Site.Url -ErrorAction Stop
                $GroupId = Get-TenantIQPropertyValue -Object $DetailedSite -Names @("GroupId")
            }
            catch {}
        }

        if (-not (Test-TenantIQGuid $GroupId)) {
            $UnresolvedSites += [PSCustomObject]@{
                Url      = [string]$Site.Url
                Template = [string]$Site.Template
                GroupId  = [string]$GroupId
                Reason   = "A valid Microsoft 365 Group ID was not returned for the site."
            }
            continue
        }

        try {
            $Group = Get-MgGroup `
                -GroupId ([string]$GroupId) `
                -Property Id,DisplayName,Mail,MailEnabled,SecurityEnabled,GroupTypes,Visibility `
                -ErrorAction Stop
        }
        catch {
            $UnresolvedSites += [PSCustomObject]@{
                Url      = [string]$Site.Url
                Template = [string]$Site.Template
                GroupId  = [string]$GroupId
                Reason   = "Associated Microsoft 365 Group could not be retrieved. $($_.Exception.Message)"
            }
            continue
        }

        try {
            $RawOwners = @(Get-MgGroupOwner -GroupId ([string]$GroupId) -All -ErrorAction Stop)
        }
        catch {
            $UnresolvedSites += [PSCustomObject]@{
                Url      = [string]$Site.Url
                Template = [string]$Site.Template
                GroupId  = [string]$GroupId
                Reason   = "Group owners could not be retrieved. $($_.Exception.Message)"
            }
            continue
        }

        $Owners = @(
            $RawOwners | ForEach-Object {
                Resolve-TenantIQOwner $_
            }
        )

        $HumanOwners = @(
            $Owners | Where-Object {
                $_.IsHumanUser -eq $true
            }
        )

        $ServicePrincipalOwners = @(
            $Owners | Where-Object {
                $_.IsServicePrincipal -eq $true
            }
        )

        $OtherOwners = @(
            $Owners | Where-Object {
                $_.IsHumanUser -ne $true -and
                $_.IsServicePrincipal -ne $true
            }
        )

        $Inventory += [PSCustomObject]@{
            SiteUrl               = [string]$Site.Url
            GroupId               = [string]$Group.Id
            GroupDisplayName      = [string]$Group.DisplayName
            GroupMail             = [string]$Group.Mail
            Visibility            = [string]$Group.Visibility
            TotalOwnerCount       = $Owners.Count
            HumanOwnerCount       = $HumanOwners.Count
            ServicePrincipalCount = $ServicePrincipalOwners.Count
            OtherOwnerCount       = $OtherOwners.Count
            HumanOwners           = if ($HumanOwners.Count -gt 0) {
                (@($HumanOwners | ForEach-Object { $_.Label }) -join ", ")
            }
            else {
                "None detected"
            }
            NonHumanOwners        = if (($ServicePrincipalOwners.Count + $OtherOwners.Count) -gt 0) {
                (@(
                    $Owners |
                    Where-Object { $_.IsHumanUser -ne $true } |
                    ForEach-Object { $_.Label }
                ) -join ", ")
            }
            else {
                "None"
            }
        }
    }

    $OwnerlessGroups = @(
        $Inventory | Where-Object {
            $_.TotalOwnerCount -eq 0
        }
    )

    $NoHumanOwnerGroups = @(
        $Inventory | Where-Object {
            $_.TotalOwnerCount -gt 0 -and
            $_.HumanOwnerCount -eq 0
        }
    )

    $SingleHumanOwnerGroups = @(
        $Inventory | Where-Object {
            $_.HumanOwnerCount -eq 1
        }
    )

    $HealthyGroups = @(
        $Inventory | Where-Object {
            $_.HumanOwnerCount -ge 2
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Microsoft 365 Group Site Ownership" -ForegroundColor Cyan
    Write-Host "---------------------------------"
    Write-Host ""
    Write-Host "Group-Connected Sites Discovered   : $($Sites.Count)"
    Write-Host "Group Sites Successfully Reviewed  : $($Inventory.Count)"
    Write-Host "Teams Channel Sites Excluded       : $($ExcludedTeamsChannelSites.Count)"
    Write-Host "Sites/Groups Not Resolved          : $($UnresolvedSites.Count)"
    Write-Host "Groups With Zero Owners            : $($OwnerlessGroups.Count)"
    Write-Host "Groups With No Human Owners        : $($NoHumanOwnerGroups.Count)"
    Write-Host "Groups With One Human Owner        : $($SingleHumanOwnerGroups.Count)"
    Write-Host "Groups With 2+ Human Owners        : $($HealthyGroups.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Group Site Ownership Inventory" -ForegroundColor Cyan
        Write-Host "------------------------------"

        $Inventory |
            Sort-Object HumanOwnerCount, GroupDisplayName |
            Select-Object `
                SiteUrl,
                GroupDisplayName,
                GroupId,
                Visibility,
                TotalOwnerCount,
                HumanOwnerCount,
                HumanOwners |
            Format-Table -AutoSize -Wrap
    }

    $NonHumanOnly = @(
        $Inventory | Where-Object {
            $_.TotalOwnerCount -gt 0 -and
            $_.HumanOwnerCount -eq 0
        }
    )

    if ($NonHumanOnly.Count -gt 0) {
        Write-Host ""
        Write-Host "Groups With Non-Human Ownership Only" -ForegroundColor Cyan
        Write-Host "------------------------------------"

        $NonHumanOnly |
            Select-Object `
                GroupDisplayName,
                GroupId,
                TotalOwnerCount,
                NonHumanOwners |
            Format-Table -AutoSize -Wrap
    }

    if ($ExcludedTeamsChannelSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Teams Channel Sites Excluded" -ForegroundColor Cyan
        Write-Host "----------------------------"

        $ExcludedTeamsChannelSites |
            Sort-Object Url |
            Select-Object Url,Template,Reason |
            Format-Table -AutoSize -Wrap
    }

    if ($UnresolvedSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Sites / Groups Not Resolved" -ForegroundColor Cyan
        Write-Host "---------------------------"

        $UnresolvedSites |
            Sort-Object Url |
            Select-Object `
                Url,
                Template,
                GroupId,
                Reason |
            Format-Table -AutoSize -Wrap
    }

    $Issues = @()

    if ($OwnerlessGroups.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "$($OwnerlessGroups.Count) Microsoft 365 Group-connected SharePoint site(s) are associated with groups that have zero owners."
        }
    }

    if ($NoHumanOwnerGroups.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "$($NoHumanOwnerGroups.Count) Microsoft 365 Group-connected SharePoint site(s) have group ownership entries but no human user owners."
        }
    }

    if ($SingleHumanOwnerGroups.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "$($SingleHumanOwnerGroups.Count) Microsoft 365 Group-connected SharePoint site(s) have only one detected human group owner."
        }
    }

    $Stopwatch.Stop()

    if ($Inventory.Count -eq 0 -and $Sites.Count -gt 0) {
        $Status = "INFO"
        $Severity = "None"
        $Finding = "TenantIQ discovered $($Sites.Count) Microsoft 365 Group-connected SharePoint site(s), but none could be fully resolved and assessed through Microsoft Graph."
        $Recommendation = "Verify the Microsoft Graph connection and group-read permissions, then rerun the assessment."

        Write-Host ""
        Write-Host "INFO  Microsoft 365 Group site ownership could not be fully assessed." -ForegroundColor Yellow
    }
    elseif ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) Microsoft 365 Group-connected SharePoint site(s) were reviewed and each resolved group has at least two detected human owners. $($ExcludedTeamsChannelSites.Count) Teams channel site(s) were intentionally excluded from Microsoft 365 Group ownership scoring."
        $Recommendation = "Continue maintaining at least two accountable owners for business-relevant Microsoft 365 Groups and periodically review group ownership as personnel and responsibilities change."

        Write-Host ""
        Write-Host "PASS  Microsoft 365 Group site ownership appears healthy." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"

        if (@($Issues | Where-Object Severity -eq "High").Count -gt 0) {
            $Severity = "High"
        }
        else {
            $Severity = "Low"
        }

        $Finding = (@($Issues | ForEach-Object { $_.Finding }) -join " ")
        $Finding += " $($ExcludedTeamsChannelSites.Count) Teams channel site(s) were intentionally excluded from Microsoft 365 Group ownership scoring."

        if ($UnresolvedSites.Count -gt 0) {
            $Finding += " $($UnresolvedSites.Count) site/group association(s) could not be fully resolved and were excluded from scoring."
        }

        $Recommendation = "Review Microsoft 365 Group ownership for SharePoint-connected sites. Assign accountable human owners to ownerless or non-human-only groups and avoid unnecessary single-owner dependencies for active business collaboration sites."

        Write-Host ""
        Write-Host "Microsoft 365 Group Ownership Findings" -ForegroundColor Cyan
        Write-Host "-------------------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        if ($ExcludedTeamsChannelSites.Count -gt 0) {
            Write-Host ""
            Write-Host "INFO  $($ExcludedTeamsChannelSites.Count) Teams channel site(s) were excluded from Microsoft 365 Group ownership scoring." -ForegroundColor DarkYellow
        }

        if ($UnresolvedSites.Count -gt 0) {
            Write-Host ""
            Write-Host "INFO  $($UnresolvedSites.Count) site/group association(s) could not be resolved and were excluded from scoring." -ForegroundColor DarkYellow
        }

        Write-Host ""
        Write-Host "WARNING  Microsoft 365 Group site ownership requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Microsoft 365 Group Site Ownership" `
        -Category "Sites" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Microsoft 365 Group Site Ownership health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Microsoft 365 Group Site Ownership health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Microsoft 365 Group Site Ownership assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Microsoft 365 Group Site Ownership" `
        -Category "Sites" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify SharePoint Online and Microsoft Graph connections, ensure GroupMember.Read.All or equivalent group-read permission is granted, and rerun the assessment." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
