#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
export AI_GH_STATE_DIR="$TMP/gh-state"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

make_repo() {
  local path="$1" remote="$2"
  git init -q "$path"
  git -C "$path" remote add origin "$remote"
}

make_repo "$TMP/private" https://github.com/u2giants/ai-devops-transcripts.git
make_repo "$TMP/public" https://github.com/u2giants/ai-devops.git
make_repo "$TMP/lookalike" https://github.com/attacker/ai-devops-transcripts.git

AI_TRANSCRIPT_TEST_MODE=1 AI_TRANSCRIPT_TEST_PRIVATE=1 \
  bash "$ROOT/bin/ai-transcript-destination-check" "$TMP/private" >/dev/null ||
  fail "canonical private fixture was rejected"

for hostile in public lookalike; do
  if AI_TRANSCRIPT_TEST_MODE=1 AI_TRANSCRIPT_TEST_PRIVATE=1 \
      bash "$ROOT/bin/ai-transcript-destination-check" "$TMP/$hostile" >/dev/null 2>&1; then
    fail "$hostile destination was accepted"
  fi
done

# Production privacy proof is fresh for each invocation and uses the shared
# admission path. No private response is cached or accepted after a refusal.
mkdir -p "$TMP/bin"
cat > "$TMP/bin/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GH_LOG"
[ "$*" = "api repos/u2giants/ai-devops-transcripts --jq .private" ] || exit 2
case "${FAKE_VISIBILITY:-}" in true|false) printf '%s\n' "$FAKE_VISIBILITY" ;; *) exit 1 ;; esac
GH
chmod +x "$TMP/bin/gh"
export GH_LOG="$TMP/gh.log" AI_GH_STATE_DIR="$TMP/gh-state"
export AI_GH_MIN_SPACING_SECONDS=0 AI_GH_QUOTA_PROBE_SECONDS=off
PATH="$TMP/bin:$PATH" FAKE_VISIBILITY=true \
  bash "$ROOT/bin/ai-transcript-destination-check" "$TMP/private" >/dev/null ||
  fail 'fresh private proof failed through shared admission'
[ -f "$AI_GH_STATE_DIR/last_call_ms" ] || fail 'privacy read bypassed shared admission'
if PATH="$TMP/bin:$PATH" FAKE_VISIBILITY=false \
    bash "$ROOT/bin/ai-transcript-destination-check" "$TMP/private" >/dev/null 2>&1; then
  fail 'a newly public transcript destination was accepted'
fi
if PATH="$TMP/bin:$PATH" FAKE_VISIBILITY=error \
    bash "$ROOT/bin/ai-transcript-destination-check" "$TMP/private" >/dev/null 2>&1; then
  fail 'privacy-check failure was accepted'
fi
[ "$(wc -l < "$GH_LOG")" -eq 3 ] || fail 'privacy proof reused stale response'

if AI_TRANSCRIPT_TEST_MODE=1 AI_TRANSCRIPT_TEST_PRIVATE=1 \
    bash "$ROOT/bin/ai-transcript-destination-check" "$TMP/missing" >/dev/null 2>&1; then
  fail "non-repository destination was accepted"
fi

[[ "$(head -1 "$ROOT/skills/claude/claude-transcript-backup/SKILL.md")" == '---' ]] ||
  fail "Claude transcript skill frontmatter is not on line 1"

python3 - "$AI_GH_STATE_DIR/measurements" <<'PY' || fail 'privacy receipts lost failure/refusal/skipped boundaries'
import json, pathlib, re, sys
rows = [json.loads(line) for p in pathlib.Path(sys.argv[1]).glob('????-??-??.jsonl') for line in p.read_text().splitlines()]
receipts = [r for r in rows if r.get('measurement') == 'workflow_outcome' and r.get('caller') == 'ai-transcript-destination-check']
assert {r['outcome'] for r in receipts} == {'verified','refused','failed','skipped'}
assert sum(r['outcome'] == 'verified' for r in receipts) == 1  # Only the fresh successful API proof.
assert len({r['workflow_id'] for r in receipts}) == len(receipts)
for r in receipts:
    assert re.fullmatch('[0-9a-f]{32}', r['workflow_id'])
    assert r['workflow'] == 'transcript_privacy'
    assert set(r) == {'schema','utc','measurement','caller','workflow','workflow_id','outcome','elapsed_ms'}
PY

echo "PASS: transcript guard accepts only the canonical private destination"
