$ExchangeAIHealthChecks = @(

    @{
        Name          = "Accepted Domains"
        Category      = "Mail Flow"
        Severity      = "High"
        EstimatedTime = "< 1 sec"
        Version       = "1.0"
        Description   = "Validates accepted domain configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Exchange Online\Mail Flow\Test-AcceptedDomains.ps1"
    }

    @{
        Name          = "DKIM"
        Category      = "Mail Flow"
        Severity      = "High"
        EstimatedTime = "< 1 sec"
        Version       = "1.0"
        Description   = "Verifies DKIM signing configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Exchange Online\Mail Flow\Test-DKIM.ps1"
    }

    @{
        Name          = "SPF"
        Category      = "Mail Flow"
        Severity      = "High"
        EstimatedTime = "< 1 sec"
        Version       = "1.0"
        Description   = "Validates SPF DNS records."
        Script        = "$PSScriptRoot\..\02 Health Checks\Exchange Online\Mail Flow\Test-SPF.ps1"
    }

    @{
        Name          = "DMARC"
        Category      = "Mail Flow"
        Severity      = "High"
        EstimatedTime = "< 1 sec"
        Version       = "1.0"
        Description   = "Validates DMARC DNS records."
        Script        = "$PSScriptRoot\..\02 Health Checks\Exchange Online\Mail Flow\Test-DMARC.ps1"
    }

    @{
        Name          = "Transport Rules"
        Category      = "Mail Flow"
        Severity      = "Medium"
        EstimatedTime = "1 sec"
        Version       = "1.0"
        Description   = "Reviews transport rules for disabled or audit-mode configurations."
        Script        = "$PSScriptRoot\..\02 Health Checks\Exchange Online\Mail Flow\Test-TransportRules.ps1"
    }

    @{
        Name          = "Connectors"
        Category      = "Mail Flow"
        Severity      = "Medium"
        EstimatedTime = "2 sec"
        Version       = "1.0"
        Description   = "Reviews inbound and outbound Exchange Online connectors."
        Script        = "$PSScriptRoot\..\02 Health Checks\Exchange Online\Mail Flow\Test-Connectors.ps1"
    }

    @{
        Name          = "Remote Domains"
        Category      = "Mail Flow"
        Severity      = "Medium"
        EstimatedTime = "1 sec"
        Version       = "1.0"
        Description   = "Reviews Exchange Online remote domain settings."
        Script        = "$PSScriptRoot\..\02 Health Checks\Exchange Online\Mail Flow\Test-RemoteDomains.ps1"
    }

    @{
        Name          = "SMTP AUTH"
        Category      = "Security"
        Severity      = "Medium"
        EstimatedTime = "2 sec"
        Version       = "1.0"
        Description   = "Checks SMTP AUTH usage across mailboxes."
        Script        = "$PSScriptRoot\..\02 Health Checks\Exchange Online\Security\Test-SMTPAuth.ps1"
    }

    @{
        Name          = "External Forwarding"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "2 sec"
        Version       = "1.0"
        Description   = "Detects external forwarding rules."
        Script        = "$PSScriptRoot\..\02 Health Checks\Exchange Online\Security\Test-ExternalForwarding.ps1"
    }

    @{
        Name          = "Mailbox Auditing"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "2 sec"
        Version       = "1.0"
        Description   = "Verifies mailbox auditing is enabled for the organization."
        Script        = "$PSScriptRoot\..\02 Health Checks\Exchange Online\Security\Test-MailboxAuditing.ps1"
    }

    @{
        Name          = "Authentication Policies"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "2 sec"
        Version       = "1.0"
        Description   = "Reviews Exchange Online authentication policies and Basic Authentication settings."
        Script        = "$PSScriptRoot\..\02 Health Checks\Exchange Online\Security\Test-AuthenticationPolicies.ps1"
    }

    @{
        Name          = "Anti-Spam Policies"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "2 sec"
        Version       = "1.0"
        Description   = "Reviews Exchange Online anti-spam policies and recommended settings."
        Script        = "$PSScriptRoot\..\02 Health Checks\Exchange Online\Security\Test-AntiSpam.ps1"
    }

)