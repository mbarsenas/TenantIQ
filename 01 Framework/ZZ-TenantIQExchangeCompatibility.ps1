# TenantIQ Exchange Online compatibility overrides
# Loaded after the primary hardened Exchange evaluator.

if (Get-Command Invoke-TenantIQExchangeHardenedCheck -CommandType Function -ErrorAction SilentlyContinue) {
    # Preserve the original evaluator in global scope so the compatibility
    # wrapper remains callable from the isolated Exchange child process.
    $Global:TenantIQExchangeHardenedCheckBase =
        (Get-Command Invoke-TenantIQExchangeHardenedCheck -CommandType Function).ScriptBlock

    function Invoke-TenantIQExchangeHardenedCheck {
        param(
            [Parameter(Mandatory)][string]$CheckName,
            [Parameter(Mandatory)][string]$Category,
            [Parameter(Mandatory)][string]$DeclaredSeverity
        )

        if ($CheckName -ne 'Public Folders') {
            if (-not $Global:TenantIQExchangeHardenedCheckBase) {
                throw 'The base Exchange hardened evaluator is unavailable.'
            }
            & $Global:TenantIQExchangeHardenedCheckBase @PSBoundParameters
            return
        }

        $SW = [Diagnostics.Stopwatch]::StartNew()
        try {
            $Folders = @(Get-PublicFolder -Recurse -ResultSize Unlimited -ErrorAction Stop)
            $SW.Stop()

            if ($Folders.Count -eq 0) {
                Add-TenantIQExchangeResult `
                    $CheckName `
                    $Category `
                    'PASS' `
                    'None' `
                    'No public folders were returned.' `
                    'No action required.' `
                    $SW.Elapsed.TotalSeconds
            }
            else {
                Add-TenantIQExchangeResult `
                    $CheckName `
                    $Category `
                    'INFO' `
                    'None' `
                    "$($Folders.Count) public folder(s) detected." `
                    'Confirm that public folders remain required and that permissions, quotas, mail enablement, migration posture, and legacy dependencies are governed.' `
                    $SW.Elapsed.TotalSeconds
            }
        }
        catch {
            $SW.Stop()
            Add-TenantIQExchangeResult `
                $CheckName `
                $Category `
                'INFO' `
                'None' `
                "Public Folders could not be authoritatively evaluated: $($_.Exception.Message)" `
                'Review Exchange Online permissions and Public Folder cmdlet availability before scoring this control.' `
                $SW.Elapsed.TotalSeconds
        }
    }
}
