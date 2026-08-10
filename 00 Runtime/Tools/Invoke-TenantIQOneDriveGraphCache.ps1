param(
    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

function Write-CollectorResult {
    param($Payload)
    $Payload | ConvertTo-Json -Depth 40 | Set-Content -Path $OutputPath -Encoding UTF8
}

try {
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

    $Scopes = @(
        "User.Read.All",
        "Directory.Read.All",
        "Organization.Read.All",
        "Policy.Read.All",
        "AuditLog.Read.All",
        "DeviceManagementManagedDevices.Read.All"
    )

    Connect-MgGraph -Scopes $Scopes -ContextScope Process -NoWelcome -ErrorAction Stop

    function Get-GraphCollection {
        param([string]$Uri)
        $All = @()
        do {
            $R = Invoke-MgGraphRequest -Method GET -Uri $Uri -ErrorAction Stop
            if ($R.value) { $All += @($R.value) } else { $All += @($R) }
            $Uri = $R.'@odata.nextLink'
        } while ($Uri)
        return $All
    }

    $Users = @(Get-GraphCollection "/v1.0/users?`$select=id,userPrincipalName,accountEnabled,userType,assignedLicenses&`$top=999")
    $Devices = @()
    try {
        $Devices = @(Get-GraphCollection "/v1.0/deviceManagement/managedDevices?`$select=id,deviceName,operatingSystem,complianceState&`$top=999")
    } catch {}

    $CAPolicies = @()
    try {
        $CAPolicies = @(Get-GraphCollection "/v1.0/identity/conditionalAccess/policies?`$top=999")
    } catch {}

    $AuthPolicy = $null
    try {
        $AuthPolicy = Invoke-MgGraphRequest -Method GET -Uri "/v1.0/policies/authenticationMethodsPolicy" -ErrorAction Stop
    } catch {}

    $Org = @()
    try {
        $Org = @(Get-GraphCollection "/v1.0/organization?`$select=id,displayName,verifiedDomains")
    } catch {}

    $SubscribedSkus = @()
    try {
        $SubscribedSkus = @(Get-GraphCollection "/v1.0/subscribedSkus")
    } catch {}

    Write-CollectorResult ([ordered]@{
        Success = $true
        Error = $null
        GeneratedAt = (Get-Date).ToString("o")
        Account = (Get-MgContext).Account
        Users = $Users
        ManagedDevices = $Devices
        ConditionalAccessPolicies = $CAPolicies
        AuthenticationMethodsPolicy = $AuthPolicy
        Organization = $Org
        SubscribedSkus = $SubscribedSkus
    })
    exit 0
}
catch {
    Write-CollectorResult ([ordered]@{
        Success = $false
        Error = $_.Exception.Message
        GeneratedAt = (Get-Date).ToString("o")
    })
    exit 1
}
