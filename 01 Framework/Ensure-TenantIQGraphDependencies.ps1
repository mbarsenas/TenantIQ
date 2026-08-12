function Get-TenantIQGraphStableVersion {
    return '2.33.0'
}

function Test-TenantIQPowerShell7 {
    return ($PSVersionTable.PSEdition -eq 'Core' -and $PSVersionTable.PSVersion.Major -ge 7)
}

function Get-TenantIQPowerShell7Path {
    $Candidates = @(
        (Get-Command pwsh.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1),
        "$env:ProgramFiles\PowerShell\7\pwsh.exe",
        "$env:ProgramFiles\PowerShell\7-preview\pwsh.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }

    return ($Candidates | Select-Object -First 1)
}

function Ensure-TenantIQGraphDependency {
    param(
        [Parameter(Mandatory)][string]$ModuleName,
        [Parameter(Mandatory)][string]$CommandName,
        [string]$RequiredVersion = (Get-TenantIQGraphStableVersion)
    )

    if (-not (Test-TenantIQPowerShell7)) {
        throw 'Microsoft Graph dependencies must be loaded in PowerShell 7 for TenantIQ Entra ID assessments.'
    }

    try {
        $Installed = Get-Module -ListAvailable -Name $ModuleName |
            Where-Object { $_.Version -eq [version]$RequiredVersion } |
            Select-Object -First 1

        if (-not $Installed) {
            Write-Host ''
            Write-Host "Installing required Microsoft Graph module: $ModuleName $RequiredVersion" -ForegroundColor Cyan
            Install-Module -Name $ModuleName -RequiredVersion $RequiredVersion -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
            $Installed = Get-Module -ListAvailable -Name $ModuleName |
                Where-Object { $_.Version -eq [version]$RequiredVersion } |
                Select-Object -First 1
        }

        if (-not $Installed) {
            throw "Module '$ModuleName' version $RequiredVersion could not be located after installation."
        }

        Import-Module $Installed.Path -RequiredVersion $RequiredVersion -Force -Global -ErrorAction Stop

        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
            throw "Command '$CommandName' is unavailable after loading $ModuleName $RequiredVersion."
        }

        return $true
    }
    catch {
        if (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue) {
            Write-ExchangeAILog -Message "Unable to prepare required Microsoft Graph module '$ModuleName' $RequiredVersion. $($_.Exception.Message)" -Level ERROR
        }
        Write-Host ''
        Write-Host "[ERROR] Unable to prepare required Microsoft Graph module: $ModuleName $RequiredVersion" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Ensure-TenantIQGraphCore {
    $RequiredVersion = Get-TenantIQGraphStableVersion

    if (-not (Test-TenantIQPowerShell7)) {
        $Pwsh = Get-TenantIQPowerShell7Path
        if ($Pwsh) {
            Write-Host ''
            Write-Host '[INFO] Entra ID requires PowerShell 7 because Microsoft Graph authentication is incompatible with this Windows PowerShell 5.1 process.' -ForegroundColor Yellow
            Write-Host '[INFO] TenantIQ will relaunch in PowerShell 7.' -ForegroundColor Cyan
            return $false
        }

        Write-Host ''
        Write-Host '[ERROR] PowerShell 7 is required for the Entra ID assessment on this system.' -ForegroundColor Red
        Write-Host 'Install PowerShell 7, then launch TenantIQ with pwsh.exe.' -ForegroundColor Yellow
        return $false
    }

    try {
        $CoreModule = Get-Module -ListAvailable -Name 'Microsoft.Graph.Authentication' |
            Where-Object { $_.Version -eq [version]$RequiredVersion } |
            Select-Object -First 1

        if (-not $CoreModule) {
            Write-Host ''
            Write-Host "Installing Microsoft Graph Authentication $RequiredVersion..." -ForegroundColor Cyan
            Install-Module -Name 'Microsoft.Graph.Authentication' -RequiredVersion $RequiredVersion -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
            $CoreModule = Get-Module -ListAvailable -Name 'Microsoft.Graph.Authentication' |
                Where-Object { $_.Version -eq [version]$RequiredVersion } |
                Select-Object -First 1
        }

        if (-not $CoreModule) {
            throw "Microsoft.Graph.Authentication $RequiredVersion could not be located after installation."
        }

        Import-Module $CoreModule.Path -RequiredVersion $RequiredVersion -Force -Global -ErrorAction Stop

        if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
            throw "Connect-MgGraph is unavailable after loading Microsoft.Graph.Authentication $RequiredVersion."
        }

        return [bool](Get-Command Get-MgContext -ErrorAction SilentlyContinue)
    }
    catch {
        if (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue) {
            Write-ExchangeAILog -Message "Unable to prepare Microsoft Graph core authentication module $RequiredVersion. $($_.Exception.Message)" -Level ERROR
        }
        Write-Host ''
        Write-Host "[ERROR] Unable to prepare Microsoft Graph Authentication $RequiredVersion." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Ensure-TenantIQGraphReports {
    $RequiredVersion = Get-TenantIQGraphStableVersion
    Ensure-TenantIQGraphDependency -ModuleName 'Microsoft.Graph.Reports' -CommandName 'Get-MgReportAuthenticationMethodUserRegistrationDetail' -RequiredVersion $RequiredVersion
}
