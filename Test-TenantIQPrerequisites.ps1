[CmdletBinding()]
param(
    [switch]$IncludeOptional
)

$ErrorActionPreference = 'SilentlyContinue'

$RequiredModules = @(
    'ExchangeOnlineManagement',
    'Microsoft.Graph.Authentication',
    'Microsoft.Graph.Reports',
    'Microsoft.Graph.Users',
    'Microsoft.Graph.Groups',
    'Microsoft.Graph.Applications',
    'Microsoft.Graph.Identity.SignIns',
    'Microsoft.Graph.Identity.Governance',
    'Microsoft.Graph.Identity.DirectoryManagement',
    'Microsoft.Online.SharePoint.PowerShell',
    'MicrosoftTeams'
)

$OptionalModules = @('PnP.PowerShell')
$Results = New-Object System.Collections.Generic.List[object]

function Add-TenantIQPrecheckResult {
    param(
        [string]$Item,
        [string]$Status,
        [string]$Detected = '',
        [string]$Needed = '',
        [string]$Fix = ''
    )

    $Results.Add([pscustomobject]@{
        Item     = $Item
        Status   = $Status
        Detected = $Detected
        Needed   = $Needed
        Fix      = $Fix
    }) | Out-Null
}

Write-Host ''
Write-Host 'TenantIQ Troubleshooting Pre-Check' -ForegroundColor Cyan
Write-Host '==================================' -ForegroundColor Cyan
Write-Host ''

$PowerShellVersion = $PSVersionTable.PSVersion.ToString()
$PowerShellOk = $PSVersionTable.PSVersion.Major -ge 7
Add-TenantIQPrecheckResult -Item 'PowerShell' -Status $(if ($PowerShellOk) { 'OK' } else { 'MISSING' }) -Detected $PowerShellVersion -Needed '7.0 or later' -Fix $(if ($PowerShellOk) { '' } else { 'Install PowerShell 7 and run this script from pwsh.exe.' })

$ExecutionPolicy = Get-ExecutionPolicy -Scope CurrentUser
if (-not $ExecutionPolicy) { $ExecutionPolicy = Get-ExecutionPolicy }
$ExecutionPolicyOk = $ExecutionPolicy -notin @('Restricted','AllSigned')
Add-TenantIQPrecheckResult -Item 'Execution Policy' -Status $(if ($ExecutionPolicyOk) { 'OK' } else { 'REVIEW' }) -Detected ([string]$ExecutionPolicy) -Needed 'Allows local TenantIQ scripts to run' -Fix $(if ($ExecutionPolicyOk) { '' } else { 'Use pwsh -ExecutionPolicy Bypass for troubleshooting, or review your organization policy.' })

$Gallery = Get-PSRepository -Name PSGallery
$GalleryOk = $null -ne $Gallery
Add-TenantIQPrecheckResult -Item 'PowerShell Gallery' -Status $(if ($GalleryOk) { 'OK' } else { 'MISSING' }) -Detected $(if ($GalleryOk) { "Registered ($($Gallery.InstallationPolicy))" } else { 'Not registered' }) -Needed 'PSGallery available for module installation' -Fix $(if ($GalleryOk) { '' } else { 'Run Register-PSRepository -Default from an elevated PowerShell session if your organization permits it.' })

$NuGet = Get-PackageProvider -Name NuGet | Sort-Object Version -Descending | Select-Object -First 1
$NuGetOk = $null -ne $NuGet
Add-TenantIQPrecheckResult -Item 'NuGet Provider' -Status $(if ($NuGetOk) { 'OK' } else { 'MISSING' }) -Detected $(if ($NuGetOk) { [string]$NuGet.Version } else { 'Not installed' }) -Needed 'NuGet package provider' -Fix $(if ($NuGetOk) { '' } else { 'Run Install-PackageProvider -Name NuGet -Scope CurrentUser -Force.' })

foreach ($ModuleName in $RequiredModules) {
    $Module = Get-Module -ListAvailable -Name $ModuleName | Sort-Object Version -Descending | Select-Object -First 1
    $Installed = $null -ne $Module
    Add-TenantIQPrecheckResult -Item $ModuleName -Status $(if ($Installed) { 'OK' } else { 'MISSING' }) -Detected $(if ($Installed) { [string]$Module.Version } else { 'Not installed' }) -Needed 'Required' -Fix $(if ($Installed) { '' } else { "Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber" })
}

if ($IncludeOptional) {
    foreach ($ModuleName in $OptionalModules) {
        $Module = Get-Module -ListAvailable -Name $ModuleName | Sort-Object Version -Descending | Select-Object -First 1
        $Installed = $null -ne $Module
        Add-TenantIQPrecheckResult -Item $ModuleName -Status $(if ($Installed) { 'OK' } else { 'OPTIONAL' }) -Detected $(if ($Installed) { [string]$Module.Version } else { 'Not installed' }) -Needed 'Optional' -Fix $(if ($Installed) { '' } else { "Install-Module -Name $ModuleName -Scope CurrentUser -Force -AllowClobber" })
    }
}

$LauncherPath = Join-Path $PSScriptRoot 'Start-TenantIQ.ps1'
$LauncherOk = Test-Path $LauncherPath -PathType Leaf
Add-TenantIQPrecheckResult -Item 'TenantIQ Launcher' -Status $(if ($LauncherOk) { 'OK' } else { 'MISSING' }) -Detected $(if ($LauncherOk) { $LauncherPath } else { 'Start-TenantIQ.ps1 not found' }) -Needed 'Required' -Fix $(if ($LauncherOk) { '' } else { 'Run the pre-check from the TenantIQ package root.' })

$RequiredFailures = @($Results | Where-Object { $_.Needed -eq 'Required' -and $_.Status -ne 'OK' })
$EnvironmentFailures = @($Results | Where-Object { $_.Item -in @('PowerShell','PowerShell Gallery','NuGet Provider','TenantIQ Launcher') -and $_.Status -ne 'OK' })
$ReviewItems = @($Results | Where-Object { $_.Status -eq 'REVIEW' })

foreach ($Result in $Results) {
    $Color = switch ($Result.Status) {
        'OK'       { 'Green' }
        'OPTIONAL' { 'DarkGray' }
        'REVIEW'   { 'Yellow' }
        default    { 'Red' }
    }

    Write-Host ('[{0}] {1}' -f $Result.Status,$Result.Item) -ForegroundColor $Color
    Write-Host ('     Detected : {0}' -f $Result.Detected) -ForegroundColor DarkGray
    if ($Result.Fix) {
        Write-Host ('     Fix      : {0}' -f $Result.Fix) -ForegroundColor Yellow
    }
}

Write-Host ''
Write-Host 'Summary' -ForegroundColor Cyan
Write-Host '-------' -ForegroundColor Cyan
Write-Host ('PowerShell        : {0}' -f $PowerShellVersion)
Write-Host ('Required modules  : {0}/{1} installed' -f ($RequiredModules.Count - $RequiredFailures.Count),$RequiredModules.Count)
Write-Host ('Review items      : {0}' -f $ReviewItems.Count)
Write-Host ''

$Ready = ($RequiredFailures.Count -eq 0 -and $EnvironmentFailures.Count -eq 0)
if ($Ready) {
    Write-Host '[READY] This computer has the TenantIQ prerequisites needed to start troubleshooting.' -ForegroundColor Green
    Write-Host 'Launch TenantIQ with:' -ForegroundColor Cyan
    Write-Host '  .\Start-TenantIQ.ps1' -ForegroundColor White
}
else {
    Write-Host '[NOT READY] One or more TenantIQ prerequisites are missing.' -ForegroundColor Red
    Write-Host ''
    Write-Host 'Fastest remediation:' -ForegroundColor Cyan
    Write-Host '  .\Install-TenantIQPrerequisites.ps1' -ForegroundColor White
}

Write-Host ''
Write-Host 'Detailed object output:' -ForegroundColor DarkGray
$Results | Format-Table Item,Status,Detected,Needed -AutoSize

[pscustomobject]@{
    Ready = $Ready
    PowerShellVersion = $PowerShellVersion
    RequiredModulesInstalled = $RequiredModules.Count - $RequiredFailures.Count
    RequiredModulesTotal = $RequiredModules.Count
    ReviewItems = $ReviewItems.Count
    Results = $Results
}
