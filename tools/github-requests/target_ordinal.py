#!/usr/bin/env python3
"""Local target-correlation adapter for #658 section 13 item 2.

Assigns a stable positive integer ordinal to each opaque local target key so
same-target re-reads and rewrites can be counted with a denominator without
persisting repository, issue, URL, or raw key text. Hashes mix a machine-local
random salt (same construction as principal hashing); ordinals cannot be
correlated across hosts.

Usage: target_ordinal.py --state-dir DIR --key KEY
Prints one integer ordinal. Any failure prints nothing and exits 3, so callers
must treat the target as uncorrelated rather than invent an ordinal.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile

MAX_MAP = 10000


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("duplicate JSON key")
        result[key] = value
    return result


def unix_private(path, kind, *, owner=None):
    try:
        info = os.lstat(path) if owner is None else os.fstat(owner)
        wanted = stat.S_ISDIR if kind == "directory" else stat.S_ISREG
        if not wanted(info.st_mode):
            return False
        if os.name == "nt":
            # Windows ACLs are enforced by secure-windows-path elsewhere;
            # st_mode bits are not a reliable private-inode predicate here.
            return True
        return (info.st_uid == os.geteuid()
                and not info.st_mode & 0o077
                and (kind == "directory" or info.st_nlink == 1))
    except OSError:
        return False


def ensure_salt(directory: Path) -> bytes:
    salt_path = directory / "target-salt"
    if salt_path.is_symlink() or (salt_path.exists() and not salt_path.is_file()):
        raise OSError("salt path is not a private regular file")
    if not salt_path.exists():
        descriptor, name = tempfile.mkstemp(prefix="target-salt.", dir=directory)
        try:
            if os.name != "nt":
                os.fchmod(descriptor, stat.S_IRUSR | stat.S_IWUSR)
            with os.fdopen(descriptor, "wb") as handle:
                handle.write(os.urandom(32).hex().encode("ascii"))
                handle.flush()
                os.fsync(handle.fileno())
            if salt_path.exists():
                os.unlink(name)
            else:
                os.replace(name, salt_path)
        finally:
            if os.path.exists(name):
                os.unlink(name)
    if not unix_private(salt_path, "file"):
        raise OSError("salt is not a private regular file")
    salt = salt_path.read_bytes()
    if not re.fullmatch(rb"[0-9a-f]{64}", salt):
        raise OSError("salt has the wrong shape")
    return salt


def load_map(path: Path) -> dict:
    if path.is_symlink() or (path.exists() and not path.is_file()):
        raise OSError("map path is not a private regular file")
    if not path.exists():
        return {"next": 1, "map": {}}
    if not unix_private(path, "file"):
        raise OSError("map is not a private regular file")
    if path.stat().st_size > 2_000_000:
        raise OSError("map is too large")
    row = json.loads(path.read_bytes().decode("utf-8"), object_pairs_hook=unique_object)
    if (not isinstance(row, dict) or set(row) != {"next", "map"}
            or type(row["next"]) is not int or not 1 <= row["next"] <= 1_000_000_000
            or not isinstance(row["map"], dict)):
        raise ValueError("invalid ordinal map")
    cleaned = {}
    for key, value in row["map"].items():
        if (not isinstance(key, str) or re.fullmatch(r"[0-9a-f]{16}", key) is None
                or type(value) is not int or not 1 <= value <= 1_000_000_000):
            raise ValueError("invalid ordinal map entry")
        cleaned[key] = value
    return {"next": row["next"], "map": cleaned}


def save_map(path: Path, row: dict) -> None:
    payload = json.dumps(row, separators=(",", ":"), sort_keys=True).encode("utf-8")
    descriptor, name = tempfile.mkstemp(prefix=".target-map-", dir=path.parent)
    try:
        if os.name != "nt":
            os.fchmod(descriptor, stat.S_IRUSR | stat.S_IWUSR)
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(payload)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def ordinal_for(directory: Path, key: str) -> int:
    if not isinstance(key, str) or not key or len(key) > 4096:
        raise ValueError("invalid target key")
    if not directory.exists():
        directory.mkdir(parents=True, mode=0o700, exist_ok=True)
    if os.name != "nt" and not unix_private(directory, "directory"):
        raise OSError("state directory is not private")
    salt = ensure_salt(directory)
    digest = hashlib.sha256(salt + b"\x00" + key.encode("utf-8")).hexdigest()[:16]
    row = load_map(directory / "target-ordinals.json")
    if digest in row["map"]:
        return row["map"][digest]
    if len(row["map"]) >= MAX_MAP:
        # Bound private metadata: drop the lowest ordinals first so recent
        # same-target traffic keeps its identity within one measurement window.
        for stale in sorted(row["map"], key=row["map"].get)[: MAX_MAP // 10]:
            del row["map"][stale]
    ordinal = row["next"]
    if ordinal > 1_000_000_000:
        raise ValueError("ordinal space exhausted")
    row["map"][digest] = ordinal
    row["next"] = ordinal + 1
    save_map(directory / "target-ordinals.json", row)
    return ordinal


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--state-dir", required=True)
    parser.add_argument("--key", required=True)
    args = parser.parse_args()
    directory = Path(args.state_dir)
    if directory.is_symlink() or not directory.is_dir():
        return 3
    if os.name != "nt":
        if not unix_private(directory, "directory"):
            return 3
    try:
        ordinal = ordinal_for(directory, args.key)
    except (OSError, ValueError, TypeError, KeyError, RecursionError, json.JSONDecodeError):
        return 3
    sys.stdout.write(str(ordinal))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
