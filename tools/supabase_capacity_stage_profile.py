"""Closed, source-pinned admission for one Supabase no-restart workflow.

This validates dispatch metadata only. It has no cloud credentials or mutator.
The profile intentionally grants no restart, SQL, arbitrary setting or CLI use.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

REPOSITORY = "popcre/shared-db"
WORKFLOW = "stage-pgss-capacity.yml"
GATE = "supabase-postgres-config-stage-only"
ROOT = Path(__file__).resolve().parent.parent
PROFILE = ROOT / "config/supabase-capacity-stage-profile.json"
SOURCE_FILES = frozenset({
    ".github/workflows/stage-pgss-capacity.yml",
    "scripts/stage_pgss_capacity.py",
    "scripts/pgss-stage-exclusive.mjs",
    "config/pgss-capacity-stage.json",
    "scripts/shared_db_live_proof.py",
})


class Refused(ValueError):
    pass


def object_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise Refused("duplicate JSON key")
        result[key] = value
    return result


def parse(text, limit=8192):
    if len(text.encode("utf-8")) > limit:
        raise Refused("bounded descriptor too large")
    try:
        return json.loads(text, object_pairs_hook=object_pairs)
    except (ValueError, TypeError) as exc:
        raise Refused("invalid bounded JSON") from exc


def qualify(manifest, profile, *, head, main, consumer, blobs, platform):
    if platform != "linux":
        raise Refused("new staging dispatch is qualified only on Linux")
    fields = {"schema_version", "operation", "repository", "workflow", "ref", "head_sha", "work_issue"}
    if not isinstance(manifest, dict) or set(manifest) != fields:
        raise Refused("unknown or missing dispatch field")
    if (type(manifest["schema_version"]) is not int or manifest["schema_version"] != 1
            or manifest["operation"] != "pgss-capacity-stage/v1"
            or manifest["repository"] != REPOSITORY
            or manifest["workflow"] != WORKFLOW or manifest["ref"] != "main"
            or type(manifest["work_issue"]) is not int or manifest["work_issue"] != 5609):
        raise Refused("dispatch is outside the closed staging profile")
    if not re.fullmatch(r"[0-9a-f]{40}", str(head)) or head != main or manifest["head_sha"] != head:
        raise Refused("dispatch is not the freshly proved main")
    if not isinstance(profile, dict) or set(profile) != {"schema_version", "enabled", "repository", "source_files"}:
        raise Refused("invalid installed profile")
    if (type(profile["schema_version"]) is not int or profile["schema_version"] != 1
            or profile["enabled"] is not True or profile["repository"] != REPOSITORY):
        raise Refused("installed staging profile is not enabled")
    pins = profile["source_files"]
    if not isinstance(pins, dict) or set(pins) != SOURCE_FILES or set(blobs) != SOURCE_FILES:
        raise Refused("source pin set differs from the closed profile")
    for name, digest in pins.items():
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise Refused("invalid source digest")
        if hashlib.sha256(blobs[name]).hexdigest() != digest:
            raise Refused("source differs from the installed profile")
    try:
        required = consumer["gates"]["infrastructure"]["required"]
    except (KeyError, TypeError):
        raise Refused("repository has not declared the staging gate") from None
    if (not isinstance(required, list) or any(type(value) is not str for value in required)
            or not {GATE, "reviewed-production-dispatch"}.issubset(required)):
        raise Refused("repository has not declared the staging gate")
    encoded = json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def committed_blob(repo, commit, name):
    # Never resolve replace refs, textconv, filters, symlinks or working bytes.
    env = {
        "PATH": "/usr/bin:/bin",
        "HOME": "/nonexistent",
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": "/dev/null",
        "GIT_NO_REPLACE_OBJECTS": "1",
    }
    item = subprocess.run(["/usr/bin/git", "--no-replace-objects", "-C", str(repo),
                           "ls-tree", commit, "--", name], capture_output=True, env=env, timeout=20)
    if item.returncode or not item.stdout.startswith(b"100644 blob ") or item.stdout.count(b"\n") != 1:
        raise Refused("required committed regular file is absent")
    result = subprocess.run(["/usr/bin/git", "--no-replace-objects", "-C", str(repo),
                             "show", commit + ":" + name], capture_output=True, env=env, timeout=20)
    if result.returncode or len(result.stdout) > 2_000_000:
        raise Refused("committed source cannot be read")
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", required=True, type=Path)
    parser.add_argument("--head", required=True)
    parser.add_argument("--main", required=True)
    args = parser.parse_args()
    try:
        if sys.platform != "linux":
            raise Refused("new staging dispatch is qualified only on Linux")
        if not re.fullmatch(r"[0-9a-f]{40}", args.head) or args.head != args.main:
            raise Refused("dispatch is not the freshly proved main")
        raw = sys.stdin.read(8193)
        manifest = parse(raw)
        profile = parse(PROFILE.read_text(), limit=16384)
        consumer = parse(committed_blob(args.repo, args.head, ".ai-devops/task-gates.json").decode(), limit=65536)
        blobs = {name: committed_blob(args.repo, args.head, name) for name in SOURCE_FILES}
        digest = qualify(manifest, profile, head=args.head, main=args.main,
                         consumer=consumer, blobs=blobs, platform=sys.platform)
        print("pgss-capacity-stage/v1 " + args.head + " " + digest)
        return 0
    except (OSError, UnicodeError, subprocess.SubprocessError, Refused):
        print("Supabase staging admission refused; no production operation is authorized.", file=sys.stderr)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
