$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online External Sharing Security Groups health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOTenant -ErrorAction SilentlyContinue)) {
        throw "Get-SPOTenant is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online external sharing security group controls..." -ForegroundColor Cyan

    try {
        $Tenant = Get-SPOTenant -ErrorAction Stop
    }
    catch {
        throw "Unable to retrieve SharePoint Online tenant settings. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
    }

    function Get-TenantIQProperty {
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

    function Normalize-TenantIQGuidList {
        param($Value)

        if ($null -eq $Value) {
            return @()
        }

        return @(
            @($Value) |
            ForEach-Object {
                $Text = [string]$_
                if (-not [string]::IsNullOrWhiteSpace($Text)) {
                    $Text.Trim()
                }
            } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
        )
    }

    $AnonymousAllowListRaw = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("WhoCanShareAnonymousAllowList")

    $AuthenticatedGuestAllowListRaw = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("WhoCanShareAuthenticatedGuestAllowList")

    $AnonymousAllowList = @(Normalize-TenantIQGuidList $AnonymousAllowListRaw)
    $AuthenticatedGuestAllowList = @(Normalize-TenantIQGuidList $AuthenticatedGuestAllowListRaw)

    $InvalidAnonymousIds = @(
        $AnonymousAllowList | Where-Object {
            $Parsed = [guid]::Empty
            -not [guid]::TryParse($_, [ref]$Parsed)
        }
    )

    $InvalidAuthenticatedGuestIds = @(
        $AuthenticatedGuestAllowList | Where-Object {
            $Parsed = [guid]::Empty
            -not [guid]::TryParse($_, [ref]$Parsed)
        }
    )

    $DuplicateAcrossLists = @(
        $AnonymousAllowList | Where-Object {
            $_ -in $AuthenticatedGuestAllowList
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "External Sharing Security Groups" -ForegroundColor Cyan
    Write-Host "--------------------------------"
    Write-Host ""
    Write-Host "Anonymous Sharing Group Count       : $($AnonymousAllowList.Count)"
    Write-Host "Authenticated Guest Group Count     : $($AuthenticatedGuestAllowList.Count)"
    Write-Host "Invalid Anonymous Group IDs         : $($InvalidAnonymousIds.Count)"
    Write-Host "Invalid Authenticated Group IDs     : $($InvalidAuthenticatedGuestIds.Count)"
    Write-Host "Groups Present In Both Lists        : $($DuplicateAcrossLists.Count)"

    if ($AnonymousAllowList.Count -gt 0) {
        Write-Host ""
        Write-Host "Groups Allowed to Share with Anyone" -ForegroundColor Cyan
        Write-Host "-----------------------------------"
        $AnonymousAllowList | ForEach-Object { Write-Host $_ }
    }

    if ($AuthenticatedGuestAllowList.Count -gt 0) {
        Write-Host ""
        Write-Host "Groups Allowed to Share with Authenticated Guests" -ForegroundColor Cyan
        Write-Host "-------------------------------------------------"
        $AuthenticatedGuestAllowList | ForEach-Object { Write-Host $_ }
    }

    $Issues = @()

    if ($InvalidAnonymousIds.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "$($InvalidAnonymousIds.Count) entry or entries in WhoCanShareAnonymousAllowList are not valid GUID values."
        }
    }

    if ($InvalidAuthenticatedGuestIds.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "$($InvalidAuthenticatedGuestIds.Count) entry or entries in WhoCanShareAuthenticatedGuestAllowList are not valid GUID values."
        }
    }

    if ($AnonymousAllowList.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($AnonymousAllowList.Count) Microsoft Entra security group(s) are allowed to share externally using Anyone links."
        }
    }

    if ($AuthenticatedGuestAllowList.Count -eq 0 -and $AnonymousAllowList.Count -eq 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "No external-sharing security group allow lists are configured, so TenantIQ did not detect a restriction limiting who can share externally to designated Entra security groups."
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($AuthenticatedGuestAllowList.Count) security group(s) are configured for authenticated-guest external sharing, and no Anyone-link sharing groups or invalid group identifiers were detected."
        $Recommendation = "Continue reviewing the approved Entra security groups and keep authenticated-guest sharing scoped to the minimum set of users required."

        Write-Host ""
        Write-Host "PASS  External sharing security group configuration appears healthy." -ForegroundColor Green
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
        $Recommendation = "Review external-sharing security group controls. Prefer authenticated-guest sharing for sensitive or proprietary content, limit Anyone-link sharing to narrowly scoped approved groups when required, and use valid Microsoft Entra security group object IDs."

        Write-Host ""
        Write-Host "External Sharing Security Group Findings" -ForegroundColor Cyan
        Write-Host "----------------------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  External sharing security group controls require review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "External Sharing Security Groups" `
        -Category "Sharing" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online External Sharing Security Groups health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online External Sharing Security Groups health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "External Sharing Security Groups assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "External Sharing Security Groups" `
        -Category "Sharing" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
