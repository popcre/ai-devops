#!/usr/bin/env python3
"""Reader helper for the published transcript store (plan step 8).

Issue popcre/ai-devops#2050 (stage D, #2062). Python 3.10+, stdlib only.

Follows the step 4 read protocol through ``reader.open_store``: pointer,
local verified copy, read-only open. SQLite never opens a file inside Dropbox.

    ai-transcript-query --topic reviewer-tooling --repo designflow --since 2026-10-01 --text "402"
    ai-transcript-query --stats
    ai-transcript-query --raw <segment id>
    ai-transcript-query --add-labels <file.jsonl>

Environment: ``AI_TRANSCRIPT_STORE_ROOT`` (default ``~/Dropbox/ai/transcript-store``),
``AI_TRANSCRIPT_STORE_CACHE`` (local copy folder), ``AI_TRANSCRIPT_ARCHIVE``
(raw archive root for ``--raw``; default ``<store root>/../chat_transcripts``).
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import socket
import sqlite3
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import reader  # noqa: E402

STALE_DAYS = 2
TEXT_CAP = 1500
DEFAULT_LIMIT = 20


# ---------------------------------------------------------------- time

def _nth_sunday(year: int, month: int, n: int) -> dt.date:
    d = dt.date(year, month, 1)
    d += dt.timedelta(days=(6 - d.weekday()) % 7)
    return d + dt.timedelta(weeks=n - 1)


def to_new_york(ts: dt.datetime) -> str:
    """Format a UTC time as America/New_York (US DST rule; no tzdata needed)."""
    if ts.tzinfo is None:
        ts = ts.replace(tzinfo=dt.timezone.utc)
    u = ts.astimezone(dt.timezone.utc).replace(tzinfo=None)
    start = dt.datetime.combine(_nth_sunday(u.year, 3, 2), dt.time(7))   # 2 AM EST
    end = dt.datetime.combine(_nth_sunday(u.year, 11, 1), dt.time(6))    # 2 AM EDT
    dst = start <= u < end
    local = u + dt.timedelta(hours=-4 if dst else -5)
    return local.strftime("%Y-%m-%d %I:%M %p ") + ("EDT" if dst else "EST")


def parse_ts(value) -> dt.datetime | None:
    if not value:
        return None
    try:
        t = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except ValueError:
        return None
    return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)


# ---------------------------------------------------------------- modes

def search(conn, topic=None, repo=None, since=None, text=None, limit=DEFAULT_LIMIT, cap=TEXT_CAP) -> list[str]:
    where, args = [], []
    if topic:
        where.append("(',' || s.topic_slugs || ',') LIKE ?")
        args.append(f"%,{topic},%")
    if repo:
        where.append("(s.repo = ? OR s.repo_hint = ?)")
        args += [repo, repo]
    if since:
        where.append("COALESCE(se.last_ts, s.created) >= ?")
        args.append(since)
    fts = None
    if text:
        fts = '"' + text.replace('"', '""') + '"'
    base = ("SELECT s.id, s.topic_slugs, s.repo, s.subject, s.text, se.last_ts FROM segments s"
            " LEFT JOIN sessions se ON se.path = s.path")
    order = " ORDER BY COALESCE(se.last_ts, s.created) DESC LIMIT ?"
    rows = None
    if fts:
        try:
            rows = conn.execute(base + " WHERE s.rowid IN (SELECT rowid FROM segments_fts WHERE segments_fts MATCH ?)"
                                + "".join(" AND " + w for w in where) + order, [fts] + args + [limit]).fetchall()
        except sqlite3.OperationalError:
            rows = None  # FTS5 missing in this Python's SQLite: fall back to LIKE
        if rows is None:
            where.append("(s.subject LIKE ? OR s.text LIKE ?)")
            args += [f"%{text}%", f"%{text}%"]
    if rows is None:
        rows = conn.execute(base + (" WHERE " + " AND ".join(where) if where else "") + order,
                            args + [limit]).fetchall()
    out = []
    for sid, topics, r, subject, body, last in rows:
        body = body or ""
        if len(body) > cap:
            body = body[:cap] + " [...]"
        out.append(f"== {sid}  [{topics or '-'}]  repo={r or '-'}  last={last or '-'}\n{subject or ''}\n{body}\n")
    return out


def stats(conn, now: dt.datetime | None = None, stale_days: int = STALE_DAYS) -> list[str]:
    now = now or dt.datetime.now(dt.timezone.utc)
    q = lambda sql: conn.execute(sql).fetchall()  # noqa: E731
    lines = [f"segments: {q('SELECT count(*) FROM segments')[0][0]}",
             f"sessions: {q('SELECT count(*) FROM sessions')[0][0]}",
             f"question labels: {q('SELECT count(*) FROM question_labels')[0][0]}", "", "by topic:"]
    topics: dict[str, int] = {}
    for slugs, n in q("SELECT topic_slugs, count(*) FROM segments GROUP BY topic_slugs"):
        for t in (slugs or "-").split(","):
            topics[t.strip() or "-"] = topics.get(t.strip() or "-", 0) + n
    lines += [f"  {t}: {n}" for t, n in sorted(topics.items(), key=lambda kv: (-kv[1], kv[0]))]
    lines += ["", "by repo:"]
    lines += [f"  {r or '-'}: {n}" for r, n in q("SELECT repo, count(*) FROM segments GROUP BY repo ORDER BY 2 DESC, 1")]
    lines += ["", f"by machine (last session; STALE = older than {stale_days} days):"]
    for m, n, last in q("SELECT machine, count(*), max(last_ts) FROM sessions GROUP BY machine ORDER BY machine"):
        t = parse_ts(last)
        when = to_new_york(t) if t else "unknown"
        flag = "  STALE" if t is None or (now - t) > dt.timedelta(days=stale_days) else ""
        lines.append(f"  {m or '-'}: {n} sessions, last {when}{flag}")
    return lines


def raw_pointer(conn, seg_id: str, archive: Path) -> list[str]:
    row = conn.execute("SELECT s.path, c.first_turn_key, c.last_turn_key FROM segments s"
                       " LEFT JOIN chunks c ON c.chunk_id = s.chunk_id WHERE s.id = ?", (seg_id,)).fetchone()
    if not row:
        raise SystemExit(f"no segment with id {seg_id}")
    path, first, last = row
    return [f"file: {archive / path}", f"turns: {first} .. {last}"]


def add_labels(src: Path, inbox: Path, host: str | None = None, now: dt.datetime | None = None) -> Path:
    import build  # lazy: only this mode needs the writer's validator

    raw = src.read_bytes()
    first = raw.split(b"\n", 1)[0]
    m = re.search(rb'"question"\s*:\s*"([a-z0-9-]{1,40})"', first)
    if not m:
        raise build.InboxReject("first line needs a question slug matching [a-z0-9-]{1,40}")
    host = re.sub(r"[^a-z0-9-]", "-", (host or socket.gethostname()).lower())[:30].strip("-") or "host"
    stamp = (now or dt.datetime.now(dt.timezone.utc)).strftime("%Y%m%dT%H%M%SZ")
    name = f"{m.group(1).decode()}__{stamp}__{host}.jsonl"
    build.validate_inbox_file(Path(name), raw)
    if not inbox.is_dir():
        raise build.InboxReject(f"inbox folder not found: {inbox}")
    part = inbox / ".partial"  # writer only reads top-level files
    part.mkdir(exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=part, suffix=".part")
    with os.fdopen(fd, "wb") as f:
        f.write(raw)
    dest = inbox / name
    os.replace(tmp, dest)
    return dest


# ---------------------------------------------------------------- main

def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="ai-transcript-query", description=__doc__.split("\n\n")[0])
    p.add_argument("--topic")
    p.add_argument("--repo")
    p.add_argument("--since", help="YYYY-MM-DD")
    p.add_argument("--text")
    p.add_argument("--limit", type=int, default=DEFAULT_LIMIT)
    p.add_argument("--stats", action="store_true")
    p.add_argument("--raw", metavar="SEGMENT_ID")
    p.add_argument("--add-labels", metavar="FILE")
    p.add_argument("--store-root")
    p.add_argument("--now", help=argparse.SUPPRESS)  # tests only: ISO UTC time
    p.add_argument("--no-wait", action="store_true", help=argparse.SUPPRESS)  # tests only: skip Dropbox waits
    a = p.parse_args(argv)
    root = Path(a.store_root) if a.store_root else reader.default_store_root()

    if a.add_labels:
        import build
        try:
            dest = add_labels(Path(a.add_labels), root / "inbox")
        except (build.InboxReject, OSError) as exc:
            print(f"rejected: {exc}", file=sys.stderr)
            return 1
        print(f"queued: {dest.name}")
        return 0

    if not (a.stats or a.raw or a.topic or a.repo or a.since or a.text):
        p.error("give --stats, --raw, --add-labels, or at least one search filter")
    try:
        conn = reader.open_store(root, sleep=(lambda _s: None) if a.no_wait else reader.time.sleep)
    except reader.StoreUnavailable as exc:
        print(str(exc), file=sys.stderr)
        return 2
    info = reader.last_open_info()
    try:
        if a.stats:
            now = parse_ts(a.now) if a.now else None
            print(f"store: {info.source}" + ("  (FALLBACK: current version did not verify)" if info.fallback else ""))
            print("\n".join(stats(conn, now)))
        elif a.raw:
            archive = Path(os.environ.get("AI_TRANSCRIPT_ARCHIVE") or root.parent / "chat_transcripts")
            print("\n".join(raw_pointer(conn, a.raw, archive)))
        else:
            hits = search(conn, a.topic, a.repo, a.since, a.text, a.limit)
            print("\n".join(hits) if hits else "no matching segments")
    finally:
        conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
