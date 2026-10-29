#!/usr/bin/env python3
"""Normalize one Claude Code or Codex ``.jsonl`` transcript (plan step 2).

Issue popcre/ai-devops#2050 (stage B, #2060). Python 3.10+, stdlib only.

``parse_file(path)`` returns a dict::

    {"meta": {machine, path, cwd, repo, session_id, parent_session_id,
              first_ts, last_ts},
     "turns": [{ts, role, text, tools, turn_hash, occurrence_no}],
     "bytes_parsed": int,      # stops before a truncated last line
     "bad_lines": int,         # malformed lines skipped (not the tail)
     "truncated_tail": bool,
     "redactions": int}

Rules: secrets are redacted (``redact_patterns.tsv``) before anything else
sees the text; turns under 20 characters are skipped (their tool names are
kept on the previous kept turn); each turn is capped at 6,000 characters;
``turn_hash = sha256(role + "\\x00" + whitespace-normalized text)``.
Lineage grouping (forks share their first 3 turn hashes) is done by the
writer with ``lineage_key()``.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
PATTERNS_FILE = HERE / "redact_patterns.tsv"
MIN_TURN_CHARS = 20
MAX_TURN_CHARS = 6000
SKIP_KEYS = {
    "signature", "data", "thinkingSignature", "encrypted_content",
    # metadata strings that are not conversation text
    "id", "type", "role", "model", "stop_reason", "stop_sequence",
    "tool_use_id", "name", "media_type", "call_id", "status",
}

TOOL_OUTPUT_TYPES = {"tool_result", "function_call_output", "custom_tool_call_output"}

_PATTERNS: list[tuple[str, re.Pattern]] | None = None


def load_patterns(path: Path = PATTERNS_FILE) -> list[tuple[str, re.Pattern]]:
    """Load ``kind<TAB>pattern`` lines in file order (anthropic first)."""
    out = []
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        kind, pattern = line.split("\t", 1)
        out.append((kind, re.compile(pattern)))
    return out


def redact(text: str) -> tuple[str, int]:
    """Replace every secret match with ``[REDACTED:<kind>]``; return count."""
    global _PATTERNS
    if _PATTERNS is None:
        _PATTERNS = load_patterns()
    total = 0
    for kind, rx in _PATTERNS:
        text, n = rx.subn(f"[REDACTED:{kind}]", text)
        total += n
    return text, total


def redact_value(value):
    """Redact every string inside a JSON-like value; return (value, count)."""
    if isinstance(value, str):
        return redact(value)
    if isinstance(value, list):
        total, out = 0, []
        for item in value:
            v, n = redact_value(item)
            out.append(v)
            total += n
        return out, total
    if isinstance(value, dict):
        total, out = 0, {}
        for k, item in value.items():
            v, n = redact_value(item)
            out[k] = v
            total += n
        return out, total
    return value, 0


_WS = re.compile(r"\s+")


def norm_ws(text: str) -> str:
    return _WS.sub(" ", text).strip()


def turn_hash(role: str, text: str) -> str:
    return hashlib.sha256((role + "\x00" + norm_ws(text)).encode("utf-8")).hexdigest()


_REPO_PARENTS = ("repos", "worksp", "src")


def derive_repo(cwd: str | None) -> str:
    """Apply the plan's repo derivation rules; ``unknown`` when none match."""
    if not cwd:
        return "unknown"
    p = cwd.replace("\\", "/")
    if re.match(r"^[A-Za-z]:", p):
        p = p[0].lower() + p[1:]
    p = p.rstrip("/")
    # Claude project-folder form, e.g. -home-x-repos-ai-devops--claude-worktrees-y
    if "/" not in p and p.startswith("-"):
        p = p.split("--claude-worktrees", 1)[0]
        best = None
        for marker in ("-repos-", "-worksp-"):
            i = p.rfind(marker)
            if i >= 0 and (best is None or i > best[0]):
                best = (i, p[i + len(marker):])
        if best and best[1]:
            return best[1].lower()
        return "unknown"
    for marker in ("/.claude/worktrees/", "/.codex/worktrees/", "/worktrees/"):
        i = p.find(marker)
        if i >= 0:
            p = p[:i]
    parts = [x for x in p.split("/") if x]
    for i, part in enumerate(parts[:-1]):
        if part.lower() in _REPO_PARENTS:
            return parts[i + 1].lower()
    return "unknown"


def _collect_strings(value, out: list[str]) -> None:
    if isinstance(value, str):
        out.append(value)
    elif isinstance(value, list):
        for item in value:
            _collect_strings(item, out)
    elif isinstance(value, dict):
        if value.get("type") in TOOL_OUTPUT_TYPES:
            return  # ScaleDown never sees tool output (plan step 3)
        for k, item in value.items():
            if k in SKIP_KEYS:
                continue
            _collect_strings(item, out)


def _tool_names(value, out: list[str]) -> None:
    """Claude ``tool_use`` block names, in order."""
    if isinstance(value, list):
        for item in value:
            _tool_names(item, out)
    elif isinstance(value, dict):
        if value.get("type") == "tool_use" and isinstance(value.get("name"), str):
            out.append(value["name"])
        for k, item in value.items():
            if k not in SKIP_KEYS:
                _tool_names(item, out)


def _claude_turn(obj: dict):
    msg = obj.get("message")
    if not isinstance(msg, dict):
        return None
    role = msg.get("role") or obj.get("type")
    if role not in ("user", "assistant"):
        return None
    strings: list[str] = []
    _collect_strings(msg.get("content"), strings)
    tools: list[str] = []
    _tool_names(msg.get("content"), tools)
    return role, "\n".join(strings), tools


def _codex_turn(obj: dict):
    payload = obj.get("payload")
    if obj.get("type") != "response_item" or not isinstance(payload, dict):
        return None
    ptype = payload.get("type")
    if ptype == "message":
        role = payload.get("role") or "assistant"
        if role not in ("user", "assistant"):
            return None  # developer/system prompts are not conversation
        strings: list[str] = []
        _collect_strings(payload.get("content"), strings)
        return role, "\n".join(strings), []
    if ptype in ("function_call", "custom_tool_call", "local_shell_call"):
        name = payload.get("name") or ptype
        strings = []
        _collect_strings({k: v for k, v in payload.items() if k not in SKIP_KEYS}, strings)
        return "assistant", "\n".join(strings), [str(name)]
    return None  # tool output and reasoning are never sent to ScaleDown


def parse_lines(raw: bytes):
    """Yield (obj_or_None, end_offset, is_last) per line of ``raw``."""
    pos = 0
    n = len(raw)
    while pos < n:
        nl = raw.find(b"\n", pos)
        end = n if nl < 0 else nl + 1
        line = raw[pos:end]
        is_last = end >= n or not raw[end:].strip()
        try:
            obj = json.loads(line.decode("utf-8")) if line.strip() else ...
        except (ValueError, UnicodeDecodeError):
            obj = None
        yield obj, end, is_last, nl < 0
        pos = end


def parse_file(path, machine: str | None = None, rel_path: str | None = None) -> dict:
    raw = Path(path).read_bytes()
    meta = {"machine": machine, "path": rel_path or str(path), "cwd": None,
            "repo": "unknown", "session_id": None, "parent_session_id": None,
            "first_ts": None, "last_ts": None}
    turns: list[dict] = []
    bad = 0
    redactions = 0
    bytes_parsed = 0
    truncated = False
    occ: dict[str, int] = {}
    for obj, end, is_last, no_newline in parse_lines(raw):
        if obj is ...:
            bytes_parsed = end
            continue
        if obj is None:
            if is_last:
                truncated = True
                break  # bytes_parsed stays before it; re-read next run
            bad += 1
            bytes_parsed = end
            continue
        if not isinstance(obj, dict):
            bad += 1
            bytes_parsed = end
            continue
        bytes_parsed = end
        ts = obj.get("timestamp")
        if obj.get("type") == "session_meta" and isinstance(obj.get("payload"), dict):
            p = obj["payload"]
            meta["session_id"] = meta["session_id"] or p.get("id")
            meta["cwd"] = meta["cwd"] or p.get("cwd")
            meta["parent_session_id"] = p.get("forked_from_id") or meta["parent_session_id"]
            continue
        if obj.get("type") == "turn_context" and isinstance(obj.get("payload"), dict):
            meta["cwd"] = meta["cwd"] or obj["payload"].get("cwd")
            continue
        if obj.get("sessionId") and not meta["session_id"]:
            meta["session_id"] = obj["sessionId"]
        if obj.get("cwd") and not meta["cwd"]:
            meta["cwd"] = obj["cwd"]
        if obj.get("parentSessionId"):
            meta["parent_session_id"] = obj["parentSessionId"]
        got = _claude_turn(obj) if "message" in obj else _codex_turn(obj)
        if got is None:
            continue
        role, text, tools = got
        if isinstance(ts, str):
            meta["first_ts"] = meta["first_ts"] or ts
            meta["last_ts"] = ts
        text, n = redact(text)
        redactions += n
        text = norm_ws(text)[:MAX_TURN_CHARS]
        if len(text) < MIN_TURN_CHARS:
            if tools and turns:
                turns[-1]["tools"].extend(tools)
            continue
        h = turn_hash(role, text)
        occ[h] = occ.get(h, 0) + 1
        turns.append({"ts": ts if isinstance(ts, str) else None, "role": role,
                      "text": text, "tools": list(tools), "turn_hash": h,
                      "occurrence_no": occ[h]})
    if not meta["session_id"]:
        meta["session_id"] = Path(path).stem
    meta["repo"] = derive_repo(meta["cwd"])
    if meta["repo"] == "unknown" and rel_path:
        # Claude project-folder name in the archive path
        for part in Path(rel_path.replace("\\", "/")).parts:
            if part.startswith("-"):
                meta["repo"] = derive_repo(part)
                break
    return {"meta": meta, "turns": turns, "bytes_parsed": bytes_parsed,
            "bad_lines": bad, "truncated_tail": truncated, "redactions": redactions}


def lineage_key(turns: list[dict]) -> str:
    """Files whose first 3 kept turns hash alike share one lineage."""
    return hashlib.sha256("|".join(t["turn_hash"] for t in turns[:3]).encode()).hexdigest()


def main(argv=None) -> int:
    import argparse
    ap = argparse.ArgumentParser(description="Normalize one transcript; prints counts only.")
    ap.add_argument("path")
    a = ap.parse_args(argv)
    r = parse_file(a.path)
    print(json.dumps({"turns": len(r["turns"]), "chars": sum(len(t["text"]) for t in r["turns"]),
                      "tools": sum(len(t["tools"]) for t in r["turns"]), "bad_lines": r["bad_lines"],
                      "truncated_tail": r["truncated_tail"], "repo": r["meta"]["repo"]}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
