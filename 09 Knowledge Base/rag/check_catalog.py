from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class CheckDefinition:
    check_id: str
    workload: str
    aliases: tuple[str, ...]


CHECKS: tuple[CheckDefinition, ...] = (
    CheckDefinition(
        check_id="ENTRA-MFA-001",
        workload="Entra ID",
        aliases=(
            "mfa registration",
            "mfa registration coverage",
            "multifactor authentication registration",
            "multi-factor authentication registration",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-AUTH-001",
        workload="Entra ID",
        aliases=(
            "authentication methods",
            "authentication method registration",
            "registered authentication methods",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-AUTH-002",
        workload="Entra ID",
        aliases=(
            "authentication methods policy",
            "authentication method policy",
            "authentication policy methods",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-AUTH-003",
        workload="Entra ID",
        aliases=(
            "authentication registration campaign",
            "authentication methods registration campaign",
            "registration campaign",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-AUTH-004",
        workload="Entra ID",
        aliases=(
            "password expiration policy",
            "password expiry policy",
            "password expiration",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-CA-001",
        workload="Entra ID",
        aliases=(
            "authentication context",
            "conditional access authentication context",
            "authentication contexts",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-CA-002",
        workload="Entra ID",
        aliases=(
            "authentication strength",
            "conditional access authentication strength",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-CA-003",
        workload="Entra ID",
        aliases=(
            "authentication strengths",
            "conditional access authentication strengths",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-CA-004",
        workload="Entra ID",
        aliases=(
            "conditional access exclusions",
            "ca exclusions",
            "conditional access policy exclusions",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-CA-005",
        workload="Entra ID",
        aliases=(
            "conditional access policies",
            "conditional access policy",
            "ca policies",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-CA-006",
        workload="Entra ID",
        aliases=(
            "legacy authentication",
            "legacy auth",
            "block legacy authentication",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-CA-007",
        workload="Entra ID",
        aliases=(
            "named locations",
            "conditional access named locations",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-CA-008",
        workload="Entra ID",
        aliases=(
            "risk based conditional access",
            "risk-based conditional access",
            "identity protection conditional access",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-APP-001",
        workload="Entra ID",
        aliases=(
            "admin consent request policy",
            "admin consent requests",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-APP-002",
        workload="Entra ID",
        aliases=(
            "admin consent workflow",
            "admin consent request workflow",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-APP-003",
        workload="Entra ID",
        aliases=(
            "app registrations",
            "application registrations",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-APP-004",
        workload="Entra ID",
        aliases=(
            "application credentials",
            "app credentials",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-APP-005",
        workload="Entra ID",
        aliases=(
            "application ownership",
            "app ownership",
            "application owners",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-APP-006",
        workload="Entra ID",
        aliases=(
            "application proxy",
            "entra application proxy",
            "app proxy",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-APP-007",
        workload="Entra ID",
        aliases=(
            "enterprise app permissions",
            "enterprise application permissions",
            "service principal permissions",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-APP-008",
        workload="Entra ID",
        aliases=(
            "service principal credentials",
            "service principal secrets",
            "service principal certificates",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-APP-009",
        workload="Entra ID",
        aliases=(
            "service principals",
            "enterprise applications",
        ),
    ),
    CheckDefinition(
        check_id="ENTRA-APP-010",
        workload="Entra ID",
        aliases=(
            "tenant app management policy",
            "tenant application management policy",
            "app management policy",
        ),
    ),
)


CHECK_BY_ID = {check.check_id: check for check in CHECKS}
CHECK_ID_BY_ALIAS = {
    alias: check.check_id
    for check in CHECKS
    for alias in check.aliases
}


def canonical_check_id(value: str | None) -> str | None:
    if not value:
        return None
    candidate = value.strip()
    if candidate in CHECK_BY_ID:
        return candidate
    return CHECK_ID_BY_ALIAS.get(" ".join(candidate.lower().split()))
