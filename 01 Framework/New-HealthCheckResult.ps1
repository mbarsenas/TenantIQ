function New-HealthCheckResult {

    param(

        [string]$Check,

        [string]$Category,

        [string]$Status,

        [string]$Severity,

        [string]$Finding,

        [string]$Recommendation,

        [double]$Duration = 0
    )

    $Result = [PSCustomObject]@{

        Check          = $Check
        Category       = $Category
        Status         = $Status
        Severity       = $Severity
        Finding        = $Finding
        Recommendation = $Recommendation
        Duration       = [math]::Round($Duration, 2)
        Date           = Get-Date
    }

    # Ensure the global result collection is always an array.
    if ($null -eq $Global:ExchangeAIResults) {

        $Global:ExchangeAIResults = @()
    }
    elseif ($Global:ExchangeAIResults -isnot [System.Array]) {

        $Global:ExchangeAIResults = @(
            $Global:ExchangeAIResults
        )
    }

    $Global:ExchangeAIResults += $Result

    return $Result
}