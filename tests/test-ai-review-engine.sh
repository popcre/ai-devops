#!/usr/bin/env bash
# Tests for the shared review runner (bin/ai-review-engine) and its Grok door.
#
# Fully offline: a mock door and a stub `grok` binary stand in for providers.
# No network, no xAI/DeepSeek calls, no cost.
#
# The tests that matter most and must never be weakened:
#   - pool_refuses_bypass_for_runner_doors / door_refuses_without_runner_token /
#     pool_refuses_ungated_engine_bin_override /
#     pool_keeps_runner_door_when_registry_unregisters_grok /
#     preflight_refuses_bypass_for_runner_doors :
#     the structural forcing function. A library the doors may skip is a
#     rejected shape; pool/preflight must REFUSE a bypassed review.
#   - adapter_source_has_no_packet_remove_or_sandbox_delete : door purity.
#   - review_contract_leaves_packet_and_report : one end-to-end door run
#     through the runner leaves packet + report.
#   - implement_contract_preserves_worktree_on_failure : implement is a real
#     worktree + recovery contract, not a thin review adapter.
#   - store_before_delete_skips_delete_when_store_fails : store-first order.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENGINE="$REPO_ROOT/bin/ai-review-engine"
CORE="$REPO_ROOT/tools/lib/review-lifecycle-core.sh"
GROK_DOOR="$REPO_ROOT/tools/lib/review-doors/grok.sh"
POOL="$REPO_ROOT/bin/ai-review-pool"
PASS=0; FAIL=0; SKIP=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

export AI_DEVOPS_TEST_MODE=1
export AI_TASK_GATES_MODE=none

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Packet/sandbox classification calls ai-task-gates; the offline suites mock it
# (same contract as tests/test-ai-review-packet.sh) so no real gate run starts.
mkdir -p "$TMP/mockbin"
cat > "$TMP/mockbin/ai-task-gates" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '{"identity_resolved":true,"effective_class":"code","observed_class":"code"}'
EOF
chmod +x "$TMP/mockbin/ai-task-gates"
export PATH="$TMP/mockbin:$PATH"

# Keep every runner artifact inside the suite temp dir.
export AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes"
export AI_REVIEW_LIFECYCLE_DIR="$TMP/lifecycle-state"
export AI_REVIEW_PACKET_STORE="$TMP/packet-store"
export AI_REVIEW_IMPLEMENT_ROOT="$TMP/implement"

echo '== review-lifecycle-core library'
check "core_declares_one_stamp" "grep -q 'RLC_STAMP=\"review-lifecycle-core/1\"' '$CORE'"
check "core_owns_report_floor" "grep -q 'MIN_REPORT_CHARS=' '$CORE' && grep -q 'rlc_report_substance' '$CORE'"
check "core_owns_store_before_delete" "grep -q 'rlc_packet_store' '$CORE' && grep -q 'rlc_cleanup_after_store' '$CORE'"
check "core_unifies_tag_and_dir_budgets" "grep -q 'RLC_TAG_MAX=48' '$CORE' && grep -q 'RLC_DIR_MAX=64' '$CORE'"
check "core_owns_both_contracts" "grep -q 'rlc_run_review' '$CORE' && grep -q 'rlc_run_implement' '$CORE'"

# --- tag budget -------------------------------------------------------------
# shellcheck disable=SC1090
. "$CORE"
NAME300="$(printf 'x%.0s' $(seq 1 300))"
BOUNDED="$(rlc_short_name "$NAME300" 64)"
check "short_name_bounds_to_dir_budget" "test \${#BOUNDED} -le 64"
check "short_name_keeps_short_names" "[ \"\$(rlc_short_name abc 64)\" = abc ]"
OVERSIZE="$(printf 'x%.0s' $(seq 1 78))"
check "assert_tag_budget_refuses_oversize" "! (rlc_assert_tag_budget \"$OVERSIZE\") 2>/dev/null"
check "assert_tag_budget_documents_unified_limits" "grep -q 'dir budget' '$CORE'"

# --- report floor -----------------------------------------------------------
FLOOR_EMPTY="$TMP/empty.md"
FLOOR_REAL="$TMP/real.md"
printf '## Verdict\nAPPROVE\n' > "$FLOOR_EMPTY"
{
  printf '# Review\n\n'
  printf 'Read every changed hunk against the stated intent. The lock release path is correct,\n'
  printf 'the digest is recomputed at the terminal transition, and no path writes outside\n'
  printf 'managed storage. The scoreboard append is checked and an accounting failure keeps\n'
  printf 'the lock for recovery rather than reporting success. No blocking findings.\n'
  printf 'Additional analysis of sibling issues in the same class found none.\n'
  printf '\n## Verdict\nAPPROVE\n'
} > "$FLOOR_REAL"
check "report_floor_rejects_bare_decision" "! bash -c 'set -e; . \"'$CORE'\"; rlc_report_floor_ok \"'$FLOOR_EMPTY'\"'"
check "report_floor_accepts_substance" "bash -c 'set -e; . \"'$CORE'\"; rlc_report_floor_ok \"'$FLOOR_REAL'\"'"

# --- structural forcing function: door refuses without the runner token -----
echo '== structural forcing function (doors)'
set +e
( unset AI_REVIEW_RUNNER_CORE; bash "$GROK_DOOR" review ) >"$TMP/door-bypass.out" 2>"$TMP/door-bypass.err"
DOOR_BYPASS_RC=$?
set -e
check "door_refuses_without_runner_token" "test '$DOOR_BYPASS_RC' -ne 0 && grep -q 'bypasses the shared runner' '$TMP/door-bypass.err'"
check "door_refusal_is_exit_2" "test '$DOOR_BYPASS_RC' -eq 2"

# --- structural forcing function: pool refuses a bypassed runner ------------
echo '== structural forcing function (pool)'
NOT_ENGINE="$TMP/not-the-engine.sh"
cat > "$NOT_ENGINE" <<'EOF'
#!/usr/bin/env bash
echo "this script must never be used as a pool runner for a registered door" >&2
exit 99
EOF
chmod +x "$NOT_ENGINE"

# A disposable repo the pool can classify and refuse inside.
PREPO="$TMP/pool-repo"
mkdir -p "$PREPO"
git -C "$PREPO" init -q -b main
git -C "$PREPO" config user.name Test
git -C "$PREPO" config user.email t@example.com
printf 'base\n' > "$PREPO/a.txt"
git -C "$PREPO" add a.txt
git -C "$PREPO" commit -qm init
printf '.ai/\n' > "$PREPO/.gitignore"
git -C "$PREPO" add .gitignore
git -C "$PREPO" commit -qm ignore

set +e
( cd "$PREPO" && AI_POOL_TEST_HOOKS=1 AI_POOL_RUNNER_GROK="$NOT_ENGINE" \
    AI_POOL_CALLER=codex bash "$POOL" grok diff-review ) >"$TMP/pool-bypass.out" 2>"$TMP/pool-bypass.err"
POOL_BYPASS_RC=$?
set -e
check "pool_refuses_bypass_for_runner_doors" "test '$POOL_BYPASS_RC' -ne 0 && grep -q 'bypasses the shared review runner' '$TMP/pool-bypass.err'"
check "pool_bypass_refusal_names_the_engine" "grep -q 'ai-review-engine' '$TMP/pool-bypass.err'"

# Unregistered providers keep their existing session-runner path (muse is not
# in the doors registry), so a plain substitution is still allowed under hooks.
# Provider preflight is stubbed: this check proves dispatch routing, not the
# host's Muse health (a missing provider binary must not decide the outcome).
POOL_PF_STUB="$TMP/pool-preflight-stub"
cat > "$POOL_PF_STUB" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$POOL_PF_STUB"
set +e
( cd "$PREPO" && AI_POOL_TEST_HOOKS=1 AI_POOL_RUNNER_MUSE="$NOT_ENGINE" \
    AI_REVIEW_PREFLIGHT_BIN="$POOL_PF_STUB" \
    AI_POOL_CALLER=codex bash "$POOL" muse diff-review ) >"$TMP/pool-muse.out" 2>"$TMP/pool-muse.err"
POOL_MUSE_RC=$?
set -e
# The stub exits 99; the pool must have LAUNCHED it (not refused as bypass).
check "pool_still_dispatches_unregistered_doors" "grep -q 'must never be used' '$TMP/pool-muse.err' || test '$POOL_MUSE_RC' -eq 99"

# --- structural forcing function: AI_REVIEW_ENGINE_BIN is a gated test hook --
echo '== structural forcing function (engine bin gate)'
FAKE_ENGINE="$TMP/fake-engine.sh"
cat > "$FAKE_ENGINE" <<EOF
#!/usr/bin/env bash
printf 'invoked: %s\n' "\$*" >> "$TMP/engine-invoked.log"
exit 99
EOF
chmod +x "$FAKE_ENGINE"

# Without AI_POOL_TEST_HOOKS=1 an injected engine bin is refused and never
# invoked: it would otherwise export the runner token and skip every
# governance step while still satisfying the door.
rm -f "$TMP/engine-invoked.log"
set +e
( cd "$PREPO" && AI_REVIEW_ENGINE_BIN="$FAKE_ENGINE" \
    AI_POOL_CALLER=codex bash "$POOL" grok diff-review ) >"$TMP/pool-eng.out" 2>"$TMP/pool-eng.err"
POOL_ENG_RC=$?
set -e
check "pool_refuses_ungated_engine_bin_override" \
  "test '$POOL_ENG_RC' -ne 0 && grep -q 'AI_REVIEW_ENGINE_BIN' '$TMP/pool-eng.err' && test ! -f '$TMP/engine-invoked.log'"

# --- structural forcing function: the shipped door set cannot be shrunk ------
echo '== structural forcing function (doors registry cannot shrink)'
SHRUNK_DOORS="$TMP/doors-no-grok.json"
printf '{\n  "schema_version": 1,\n  "_comment": "grok deliberately unregistered"\n}\n' > "$SHRUNK_DOORS"
rm -f "$TMP/engine-invoked.log"
set +e
( cd "$PREPO" && AI_POOL_TEST_HOOKS=1 AI_REVIEW_ENGINE_BIN="$FAKE_ENGINE" \
    AI_REVIEW_RUNNER_DOORS_JSON="$SHRUNK_DOORS" \
    AI_POOL_CALLER=codex bash "$POOL" grok diff-review ) >"$TMP/pool-shrunk.out" 2>"$TMP/pool-shrunk.err"
POOL_SHRUNK_RC=$?
set -e
# Unregistering grok via the env JSON must NOT fall through to the legacy
# session-runner path: the shipped registry still owns the door set, so the
# review is dispatched through the engine (the gated fake records its argv).
check "pool_keeps_runner_door_when_registry_unregisters_grok" \
  "grep -q 'invoked: review --provider grok' '$TMP/engine-invoked.log'"
check "pool_shrunk_registry_never_reaches_legacy_runner" \
  "test '$POOL_SHRUNK_RC' -eq 99"

# A missing doors file is the same class: it must not unregister the door.
rm -f "$TMP/engine-invoked.log"
set +e
( cd "$PREPO" && AI_POOL_TEST_HOOKS=1 AI_REVIEW_ENGINE_BIN="$FAKE_ENGINE" \
    AI_REVIEW_RUNNER_DOORS_JSON="$TMP/doors-missing.json" \
    AI_POOL_CALLER=codex bash "$POOL" grok diff-review ) >"$TMP/pool-missing.out" 2>"$TMP/pool-missing.err"
POOL_MISSING_RC=$?
set -e
check "pool_keeps_runner_door_when_registry_file_is_missing" \
  "grep -q 'invoked: review --provider grok' '$TMP/engine-invoked.log' && test '$POOL_MISSING_RC' -eq 99"

# --- structural forcing function: preflight refuses the same bypass ----------
echo '== structural forcing function (preflight)'
PREFLIGHT_BIN="$REPO_ROOT/bin/ai-review-preflight"
rm -f "$TMP/engine-invoked.log"
set +e
( cd "$PREPO" && AI_REVIEW_QUARANTINE_DIR="$TMP/pf-state" \
    AI_REVIEW_ENGINE_BIN="$FAKE_ENGINE" \
    AI_POOL_CALLER=codex bash "$PREFLIGHT_BIN" check grok "$PREPO" ) >"$TMP/pf-bypass.out" 2>"$TMP/pf-bypass.err"
PF_BYPASS_RC=$?
set -e
check "preflight_refuses_bypass_for_runner_doors" \
  "test '$PF_BYPASS_RC' -ne 0 && grep -qi 'refus' '$TMP/pf-bypass.err' && test ! -f '$TMP/engine-invoked.log'"
# A shrunk registry must not switch the refusal off either.
rm -f "$TMP/engine-invoked.log"
set +e
( cd "$PREPO" && AI_REVIEW_QUARANTINE_DIR="$TMP/pf-state" \
    AI_REVIEW_ENGINE_BIN="$FAKE_ENGINE" AI_REVIEW_RUNNER_DOORS_JSON="$SHRUNK_DOORS" \
    AI_POOL_CALLER=codex bash "$PREFLIGHT_BIN" check grok "$PREPO" ) >"$TMP/pf-shrunk.out" 2>"$TMP/pf-shrunk.err"
PF_SHRUNK_RC=$?
set -e
check "preflight_refuses_bypass_even_when_registry_unregisters_grok" \
  "test '$PF_SHRUNK_RC' -ne 0 && grep -qi 'refus' '$TMP/pf-shrunk.err' && test ! -f '$TMP/engine-invoked.log'"

# --- door adapter purity ----------------------------------------------------
echo '== adapter purity'
check "adapter_source_has_no_packet_remove" "! grep -nE 'PACKET(_BIN)?[[:space:]]+remove|ai-review-packet[[:space:]]+remove' '$GROK_DOOR' | grep -q ."
check "adapter_source_has_no_sandbox_delete" "! grep -nE 'remove-copy|remove_code_only|sandbox.*remove' '$GROK_DOOR' | grep -q ."
check "adapter_source_has_no_lifecycle_terminal" "! grep -nE 'ai-review-lifecycle|rlc_lifecycle|lifecycle (finish|fail|begin)' '$GROK_DOOR' | grep -q ."
check "adapter_keeps_provider_bits" "grep -q 'GROK_MODEL=' '$GROK_DOOR' && grep -q 'resolve_grok' '$GROK_DOOR' && grep -q 'extract_report' '$GROK_DOOR'"

# --- end-to-end review through the runner with a mock door ------------------
echo '== review contract (mock door)'
MOCK_DOOR="$TMP/mock-door.sh"
cat > "$MOCK_DOOR" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "${AI_REVIEW_RUNNER_CORE:-}" = "review-lifecycle-core/1" ] || {
  echo 'mock door: missing runner token' >&2; exit 2
}
[ -n "${DOOR_REPORT_OUT:-}" ] || { echo 'mock door: DOOR_REPORT_OUT required' >&2; exit 2; }
[ -n "${DOOR_HEAD:-}" ] || { echo 'mock door: DOOR_HEAD required' >&2; exit 2; }
[ -f "${DOOR_PACKET_DIR:-/nonexistent}/MANIFEST.md" ] || { echo 'mock door: packet missing' >&2; exit 2; }
body='The lock release path is correct, the digest is recomputed at the terminal transition, and no path writes outside managed storage. The scoreboard append is checked and an accounting failure keeps the lock for recovery rather than reporting success. Sibling issues of the same class were checked across the module and none remain. No blocking findings in this change set.'
{
  printf '# mock door review\n\n'
  printf 'Reviewed head: %s\n\n' "$DOOR_HEAD"
  printf '%s\n\n' "$body"
  printf -- '---\n\n## Verdict\nAPPROVE\n'
} > "$DOOR_REPORT_OUT"
exit 0
EOF
chmod +x "$MOCK_DOOR"

MREPO="$TMP/engine-repo"
mkdir -p "$MREPO"
git -C "$MREPO" init -q -b main
git -C "$MREPO" config user.name Test
git -C "$MREPO" config user.email t@example.com
printf 'base\n' > "$MREPO/a.txt"
git -C "$MREPO" add a.txt
git -C "$MREPO" commit -qm init
printf 'change\n' > "$MREPO/a.txt"
git -C "$MREPO" add a.txt
git -C "$MREPO" commit -qm change
printf '.ai/\n' > "$MREPO/.gitignore"
git -C "$MREPO" add .gitignore
git -C "$MREPO" commit -qm ignore
HEAD_SHA="$(git -C "$MREPO" rev-parse HEAD)"
git -C "$MREPO" status --porcelain

PREFLIGHT_STUB="$TMP/preflight-stub"
cat > "$PREFLIGHT_STUB" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$PREFLIGHT_STUB"
SCOREBOARD_STUB="$TMP/scoreboard-stub"
cat > "$SCOREBOARD_STUB" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$SCOREBOARD_STUB"

export AI_REVIEW_PREFLIGHT_BIN="$PREFLIGHT_STUB"
export AI_REVIEW_SCOREBOARD_BIN="$SCOREBOARD_STUB"
export AI_REVIEW_DOOR_GROK="$MOCK_DOOR"
export AI_REVIEW_RUNNER_DOORS_JSON="$REPO_ROOT/config/review-runner-doors.json"

set +e
( cd "$MREPO" && timeout 90 "$ENGINE" review --provider grok --name engine-e2e --repo "$MREPO" \
    --mode diff-review --caller codex ) >"$TMP/e2e.out" 2>"$TMP/e2e.err"
E2E_RC=$?
set -e
check "review_contract_succeeds_through_runner" "test '$E2E_RC' -eq 0"
REPORT_PATH="$(tail -1 "$TMP/e2e.out" 2>/dev/null || true)"
check "review_contract_leaves_report" "test -s '$REPORT_PATH' && grep -q '## Verdict' '$REPORT_PATH'"
check "report_records_runner_stamp" "grep -q 'review-lifecycle-core/1' '$REPORT_PATH'"
check "report_binds_reviewed_head" "grep -q '$HEAD_SHA' '$REPORT_PATH'"
check "review_contract_leaves_durable_packet" "test -d '$AI_REVIEW_PACKET_STORE' && find '$AI_REVIEW_PACKET_STORE' -name MANIFEST.md | grep -q ."
check "cleanup_removed_working_sandbox_after_store" "! find '${TMP}' -maxdepth 2 -type d -name '*engine-e2e*' 2>/dev/null | grep -v packet-store | grep -q ."

# Lifecycle terminal carries packet identity (Phase A contract, used by the runner).
STATE_FILE="$(grep -Rsl '"status": "completed"' "$AI_REVIEW_LIFECYCLE_DIR/runs" 2>/dev/null | head -1)"
check "lifecycle_records_packet_identity" "test -n '$STATE_FILE' && jq -e '.packet_sha256|test(\"^[0-9a-f]{64}\")' '$STATE_FILE' && jq -e '.packet_dir|type==\"string\" and length>0' '$STATE_FILE'"
check "lifecycle_records_completed_verdict" "test -n '$STATE_FILE' && jq -e '.status==\"completed\" and .verdict==\"APPROVE\"' '$STATE_FILE'"
check "lifecycle_records_runner_fields_on_report" "grep -q 'runner | \`ai-review-engine\`' '$REPORT_PATH'"

# --- report floor refusal through the runner --------------------------------
echo '== report floor refusal'
FLOOR_DOOR="$TMP/floor-door.sh"
cat > "$FLOOR_DOOR" <<'EOF'
#!/usr/bin/env bash
[ "${AI_REVIEW_RUNNER_CORE:-}" = "review-lifecycle-core/1" ] || exit 2
# Bare decision with the required head binding but no analysis body.
printf 'Reviewed head %s\n\n## Verdict\nAPPROVE\n' "$DOOR_HEAD" > "$DOOR_REPORT_OUT"
exit 0
EOF
chmod +x "$FLOOR_DOOR"
set +e
( cd "$MREPO" && timeout 90 env AI_REVIEW_DOOR_GROK="$FLOOR_DOOR" "$ENGINE" review --provider grok \
    --name engine-floor --repo "$MREPO" --mode diff-review --caller codex ) >"$TMP/floor.out" 2>"$TMP/floor.err"
FLOOR_RC=$?
set -e
check "runner_refuses_report_below_floor" "test '$FLOOR_RC' -ne 0 && grep -qi 'floor' '$TMP/floor.err'"
check "floor_refusal_is_terminal_blocked" "grep -Rqs '\"failure_class\": \"report-floor\"' '$AI_REVIEW_LIFECYCLE_DIR/runs' || grep -Rqs '\"failure_class\":\"report-floor\"' '$AI_REVIEW_LIFECYCLE_DIR/runs'"

# --- store-before-delete: store failure retains the sandbox -----------------
echo '== store-before-delete'
STORE_FAIL="$TMP/store-fail"
mkdir -p "$STORE_FAIL"
chmod 000 "$STORE_FAIL" 2>/dev/null || true
# On Windows/MSYS chmod 000 may not block; use a path that retain will reject.
STORE_FAIL_FILE="$TMP/store-is-a-file"
printf 'not a directory\n' > "$STORE_FAIL_FILE"
set +e
( cd "$MREPO" && timeout 90 env AI_REVIEW_PACKET_STORE="$STORE_FAIL_FILE" AI_REVIEW_DOOR_GROK="$MOCK_DOOR" \
    "$ENGINE" review --provider grok --name engine-storefail --repo "$MREPO" \
    --mode diff-review --caller codex ) >"$TMP/storefail.out" 2>"$TMP/storefail.err"
STOREFAIL_RC=$?
set -e
# The review may still complete (report + lifecycle), but the sandbox must be
# retained because the durable store did not succeed.
check "store_failure_message_is_visible" "grep -qi 'store' '$TMP/storefail.err'"
# Sandbox copies live under the sandbox state; find any leftover copy for this tag.
check "store_before_delete_skips_delete_when_store_fails" \
  "grep -qi 'retaining sandbox\|durable store failed\|durable packet store failed' '$TMP/storefail.err'"

# --- implement contract: worktree + recovery --------------------------------
echo '== implement contract'
IMPL_DOOR_FAIL="$TMP/impl-door-fail.sh"
cat > "$IMPL_DOOR_FAIL" <<'EOF'
#!/usr/bin/env bash
[ "${AI_REVIEW_RUNNER_CORE:-}" = "review-lifecycle-core/1" ] || exit 2
[ "${DOOR_MODE:-}" = implement ] || { echo 'expected implement mode' >&2; exit 2; }
printf 'provider exploded mid-edit\n' >&2
exit 1
EOF
chmod +x "$IMPL_DOOR_FAIL"
printf 'Please implement the change.\n' > "$TMP/impl-prompt.txt"

set +e
( cd "$MREPO" && timeout 90 env AI_REVIEW_DOOR_GROK="$IMPL_DOOR_FAIL" "$ENGINE" implement --provider grok \
    --name engine-impl-fail2 --repo "$MREPO" --prompt-file "$TMP/impl-prompt.txt" \
    --caller codex ) >"$TMP/impl-fail2.out" 2>"$TMP/impl-fail2.err"
IMPL_FAIL2_RC=$?
set -e
check "implement_failure_preserves_worktree_for_recovery" "test '$IMPL_FAIL2_RC' -ne 0 && grep -q 'worktree preserved for recovery' '$TMP/impl-fail2.err'"
PRESERVED_WT="$(sed -n 's/.*worktree preserved for recovery: //p' "$TMP/impl-fail2.err" | head -1 | tr -d '\r')"
check "preserved_worktree_exists" "test -n \"$PRESERVED_WT\" && test -d \"$PRESERVED_WT\""
check "preserved_worktree_is_detached_git_worktree" "test -d \"$PRESERVED_WT\" && git -C \"$PRESERVED_WT\" rev-parse --is-inside-work-tree >/dev/null 2>&1"

IMPL_DOOR_OK="$TMP/impl-door-ok.sh"
cat > "$IMPL_DOOR_OK" <<'EOF'
#!/usr/bin/env bash
[ "${AI_REVIEW_RUNNER_CORE:-}" = "review-lifecycle-core/1" ] || exit 2
[ "${DOOR_ALLOW_WRITE:-0}" = 1 ] || { echo 'implement requires write tools' >&2; exit 2; }
printf 'implemented\n' > "$DOOR_WORKDIR/impl.txt"
{
  printf '# implement result\n\n'
  printf 'Implemented the requested change in the worktree. Reviewed head %s.\n' "$DOOR_HEAD"
  printf 'Wrote impl.txt. Residual risk is limited to the touched module.\n'
  printf '\n## Verdict\nAPPROVE\n'
} > "$DOOR_REPORT_OUT"
exit 0
EOF
chmod +x "$IMPL_DOOR_OK"

set +e
( cd "$MREPO" && timeout 90 env AI_REVIEW_DOOR_GROK="$IMPL_DOOR_OK" "$ENGINE" implement --provider grok \
    --name engine-impl-ok --repo "$MREPO" --prompt-file "$TMP/impl-prompt.txt" \
    --caller codex --keep ) >"$TMP/impl-ok.out" 2>"$TMP/impl-ok.err"
IMPL_OK_RC=$?
set -e
IMPL_WT="$(tail -1 "$TMP/impl-ok.out" 2>/dev/null || true)"
check "implement_success_returns_worktree" "test '$IMPL_OK_RC' -eq 0 && test -d '$IMPL_WT'"
check "implement_success_kept_worktree_on_request" "test -f '$IMPL_WT/impl.txt'"
check "implement_leaves_report_and_packet" "find '$MREPO/.ai/reviews' -name '*implement*' | grep -q ."

# --- grok door with a stub binary (provider-bits path, still offline) -------
echo '== grok door with stub provider binary'
STUB_GROK="$TMP/stub-grok"
cat > "$STUB_GROK" <<EOF
#!/usr/bin/env bash
# Offline stub: answers the door's --output-format json contract.
out=''
while [ \$# -gt 0 ]; do
  case "\$1" in
    --output-format) shift; shift ;;
    --prompt-file) prompt="\$2"; shift 2 ;;
    --model) printf '%s\n' "\$2" > "$TMP/stub-grok-model"; shift 2 ;;
    *) shift ;;
  esac
done
cat <<'JSON'
{"text":"## Verdict\nAPPROVE","stopReason":"end_turn","num_turns":1,"total_cost_usd":0,"modelUsage":{"grok-4.5-build":{}}}
JSON
EOF
chmod +x "$STUB_GROK"

STUB_REPORT="$TMP/stub-report.md"
set +e
AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 \
  AI_GROK_BIN="$STUB_GROK" AI_GROK_ALLOW_NO_CREDS=1 \
  DOOR_MODE=review DOOR_WORKDIR="$MREPO" DOOR_PACKET_DIR="$MREPO" \
  DOOR_PROMPT_FILE="$TMP/impl-prompt.txt" DOOR_REPORT_OUT="$STUB_REPORT" \
  DOOR_HEAD="$HEAD_SHA" \
  bash "$GROK_DOOR" review >"$TMP/stub-door.out" 2>"$TMP/stub-door.err"
STUB_RC=$?
set -e
check "grok_door_parses_provider_envelope_to_report_shape" "test '$STUB_RC' -eq 0 && grep -q '## Verdict' '$STUB_REPORT'"
check "grok_door_uses_config_model_pin" \
  "test \"\$(cat '$TMP/stub-grok-model')\" = \"\$(jq -r '.providers.grok.model_pin' '$REPO_ROOT/config/provider-cli-versions.json')\""
check "grok_door_report_carries_stopreason_metadata" "grep -q 'end_turn' '$STUB_REPORT'"
check "grok_door_requires_runner_token_even_with_stub" \
  "! (unset AI_REVIEW_RUNNER_CORE; AI_GROK_BIN='$STUB_GROK' AI_GROK_ALLOW_NO_CREDS=1 DOOR_MODE=review DOOR_WORKDIR='$MREPO' DOOR_PACKET_DIR='$MREPO' DOOR_PROMPT_FILE='$TMP/impl-prompt.txt' DOOR_REPORT_OUT='$TMP/x.md' DOOR_HEAD='$HEAD_SHA' bash '$GROK_DOOR' review) 2>/dev/null"

# Grok cancels a headless turn on a refused shell form (PermissionCancelled);
# the door resumes the same session (remaining turn budget) instead of failing.
# Stub: first call writes a native witness of category $PC_CAT (spaced JSON,
# bound to sessionId/requestId) and returns cancelled; a -r call approves.
STUB_PC="$TMP/stub-grok-pc"
cat > "$STUB_PC" <<'STUBEOF'
#!/usr/bin/env bash
mt=""; resumed=0
while [ $# -gt 0 ]; do
  case "$1" in -r) resumed=1; shift 2 ;; --max-turns) mt="$2"; shift 2 ;; *) shift ;; esac
done
if [ "$resumed" = 1 ]; then
  echo "resumed:$mt" >> "$PC_CALLS"
  printf '%s\n' '{"text":"## Verdict\nAPPROVE","stopReason":"end_turn","num_turns":1,"sessionId":"sid-pc1","requestId":"req-2","modelUsage":{"grok-4.6-build":{}}}'
  exit 0
fi
echo "first:$mt" >> "$PC_CALLS"
mkdir -p "$GROK_HOME/sessions/x/sid-pc1"
printf '%s\n' "{\"params\": {\"sessionId\": \"sid-pc1\", \"update\": {\"sessionUpdate\": \"turn_completed\", \"prompt_id\": \"req-1\", \"stop_reason\": \"cancelled\"}, \"_meta\": {\"cancellationCategory\": \"$PC_CAT\"}}}" > "$GROK_HOME/sessions/x/sid-pc1/updates.jsonl"
printf '%s\n' '{"text":"","stopReason":"cancelled","num_turns":4,"sessionId":"sid-pc1","requestId":"req-1"}'
STUBEOF
chmod +x "$STUB_PC"
run_pc_door() { # run_pc_door CATEGORY TAG -> sets PC_RC
  rm -rf "$TMP/pc-home-$2"; : > "$TMP/pc-calls-$2"
  set +e
  AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 GROK_HOME="$TMP/pc-home-$2" \
    PC_CAT="$1" PC_CALLS="$TMP/pc-calls-$2" DOOR_MAX_TURNS=10 \
    AI_GROK_BIN="$STUB_PC" AI_GROK_ALLOW_NO_CREDS=1 \
    DOOR_MODE=review DOOR_WORKDIR="$MREPO" DOOR_PACKET_DIR="$MREPO" \
    DOOR_PROMPT_FILE="$TMP/impl-prompt.txt" DOOR_REPORT_OUT="$TMP/pc-report-$2.md" \
    DOOR_HEAD="$HEAD_SHA" \
    bash "$GROK_DOOR" review >/dev/null 2>"$TMP/pc-door-$2.err"
  PC_RC=$?
  set -e
}
run_pc_door PermissionCancelled perm
check "grok_door_resumes_permission_cancelled_turn_with_remaining_budget" \
  "test '$PC_RC' -eq 0 && grep -q APPROVE '$TMP/pc-report-perm.md' && test \"\$(tr '\n' ' ' < '$TMP/pc-calls-perm')\" = 'first:10 resumed:6 '"
run_pc_door max_turns_reached turns
check "grok_door_does_not_resume_turn_limit_cancel" \
  "test '$PC_RC' -ne 0 && test \"\$(tr '\n' ' ' < '$TMP/pc-calls-turns')\" = 'first:10 '"

# --- deepseek (OpenCode) door on the same runner ----------------------------
# Program done needs one native door (grok) AND one OpenCode door on the same
# runner. These checks prove the OpenCode shape keeps the same contracts and
# the same structural forcing function.
echo '== deepseek door (OpenCode) on the shared runner'
DS_DOOR="$REPO_ROOT/tools/lib/review-doors/deepseek.sh"
DOORS_JSON_REAL="$REPO_ROOT/config/review-runner-doors.json"

check "doors_registry_registers_deepseek_opencode_door" \
  "jq -e '.deepseek.door==\"tools/lib/review-doors/deepseek.sh\" and .deepseek.harness==\"opencode\"' '$DOORS_JSON_REAL'"
check "doors_registry_gives_deepseek_both_contracts" \
  "jq -e '.deepseek.contract==[\"review\",\"implement\"]' '$DOORS_JSON_REAL'"
check "doors_registry_keeps_grok_beside_deepseek" \
  "jq -e '.grok.door==\"tools/lib/review-doors/grok.sh\"' '$DOORS_JSON_REAL'"

check "deepseek_adapter_source_has_no_packet_remove" "! grep -nE 'PACKET(_BIN)?[[:space:]]+remove|ai-review-packet[[:space:]]+remove' '$DS_DOOR' | grep -q ."
check "deepseek_adapter_source_has_no_sandbox_delete" "! grep -nE 'remove-copy|remove_code_only|sandbox.*remove' '$DS_DOOR' | grep -q ."
check "deepseek_adapter_source_has_no_lifecycle_terminal" "! grep -nE 'ai-review-lifecycle|rlc_lifecycle|lifecycle (finish|fail|begin)' '$DS_DOOR' | grep -q ."
check "deepseek_adapter_keeps_provider_bits" \
  "grep -q 'DS_MODEL=' '$DS_DOOR' && grep -q 'resolve_opencode' '$DS_DOOR' && grep -q 'extract_report' '$DS_DOOR' && grep -q 'install_profile' '$DS_DOOR'"
check "deepseek_adapter_selects_opencode_profile" \
  "grep -q 'config/opencode-deepseek' '$DS_DOOR' && grep -q 'deepseek-review' '$DS_DOOR' && grep -q 'deepseek-implement' '$DS_DOOR'"
check "deepseek_review_agent_profile_exists" \
  "test -f '$REPO_ROOT/config/opencode-deepseek/agent/deepseek-review.md'"

# Structural forcing function: the OpenCode door refuses without the runner token.
set +e
( unset AI_REVIEW_RUNNER_CORE; bash "$DS_DOOR" review ) >"$TMP/ds-bypass.out" 2>"$TMP/ds-bypass.err"
DS_BYPASS_RC=$?
set -e
check "deepseek_door_refuses_without_runner_token" \
  "test '$DS_BYPASS_RC' -ne 0 && grep -q 'bypasses the shared runner' '$TMP/ds-bypass.err'"
check "deepseek_door_refusal_is_exit_2" "test '$DS_BYPASS_RC' -eq 2"

# Structural forcing function: pool refuses a bypassed deepseek review.
set +e
( cd "$PREPO" && AI_POOL_TEST_HOOKS=1 AI_POOL_RUNNER_DEEPSEEK="$NOT_ENGINE" \
    AI_POOL_CALLER=codex bash "$POOL" deepseek diff-review ) >"$TMP/pool-ds-bypass.out" 2>"$TMP/pool-ds-bypass.err"
POOL_DS_BYPASS_RC=$?
set -e
check "pool_refuses_bypass_for_deepseek_door" \
  "test '$POOL_DS_BYPASS_RC' -ne 0 && grep -q 'bypasses the shared review runner' '$TMP/pool-ds-bypass.err'"
check "pool_deepseek_bypass_refusal_names_the_engine" "grep -q 'ai-review-engine' '$TMP/pool-ds-bypass.err'"

# The shipped registry is authoritative for deepseek too: a foreign JSON that
# unregisters it must not drop the structural gate.
rm -f "$TMP/engine-invoked.log"
set +e
( cd "$PREPO" && AI_POOL_TEST_HOOKS=1 AI_REVIEW_ENGINE_BIN="$FAKE_ENGINE" \
    AI_REVIEW_RUNNER_DOORS_JSON="$SHRUNK_DOORS" \
    AI_POOL_CALLER=codex bash "$POOL" deepseek diff-review ) >"$TMP/pool-ds-shrunk.out" 2>"$TMP/pool-ds-shrunk.err"
POOL_DS_SHRUNK_RC=$?
set -e
check "pool_keeps_deepseek_door_when_registry_unregisters_deepseek" \
  "grep -q 'invoked: review --provider deepseek' '$TMP/engine-invoked.log'"
check "pool_deepseek_shrunk_registry_never_reaches_legacy_runner" \
  "test '$POOL_DS_SHRUNK_RC' -eq 99"

# Structural forcing function: preflight refuses the same bypass for deepseek.
rm -f "$TMP/engine-invoked.log"
set +e
( cd "$PREPO" && AI_REVIEW_QUARANTINE_DIR="$TMP/pf-state" \
    AI_REVIEW_ENGINE_BIN="$FAKE_ENGINE" \
    AI_POOL_CALLER=codex bash "$PREFLIGHT_BIN" check deepseek "$PREPO" ) >"$TMP/pf-ds-bypass.out" 2>"$TMP/pf-ds-bypass.err"
PF_DS_BYPASS_RC=$?
set -e
check "preflight_refuses_bypass_for_deepseek_door" \
  "test '$PF_DS_BYPASS_RC' -ne 0 && grep -qi 'refus' '$TMP/pf-ds-bypass.err' && test ! -f '$TMP/engine-invoked.log'"
rm -f "$TMP/engine-invoked.log"
set +e
( cd "$PREPO" && AI_REVIEW_QUARANTINE_DIR="$TMP/pf-state" \
    AI_REVIEW_ENGINE_BIN="$FAKE_ENGINE" AI_REVIEW_RUNNER_DOORS_JSON="$SHRUNK_DOORS" \
    AI_POOL_CALLER=codex bash "$PREFLIGHT_BIN" check deepseek "$PREPO" ) >"$TMP/pf-ds-shrunk.out" 2>"$TMP/pf-ds-shrunk.err"
PF_DS_SHRUNK_RC=$?
set -e
check "preflight_refuses_deepseek_bypass_even_when_registry_unregisters_deepseek" \
  "test '$PF_DS_SHRUNK_RC' -ne 0 && grep -qi 'refus' '$TMP/pf-ds-shrunk.err' && test ! -f '$TMP/engine-invoked.log'"

# The front door dispatches an ordinary DeepSeek review through the pool
# (and so the shared runner), the same route as the other rotation reviewers.
# The --code-only attachment-only route stays a separate path.
echo '== front door routes deepseek through the pool'
FRONT="$REPO_ROOT/bin/ai-review"
STUB_POOL="$TMP/stub-pool"
cat > "$STUB_POOL" <<EOF
#!/usr/bin/env bash
printf 'pool-invoked: %s\n' "\$*" >> "$TMP/stub-pool.log"
exit 0
EOF
chmod +x "$STUB_POOL"
rm -f "$TMP/stub-pool.log"
set +e
( cd "$PREPO" && AI_POOL_TEST_HOOKS=1 AI_REVIEW_POOL_BIN="$STUB_POOL" \
    AI_POOL_CALLER=codex bash "$FRONT" deepseek diff-review ) >"$TMP/front-ds.out" 2>"$TMP/front-ds.err"
FRONT_DS_RC=$?
set -e
check "front_door_routes_deepseek_to_pool" \
  "test '$FRONT_DS_RC' -eq 0 && grep -q 'pool-invoked: deepseek diff-review' '$TMP/stub-pool.log'"
check "front_door_deepseek_no_longer_forces_code_only" \
  "! grep -q 'explicit code-only route' '$TMP/front-ds.err'"
printf '{\n  "version": 1,\n  "providers": { "deepseek": { "registry_state": "absent", "reason": "test" } }\n}\n' > "$TMP/ds-absent-registry.json"
rm -f "$TMP/stub-pool.log"
set +e
( cd "$PREPO" && AI_REVIEW_REGISTRY_FILE="$TMP/ds-absent-registry.json" \
    AI_POOL_TEST_HOOKS=1 AI_REVIEW_POOL_BIN="$STUB_POOL" \
    AI_POOL_CALLER=codex bash "$FRONT" deepseek diff-review ) >"$TMP/front-ds-absent.out" 2>"$TMP/front-ds-absent.err"
FRONT_DS_ABSENT_RC=$?
set -e
check "front_door_deepseek_respects_reviewer_registry" \
  "test '$FRONT_DS_ABSENT_RC' -ne 0 && grep -q 'not a registered reviewer' '$TMP/front-ds-absent.err' && test ! -f '$TMP/stub-pool.log'"

# End-to-end review through the runner with the OpenCode door and a stub
# OpenCode binary: the same runner contracts (packet + report + lifecycle) as
# the native grok door, offline.
echo '== deepseek review contract through the runner (stub OpenCode)'
STUB_OC="$TMP/stub-opencode"
cat > "$STUB_OC" <<EOF
#!/usr/bin/env bash
# Offline stub OpenCode: accepts the door's run contract and emits JSONL.
out=''
dir=''
while [ \$# -gt 0 ]; do
  case "\$1" in
    --dir) dir="\$2"; shift 2 ;;
    --agent|--format|--model) shift 2 ;;
    run|--auto) shift ;;
    *) shift ;;
  esac
done
cat > /dev/null
cat <<'JSON'
{"type":"sessionID","sessionID":"stub-session-1"}
{"type":"text","part":{"text":"I read the evidence packet and every changed hunk against the stated intent. The lock release path is correct, the digest is recomputed at the terminal transition, and no path writes outside managed storage. The scoreboard append is checked and an accounting failure keeps the lock for recovery rather than reporting success. Sibling issues of the same class were checked across the module and none remain. No blocking findings in this change set."}}
{"type":"tool_use","part":{"state":{"status":"ok"}}}
{"type":"text","part":{"text":"## Verdict\nAPPROVE"}}
JSON
EOF
chmod +x "$STUB_OC"

DS_REPORT="$TMP/ds-stub-report.md"
set +e
AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 \
  AI_DEEPSEEK_OPENCODE="$STUB_OC" AI_DEEPSEEK_ALLOW_NO_CREDS=1 \
  DOOR_MODE=review DOOR_WORKDIR="$MREPO" DOOR_PACKET_DIR="$MREPO" \
  DOOR_PROMPT_FILE="$TMP/impl-prompt.txt" DOOR_REPORT_OUT="$DS_REPORT" \
  DOOR_HEAD="$HEAD_SHA" \
  bash "$DS_DOOR" review >"$TMP/ds-stub-door.out" 2>"$TMP/ds-stub-door.err"
DS_STUB_RC=$?
set -e
check "deepseek_door_parses_opencode_envelope_to_report_shape" \
  "test '$DS_STUB_RC' -eq 0 && grep -q '## Verdict' '$DS_REPORT'"
check "deepseek_door_report_carries_opencode_metadata" \
  "grep -q 'opencode' '$DS_REPORT' && grep -q 'deepseek-api/deepseek-flash' '$DS_REPORT'"
check "deepseek_door_report_binds_reviewed_head" "grep -q '$HEAD_SHA' '$DS_REPORT'"
check "deepseek_door_requires_runner_token_even_with_stub" \
  "! (unset AI_REVIEW_RUNNER_CORE; AI_DEEPSEEK_OPENCODE='$STUB_OC' AI_DEEPSEEK_ALLOW_NO_CREDS=1 DOOR_MODE=review DOOR_WORKDIR='$MREPO' DOOR_PACKET_DIR='$MREPO' DOOR_PROMPT_FILE='$TMP/impl-prompt.txt' DOOR_REPORT_OUT='$TMP/ds-x.md' DOOR_HEAD='$HEAD_SHA' bash '$DS_DOOR' review) 2>/dev/null"

# Full review contract for deepseek through the runner: packet + report.
export AI_REVIEW_DOOR_DEEPSEEK="$DS_DOOR"
set +e
( cd "$MREPO" && timeout 90 env AI_DEEPSEEK_OPENCODE="$STUB_OC" AI_DEEPSEEK_ALLOW_NO_CREDS=1 \
    AI_REVIEW_DOOR_DEEPSEEK="$DS_DOOR" \
    "$ENGINE" review --provider deepseek --name engine-ds-e2e --repo "$MREPO" \
    --mode diff-review --caller codex ) >"$TMP/ds-e2e.out" 2>"$TMP/ds-e2e.err"
DS_E2E_RC=$?
set -e
check "deepseek_review_contract_succeeds_through_runner" "test '$DS_E2E_RC' -eq 0"
DS_REPORT_PATH="$(tail -1 "$TMP/ds-e2e.out" 2>/dev/null || true)"
check "deepseek_review_contract_leaves_packet_and_report" \
  "test -s '$DS_REPORT_PATH' && grep -q '## Verdict' '$DS_REPORT_PATH' && find '$AI_REVIEW_PACKET_STORE' -name MANIFEST.md | grep -q ."
check "deepseek_report_records_runner_stamp" "grep -q 'review-lifecycle-core/1' '$DS_REPORT_PATH'"
check "deepseek_report_binds_reviewed_head" "grep -q '$HEAD_SHA' '$DS_REPORT_PATH'"
DS_STATE_FILE="$(grep -Rsl '\"provider\": \"deepseek\"' "$AI_REVIEW_LIFECYCLE_DIR/runs" 2>/dev/null | head -1)"
check "deepseek_lifecycle_records_completed_verdict_with_packet" \
  "test -n '$DS_STATE_FILE' && jq -e '.status==\"completed\" and .verdict==\"APPROVE\"' '$DS_STATE_FILE' && jq -e '.packet_sha256|test(\"^[0-9a-f]{64}\")' '$DS_STATE_FILE'"
check "deepseek_review_cleanup_removed_working_sandbox_after_store" \
  "! find '$AI_REVIEW_SANDBOX_DIR' -maxdepth 1 -type d -name 'rlc-deepseek-*' 2>/dev/null | grep -q ."

# Both contracts stay in the runner: deepseek implement runs through it too.
export AI_REVIEW_DOOR_DEEPSEEK="$IMPL_DOOR_OK"
set +e
( cd "$MREPO" && timeout 90 env AI_REVIEW_DOOR_DEEPSEEK="$IMPL_DOOR_OK" \
    "$ENGINE" implement --provider deepseek --name engine-ds-impl --repo "$MREPO" \
    --prompt-file "$TMP/impl-prompt.txt" --caller codex --keep ) >"$TMP/ds-impl.out" 2>"$TMP/ds-impl.err"
DS_IMPL_RC=$?
set -e
DS_IMPL_WT="$(tail -1 "$TMP/ds-impl.out" 2>/dev/null || true)"
check "deepseek_implement_contract_runs_through_runner" \
  "test '$DS_IMPL_RC' -eq 0 && test -d '$DS_IMPL_WT' && test -f '$DS_IMPL_WT/impl.txt'"

# --- engine doctor ----------------------------------------------------------
echo '== engine doctor'
check "engine_doctor_reports_core_stamp" "'$ENGINE' doctor | grep -q 'review-lifecycle-core/1'"

echo
printf '== test-ai-review-engine: %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
