# TenantIQ Exchange Online compatibility overrides
# Loaded after the primary hardened Exchange evaluator.

if (Get-Command Invoke-TenantIQExchangeHardenedCheck -CommandType Function -ErrorAction SilentlyContinue) {
    $script:TenantIQExchangeHardenedCheckBase = ${function:Invoke-TenantIQExchangeHardenedCheck}

    function Invoke-TenantIQExchangeHardenedCheck {
        param(
            [Parameter(Mandatory)][string]$CheckName,
            [Parameter(Mandatory)][string]$Category,
            [Parameter(Mandatory)][string]$DeclaredSeverity
        )

        if ($CheckName -ne 'Public Folders') {
            & $script:TenantIQExchangeHardenedCheckBase @PSBoundParameters
            return
        }

        $SW = [Diagnostics.Stopwatch]::StartNew()
        try {
            $Folders = @(Get-PublicFolder -ResultSize Unlimited -ErrorAction Stop)
            $Mailboxes = @(Get-Mailbox -PublicFolder -ResultSize Unlimited -ErrorAction Stop)
            $SW.Stop()

            Add-TenantIQExchangeResult `
                $CheckName `
                $Category `
                'INFO' `
                'None' `
                "$($Folders.Count) public folder(s) and $($Mailboxes.Count) public-folder mailbox(es) detected." `
                'Confirm that public folders remain required and that permissions, quotas, mail enablement, migration posture, and legacy dependencies are governed.' `
                $SW.Elapsed.TotalSeconds
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
