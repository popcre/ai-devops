#!/usr/bin/env python3
"""Export ZCode or MiMo sessions from a live sqlite database to one ``.jsonl`` each.

ZCode keeps conversations in ``~/.zcode/cli/db/db.sqlite`` and MiMo in
``~/.local/share/mimocode/mimocode.db``, with the same session, message and part
tables, which the transcript uploader cannot copy as a set of session files. Each
export line uses the Claude Code shape ``normalize.parse_file`` already reads. Only
text parts and tool names are exported; reasoning, tool output and text the client
injected itself (marked synthetic or ignored) are left out. A file is rewritten only
when its session changed, and its mtime is the session's last activity.

    zcode_export.py DB DEST    # prints counts only
"""

from __future__ import annotations

import datetime as dt
import json
import os
import re
import sqlite3
import sys
from pathlib import Path

SAFE_ID = re.compile(r"^[A-Za-z0-9._-]+$")


def iso(ms: int) -> str:
    t = dt.datetime.fromtimestamp(ms / 1000, dt.timezone.utc)
    return t.strftime("%Y-%m-%dT%H:%M:%S.") + f"{t.microsecond // 1000:03d}Z"


def session_lines(conn, sid: str, cwd, parent) -> list[str]:
    parts: dict[str, list[dict]] = {}
    for mid, raw in conn.execute("SELECT message_id, data FROM part WHERE session_id=? ORDER BY time_created, id", (sid,)):
        obj = json.loads(raw)
        if obj.get("synthetic") or obj.get("ignored"):
            continue
        if obj.get("type") == "text" and isinstance(obj.get("text"), str):
            parts.setdefault(mid, []).append({"type": "text", "text": obj["text"]})
        elif obj.get("type") == "tool" and isinstance(obj.get("tool"), str):
            parts.setdefault(mid, []).append({"type": "tool_use", "name": obj["tool"]})
    lines = []
    for mid, raw, created in conn.execute("SELECT id, data, time_created FROM message WHERE session_id=? ORDER BY time_created, id", (sid,)):
        role = json.loads(raw).get("role")
        if role not in ("user", "assistant") or mid not in parts:
            continue
        rec = {"type": role, "sessionId": sid, "cwd": cwd, "timestamp": iso(created),
               "message": {"role": role, "content": parts[mid]}}
        if parent:
            rec["parentSessionId"] = parent
        lines.append(json.dumps(rec, ensure_ascii=False))
    return lines


def export(db: Path, dest: Path) -> dict:
    out = {"sessions": 0, "written": 0, "empty": 0}
    conn = sqlite3.connect(f"{db.resolve().as_uri()}?mode=ro", uri=True, timeout=30)
    try:
        dest.mkdir(parents=True, exist_ok=True)
        rows = conn.execute(
            "SELECT s.id, s.directory, s.parent_id, max(m.time_updated) FROM session s"
            " JOIN message m ON m.session_id=s.id GROUP BY s.id").fetchall()
        for sid, cwd, parent, last_ms in rows:
            if not SAFE_ID.match(sid):
                raise ValueError("unsafe session id in database")
            out["sessions"] += 1
            target = dest / f"{sid}.jsonl"
            mtime = last_ms / 1000
            if target.exists() and abs(target.stat().st_mtime - mtime) < 1:
                continue
            lines = session_lines(conn, sid, cwd, parent)
            if not lines:
                out["empty"] += 1
                continue
            tmp = target.with_name(target.name + ".tmp")
            tmp.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
            os.utime(tmp, (mtime, mtime))
            os.replace(tmp, target)
            out["written"] += 1
    finally:
        conn.close()
    return out


def main(argv=None) -> int:
    args = sys.argv[1:] if argv is None else argv
    if len(args) != 2:
        print("usage: zcode_export.py DB DEST", file=sys.stderr)
        return 2
    print(json.dumps(export(Path(args[0]), Path(args[1]))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
