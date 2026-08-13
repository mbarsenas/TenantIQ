[CmdletBinding()]
param(
    [string]$PackageRoot = $PSScriptRoot,
    [string]$ZipPath,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

function Add-CheckResult {
    param([Parameter(Mandatory)][string]$Name,[Parameter(Mandatory)][bool]$Passed,[string]$Detail='')
    [pscustomobject]@{ Check=$Name; Passed=$Passed; Detail=$Detail }
}

$PackageRoot = (Resolve-Path -Path $PackageRoot -ErrorAction Stop).Path
$Results = New-Object System.Collections.Generic.List[object]

function Test-RequiredFile {
    param([string]$RelativePath)
    $Path = Join-Path $PackageRoot $RelativePath
    $Exists = Test-Path $Path -PathType Leaf
    $Results.Add((Add-CheckResult -Name "File: $RelativePath" -Passed $Exists -Detail $(if($Exists){'Present'}else{'Missing'})))
}

function Test-RequiredDirectory {
    param([string]$RelativePath)
    $Path = Join-Path $PackageRoot $RelativePath
    $Exists = Test-Path $Path -PathType Container
    $Results.Add((Add-CheckResult -Name "Directory: $RelativePath" -Passed $Exists -Detail $(if($Exists){'Present'}else{'Missing'})))
}

if (-not (Test-Path $PackageRoot -PathType Container)) { throw "Package folder was not found: $PackageRoot" }
if ($ZipPath) {
    $ZipPath = (Resolve-Path -Path $ZipPath -ErrorAction Stop).Path
    if (-not (Test-Path $ZipPath -PathType Leaf)) { throw "Package ZIP was not found: $ZipPath" }
}

$CustomerDeliveryPath = Join-Path $PackageRoot 'CUSTOMER-DELIVERY.json'
$CustomerLicensePath = Join-Path $PackageRoot 'TenantIQ-License.json'
$IsCustomerDelivery = (Test-Path $CustomerDeliveryPath -PathType Leaf) -or (Test-Path $CustomerLicensePath -PathType Leaf)
$PackageType = if ($IsCustomerDelivery) { 'Customer Delivery' } else { 'Generic Release' }

$RequiredFiles = @(
    'Start-TenantIQ.ps1','TenantIQ.ps1','TenantIQ.json','TenantIQ-License.template.json','TenantIQ-License-Public.pem',
    'Install-TenantIQPrerequisites.ps1','Get-TenantIQVersion.ps1','Get-TenantIQLicenseStatus.ps1',
    'QUICKSTART.md','CUSTOMER-README.md','CHANGELOG.md','PACKAGE-INFO.json','PACKAGE-SHA256.txt','06 Output\README.txt'
)
if ($IsCustomerDelivery) {
    $RequiredFiles += @('TenantIQ-License.json','CUSTOMER-DELIVERY.json','CUSTOMER-README.txt')
}

$RequiredDirectories = @('00 Runtime','01 Framework','02 Health Checks','03 Reports','04 Scripts','05 Templates','06 Output','07 Assets','10 Modules')
foreach($File in $RequiredFiles){ Test-RequiredFile $File }
foreach($Directory in $RequiredDirectories){ Test-RequiredDirectory $Directory }

if ($IsCustomerDelivery) {
    $Results.Add((Add-CheckResult -Name 'Customer-specific license present' -Passed (Test-Path $CustomerLicensePath -PathType Leaf) -Detail $(if(Test-Path $CustomerLicensePath -PathType Leaf){'TenantIQ-License.json present'}else{'TenantIQ-License.json missing'})))
} else {
    $Results.Add((Add-CheckResult -Name 'Customer-specific license excluded' -Passed (-not (Test-Path $CustomerLicensePath)) -Detail $(if(Test-Path $CustomerLicensePath){'TenantIQ-License.json must not ship in a generic release package.'}else{'No customer-specific license present'})))
}

$PublicKeyPath = Join-Path $PackageRoot 'TenantIQ-License-Public.pem'
$PublicKeyId = ''
if (Test-Path $PublicKeyPath) {
    try {
        $rsa = [System.Security.Cryptography.RSA]::Create()
        try {
            $rsa.ImportFromPem((Get-Content -Path $PublicKeyPath -Raw))
            $PublicBytes = $rsa.ExportSubjectPublicKeyInfo()
            $PublicKeyId = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($PublicBytes)).Substring(0,16)
            $Results.Add((Add-CheckResult -Name 'License public key parses' -Passed $true -Detail ("KeyId={0}" -f $PublicKeyId)))
        }
        finally { $rsa.Dispose() }
    }
    catch {
        $Results.Add((Add-CheckResult -Name 'License public key parses' -Passed $false -Detail $_.Exception.Message))
    }
}

if ($IsCustomerDelivery -and (Test-Path $CustomerLicensePath) -and (Test-Path $PublicKeyPath)) {
    $LicenseTool = Join-Path $PackageRoot 'Get-TenantIQLicenseStatus.ps1'
    if (Test-Path $LicenseTool -PathType Leaf) {
        try {
            $LicenseStatus = & $LicenseTool -LicensePath $CustomerLicensePath -PublicKeyPath $PublicKeyPath 6>$null
            if ($LicenseStatus -is [array]) { $LicenseStatus = $LicenseStatus | Select-Object -Last 1 }
            $Valid = $LicenseStatus -and $LicenseStatus.SignatureValid -and [string]$LicenseStatus.State -eq 'ACTIVE'
            $Detail = if ($LicenseStatus) { "State=$($LicenseStatus.State); SignatureValid=$($LicenseStatus.SignatureValid); LicenseId=$($LicenseStatus.LicenseId)" } else { 'No license status returned.' }
            $Results.Add((Add-CheckResult -Name 'Customer license cryptographically valid' -Passed $Valid -Detail $Detail))
        }
        catch {
            $Results.Add((Add-CheckResult -Name 'Customer license cryptographically valid' -Passed $false -Detail $_.Exception.Message))
        }
    }
}

$PackageInfoPath = Join-Path $PackageRoot 'PACKAGE-INFO.json'
if (Test-Path $PackageInfoPath) {
    try {
        $Info = Get-Content $PackageInfoPath -Raw | ConvertFrom-Json -ErrorAction Stop
        $Results.Add((Add-CheckResult -Name 'Metadata product' -Passed ($Info.Product -eq 'TenantIQ') -Detail [string]$Info.Product))
        $Results.Add((Add-CheckResult -Name 'Metadata version' -Passed ([string]$Info.Version -match '^\d+\.\d+\.\d+$') -Detail [string]$Info.Version))
        $Results.Add((Add-CheckResult -Name 'Metadata controls' -Passed ([int]$Info.Controls -eq 416) -Detail [string]$Info.Controls))
        $Results.Add((Add-CheckResult -Name 'Metadata workloads' -Passed ([int]$Info.Workloads -eq 8) -Detail [string]$Info.Workloads))
        $Results.Add((Add-CheckResult -Name 'Metadata PowerShell minimum' -Passed ([string]$Info.MinimumPowerShell -eq '7.0') -Detail [string]$Info.MinimumPowerShell))
        $Results.Add((Add-CheckResult -Name 'Metadata package type' -Passed ([string]$Info.PackageType -eq 'Customer') -Detail [string]$Info.PackageType))
        $Results.Add((Add-CheckResult -Name 'Metadata licensing mode' -Passed ([string]$Info.LicensingMode -eq 'SignedLicenseVerification') -Detail [string]$Info.LicensingMode))
        $Results.Add((Add-CheckResult -Name 'License key ID matches package metadata' -Passed ($PublicKeyId -and [string]$Info.LicenseKeyId -eq $PublicKeyId) -Detail ("Package={0}; PublicKey={1}" -f $Info.LicenseKeyId,$PublicKeyId)))
        $Results.Add((Add-CheckResult -Name 'License launch enforcement disabled' -Passed (-not [bool]$Info.LicenseEnforcement) -Detail [string]$Info.LicenseEnforcement))
    }
    catch {
        $Results.Add((Add-CheckResult -Name 'PACKAGE-INFO.json parses' -Passed $false -Detail $_.Exception.Message))
    }
}

$TenantIQConfigPath = Join-Path $PackageRoot 'TenantIQ.json'
if ((Test-Path $TenantIQConfigPath) -and (Test-Path $PackageInfoPath)) {
    try {
        $Config = Get-Content $TenantIQConfigPath -Raw | ConvertFrom-Json -ErrorAction Stop
        $Info = Get-Content $PackageInfoPath -Raw | ConvertFrom-Json -ErrorAction Stop
        $Results.Add((Add-CheckResult -Name 'Version metadata consistent' -Passed ([string]$Config.Version -eq [string]$Info.Version) -Detail ("TenantIQ.json={0}; PACKAGE-INFO.json={1}" -f $Config.Version,$Info.Version)))
    }
    catch { $Results.Add((Add-CheckResult -Name 'Version metadata consistent' -Passed $false -Detail $_.Exception.Message)) }
}

$ManifestPath = Join-Path $PackageRoot 'PACKAGE-SHA256.txt'
if (Test-Path $ManifestPath) {
    $ManifestFailures = New-Object System.Collections.Generic.List[string]
    $ManifestLines = Get-Content $ManifestPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    foreach($Line in $ManifestLines){
        if($Line -notmatch '^([A-Fa-f0-9]{64})\s{2}(.+)$'){ $ManifestFailures.Add("Malformed manifest line: $Line"); continue }
        $ExpectedHash=$Matches[1].ToUpperInvariant(); $RelativePath=$Matches[2]; $TargetPath=Join-Path $PackageRoot $RelativePath
        if(-not(Test-Path $TargetPath -PathType Leaf)){ $ManifestFailures.Add("Missing manifest target: $RelativePath"); continue }
        $ActualHash=(Get-FileHash -Path $TargetPath -Algorithm SHA256).Hash.ToUpperInvariant()
        if($ActualHash -ne $ExpectedHash){ $ManifestFailures.Add("Hash mismatch: $RelativePath") }
    }
    $Results.Add((Add-CheckResult -Name 'Package SHA256 manifest' -Passed ($ManifestFailures.Count -eq 0) -Detail $(if($ManifestFailures.Count -eq 0){"$($ManifestLines.Count) files verified"}else{($ManifestFailures -join '; ')})))
}

if ($ZipPath) {
    $ZipHashPath="$ZipPath.sha256"
    $ZipSidecarExists=Test-Path $ZipHashPath -PathType Leaf
    $Results.Add((Add-CheckResult -Name 'ZIP SHA256 sidecar present' -Passed $ZipSidecarExists -Detail $ZipHashPath))
    if($ZipSidecarExists){
        try{
            $HashLine=(Get-Content $ZipHashPath|Select-Object -First 1).Trim()
            if($HashLine -match '^([A-Fa-f0-9]{64})\s{2}(.+)$'){
                $ExpectedZipHash=$Matches[1].ToUpperInvariant(); $ExpectedZipName=$Matches[2]; $ActualZipHash=(Get-FileHash -Path $ZipPath -Algorithm SHA256).Hash.ToUpperInvariant()
                $HashMatches=$ActualZipHash -eq $ExpectedZipHash; $NameMatches=(Split-Path $ZipPath -Leaf) -eq $ExpectedZipName
                $Results.Add((Add-CheckResult -Name 'ZIP SHA256 verifies' -Passed ($HashMatches -and $NameMatches) -Detail ("HashMatch={0}; NameMatch={1}" -f $HashMatches,$NameMatches)))
            } else { $Results.Add((Add-CheckResult -Name 'ZIP SHA256 verifies' -Passed $false -Detail 'Malformed ZIP SHA256 sidecar.')) }
        } catch { $Results.Add((Add-CheckResult -Name 'ZIP SHA256 verifies' -Passed $false -Detail $_.Exception.Message)) }
    }
} else {
    $Results.Add((Add-CheckResult -Name 'ZIP validation' -Passed $true -Detail 'Skipped because -ZipPath was not supplied; extracted package validation only.'))
}

$Failed=@($Results|Where-Object{-not $_.Passed}); $Passed=@($Results|Where-Object{$_.Passed}); $Ready=$Failed.Count -eq 0
if(-not $Quiet){
    Write-Host ''; Write-Host 'TenantIQ Release Package Validation' -ForegroundColor Cyan; Write-Host '===================================' -ForegroundColor Cyan
    Write-Host ("Package Type : {0}" -f $PackageType)
    Write-Host ("Package      : {0}" -f $PackageRoot)
    Write-Host ("ZIP          : {0}" -f $(if($ZipPath){$ZipPath}else{'Not supplied (extracted package validation)'})); Write-Host ''
    foreach($Result in $Results){ $Prefix=if($Result.Passed){'[OK]'}else{'[FAIL]'}; $Color=if($Result.Passed){'Green'}else{'Red'}; Write-Host ("{0} {1}" -f $Prefix,$Result.Check) -ForegroundColor $Color; if(-not[string]::IsNullOrWhiteSpace($Result.Detail)){Write-Host ("     {0}" -f $Result.Detail) -ForegroundColor DarkGray} }
    Write-Host ''; Write-Host ("Passed : {0}" -f $Passed.Count) -ForegroundColor Green; Write-Host ("Failed : {0}" -f $Failed.Count) -ForegroundColor $(if($Failed.Count -eq 0){'Green'}else{'Red'}); Write-Host ("Status : {0}" -f $(if($Ready){'RELEASE READY'}else{'NOT RELEASE READY'})) -ForegroundColor $(if($Ready){'Green'}else{'Red'})
}
$Summary=[pscustomobject]@{Ready=$Ready;Passed=$Passed.Count;Failed=$Failed.Count;PackageType=$PackageType;PackageRoot=$PackageRoot;ZipPath=$ZipPath;Results=$Results}
if(-not $Ready){$Summary;exit 1}
$Summary
