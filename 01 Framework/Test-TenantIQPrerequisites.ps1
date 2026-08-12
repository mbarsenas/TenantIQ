function Test-TenantIQPrerequisites {
    [CmdletBinding()]
    param(
        [switch]$Quiet
    )

    $Requirements = @(
        [pscustomobject]@{ Name = 'PowerShell 5+'; Type = 'Runtime'; Required = $true; Test = { $PSVersionTable.PSVersion.Major -ge 5 }; Fix = 'Use Windows PowerShell 5.1 or PowerShell 7+.' },
        [pscustomobject]@{ Name = 'ExchangeOnlineManagement'; Type = 'Module'; Required = $true; Test = { [bool](Get-Module -ListAvailable -Name 'ExchangeOnlineManagement' | Select-Object -First 1) }; Fix = 'Install-Module ExchangeOnlineManagement -Scope CurrentUser' },
        [pscustomobject]@{ Name = 'Microsoft.Graph.Authentication'; Type = 'Module'; Required = $true; Test = { [bool](Get-Module -ListAvailable -Name 'Microsoft.Graph.Authentication' | Select-Object -First 1) }; Fix = 'Install-Module Microsoft.Graph.Authentication -Scope CurrentUser' },
        [pscustomobject]@{ Name = 'Microsoft.Graph.Reports'; Type = 'Module'; Required = $true; Test = { [bool](Get-Module -ListAvailable -Name 'Microsoft.Graph.Reports' | Select-Object -First 1) }; Fix = 'Install-Module Microsoft.Graph.Reports -Scope CurrentUser' },
        [pscustomobject]@{ Name = 'Microsoft.Online.SharePoint.PowerShell'; Type = 'Module'; Required = $true; Test = { [bool](Get-Module -ListAvailable -Name 'Microsoft.Online.SharePoint.PowerShell' | Select-Object -First 1) }; Fix = 'Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser' },
        [pscustomobject]@{ Name = 'MicrosoftTeams'; Type = 'Module'; Required = $true; Test = { [bool](Get-Module -ListAvailable -Name 'MicrosoftTeams' | Select-Object -First 1) }; Fix = 'Install-Module MicrosoftTeams -Scope CurrentUser' },
        [pscustomobject]@{ Name = 'PnP.PowerShell'; Type = 'Module'; Required = $false; Test = { [bool](Get-Module -ListAvailable -Name 'PnP.PowerShell' | Select-Object -First 1) }; Fix = 'Optional: Install-Module PnP.PowerShell -Scope CurrentUser' }
    )

    $Results = foreach ($Requirement in $Requirements) {
        $Available = $false
        try { $Available = [bool](& $Requirement.Test) } catch { $Available = $false }

        [pscustomobject]@{
            Name       = $Requirement.Name
            Type       = $Requirement.Type
            Required   = $Requirement.Required
            Available  = $Available
            Status     = if ($Available) { 'PASS' } elseif ($Requirement.Required) { 'FAIL' } else { 'INFO' }
            Remediation = $Requirement.Fix
        }
    }

    $RequiredMissing = @($Results | Where-Object { $_.Required -eq $true -and $_.Available -eq $false })
    $OptionalMissing = @($Results | Where-Object { $_.Required -eq $false -and $_.Available -eq $false })

    if (-not $Quiet) {
        Write-Host ''
        Write-Host 'TenantIQ Environment Validation' -ForegroundColor Cyan
        Write-Host '===============================' -ForegroundColor Cyan
        Write-Host ''

        foreach ($Result in $Results) {
            $Color = switch ($Result.Status) {
                'PASS' { 'Green' }
                'FAIL' { 'Red' }
                default { 'Yellow' }
            }

            $Label = switch ($Result.Status) {
                'PASS' { '[OK]' }
                'FAIL' { '[MISSING]' }
                default { '[OPTIONAL]' }
            }

            Write-Host ('{0} {1}' -f $Label,$Result.Name) -ForegroundColor $Color
        }

        Write-Host ''
        if ($RequiredMissing.Count -eq 0) {
            Write-Host '[OK] Required environment checks passed.' -ForegroundColor Green
        }
        else {
            Write-Host ('[ERROR] {0} required prerequisite(s) are missing.' -f $RequiredMissing.Count) -ForegroundColor Red
            Write-Host ''
            Write-Host 'Required actions:' -ForegroundColor Yellow
            foreach ($Missing in $RequiredMissing) {
                Write-Host ('  - {0}' -f $Missing.Remediation) -ForegroundColor Yellow
            }
        }

        if ($OptionalMissing.Count -gt 0) {
            Write-Host ''
            Write-Host ('[INFO] {0} optional component(s) are not installed. TenantIQ can still start.' -f $OptionalMissing.Count) -ForegroundColor Yellow
        }
    }

    [pscustomobject]@{
        Ready           = ($RequiredMissing.Count -eq 0)
        RequiredMissing = $RequiredMissing
        OptionalMissing = $OptionalMissing
        Results         = $Results
    }
}
