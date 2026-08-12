function Show-TenantIQAssessmentFreshness {
    Clear-Host
    Show-Banner

    Write-Host 'Assessment Data Freshness' -ForegroundColor Cyan
    Write-Host '=========================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'FRESH  : 24 hours or less' -ForegroundColor DarkGray
    Write-Host 'AGING  : More than 24 hours, up to 7 days' -ForegroundColor DarkGray
    Write-Host 'STALE  : More than 7 days' -ForegroundColor DarkGray
    Write-Host 'MISSING: No assessment CSV found' -ForegroundColor DarkGray
    Write-Host ''

    $Freshness = @(Get-TenantIQAssessmentFreshness)

    foreach ($Item in $Freshness) {
        $Color = switch ($Item.Freshness) {
            'FRESH' { 'Green' }
            'AGING' { 'Yellow' }
            'STALE' { 'Red' }
            default { 'DarkYellow' }
        }

        Write-Host ('[{0}] {1}' -f $Item.Freshness,$Item.Workload) -ForegroundColor $Color

        if ($Item.LastRun) {
            Write-Host ('    Last Run : {0}' -f $Item.LastRun.ToString('yyyy-MM-dd HH:mm:ss'))
            Write-Host ('    Age      : {0} hours' -f $Item.AgeHours)
            Write-Host ('    File     : {0}' -f $Item.File) -ForegroundColor DarkGray
        }
        else {
            Write-Host '    No workload assessment CSV is available.' -ForegroundColor DarkYellow
        }

        Write-Host ('    Status   : {0}' -f $Item.Status)
        Write-Host ''
    }

    $Fresh = @($Freshness | Where-Object Freshness -eq 'FRESH').Count
    $Aging = @($Freshness | Where-Object Freshness -eq 'AGING').Count
    $Stale = @($Freshness | Where-Object Freshness -eq 'STALE').Count
    $Missing = @($Freshness | Where-Object Freshness -eq 'MISSING').Count

    Write-Host 'Summary' -ForegroundColor Cyan
    Write-Host '-------'
    Write-Host ('Fresh   : {0}' -f $Fresh) -ForegroundColor Green
    Write-Host ('Aging   : {0}' -f $Aging) -ForegroundColor Yellow
    Write-Host ('Stale   : {0}' -f $Stale) -ForegroundColor $(if ($Stale -gt 0) { 'Red' } else { 'DarkGray' })
    Write-Host ('Missing : {0}' -f $Missing) -ForegroundColor $(if ($Missing -gt 0) { 'Yellow' } else { 'DarkGray' })
    Write-Host ''

    Wait-TenantIQ
}
