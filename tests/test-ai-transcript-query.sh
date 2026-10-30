#!/usr/bin/env bash
# bin/ai-transcript-query against a synthetic store and pointer (plan step 8,
# popcre/ai-devops#2050, #2062). Synthetic fixtures only.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
store="$work/transcript-store"
export AI_TRANSCRIPT_STORE_ROOT="$store" AI_TRANSCRIPT_STORE_CACHE="$work/cache"
mkdir -p "$store/db" "$store/inbox"
q() { bash "$ROOT/bin/ai-transcript-query" --no-wait "$@"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; if [ $# -gt 1 ]; then printf '%s\n' "$2" >&2; fi; exit 1; }

python3 - "$ROOT" "$store" <<'PY'
import hashlib, json, sqlite3, sys
from pathlib import Path
sys.path.insert(0, sys.argv[1] + "/tools/transcript_store")
import build
store = Path(sys.argv[2])
def make(name, segs):
    p = store / "db" / name
    c = sqlite3.connect(p)
    c.executescript(build.SCHEMA)
    c.executemany("INSERT INTO sessions (path, machine, last_ts) VALUES (?,?,?)", [
        ("edge-dev3/a.jsonl", "edge-dev3", "2026-10-29T14:00:00Z"),
        ("old-box/b.jsonl", "old-box", "2026-10-20T14:00:00Z")])
    c.execute("INSERT INTO chunks (chunk_id, path, first_turn_key, last_turn_key) VALUES ('c1','edge-dev3/a.jsonl','t3','t9')")
    for sid, topics, repo, subj, text in segs:
        cur = c.execute("INSERT INTO segments (id, chunk_id, section_no, path, topic_slugs, subject, repo, text, created)"
                        " VALUES (?,?,?,?,?,?,?,?,?)", (sid, "c1", 0, "edge-dev3/a.jsonl", topics, subj, repo, text, "2026-10-29"))
        c.execute("INSERT INTO segments_fts(rowid, subject, text) VALUES (?,?,?)", (cur.lastrowid, subj, text))
    c.commit()
    c.execute("PRAGMA journal_mode=DELETE")
    c.close()
    return p
segs = [("seg1", "reviewer-tooling,billing", "designflow", "Reviewer hit 402", "the provider answered HTTP 402 payment required"),
        ("seg2", "ci", "ai-devops", "Merge queue", "queue ejected the PR")]
make("store-20261028T000000Z.db", segs[:1] + [("segold", "ci", "ai-devops", "older version", "x")])
cur = make("store-20261029T000000Z.db", segs)
data = cur.read_bytes()
ptr = {"file": "db/" + cur.name, "sha256": hashlib.sha256(data).hexdigest(), "size": len(data), "built": "x", "schema": 1}
(store / "CURRENT.json").write_text(json.dumps(ptr))
ptr["size"] += 1  # names the current file with the wrong size
(store / "BAD.json").write_text(json.dumps(ptr))
PY

# search: topic + repo + since + text
out="$(q --topic reviewer-tooling --repo designflow --since 2026-10-01 --text 402)"
printf '%s\n' "$out" | grep -q '^== seg1 ' || fail "search did not find seg1" "$out"
if printf '%s\n' "$out" | grep -q 'seg2'; then fail "search returned a non-matching segment" "$out"; fi
out="$(q --topic billing)"
printf '%s\n' "$out" | grep -q 'seg1' || fail "second topic slug not matched" "$out"
out="$(q --text nosuchword)"
[ "$out" = "no matching segments" ] || fail "empty search" "$out"
[ -z "$(find "$store" -name '*-journal' -o -name '*-wal')" ] || fail "sqlite touched a file inside the store folder"

# stats: topics, repos, machine freshness in New York time, stale flag
out="$(q --stats --now 2026-10-29T18:00:00Z)"
printf '%s\n' "$out" | grep -q '^  reviewer-tooling: 1$' || fail "stats topic count" "$out"
printf '%s\n' "$out" | grep -q '^  designflow: 1$' || fail "stats repo count" "$out"
printf '%s\n' "$out" | grep -q '^  edge-dev3: 1 sessions, last 2026-10-29 10:00 AM EDT$' || fail "fresh machine line" "$out"
printf '%s\n' "$out" | grep -q '^  old-box: 1 sessions, last 2026-10-20 10:00 AM EDT  STALE$' || fail "stale machine flag" "$out"

# raw: a pointer into the reader's own archive, never transcript text
out="$(AI_TRANSCRIPT_ARCHIVE=/arch q --raw seg1)"
printf '%s\n' "$out" | grep -q '^file: /arch/edge-dev3/a.jsonl$' || fail "raw path" "$out"
printf '%s\n' "$out" | grep -q '^turns: t3 .. t9$' || fail "raw turn range" "$out"

# size mismatch: falls back to the older verified version
rm -rf -- "$work/cache"
cp "$store/CURRENT.json" "$work/good.json"
cp "$store/BAD.json" "$store/CURRENT.json"
out="$(q --stats)"
printf '%s\n' "$out" | grep -q 'store: db/store-20261028T000000Z.db  (FALLBACK' || fail "size mismatch did not fall back" "$out"
cp "$work/good.json" "$store/CURRENT.json"

# placeholder (0-byte) and missing pointer stop with the offline message
: > "$store/CURRENT.json"
set +e; out="$(q --stats 2>&1)"; rc=$?; set -e
{ [ "$rc" = 2 ] && printf '%s\n' "$out" | grep -q 'store not available locally'; } || fail "placeholder pointer" "$out"
rm "$store/CURRENT.json"
set +e; out="$(q --text x 2>&1)"; rc=$?; set -e
{ [ "$rc" = 2 ] && printf '%s\n' "$out" | grep -q 'store not available locally'; } || fail "missing pointer" "$out"

# add-labels: a valid file is queued under the inbox naming rule; a bad one is refused
printf '%s\n' '{"question":"review-value","src":"edge-dev3/a.jsonl","prompt_version":"v1","fields":{"value":3}}' > "$work/l.jsonl"
out="$(q --add-labels "$work/l.jsonl")"
printf '%s\n' "$out" | grep -Eq '^queued: review-value__[0-9]{8}T[0-9]{6}Z__[a-z0-9-]+\.jsonl$' || fail "add-labels" "$out"
[ "$(find "$store/inbox" -maxdepth 1 -name 'review-value__*.jsonl' | wc -l)" = 1 ] || fail "inbox file missing"
printf '%s\n' '{"question":"review-value","src":"../etc/passwd","prompt_version":"v1","fields":{}}' > "$work/bad.jsonl"
set +e; out="$(q --add-labels "$work/bad.jsonl" 2>&1)"; rc=$?; set -e
{ [ "$rc" = 1 ] && printf '%s\n' "$out" | grep -q '^rejected:'; } || fail "traversal label accepted" "$out"
[ "$(find "$store/inbox" -maxdepth 1 -type f | wc -l)" = 1 ] || fail "rejected file reached the inbox"
printf 'PASS: ai-transcript-query\n'
