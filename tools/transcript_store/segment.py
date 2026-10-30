#!/usr/bin/env python3
"""Chunk normalized turns and topic-label them with ScaleDown (plan step 3).

Issue popcre/ai-devops#2050 (stage B, #2060). Python 3.10+, stdlib only.
ScaleDown is the only model that reads transcript text.

Main pieces (the writer, ``build.py``, owns the database side):

- ``make_chunks(lineage_id, records, prompt_version, max_chars)`` cuts
  ``[(turn_key, turn), ...]`` into chunks on turn boundaries.
- ``label_chunk(text, call, ...)`` -> ``LabelResult``: one ScaleDown call
  (plus at most one re-ask for invalid slugs), with retries and backoff.
  ``call(system, user) -> str`` is injectable; ``scaledown_call`` is the real
  one. Errors raise ``ScaleDownError`` after the retries are spent.
- ``parse_reply(content)`` parses ``### TOPIC: slugs | subject | repo=x``
  sections from the reply only (never from the transcript text).
- ``--live-check FILE`` segments one real session and prints counts only.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import normalize  # noqa: E402

SLUGS = (
    "ci", "reviewer-model", "reviewer-tooling", "ai-devops-process", "database",
    "machines-setup", "vendor-credit", "secrets", "ai-mistakes", "agent-loop",
    "agent-stuck-waiting", "idle-waiting", "token-waste-process", "token-waste-tools",
    "should-be-skill", "owner-decision", "business-rules", "ai-interaction-ideas", "other",
)
SLUG_SET = frozenset(SLUGS)
MAX_CHUNK_CHARS = 40_000
PENDING_TAIL_CHARS = 4_000
QUIET_SECONDS = 24 * 3600
ENDPOINT = "https://api.scaledown.xyz/v1/chat/completions"
TIMEOUT = 300
RETRIES = 3
# ScaleDown often drops the literal "TOPIC:" and writes "### slug,slug | subject";
# accept both, but only when a lowercase slug list is followed by "|".
HEADER_RX = re.compile(r"^#{2,4}[ \t]*(?:TOPIC:[ \t]*)?([a-z][a-z-]*(?:[ \t]*,[ \t]*[a-z][a-z-]*)*[ \t]*\|.*)$",
                       re.MULTILINE)
# Reply parsing is wider than HEADER_RX (which also neutralizes headers inside
# turn text): any case, 1-4 '#', and a bare "slugs | subject | repo=x" line.
_SLUGLIST = r"[A-Za-z][A-Za-z0-9_-]*(?:[ \t]*,[ \t]*[A-Za-z][A-Za-z0-9_-]*)*"
REPLY_HEADER_RX = re.compile(
    r"^(?:#{1,4}[ \t]*(?:[a-z]+:[ \t]*)?(" + _SLUGLIST + r"[ \t]*\|.*)"
    r"|(?:topic:[ \t]*)?(" + _SLUGLIST + r"[ \t]*\|[^|\n]*\|[ \t]*repo=.*))$",
    re.MULTILINE | re.IGNORECASE)


class ScaleDownError(Exception):
    def __init__(self, message: str, status: int | None = None):
        super().__init__(message)
        self.status = status


DEFAULT_PROMPT = "v5"


def load_prompt(version: str = DEFAULT_PROMPT) -> str:
    return (HERE / f"prompt_{version}.txt").read_text(encoding="utf-8")


def load_aliases(path: Path = HERE / "aliases.json") -> dict[str, str]:
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    return {k.lower(): v for k, v in data.items() if not k.startswith("_")}


def turn_key_str(lineage_id: str, turn: dict) -> str:
    return f"{lineage_id}:{turn['turn_hash']}:{turn['occurrence_no']}"


def chunk_id(lineage_id: str, first_key: str, last_key: str, prompt_version: str) -> str:
    # prompt_version is part of the id so a relabel builds new chunk ids.
    return hashlib.sha256("\x00".join((lineage_id, first_key, last_key, prompt_version)).encode()).hexdigest()


def render_turn(turn: dict) -> str:
    # A transcript can contain a fake "### TOPIC:" header; defang it so it can
    # never look like a reply header (headers are parsed from the reply only).
    text = HEADER_RX.sub(lambda m: "## topic-text: " + m.group(1), turn["text"])
    text = text.replace("### TOPIC:", "## topic-text:")
    return f"[{turn['role']}] {text}"


def make_chunks(lineage_id: str, records: list[tuple[str, dict]], prompt_version: str,
                max_chars: int = MAX_CHUNK_CHARS) -> list[dict]:
    """Group ``(turn_key, turn)`` records into chunks of at most ``max_chars``."""
    chunks: list[dict] = []
    cur: list[tuple[str, dict]] = []
    size = 0

    def flush():
        if not cur:
            return
        keys = [k for k, _ in cur]
        text = "\n\n".join(render_turn(t) for _, t in cur)
        chunks.append({
            "chunk_id": chunk_id(lineage_id, keys[0], keys[-1], prompt_version),
            "lineage_id": lineage_id, "first_turn_key": keys[0], "last_turn_key": keys[-1],
            "turn_keys": keys, "chars": len(text), "text": text,
            "tool_seq": [list(t["tools"]) for _, t in cur],
        })

    for key, turn in records:
        add = len(turn["text"]) + 2
        if cur and size + add > max_chars:
            flush()
            cur, size = [], 0
        cur.append((key, turn))
        size += add
    flush()
    return chunks


def hold_tail(chunks: list[dict], session_mtime: float, now: float) -> bool:
    """True when the trailing chunk must stay ``pending`` (short, live)."""
    return bool(chunks) and chunks[-1]["chars"] < PENDING_TAIL_CHARS and (now - session_mtime) < QUIET_SECONDS


def unwrap_reply(content) -> str:
    """Return the reply text; ScaleDown often wraps it as JSON ``summary``."""
    if not isinstance(content, str):
        return ""
    s = content.strip()
    if s.startswith("{"):
        try:
            obj = json.loads(s)
        except ValueError:
            return s
        if isinstance(obj, dict):
            for k in ("summary", "content", "text"):
                if isinstance(obj.get(k), str):
                    return obj[k].strip()
        return ""
    return s


def parse_reply(content) -> list[dict]:
    """Sections ``{raw_slugs, subject, repo_hint, text}`` from a reply."""
    text = unwrap_reply(content)
    matches = list(REPLY_HEADER_RX.finditer(text))
    sections = []
    for i, m in enumerate(matches):
        body_end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        body = text[m.end():body_end].strip()
        parts = [p.strip() for p in (m.group(1) or m.group(2)).split("|")]
        raw_slugs = [s.strip() for s in parts[0].split(",") if s.strip()] if parts else []
        subject = parts[1] if len(parts) > 1 else ""
        repo_hint = None
        spill = ""
        for p in parts[2:]:
            if p.lower().startswith("repo="):
                tokens = p[5:].split(None, 1)
                repo_hint = tokens[0] if tokens else None
                spill = tokens[1] if len(tokens) > 1 else ""
        words = subject.split()
        if len(parts) < 3 and len(words) > 8:
            # header and body flattened onto one line: the body spilled into it
            spill = " ".join(words[8:])
        subject = " ".join(words[:8])
        if spill:
            body = (spill + "\n" + body).strip()
        sections.append({"raw_slugs": raw_slugs, "subject": subject,
                         "repo_hint": repo_hint, "text": body})
    return sections


# Deterministic first-slug rules (step 5 "decision rules"). ScaleDown is a
# summarizer and does not follow a priority order reliably; these rules run
# on its own subject and cleaned text, never on raw transcript text.
_RX = lambda p: re.compile(p, re.IGNORECASE)
REVIEWER_RX = _RX(r"\b(reviewers?|ai-review|kimi|grok|glm|qwen|muse|deepseek|stepfun|gemini|review wrapper|exact-head review)\b")
BUSINESS_RX = _RX(r"\b(warner|paramount|sega|coca-cola|universal|nbcu|licensor|coldlion|mg0[1-9]|mgcategory|merch(andise)? group|"
                  r"property codes?|style.?guides?|entitlements?|business[- ]rules?)\b")
DATABASE_RX = _RX(r"\b(shared-db|supabase|migrations?|schema|postgres|rls|production apply|preview (lane|apply|capture)|"
                  r"orchestrator|sql)\b")
APP_RX = _RX(r"\b(designflow|popdam|poppim|popcrm|erp|item library|crawler|search results?|frontend|ui)\b")
SOFT_FIRST = {"ai-devops-process", "owner-decision", "ci", "database"}


def refine_slugs(slugs: list[str], subject: str, text: str) -> tuple[list[str], bool]:
    """Re-order or replace a weak first slug; returns (slugs, changed)."""
    if not slugs or slugs == ["other"]:
        return slugs, False
    out = list(slugs)
    head = subject + "\n" + text[:1500]
    first = out[0]
    want = None
    if first in SOFT_FIRST and REVIEWER_RX.search(subject):
        want = "reviewer-tooling" if "reviewer-model" not in out else "reviewer-model"
    elif first in SOFT_FIRST and BUSINESS_RX.search(head):
        want = "business-rules"
    elif first in ("ai-devops-process", "owner-decision") and DATABASE_RX.search(head):
        want = "database"
    elif first in ("ai-devops-process", "owner-decision") and APP_RX.search(head):
        want = "other"
    if want == "other":
        return ["other"], True
    if want:
        out = [want] + [x for x in out if x != want]
    if out[0] == "owner-decision" and len(out) > 1:
        out = out[1:2] + ["owner-decision"] + out[2:]
    out = out[:3]
    return out, out != slugs


def map_slug(raw: str, aliases: dict[str, str]) -> tuple[str | None, bool]:
    """Map one label to a valid slug; returns (slug or None, aliased?)."""
    s = raw.strip().strip("`'\"").lower()
    if s in SLUG_SET:
        return s, False
    cands = [s, s.replace("_", "-").replace(" ", "-")]
    for c in list(cands):
        cands += [c[:-1] if c.endswith("s") else c, c + "s"]
    for c in cands:
        if c in SLUG_SET:
            return c, True
        if c in aliases and aliases[c] in SLUG_SET:
            return aliases[c], True
    return None, False


def resolve_slugs(raw_slugs: list[str], aliases: dict[str, str]):
    """Return (slugs, invalid_raw, aliased) applying the §8 rules."""
    out: list[str] = []
    invalid: list[str] = []
    aliased = False
    for r in raw_slugs:
        slug, was_alias = map_slug(r, aliases)
        if slug is None:
            invalid.append(r)
            continue
        aliased |= was_alias
        if slug not in out:
            out.append(slug)
    if "other" in out and len(out) > 1:
        out.remove("other")  # `other` never alongside another slug
    return out[:3], invalid, aliased


@dataclass
class LabelResult:
    sections: list[dict] = field(default_factory=list)
    calls: int = 0
    reasked: bool = False


def call_with_retry(call, system: str, user: str, retries: int = RETRIES, sleep=time.sleep) -> str:
    last: Exception | None = None
    for attempt in range(retries):
        try:
            reply = call(system, user)
            if not unwrap_reply(reply):
                raise ScaleDownError("empty reply")
            return reply
        except ScaleDownError as exc:
            if getattr(exc, "no_retry", False):
                raise
            last = exc
        except Exception as exc:  # network errors from the real client
            last = ScaleDownError(f"{type(exc).__name__}: {exc}")
        if attempt + 1 < retries:
            sleep(2 ** attempt * 5)
    assert last is not None
    raise last if isinstance(last, ScaleDownError) else ScaleDownError(str(last))


def label_chunk(text: str, call, prompt: str, aliases: dict[str, str], sleep=time.sleep) -> LabelResult:
    """Label one chunk. Raises ScaleDownError when every retry failed or the
    reply holds no section header."""
    res = LabelResult()
    reply = call_with_retry(call, prompt, text, sleep=sleep)
    res.calls += 1
    sections = parse_reply(reply)
    if not sections:
        # ScaleDown's header format drifts between calls: ask once more
        reply = call_with_retry(call, prompt, text, sleep=sleep)
        res.calls += 1
        sections = parse_reply(reply)
    if not sections:
        raise ScaleDownError("reply had no TOPIC sections")
    resolved = [(s, *resolve_slugs(s["raw_slugs"], aliases)) for s in sections]
    if any(inv or not slugs for _, slugs, inv, _ in resolved):
        res.reasked = True
        reask = prompt + "\n\nUse only these slugs: " + ", ".join(SLUGS) + "."
        try:
            reply2 = call_with_retry(call, reask, text, sleep=sleep)
            res.calls += 1
            sections2 = parse_reply(reply2)
            if sections2:
                resolved = [(s, *resolve_slugs(s["raw_slugs"], aliases)) for s in sections2]
        except ScaleDownError:
            pass  # keep the first reply; invalid slugs become `other`
    for i, (s, slugs, inv, aliased) in enumerate(resolved):
        flags = []
        if aliased:
            flags.append("aliased")
        if res.reasked:
            flags.append("reasked")
        if not slugs:
            slugs = ["other"]
            flags.append("forced-other")
        slugs, refined = refine_slugs(slugs, s["subject"], s["text"])
        if refined:
            flags.append("refined")
        body, _ = normalize.redact(s["text"])
        subject, _ = normalize.redact(s["subject"])
        res.sections.append({"section_no": i, "topic_slugs": slugs, "subject": subject,
                             "repo_hint": s["repo_hint"], "text": body, "flags": flags})
    return res


def scaledown_call(api_key: str):
    """Return a ``call(system, user)`` that posts to ScaleDown Summarize."""
    def call(system: str, user: str) -> str:
        body = json.dumps({"model": "summarize", "messages": [
            {"role": "system", "content": system}, {"role": "user", "content": user}]}).encode()
        req = urllib.request.Request(ENDPOINT, data=body, method="POST", headers={
            "content-type": "application/json", "x-api-key": api_key})
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
                data = json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            raise ScaleDownError(f"HTTP {exc.code}", status=exc.code) from None
        except (urllib.error.URLError, TimeoutError, ValueError) as exc:
            raise ScaleDownError(f"{type(exc).__name__}") from None
        try:
            return data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError):
            raise ScaleDownError("unexpected reply shape") from None
    return call


def api_key_from_env() -> str:
    key = os.environ.get("SCALEDOWN_API_KEY", "").strip()
    if not key:
        raise SystemExit("SCALEDOWN_API_KEY is not set (load it from 1Password; never print it)")
    return key


def live_check(path: str, threads: int = 6) -> dict:
    """Segment one real session; return counts and sizes only."""
    from concurrent.futures import ThreadPoolExecutor
    started = time.time()
    parsed = normalize.parse_file(path)
    lineage = parsed["meta"]["session_id"]
    records = [(turn_key_str(lineage, t), t) for t in parsed["turns"]]
    chunks = make_chunks(lineage, records, "v1")
    call = scaledown_call(api_key_from_env())
    prompt, aliases = load_prompt(DEFAULT_PROMPT), load_aliases()
    stats = {"file_bytes": os.path.getsize(path), "turns": len(parsed["turns"]),
             "turn_chars": sum(len(t["text"]) for t in parsed["turns"]),
             "redactions": parsed["redactions"], "chunks": len(chunks), "calls": 0,
             "failed_chunks": 0, "sections": 0, "section_chars": 0, "invalid_slugs_final": 0,
             "aliased_sections": 0, "reasked_sections": 0, "other_sections": 0,
             "multi_topic_sections": 0, "tool_calls": sum(len(t["tools"]) for t in parsed["turns"])}

    def one(ch):
        try:
            return label_chunk(ch["text"], call, prompt, aliases)
        except ScaleDownError as exc:
            return exc

    with ThreadPoolExecutor(max_workers=threads) as pool:
        for res in pool.map(one, chunks):
            if isinstance(res, ScaleDownError):
                stats["failed_chunks"] += 1
                continue
            stats["calls"] += res.calls
            for s in res.sections:
                stats["sections"] += 1
                stats["section_chars"] += len(s["text"])
                stats["invalid_slugs_final"] += sum(1 for x in s["topic_slugs"] if x not in SLUG_SET)
                stats["aliased_sections"] += "aliased" in s["flags"]
                stats["reasked_sections"] += "reasked" in s["flags"]
                stats["other_sections"] += s["topic_slugs"] == ["other"]
                stats["multi_topic_sections"] += len(s["topic_slugs"]) > 1
    stats["wall_seconds"] = round(time.time() - started, 1)
    return stats


def main(argv=None) -> int:
    import argparse
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--live-check", metavar="JSONL", required=True,
                    help="segment one real session; print counts only")
    ap.add_argument("--threads", type=int, default=6)
    a = ap.parse_args(argv)
    print(json.dumps(live_check(a.live_check, a.threads), indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
