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

Write-ExchangeAILog -Message "Starting SharePoint Online Microsoft 365 Group Guest Membership health check." -Level INFO

try {
    # Load required Microsoft modules.
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
            -not (Get-Command Get-MgGroupMemberAsUser -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Graph.Groups -ErrorAction Stop
        }
    }
    catch {
        throw "Unable to load Microsoft Graph Authentication/Groups modules. $($_.Exception.Message)"
    }

    foreach ($Command in @(
        "Get-SPOSite",
        "Connect-MgGraph",
        "Get-MgContext",
        "Get-MgGroup",
        "Get-MgGroupMemberAsUser"
    )) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "$Command is unavailable after module import."
        }
    }

    Write-Host ""
    Write-Host "Retrieving Microsoft 365 Group guest membership for SharePoint sites..." -ForegroundColor Cyan

    # Verify SharePoint Online is connected.
    try {
        $Sites = @(Get-SPOSite -Limit All -GroupIdDefined $true -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve Microsoft 365 Group-connected SharePoint sites. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
    }

    # Ensure Graph has enough permission to read group membership.
    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue
    $AcceptedScopes = @(
        "GroupMember.Read.All",
        "Group.Read.All",
        "Group.ReadWrite.All",
        "Directory.Read.All",
        "Directory.ReadWrite.All"
    )

    $HasMembershipScope = $false

    if ($GraphContext) {
        foreach ($Scope in @($GraphContext.Scopes)) {
            if ($Scope -in $AcceptedScopes) {
                $HasMembershipScope = $true
                break
            }
        }
    }

    if (-not $GraphContext -or -not $HasMembershipScope) {
        Write-Host ""
        Write-Host "Microsoft Graph group membership permission is required." -ForegroundColor Yellow
        Write-Host "Launching Microsoft Graph sign-in..." -ForegroundColor Cyan
        Write-Host ""

        try {
            Connect-MgGraph -Scopes "GroupMember.Read.All" -NoWelcome -ErrorAction Stop
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

    $Inventory = @()
    $GuestInventory = @()
    $UnresolvedSites = @()
    $ExcludedTeamsChannelSites = @()

    foreach ($Site in $Sites) {
        if ([string]$Site.Template -like "TEAMCHANNEL#*") {
            $ExcludedTeamsChannelSites += [PSCustomObject]@{
                Url      = [string]$Site.Url
                Template = [string]$Site.Template
                Reason   = "Teams channel site membership is governed through the associated Team/channel and is excluded from Microsoft 365 Group site guest membership scoring."
            }
            continue
        }

        $GroupId = Get-TenantIQPropertyValue -Object $Site -Names @("GroupId")

        if (-not (Test-TenantIQGuid $GroupId) -or ([guid]$GroupId -eq [guid]::Empty)) {
            try {
                $DetailedSite = Get-SPOSite -Identity $Site.Url -ErrorAction Stop
                $GroupId = Get-TenantIQPropertyValue -Object $DetailedSite -Names @("GroupId")
            }
            catch {}
        }

        if (-not (Test-TenantIQGuid $GroupId) -or ([guid]$GroupId -eq [guid]::Empty)) {
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
                -Property Id,DisplayName,Mail,Visibility,GroupTypes `
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
            $Users = @(
                Get-MgGroupMemberAsUser `
                    -GroupId ([string]$GroupId) `
                    -All `
                    -Property Id,DisplayName,UserPrincipalName,Mail,UserType,AccountEnabled `
                    -ErrorAction Stop
            )
        }
        catch {
            $UnresolvedSites += [PSCustomObject]@{
                Url      = [string]$Site.Url
                Template = [string]$Site.Template
                GroupId  = [string]$GroupId
                Reason   = "Group user membership could not be retrieved. $($_.Exception.Message)"
            }
            continue
        }

        $Guests = @(
            $Users | Where-Object {
                [string]$_.UserType -eq "Guest"
            }
        )

        $DisabledGuests = @(
            $Guests | Where-Object {
                $null -ne $_.AccountEnabled -and
                $_.AccountEnabled -eq $false
            }
        )

        $GuestLabels = @(
            $Guests | ForEach-Object {
                if (-not [string]::IsNullOrWhiteSpace([string]$_.Mail)) {
                    [string]$_.Mail
                }
                elseif (-not [string]::IsNullOrWhiteSpace([string]$_.UserPrincipalName)) {
                    [string]$_.UserPrincipalName
                }
                elseif (-not [string]::IsNullOrWhiteSpace([string]$_.DisplayName)) {
                    [string]$_.DisplayName
                }
                else {
                    [string]$_.Id
                }
            }
        )

        $Inventory += [PSCustomObject]@{
            SiteUrl            = [string]$Site.Url
            GroupId            = [string]$Group.Id
            GroupDisplayName   = [string]$Group.DisplayName
            GroupMail          = [string]$Group.Mail
            Visibility         = [string]$Group.Visibility
            UserMemberCount    = $Users.Count
            GuestCount         = $Guests.Count
            DisabledGuestCount = $DisabledGuests.Count
            Guests             = if ($GuestLabels.Count -gt 0) {
                $GuestLabels -join ", "
            }
            else {
                "None"
            }
        }

        foreach ($Guest in $Guests) {
            $GuestInventory += [PSCustomObject]@{
                SiteUrl          = [string]$Site.Url
                GroupDisplayName = [string]$Group.DisplayName
                GroupId          = [string]$Group.Id
                Visibility       = [string]$Group.Visibility
                DisplayName      = [string]$Guest.DisplayName
                UserPrincipalName= [string]$Guest.UserPrincipalName
                Mail             = [string]$Guest.Mail
                AccountEnabled   = $Guest.AccountEnabled
            }
        }
    }

    $GroupsWithGuests = @(
        $Inventory | Where-Object {
            $_.GuestCount -gt 0
        }
    )

    $GroupsWithoutGuests = @(
        $Inventory | Where-Object {
            $_.GuestCount -eq 0
        }
    )

    $GroupsWithDisabledGuests = @(
        $Inventory | Where-Object {
            $_.DisabledGuestCount -gt 0
        }
    )

    $TotalGuests = @($GuestInventory).Count

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Microsoft 365 Group Guest Membership" -ForegroundColor Cyan
    Write-Host "------------------------------------"
    Write-Host ""
    Write-Host "Group-Connected Sites Discovered : $($Sites.Count)"
    Write-Host "Group Sites Successfully Reviewed: $($Inventory.Count)"
    Write-Host "Teams Channel Sites Excluded     : $($ExcludedTeamsChannelSites.Count)"
    Write-Host "Sites/Groups Not Resolved        : $($UnresolvedSites.Count)"
    Write-Host "Groups With Guest Members        : $($GroupsWithGuests.Count)"
    Write-Host "Groups Without Guest Members     : $($GroupsWithoutGuests.Count)"
    Write-Host "Total Guest Memberships          : $TotalGuests"
    Write-Host "Groups With Disabled Guests      : $($GroupsWithDisabledGuests.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Group Guest Membership Inventory" -ForegroundColor Cyan
        Write-Host "--------------------------------"

        $Inventory |
            Sort-Object `
                @{ Expression = "GuestCount"; Descending = $true }, `
                @{ Expression = "GroupDisplayName"; Descending = $false } |
            Select-Object `
                SiteUrl,
                GroupDisplayName,
                Visibility,
                UserMemberCount,
                GuestCount,
                DisabledGuestCount,
                Guests |
            Format-Table -AutoSize -Wrap
    }

    if ($GuestInventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Guest Membership Detail" -ForegroundColor Cyan
        Write-Host "-----------------------"

        $GuestInventory |
            Sort-Object GroupDisplayName, DisplayName |
            Select-Object `
                GroupDisplayName,
                SiteUrl,
                DisplayName,
                UserPrincipalName,
                Mail,
                AccountEnabled |
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
            Select-Object Url,Template,GroupId,Reason |
            Format-Table -AutoSize -Wrap
    }

    $Issues = @()

    if ($GroupsWithGuests.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($GroupsWithGuests.Count) Microsoft 365 Group-connected SharePoint site(s) contain guest members, representing $TotalGuests guest membership(s) that require external-collaboration review."
        }
    }

    if ($GroupsWithDisabledGuests.Count -gt 0) {
        $DisabledGuestMemberships = @(
            $GuestInventory | Where-Object {
                $null -ne $_.AccountEnabled -and
                $_.AccountEnabled -eq $false
            }
        ).Count

        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "$($GroupsWithDisabledGuests.Count) group-connected SharePoint site(s) retain $DisabledGuestMemberships disabled guest membership(s)."
        }
    }

    $Stopwatch.Stop()

    if ($Inventory.Count -eq 0 -and $Sites.Count -gt 0) {
        $Status = "INFO"
        $Severity = "None"
        $Finding = "TenantIQ discovered $($Sites.Count) Group-connected SharePoint site(s), but none could be fully assessed for guest membership."
        $Recommendation = "Verify SharePoint Online and Microsoft Graph connectivity and the GroupMember.Read.All permission, then rerun the assessment."

        Write-Host ""
        Write-Host "INFO  Microsoft 365 Group guest membership could not be fully assessed." -ForegroundColor Yellow
    }
    elseif ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) Microsoft 365 Group-connected SharePoint site(s) were reviewed and no guest user memberships were detected. $($ExcludedTeamsChannelSites.Count) Teams channel site(s) were intentionally excluded."
        $Recommendation = "Continue periodically reviewing Microsoft 365 Group membership and external collaboration requirements."

        Write-Host ""
        Write-Host "PASS  No guest membership was detected in the reviewed Microsoft 365 Group-connected SharePoint sites." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"

        if (@($Issues | Where-Object Severity -eq "High").Count -gt 0) {
            $Severity = "High"
        }
        elseif (@($Issues | Where-Object Severity -eq "Medium").Count -gt 0) {
            $Severity = "Medium"
        }
        else {
            $Severity = "Low"
        }

        $Finding = (@($Issues | ForEach-Object { $_.Finding }) -join " ")
        $Finding += " $($ExcludedTeamsChannelSites.Count) Teams channel site(s) were intentionally excluded from Microsoft 365 Group guest membership scoring."

        if ($UnresolvedSites.Count -gt 0) {
            $Finding += " $($UnresolvedSites.Count) site/group association(s) could not be resolved and were excluded from scoring."
        }

        $Recommendation = "Review guest membership for Microsoft 365 Groups associated with SharePoint sites. Confirm each external user still requires access, remove stale or unnecessary guests, and align external collaboration with SharePoint sharing, Entra B2B, access review, and guest lifecycle policies."

        Write-Host ""
        Write-Host "Microsoft 365 Group Guest Membership Findings" -ForegroundColor Cyan
        Write-Host "--------------------------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        if ($ExcludedTeamsChannelSites.Count -gt 0) {
            Write-Host ""
            Write-Host "INFO  $($ExcludedTeamsChannelSites.Count) Teams channel site(s) were excluded from Microsoft 365 Group guest membership scoring." -ForegroundColor DarkYellow
        }

        if ($UnresolvedSites.Count -gt 0) {
            Write-Host "INFO  $($UnresolvedSites.Count) site/group association(s) could not be resolved and were excluded from scoring." -ForegroundColor DarkYellow
        }

        Write-Host ""
        Write-Host "WARNING  Microsoft 365 Group guest membership requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Microsoft 365 Group Guest Membership" `
        -Category "Sharing" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Microsoft 365 Group Guest Membership health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Microsoft 365 Group Guest Membership health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Microsoft 365 Group Guest Membership assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Microsoft 365 Group Guest Membership" `
        -Category "Sharing" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify SharePoint Online and Microsoft Graph connections, ensure GroupMember.Read.All or equivalent permission is granted, and rerun the assessment." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
