[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$IncludeOptional
)

$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host '[ERROR] TenantIQ requires PowerShell 7 or later.' -ForegroundColor Red
    Write-Host 'Install PowerShell 7, open pwsh.exe, and run this installer again.' -ForegroundColor Yellow
    exit 1
}

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

Write-Host ''
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '              TenantIQ Prerequisite Installer' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host ('PowerShell : {0}' -f $PSVersionTable.PSVersion) -ForegroundColor Gray
Write-Host ('Scope      : CurrentUser') -ForegroundColor Gray
Write-Host ''

try {
    $NuGet = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
    if (-not $NuGet) {
        Write-Host 'Installing NuGet package provider...' -ForegroundColor Cyan
        Install-PackageProvider -Name NuGet -Scope CurrentUser -Force | Out-Null
    }
} catch {
    Write-Host ('[WARNING] NuGet provider check failed: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
}

try {
    $Gallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($Gallery -and $Gallery.InstallationPolicy -ne 'Trusted') {
        Write-Host 'PowerShell Gallery is not trusted. Module installs may prompt for confirmation.' -ForegroundColor Yellow
    }
} catch {}

function Install-TenantIQModule {
    param(
        [Parameter(Mandatory)][string]$Name,
        [bool]$Required = $true
    )

    $Installed = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
    if ($Installed) {
        Write-Host ('[OK] {0} {1}' -f $Name,$Installed.Version) -ForegroundColor Green
        return
    }

    $Label = if ($Required) { '[INSTALL]' } else { '[OPTIONAL]' }
    Write-Host ("$Label $Name") -ForegroundColor Cyan

    if ($PSCmdlet.ShouldProcess($Name, 'Install PowerShell module for CurrentUser')) {
        try {
            Install-Module -Name $Name -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
            $Installed = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
            if ($Installed) {
                Write-Host ('[OK] Installed {0} {1}' -f $Name,$Installed.Version) -ForegroundColor Green
            } else {
                throw 'Module installation completed but the module was not discoverable.'
            }
        } catch {
            $Color = if ($Required) { 'Red' } else { 'Yellow' }
            Write-Host ('[ERROR] {0}: {1}' -f $Name,$_.Exception.Message) -ForegroundColor $Color
            if ($Required) { $script:InstallFailed = $true }
        }
    }
}

$script:InstallFailed = $false

foreach ($Module in $RequiredModules) {
    Install-TenantIQModule -Name $Module -Required $true
}

if ($IncludeOptional) {
    foreach ($Module in $OptionalModules) {
        Install-TenantIQModule -Name $Module -Required $false
    }
} else {
    Write-Host ''
    Write-Host 'Optional module not installed automatically:' -ForegroundColor DarkGray
    Write-Host '  PnP.PowerShell  (run with -IncludeOptional to install)' -ForegroundColor DarkGray
}

Write-Host ''
if ($script:InstallFailed) {
    Write-Host '[ERROR] One or more required modules could not be installed.' -ForegroundColor Red
    Write-Host 'Resolve the errors above, then run this installer again.' -ForegroundColor Yellow
    exit 2
}

Write-Host '[OK] TenantIQ required PowerShell modules are installed.' -ForegroundColor Green
Write-Host ''
Write-Host 'Next:' -ForegroundColor Cyan
Write-Host '  .\Start-TenantIQ.ps1' -ForegroundColor White
