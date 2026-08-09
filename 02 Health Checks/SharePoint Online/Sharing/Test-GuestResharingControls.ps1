$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Guest Resharing Controls health check." -Level INFO

try {
    foreach ($Command in @("Get-SPOTenant","Get-SPOSite")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "$Command is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
        }
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online guest resharing controls..." -ForegroundColor Cyan

    try {
        $Tenant = Get-SPOTenant -ErrorAction Stop
        $Sites = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online sharing settings. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
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

    $PreventExternalUsersFromResharing = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("PreventExternalUsersFromResharing")

    $RestrictExternalSharingToSecurityGroup = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("RestrictExternalSharingToSecurityGroup")

    $ExternalSharingSecurityGroup = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("ExternalSharingSecurityGroup")

    $ExternalSharingSecurityGroupAllowList = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("ExternalSharingSecurityGroupAllowList")

    $ExternalSharingSecurityGroupAllowListCount = 0

    if ($null -ne $ExternalSharingSecurityGroupAllowList) {
        $ExternalSharingSecurityGroupAllowListCount = @($ExternalSharingSecurityGroupAllowList).Count
    }

    $Inventory = @(
        foreach ($Site in $Sites) {
            try {
                $Detail = Get-SPOSite -Identity $Site.Url -ErrorAction Stop
            }
            catch {
                $Detail = $Site
                Write-ExchangeAILog `
                    -Message "Unable to retrieve detailed sharing properties for '$($Site.Url)'. Using list result. $($_.Exception.Message)" `
                    -Level WARNING
            }

            $SharingCapability = [string](Get-TenantIQProperty `
                -Object $Detail `
                -Names @("SharingCapability"))

            [PSCustomObject]@{
                Url                 = [string]$Detail.Url
                SharingCapability   = $SharingCapability
                ExternallyShareable = ($SharingCapability -ne "Disabled")
                AnonymousCapable    = ($SharingCapability -eq "ExternalUserAndGuestSharing")
            }
        }
    )

    $ExternalSites = @(
        $Inventory | Where-Object { $_.ExternallyShareable -eq $true }
    )

    $AnonymousSites = @(
        $Inventory | Where-Object { $_.AnonymousCapable -eq $true }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Guest Resharing Controls" -ForegroundColor Cyan
    Write-Host "------------------------"
    Write-Host ""
    Write-Host "Prevent External Users From Resharing : $PreventExternalUsersFromResharing"
    Write-Host "Externally Shareable Sites            : $($ExternalSites.Count)"
    Write-Host "Anyone/Anonymous-Capable Sites        : $($AnonymousSites.Count)"
    Write-Host "External Sharing Restricted to Group  : $RestrictExternalSharingToSecurityGroup"
    Write-Host "Configured Sharing Security Group     : $ExternalSharingSecurityGroup"
    Write-Host "Sharing Security Group AllowList      : $ExternalSharingSecurityGroupAllowListCount"

    if ($ExternalSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Externally Shareable Site Inventory" -ForegroundColor Cyan
        Write-Host "-----------------------------------"

        $ExternalSites |
            Sort-Object SharingCapability, Url |
            Format-Table Url, SharingCapability -AutoSize
    }

    $Issues = @()

    if ($ExternalSites.Count -gt 0 -and $PreventExternalUsersFromResharing -ne $true) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "External sharing is enabled and external users are not prevented from resharing files, folders, and sites they do not own."
        }
    }

    if ($AnonymousSites.Count -gt 0 -and $PreventExternalUsersFromResharing -ne $true) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($AnonymousSites.Count) site collection(s) permit Anyone links while tenant guest resharing prevention is disabled."
        }
    }

    if ($RestrictExternalSharingToSecurityGroup -eq $true -and
        [string]::IsNullOrWhiteSpace([string]$ExternalSharingSecurityGroup) -and
        $ExternalSharingSecurityGroupAllowListCount -eq 0) {

        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "External sharing is configured to be restricted to security groups, but no sharing security group configuration was returned."
        }
    }

    $Stopwatch.Stop()

    if ($ExternalSites.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No SharePoint Online site collections are externally shareable, so guest resharing exposure is not present."
        $Recommendation = "No guest resharing remediation is required while external sharing remains disabled."

        Write-Host ""
        Write-Host "PASS  No externally shareable sites were detected." -ForegroundColor Green
    }
    elseif ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "SharePoint Online guest resharing controls were reviewed and external users are prevented from resharing content they do not own."
        $Recommendation = "Continue reviewing external sharing governance and any security-group-based sharing restrictions as collaboration requirements change."

        Write-Host ""
        Write-Host "PASS  Guest resharing controls appear healthy." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"

        if (@($Issues | Where-Object Severity -eq "High").Count -gt 0) {
            $Severity = "High"
        }
        else {
            $Severity = "Medium"
        }

        $Finding = (@($Issues | ForEach-Object { $_.Finding }) -join " ")
        $Recommendation = "Consider enabling PreventExternalUsersFromResharing to stop external users from resharing content they do not own. Where appropriate, also restrict who can share externally by using approved Microsoft Entra security groups."

        Write-Host ""
        Write-Host "Guest Resharing Findings" -ForegroundColor Cyan
        Write-Host "------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Guest resharing controls require review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Guest Resharing Controls" `
        -Category "Sharing" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Guest Resharing Controls health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Guest Resharing Controls health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Guest Resharing Controls assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Guest Resharing Controls" `
        -Category "Sharing" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
