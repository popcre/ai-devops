#!/usr/bin/env python3
"""The single transcript-store writer (plan step 4). Runs on edge-dev3 only.

Issue popcre/ai-devops#2050 (stage B, #2060). Python 3.10+, stdlib only.

Flow per run: scan the raw archive -> normalize changed sessions -> chunk new
turns -> label chunks with ScaleDown -> insert segments -> apply the inbox ->
publish a versioned read-only copy plus ``CURRENT.json`` into Dropbox.

The working database lives outside Dropbox (default
``~/.local/share/ai-devops/transcript-store/store.db``); SQLite never opens a
file inside Dropbox. The ScaleDown key comes from ``SCALEDOWN_API_KEY``.

    build.py [--limit-calls N] [--threads 6] [--no-publish]
    build.py --relabel --prompt v2      # re-chunk + relabel, then swap
    build.py --import-labels labels.db  # review labels -> question_labels
    build.py --stats                    # counts only
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import re
import shutil
import sqlite3
import sys
import tempfile
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import normalize  # noqa: E402
import segment  # noqa: E402

SCHEMA_VERSION = 1
HOME = Path.home()
DEFAULT_DB = HOME / ".local/share/ai-devops/transcript-store/store.db"
DEFAULT_ARCHIVE = HOME / "Dropbox/ai/chat_transcripts"
DEFAULT_STORE_ROOT = HOME / "Dropbox/ai/transcript-store"
INBOX_NAME_RX = re.compile(r"^[a-z0-9-]{1,40}__[0-9]{8}T[0-9]{6}Z__[a-z0-9-]{1,30}\.jsonl$")
INBOX_MAX_BYTES = 5 * 1024 * 1024
INBOX_MAX_LINES = 20_000
INBOX_MAX_LINE = 8 * 1024
INBOX_KEYS = {"question", "src", "prompt_version", "fields"}
RETENTION_DAYS = 90
KEEP_VERSIONS = 3
CONFLICT = "conflicted copy"

SCHEMA = """
CREATE TABLE IF NOT EXISTS sessions (
  path TEXT PRIMARY KEY, machine TEXT, session_id TEXT, lineage_id TEXT,
  lineage_key TEXT, repo TEXT, cwd TEXT, first_ts TEXT, last_ts TEXT,
  mtime REAL, size INTEGER, bytes_parsed INTEGER, bad_lines INTEGER DEFAULT 0,
  redactions INTEGER DEFAULT 0, status TEXT);
CREATE INDEX IF NOT EXISTS sessions_lineage ON sessions(lineage_key);
CREATE TABLE IF NOT EXISTS chunks (
  chunk_id TEXT PRIMARY KEY, lineage_id TEXT, path TEXT, first_turn_key TEXT,
  last_turn_key TEXT, turn_keys_json TEXT, chars INTEGER, tool_seq_json TEXT,
  status TEXT, attempts INTEGER DEFAULT 0, error TEXT, prompt_version TEXT,
  created TEXT);
CREATE INDEX IF NOT EXISTS chunks_path ON chunks(path);
CREATE TABLE IF NOT EXISTS segments (
  id TEXT PRIMARY KEY, chunk_id TEXT, section_no INTEGER, path TEXT,
  topic_slugs TEXT, subject TEXT, repo TEXT, repo_hint TEXT, text TEXT,
  label_flags TEXT, prompt_version TEXT, created TEXT);
CREATE INDEX IF NOT EXISTS segments_chunk ON segments(chunk_id);
CREATE VIRTUAL TABLE IF NOT EXISTS segments_fts USING fts5(subject, text);
CREATE TABLE IF NOT EXISTS seen_turns (
  lineage_id TEXT, turn_hash TEXT, occurrence_no INTEGER, chunk_id TEXT,
  PRIMARY KEY (lineage_id, turn_hash, occurrence_no));
CREATE TABLE IF NOT EXISTS question_labels (
  question TEXT, src TEXT, prompt_version TEXT, fields_json TEXT, created TEXT);
CREATE TABLE IF NOT EXISTS inbox_applied (filename TEXT PRIMARY KEY, sha256 TEXT, applied TEXT);
CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT);
"""


def utc_stamp(now: float | None = None) -> str:
    return dt.datetime.fromtimestamp(now if now is not None else time.time(), dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def iso_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def edt_now() -> str:
    try:
        from zoneinfo import ZoneInfo
        t = dt.datetime.now(ZoneInfo("America/New_York"))
        return t.strftime("%Y-%m-%d %I:%M %p ") + (t.tzname() or "ET")
    except Exception:
        return iso_now()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(db_path)
    conn.executescript(SCHEMA)
    conn.execute("INSERT OR IGNORE INTO meta VALUES ('schema_version', ?)", (str(SCHEMA_VERSION),))
    conn.commit()
    return conn


def meta_get(conn, key, default=None):
    row = conn.execute("SELECT value FROM meta WHERE key=?", (key,)).fetchone()
    return row[0] if row else default


def meta_set(conn, key, value):
    conn.execute("INSERT OR REPLACE INTO meta VALUES (?, ?)", (key, value))


# ---------------------------------------------------------------- scanning

def scan_archive(archive: Path):
    """Yield (abs path, rel path, machine) for every eligible ``.jsonl``."""
    if not archive.is_dir():
        return
    for root, dirs, files in os.walk(archive):
        dirs[:] = sorted(d for d in dirs if d != ".partial" and CONFLICT not in d)
        for name in sorted(files):
            if not name.endswith(".jsonl") or CONFLICT in name or name == ".upload-last.txt":
                continue
            p = Path(root) / name
            rel = p.relative_to(archive).as_posix()
            yield p, rel, rel.split("/", 1)[0]


# ---------------------------------------------------------------- sessions

class Budget:
    """Shared ScaleDown call budget (``--limit-calls``); None = unlimited."""

    def __init__(self, limit: int | None):
        self.limit, self.used, self.lock = limit, 0, threading.Lock()

    def take(self) -> bool:
        with self.lock:
            if self.limit is not None and self.used >= self.limit:
                return False
            self.used += 1
            return True


class BudgetExhausted(segment.ScaleDownError):
    no_retry = True


class Runner:
    def __init__(self, conn, call, prompt_version="v1", threads=6, budget=None,
                 now=None, sleep=time.sleep, tables=None):
        self.conn, self.call, self.pv, self.threads = conn, call, prompt_version, threads
        self.budget = budget or Budget(None)
        self.now = now if now is not None else time.time()
        self.sleep = sleep
        self.prompt = segment.load_prompt(prompt_version) if call else ""
        self.aliases = segment.load_aliases()
        self.t = tables or {"chunks": "chunks", "segments": "segments", "seen": "seen_turns"}
        self.stats = {"sessions_scanned": 0, "sessions_processed": 0, "sessions_skipped": 0,
                      "chunks_ok": 0, "chunks_failed": 0, "chunks_pending": 0, "calls": 0,
                      "segments": 0, "reasked_chunks": 0, "bad_lines": 0}

    # lineage -------------------------------------------------------------
    def lineage_for(self, path: str, parsed: dict) -> tuple[str, str]:
        key = normalize.lineage_key(parsed["turns"])
        own = self.conn.execute("SELECT lineage_id, lineage_key FROM sessions WHERE path=?", (path,)).fetchone()
        if own and own[1] == key and own[0]:
            return own[0], key
        row = self.conn.execute(
            "SELECT lineage_id FROM sessions WHERE lineage_key=? AND path<>? ORDER BY first_ts LIMIT 1",
            (key, path)).fetchone()
        if row and parsed["turns"]:
            return row[0], key
        return parsed["meta"]["session_id"], key

    def drop_lineage(self, lineage_id: str):
        t = self.t
        ids = [r[0] for r in self.conn.execute(f"SELECT chunk_id FROM {t['chunks']} WHERE lineage_id=?", (lineage_id,))]
        self._delete_segments_for(ids)
        self.conn.execute(f"DELETE FROM {t['chunks']} WHERE lineage_id=?", (lineage_id,))
        self.conn.execute(f"DELETE FROM {t['seen']} WHERE lineage_id=?", (lineage_id,))
        self.conn.execute("UPDATE sessions SET mtime=0, size=-1 WHERE lineage_id=?", (lineage_id,))

    def _delete_segments_for(self, chunk_ids):
        seg = self.t["segments"]
        for cid in chunk_ids:
            if seg == "segments":
                self.conn.execute("DELETE FROM segments_fts WHERE rowid IN (SELECT rowid FROM segments WHERE chunk_id=?)", (cid,))
            self.conn.execute(f"DELETE FROM {seg} WHERE chunk_id=?", (cid,))

    # one session -----------------------------------------------------------
    def needs_work(self, rel: str, st) -> bool:
        row = self.conn.execute("SELECT mtime, size, status FROM sessions WHERE path=?", (rel,)).fetchone()
        if row is None or row[0] != st.st_mtime or row[1] != st.st_size or row[2] != "ok":
            return True
        open_chunks = self.conn.execute(
            f"SELECT 1 FROM {self.t['chunks']} WHERE path=? AND status<>'ok' LIMIT 1", (rel,)).fetchone()
        return open_chunks is not None

    def process(self, abspath: Path, rel: str, machine: str) -> None:
        st = abspath.stat()
        self.stats["sessions_scanned"] += 1
        if not self.needs_work(rel, st):
            self.stats["sessions_skipped"] += 1
            return
        old = self.conn.execute("SELECT bytes_parsed, lineage_id FROM sessions WHERE path=?", (rel,)).fetchone()
        if old and old[0] is not None and st.st_size < old[0]:
            self.drop_lineage(old[1])  # shrunk or rotated: reprocess from byte 0
            self.conn.commit()
        parsed = normalize.parse_file(abspath, machine=machine, rel_path=rel)
        self.stats["bad_lines"] += parsed["bad_lines"]
        lineage_id, lkey = self.lineage_for(rel, parsed)
        m = parsed["meta"]
        status = "partial" if parsed["truncated_tail"] else "new"
        self.conn.execute(
            "INSERT OR REPLACE INTO sessions (path, machine, session_id, lineage_id, lineage_key, repo, cwd,"
            " first_ts, last_ts, mtime, size, bytes_parsed, bad_lines, redactions, status)"
            " VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (rel, machine, m["session_id"], lineage_id, lkey, m["repo"], m["cwd"], m["first_ts"],
             m["last_ts"], st.st_mtime, st.st_size, parsed["bytes_parsed"], parsed["bad_lines"],
             parsed["redactions"], status))
        self.stats["sessions_processed"] += 1
        ok = self.segment_session(rel, lineage_id, m["repo"], parsed["turns"], st.st_mtime)
        final = "partial" if parsed["truncated_tail"] else ("ok" if ok else "failed")
        self.conn.execute("UPDATE sessions SET status=? WHERE path=?", (final, rel))
        self.conn.commit()

    def segment_session(self, rel, lineage_id, repo, turns, mtime) -> bool:
        t = self.t
        # pending chunks were never sent: release their turns and rechunk
        pend = [r[0] for r in self.conn.execute(
            f"SELECT chunk_id FROM {t['chunks']} WHERE path=? AND status='pending'", (rel,))]
        for cid in pend:
            self.conn.execute(f"DELETE FROM {t['seen']} WHERE chunk_id=?", (cid,))
            self.conn.execute(f"DELETE FROM {t['chunks']} WHERE chunk_id=?", (cid,))
        by_key = {segment.turn_key_str(lineage_id, x): x for x in turns}
        seen = set()
        for h, o in self.conn.execute(f"SELECT turn_hash, occurrence_no FROM {t['seen']} WHERE lineage_id=?", (lineage_id,)):
            seen.add(f"{lineage_id}:{h}:{o}")
        new_records = [(k, x) for k, x in by_key.items() if k not in seen]
        new_chunks = segment.make_chunks(lineage_id, new_records, self.pv)
        hold = segment.hold_tail(new_chunks, mtime, self.now)
        created = iso_now()
        for i, ch in enumerate(new_chunks):
            status = "pending" if (hold and i == len(new_chunks) - 1) else "sending"
            self.conn.execute(
                f"INSERT OR REPLACE INTO {t['chunks']} (chunk_id, lineage_id, path, first_turn_key, last_turn_key,"
                " turn_keys_json, chars, tool_seq_json, status, attempts, error, prompt_version, created)"
                " VALUES (?,?,?,?,?,?,?,?,?,0,NULL,?,?)",
                (ch["chunk_id"], lineage_id, rel, ch["first_turn_key"], ch["last_turn_key"],
                 json.dumps(ch["turn_keys"]), ch["chars"], json.dumps(ch["tool_seq"]), status, self.pv, created))
            for k in ch["turn_keys"]:
                _, h, o = k.rsplit(":", 2)
                self.conn.execute(f"INSERT OR IGNORE INTO {t['seen']} VALUES (?,?,?,?)", (lineage_id, h, int(o), ch["chunk_id"]))
        self.conn.commit()
        # resend every sending/failed chunk of this file with its stored turn range
        todo = []
        for cid, keys_json in self.conn.execute(
                f"SELECT chunk_id, turn_keys_json FROM {t['chunks']} WHERE path=? AND status IN ('sending','failed')"
                " ORDER BY created, first_turn_key", (rel,)).fetchall():
            keys = json.loads(keys_json)
            recs = [(k, by_key[k]) for k in keys if k in by_key]
            if len(recs) != len(keys):
                self.conn.execute(f"UPDATE {t['chunks']} SET status='failed', error=? WHERE chunk_id=?",
                                  ("turns missing from source", cid))
                continue
            text = "\n\n".join(segment.render_turn(x) for _, x in recs)
            todo.append((cid, text))
        self.stats["chunks_pending"] += self.conn.execute(
            f"SELECT count(*) FROM {t['chunks']} WHERE path=? AND status='pending'", (rel,)).fetchone()[0]
        if not todo:
            return True
        if self.call is None:
            return False
        results = self._send(todo)
        all_ok = True
        for cid, res in results:
            if res is None:
                all_ok = False
                continue  # budget exhausted: stays `sending`, resumed next run
            if isinstance(res, Exception):
                all_ok = False
                self.stats["chunks_failed"] += 1
                self.conn.execute(f"UPDATE {t['chunks']} SET status='failed', attempts=attempts+1, error=? WHERE chunk_id=?",
                                  (str(res)[:300], cid))
                continue
            self.stats["calls"] += res.calls
            self.stats["chunks_ok"] += 1
            self.stats["reasked_chunks"] += res.reasked
            self._delete_segments_for([cid])
            for s in res.sections:
                sid = hashlib.sha256(f"{cid}{s['section_no']}{self.pv}".encode()).hexdigest()
                cur = self.conn.execute(
                    f"INSERT OR REPLACE INTO {t['segments']} (id, chunk_id, section_no, path, topic_slugs, subject, repo,"
                    " repo_hint, text, label_flags, prompt_version, created) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                    (sid, cid, s["section_no"], rel, ",".join(s["topic_slugs"]), s["subject"], repo,
                     s["repo_hint"], s["text"], ",".join(s["flags"]), self.pv, iso_now()))
                if t["segments"] == "segments":
                    self.conn.execute("INSERT INTO segments_fts(rowid, subject, text) VALUES (?,?,?)",
                                      (cur.lastrowid, s["subject"], s["text"]))
                self.stats["segments"] += 1
            self.conn.execute(f"UPDATE {t['chunks']} SET status='ok', attempts=attempts+1, error=NULL WHERE chunk_id=?", (cid,))
        self.conn.commit()
        return all_ok

    def _send(self, todo):
        def budgeted(system, user):
            # --limit-calls counts every ScaleDown HTTP call (retries, re-asks)
            if not self.budget.take():
                raise BudgetExhausted("call budget exhausted")
            return self.call(system, user)

        def one(item):
            cid, text = item
            if self.budget.limit is not None and self.budget.used >= self.budget.limit:
                return cid, None
            try:
                return cid, segment.label_chunk(text, budgeted, self.prompt, self.aliases, sleep=self.sleep)
            except BudgetExhausted:
                return cid, None
            except segment.ScaleDownError as exc:
                if "budget exhausted" in str(exc):
                    return cid, None
                return cid, exc
        with ThreadPoolExecutor(max_workers=max(1, self.threads)) as pool:
            return list(pool.map(one, todo))


def run_archive(conn, archive: Path, runner: Runner, newest_first=True):
    files = list(scan_archive(archive))
    if newest_first:
        files.sort(key=lambda f: f[0].stat().st_mtime, reverse=True)
    for abspath, rel, machine in files:
        if runner.budget.limit is not None and runner.budget.used >= runner.budget.limit:
            break
        runner.process(abspath, rel, machine)
    meta_set(conn, "last_build", iso_now())
    conn.commit()


# ---------------------------------------------------------------- relabel

def relabel(conn, archive: Path, call, prompt_version: str, threads=6, budget=None, now=None, sleep=time.sleep) -> bool:
    """Re-chunk and relabel every lineage under ``prompt_version`` in side
    tables; swap them in one transaction once no chunk is ``sending`` or
    ``failed`` (a short live tail stays ``pending`` for a later run). A run
    stopped by ``--limit-calls`` resumes from the side tables. Returns True
    when swapped."""
    for base in ("chunks", "segments", "seen_turns"):
        conn.execute(f"CREATE TABLE IF NOT EXISTS {base}_relabel AS SELECT * FROM {base} WHERE 0")
    conn.execute("CREATE UNIQUE INDEX IF NOT EXISTS chunks_relabel_pk ON chunks_relabel(chunk_id)")
    conn.execute("CREATE UNIQUE INDEX IF NOT EXISTS segments_relabel_pk ON segments_relabel(id)")
    conn.execute("CREATE UNIQUE INDEX IF NOT EXISTS seen_relabel_pk ON seen_turns_relabel(lineage_id, turn_hash, occurrence_no)")
    prev = meta_get(conn, "relabel_prompt")
    if prev and prev != prompt_version:
        for base in ("chunks", "segments", "seen_turns"):
            conn.execute(f"DELETE FROM {base}_relabel")
    meta_set(conn, "relabel_prompt", prompt_version)
    conn.commit()
    tables = {"chunks": "chunks_relabel", "segments": "segments_relabel", "seen": "seen_turns_relabel"}
    runner = Runner(conn, call, prompt_version, threads, budget, now, sleep, tables)
    for abspath, rel, machine in scan_archive(archive):
        row = conn.execute("SELECT lineage_id, repo FROM sessions WHERE path=?", (rel,)).fetchone()
        if row is None:
            continue
        parsed = normalize.parse_file(abspath, machine=machine, rel_path=rel)
        runner.segment_session(rel, row[0], row[1], parsed["turns"], abspath.stat().st_mtime)
    open_n = conn.execute("SELECT count(*) FROM chunks_relabel WHERE status IN ('sending','failed')").fetchone()[0]
    if open_n:
        return False
    with conn:
        conn.execute("DELETE FROM segments_fts")
        conn.execute("DELETE FROM segments")
        conn.execute("DELETE FROM chunks")
        conn.execute("DELETE FROM seen_turns")
        conn.execute("INSERT INTO chunks SELECT * FROM chunks_relabel")
        conn.execute("INSERT INTO segments SELECT * FROM segments_relabel")
        conn.execute("INSERT INTO seen_turns SELECT * FROM seen_turns_relabel")
        conn.execute("INSERT INTO segments_fts(rowid, subject, text) SELECT rowid, subject, text FROM segments")
        for base in ("chunks", "segments", "seen_turns"):
            conn.execute(f"DROP TABLE {base}_relabel")
        meta_set(conn, "prompt_version", prompt_version)
        conn.execute("DELETE FROM meta WHERE key='relabel_prompt'")
    return True


# ---------------------------------------------------------------- labels.db

def import_labels(conn, labels_db: Path) -> int:
    src = sqlite3.connect(f"file:{labels_db}?mode=ro", uri=True)
    created = iso_now()
    rows = src.execute("SELECT src, repo, work, mode, reviewer, verdict, value, why FROM review_labels").fetchall()
    src.close()
    with conn:
        conn.execute("DELETE FROM question_labels WHERE question='review-value-2026-10-29'")
        conn.executemany(
            "INSERT INTO question_labels VALUES ('review-value-2026-10-29', ?, 'review-value-v0', ?, ?)",
            [(r[0], json.dumps(dict(zip(("repo", "work", "mode", "reviewer", "verdict", "value", "why"), r[1:]))), created)
             for r in rows])
    return len(rows)


# ---------------------------------------------------------------- inbox

class InboxReject(Exception):
    pass


def validate_inbox_file(path: Path, raw: bytes | None = None) -> list[tuple]:
    name = path.name
    if not INBOX_NAME_RX.match(name) or ".." in name or "/" in name or "\\" in name:
        raise InboxReject("bad file name")
    question = name.split("__", 1)[0]
    if raw is None:
        with open(path, "rb") as f:
            raw = f.read(INBOX_MAX_BYTES + 1)  # bounded even if the file grows
    if len(raw) > INBOX_MAX_BYTES:
        raise InboxReject("file over 5 MB")
    lines = raw.split(b"\n")
    if lines and lines[-1] == b"":
        lines.pop()
    if len(lines) > INBOX_MAX_LINES:
        raise InboxReject("over 20000 lines")
    rows = []
    for i, line in enumerate(lines, 1):
        if len(line) > INBOX_MAX_LINE:
            raise InboxReject(f"line {i} over 8 KB")
        try:
            obj = json.loads(line.decode("utf-8"))
        except (ValueError, UnicodeDecodeError):
            raise InboxReject(f"line {i} is not JSON") from None
        if not isinstance(obj, dict) or set(obj) != INBOX_KEYS:
            raise InboxReject(f"line {i} keys must be exactly {sorted(INBOX_KEYS)}")
        if obj["question"] != question:
            raise InboxReject(f"line {i} question differs from file name")
        s = obj["src"]
        if not isinstance(s, str) or not s or ".." in s.replace("\\", "/").split("/") or s.startswith(("/", "\\")) or re.match(r"^[A-Za-z]:", s):
            raise InboxReject(f"line {i} src must be a relative archive path without ..")
        if not isinstance(obj["prompt_version"], str) or len(obj["prompt_version"]) > 40:
            raise InboxReject(f"line {i} bad prompt_version")
        f = obj["fields"]
        if not isinstance(f, dict) or len(f) > 30:
            raise InboxReject(f"line {i} fields must be a flat object of at most 30 keys")
        for k, v in f.items():
            if isinstance(v, bool) or isinstance(v, (int, float)):
                continue
            if not isinstance(v, str) or len(v) > 2000:
                raise InboxReject(f"line {i} field {k!r} must be string/number/bool <= 2000 chars")
        red, _ = normalize.redact_value(obj)
        rows.append((red["question"], red["src"], red["prompt_version"], json.dumps(red["fields"], sort_keys=True)))
    return rows


def _move(src: Path, dest_dir: Path) -> Path:
    dest_dir.mkdir(parents=True, exist_ok=True)
    dest = dest_dir / src.name
    if dest.exists():
        dest = dest_dir / f"{src.stem}.{utc_stamp()}{src.suffix}"
    shutil.move(str(src), str(dest))
    return dest


def apply_inbox(conn, inbox: Path, now: float | None = None) -> dict:
    out = {"applied": 0, "rejected": 0, "conflicts": 0, "duplicates": 0}
    if not inbox.is_dir():
        return out
    for p in sorted(inbox.iterdir()):
        if not p.is_file():
            continue
        if CONFLICT in p.name:
            _move(p, inbox / "conflicts")
            out["conflicts"] += 1
            continue
        with open(p, "rb") as f:
            raw = f.read(INBOX_MAX_BYTES + 1)
        digest = hashlib.sha256(raw).hexdigest()  # hash and validate the same bytes
        prior = conn.execute("SELECT sha256 FROM inbox_applied WHERE filename=?", (p.name,)).fetchone()
        try:
            if prior and prior[0] == digest:
                _move(p, inbox / "applied")
                out["duplicates"] += 1
                continue
            if prior:
                raise InboxReject("file name already applied with different content")
            rows = validate_inbox_file(p, raw)
            with conn:
                created = iso_now()
                conn.executemany("INSERT INTO question_labels VALUES (?,?,?,?,?)", [r + (created,) for r in rows])
                conn.execute("INSERT INTO inbox_applied VALUES (?,?,?)", (p.name, digest, created))
            _move(p, inbox / "applied")
            out["applied"] += 1
        except InboxReject as exc:
            dest = _move(p, inbox / "rejected")
            dest.with_name(dest.name + ".reason.txt").write_text(str(exc) + "\n", encoding="utf-8")
            out["rejected"] += 1
    cutoff = (now if now is not None else time.time()) - RETENTION_DAYS * 86400
    for sub in ("rejected", "applied"):  # retention applies only here
        d = inbox / sub
        if d.is_dir():
            for f in d.iterdir():
                if f.is_file() and f.stat().st_mtime < cutoff:
                    f.unlink()
    return out


# ---------------------------------------------------------------- publish

def move_conflicts(store_root: Path) -> int:
    """Move any Dropbox conflicted copy under transcript-store/ to conflicts/."""
    n = 0
    if not store_root.is_dir():
        return 0
    dest = store_root / "conflicts"
    for root, dirs, files in os.walk(store_root):
        rp = Path(root)
        if rp == dest or dest in rp.parents or rp.name == "conflicts":
            dirs[:] = []
            continue
        for name in files:
            if CONFLICT in name:
                _move(rp / name, dest)
                n += 1
    return n


def publish(db_path: Path, store_root: Path, now: float | None = None, stage_dir: Path | None = None) -> dict:
    now = now if now is not None else time.time()
    stamp = utc_stamp(now)
    stage_dir = stage_dir or db_path.parent / "stage"
    stage_dir.mkdir(parents=True, exist_ok=True)
    staged = stage_dir / f"store-{stamp}.db"
    src = sqlite3.connect(db_path)
    dst = sqlite3.connect(staged)
    with dst:
        src.backup(dst)
    src.close()
    ok = dst.execute("PRAGMA integrity_check").fetchone()[0]
    dst.execute("PRAGMA journal_mode=DELETE")
    dst.close()
    if ok != "ok":
        raise RuntimeError(f"integrity_check failed: {ok}")
    size, digest = staged.stat().st_size, sha256_file(staged)
    dbdir = store_root / "db"
    dbdir.mkdir(parents=True, exist_ok=True)
    incoming = dbdir / f".incoming-store-{stamp}.db"
    shutil.copyfile(staged, incoming)
    if incoming.stat().st_size != size or sha256_file(incoming) != digest:
        incoming.unlink()
        raise RuntimeError("copy into Dropbox did not verify")
    final = dbdir / f"store-{stamp}.db"
    os.replace(incoming, final)
    pointer = {"file": f"db/store-{stamp}.db", "sha256": digest, "size": size,
               "built": edt_now(), "schema": SCHEMA_VERSION}
    # Write a dot-named sibling readers never follow, then rename it over the
    # old pointer so a reader never sees a half-written CURRENT.json.
    incoming_ptr = store_root / f".incoming-CURRENT-{stamp}.json"
    incoming_ptr.write_text(json.dumps(pointer), encoding="utf-8")
    os.replace(incoming_ptr, store_root / "CURRENT.json")
    staged.unlink()
    # publish history for the 24 h retention rule
    hist_path = db_path.parent / "publish-history.json"
    hist = json.loads(hist_path.read_text()) if hist_path.exists() else []
    hist.append({"file": final.name, "at": now})
    hist_path.write_text(json.dumps(hist[-50:]))
    removed = prune_versions(dbdir, hist, now)
    conflicts = move_conflicts(store_root)
    return {"file": pointer["file"], "size": size, "removed": removed, "conflicts": conflicts}


def prune_versions(dbdir: Path, hist: list[dict], now: float) -> int:
    files = sorted(p for p in dbdir.glob("store-*.db") if CONFLICT not in p.name)
    old = files[:-KEEP_VERSIONS] if len(files) > KEEP_VERSIONS else []
    published_at = {h["file"]: h["at"] for h in hist}
    removed = 0
    for p in old:
        newer = [published_at[f.name] for f in files if f.name > p.name and f.name in published_at]
        if newer and now - min(newer) >= 24 * 3600:
            p.unlink()
            removed += 1
    return removed


# ---------------------------------------------------------------- stats

def stats(conn) -> dict:
    q = lambda sql: conn.execute(sql).fetchall()  # noqa: E731
    out = {
        "sessions_by_status": dict(q("SELECT status, count(*) FROM sessions GROUP BY status")),
        "sessions_by_machine": {m: {"sessions": n, "last_ts": last} for m, n, last in
                                q("SELECT machine, count(*), max(last_ts) FROM sessions GROUP BY machine")},
        "chunks_by_status": dict(q("SELECT status, count(*) FROM chunks GROUP BY status")),
        "segments": q("SELECT count(*) FROM segments")[0][0],
        "segments_by_first_topic": dict(q(
            "SELECT CASE WHEN instr(topic_slugs, ',')>0 THEN substr(topic_slugs,1,instr(topic_slugs,',')-1)"
            " ELSE topic_slugs END t, count(*) FROM segments GROUP BY t ORDER BY 2 DESC")),
        "segments_by_repo": dict(q("SELECT repo, count(*) FROM segments GROUP BY repo ORDER BY 2 DESC LIMIT 30")),
        "label_flags": {
            "aliased": q("SELECT count(*) FROM segments WHERE label_flags LIKE '%aliased%'")[0][0],
            "reasked": q("SELECT count(*) FROM segments WHERE label_flags LIKE '%reasked%'")[0][0],
            "forced_other": q("SELECT count(*) FROM segments WHERE label_flags LIKE '%forced-other%'")[0][0],
            "other": q("SELECT count(*) FROM segments WHERE topic_slugs='other'")[0][0]},
        "question_labels": dict(q("SELECT question, count(*) FROM question_labels GROUP BY question")),
        "inbox_applied": q("SELECT count(*) FROM inbox_applied")[0][0],
        "last_build": meta_get(conn, "last_build"),
    }
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Transcript-store writer (edge-dev3 only).")
    ap.add_argument("--db", type=Path, default=DEFAULT_DB)
    ap.add_argument("--archive", type=Path, default=DEFAULT_ARCHIVE)
    ap.add_argument("--store-root", type=Path, default=DEFAULT_STORE_ROOT)
    ap.add_argument("--limit-calls", type=int, default=None)
    ap.add_argument("--threads", type=int, default=6)
    ap.add_argument("--prompt", default="v1", help="prompt version (prompt_<v>.txt)")
    ap.add_argument("--relabel", action="store_true")
    ap.add_argument("--import-labels", type=Path)
    ap.add_argument("--stats", action="store_true")
    ap.add_argument("--no-publish", action="store_true")
    a = ap.parse_args(argv)
    conn = connect(a.db)
    if a.stats:
        s = stats(conn)
        s["conflicts_waiting"] = len(list((a.store_root / "conflicts").glob("*"))) if (a.store_root / "conflicts").is_dir() else 0
        print(json.dumps(s, indent=1))
        return 0
    if a.import_labels:
        print(json.dumps({"imported": import_labels(conn, a.import_labels)}))
        return 0
    call = segment.scaledown_call(segment.api_key_from_env())
    budget = Budget(a.limit_calls)
    started = time.time()
    if a.relabel:
        swapped = relabel(conn, a.archive, call, a.prompt, a.threads, budget)
        result = {"relabel_swapped": swapped, "calls": budget.used}
        if not swapped:
            print(json.dumps(result))
            return 0
    else:
        pv = meta_get(conn, "prompt_version") or a.prompt
        runner = Runner(conn, call, pv, a.threads, budget)
        run_archive(conn, a.archive, runner)
        result = dict(runner.stats)
    result["inbox"] = apply_inbox(conn, a.store_root / "inbox")
    if not a.no_publish:
        result["publish"] = publish(a.db, a.store_root)
    result["wall_seconds"] = round(time.time() - started, 1)
    print(json.dumps(result, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
