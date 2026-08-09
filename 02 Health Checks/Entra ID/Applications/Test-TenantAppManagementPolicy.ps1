$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Tenant App Management Policy health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    #$RequiredScope = "Policy.Read.ApplicationConfiguration"
	$RequiredScope = "Policy.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with application policy read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope -NoWelcome
    }

    Write-Host ""
    Write-Host "Retrieving Entra tenant app management policy..." -ForegroundColor Cyan

    $Policy = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/policies/defaultAppManagementPolicy" `
        -ErrorAction Stop

    function Get-RestrictionSummary {
        param($Restrictions)

        $Result = [ordered]@{
            PasswordAddition       = $false
            PasswordLifetime       = $false
            SymmetricKeyAddition   = $false
            SymmetricKeyLifetime   = $false
            AsymmetricKeyLifetime  = $false
        }

        if ($null -eq $Restrictions) {
            return [PSCustomObject]$Result
        }

        $Password = $Restrictions.passwordCredentials
        $Key = $Restrictions.keyCredentials

        if ($Password) {
            if ($Password.restrictionType -contains "passwordAddition") {
                $Result.PasswordAddition = $true
            }
            if ($Password.restrictionType -contains "passwordLifetime") {
                $Result.PasswordLifetime = $true
            }
            if ($Password.restrictionType -contains "symmetricKeyAddition") {
                $Result.SymmetricKeyAddition = $true
            }
            if ($Password.restrictionType -contains "symmetricKeyLifetime") {
                $Result.SymmetricKeyLifetime = $true
            }
        }

        if ($Key) {
            if ($Key.restrictionType -contains "asymmetricKeyLifetime") {
                $Result.AsymmetricKeyLifetime = $true
            }
        }

        return [PSCustomObject]$Result
    }

    $AppSummary = Get-RestrictionSummary -Restrictions $Policy.applicationRestrictions
    $SPSummary  = Get-RestrictionSummary -Restrictions $Policy.servicePrincipalRestrictions

    $Enabled = [bool]$Policy.isEnabled

    $AppRestrictionCount = @(
        $AppSummary.PSObject.Properties | Where-Object Value -eq $true
    ).Count

    $SPRestrictionCount = @(
        $SPSummary.PSObject.Properties | Where-Object Value -eq $true
    ).Count

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Tenant App Management Policy" -ForegroundColor Cyan
    Write-Host "----------------------------"
    Write-Host ""
    Write-Host "Policy Enabled                  : $Enabled"
    Write-Host "Application Restrictions       : $AppRestrictionCount"
    Write-Host "Service Principal Restrictions : $SPRestrictionCount"

    Write-Host ""
    Write-Host "Application Credential Controls" -ForegroundColor Cyan
    Write-Host "-------------------------------"
    Write-Host "Password Addition Restricted    : $($AppSummary.PasswordAddition)"
    Write-Host "Password Lifetime Restricted    : $($AppSummary.PasswordLifetime)"
    Write-Host "Symmetric Key Addition Restricted: $($AppSummary.SymmetricKeyAddition)"
    Write-Host "Symmetric Key Lifetime Restricted: $($AppSummary.SymmetricKeyLifetime)"
    Write-Host "Certificate Lifetime Restricted : $($AppSummary.AsymmetricKeyLifetime)"

    Write-Host ""
    Write-Host "Service Principal Credential Controls" -ForegroundColor Cyan
    Write-Host "-------------------------------------"
    Write-Host "Password Addition Restricted    : $($SPSummary.PasswordAddition)"
    Write-Host "Password Lifetime Restricted    : $($SPSummary.PasswordLifetime)"
    Write-Host "Symmetric Key Addition Restricted: $($SPSummary.SymmetricKeyAddition)"
    Write-Host "Symmetric Key Lifetime Restricted: $($SPSummary.SymmetricKeyLifetime)"
    Write-Host "Certificate Lifetime Restricted : $($SPSummary.AsymmetricKeyLifetime)"

    $Stopwatch.Stop()

    if (-not $Enabled) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "The tenant default application management policy exists but is not enabled."
        $Recommendation = "Evaluate enabling the tenant app management policy and enforce credential restrictions appropriate for applications and service principals, including secret and certificate lifetime controls."
        Write-Host ""
        Write-Host "WARNING  Tenant app management policy is not enabled." -ForegroundColor Yellow
    }
    elseif (($AppRestrictionCount + $SPRestrictionCount) -eq 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "The tenant app management policy is enabled but no application or service principal credential restrictions were detected."
        $Recommendation = "Configure credential restrictions for applications and service principals based on organizational security requirements."
        Write-Host ""
        Write-Host "WARNING  App management policy has no detected credential restrictions." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "The tenant app management policy is enabled with $AppRestrictionCount application restriction(s) and $SPRestrictionCount service principal restriction(s) detected."
        $Recommendation = "Continue reviewing application and service principal credential restrictions as Microsoft Entra application security guidance evolves."
        Write-Host ""
        Write-Host "PASS  Tenant app management credential restrictions are configured." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Tenant App Management Policy" `
        -Category "Applications" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Tenant App Management Policy health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Tenant App Management Policy health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Tenant App Management Policy assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Tenant App Management Policy" `
        -Category "Applications" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Policy.Read.ApplicationConfiguration consent, Microsoft Graph connectivity, and access to the default app management policy." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
