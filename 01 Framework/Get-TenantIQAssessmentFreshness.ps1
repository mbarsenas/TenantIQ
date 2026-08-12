function Get-TenantIQAssessmentFreshness {
    [CmdletBinding()]
    param(
        [string]$OutputPath,
        [int]$FreshHours = 24,
        [int]$StaleHours = 168
    )

    $RootPath = Split-Path $PSScriptRoot -Parent
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path $RootPath '06 Output'
    }

    $Workloads = @(
        [pscustomobject]@{ Name = 'Exchange Online'; Slug = 'ExchangeOnline' },
        [pscustomobject]@{ Name = 'Entra ID'; Slug = 'EntraID' },
        [pscustomobject]@{ Name = 'SharePoint Online'; Slug = 'SharePointOnline' },
        [pscustomobject]@{ Name = 'Microsoft Teams'; Slug = 'MicrosoftTeams' },
        [pscustomobject]@{ Name = 'OneDrive'; Slug = 'OneDrive' },
        [pscustomobject]@{ Name = 'Microsoft Intune'; Slug = 'MicrosoftIntune' },
        [pscustomobject]@{ Name = 'Microsoft Defender'; Slug = 'MicrosoftDefender' },
        [pscustomobject]@{ Name = 'Microsoft Purview'; Slug = 'MicrosoftPurview' }
    )

    $Now = Get-Date
    $Results = foreach ($Workload in $Workloads) {
        $Latest = Get-ChildItem -Path $OutputPath -Filter "TenantIQ-$($Workload.Slug)-Assessment-*.csv" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1

        if (-not $Latest) {
            [pscustomobject]@{
                Workload = $Workload.Name
                File = $null
                LastRun = $null
                AgeHours = $null
                Freshness = 'MISSING'
                Status = 'No assessment found'
            }
            continue
        }

        $AgeHours = [math]::Round(($Now - $Latest.LastWriteTime).TotalHours, 1)
        $Freshness = if ($AgeHours -le $FreshHours) { 'FRESH' }
            elseif ($AgeHours -le $StaleHours) { 'AGING' }
            else { 'STALE' }

        [pscustomobject]@{
            Workload = $Workload.Name
            File = $Latest.Name
            LastRun = $Latest.LastWriteTime
            AgeHours = $AgeHours
            Freshness = $Freshness
            Status = switch ($Freshness) {
                'FRESH' { 'Current' }
                'AGING' { 'Review freshness' }
                'STALE' { 'Rerun recommended' }
            }
        }
    }

    return @($Results)
}
