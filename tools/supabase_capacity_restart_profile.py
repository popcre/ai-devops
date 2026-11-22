"""Closed, source-pinned admission for the #5609 Supabase capacity+restart workflow.

Validates dispatch metadata and committed source hashes only. Holds no cloud
credentials or mutator. Supports Linux and Windows callers.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

REPOSITORY = "popcre/shared-db"
WORKFLOW = "apply-pgss-capacity-restart.yml"
GATE = "supabase-postgres-config-capacity-restart"
ALLOWED_MODES = frozenset({"preview_only", "preview_and_production"})
ALLOWED_PLATFORMS = frozenset({"linux", "win32", "cygwin", "msys"})
ROOT = Path(__file__).resolve().parent.parent
PROFILE = ROOT / "config/supabase-capacity-restart-profile.json"
SOURCE_FILES = frozenset({
    ".github/workflows/apply-pgss-capacity-restart.yml",
    "scripts/apply_pgss_capacity_restart.py",
    "scripts/pgss-restart-exclusive.mjs",
    "scripts/gh-read.mjs",
    "scripts/lib/claim-recovery-dependencies.mjs",
    "config/pgss-capacity-restart.json",
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
    if platform not in ALLOWED_PLATFORMS:
        raise Refused("unsupported platform for capacity-restart dispatch")
    fields = {"schema_version", "operation", "repository", "workflow", "ref", "head_sha", "work_issue", "mode"}
    if not isinstance(manifest, dict) or set(manifest) != fields:
        raise Refused("unknown or missing dispatch field")
    if (
        type(manifest["schema_version"]) is not int
        or manifest["schema_version"] != 1
        or manifest["operation"] != "pgss-capacity-restart/v1"
        or manifest["repository"] != REPOSITORY
        or manifest["workflow"] != WORKFLOW
        or manifest["ref"] != "main"
        or type(manifest["work_issue"]) is not int
        or manifest["work_issue"] != 5609
        or manifest["mode"] not in ALLOWED_MODES
    ):
        raise Refused("dispatch is outside the closed capacity-restart profile")
    if not re.fullmatch(r"[0-9a-f]{40}", str(head)) or head != main or manifest["head_sha"] != head:
        raise Refused("dispatch is not the freshly proved main")
    if not isinstance(profile, dict) or set(profile) != {"schema_version", "enabled", "repository", "workflow", "source_files"}:
        raise Refused("invalid installed profile")
    if (
        type(profile["schema_version"]) is not int
        or profile["schema_version"] != 1
        or profile["enabled"] is not True
        or profile["repository"] != REPOSITORY
        or profile["workflow"] != WORKFLOW
    ):
        raise Refused("installed capacity-restart profile is not enabled")
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
        raise Refused("repository has not declared the capacity-restart gate") from None
    if (
        not isinstance(required, list)
        or any(type(value) is not str for value in required)
        or not {GATE, "reviewed-production-dispatch"}.issubset(required)
    ):
        raise Refused("repository has not declared the capacity-restart gate")
    encoded = json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def _git_bin():
    if sys.platform == "linux" and Path("/usr/bin/git").is_file():
        return "/usr/bin/git"
    found = shutil.which("git")
    if not found:
        raise Refused("git executable unavailable")
    return found


def committed_blob(repo, commit, name):
    # Never resolve replace refs, textconv, filters, symlinks or working bytes.
    env = {
        "PATH": os.environ.get("PATH", "/usr/bin:/bin") if sys.platform != "linux" else "/usr/bin:/bin",
        "GIT_CONFIG_NOSYSTEM": "1",
        "GIT_CONFIG_GLOBAL": os.devnull,
        "GIT_NO_REPLACE_OBJECTS": "1",
        "GIT_TERMINAL_PROMPT": "0",
    }
    if sys.platform != "linux":
        for key in ("SYSTEMROOT", "WINDIR", "COMSPEC", "TEMP", "TMP"):
            if key in os.environ:
                env[key] = os.environ[key]
    else:
        env["HOME"] = "/nonexistent"
    git = _git_bin()
    item = subprocess.run(
        [git, "--no-replace-objects", "-C", str(repo), "ls-tree", commit, "--", name],
        capture_output=True, env=env, timeout=20,
    )
    if item.returncode or not item.stdout.startswith(b"100644 blob ") or item.stdout.count(b"\n") != 1:
        raise Refused("required committed regular file is absent")
    result = subprocess.run(
        [git, "--no-replace-objects", "-C", str(repo), "show", commit + ":" + name],
        capture_output=True, env=env, timeout=20,
    )
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
        if sys.platform not in ALLOWED_PLATFORMS:
            raise Refused("unsupported platform for capacity-restart dispatch")
        if not re.fullmatch(r"[0-9a-f]{40}", args.head) or args.head != args.main:
            raise Refused("dispatch is not the freshly proved main")
        manifest = parse(sys.stdin.read(8193))
        profile = parse(PROFILE.read_text(encoding="utf-8"), limit=65536)
        consumer = parse(committed_blob(args.repo, args.head, ".ai-devops/task-gates.json").decode("utf-8"), limit=65536)
        blobs = {name: committed_blob(args.repo, args.head, name) for name in SOURCE_FILES}
        digest = qualify(
            manifest, profile, head=args.head, main=args.main,
            consumer=consumer, blobs=blobs, platform=sys.platform,
        )
        print(f"pgss-capacity-restart/v1:{manifest['mode']}:{digest[:16]}")
        return 0
    except Refused as err:
        print(f"ai-task-gates: STOP. {err}", file=sys.stderr)
        return 2
    except Exception:
        print("ai-task-gates: STOP. capacity-restart admission refused", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
