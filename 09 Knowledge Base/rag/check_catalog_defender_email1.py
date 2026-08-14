from check_catalog import CheckDefinition

CHECKS = (
    CheckDefinition("DEF-EMAIL-001", "Microsoft Defender", ("anti malware policies", "anti-malware policies")),
    CheckDefinition("DEF-EMAIL-002", "Microsoft Defender", ("anti phishing policies", "anti-phishing policies")),
    CheckDefinition("DEF-EMAIL-003", "Microsoft Defender", ("anti spam policies", "anti-spam policies")),
    CheckDefinition("DEF-EMAIL-004", "Microsoft Defender", ("campaign view readiness", "campaign view")),
    CheckDefinition("DEF-EMAIL-005", "Microsoft Defender", ("email authentication findings", "email authentication")),
    CheckDefinition("DEF-EMAIL-006", "Microsoft Defender", ("preset security policies", "preset policies")),
)
