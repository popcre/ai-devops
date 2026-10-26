#!/usr/bin/env python3
"""Extract per-session Claude usage stats for the SLM history-compaction pilot.

Usage:
  python extract_claude_usage.py [limit] [out.jsonl]

Reads ~/.claude/projects/**/*.jsonl and writes one JSON object per session with
billed input, output, cache_read/cache_write, cache hit percent, and compact
markers. Do not commit the JSONL output (it may contain private transcript
adjacent metadata); commit only the summary tables in the pilot markdown.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path.home() / ".claude" / "projects"


def parse_session(path: Path) -> dict | None:
    turns = 0
    assistant_msgs = 0
    input_tokens = 0
    output_tokens = 0
    cache_creation = 0
    cache_read = 0
    compact_events = 0
    first_ts = None
    last_ts = None
    models = set()

    try:
        with path.open("r", encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except json.JSONDecodeError:
                    continue

                ts = rec.get("timestamp")
                if ts:
                    if first_ts is None:
                        first_ts = ts
                    last_ts = ts

                if rec.get("type") == "user":
                    turns += 1

                msg = rec.get("message") or {}
                if rec.get("type") == "assistant" or msg.get("role") == "assistant":
                    assistant_msgs += 1
                    usage = msg.get("usage") or {}
                    if usage:
                        input_tokens += int(usage.get("input_tokens") or 0)
                        output_tokens += int(usage.get("output_tokens") or 0)
                        cache_creation += int(
                            usage.get("cache_creation_input_tokens") or 0
                        )
                        cache_read += int(usage.get("cache_read_input_tokens") or 0)
                    model = msg.get("model")
                    if model:
                        models.add(str(model))

                blob = json.dumps(rec, ensure_ascii=False)
                if (
                    "isCompactSummary" in blob
                    or "compact_boundary" in blob
                    or rec.get("subtype") == "compact_boundary"
                    or rec.get("isCompact") is True
                    or rec.get("type") == "summary"
                ):
                    compact_events += 1
    except OSError as exc:
        print(f"skip {path}: {exc}", file=sys.stderr)
        return None

    if assistant_msgs == 0 and input_tokens == 0:
        return None

    billed_input = input_tokens + cache_creation + cache_read
    cache_denom = cache_creation + cache_read
    cache_hit_pct = (
        round(100.0 * cache_read / cache_denom, 2) if cache_denom else None
    )

    return {
        "session_id": path.stem,
        "project": path.parent.name,
        "turns": turns,
        "assistant_msgs": assistant_msgs,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "cache_creation_input_tokens": cache_creation,
        "cache_read_input_tokens": cache_read,
        "billed_input_tokens": billed_input,
        "total_tokens": billed_input + output_tokens,
        "cache_hit_pct": cache_hit_pct,
        "compact_events": compact_events,
        "models": ",".join(sorted(models)),
        "first_ts": first_ts,
        "last_ts": last_ts,
        "file_bytes": path.stat().st_size,
    }


def main() -> None:
    limit = int(sys.argv[1]) if len(sys.argv) > 1 else 25
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("claude-usage-sessions.jsonl")
    files = sorted(ROOT.rglob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)
    rows = []
    for path in files:
        row = parse_session(path)
        if row:
            rows.append(row)
        if len(rows) >= limit:
            break

    with out.open("w", encoding="utf-8") as fh:
        for row in rows:
            fh.write(json.dumps(row, ensure_ascii=False) + "\n")

    big = [r for r in rows if r["turns"] >= 10]
    print(f"sessions={len(rows)} substantial={len(big)} -> {out}")
    for r in big[:15]:
        print(
            f"{r['session_id'][:12]} turns={r['turns']:4d} "
            f"asst={r['assistant_msgs']:4d} "
            f"in={r['billed_input_tokens']:12,d} "
            f"out={r['output_tokens']:8,d} "
            f"cache_w={r['cache_creation_input_tokens']:10,d} "
            f"cache_r={r['cache_read_input_tokens']:12,d} "
            f"hit={r['cache_hit_pct']} "
            f"compact={r['compact_events']} "
            f"ts={(r['last_ts'] or '')[:10]}"
        )


if __name__ == "__main__":
    main()
