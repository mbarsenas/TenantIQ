from __future__ import annotations

import argparse
import re
from collections import defaultdict
from typing import Any

import psycopg

from assessment_store import DATABASE_URL, ensure_schema

DIGEST_RE = re.compile(r"([0-9a-fA-F]{16})$")


def _digest_from_row(assessment_id: str, metadata: dict[str, Any] | None) -> str | None:
    metadata = metadata or {}
    digest = str(metadata.get("content_digest") or "").strip().lower()
    if re.fullmatch(r"[0-9a-f]{16}", digest):
        return digest
    match = DIGEST_RE.search(str(assessment_id or ""))
    return match.group(1).lower() if match else None


def find_duplicate_groups(customer_id: str | None = None) -> list[dict[str, Any]]:
    with psycopg.connect(DATABASE_URL) as conn:
        ensure_schema(conn)
        if customer_id:
            rows = conn.execute(
                """
                SELECT assessment_id, customer_id, source_name, imported_at, finding_count, metadata
                FROM tenantiq_assessments
                WHERE customer_id = %s
                ORDER BY customer_id, imported_at DESC, assessment_id DESC
                """,
                (customer_id,),
            ).fetchall()
        else:
            rows = conn.execute(
                """
                SELECT assessment_id, customer_id, source_name, imported_at, finding_count, metadata
                FROM tenantiq_assessments
                ORDER BY customer_id, imported_at DESC, assessment_id DESC
                """
            ).fetchall()

    grouped: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        assessment_id = str(row[0])
        customer = str(row[1])
        metadata = row[5] or {}
        digest = _digest_from_row(assessment_id, metadata)
        if not digest:
            continue
        grouped[(customer, digest)].append(
            {
                "assessment_id": assessment_id,
                "customer_id": customer,
                "source_name": str(row[2] or ""),
                "imported_at": row[3],
                "finding_count": int(row[4] or 0),
                "digest": digest,
            }
        )

    duplicate_groups: list[dict[str, Any]] = []
    for (customer, digest), items in grouped.items():
        if len(items) < 2:
            continue
        items.sort(key=lambda item: (item["imported_at"], item["assessment_id"]), reverse=True)
        duplicate_groups.append(
            {
                "customer_id": customer,
                "digest": digest,
                "keep": items[0],
                "remove": items[1:],
            }
        )
    duplicate_groups.sort(key=lambda group: (group["customer_id"], group["digest"]))
    return duplicate_groups


def cleanup_duplicate_groups(groups: list[dict[str, Any]]) -> tuple[int, int]:
    removed_assessments = 0
    removed_findings = 0
    with psycopg.connect(DATABASE_URL, autocommit=True) as conn:
        ensure_schema(conn)
        for group in groups:
            for item in group["remove"]:
                finding_row = conn.execute(
                    "SELECT COUNT(*) FROM tenantiq_assessment_findings WHERE assessment_id = %s",
                    (item["assessment_id"],),
                ).fetchone()
                removed_findings += int(finding_row[0] or 0) if finding_row else 0
                result = conn.execute(
                    "DELETE FROM tenantiq_assessments WHERE assessment_id = %s AND customer_id = %s",
                    (item["assessment_id"], item["customer_id"]),
                )
                removed_assessments += result.rowcount or 0
    return removed_assessments, removed_findings


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Find and optionally remove duplicate TenantIQ assessments with identical content digests."
    )
    parser.add_argument("--customer-id", default=None, help="Limit cleanup to one customer identity.")
    parser.add_argument("--apply", action="store_true", help="Delete older duplicates. Without this flag, the command is read-only.")
    args = parser.parse_args()

    groups = find_duplicate_groups(args.customer_id)
    if not groups:
        print("No duplicate assessment groups found.")
        return

    duplicate_count = sum(len(group["remove"]) for group in groups)
    duplicate_findings = sum(item["finding_count"] for group in groups for item in group["remove"])

    print(f"Duplicate groups: {len(groups)}")
    print(f"Duplicate assessments: {duplicate_count}")
    print(f"Duplicate findings represented: {duplicate_findings}")
    print()

    for group in groups:
        keep = group["keep"]
        print(f"Customer: {group['customer_id']}")
        print(f"Digest:   {group['digest']}")
        print(f"KEEP:     {keep['assessment_id']} | {keep['source_name']} | {keep['imported_at']}")
        for item in group["remove"]:
            print(f"REMOVE:   {item['assessment_id']} | {item['source_name']} | {item['imported_at']}")
        print()

    if not args.apply:
        print("DRY RUN ONLY. Re-run with --apply to delete the REMOVE entries.")
        return

    removed_assessments, removed_findings = cleanup_duplicate_groups(groups)
    print(f"Removed assessments: {removed_assessments}")
    print(f"Removed findings: {removed_findings}")


if __name__ == "__main__":
    main()
