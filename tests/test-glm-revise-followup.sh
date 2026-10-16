#!/usr/bin/env bash
# glm_revise_followup_reuses_bound_turn — offline proof that a completed GLM
# REVISE turn continues the same conversation with `ask` on the corrected head
# (issue #1678 step 3), and that REJECT stays cold for independence.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export AI_DEVOPS_TEST_MODE=1 AI_TASK_GATES_MODE=none AI_POOL_TEST_HOOKS=1 AI_POOL_CALLER=codex
export AI_REVIEW_EVENT_DIR="$TMP/events" AI_REVIEW_SANDBOX_HOME="$TMP/sandboxes"
export GLM_FIXTURE="$TMP" REAL_PACKET="$ROOT/bin/ai-review-packet" AI_GLM_STATE_DIR="$TMP/glm-state"
mkdir -p "$TMP/repo" "$TMP/events" "$AI_GLM_STATE_DIR"
git -C "$TMP/repo" init -q -b main
git -C "$TMP/repo" config user.name Test
git -C "$TMP/repo" config user.email t@example.com
printf '.ai/\n' > "$TMP/repo/.gitignore"
printf 'original\n' > "$TMP/repo/file"
git -C "$TMP/repo" add .gitignore file
git -C "$TMP/repo" commit -qm base
BASE="$(git -C "$TMP/repo" rev-parse HEAD)"
printf 'changed\n' > "$TMP/repo/file"
git -C "$TMP/repo" add file
git -C "$TMP/repo" commit -qm changed
HEAD="$(git -C "$TMP/repo" rev-parse HEAD)"
export GLM_TEST_BASE="$BASE" GLM_TEST_HEAD="$HEAD"
cat > "$TMP/lifecycle" <<'EOF'
#!/usr/bin/env bash
set -eu
case "$1" in
 identity) "$REAL_PACKET" resolve "$2" --base "$GLM_TEST_BASE" --assert-head "$GLM_TEST_HEAD" | jq '. + {repository_key:"glm-fixture-repository"}' ;;
 begin)
   "$REAL_PACKET" resolve "$PWD" --base "$GLM_TEST_BASE" --assert-head "$GLM_TEST_HEAD" > "$GLM_FIXTURE/identity"
   jq '{head,source_digest,stale:false,verdict:null}' "$GLM_FIXTURE/identity" > "$GLM_FIXTURE/state"
   printf '%s\n' "$GLM_FIXTURE/state" ;;
 finish) printf '{"stale":false,"verdict":"APPROVE"}\n' ;;
 *) exit 0 ;;
esac
EOF
cat > "$TMP/runner" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$@" > "$GLM_FIXTURE/runner-args"
cmd="${1:-}"; name="${2:-}"
case "$cmd" in new|ask) ;; *) exit 1 ;; esac
[[ "$name" == pool-glm-* ]] || exit 1
while [ "$#" -gt 0 ]; do
  case "$1" in
    --prompt-file) shift 2 ;;
    --base) shift 2 ;;
    --assert-head) shift 2 ;;
    --repo|--caller) shift 2 ;;
    *) shift ;;
  esac
done
printf 'Reviewed head %s.\n' "$GLM_TEST_HEAD"
printf 'The immutable source packet, changed files, protected snapshot boundary, exact source identity, lifecycle terminal handling, refusal conditions and tests were inspected. The change retains fail-closed validation and all existing guarantees. No findings were identified after checking relevant siblings, invalid inputs, source changes and failure paths. The exact reviewed commit remains bound throughout this report, and the model report is distinct from runtime progress chrome.\n\n## Verdict\nAPPROVE\n'
EOF
chmod +x "$TMP/lifecycle" "$TMP/runner"
export AI_REVIEW_LIFECYCLE_BIN="$TMP/lifecycle" AI_POOL_RUNNER_GLM="$TMP/runner"
pass=0; fail=0
ok() { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1" >&2; }

run_pool() {
  (cd "$TMP/repo" && timeout 45 bash "$ROOT/bin/ai-review-pool" glm final-check --force --base "$BASE" --assert-head "$HEAD") > "$TMP/out" 2>&1
}

run_pool || true
first="$(head -1 "$TMP/runner-args" 2>/dev/null || true)"
if [ "$first" = new ]; then ok 'first dispatch is cold new'; else bad "first dispatch is cold new (got $first)"; fi

rid="$(printf '%s\n%s' "$(cd "$TMP/repo" && pwd -P)" "" | sha256sum | cut -c1-12)"
mkdir -p "$AI_GLM_STATE_DIR/sessions/$rid"
printf 'Head %s\n## Verdict\nREVISE\n' "$HEAD" > "$TMP/revise-report.md"
cat > "$AI_GLM_STATE_DIR/sessions/$rid/codex--pool-glm-revise-thread.json" <<EOF
{"schema_version":2,"name":"pool-glm-revise-thread","type":"review","caller":"codex","repository_root":"$TMP/repo","last_completed_turn":{"report":"$TMP/revise-report.md"}}
EOF
rm -f "$TMP/runner-args"
run_pool || true
second="$(head -1 "$TMP/runner-args" 2>/dev/null || true)"
if [ "$second" = ask ]; then ok 'glm_revise_followup_reuses_bound_turn: REVISE continues with ask'; else bad "REVISE continues with ask (got $second)"; fi
if grep -qx 'pool-glm-revise-thread' "$TMP/runner-args" 2>/dev/null; then ok 'follow-up reuses the bound session name'; else bad 'follow-up reuses the bound session name'; fi
if grep -q 'REVISE follow-up' "$TMP/out" 2>/dev/null; then ok 'pool reports REVISE follow-up'; else bad 'pool reports REVISE follow-up'; fi

printf 'Head %s\n## Verdict\nREJECT\n' "$HEAD" > "$TMP/reject-report.md"
cat > "$AI_GLM_STATE_DIR/sessions/$rid/codex--pool-glm-revise-thread.json" <<EOF
{"schema_version":2,"name":"pool-glm-revise-thread","type":"review","caller":"codex","repository_root":"$TMP/repo","last_completed_turn":{"report":"$TMP/reject-report.md"}}
EOF
rm -f "$TMP/runner-args"
run_pool || true
third="$(head -1 "$TMP/runner-args" 2>/dev/null || true)"
if [ "$third" = new ]; then ok 'REJECT stays cold (independent re-review)'; else bad "REJECT stays cold (got $third)"; fi

printf 'passed=%s failed=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
