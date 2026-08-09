$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Domain Configuration health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "Domain.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with domain read permissions..." -ForegroundColor Cyan
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
    Write-Host "Retrieving Entra domain configuration..." -ForegroundColor Cyan

    $Domains = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/domains"
    )

    $Verified = @($Domains | Where-Object { $_.isVerified -eq $true })
    $Unverified = @($Domains | Where-Object { $_.isVerified -ne $true })
    $Managed = @($Domains | Where-Object { [string]$_.authenticationType -eq "Managed" })
    $Federated = @($Domains | Where-Object { [string]$_.authenticationType -eq "Federated" })
    $Default = @($Domains | Where-Object { $_.isDefault -eq $true })
    $Initial = @($Domains | Where-Object { $_.isInitial -eq $true })

    $DefaultDomain = if ($Default.Count -gt 0) { [string]$Default[0].id } else { "Not detected" }
    $InitialDomain = if ($Initial.Count -gt 0) { [string]$Initial[0].id } else { "Not detected" }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Domain Configuration" -ForegroundColor Cyan
    Write-Host "--------------------"
    Write-Host ""
    Write-Host "Domains Reviewed      : $($Domains.Count)"
    Write-Host "Verified Domains      : $($Verified.Count)"
    Write-Host "Unverified Domains    : $($Unverified.Count)"
    Write-Host "Managed Domains       : $($Managed.Count)"
    Write-Host "Federated Domains     : $($Federated.Count)"
    Write-Host "Default Domain        : $DefaultDomain"
    Write-Host "Initial Domain        : $InitialDomain"

    if ($Domains.Count -gt 0) {
        Write-Host ""
        Write-Host "Domain Inventory" -ForegroundColor Cyan
        Write-Host "----------------"

        $Domains |
            Sort-Object @{Expression={-not $_.isDefault}}, id |
            ForEach-Object {
                [PSCustomObject]@{
                    Domain             = [string]$_.id
                    Verified           = [bool]$_.isVerified
                    Default            = [bool]$_.isDefault
                    Initial            = [bool]$_.isInitial
                    AuthenticationType = [string]$_.authenticationType
                    AdminManaged       = [bool]$_.isAdminManaged
                    SupportedServices  = (@($_.supportedServices) -join ", ")
                }
            } |
            Format-Table -AutoSize
    }

    $Stopwatch.Stop()

    if ($Domains.Count -eq 0) {
        $Status = "FAIL"
        $Severity = "High"
        $Finding = "No Entra domain objects were returned."
        $Recommendation = "Verify tenant domain configuration and Microsoft Graph access."
        Write-Host ""
        Write-Host "FAIL  No Entra domains were returned." -ForegroundColor Red
    }
    elseif ($Default.Count -eq 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "No default Entra domain was identified."
        $Recommendation = "Review tenant domain configuration and verify a valid default domain is configured."
        Write-Host ""
        Write-Host "WARNING  No default Entra domain was identified." -ForegroundColor Yellow
    }
    elseif ($Unverified.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($Unverified.Count) Entra domain(s) are not verified."
        $Recommendation = "Review unverified domains and either complete verification for domains still required or remove obsolete domain objects."
        Write-Host ""
        Write-Host "WARNING  Unverified Entra domains require review." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Domains.Count) Entra domain(s) were reviewed and all are verified. Default domain: $DefaultDomain."
        $Recommendation = "Continue periodically reviewing verified domains, authentication type, and supported services. Review federated domains separately when federation is in use."
        Write-Host ""
        Write-Host "PASS  Entra domain configuration appears healthy." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Domain Configuration" `
        -Category "Identity" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Domain Configuration health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Domain Configuration health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Domain Configuration assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Domain Configuration" `
        -Category "Identity" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Domain.Read.All consent and Microsoft Graph connectivity." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
