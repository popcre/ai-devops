#!/usr/bin/env python3
"""Read-only audit of the canonical cross-repository routing coverage.

The audit answers one question: does every canonical remote have exactly one
coverage row, and does the frozen routing baseline agree with it?

It never opens repository file bodies. Sizes come from the frozen baseline that
Phase 0 measured from GitHub contents metadata, and rows whose privacy class
forbids raw inspection are additionally asserted to stay metadata-only. Clones,
host checkouts, and linked worktrees are not rollout rows: they collapse onto
the canonical identity, and `--check-identity <dir>` proves that for one path.

Exit status is 0 when the audit is clean and 1 when any check fails.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
COVERAGE = ROOT / "config" / "repository-coverage.json"
BASELINE = ROOT / "tests" / "verification" / "task-gates" / "routing-baseline.json"

ROUTER_FILES = ("AGENTS.md", "CLAUDE.md", "HANDOFF.md")
PRIVACY_CLASSES = {"public", "private", "private-licensed", "private-transcripts"}
WORKFLOW_FAMILIES = {"main-only", "feature-branch-pr", "sandbox-pr"}
POLICY_SOURCES = {"central", "consumer"}
REQUIRED_KEYS = (
    "identity",
    "group",
    "local_representative",
    "default_branch",
    "privacy",
    "raw_content_inspectable",
    "workflow_family",
    "policy_source",
    "routing_files",
    "special_gates",
    "aliases",
)
IDENTITY_RE = re.compile(r"^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$")


def canonical_identity(remote: str) -> str:
    """Collapse any clone URL form onto `owner/repo`.

    A linked worktree shares its clone's remote, so a worktree and its parent
    checkout always produce the same string. That is the property that keeps
    coverage keyed on repositories instead of folders.
    """
    value = remote.strip().rstrip("/")
    if value.endswith(".git"):
        value = value[: -len(".git")]
    value = re.sub(r"^[a-z][a-z0-9+.-]*://(?:[^/@]+@)?[^/]+/", "", value)
    value = re.sub(r"^[^@/]+@[^:/]+:", "", value)
    parts = [p for p in value.split("/") if p]
    if len(parts) >= 2:
        return f"{parts[-2].lower()}/{parts[-1]}"
    return value.lower()


def load(path: Path) -> dict:
    if not path.is_file():
        raise SystemExit(f"audit-repository-routing: missing required file: {path}")
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:  # fail closed on a corrupt manifest
        raise SystemExit(f"audit-repository-routing: {path.name} is not valid JSON: {exc}")


def audit(coverage: dict, baseline: dict) -> list[str]:
    problems: list[str] = []

    if coverage.get("schema_version") != 1:
        problems.append("coverage schema_version must be 1")
    rows = coverage.get("repositories")
    if not isinstance(rows, list) or not rows:
        return problems + ["coverage manifest has no repositories array"]

    seen: dict[str, int] = {}
    alias_owner: dict[str, str] = {}
    for index, row in enumerate(rows):
        where = f"row {index}"
        for key in REQUIRED_KEYS:
            if key not in row:
                problems.append(f"{where}: missing required key '{key}'")
        identity = row.get("identity", "")
        if not IDENTITY_RE.match(str(identity)):
            problems.append(f"{where}: identity '{identity}' is not owner/repo")
            continue
        where = identity
        if identity in seen:
            problems.append(f"{identity}: duplicate coverage row (also row {seen[identity]})")
        seen[identity] = index
        if row.get("privacy") not in PRIVACY_CLASSES:
            problems.append(f"{where}: unknown privacy class {row.get('privacy')!r}")
        if row.get("workflow_family") not in WORKFLOW_FAMILIES:
            problems.append(f"{where}: unknown workflow family {row.get('workflow_family')!r}")
        if row.get("policy_source") not in POLICY_SOURCES:
            problems.append(f"{where}: unknown policy source {row.get('policy_source')!r}")
        if not isinstance(row.get("routing_files"), list):
            problems.append(f"{where}: routing_files must be a list")
        if not isinstance(row.get("special_gates"), list):
            problems.append(f"{where}: special_gates must be a list")
        privacy = row.get("privacy")
        inspectable = row.get("raw_content_inspectable")
        if privacy in ("private-licensed", "private-transcripts") and inspectable is not False:
            problems.append(
                f"{where}: privacy class {privacy} must set raw_content_inspectable false"
            )
        for alias in row.get("aliases", []) or []:
            if alias in alias_owner and alias_owner[alias] != identity:
                problems.append(f"{where}: alias '{alias}' also claimed by {alias_owner[alias]}")
            alias_owner[alias] = identity
            if alias in seen:
                problems.append(f"{where}: alias '{alias}' is also a coverage row")

    base_rows = {r.get("identity"): r for r in baseline.get("repositories", [])}
    for identity in seen:
        if identity not in base_rows:
            problems.append(f"{identity}: no routing baseline row")
    for identity in base_rows:
        if identity not in seen:
            problems.append(f"{identity}: routing baseline row has no coverage row")

    for identity, base in base_rows.items():
        expected = sum(int(base.get(name, 0) or 0) for name in ROUTER_FILES)
        if int(base.get("router_bytes", -1)) != expected:
            problems.append(
                f"{identity}: router_bytes {base.get('router_bytes')} != {expected} "
                "(sum of AGENTS.md, CLAUDE.md, HANDOFF.md)"
            )
        row = rows[seen[identity]] if identity in seen else {}
        declared = set(row.get("routing_files", []) or [])
        for name in ROUTER_FILES:
            has_bytes = int(base.get(name, 0) or 0) > 0
            if has_bytes and name not in declared:
                problems.append(f"{identity}: baseline has {name} but coverage does not list it")
            if not has_bytes and name in declared:
                problems.append(f"{identity}: coverage lists {name} but baseline measured 0 bytes")

    totals = baseline.get("totals", {})
    if totals.get("repositories") != len(base_rows):
        problems.append("baseline totals.repositories disagrees with the measured rows")
    with_agents = sum(1 for r in base_rows.values() if int(r.get("AGENTS.md", 0) or 0) > 0)
    if totals.get("with_root_agents_md") != with_agents:
        problems.append("baseline totals.with_root_agents_md is stale")
    without = sorted(i for i, r in base_rows.items() if not int(r.get("AGENTS.md", 0) or 0))
    if sorted(totals.get("without_root_agents_md", [])) != without:
        problems.append("baseline totals.without_root_agents_md is stale")
    total_bytes = sum(int(r.get("router_bytes", 0) or 0) for r in base_rows.values())
    if totals.get("router_bytes_total") != total_bytes:
        problems.append(
            f"baseline totals.router_bytes_total {totals.get('router_bytes_total')} != {total_bytes}"
        )
    if base_rows:
        largest = max(int(r.get("router_bytes", 0) or 0) for r in base_rows.values())
        if totals.get("router_bytes_max") != largest:
            problems.append("baseline totals.router_bytes_max is stale")

    return problems


def check_identity(directory: str) -> tuple[str, list[str]]:
    """Resolve one checkout to its canonical identity without reading content."""
    problems: list[str] = []
    try:
        remote = subprocess.run(
            ["git", "-C", directory, "remote", "get-url", "origin"],
            capture_output=True, text=True, check=True,
        ).stdout
    except (subprocess.CalledProcessError, FileNotFoundError):
        return "", [f"{directory}: no origin remote; identity cannot be resolved (fail closed)"]
    return canonical_identity(remote), problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--coverage", default=str(COVERAGE))
    parser.add_argument("--baseline", default=str(BASELINE))
    parser.add_argument(
        "--check-identity",
        metavar="DIR",
        help="resolve one checkout or linked worktree to its canonical identity",
    )
    parser.add_argument("--json", action="store_true", help="machine-readable result")
    args = parser.parse_args()

    coverage = load(Path(args.coverage))
    baseline = load(Path(args.baseline))
    problems = audit(coverage, baseline)

    identity = None
    if args.check_identity:
        identity, extra = check_identity(args.check_identity)
        problems.extend(extra)
        if identity:
            known = {r.get("identity") for r in coverage.get("repositories", [])}
            aliases = {
                a for r in coverage.get("repositories", []) for a in (r.get("aliases") or [])
            }
            if identity not in known and identity not in aliases:
                problems.append(
                    f"{args.check_identity}: resolves to '{identity}', which is not a "
                    "coverage row or alias (fail closed: classify it before use)"
                )

    rows = coverage.get("repositories", [])
    result = {
        "coverage_rows": len(rows),
        "canonical_remotes": len({r.get("identity") for r in rows}),
        "private_rows_metadata_only": sorted(
            r["identity"] for r in rows if r.get("raw_content_inspectable") is False
        ),
        "resolved_identity": identity,
        "problems": problems,
        "ok": not problems,
    }

    if args.json:
        print(json.dumps(result, indent=2, sort_keys=True))
    else:
        print(f"coverage rows        : {result['coverage_rows']}")
        print(f"canonical remotes    : {result['canonical_remotes']}")
        print(f"metadata-only rows   : {', '.join(result['private_rows_metadata_only']) or 'none'}")
        if identity:
            print(f"resolved identity    : {identity}")
        if problems:
            print("\nproblems:")
            for problem in problems:
                print(f"  - {problem}")
        else:
            print("\naudit clean: one row per canonical remote, baseline agrees, no content read")

    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
