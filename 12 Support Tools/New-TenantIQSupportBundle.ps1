[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Support Bundles'),
    [switch]$IncludeTenantAccess,
    [switch]$IncludeRecentAssessmentOutput
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "TenantIQ-Support-$timestamp"
$workRoot = Join-Path ([IO.Path]::GetTempPath()) $bundleName
$zipPath = Join-Path $OutputDirectory "$bundleName.zip"

function Invoke-CapturedTool {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$OutputPath
    )

    $tool = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path $tool -PathType Leaf)) {
        "Tool not found: $RelativePath" | Set-Content -LiteralPath $OutputPath -Encoding utf8
        return
    }

    try {
        & $tool *>&1 | Out-String -Width 240 | Set-Content -LiteralPath $OutputPath -Encoding utf8
    }
    catch {
        @(
            "Tool: $RelativePath"
            "Status: ERROR"
            "Message: $($_.Exception.Message)"
        ) | Set-Content -LiteralPath $OutputPath -Encoding utf8
    }
}

function Get-SafeEnvironmentStatus {
    $names = @(
        'TENANTIQ_RAG_API',
        'TENANTIQ_SITE_URL',
        'DATABASE_URL',
        'STRIPE_SECRET_KEY',
        'TENANTIQ_FULFILLMENT_API_KEY',
        'TENANTIQ_R2_ACCOUNT_ID',
        'TENANTIQ_R2_ACCESS_KEY_ID',
        'TENANTIQ_R2_SECRET_ACCESS_KEY',
        'TENANTIQ_LICENSE_PRIVATE_KEY_PATH'
    )

    foreach ($name in $names) {
        $value = [Environment]::GetEnvironmentVariable($name)
        [pscustomobject]@{
            Variable = $name
            Status   = if ([string]::IsNullOrWhiteSpace($value)) { 'Missing' } else { 'Configured' }
        }
    }
}

New-Item -ItemType Directory -Path $workRoot -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

try {
    $summaryPath = Join-Path $workRoot 'SUMMARY.txt'
    @(
        'TenantIQ Support Bundle'
        '======================='
        "Created       : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
        "Computer      : $env:COMPUTERNAME"
        "User          : $env:USERNAME"
        "PowerShell    : $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)"
        "OS            : $([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)"
        "Repository    : $RepoRoot"
        "Tenant Access : $(if ($IncludeTenantAccess) { 'Included' } else { 'Not run (use -IncludeTenantAccess to opt in)' })"
        "Assessment CSV: $(if ($IncludeRecentAssessmentOutput) { 'Latest files included' } else { 'Not included' })"
        ''
        'SECURITY NOTE: Secret values are intentionally not collected. Environment variables are recorded only as Configured/Missing.'
    ) | Set-Content -LiteralPath $summaryPath -Encoding utf8

    $configPath = Join-Path $RepoRoot 'TenantIQ.json'
    if (Test-Path $configPath -PathType Leaf) {
        try {
            $config = Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json
            [pscustomobject]@{
                Name           = $config.Name
                Version        = $config.Version
                ReleaseChannel = $config.ReleaseChannel
                Description    = $config.Description
            } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $workRoot 'TenantIQ-Version.json') -Encoding utf8
        }
        catch {
            "Unable to parse TenantIQ.json: $($_.Exception.Message)" | Set-Content -LiteralPath (Join-Path $workRoot 'TenantIQ-Version.txt') -Encoding utf8
        }
    }

    Get-SafeEnvironmentStatus | Format-Table -AutoSize | Out-String -Width 200 |
        Set-Content -LiteralPath (Join-Path $workRoot 'Environment-Status.txt') -Encoding utf8

    $gitPath = Join-Path $workRoot 'Git-State.txt'
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Push-Location $RepoRoot
        try {
            @(
                'git status --short --branch'
                (git status --short --branch 2>&1 | Out-String)
                'git log -5 --oneline --decorate'
                (git log -5 --oneline --decorate 2>&1 | Out-String)
            ) | Set-Content -LiteralPath $gitPath -Encoding utf8
        }
        finally { Pop-Location }
    }
    else {
        'git is not available in PATH.' | Set-Content -LiteralPath $gitPath -Encoding utf8
    }

    Get-Module -ListAvailable |
        Sort-Object Name, Version -Descending |
        Select-Object Name, Version, Path |
        Format-Table -AutoSize | Out-String -Width 240 |
        Set-Content -LiteralPath (Join-Path $workRoot 'PowerShell-Modules.txt') -Encoding utf8

    Invoke-CapturedTool -RelativePath 'Get-TenantIQVersion.ps1' -OutputPath (Join-Path $workRoot 'TenantIQ-Version-Command.txt')
    Invoke-CapturedTool -RelativePath 'Get-TenantIQLicenseStatus.ps1' -OutputPath (Join-Path $workRoot 'TenantIQ-License-Status.txt')
    Invoke-CapturedTool -RelativePath 'Test-TenantIQPrerequisites.ps1' -OutputPath (Join-Path $workRoot 'Prerequisite-Check.txt')

    if ($IncludeTenantAccess) {
        Invoke-CapturedTool -RelativePath 'Test-TenantIQTenantAccess.ps1' -OutputPath (Join-Path $workRoot 'Tenant-Access-Check.txt')
    }

    $outputRoot = Join-Path $RepoRoot '06 Output'
    if (Test-Path $outputRoot -PathType Container) {
        $recent = Get-ChildItem -LiteralPath $outputRoot -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 30 Name, Length, LastWriteTime
        $recent | Format-Table -AutoSize | Out-String -Width 220 |
            Set-Content -LiteralPath (Join-Path $workRoot 'Recent-Output-Inventory.txt') -Encoding utf8

        if ($IncludeRecentAssessmentOutput) {
            $assessmentDir = Join-Path $workRoot 'Recent Assessment Output'
            New-Item -ItemType Directory -Path $assessmentDir -Force | Out-Null
            Get-ChildItem -LiteralPath $outputRoot -File -Filter 'TenantIQ-*-Assessment-*.csv' -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Group-Object { if ($_.Name -match '^TenantIQ-(.+?)-Assessment-') { $matches[1] } else { $_.Name } } |
                ForEach-Object { $_.Group | Select-Object -First 1 } |
                Copy-Item -Destination $assessmentDir -Force
        }
    }

    $runtimeRoot = Join-Path $RepoRoot '00 Runtime'
    if (Test-Path $runtimeRoot -PathType Container) {
        Get-ChildItem -LiteralPath $runtimeRoot -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 30 Name, Length, LastWriteTime |
            Format-Table -AutoSize | Out-String -Width 220 |
            Set-Content -LiteralPath (Join-Path $workRoot 'Runtime-File-Inventory.txt') -Encoding utf8
    }

    if (Test-Path $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Compress-Archive -Path (Join-Path $workRoot '*') -DestinationPath $zipPath -CompressionLevel Optimal

    Write-Host ''
    Write-Host '[OK] TenantIQ support bundle created.' -ForegroundColor Green
    Write-Host "ZIP: $zipPath" -ForegroundColor Green
    Write-Host ''
    Write-Host 'Secret values were not collected.' -ForegroundColor Cyan

    [pscustomobject]@{
        BundlePath = $zipPath
        CreatedAt = Get-Date
        IncludedTenantAccess = [bool]$IncludeTenantAccess
        IncludedAssessmentOutput = [bool]$IncludeRecentAssessmentOutput
    }
}
finally {
    if (Test-Path $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
