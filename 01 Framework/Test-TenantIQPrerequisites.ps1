function Test-TenantIQPrerequisites {
    [CmdletBinding()]
    param(
        [switch]$Quiet
    )

    $Requirements = @(
        [pscustomobject]@{ Name = 'PowerShell'; Type = 'Runtime'; Required = $true; Test = { $PSVersionTable.PSVersion.Major -ge 5 } },
        [pscustomobject]@{ Name = 'ExchangeOnlineManagement'; Type = 'Module'; Required = $true; Test = { [bool](Get-Module -ListAvailable -Name 'ExchangeOnlineManagement' | Select-Object -First 1) } },
        [pscustomobject]@{ Name = 'Microsoft.Graph.Authentication'; Type = 'Module'; Required = $true; Test = { [bool](Get-Module -ListAvailable -Name 'Microsoft.Graph.Authentication' | Select-Object -First 1) } },
        [pscustomobject]@{ Name = 'Microsoft.Graph.Reports'; Type = 'Module'; Required = $true; Test = { [bool](Get-Module -ListAvailable -Name 'Microsoft.Graph.Reports' | Select-Object -First 1) } },
        [pscustomobject]@{ Name = 'Microsoft.Online.SharePoint.PowerShell'; Type = 'Module'; Required = $true; Test = { [bool](Get-Module -ListAvailable -Name 'Microsoft.Online.SharePoint.PowerShell' | Select-Object -First 1) } },
        [pscustomobject]@{ Name = 'MicrosoftTeams'; Type = 'Module'; Required = $true; Test = { [bool](Get-Module -ListAvailable -Name 'MicrosoftTeams' | Select-Object -First 1) } },
        [pscustomobject]@{ Name = 'PnP.PowerShell'; Type = 'Module'; Required = $false; Test = { [bool](Get-Module -ListAvailable -Name 'PnP.PowerShell' | Select-Object -First 1) } }
    )

    $Results = foreach ($Requirement in $Requirements) {
        $Available = $false
        try { $Available = [bool](& $Requirement.Test) } catch { $Available = $false }

        [pscustomobject]@{
            Name      = $Requirement.Name
            Type      = $Requirement.Type
            Required  = $Requirement.Required
            Available = $Available
            Status    = if ($Available) { 'PASS' } elseif ($Requirement.Required) { 'FAIL' } else { 'INFO' }
        }
    }

    $RequiredMissing = @($Results | Where-Object { $_.Required -eq $true -and $_.Available -eq $false })

    if (-not $Quiet) {
        Write-Host ''
        Write-Host 'TenantIQ Prerequisite Check' -ForegroundColor Cyan
        Write-Host '===========================' -ForegroundColor Cyan
        Write-Host ''

        foreach ($Result in $Results) {
            $Color = switch ($Result.Status) {
                'PASS' { 'Green' }
                'FAIL' { 'Red' }
                default { 'Yellow' }
            }
            Write-Host ('[{0}] {1}' -f $Result.Status,$Result.Name) -ForegroundColor $Color
        }

        Write-Host ''
        if ($RequiredMissing.Count -eq 0) {
            Write-Host '[OK] All required TenantIQ prerequisites are available.' -ForegroundColor Green
        }
        else {
            Write-Host ('[ERROR] {0} required prerequisite(s) are missing.' -f $RequiredMissing.Count) -ForegroundColor Red
        }
    }

    [pscustomobject]@{
        Ready          = ($RequiredMissing.Count -eq 0)
        RequiredMissing = $RequiredMissing
        Results        = $Results
    }
}
