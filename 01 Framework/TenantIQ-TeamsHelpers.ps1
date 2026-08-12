# TenantIQ Microsoft Teams shared connection helper
# Provides the connection contract required by the hardened Teams evaluator.

function Ensure-TenantIQTeamsConnection {
    try {
        if (-not (Get-Module MicrosoftTeams -ListAvailable -ErrorAction SilentlyContinue)) {
            throw 'MicrosoftTeams PowerShell module is not installed.'
        }

        if (-not (Get-Module MicrosoftTeams -ErrorAction SilentlyContinue)) {
            Import-Module MicrosoftTeams -ErrorAction Stop
        }

        # A lightweight tenant query is the most reliable cross-version test that
        # an authenticated Teams PowerShell session is usable.
        try {
            $null = Get-CsTenant -ErrorAction Stop
            return $true
        }
        catch {
            # No usable session exists. Authenticate once, then validate it.
        }

        Write-Host ''
        Write-Host 'Microsoft Teams session is not connected.' -ForegroundColor Yellow
        Write-Host 'Launching Microsoft Teams sign-in...' -ForegroundColor Yellow
        Write-Host ''

        Connect-MicrosoftTeams -ErrorAction Stop | Out-Null
        $null = Get-CsTenant -ErrorAction Stop
        return $true
    }
    catch {
        Write-Host ''
        Write-Host 'Unable to establish Microsoft Teams connection.' -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ''
        return $false
    }
}
