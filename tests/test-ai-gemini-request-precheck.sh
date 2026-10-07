#!/usr/bin/env bash
# Focused pre-check tests for Codex findings on PR 1362 (request before requalify).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-gemini"
export REAL_REVIEW_PACKET="$ROOT/bin/ai-review-packet"
. "$ROOT/tests/lib-test-harness.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
. "$ROOT/tests/lib-review-public-fixture.sh"
ai_test_public_sources "$TMP"
export AI_REVIEW_EVENT_DIR="$TMP/reviewer-events"
mkdir -p "$TMP/bin" "$TMP/state" "$TMP/copies" "$TMP/quarantine"
export AI_REVIEW_QUARANTINE_DIR="$TMP/quarantine"
export MOCK_COPIES="$TMP/copies"
export MOCK_AGY_CALLS="$TMP/agy-calls"
export AI_GEMINI_BIN="$TMP/bin/agy"
export AI_REVIEW_SANDBOX_BIN="$TMP/bin/sandbox"
export AI_REVIEW_PACKET_BIN="$TMP/bin/packet"
export AI_GEMINI_STATE_DIR="$TMP/state"
export AI_GEMINI_CALLER=test
export PATH="$TMP/bin:$PATH"
cat > "$TMP/bin/agy" <<'EOF'
#!/usr/bin/env bash
set -e
case "${1:-}" in --version) echo 1.1.14; exit;; --help) echo --sandbox; exit;; models) echo 'gemini-3.8-flash-high'; exit;; esac
printf '%s\n' "$*" >> "$MOCK_AGY_CALLS"
args=" $* "
if [[ "$args" == *" /model "* ]]; then
  printf '{"status":"SUCCESS","conversation_id":"conv-good","command":{"name":"model","data":{"id":"gemini-3.8-flash-high","is_default":false}}}\n'
  exit
fi
printf '{"status":"SUCCESS","conversation_id":"conv-good","response":%s}\n' "$(printf '%s' $'## Verdict\nAPPROVE' | jq -Rs .)"
EOF
cat > "$TMP/bin/sandbox" <<'EOF'
#!/usr/bin/env bash
set -e
case "$1" in
 ensure-copy) src="$2"; tag="$3"; dst="$MOCK_COPIES/$tag"; cp -a "$src" "$dst"; printf '%s\nevidence_format=1\n' "$src" > "$dst/.ai-review-sandbox"; printf %s "$dst" ;;
 remove-copy) rm -rf "$MOCK_COPIES/$3" ;;
 *) exit 2 ;;
esac
EOF
cat > "$TMP/bin/packet" <<'EOF'
#!/usr/bin/env bash
set -e
case "$1" in
 resolve) exec "$REAL_REVIEW_PACKET" "$@" ;;
 build) p="$2/.ai-review-$3"; mkdir -p "$p"; if [ "${4:-}" = --identity ]; then cp "$5" "$p/identity.json"; fi; printf manifest > "$p/MANIFEST.md"; sha256sum "$p/MANIFEST.md" > "$p/MANIFEST.sha256"; printf %s "$p" ;;
 verify) test -s "$2/MANIFEST.sha256" ;;
 path) printf %s "$2/.ai-review-$3" ;;
 remove) rm -rf "$2/.ai-review-$3" ;;
 *) exit 2 ;;
esac
EOF
chmod +x "$TMP/bin/"*
mkdir -p "$TMP/tools"
cp "$ROOT/tools/reviewer_event_guard.sh" "$ROOT/tools/reviewer_events.py" "$ROOT/tools/reviewer_maintenance.py" "$ROOT/tools/reviewer_admission.py" "$TMP/tools/" 2>/dev/null || true
make_repo(){ local r="$1"; mkdir -p "$r"; git -C "$r" init -q; git -C "$r" config user.email t@t; git -C "$r" config user.name t; printf x > "$r/file.txt"; printf '/.ai\n' > "$r/.gitignore"; git -C "$r" add -A; git -C "$r" commit -qm init; }
WRAPPER_SHA="$(sha256sum "$SCRIPT" | awk '{print $1}')"
AGY_SHA="$(sha256sum "$TMP/bin/agy" | awk '{print $1}')"
write_q(){ jq -nc --arg sha "$WRAPPER_SHA" --arg agy "${1:-1.1.14}" --arg agy_sha "$AGY_SHA" --arg model gemini-3.8-flash-high '{version:2,provider:"gemini",wrapper_sha256:$sha,agy_version:$agy,agy_sha256:$agy_sha,model:$model,qualified_epoch:1}' > "$AI_REVIEW_QUARANTINE_DIR/gemini-live-qualified.json"; }
R="$TMP/repo"; make_repo "$R"
write_q 1.1.15
: > "$MOCK_AGY_CALLS"

check 'invalid session name never auto-requalifies' "! (cd '$R' && '$SCRIPT' new 'bad name!' --prompt review) 2>'$TMP/a.err' && grep -q 'invalid session name' '$TMP/a.err' && ! grep -q 'requalifying automatically' '$TMP/a.err' && test ! -s '$MOCK_AGY_CALLS'"
check 'invalid governed SHA never auto-requalifies' "! (cd '$R' && '$SCRIPT' new --governed-verdict not-a-sha badsha --prompt review) 2>'$TMP/b.err' && grep -q '40-character commit SHA' '$TMP/b.err' && ! grep -q 'requalifying automatically' '$TMP/b.err' && test ! -s '$MOCK_AGY_CALLS'"
check 'mismatched governed SHA never auto-requalifies' "! (cd '$R' && '$SCRIPT' new --governed-verdict 1111111111111111111111111111111111111111 badgov --prompt review) 2>'$TMP/b2.err' && grep -q 'reviewed HEAD' '$TMP/b2.err' && ! grep -q 'requalifying automatically' '$TMP/b2.err' && test ! -s '$MOCK_AGY_CALLS'"
check 'invalid assert-head never auto-requalifies' "! (cd '$R' && '$SCRIPT' new badassert --assert-head zzzz --prompt review) 2>'$TMP/c.err' && grep -q 'assert head' '$TMP/c.err' && ! grep -q 'requalifying automatically' '$TMP/c.err' && test ! -s '$MOCK_AGY_CALLS'"
check 'missing session ask never auto-requalifies' "! (cd '$R' && '$SCRIPT' ask missing-session --prompt review) 2>'$TMP/d.err' && grep -q 'session not found' '$TMP/d.err' && ! grep -q 'requalifying automatically' '$TMP/d.err' && test ! -s '$MOCK_AGY_CALLS'"
check 'unknown assert-head commit never auto-requalifies' "! (cd '$R' && '$SCRIPT' new badcommit --assert-head 0000000000000000000000000000000000000000 --prompt review) 2>'$TMP/e.err' && ! grep -q 'requalifying automatically' '$TMP/e.err' && test ! -s '$MOCK_AGY_CALLS'"
# duplicate-new under drift
write_q 1.1.14
(cd "$R" && "$SCRIPT" new dupsrc --prompt review) >/dev/null
write_q 1.1.15; : > "$MOCK_AGY_CALLS"
check 'duplicate new never auto-requalifies' "! (cd '$R' && '$SCRIPT' new dupsrc --prompt review) 2>'$TMP/f.err' && grep -q 'session already exists' '$TMP/f.err' && ! grep -q 'requalifying automatically' '$TMP/f.err' && test ! -s '$MOCK_AGY_CALLS'"
check 'record_qualification rejects an empty runtime version' "grep -q '\\[ -n \"\$av\" \\] || return 1' '$SCRIPT' && grep -q '\\[ -n \"\$as\" \\] || return 1' '$SCRIPT'"
# Codex: a valid request under runtime-only drift must reach auto_requalify
write_q 1.1.15; : > "$MOCK_AGY_CALLS"
check 'valid request under runtime drift auto-requalifies' "(cd '$R' && '$SCRIPT' new autoreq --prompt review) 2>'$TMP/g.err' | grep -q '^PASS' && grep -q 'requalifying automatically' '$TMP/g.err'"
printf 'ok tests\n'
