from check_catalog import CheckDefinition

CHECKS = (
    CheckDefinition("DEF-EMAIL-007", "Microsoft Defender", ("quarantine policies",)),
    CheckDefinition("DEF-EMAIL-008", "Microsoft Defender", ("safe attachments policies", "safe attachments")),
    CheckDefinition("DEF-EMAIL-009", "Microsoft Defender", ("safe links policies", "safe links")),
    CheckDefinition("DEF-EMAIL-010", "Microsoft Defender", ("tenant allow block list", "tenant allow/block list")),
    CheckDefinition("DEF-EMAIL-011", "Microsoft Defender", ("user submissions configuration", "user submissions")),
    CheckDefinition("DEF-EMAIL-012", "Microsoft Defender", ("zero hour auto purge", "zero-hour auto purge")),
)
