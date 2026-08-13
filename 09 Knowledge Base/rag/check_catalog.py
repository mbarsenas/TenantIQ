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
