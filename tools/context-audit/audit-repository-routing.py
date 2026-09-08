#!/usr/bin/env python3
"""Validate the metadata-only coverage baseline for task-gate rollout."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


REQUIRED_IDS = {
    "popcre/ai-devops", "popcre/designflow-backend", "popcre/designflow-bff",
    "popcre/designflow-data-syncing", "popcre/designflow-frontend",
    "popcre/designflow-item-master", "popcre/designflow-tracking", "u2giants/shared-db",
    "u2giants/theoracle", "u2giants/licensor-source-data", "u2giants/ai-devops-transcripts",
    "u2giants/popcrm-web", "u2giants/poppim-web", "u2giants/popdam3",
    "u2giants/backrest-wiz", "popcre/infrastructure", "u2giants/ansible",
}
PRIVATE_CLASSES = {"private", "private-licensed", "private-transcripts"}


def audit(path: Path, baseline_path: Path | None = None) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    rows = data.get("repositories", [])
    ids = [row.get("id") for row in rows]
    errors = []
    if data.get("schemaVersion") != 1:
        errors.append("schemaVersion must be 1")
    if len(ids) != len(set(ids)):
        errors.append("duplicate repository identity")
    if set(ids) != REQUIRED_IDS:
        errors.append("coverage must contain exactly the 17 canonical repositories")
    for row in rows:
        missing = [key for key in ("id", "defaultBranch", "privacy", "routingFiles", "workflow", "specialGates") if not row.get(key)]
        if missing:
            errors.append(f"{row.get('id', '<unknown>')}: missing {', '.join(missing)}")
        if row.get("privacy") in PRIVATE_CLASSES and any("raw" in value.lower() for value in row.get("routingFiles", [])):
            errors.append(f"{row['id']}: raw private content cannot be an audit surface")
    if baseline_path:
        baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
        baseline_rows = baseline.get("repositories", [])
        baseline_ids = [row.get("id") for row in baseline_rows]
        if baseline.get("schemaVersion") != 1 or set(baseline_ids) != set(ids) or len(baseline_ids) != len(set(baseline_ids)):
            errors.append("routing baseline must account for every canonical repository exactly once")
        coverage_surfaces = {row["id"]: set(row["routingFiles"]) for row in rows}
        for row in baseline_rows:
            if row.get("id") in coverage_surfaces and set(row.get("surfaces", [])) != coverage_surfaces[row["id"]]:
                errors.append(f"{row['id']}: routing baseline surfaces do not match coverage")
            snapshot = row.get("snapshot", [])
            valid = [item for item in snapshot if isinstance(item, list) and len(item) == 4]
            if {item[0] for item in valid} != set(row.get("surfaces", [])):
                errors.append(f"{row.get('id', '<unknown>')}: every routing surface needs a byte, heading, and hash snapshot")
            if any(not isinstance(item[1], int) or item[1] <= 0 or not isinstance(item[2], int) or item[2] <= 0 or not isinstance(item[3], str) or len(item[3]) != 64 for item in valid):
                errors.append(f"{row.get('id', '<unknown>')}: invalid routing snapshot")
    return {"repositoryCount": len(rows), "identities": sorted(ids), "errors": errors}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--coverage", type=Path, default=Path(__file__).resolve().parents[2] / "config" / "repository-coverage.json")
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    report = audit(args.coverage, args.baseline)
    if args.json:
        print(json.dumps(report, sort_keys=True))
    else:
        print(f"canonical repositories: {report['repositoryCount']}")
        for error in report["errors"]:
            print(f"FAIL: {error}")
    return 1 if report["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
