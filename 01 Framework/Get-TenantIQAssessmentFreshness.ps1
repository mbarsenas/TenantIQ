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

    $WorkloadCheckMaps = @{}
    $RegistryMap = @(
        [pscustomobject]@{ Name = 'Entra ID'; Variable = 'TenantIQEntraHealthChecks'; File = '10 Modules\EntraID.ps1' },
        [pscustomobject]@{ Name = 'SharePoint Online'; Variable = 'TenantIQSharePointHealthChecks'; File = '10 Modules\SharePointOnline.ps1' },
        [pscustomobject]@{ Name = 'Microsoft Teams'; Variable = 'TenantIQTeamsHealthChecks'; File = '10 Modules\MicrosoftTeams.ps1' },
        [pscustomobject]@{ Name = 'OneDrive'; Variable = 'TenantIQOneDriveHealthChecks'; File = '10 Modules\OneDrive.ps1' },
        [pscustomobject]@{ Name = 'Microsoft Intune'; Variable = 'TenantIQIntuneHealthChecks'; File = '10 Modules\MicrosoftIntune.ps1' },
        [pscustomobject]@{ Name = 'Microsoft Defender'; Variable = 'TenantIQDefenderHealthChecks'; File = '10 Modules\MicrosoftDefender.ps1' },
        [pscustomobject]@{ Name = 'Microsoft Purview'; Variable = 'TenantIQPurviewHealthChecks'; File = '10 Modules\MicrosoftPurview.ps1' }
    )

    foreach ($Registry in $RegistryMap) {
        $Names = @()
        $Variable = Get-Variable -Name $Registry.Variable -Scope Global -ErrorAction SilentlyContinue
        if (-not $Variable) {
            $Variable = Get-Variable -Name $Registry.Variable -ErrorAction SilentlyContinue
        }

        if ($Variable -and $Variable.Value) {
            $Names = @($Variable.Value | ForEach-Object { [string]$_.Name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        }
        else {
            $RegistryPath = Join-Path $RootPath $Registry.File
            if (Test-Path $RegistryPath) {
                try {
                    $Text = Get-Content -Path $RegistryPath -Raw -ErrorAction Stop
                    $Names = @([regex]::Matches($Text, 'Name\s*=\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
                }
                catch {}
            }
        }

        $WorkloadCheckMaps[$Registry.Name] = @($Names | Select-Object -Unique)
    }

    $ExchangeRegistry = Join-Path $RootPath '01 Framework\HealthChecks.ps1'
    $ExchangeNames = @()
    if (Test-Path $ExchangeRegistry) {
        try {
            $Text = Get-Content -Path $ExchangeRegistry -Raw -ErrorAction Stop
            $ExchangeNames = @([regex]::Matches($Text, 'Name\s*=\s*"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
        }
        catch {}
    }
    $WorkloadCheckMaps['Exchange Online'] = @($ExchangeNames | Select-Object -Unique)

    $AllCsv = @(
        Get-ChildItem -Path $OutputPath -Filter '*.csv' -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -like 'TenantIQ-*-Assessment-*.csv' -or
            $_.Name -like 'TenantIQ--Assessment-*.csv'
        } |
        Sort-Object LastWriteTime -Descending
    )

    $ClassifiedGeneric = @{}
    foreach ($File in @($AllCsv | Where-Object { $_.Name -like 'TenantIQ--Assessment-*.csv' })) {
        try {
            $Rows = @(Import-Csv -Path $File.FullName -ErrorAction Stop)
        }
        catch {
            continue
        }

        if ($Rows.Count -eq 0) { continue }

        $CsvChecks = @($Rows | ForEach-Object { [string]$_.Check } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        if ($CsvChecks.Count -eq 0) { continue }

        $BestWorkload = $null
        $BestMatches = 0
        $BestRatio = 0.0

        foreach ($Workload in $Workloads) {
            $KnownChecks = @($WorkloadCheckMaps[$Workload.Name])
            if ($KnownChecks.Count -eq 0) { continue }

            $KnownSet = @{}
            foreach ($Known in $KnownChecks) { $KnownSet[$Known.ToLowerInvariant()] = $true }

            $Matches = 0
            foreach ($Check in $CsvChecks) {
                if ($KnownSet.ContainsKey($Check.ToLowerInvariant())) { $Matches++ }
            }

            $Ratio = if ($CsvChecks.Count -gt 0) { $Matches / $CsvChecks.Count } else { 0 }

            if ($Matches -gt $BestMatches -or ($Matches -eq $BestMatches -and $Ratio -gt $BestRatio)) {
                $BestWorkload = $Workload.Name
                $BestMatches = $Matches
                $BestRatio = $Ratio
            }
        }

        # Require meaningful agreement so an unrelated or malformed generic CSV
        # cannot be silently attributed to a workload.
        if ($BestWorkload -and $BestMatches -ge 3 -and $BestRatio -ge 0.25) {
            if (-not $ClassifiedGeneric.ContainsKey($BestWorkload)) {
                $ClassifiedGeneric[$BestWorkload] = @()
            }
            $ClassifiedGeneric[$BestWorkload] += $File
        }
    }

    $Now = Get-Date
    $Results = foreach ($Workload in $Workloads) {
        $Candidates = @(
            $AllCsv |
            Where-Object { $_.Name -like "TenantIQ-$($Workload.Slug)-Assessment-*.csv" }
        )

        if ($ClassifiedGeneric.ContainsKey($Workload.Name)) {
            $Candidates += @($ClassifiedGeneric[$Workload.Name])
        }

        $Latest = @($Candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
        if ($Latest.Count -gt 0) { $Latest = $Latest[0] } else { $Latest = $null }

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
