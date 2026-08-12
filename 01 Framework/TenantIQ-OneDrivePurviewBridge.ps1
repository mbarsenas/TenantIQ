# TenantIQ OneDrive -> Purview isolated evidence bridge
# Purview evidence is collected at most once per OneDrive assessment.

if (-not (Get-Variable TenantIQOneDrivePurviewCache -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:TenantIQOneDrivePurviewCache = $null
}
if (-not (Get-Variable TenantIQOneDrivePurviewAttempted -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:TenantIQOneDrivePurviewAttempted = $false
}
if (-not (Get-Variable TenantIQOneDrivePurviewError -Scope Global -ErrorAction SilentlyContinue)) {
    $Global:TenantIQOneDrivePurviewError = $null
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

    if ($Global:TenantIQOneDrivePurviewAttempted) {
        $Detail = if ($Global:TenantIQOneDrivePurviewError) { $Global:TenantIQOneDrivePurviewError } else { 'Purview evidence collection was already attempted during this assessment.' }
        throw $Detail
    }

    $Global:TenantIQOneDrivePurviewAttempted = $true
    $CachePath = Get-TenantIQOneDrivePurviewCachePath
    $Collector = Join-Path (Split-Path $PSScriptRoot -Parent) '00 Runtime\Tools\Invoke-TenantIQOneDrivePurviewCache.ps1'

    try {
        if (-not (Test-Path $Collector)) {
            throw "OneDrive isolated Purview collector not found: $Collector"
        }

        $Shell = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
            (Get-Command pwsh.exe).Source
        }
        elseif (Get-Command powershell.exe -ErrorAction SilentlyContinue) {
            (Get-Command powershell.exe).Source
        }
        else {
            $null
        }

        if (-not $Shell) {
            throw 'No PowerShell executable is available for isolated Purview collection.'
        }

        if (Test-Path $CachePath) {
            Remove-Item $CachePath -Force -ErrorAction SilentlyContinue
        }

        Write-Host ''
        Write-Host 'Preparing isolated Microsoft Purview evidence for OneDrive...' -ForegroundColor Cyan
        Write-Host 'Purview authentication will be requested once for this assessment.' -ForegroundColor DarkGray
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

        # Purview cmdlet objects can serialize properties whose names differ only
        # by case (for example Value/value). PowerShell's default PSCustomObject
        # conversion rejects those documents. -AsHashtable preserves the keys.
        $Cache = Get-Content $CachePath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        if ($Cache['Success'] -ne $true) {
            throw "Isolated Purview collection failed. $($Cache['Error'])"
        }

        $Global:TenantIQOneDrivePurviewCache = $Cache
        $Global:TenantIQOneDrivePurviewError = $null

        Write-Host '[OK] OneDrive Purview evidence collected and cached.' -ForegroundColor Green
        Write-Host ''

        return $Global:TenantIQOneDrivePurviewCache
    }
    catch {
        $Global:TenantIQOneDrivePurviewError = $_.Exception.Message
        throw
    }
}

function Get-TenantIQOneDrivePurviewData {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('DLP','Retention','Cases','InformationBarriers')]
        [string]$Type
    )

    $Cache = Get-TenantIQOneDrivePurviewCache
    $Bucket = $Cache[$Type]

    if ($null -eq $Bucket) {
        throw "Purview evidence bucket '$Type' was not returned by the isolated collector."
    }

    if ($Bucket['Available'] -ne $true) {
        $Detail = if ($Bucket['Error']) { $Bucket['Error'] } else { 'The required Purview command was unavailable.' }
        throw "Purview $Type evidence is unavailable. $Detail"
    }

    return @($Bucket['Data'])
}
