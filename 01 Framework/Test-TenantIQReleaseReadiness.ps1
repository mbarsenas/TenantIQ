function Test-TenantIQReleaseReadiness {
    [CmdletBinding()]
    param(
        [switch]$Quiet
    )

    $RootPath = Split-Path $PSScriptRoot -Parent
    $Checks = @()

    function Add-ReleaseCheck {
        param(
            [string]$Name,
            [bool]$Passed,
            [string]$Detail,
            [string]$Severity = 'Required'
        )

        $script:Checks += [pscustomobject]@{
            Name     = $Name
            Passed   = $Passed
            Detail   = $Detail
            Severity = $Severity
        }
    }

    $RequiredPaths = @(
        'TenantIQ.ps1',
        'Start-TenantIQ.ps1',
        'TenantIQ.json',
        '01 Framework',
        '02 Health Checks',
        '06 Output',
        '10 Modules'
    )

    foreach ($RelativePath in $RequiredPaths) {
        $FullPath = Join-Path $RootPath $RelativePath
        Add-ReleaseCheck -Name "Path: $RelativePath" -Passed (Test-Path $FullPath) -Detail $FullPath
    }

    $ConfigPath = Join-Path $RootPath 'TenantIQ.json'
    $Config = $null
    try {
        $Config = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        Add-ReleaseCheck -Name 'Configuration JSON' -Passed $true -Detail 'TenantIQ.json parsed successfully.'
    }
    catch {
        Add-ReleaseCheck -Name 'Configuration JSON' -Passed $false -Detail $_.Exception.Message
    }

    if ($Config) {
        Add-ReleaseCheck -Name 'Version metadata' -Passed (-not [string]::IsNullOrWhiteSpace([string]$Config.Version)) -Detail ("Version: {0}" -f $Config.Version)
        Add-ReleaseCheck -Name 'Release channel metadata' -Passed (-not [string]::IsNullOrWhiteSpace([string]$Config.ReleaseChannel)) -Detail ("ReleaseChannel: {0}" -f $Config.ReleaseChannel)
    }

    $ExpectedModules = @(
        'EntraID.ps1',
        'SharePointOnline.ps1',
        'MicrosoftTeams.ps1',
        'OneDrive.ps1',
        'MicrosoftIntune.ps1',
        'MicrosoftDefender.ps1',
        'MicrosoftPurview.ps1'
    )

    foreach ($ModuleFile in $ExpectedModules) {
        $ModulePath = Join-Path $RootPath ("10 Modules\{0}" -f $ModuleFile)
        Add-ReleaseCheck -Name "Module registry: $ModuleFile" -Passed (Test-Path $ModulePath) -Detail $ModulePath
    }

    $RequiredFrameworkFunctions = @(
        'Export-TenantIQPortfolioReport',
        'Show-TenantIQPortfolioMenu',
        'Show-TenantIQConfigurationWizard',
        'Test-TenantIQPrerequisites'
    )

    foreach ($FunctionName in $RequiredFrameworkFunctions) {
        $Found = [bool](Get-Command $FunctionName -ErrorAction SilentlyContinue)
        Add-ReleaseCheck -Name "Function: $FunctionName" -Passed $Found -Detail $(if ($Found) { 'Loaded' } else { 'Not loaded' })
    }

    $Failures = @($Checks | Where-Object { -not $_.Passed -and $_.Severity -eq 'Required' })

    if (-not $Quiet) {
        Write-Host ''
        Write-Host 'TenantIQ Release Readiness' -ForegroundColor Cyan
        Write-Host '===========================' -ForegroundColor Cyan
        Write-Host ''

        foreach ($Check in $Checks) {
            if ($Check.Passed) {
                Write-Host ("[OK] {0}" -f $Check.Name) -ForegroundColor Green
            }
            else {
                Write-Host ("[FAIL] {0}" -f $Check.Name) -ForegroundColor Red
                Write-Host ("       {0}" -f $Check.Detail) -ForegroundColor DarkYellow
            }
        }

        Write-Host ''
        if ($Failures.Count -eq 0) {
            Write-Host '[OK] TenantIQ release readiness checks passed.' -ForegroundColor Green
        }
        else {
            Write-Host ("[ERROR] {0} release-readiness check(s) failed." -f $Failures.Count) -ForegroundColor Red
        }
    }

    [pscustomobject]@{
        Ready    = ($Failures.Count -eq 0)
        Failures = $Failures
        Results  = $Checks
    }
}
