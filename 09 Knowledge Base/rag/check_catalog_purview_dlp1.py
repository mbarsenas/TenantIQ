from check_catalog import CheckDefinition

CHECKS = (
    CheckDefinition("PUR-DLP-001", "Microsoft Purview", ("dlp alerts", "data loss prevention alerts")),
    CheckDefinition("PUR-DLP-002", "Microsoft Purview", ("dlp policies", "data loss prevention policies")),
    CheckDefinition("PUR-DLP-003", "Microsoft Purview", ("dlp policy mode", "data loss prevention policy mode")),
    CheckDefinition("PUR-DLP-004", "Microsoft Purview", ("endpoint dlp configuration", "endpoint data loss prevention configuration")),
    CheckDefinition("PUR-DLP-005", "Microsoft Purview", ("endpoint dlp devices", "endpoint data loss prevention devices")),
)
