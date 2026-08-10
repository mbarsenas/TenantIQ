param(
    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

function Write-GraphCollectorError {
    param([string]$Message)
    $ErrorPayload = [ordered]@{
        Success = $false
        Error   = $Message
        GeneratedAt = (Get-Date).ToString("o")
    }
    $ErrorPayload | ConvertTo-Json -Depth 12 | Set-Content -Path $OutputPath -Encoding UTF8
}

try {
    # Important: this script intentionally runs in a clean child process.
    # Do not import ExchangeOnlineManagement, MicrosoftTeams, or SharePoint here.
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

    $RequiredScopes = @(
        "Group.Read.All",
        "Directory.Read.All",
        "Policy.Read.All",
        "DeviceManagementManagedDevices.Read.All"
    )

    $Context = Get-MgContext -ErrorAction SilentlyContinue
    $NeedConnect = $true

    if ($Context) {
        $NeedConnect = $false
        foreach ($Scope in $RequiredScopes) {
            if ($Scope -notin @($Context.Scopes)) {
                $NeedConnect = $true
                break
            }
        }
    }

    if ($NeedConnect) {
        Connect-MgGraph `
            -Scopes $RequiredScopes `
            -ContextScope CurrentUser `
            -NoWelcome `
            -ErrorAction Stop
    }

    function Get-GraphCollection {
        param([Parameter(Mandatory)][string]$Uri)

        $Response = Invoke-MgGraphRequest -Method GET -Uri $Uri -ErrorAction Stop

        if ($Response.PSObject.Properties["value"]) {
            return @($Response.value)
        }

        return @($Response)
    }

    $TeamsGroups = @(
        Get-GraphCollection -Uri "/v1.0/groups?`$filter=resourceProvisioningOptions/Any(x:x eq 'Team')&`$select=id,displayName,renewedDateTime,createdDateTime,assignedLabels&`$top=999"
    )

    $LifecyclePolicies = @()
    try {
        $LifecyclePolicies = @(Get-GraphCollection -Uri "/v1.0/groupLifecyclePolicies")
    }
    catch {}

    $ManagedDevices = @()
    try {
        $ManagedDevices = @(
            Get-GraphCollection -Uri "/v1.0/deviceManagement/managedDevices?`$select=id,deviceName,operatingSystem,complianceState&`$top=999"
        )
    }
    catch {}

    $CrossTenantDefault = $null
    try {
        $CrossTenantDefault = Invoke-MgGraphRequest `
            -Method GET `
            -Uri "/v1.0/policies/crossTenantAccessPolicy/default" `
            -ErrorAction Stop
    }
    catch {}

    $Payload = [ordered]@{
        Success            = $true
        Error              = $null
        GeneratedAt        = (Get-Date).ToString("o")
        Account            = (Get-MgContext).Account
        TeamsGroups        = $TeamsGroups
        LifecyclePolicies  = $LifecyclePolicies
        ManagedDevices     = $ManagedDevices
        CrossTenantDefault = $CrossTenantDefault
    }

    $Payload |
        ConvertTo-Json -Depth 30 |
        Set-Content -Path $OutputPath -Encoding UTF8

    exit 0
}
catch {
    Write-GraphCollectorError -Message $_.Exception.Message
    exit 1
}
