function Remove-TenantIQGraphModules {
    Get-Module -Name 'Microsoft.Graph*' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object {
            try { Remove-Module $_.Name -Force -ErrorAction SilentlyContinue } catch {}
        }
}

function Ensure-TenantIQGraphDependency {
    param(
        [Parameter(Mandatory)][string]$ModuleName,
        [Parameter(Mandatory)][string]$CommandName,
        [string]$RequiredVersion
    )

    try {
        $Installed = if ($RequiredVersion) {
            Get-Module -ListAvailable -Name $ModuleName |
                Where-Object { $_.Version -eq [version]$RequiredVersion } |
                Select-Object -First 1
        }
        else {
            Get-Module -ListAvailable -Name $ModuleName |
                Sort-Object Version -Descending |
                Select-Object -First 1
        }

        if (-not $Installed) {
            Write-Host ''
            if ($RequiredVersion) {
                Write-Host "Installing required Microsoft Graph module: $ModuleName $RequiredVersion" -ForegroundColor Cyan
                Install-Module -Name $ModuleName -RequiredVersion $RequiredVersion -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
            }
            else {
                Write-Host "Installing required Microsoft Graph module: $ModuleName" -ForegroundColor Cyan
                Install-Module -Name $ModuleName -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
            }

            $Installed = if ($RequiredVersion) {
                Get-Module -ListAvailable -Name $ModuleName |
                    Where-Object { $_.Version -eq [version]$RequiredVersion } |
                    Select-Object -First 1
            }
            else {
                Get-Module -ListAvailable -Name $ModuleName |
                    Sort-Object Version -Descending |
                    Select-Object -First 1
            }
        }

        if (-not $Installed) {
            throw "Module '$ModuleName' could not be located after installation."
        }

        Import-Module $Installed.Path -Force -Global -ErrorAction Stop

        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
            throw "Command '$CommandName' is unavailable after loading $ModuleName."
        }

        return $true
    }
    catch {
        if (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue) {
            Write-ExchangeAILog -Message "Unable to prepare required Microsoft Graph module '$ModuleName'. $($_.Exception.Message)" -Level ERROR
        }
        Write-Host ''
        Write-Host "[ERROR] Unable to prepare required Microsoft Graph module: $ModuleName" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Ensure-TenantIQGraphCore {
    try {
        # A Graph module version already loaded into Windows PowerShell can leave incompatible
        # Authentication.Core assemblies resident in the process. Remove every loaded Graph module
        # before selecting one coherent installed SDK version.
        Remove-TenantIQGraphModules

        $AuthModules = @(Get-Module -ListAvailable -Name 'Microsoft.Graph.Authentication' |
            Sort-Object Version -Descending)

        if ($AuthModules.Count -eq 0) {
            Write-Host ''
            Write-Host 'Installing Microsoft Graph Authentication module...' -ForegroundColor Cyan
            Install-Module -Name 'Microsoft.Graph.Authentication' -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
            $AuthModules = @(Get-Module -ListAvailable -Name 'Microsoft.Graph.Authentication' | Sort-Object Version -Descending)
        }

        if ($AuthModules.Count -eq 0) {
            throw 'Microsoft.Graph.Authentication could not be located after installation.'
        }

        $ImportErrors = @()
        $LoadedAuth = $null

        foreach ($Candidate in $AuthModules) {
            try {
                Import-Module $Candidate.Path -Force -Global -ErrorAction Stop
                if (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue) {
                    $LoadedAuth = $Candidate
                    break
                }
            }
            catch {
                $ImportErrors += ("{0}: {1}" -f $Candidate.Version,$_.Exception.Message)
                Remove-TenantIQGraphModules
            }
        }

        if (-not $LoadedAuth) {
            $Details = if ($ImportErrors.Count -gt 0) { $ImportErrors -join ' | ' } else { 'No compatible installed version could be loaded.' }
            throw "No compatible Microsoft.Graph.Authentication version could be loaded in this PowerShell process. $Details"
        }

        return [bool](Get-Command Get-MgContext -ErrorAction SilentlyContinue)
    }
    catch {
        if (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue) {
            Write-ExchangeAILog -Message "Unable to prepare Microsoft Graph core authentication module. $($_.Exception.Message)" -Level ERROR
        }
        Write-Host ''
        Write-Host '[ERROR] Unable to prepare Microsoft Graph core authentication module.' -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ''
        Write-Host 'Close this TenantIQ PowerShell window completely and start TenantIQ again after syncing.' -ForegroundColor Yellow
        return $false
    }
}

function Ensure-TenantIQGraphReports {
    Ensure-TenantIQGraphDependency -ModuleName 'Microsoft.Graph.Reports' -CommandName 'Get-MgReportAuthenticationMethodUserRegistrationDetail'
}
