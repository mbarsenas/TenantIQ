function Ensure-TenantIQGraphDependency {
    param(
        [Parameter(Mandatory)][string]$ModuleName,
        [Parameter(Mandatory)][string]$CommandName,
        [string]$RequiredVersion
    )

    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        return $true
    }

    try {
        $Installed = if ($RequiredVersion) {
            Get-Module -ListAvailable -Name $ModuleName | Where-Object { $_.Version -eq [version]$RequiredVersion } | Select-Object -First 1
        }
        else {
            Get-Module -ListAvailable -Name $ModuleName | Sort-Object Version -Descending | Select-Object -First 1
        }

        if (-not $Installed) {
            Write-Host ""
            if ($RequiredVersion) {
                Write-Host "Installing required Microsoft Graph module: $ModuleName $RequiredVersion" -ForegroundColor Cyan
                Install-Module -Name $ModuleName -RequiredVersion $RequiredVersion -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
            }
            else {
                Write-Host "Installing required Microsoft Graph module: $ModuleName" -ForegroundColor Cyan
                Install-Module -Name $ModuleName -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
            }

            $Installed = if ($RequiredVersion) {
                Get-Module -ListAvailable -Name $ModuleName | Where-Object { $_.Version -eq [version]$RequiredVersion } | Select-Object -First 1
            }
            else {
                Get-Module -ListAvailable -Name $ModuleName | Sort-Object Version -Descending | Select-Object -First 1
            }
        }

        if ($Installed) {
            Remove-Module $ModuleName -Force -ErrorAction SilentlyContinue
            Import-Module $Installed.Path -Force -Global -ErrorAction Stop
        }
        else {
            throw "Module '$ModuleName' could not be located after installation."
        }
    }
    catch {
        if (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue) {
            Write-ExchangeAILog -Message "Unable to prepare required Microsoft Graph module '$ModuleName'. $($_.Exception.Message)" -Level ERROR
        }

        Write-Host ""
        Write-Host "[ERROR] Unable to prepare required Microsoft Graph module: $ModuleName" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

    return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Ensure-TenantIQGraphCore {
    $StableAuthVersion = '2.33.0'

    try {
        $Loaded = Get-Module -Name 'Microsoft.Graph.Authentication' -ErrorAction SilentlyContinue
        if ($Loaded -and $Loaded.Version -ne [version]$StableAuthVersion) {
            Remove-Module 'Microsoft.Graph.Authentication' -Force -ErrorAction SilentlyContinue
        }

        $CoreModule = Get-Module -ListAvailable -Name 'Microsoft.Graph.Authentication' |
            Where-Object { $_.Version -eq [version]$StableAuthVersion } |
            Select-Object -First 1

        if (-not $CoreModule) {
            Write-Host ""
            Write-Host "Installing stable Microsoft Graph Authentication module: $StableAuthVersion" -ForegroundColor Cyan
            Install-Module -Name 'Microsoft.Graph.Authentication' -RequiredVersion $StableAuthVersion -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
            $CoreModule = Get-Module -ListAvailable -Name 'Microsoft.Graph.Authentication' |
                Where-Object { $_.Version -eq [version]$StableAuthVersion } |
                Select-Object -First 1
        }

        if (-not $CoreModule) {
            throw "Microsoft.Graph.Authentication $StableAuthVersion could not be located after installation."
        }

        Import-Module $CoreModule.Path -RequiredVersion $StableAuthVersion -Force -Global -ErrorAction Stop

        if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
            throw "Connect-MgGraph is unavailable after loading Microsoft.Graph.Authentication $StableAuthVersion."
        }

        return [bool](Get-Command Get-MgContext -ErrorAction SilentlyContinue)
    }
    catch {
        if (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue) {
            Write-ExchangeAILog -Message "Unable to prepare Microsoft Graph core authentication module. $($_.Exception.Message)" -Level ERROR
        }

        Write-Host ""
        Write-Host "[ERROR] Unable to prepare Microsoft Graph Authentication $StableAuthVersion." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Ensure-TenantIQGraphReports {
    Ensure-TenantIQGraphDependency -ModuleName 'Microsoft.Graph.Reports' -CommandName 'Get-MgReportAuthenticationMethodUserRegistrationDetail'
}
