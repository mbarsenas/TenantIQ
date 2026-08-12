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
            # Get-PublicFolder can require an explicit Organization in delegated
            # or REST-backed EXO sessions. Public-folder mailbox inventory is a
            # stable tenant-level signal and avoids that session-context issue.
            $Mailboxes = @(Get-Mailbox -PublicFolder -ResultSize Unlimited -ErrorAction Stop)
            $SW.Stop()

            if ($Mailboxes.Count -eq 0) {
                Add-TenantIQExchangeResult `
                    $CheckName `
                    $Category `
                    'PASS' `
                    'None' `
                    'No public-folder mailboxes were returned.' `
                    'No action required.' `
                    $SW.Elapsed.TotalSeconds
            }
            else {
                Add-TenantIQExchangeResult `
                    $CheckName `
                    $Category `
                    'INFO' `
                    'None' `
                    "$($Mailboxes.Count) public-folder mailbox(es) detected." `
                    'Confirm that public folders remain required and review hierarchy, permissions, ownership, quotas, mail enablement, migration posture, and legacy dependencies.' `
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
                "Public-folder mailbox inventory could not be authoritatively evaluated: $($_.Exception.Message)" `
                'Review Exchange Online permissions and Public Folder cmdlet availability before scoring this control.' `
                $SW.Elapsed.TotalSeconds
        }
    }
}
