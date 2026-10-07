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
case "${1:-}" in
  --version)
    # Post-lock binding tests arm a substitution hook on the request's
    # packet resolve; the first --version after that is where a concurrent
    # delete/recreate would have swapped the same-named session.
    if [ -n "${MOCK_AGY_HOOK:-}" ] && [ -n "${MOCK_AGY_HOOK_ARM:-}" ] && [ -e "$MOCK_AGY_HOOK_ARM" ]; then
      rm -f "$MOCK_AGY_HOOK_ARM"
      bash "$MOCK_AGY_HOOK"
    fi
    echo 1.1.14; exit;;
  --help) echo --sandbox; exit;;
  models) echo 'gemini-3.8-flash-high'; exit;;
esac
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
 resolve) [ -z "${MOCK_AGY_HOOK_ARM:-}" ] || : > "$MOCK_AGY_HOOK_ARM"; exec "$REAL_REVIEW_PACKET" "$@" ;;
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
check 'invalid assert-head never auto-requalifies' "! (cd '$R' && '$SCRIPT' new badassert --assert-head zzzz --prompt review) 2>'$TMP/c.err' && grep -q 'asserted head' '$TMP/c.err' && ! grep -q 'requalifying automatically' '$TMP/c.err' && test ! -s '$MOCK_AGY_CALLS'"
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
# Codex 2026-10-07 MEDIUM: execution parses --governed-verdict from one fixed
# position, so the pre-check must refuse a duplicate or any other placement
# instead of accepting it and then running without governed output.
write_q 1.1.15; : > "$MOCK_AGY_CALLS"
check 'duplicate --governed-verdict never auto-requalifies' "! (cd '$R' && '$SCRIPT' new --governed-verdict 1111111111111111111111111111111111111111 --governed-verdict 2222222222222222222222222222222222222222 dup-gov --prompt review) 2>'$TMP/dup-gov.err' && grep -q 'may be given only once' '$TMP/dup-gov.err' && ! grep -q 'requalifying automatically' '$TMP/dup-gov.err' && test ! -s '$MOCK_AGY_CALLS'"
check 'misplaced --governed-verdict never auto-requalifies' "! (cd '$R' && '$SCRIPT' new mis-gov --governed-verdict 1111111111111111111111111111111111111111 --prompt review) 2>'$TMP/mis-gov.err' && grep -q 'must immediately follow' '$TMP/mis-gov.err' && ! grep -q 'requalifying automatically' '$TMP/mis-gov.err' && test ! -s '$MOCK_AGY_CALLS'"
check 'trailing --governed-verdict after the prompt never auto-requalifies' "! (cd '$R' && '$SCRIPT' new trail-gov --prompt review --governed-verdict 1111111111111111111111111111111111111111) 2>'$TMP/trail-gov.err' && grep -q 'must immediately follow' '$TMP/trail-gov.err' && ! grep -q 'requalifying automatically' '$TMP/trail-gov.err' && test ! -s '$MOCK_AGY_CALLS'"
write_q 1.1.14
check 'a prompt value that looks like --governed-verdict is not a flag' "(cd '$R' && '$SCRIPT' new prompt-flag --prompt --governed-verdict) 2>'$TMP/prompt-flag.err' | grep -q '^PASS'"
# Codex 2026-10-07 HIGH: the governed SHA and the requested base must be
# revalidated after the session lock. The hook rewrites the binding in the
# window between the pre-lock checks and lock acquisition, which is exactly
# what a concurrent delete/recreate of the same-named session does.
write_q 1.1.14
RR="$TMP/repo-race"; make_repo "$RR"
RR_SHA="$(git -C "$RR" rev-parse HEAD)"
(cd "$RR" && "$SCRIPT" new --base "$RR_SHA" gov-race --prompt review) >/dev/null
RR_META="$(find "$TMP/state/sessions" -name '*gov-race*.json' | head -1)"
RR_IDENT="$(jq -r .review_dir "$RR_META")/.ai-review-$(jq -r .sandbox_tag "$RR_META")/identity.json"
cat > "$TMP/hook-head.sh" <<EOF
#!/usr/bin/env bash
: > '$TMP/hook-fired-a'
jq --arg h '9999999999999999999999999999999999999999' '.head=\$h' '$RR_META' > '$RR_META.tmp' && mv '$RR_META.tmp' '$RR_META'
EOF
rm -f "$TMP/hook-fired-a"
export MOCK_AGY_HOOK_ARM="$TMP/hook-arm-a" MOCK_AGY_HOOK="$TMP/hook-head.sh"
set +e; (cd "$RR" && "$SCRIPT" ask --base "$RR_SHA" --governed-verdict "$RR_SHA" gov-race --prompt follow) >"$TMP/race-a.out" 2>"$TMP/race-a.err"; RACE_A_RC=$?; set -e
unset MOCK_AGY_HOOK MOCK_AGY_HOOK_ARM
check 'the substitution hook fired in the pre-lock window' "test -f '$TMP/hook-fired-a'"
check 'post-lock governed SHA revalidation refuses a substituted session' "test '$RACE_A_RC' -ne 0 && test -f '$TMP/hook-fired-a' && grep -q 'governed verdict head must match the reviewed HEAD' '$TMP/race-a.err'"
check 'a binding refusal does not mark the session for recovery' "test \"\$(jq -r .status '$RR_META')\" != RECOVERY_REQUIRED"
(cd "$RR" && "$SCRIPT" new --base "$RR_SHA" base-race --prompt review) >/dev/null
BR_META="$(find "$TMP/state/sessions" -name '*base-race*.json' | head -1)"
BR_IDENT="$(jq -r .review_dir "$BR_META")/.ai-review-$(jq -r .sandbox_tag "$BR_META")/identity.json"
cat > "$TMP/hook-base.sh" <<EOF
#!/usr/bin/env bash
: > '$TMP/hook-fired-b'
jq --arg b '8888888888888888888888888888888888888888' '.base=\$b' '$BR_IDENT' > '$BR_IDENT.tmp' && mv '$BR_IDENT.tmp' '$BR_IDENT'
EOF
rm -f "$TMP/hook-fired-b"
export MOCK_AGY_HOOK_ARM="$TMP/hook-arm-b" MOCK_AGY_HOOK="$TMP/hook-base.sh"
set +e; (cd "$RR" && "$SCRIPT" ask --base "$RR_SHA" base-race --prompt follow) >"$TMP/race-b.out" 2>"$TMP/race-b.err"; RACE_B_RC=$?; set -e
unset MOCK_AGY_HOOK MOCK_AGY_HOOK_ARM
check 'post-lock requested base revalidation refuses a substituted session' "test '$RACE_B_RC' -ne 0 && test -f '$TMP/hook-fired-b' && grep -q 'requested base differs from the sealed review identity' '$TMP/race-b.err'"
# The --assert-head sibling: a replacement plus a checkout advance leaves the
# pre-lock assertion holding while the review would resume on another HEAD.
(cd "$RR" && "$SCRIPT" new assert-race --prompt review) >/dev/null
CR_META="$(find "$TMP/state/sessions" -name '*assert-race*.json' | head -1)"
CR_HEAD="$(jq -r .head "$CR_META")"
cat > "$TMP/hook-assert.sh" <<EOF
#!/usr/bin/env bash
: > '$TMP/hook-fired-c'
git -C '$RR' commit --allow-empty -qm 'advance under the review'
NEW_HEAD="\$(git -C '$RR' rev-parse HEAD)"
jq --arg h "\$NEW_HEAD" '.head=\$h' '$CR_META' > '$CR_META.tmp' && mv '$CR_META.tmp' '$CR_META'
EOF
rm -f "$TMP/hook-fired-c"
export MOCK_AGY_HOOK_ARM="$TMP/hook-arm-c" MOCK_AGY_HOOK="$TMP/hook-assert.sh"
set +e; (cd "$RR" && "$SCRIPT" ask --assert-head "$CR_HEAD" assert-race --prompt follow) >"$TMP/race-c.out" 2>"$TMP/race-c.err"; RACE_C_RC=$?; set -e
unset MOCK_AGY_HOOK MOCK_AGY_HOOK_ARM
check 'post-lock assert-head revalidation refuses a substituted session' "test '$RACE_C_RC' -ne 0 && test -f '$TMP/hook-fired-c' && grep -q 'asserted head no longer matches the reviewed source' '$TMP/race-c.err'"
# The live-head leg alone: the binding still matches the frozen session head,
# but the checkout advanced under the pre-lock assertion.
(cd "$RR" && "$SCRIPT" new assert-live --prompt review) >/dev/null
CL_META="$(find "$TMP/state/sessions" -name '*assert-live*.json' | head -1)"
CL_HEAD="$(jq -r .head "$CL_META")"
cat > "$TMP/hook-live.sh" <<EOF
#!/usr/bin/env bash
: > '$TMP/hook-fired-d'
git -C '$RR' commit --allow-empty -qm 'advance again under the review'
EOF
rm -f "$TMP/hook-fired-d"
export MOCK_AGY_HOOK_ARM="$TMP/hook-arm-d" MOCK_AGY_HOOK="$TMP/hook-live.sh"
set +e; (cd "$RR" && "$SCRIPT" ask --assert-head "$CL_HEAD" assert-live --prompt follow) >"$TMP/race-d.out" 2>"$TMP/race-d.err"; RACE_D_RC=$?; set -e
unset MOCK_AGY_HOOK MOCK_AGY_HOOK_ARM
check 'post-lock assert-head revalidation also catches a checkout advance' "test '$RACE_D_RC' -ne 0 && test -f '$TMP/hook-fired-d' && grep -q 'asserted head no longer matches the reviewed source' '$TMP/race-d.err'"
printf 'ok tests\n'
