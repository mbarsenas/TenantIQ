from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class CheckDefinition:
    check_id: str
    workload: str
    aliases: tuple[str, ...]


CHECKS: tuple[CheckDefinition, ...] = (
    CheckDefinition("ENTRA-MFA-001", "Entra ID", ("mfa registration", "mfa registration coverage", "multifactor authentication registration", "multi-factor authentication registration")),
    CheckDefinition("ENTRA-AUTH-001", "Entra ID", ("authentication methods", "authentication method registration", "registered authentication methods")),
    CheckDefinition("ENTRA-AUTH-002", "Entra ID", ("authentication methods policy", "authentication method policy", "authentication policy methods")),
    CheckDefinition("ENTRA-AUTH-003", "Entra ID", ("authentication registration campaign", "authentication methods registration campaign", "registration campaign")),
    CheckDefinition("ENTRA-AUTH-004", "Entra ID", ("password expiration policy", "password expiry policy", "password expiration")),
    CheckDefinition("ENTRA-CA-001", "Entra ID", ("authentication context", "conditional access authentication context", "authentication contexts")),
    CheckDefinition("ENTRA-CA-002", "Entra ID", ("authentication strength", "conditional access authentication strength")),
    CheckDefinition("ENTRA-CA-003", "Entra ID", ("authentication strengths", "conditional access authentication strengths")),
    CheckDefinition("ENTRA-CA-004", "Entra ID", ("conditional access exclusions", "ca exclusions", "conditional access policy exclusions")),
    CheckDefinition("ENTRA-CA-005", "Entra ID", ("conditional access policies", "conditional access policy", "ca policies")),
    CheckDefinition("ENTRA-CA-006", "Entra ID", ("legacy authentication", "legacy auth", "block legacy authentication")),
    CheckDefinition("ENTRA-CA-007", "Entra ID", ("named locations", "conditional access named locations")),
    CheckDefinition("ENTRA-CA-008", "Entra ID", ("risk based conditional access", "risk-based conditional access", "identity protection conditional access")),
    CheckDefinition("ENTRA-APP-001", "Entra ID", ("admin consent request policy", "admin consent requests")),
    CheckDefinition("ENTRA-APP-002", "Entra ID", ("admin consent workflow", "admin consent request workflow")),
    CheckDefinition("ENTRA-APP-003", "Entra ID", ("app registrations", "application registrations")),
    CheckDefinition("ENTRA-APP-004", "Entra ID", ("application credentials", "app credentials")),
    CheckDefinition("ENTRA-APP-005", "Entra ID", ("application ownership", "app ownership", "application owners")),
    CheckDefinition("ENTRA-APP-006", "Entra ID", ("application proxy", "entra application proxy", "app proxy")),
    CheckDefinition("ENTRA-APP-007", "Entra ID", ("enterprise app permissions", "enterprise application permissions", "service principal permissions")),
    CheckDefinition("ENTRA-APP-008", "Entra ID", ("service principal credentials", "service principal secrets", "service principal certificates")),
    CheckDefinition("ENTRA-APP-009", "Entra ID", ("service principals", "enterprise applications")),
    CheckDefinition("ENTRA-APP-010", "Entra ID", ("tenant app management policy", "tenant application management policy", "app management policy")),
    CheckDefinition("ENTRA-DEV-001", "Entra ID", ("device join types", "entra device join types")),
    CheckDefinition("ENTRA-DEV-002", "Entra ID", ("device operating systems", "device os inventory", "device operating system inventory")),
    CheckDefinition("ENTRA-DEV-003", "Entra ID", ("device ownership", "registered device ownership")),
    CheckDefinition("ENTRA-DEV-004", "Entra ID", ("device registration activity", "device registration activity review")),
    CheckDefinition("ENTRA-DEV-005", "Entra ID", ("device registration policy", "entra device registration policy")),
    CheckDefinition("ENTRA-DEV-006", "Entra ID", ("registered device inventory", "device inventory", "registered devices")),
    CheckDefinition("ENTRA-EXT-001", "Entra ID", ("cross tenant access", "cross-tenant access", "cross tenant access policy")),
    CheckDefinition("ENTRA-EXT-002", "Entra ID", ("guest invitation restrictions", "guest invite restrictions", "guest invitation policy")),
    CheckDefinition("ENTRA-EXT-003", "Entra ID", ("guest self service sign up", "guest self-service sign-up", "self service sign up")),
    CheckDefinition("ENTRA-EXT-004", "Entra ID", ("stale guest accounts", "stale guests", "inactive guest accounts")),
    CheckDefinition("ENTRA-EXT-005", "Entra ID", ("tenant restrictions", "tenant restriction policy")),
    CheckDefinition("ENTRA-HYB-001", "Entra ID", ("directory sync health", "entra connect sync health", "directory synchronization health")),
    CheckDefinition("ENTRA-HYB-002", "Entra ID", ("domain federation", "federated domains", "domain federation configuration")),
    CheckDefinition("ENTRA-GOV-001", "Entra ID", ("access reviews", "identity governance access reviews")),
    CheckDefinition("ENTRA-GOV-002", "Entra ID", ("administrative units", "entra administrative units")),
    CheckDefinition("ENTRA-GOV-003", "Entra ID", ("deleted groups", "soft deleted groups")),
    CheckDefinition("ENTRA-GOV-004", "Entra ID", ("dynamic group configuration", "dynamic groups")),
    CheckDefinition("ENTRA-GOV-005", "Entra ID", ("group lifecycle policy", "microsoft 365 group lifecycle policy")),
    CheckDefinition("ENTRA-GOV-006", "Entra ID", ("group membership hygiene", "group membership review")),
    CheckDefinition("ENTRA-GOV-007", "Entra ID", ("group naming policy", "microsoft 365 group naming policy")),
    CheckDefinition("ENTRA-GOV-008", "Entra ID", ("group ownership", "group owners", "groups without owners")),
    CheckDefinition("ENTRA-GOV-009", "Entra ID", ("lifecycle workflows", "identity governance lifecycle workflows")),
    CheckDefinition("ENTRA-GOV-010", "Entra ID", ("terms of use", "entra terms of use")),
    CheckDefinition("ENTRA-IDP-001", "Entra ID", ("identity risk detections", "risk detections")),
    CheckDefinition("ENTRA-IDP-002", "Entra ID", ("risky service principals", "service principal risk")),
    CheckDefinition("ENTRA-IDP-003", "Entra ID", ("risky sign ins", "risky sign-ins", "risky signins")),
    CheckDefinition("ENTRA-IDP-004", "Entra ID", ("risky users", "user risk")),
    CheckDefinition("ENTRA-IDP-005", "Entra ID", ("service principal risk detections",)),
    CheckDefinition("ENTRA-ID-001", "Entra ID", ("authorization policy", "entra authorization policy")),
    CheckDefinition("ENTRA-ID-002", "Entra ID", ("default user permissions", "user default permissions")),
    CheckDefinition("ENTRA-ID-003", "Entra ID", ("deleted users", "soft deleted users")),
    CheckDefinition("ENTRA-ID-004", "Entra ID", ("domain configuration", "entra domain configuration")),
    CheckDefinition("ENTRA-ID-005", "Entra ID", ("emergency access accounts", "emergency accounts")),
    CheckDefinition("ENTRA-ID-006", "Entra ID", ("guest users", "guest user accounts")),
    CheckDefinition("ENTRA-ID-007", "Entra ID", ("privileged authentication methods", "admin authentication methods")),
    CheckDefinition("ENTRA-ID-008", "Entra ID", ("stale user accounts", "stale users", "inactive user accounts")),
    CheckDefinition("ENTRA-ID-009", "Entra ID", ("user accounts", "user account inventory")),
    CheckDefinition("ENTRA-PRIV-001", "Entra ID", ("break glass accounts", "break-glass accounts")),
    CheckDefinition("ENTRA-PRIV-002", "Entra ID", ("custom directory roles", "custom entra roles")),
    CheckDefinition("ENTRA-PRIV-003", "Entra ID", ("global administrators", "global admins")),
    CheckDefinition("ENTRA-PRIV-004", "Entra ID", ("pim role settings", "privileged identity management role settings")),
    CheckDefinition("ENTRA-PRIV-005", "Entra ID", ("privileged role eligibility", "pim role eligibility")),
    CheckDefinition("ENTRA-PRIV-006", "Entra ID", ("privileged roles", "directory privileged roles")),
    CheckDefinition("ENTRA-PRIV-007", "Entra ID", ("role assignable groups", "role-assignable groups")),
    CheckDefinition("ENTRA-SEC-001", "Entra ID", ("security risky sign ins", "security risky sign-ins")),
    CheckDefinition("ENTRA-SEC-002", "Entra ID", ("security risky users", "security user risk")),
    CheckDefinition("ENTRA-SEC-003", "Entra ID", ("security defaults", "entra security defaults")),
    CheckDefinition("EXO-MF-001", "Exchange Online", ("accepted domains", "exchange accepted domains")),
    CheckDefinition("EXO-MF-002", "Exchange Online", ("connectors", "exchange connectors", "mail flow connectors")),
    CheckDefinition("EXO-MF-003", "Exchange Online", ("dkim", "dkim configuration", "domainkeys identified mail")),
    CheckDefinition("EXO-MF-004", "Exchange Online", ("dmarc", "dmarc policy", "domain-based message authentication reporting and conformance")),
    CheckDefinition("EXO-MF-005", "Exchange Online", ("remote domains", "exchange remote domains")),
    CheckDefinition("EXO-MF-006", "Exchange Online", ("spf", "spf record", "sender policy framework")),
    CheckDefinition("EXO-MF-007", "Exchange Online", ("transport rules", "mail flow rules", "exchange transport rules")),
    CheckDefinition("EXO-SEC-001", "Exchange Online", ("anti spam", "anti-spam", "anti spam policies", "spam policies")),
    CheckDefinition("EXO-SEC-002", "Exchange Online", ("authentication policies", "exchange authentication policies")),
    CheckDefinition("EXO-SEC-003", "Exchange Online", ("external forwarding", "automatic external forwarding", "mail forwarding")),
    CheckDefinition("EXO-SEC-004", "Exchange Online", ("mailbox auditing", "mailbox audit", "mailbox audit logging")),
    CheckDefinition("EXO-SEC-005", "Exchange Online", ("smtp auth", "smtp authentication", "authenticated smtp")),
    CheckDefinition("EXO-PROD-001", "Exchange Online", ("exchange bulk control", "bulk exchange control")),
    CheckDefinition("SPO-AC-001", "SharePoint Online", ("app only authentication", "app-only authentication")),
    CheckDefinition("SPO-AC-002", "SharePoint Online", ("conditional access integration", "sharepoint conditional access integration")),
    CheckDefinition("SPO-AC-003", "SharePoint Online", ("domain restricted sync", "domain-restricted sync")),
    CheckDefinition("SPO-AC-004", "SharePoint Online", ("idle session sign out", "idle session sign-out")),
    CheckDefinition("SPO-AC-005", "SharePoint Online", ("legacy authentication", "sharepoint legacy authentication")),
    CheckDefinition("SPO-AC-006", "SharePoint Online", ("site access restrictions", "sharepoint site access restrictions")),
    CheckDefinition("SPO-AC-007", "SharePoint Online", ("sync client restrictions", "sharepoint sync client restrictions")),
    CheckDefinition("SPO-AC-008", "SharePoint Online", ("unmanaged device access", "sharepoint unmanaged device access")),
    CheckDefinition("SPO-APP-001", "SharePoint Online", ("add in retirement readiness", "add-in retirement readiness")),
    CheckDefinition("SPO-APP-002", "SharePoint Online", ("app catalog configuration", "sharepoint app catalog configuration")),
    CheckDefinition("SPO-APP-003", "SharePoint Online", ("site collection app catalogs", "site collection app catalog")),
    CheckDefinition("SPO-APP-004", "SharePoint Online", ("tenant app catalog apps", "tenant app catalog applications")),
    CheckDefinition("SPO-COMP-001", "SharePoint Online", ("information barriers integration", "sharepoint information barriers")),
    CheckDefinition("SPO-COMP-002", "SharePoint Online", ("records management integration", "sharepoint records management")),
    CheckDefinition("SPO-CM-001", "SharePoint Online", ("automatic version trimming", "version trimming")),
    CheckDefinition("SPO-CM-002", "SharePoint Online", ("large list threshold risk", "large list threshold")),
    CheckDefinition("SPO-CM-003", "SharePoint Online", ("version history limits", "version history limit")),
    CheckDefinition("SPO-GOV-001", "SharePoint Online", ("sharepoint governance summary", "governance summary")),
    CheckDefinition("SPO-GOV-002", "SharePoint Online", ("site classification", "sharepoint site classification")),
    CheckDefinition("SPO-GOV-003", "SharePoint Online", ("site creation controls", "sharepoint site creation controls")),
    CheckDefinition("SPO-GOV-004", "SharePoint Online", ("site sensitivity labels", "sharepoint sensitivity labels")),
    CheckDefinition("SPO-GOV-005", "SharePoint Online", ("site templates and customization", "site templates and customizations")),
    CheckDefinition("SPO-GOV-006", "SharePoint Online", ("unlabeled externally shared sites", "externally shared unlabeled sites")),
    CheckDefinition("SPO-LC-001", "SharePoint Online", ("deleted site retention", "sharepoint deleted site retention")),
    CheckDefinition("SPO-LC-002", "SharePoint Online", ("site lifecycle policies", "sharepoint site lifecycle policies")),
    CheckDefinition("SPO-OD-001", "SharePoint Online", ("onedrive retention configuration", "onedrive retention")),
    CheckDefinition("SPO-OD-002", "SharePoint Online", ("onedrive sharing alignment", "onedrive sharing configuration alignment")),
    CheckDefinition("SPO-PERF-001", "SharePoint Online", ("tenant cdn configuration", "sharepoint tenant cdn configuration")),
    CheckDefinition("SPO-SEC-001", "SharePoint Online", ("custom script settings", "sharepoint custom script settings")),
    CheckDefinition("SPO-SEC-002", "SharePoint Online", ("restricted content discovery", "sharepoint restricted content discovery")),
    CheckDefinition("SPO-SHR-001", "SharePoint Online", ("anonymous link exposure", "anonymous links")),
    CheckDefinition("SPO-SHR-002", "SharePoint Online", ("default sharing link configuration", "default sharing link")),
    CheckDefinition("SPO-SHR-003", "SharePoint Online", ("external sharing", "sharepoint external sharing")),
    CheckDefinition("SPO-SHR-004", "SharePoint Online", ("external sharing security groups", "sharing security groups")),
    CheckDefinition("SPO-SHR-005", "SharePoint Online", ("external user expiration", "guest expiration")),
    CheckDefinition("SPO-SHR-006", "SharePoint Online", ("guest resharing controls", "guest resharing")),
    CheckDefinition("SPO-SHR-007", "SharePoint Online", ("m365 group guest membership", "microsoft 365 group guest membership")),
    CheckDefinition("SPO-SHR-008", "SharePoint Online", ("sharing domain restrictions", "external sharing domain restrictions")),
    CheckDefinition("SPO-SHR-009", "SharePoint Online", ("site external sharing", "site-level external sharing")),
    CheckDefinition("SPO-SITE-001", "SharePoint Online", ("hub site association coverage", "hub association coverage")),
    CheckDefinition("SPO-SITE-002", "SharePoint Online", ("hub site configuration", "hub configuration")),
    CheckDefinition("SPO-SITE-003", "SharePoint Online", ("inactive sites", "inactive sharepoint sites")),
    CheckDefinition("SPO-SITE-004", "SharePoint Online", ("m365 group site ownership", "microsoft 365 group site ownership")),
    CheckDefinition("SPO-SITE-005", "SharePoint Online", ("orphaned group connected sites", "orphaned group-connected sites")),
    CheckDefinition("SPO-SITE-006", "SharePoint Online", ("site collection administrator coverage", "site admin coverage")),
    CheckDefinition("SPO-SITE-007", "SharePoint Online", ("site inventory", "sharepoint site inventory")),
    CheckDefinition("SPO-SITE-008", "SharePoint Online", ("site lock state", "sharepoint site lock state")),
    CheckDefinition("SPO-SITE-009", "SharePoint Online", ("site storage management v2", "site storage management")),
    CheckDefinition("SPO-SITE-010", "SharePoint Online", ("site storage management",)),
    CheckDefinition("SPO-TEN-001", "SharePoint Online", ("tenant configuration", "sharepoint tenant configuration")),
)

try:
    from check_catalog_teams import CHECKS as TEAMS_CHECKS
except ImportError:
    TEAMS_CHECKS = ()
try:
    from check_catalog_onedrive import CHECKS as ONEDRIVE_CHECKS
except ImportError:
    ONEDRIVE_CHECKS = ()
try:
    from check_catalog_intune import CHECKS as INTUNE_CHECKS
except ImportError:
    INTUNE_CHECKS = ()
try:
    from check_catalog_defender_core import CHECKS as DEFENDER_CORE_CHECKS
except ImportError:
    DEFENDER_CORE_CHECKS = ()
try:
    from check_catalog_defender_email1 import CHECKS as DEFENDER_EMAIL1_CHECKS
except ImportError:
    DEFENDER_EMAIL1_CHECKS = ()
try:
    from check_catalog_defender_email2 import CHECKS as DEFENDER_EMAIL2_CHECKS
except ImportError:
    DEFENDER_EMAIL2_CHECKS = ()
try:
    from check_catalog_purview_core import CHECKS as PURVIEW_CORE_CHECKS
except ImportError:
    PURVIEW_CORE_CHECKS = ()
try:
    from check_catalog_purview_dlp1 import CHECKS as PURVIEW_DLP1_CHECKS
except ImportError:
    PURVIEW_DLP1_CHECKS = ()
try:
    from check_catalog_purview_dlp2 import CHECKS as PURVIEW_DLP2_CHECKS
except ImportError:
    PURVIEW_DLP2_CHECKS = ()

CHECKS = (
    CHECKS
    + TEAMS_CHECKS
    + ONEDRIVE_CHECKS
    + INTUNE_CHECKS
    + DEFENDER_CORE_CHECKS
    + DEFENDER_EMAIL1_CHECKS
    + DEFENDER_EMAIL2_CHECKS
    + PURVIEW_CORE_CHECKS
    + PURVIEW_DLP1_CHECKS
    + PURVIEW_DLP2_CHECKS
)

CHECK_BY_ID = {check.check_id: check for check in CHECKS}
CHECK_ID_BY_ALIAS = {alias: check.check_id for check in CHECKS for alias in check.aliases}


def canonical_check_id(value: str | None) -> str | None:
    if not value:
        return None
    candidate = value.strip()
    if candidate in CHECK_BY_ID:
        return candidate
    return CHECK_ID_BY_ALIAS.get(" ".join(candidate.lower().split()))
