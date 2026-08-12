$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online Large List Threshold Risk health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
Write-Host ""; Write-Host "Retrieving SharePoint business-site inventory..." -ForegroundColor Cyan
$scope=Get-TenantIQBusinessSites
$inventory=@(); $errors=@(); $coverage='Full list-level coverage requires PnP.PowerShell.'
if (Get-Command Connect-PnPOnline -ErrorAction SilentlyContinue) {
    foreach($s in $scope.Business){
        $PnPConnected=$false
        try {
            Connect-PnPOnline -Url $s.Url -Interactive -ErrorAction Stop | Out-Null
            $PnPConnected=$true
            foreach($l in @(Get-PnPList -Includes Title,Hidden,ItemCount,BaseType -ErrorAction Stop | Where-Object {$_.Hidden -ne $true})){
                $inventory += [pscustomobject]@{SiteUrl=$s.Url;ListTitle=$l.Title;BaseType=$l.BaseType;ItemCount=[int64]$l.ItemCount;Risk=if($l.ItemCount -ge 5000){'At/Over 5000'}elseif($l.ItemCount -ge 4000){'Near 5000'}else{'Normal'}}
            }
        } catch { $errors += [pscustomobject]@{Url=$s.Url;Reason=$_.Exception.Message} }
        finally {
            if($PnPConnected -and (Get-Command Disconnect-PnPOnline -ErrorAction SilentlyContinue)){
                try { Disconnect-PnPOnline -ErrorAction Stop } catch { }
            }
        }
    }
    $coverage='PnP list-level enumeration completed where authentication succeeded.'
}
$risk=@($inventory|Where-Object {$_.ItemCount -ge 4000}); $over=@($inventory|Where-Object {$_.ItemCount -ge 5000})
Write-TenantIQSharePointHeader 'Large List Threshold Risk'
Write-Host "Business Sites Discovered      : $($scope.Business.Count)"
Write-Host "Lists/Libraries Reviewed       : $($inventory.Count)"
Write-Host "Lists At/Over 5,000 Items      : $($over.Count)"
Write-Host "Lists 4,000-4,999 Items        : $(@($risk|Where-Object {$_.ItemCount -lt 5000}).Count)"
Write-Host "Site Enumeration Errors        : $($errors.Count)"
Write-Host "Coverage                       : $coverage"
if($risk.Count){ Write-Host ""; $risk|Sort-Object ItemCount -Descending|Format-Table SiteUrl,ListTitle,BaseType,ItemCount,Risk -AutoSize -Wrap }
Write-Host ""; Write-Host 'Large List Threshold Risk Findings' -ForegroundColor Cyan; Write-Host '----------------------------------'
if(-not (Get-Command Connect-PnPOnline -ErrorAction SilentlyContinue)){
    $st='INFO';$sev='None';$f='Native SharePoint Online PowerShell does not enumerate list item counts. PnP.PowerShell is not available, so list-level threshold risk was not scored.';$rec='Run this check in PowerShell 7 with current PnP.PowerShell for list-level coverage, or review large lists in the SharePoint admin experience.';Write-Host 'INFO  List-level enumeration requires PnP.PowerShell.' -ForegroundColor Yellow
}elseif($over.Count){$st='WARNING';$sev='Low';$f="$($over.Count) visible list(s)/library(ies) contain 5,000 or more items. The 5,000-item List View Threshold is a query/view resource threshold, not a maximum list size.";$rec='Review indexed columns, filtered views, information architecture, and query patterns for the identified lists.';Write-Host "WARNING  $($over.Count) list(s)/library(ies) require large-list governance review." -ForegroundColor Yellow
}elseif($risk.Count){$st='WARNING';$sev='Low';$f="$($risk.Count) list(s)/library(ies) are approaching the 5,000-item List View Threshold review point.";$rec='Review indexing and filtered views before the lists grow further.';Write-Host "WARNING  $($risk.Count) list(s)/library(ies) are approaching 5,000 items." -ForegroundColor Yellow
}elseif($errors.Count){$st='INFO';$sev='None';$f="No risk was detected in enumerated sites, but $($errors.Count) site(s) could not be enumerated.";$rec='Resolve PnP authentication/permissions for excluded sites and rerun.';Write-Host 'INFO  Some sites could not be enumerated.' -ForegroundColor Yellow
}else{$st='PASS';$sev='None';$f='No visible business lists or libraries with 4,000 or more items were detected.';$rec='Continue monitoring list growth and use indexed columns and filtered views for large lists.';Write-Host 'PASS  No large-list threshold risk detected.' -ForegroundColor Green}
Add-TenantIQCheckResult -Check 'Large List Threshold Risk' -Category 'Content Management' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online Large List Threshold Risk health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "Large List Threshold Risk assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "Large List Threshold Risk" -Category "Content Management" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
