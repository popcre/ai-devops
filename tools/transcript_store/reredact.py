#!/usr/bin/env python3
"""One-shot re-redaction pass over published segment text (#2367 step 5.3).

build.py applies redact_patterns.tsv when a segment is CREATED; text
summarised before a pattern existed is never revisited (unchanged sessions
are skipped forever, and nothing re-redacts stored rows). This tool re-applies
the CURRENT patterns to the PUBLISHED store only — the writer (edge-dev3),
its working db and the raw archive are untouched:

    read CURRENT.json -> copy its db to db/store-<utc stamp>.db (a dated file
    is never mutated) -> UPDATE segments.subject / segments.text wherever a
    pattern now bites, in file order with the same ``[REDACTED:<kind>]``
    markers as ``normalize.redact`` (segment ids unchanged; the segments_fts
    row is rebuilt) -> repoint CURRENT.json atomically (dot-named temp +
    rename, exactly as build.publish does).

sessions, chunks, seen_turns, meta and machine_status are not modified.

Guards: refuses to run when CURRENT.json's ``built`` stamp is less than 2 h
old (writer-race window), when the referenced db file is missing, or when the
file does not match the pointer's sha256. ``--dry-run`` reports the counts and
the affected segment ids without writing anything.

    reredact.py [--store-root DIR] [--dry-run]
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shutil
import sqlite3
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import build  # noqa: E402  (utc_stamp, edt_now, sha256_file, DEFAULT_STORE_ROOT)
import normalize  # noqa: E402

WRITER_QUIET_SECONDS = 2 * 3600


def parse_built(value: str) -> float:
    """Epoch seconds for build.py's ``built`` stamp.

    Normal shape: ``2026-11-08 08:00 AM EST`` — an America/New_York wall
    clock plus an EDT/EST token (the wall clock already carries DST, so the
    token itself is dropped). The ``iso_now`` fallback is accepted too.
    """
    v = value.strip()
    try:
        t = dt.datetime.fromisoformat(v)
        return t.timestamp() if t.tzinfo else t.replace(tzinfo=dt.timezone.utc).timestamp()
    except ValueError:
        pass
    clock = dt.datetime.strptime(v.rsplit(" ", 1)[0], "%Y-%m-%d %I:%M %p")
    try:
        from zoneinfo import ZoneInfo
        return clock.replace(tzinfo=ZoneInfo("America/New_York")).timestamp()
    except Exception:
        return clock.replace(tzinfo=dt.timezone.utc).timestamp()


def scrub(conn) -> dict:
    """Plan the re-redaction: per-kind replacement totals plus, for every
    segment whose stored subject/text changes, the rewritten values.

    Patterns run in redact_patterns.tsv file order over each field — the
    same sequence and markers as ``normalize.redact`` — so parity with the
    writer is exact; per-kind attribution falls out of the loop.
    """
    pats = normalize.load_patterns()
    by_kind: dict[str, int] = {}
    affected = []
    total = 0
    for rowid, sid, subject, text in conn.execute("SELECT rowid, id, subject, text FROM segments"):
        total += 1
        new: dict[str, str | None] = {"subject": subject, "text": text}
        seg_kinds: dict[str, int] = {}
        for field in ("subject", "text"):
            out = new[field]
            if out is None:
                continue
            for kind, rx in pats:
                out, n = rx.subn(f"[REDACTED:{kind}]", out)
                if n:
                    by_kind[kind] = by_kind.get(kind, 0) + n
                    seg_kinds[kind] = seg_kinds.get(kind, 0) + n
            new[field] = out
        if new["subject"] != subject or new["text"] != text:
            affected.append({"rowid": rowid, "id": sid, "subject": new["subject"],
                             "text": new["text"], "by_kind": seg_kinds})
    return {"segments": total, "by_kind": by_kind, "affected": affected}


def apply_plan(conn, plan: dict) -> str:
    """Write the planned updates into the copied db; return integrity_check."""
    with conn:
        for a in plan["affected"]:
            conn.execute("UPDATE segments SET subject=?, text=? WHERE id=?",
                         (a["subject"], a["text"], a["id"]))
            conn.execute("DELETE FROM segments_fts WHERE rowid=?", (a["rowid"],))
            conn.execute("INSERT INTO segments_fts(rowid, subject, text) VALUES (?,?,?)",
                         (a["rowid"], a["subject"], a["text"]))
    return conn.execute("PRAGMA integrity_check").fetchone()[0]


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Re-redact stored segment text in the published transcript store.")
    ap.add_argument("--store-root", type=Path, default=build.DEFAULT_STORE_ROOT)
    ap.add_argument("--dry-run", action="store_true", help="report counts and affected ids; write nothing")
    a = ap.parse_args(argv)

    ptr_path = a.store_root / "CURRENT.json"
    try:
        ptr = json.loads(ptr_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise SystemExit(f"no CURRENT.json under {a.store_root}") from None
    src = a.store_root / ptr["file"]
    if not src.is_file():
        raise SystemExit(f"published db missing: {ptr['file']}")
    built_age = time.time() - parse_built(ptr["built"])
    if built_age < WRITER_QUIET_SECONDS:
        raise SystemExit(f"published store built less than 2 h ago ({ptr['built']}); retry after the writer-race window")
    if build.sha256_file(src) != ptr.get("sha256"):
        raise SystemExit(f"published db does not match CURRENT.json sha256: {ptr['file']}")

    conn = sqlite3.connect(f"file:{src}?mode=ro", uri=True)
    try:
        plan = scrub(conn)
    finally:
        conn.close()
    result = {"source": ptr["file"], "built": ptr["built"], "segments": plan["segments"],
              "changed": len(plan["affected"]), "by_kind": plan["by_kind"],
              "affected": [{"id": x["id"], "by_kind": x["by_kind"]} for x in plan["affected"]]}
    if a.dry_run:
        result["dry_run"] = True
        print(json.dumps(result, indent=1))
        return 0
    if not plan["affected"]:
        result["file"] = ptr["file"]  # nothing to scrub: no new db, pointer untouched
        print(json.dumps(result, indent=1))
        return 0

    stamp = build.utc_stamp()
    dest = a.store_root / "db" / f"store-{stamp}.db"
    if dest.exists():
        raise SystemExit(f"target db already exists: {dest.name}")
    shutil.copyfile(src, dest)
    conn = sqlite3.connect(dest)
    try:
        check = apply_plan(conn, plan)
        if check != "ok":
            raise RuntimeError(f"integrity_check failed: {check}")
        conn.execute("PRAGMA journal_mode=DELETE")
    finally:
        conn.close()

    size, digest = dest.stat().st_size, build.sha256_file(dest)
    pointer = {"file": f"db/{dest.name}", "sha256": digest, "size": size,
               "built": build.edt_now(), "schema": ptr.get("schema", build.SCHEMA_VERSION)}
    # Dot-named sibling readers never follow, then rename over the old pointer
    # so a reader never sees a half-written CURRENT.json (build.publish).
    incoming = a.store_root / f".incoming-CURRENT-{stamp}.json"
    incoming.write_text(json.dumps(pointer), encoding="utf-8")
    os.replace(incoming, a.store_root / "CURRENT.json")
    result.update({"file": pointer["file"], "sha256": digest, "size": size, "built": pointer["built"]})
    print(json.dumps(result, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
