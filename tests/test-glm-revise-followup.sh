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
export RUN_ID_FIXTURE="$(printf '%032d' 99)"
# Shared offline isolation (#1435, #1505): marker, cleared outer review session.
. "$ROOT/tests/lib-reviewer-events-isolation.sh"
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
 finish)
   v=APPROVE
   while [ "$#" -gt 0 ]; do
     case "$1" in --verdict) v="$2"; shift 2 ;; *) shift ;; esac
   done
   printf '{"stale":false,"verdict":"%s"}\n' "$v" ;;
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
printf 'The immutable source packet, changed files, protected snapshot boundary, exact source identity, lifecycle terminal handling, refusal conditions and tests were inspected. The change retains fail-closed validation and all existing guarantees. Findings: one fix is required before this head can pass. The exact reviewed commit remains bound throughout this report, and the model report is distinct from runtime progress chrome.\n\n## Verdict\n'
if [ "${GLM_POOL_VERDICT:-APPROVE}" = REVISE ]; then printf 'REVISE\n'; else printf 'APPROVE\n'; fi
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
if grep -qx -- '--repo' "$TMP/runner-args" 2>/dev/null && grep -E '/repo$' "$TMP/runner-args" >/dev/null 2>&1; then
  ok 'dispatch binds --repo to the original checkout'
else
  bad 'dispatch binds --repo to the original checkout'
fi

rid="$(printf '%s\n%s' "$(cd "$TMP/repo" && pwd -P)" "" | sha256sum | cut -c1-12)"
mkdir -p "$AI_GLM_STATE_DIR/sessions/$rid"
printf 'Head %s\n## Verdict\nREVISE\n' "$HEAD" > "$TMP/revise-report.md"
cat > "$AI_GLM_STATE_DIR/sessions/$rid/codex--pool-glm-revise-thread.json" <<EOF
{"schema_version":2,"name":"pool-glm-revise-thread","type":"review","caller":"codex","repository_root":"$TMP/repo","last_activity_at":"2026-10-18T12:00:00Z","last_completed_turn":{"report":"$TMP/revise-report.md"}}
EOF
rm -f "$TMP/runner-args"
run_pool || true
second="$(head -1 "$TMP/runner-args" 2>/dev/null || true)"
if [ "$second" = ask ]; then ok 'glm_revise_followup_reuses_bound_turn: REVISE continues with ask'; else bad "REVISE continues with ask (got $second)"; fi
if grep -qx 'pool-glm-revise-thread' "$TMP/runner-args" 2>/dev/null; then ok 'follow-up reuses the bound session name'; else bad 'follow-up reuses the bound session name'; fi
if grep -q 'REVISE follow-up' "$TMP/out" 2>/dev/null; then ok 'pool reports REVISE follow-up'; else bad 'pool reports REVISE follow-up'; fi

# A failed warm attempt must fall back to cold new (no re-select forever).
# ask was armed above and succeeded (rc 0), so clear happened; re-arm and fail.
: > "$AI_GLM_STATE_DIR/sessions/$rid/codex--pool-glm-revise-thread.json.followup-armed"
rm -f "$TMP/runner-args"
run_pool || true
fallback="$(head -1 "$TMP/runner-args" 2>/dev/null || true)"
if [ "$fallback" = new ]; then ok 'failed/armed follow-up falls back to cold new'; else bad "failed/armed follow-up falls back to cold new (got $fallback)"; fi

# Recency: newest REVISE wins over an older one (not filename order).
rm -f "$AI_GLM_STATE_DIR/sessions/$rid/codex--pool-glm-revise-thread.json" "$AI_GLM_STATE_DIR/sessions/$rid/codex--pool-glm-revise-thread.json.followup-armed"
printf 'Head %s\n## Verdict\nREVISE\n' "$HEAD" > "$TMP/revise-old.md"
cat > "$AI_GLM_STATE_DIR/sessions/$rid/codex--pool-glm-aaaa-old.json" <<EOF
{"schema_version":2,"name":"pool-glm-aaaa-old","type":"review","caller":"codex","repository_root":"$TMP/repo","last_activity_at":"2020-01-01T00:00:00Z","last_completed_turn":{"report":"$TMP/revise-old.md"}}
EOF
printf 'Head %s\n## Verdict\nREVISE\n' "$HEAD" > "$TMP/revise-new.md"
cat > "$AI_GLM_STATE_DIR/sessions/$rid/codex--pool-glm-zzzz-new.json" <<EOF
{"schema_version":2,"name":"pool-glm-zzzz-new","type":"review","caller":"codex","repository_root":"$TMP/repo","last_activity_at":"2026-10-18T12:00:00Z","last_completed_turn":{"report":"$TMP/revise-new.md"}}
EOF
rm -f "$TMP/runner-args" "$AI_GLM_STATE_DIR/sessions/$rid/codex--pool-glm-aaaa-old.json.followup-armed" "$AI_GLM_STATE_DIR/sessions/$rid/codex--pool-glm-zzzz-new.json.followup-armed"
run_pool || true
if grep -qx 'pool-glm-zzzz-new' "$TMP/runner-args" 2>/dev/null; then ok 'newest REVISE session is selected'; else bad "newest REVISE session is selected (got $(head -1 "$TMP/runner-args" 2>/dev/null))"; fi

printf 'Head %s\n## Verdict\nREJECT\n' "$HEAD" > "$TMP/reject-report.md"
cat > "$AI_GLM_STATE_DIR/sessions/$rid/codex--pool-glm-revise-thread.json" <<EOF
{"schema_version":2,"name":"pool-glm-revise-thread","type":"review","caller":"codex","repository_root":"$TMP/repo","last_activity_at":"2026-10-18T12:00:00Z","last_completed_turn":{"report":"$TMP/reject-report.md"}}
EOF
rm -f "$AI_GLM_STATE_DIR/sessions/$rid/codex--pool-glm-aaaa-old.json" "$AI_GLM_STATE_DIR/sessions/$rid/codex--pool-glm-zzzz-new.json" "$AI_GLM_STATE_DIR/sessions/$rid"/codex--*.followup-armed
rm -f "$TMP/runner-args"
run_pool || true
third="$(head -1 "$TMP/runner-args" 2>/dev/null || true)"
if [ "$third" = new ]; then ok 'REJECT stays cold (independent re-review)'; else bad "REJECT stays cold (got $third)"; fi

# A compliant REVISE from the runner is a completed outcome (not missing-verdict).
export GLM_POOL_VERDICT=REVISE
rm -f "$TMP/runner-args"
if run_pool; then ok 'pool accepts REVISE as a completed verdict'
else
  bad 'pool accepts REVISE as a completed verdict'
  tail -20 "$TMP/out" >&2 || true
fi
unset GLM_POOL_VERDICT

# glm_followup_clear: after a successful warm turn the marker is gone and the
# next REVISE can warm-follow again (not stuck cold forever).
rm -f "$AI_GLM_STATE_DIR/sessions/$rid"/codex--*.json "$AI_GLM_STATE_DIR/sessions/$rid"/codex--*.followup-armed
printf 'Head %s\n## Verdict\nREVISE\n' "$HEAD" > "$TMP/revise-thread2.md"
cat > "$AI_GLM_STATE_DIR/sessions/$rid/codex--pool-glm-clear-thread.json" <<EOF
{"schema_version":2,"name":"pool-glm-clear-thread","type":"review","caller":"codex","repository_root":"$TMP/repo","last_activity_at":"2026-10-18T13:00:00Z","last_completed_turn":{"report":"$TMP/revise-thread2.md"}}
EOF
rm -f "$TMP/runner-args"
run_pool || true
if [ "$(head -1 "$TMP/runner-args" 2>/dev/null)" = ask ] && [ ! -e "$AI_GLM_STATE_DIR/sessions/$rid/codex--pool-glm-clear-thread.json.followup-armed" ]; then
  ok 'glm_followup_clear removes the arm marker after successful ask'
else
  bad 'glm_followup_clear removes the arm marker after successful ask'
fi
# Second REVISE after a cleared warm turn must warm-follow again.
rm -f "$TMP/runner-args"
run_pool || true
if [ "$(head -1 "$TMP/runner-args" 2>/dev/null)" = ask ]; then
  ok 'cleared follow-up can warm-follow again on a later REVISE'
else
  bad "cleared follow-up can warm-follow again on a later REVISE (got $(head -1 "$TMP/runner-args" 2>/dev/null))"
fi

# Real lifecycle terminal contract: finish --verdict REVISE must complete
# (stubs above cannot catch a REVISE terminal-contract gap).
lc_dir="$TMP/lifecycle-real"; mkdir -p "$lc_dir"
lc_state="$(bash "$ROOT/bin/ai-review-lifecycle" begin --provider glm --repo "$TMP/repo" --run-id "$RUN_ID_FIXTURE" --caller codex --preflight standard 2>/dev/null)" || lc_state=""
if [ -n "$lc_state" ] && [ -f "$lc_state" ]; then
  printf 'Reviewed head %s. The immutable source packet, changed files, protected snapshot boundary, exact source identity, lifecycle terminal handling, refusal conditions and tests were inspected. One fix is required before this head can pass; re-review the corrected head in this conversation. The exact reviewed commit remains bound throughout this report.\n\n## Verdict\nREVISE\n' "$HEAD" > "$TMP/lc-revise.md"
  if bash "$ROOT/bin/ai-review-lifecycle" finish --state "$lc_state" --verdict REVISE --report "$TMP/lc-revise.md" --elapsed 1 >/dev/null 2>&1; then
    ok 'lifecycle finish accepts REVISE as a terminal verdict'
  else
    bad 'lifecycle finish accepts REVISE as a terminal verdict'
  fi
else
  bad 'lifecycle finish accepts REVISE as a terminal verdict (begin failed)'
fi

# Probe branch guards (source contract; formal route is Linux-only at runtime).
if grep -q "formal GLM activation is invalid; no legacy fallback" "$ROOT/bin/ai-review-pool" && \
   grep -q "invalid formal route" "$ROOT/bin/ai-review-pool" && \
   grep -q 'glm_state_root="${AI_GLM_STATE_DIR:-' "$ROOT/bin/ai-review-pool"; then
  ok 'formal route stays fail-closed and probe honours AI_GLM_STATE_DIR'
else
  bad 'formal route stays fail-closed and probe honours AI_GLM_STATE_DIR'
fi

printf 'passed=%s failed=%s\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
