function Ensure-TenantIQGraphDependency {
    param(
        [Parameter(Mandatory)][string]$ModuleName,
        [Parameter(Mandatory)][string]$CommandName
    )

    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        return $true
    }

    try {
        $Installed = Get-Module -ListAvailable -Name $ModuleName | Sort-Object Version -Descending | Select-Object -First 1

        if (-not $Installed) {
            Write-Host ""
            Write-Host "Installing required Microsoft Graph module: $ModuleName" -ForegroundColor Cyan

            Install-Module `
                -Name $ModuleName `
                -Scope CurrentUser `
                -Repository PSGallery `
                -Force `
                -AllowClobber `
                -ErrorAction Stop

            $Installed = Get-Module -ListAvailable -Name $ModuleName | Sort-Object Version -Descending | Select-Object -First 1
        }

        if ($Installed) {
            Import-Module $Installed.Path -Force -Global -ErrorAction Stop
        }
        else {
            throw "Module '$ModuleName' could not be located after installation."
        }
    }
    catch {
        if (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue) {
            Write-ExchangeAILog `
                -Message "Unable to prepare required Microsoft Graph module '$ModuleName'. $($_.Exception.Message)" `
                -Level ERROR
        }

        Write-Host ""
        Write-Host "[ERROR] Unable to prepare required Microsoft Graph module: $ModuleName" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

    return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Ensure-TenantIQGraphCore {
    try {
        if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
            $CoreModule = Get-Module -ListAvailable -Name "Microsoft.Graph.Authentication" | Sort-Object Version -Descending | Select-Object -First 1
            if (-not $CoreModule) {
                Write-Host ""
                Write-Host "Installing required Microsoft Graph module: Microsoft.Graph.Authentication" -ForegroundColor Cyan
                Install-Module -Name "Microsoft.Graph.Authentication" -Scope CurrentUser -Repository PSGallery -Force -AllowClobber -ErrorAction Stop
                $CoreModule = Get-Module -ListAvailable -Name "Microsoft.Graph.Authentication" | Sort-Object Version -Descending | Select-Object -First 1
            }
            if ($CoreModule) {
                Import-Module $CoreModule.Path -Force -Global -ErrorAction Stop
            }
        }

        return [bool](Get-Command Get-MgContext -ErrorAction SilentlyContinue)
    }
    catch {
        if (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue) {
            Write-ExchangeAILog -Message "Unable to prepare Microsoft Graph core authentication module. $($_.Exception.Message)" -Level ERROR
        }
        return $false
    }
}

function Ensure-TenantIQGraphReports {
    Ensure-TenantIQGraphDependency `
        -ModuleName "Microsoft.Graph.Reports" `
        -CommandName "Get-MgReportAuthenticationMethodUserRegistrationDetail"
}
