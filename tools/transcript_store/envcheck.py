#!/usr/bin/env python3
"""Transcript-store environment check (plan section 12). Stdlib only.

Prints one PASS/FAIL line per check and exits 1 when a check required for
the chosen role fails.

  writer (edge-dev3): Python >= 3.10, sqlite3 with FTS5, Dropbox folder,
                      chat_transcripts/ readable, free local disk >= 10 GB.
  reader (default elsewhere): Python >= 3.10, sqlite3 (FTS5 only needed for
                      --text, reported but not required), Dropbox folder.

On Windows run bin/ai-transcript-envcheck.ps1 first; it needs no Python.
"""

from __future__ import annotations

import argparse
import os
import shutil
import socket
import sqlite3
import sys
from pathlib import Path

MIN_PY = (3, 10)
MIN_FREE_GB = 10


def dropbox_root(override: str | None) -> Path:
    if override:
        return Path(override)
    env = os.environ.get("AI_DROPBOX_ROOT")
    if env:
        return Path(env)
    base = os.environ.get("USERPROFILE") if os.name == "nt" else None
    return Path(base or Path.home()) / "Dropbox"


def fts5_ok() -> tuple[bool, str]:
    try:
        c = sqlite3.connect(":memory:")
        c.execute("CREATE VIRTUAL TABLE t USING fts5(x)")
        c.execute("INSERT INTO t VALUES ('hello world')")
        n = c.execute("SELECT count(*) FROM t WHERE t MATCH 'hello'").fetchone()[0]
        c.close()
        return n == 1, f"sqlite {sqlite3.sqlite_version}"
    except sqlite3.Error as exc:
        return False, f"sqlite {sqlite3.sqlite_version}: {exc}"


def run(role: str, dropbox: Path, free_path: Path) -> list[tuple[str, bool, bool, str]]:
    """Return (check, ok, required, detail) rows."""
    rows = []
    py = sys.version_info[:2]
    rows.append(("python>=3.10", py >= MIN_PY, True, ".".join(map(str, sys.version_info[:3]))))
    ok, detail = fts5_ok()
    rows.append(("sqlite3-fts5", ok, role == "writer", detail))
    rows.append(("dropbox-folder", dropbox.is_dir(), True, str(dropbox)))
    ct = dropbox / "ai" / "chat_transcripts"
    readable = ct.is_dir() and os.access(ct, os.R_OK | os.X_OK)
    if readable:
        try:
            next(iter(os.scandir(ct)), None)
        except OSError:
            readable = False
    rows.append(("chat_transcripts-readable", readable, role == "writer", str(ct)))
    try:
        free_path.mkdir(parents=True, exist_ok=True)
        free = shutil.disk_usage(free_path).free / 1e9
        rows.append(("free-disk>=10GB", free >= MIN_FREE_GB, role == "writer", f"{free:.0f} GB at {free_path}"))
    except OSError as exc:
        rows.append(("free-disk>=10GB", False, role == "writer", str(exc)))
    return rows


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--role", choices=("writer", "reader"), default=None,
                    help="default: writer on edge-dev3, reader elsewhere")
    ap.add_argument("--dropbox", help="Dropbox root (default ~/Dropbox or AI_DROPBOX_ROOT)")
    ap.add_argument("--free-path", help="local path whose free space is checked")
    a = ap.parse_args(argv)
    host = socket.gethostname().split(".")[0].lower()
    role = a.role or ("writer" if host == "edge-dev3" else "reader")
    free_path = Path(a.free_path) if a.free_path else Path.home() / ".local/share/ai-devops"
    rows = run(role, dropbox_root(a.dropbox), free_path)
    failed = False
    print(f"host={host} role={role}")
    for name, ok, required, detail in rows:
        tag = "PASS" if ok else ("FAIL" if required else "WARN")
        failed |= (not ok and required)
        print(f"{tag} {name}: {detail}")
    print("RESULT " + ("FAIL" if failed else "PASS"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
