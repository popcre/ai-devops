#!/usr/bin/env python3
"""Read protocol for the published transcript store (plan step 4, used by
step 8's ``bin/ai-transcript-query``). Python 3.10+, stdlib only.

SQLite never opens a file inside Dropbox: the reader copies the published
file to a local cache, verifies it, then opens the copy read-only.

API
---
``open_store(store_root=None, cache_dir=None, sleep=time.sleep) -> sqlite3.Connection``
    Follow ``<store_root>/CURRENT.json`` and return a read-only connection
    (``mode=ro``) to a verified local copy. The connection has attribute-like
    info in ``last_open_info()``. Raises ``StoreUnavailable`` (message is the
    user-facing text) when no usable copy exists.

``fetch_store(store_root=None, cache_dir=None, sleep=time.sleep) -> OpenInfo``
    Same protocol without opening; returns ``OpenInfo(path, sha256, source,
    fallback)`` where ``path`` is the verified local copy and ``fallback`` is
    True when an older version was used because the current one did not
    verify.

``StoreUnavailable``  exception; ``str(exc)`` is safe to print.
``default_store_root()`` / ``default_cache_dir()``  platform defaults
    (``AI_TRANSCRIPT_STORE_ROOT`` / ``AI_TRANSCRIPT_STORE_CACHE`` override).

Protocol: re-read an unparsable pointer every 5 s up to 3 times; a missing,
unparsable or placeholder (0-byte or unreadable) pointer stops with
``NOT_AVAILABLE``. A size/sha256 mismatch waits 30 s and retries once, then
falls back to the newest older ``db/store-*.db`` that passes
``PRAGMA integrity_check``. A cached copy is reused while its sha256 matches
the pointer; older cached copies are deleted when a newer one is fetched.
"""

from __future__ import annotations

import hashlib
import json
import os
import shutil
import sqlite3
import tempfile
import time
from dataclasses import dataclass
from pathlib import Path

NOT_AVAILABLE = ("store not available locally; open Dropbox and make "
                 "`ai/transcript-store` available offline")
POINTER_RETRIES = 3
POINTER_WAIT = 5
MISMATCH_WAIT = 30


class StoreUnavailable(Exception):
    pass


@dataclass
class OpenInfo:
    path: Path
    sha256: str
    source: str
    fallback: bool


def default_store_root() -> Path:
    env = os.environ.get("AI_TRANSCRIPT_STORE_ROOT")
    if env:
        return Path(env)
    base = Path(os.environ.get("USERPROFILE") or Path.home()) if os.name == "nt" else Path.home()
    return base / "Dropbox" / "ai" / "transcript-store"


def default_cache_dir() -> Path:
    env = os.environ.get("AI_TRANSCRIPT_STORE_CACHE")
    if env:
        return Path(env)
    return Path(tempfile.gettempdir()) / "ai-transcript-store-cache"


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def read_pointer(store_root: Path, sleep=time.sleep) -> dict:
    ptr = store_root / "CURRENT.json"
    for attempt in range(POINTER_RETRIES + 1):
        try:
            if ptr.stat().st_size == 0:
                raise StoreUnavailable(NOT_AVAILABLE)  # Smart Sync placeholder
            data = json.loads(ptr.read_text(encoding="utf-8"))
            if isinstance(data, dict) and isinstance(data.get("file"), str) \
                    and isinstance(data.get("sha256"), str) and isinstance(data.get("size"), int):
                return data
        except FileNotFoundError:
            raise StoreUnavailable(NOT_AVAILABLE) from None
        except (OSError, ValueError, UnicodeDecodeError):
            pass
        if attempt < POINTER_RETRIES:
            sleep(POINTER_WAIT)
    raise StoreUnavailable(NOT_AVAILABLE)


def _safe_target(store_root: Path, rel: str) -> Path:
    if rel.startswith(("/", "\\")) or ".." in rel.replace("\\", "/").split("/") or not rel.startswith("db/"):
        raise StoreUnavailable("CURRENT.json names a file outside db/")
    return store_root / rel


def _copy_verified(src: Path, cache_dir: Path, size: int | None, digest: str | None) -> Path | None:
    """Copy ``src`` into the cache; return the copy if it verifies."""
    try:
        if size is not None and src.stat().st_size != size:
            return None
        cache_dir.mkdir(parents=True, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=cache_dir, suffix=".part")
        os.close(fd)
        shutil.copyfile(src, tmp)
    except OSError:
        return None
    tmp = Path(tmp)
    got = _sha256(tmp)
    ok = (size is None or tmp.stat().st_size == size) and (digest is None or got == digest)
    if ok and digest is None:
        ok = _integrity_ok(tmp)
    if not ok:
        tmp.unlink(missing_ok=True)
        return None
    final = cache_dir / f"store-{got}.db"
    os.replace(tmp, final)
    return final


def _integrity_ok(path: Path) -> bool:
    try:
        c = sqlite3.connect(f"file:{path.as_posix()}?mode=ro", uri=True)
        try:
            return c.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
        finally:
            c.close()
    except sqlite3.DatabaseError:
        return False


def _prune_cache(cache_dir: Path, keep: Path) -> None:
    for p in cache_dir.glob("store-*.db"):
        if p != keep:
            p.unlink(missing_ok=True)


def fetch_store(store_root: Path | None = None, cache_dir: Path | None = None, sleep=time.sleep) -> OpenInfo:
    store_root = Path(store_root or default_store_root())
    cache_dir = Path(cache_dir or default_cache_dir())
    ptr = read_pointer(store_root, sleep=sleep)
    target = _safe_target(store_root, ptr["file"])
    cached = cache_dir / f"store-{ptr['sha256']}.db"
    if cached.exists() and _sha256(cached) == ptr["sha256"]:
        return OpenInfo(cached, ptr["sha256"], ptr["file"], False)
    for attempt in range(2):
        got = _copy_verified(target, cache_dir, ptr["size"], ptr["sha256"])
        if got:
            _prune_cache(cache_dir, got)
            return OpenInfo(got, ptr["sha256"], ptr["file"], False)
        if attempt == 0:
            sleep(MISMATCH_WAIT)  # Dropbox may still be syncing
    older = sorted((p for p in (store_root / "db").glob("store-*.db")
                    if p.name < target.name and "conflicted copy" not in p.name), reverse=True)
    for p in older:
        got = _copy_verified(p, cache_dir, None, None)
        if got:
            _prune_cache(cache_dir, got)
            return OpenInfo(got, _sha256(got), f"db/{p.name}", True)
    raise StoreUnavailable(NOT_AVAILABLE)


def open_store(store_root: Path | None = None, cache_dir: Path | None = None, sleep=time.sleep) -> sqlite3.Connection:
    info = fetch_store(store_root, cache_dir, sleep)
    conn = sqlite3.connect(f"file:{info.path.as_posix()}?mode=ro", uri=True)
    global _LAST
    _LAST = info
    return conn


_LAST: OpenInfo | None = None


def last_open_info() -> OpenInfo | None:
    """The ``OpenInfo`` of the most recent ``open_store`` call."""
    return _LAST
