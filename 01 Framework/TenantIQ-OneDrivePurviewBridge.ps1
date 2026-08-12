# TenantIQ OneDrive -> Purview isolated evidence bridge
# Loaded after Invoke-TenantIQOneDriveHardenedCheck.ps1 so this definition
# intentionally replaces the legacy in-process Get-TenantIQOneDrivePurviewData.

if (-not (Get-Variable TenantIQOneDrivePurviewCache -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:TenantIQOneDrivePurviewCache = $null
}

function Get-TenantIQOneDrivePurviewCachePath {
    $Runtime = Join-Path (Split-Path $PSScriptRoot -Parent) '00 Runtime'
    if (-not (Test-Path $Runtime)) {
        $null = New-Item -Path $Runtime -ItemType Directory -Force
    }

    return (Join-Path $Runtime 'OneDrive-Purview-Evidence.json')
}

function Get-TenantIQOneDrivePurviewCache {
    if ($Global:TenantIQOneDrivePurviewCache) {
        return $Global:TenantIQOneDrivePurviewCache
    }

    $CachePath = Get-TenantIQOneDrivePurviewCachePath
    $Collector = Join-Path (Split-Path $PSScriptRoot -Parent) '00 Runtime\Tools\Invoke-TenantIQOneDrivePurviewCache.ps1'

    if (-not (Test-Path $Collector)) {
        throw "OneDrive isolated Purview collector not found: $Collector"
    }

    $Shell = $null
    if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
        $Shell = (Get-Command pwsh.exe).Source
    }
    elseif (Get-Command powershell.exe -ErrorAction SilentlyContinue) {
        $Shell = (Get-Command powershell.exe).Source
    }
    else {
        throw 'No PowerShell executable is available for isolated Purview collection.'
    }

    if (Test-Path $CachePath) {
        Remove-Item $CachePath -Force -ErrorAction SilentlyContinue
    }

    Write-Host ''
    Write-Host 'Preparing isolated Microsoft Purview evidence for OneDrive...' -ForegroundColor Cyan
    Write-Host 'Purview runs in a separate PowerShell process to avoid MSAL assembly conflicts.' -ForegroundColor DarkGray
    Write-Host 'You should be prompted for Purview authentication only once during this OneDrive assessment.' -ForegroundColor DarkGray
    Write-Host ''

    $Args = @(
        '-NoProfile',
        '-ExecutionPolicy','Bypass',
        '-File',"`"$Collector`"",
        '-OutputPath',"`"$CachePath`""
    )

    $Process = Start-Process -FilePath $Shell -ArgumentList ($Args -join ' ') -Wait -PassThru

    if (-not (Test-Path $CachePath)) {
        throw "The isolated Purview collector did not create its evidence cache. Exit code: $($Process.ExitCode)"
    }

    $Cache = Get-Content $CachePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($Cache.Success -ne $true) {
        throw "Isolated Purview collection failed. $($Cache.Error)"
    }

    $Global:TenantIQOneDrivePurviewCache = $Cache

    Write-Host '[OK] OneDrive Purview evidence collected and cached for this assessment.' -ForegroundColor Green
    Write-Host ''

    return $Global:TenantIQOneDrivePurviewCache
}

function Get-TenantIQOneDrivePurviewData {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DLP','Retention','Cases','InformationBarriers')]
        [string]$Type
    )

    $Cache = Get-TenantIQOneDrivePurviewCache
    $Bucket = $Cache.$Type

    if ($null -eq $Bucket) {
        throw "Purview evidence bucket '$Type' was not returned by the isolated collector."
    }

    if ($Bucket.Available -ne $true) {
        $Detail = if ($Bucket.Error) { $Bucket.Error } else { 'The required Purview command was unavailable.' }
        throw "Purview $Type evidence is unavailable. $Detail"
    }

    return @($Bucket.Data)
}
