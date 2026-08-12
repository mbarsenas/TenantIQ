function Ensure-TenantIQGraphDependency {
    param(
        [Parameter(Mandatory)][string]$ModuleName,
        [Parameter(Mandatory)][string]$CommandName
    )

    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        return $true
    }

    try {
        $Installed = Get-Module -ListAvailable -Name $ModuleName | Select-Object -First 1

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
        }

        Import-Module $ModuleName -Force -ErrorAction Stop
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

function Ensure-TenantIQGraphReports {
    Ensure-TenantIQGraphDependency `
        -ModuleName "Microsoft.Graph.Reports" `
        -CommandName "Get-MgReportAuthenticationMethodUserRegistrationDetail"
}
