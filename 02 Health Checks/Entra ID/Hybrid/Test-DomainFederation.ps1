$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Domain Federation health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScopes = @(
        "Domain.Read.All",
        "Domain-InternalFederation.Read.All"
    )

    $Context = Get-MgContext -ErrorAction SilentlyContinue
    $MissingScopes = @(
        $RequiredScopes | Where-Object {
            -not $Context -or $Context.Scopes -notcontains $_
        }
    )

    if ($MissingScopes.Count -gt 0) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with domain federation read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScopes -NoWelcome
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
    Write-Host "Retrieving Entra domain federation configuration..." -ForegroundColor Cyan

    $Domains = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/domains"
    )

    $VerifiedDomains = @(
        $Domains | Where-Object { $_.isVerified -eq $true }
    )

    $FederatedDomains = @(
        $VerifiedDomains | Where-Object {
            [string]$_.authenticationType -eq "Federated"
        }
    )

    $ManagedDomains = @(
        $VerifiedDomains | Where-Object {
            [string]$_.authenticationType -eq "Managed"
        }
    )

    $FederationInventory = @()

    foreach ($Domain in $FederatedDomains) {

        $DomainId = [uri]::EscapeDataString([string]$Domain.id)

        $Configs = @(
            Get-TenantIQGraphCollection `
                -Uri "https://graph.microsoft.com/v1.0/domains/$DomainId/federationConfiguration"
        )

        foreach ($Config in $Configs) {
            $FederationInventory += [PSCustomObject]@{
                Domain                  = [string]$Domain.id
                DisplayName             = [string]$Config.displayName
                IssuerUri               = [string]$Config.issuerUri
                PassiveSignInUri        = [string]$Config.passiveSignInUri
                ActiveSignInUri         = [string]$Config.activeSignInUri
                SignOutUri              = [string]$Config.signOutUri
                PreferredAuthProtocol   = [string]$Config.preferredAuthenticationProtocol
                FederatedIdpMfaBehavior = [string]$Config.federatedIdpMfaBehavior
                PromptLoginBehavior     = [string]$Config.promptLoginBehavior
                IsSignedAuthenticationRequestRequired = [bool]$Config.isSignedAuthenticationRequestRequired
                NextSigningCertificate = $Config.nextSigningCertificate
            }
        }
    }

    $MissingConfigs = @(
        $FederatedDomains | Where-Object {
            $DomainName = [string]$_.id
            -not ($FederationInventory | Where-Object { $_.Domain -eq $DomainName })
        }
    )

    $NoIssuer = @(
        $FederationInventory | Where-Object {
            [string]::IsNullOrWhiteSpace($_.IssuerUri)
        }
    )

    $NoPassiveUri = @(
        $FederationInventory | Where-Object {
            [string]::IsNullOrWhiteSpace($_.PassiveSignInUri)
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Domain Federation" -ForegroundColor Cyan
    Write-Host "-----------------"
    Write-Host ""
    Write-Host "Verified Domains              : $($VerifiedDomains.Count)"
    Write-Host "Managed Domains               : $($ManagedDomains.Count)"
    Write-Host "Federated Domains             : $($FederatedDomains.Count)"
    Write-Host "Federation Configurations     : $($FederationInventory.Count)"
    Write-Host "Federated Domains No Config   : $($MissingConfigs.Count)"
    Write-Host "Configurations Missing Issuer : $($NoIssuer.Count)"
    Write-Host "Configurations Missing SignIn : $($NoPassiveUri.Count)"

    if ($FederationInventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Federation Configuration Inventory" -ForegroundColor Cyan
        Write-Host "----------------------------------"

        $FederationInventory |
            Select-Object `
                Domain,
                DisplayName,
                PreferredAuthProtocol,
                FederatedIdpMfaBehavior,
                PromptLoginBehavior,
                IssuerUri,
                PassiveSignInUri |
            Format-Table -AutoSize -Wrap
    }

    $Stopwatch.Stop()

    if ($FederatedDomains.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No verified Entra domains use federated authentication."
        $Recommendation = "No federation-specific remediation is required. Continue monitoring domain authentication type for future changes."

        Write-Host ""
        Write-Host "PASS  No federated Entra domains are configured." -ForegroundColor Green
    }
    elseif ($MissingConfigs.Count -gt 0) {
        $Status = "FAIL"
        $Severity = "High"
        $Finding = "$($MissingConfigs.Count) federated domain(s) do not have a readable internal federation configuration."
        $Recommendation = "Review the affected federated domains and verify their internal domain federation configuration, identity provider metadata, and sign-in endpoints."

        Write-Host ""
        Write-Host "FAIL  Federated domains without federation configuration were detected." -ForegroundColor Red
    }
    elseif (($NoIssuer.Count + $NoPassiveUri.Count) -gt 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "One or more domain federation configurations are missing expected issuer or passive sign-in URI values."
        $Recommendation = "Review the affected federation configuration and validate identity provider metadata and authentication endpoints."

        Write-Host ""
        Write-Host "WARNING  Federation configuration metadata requires review." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($FederatedDomains.Count) federated domain(s) were reviewed and each has an internal federation configuration with expected core metadata."
        $Recommendation = "Continue reviewing federation certificates, MFA behavior, issuer information, and identity provider endpoints as part of hybrid identity governance."

        Write-Host ""
        Write-Host "PASS  Domain federation configuration appears healthy." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Domain Federation" `
        -Category "Hybrid" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Domain Federation health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Domain Federation health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Domain Federation assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Domain Federation" `
        -Category "Hybrid" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Domain.Read.All and Domain-InternalFederation.Read.All consent, Microsoft Graph connectivity, and a supported Entra role." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
