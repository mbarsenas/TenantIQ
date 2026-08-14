from check_catalog import CheckDefinition
from check_catalog_exchange import CHECKS as EXCHANGE_CHECKS

CHECKS = (
    CheckDefinition("PUR-DLP-006", "Microsoft Purview", ("exchange dlp coverage", "exchange data loss prevention coverage")),
    CheckDefinition("PUR-DLP-007", "Microsoft Purview", ("onedrive dlp coverage", "onedrive data loss prevention coverage")),
    CheckDefinition("PUR-DLP-008", "Microsoft Purview", ("sharepoint dlp coverage", "sharepoint data loss prevention coverage")),
    CheckDefinition("PUR-DLP-009", "Microsoft Purview", ("teams dlp coverage", "teams data loss prevention coverage")),
) + EXCHANGE_CHECKS
