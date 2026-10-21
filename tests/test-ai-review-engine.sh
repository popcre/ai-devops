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
DEEPSEEK_DOOR="$REPO_ROOT/tools/lib/review-doors/deepseek.sh"
MUSE_DOOR="$REPO_ROOT/tools/lib/review-doors/muse.sh"
QWEN_DOOR="$REPO_ROOT/tools/lib/review-doors/qwen.sh"
GEMINI_DOOR="$REPO_ROOT/tools/lib/review-doors/gemini.sh"
STEPFUN_DOOR="$REPO_ROOT/tools/lib/review-doors/stepfun.sh"
DOORS_JSON="$REPO_ROOT/config/review-runner-doors.json"
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
export AI_REVIEW_SCOREBOARD_DIR="$TMP/scoreboard-state"
export AI_REVIEW_SCOREBOARD_FILE="$TMP/scoreboard-state/reviews.jsonl"
export AI_REVIEW_PACKET_STORE="$TMP/packet-store"
export AI_REVIEW_IMPLEMENT_ROOT="$TMP/implement"

echo '== review-lifecycle-core library'
. "$REPO_ROOT/tools/lib/deepseek-opencode.sh"
printf 'Reviewed exact source\n## Verdict\nAPPROVE\nCompaction summary preserves all findings.\n' > "$TMP/deepseek-summary.txt"
deepseek_terminal_report < "$TMP/deepseek-summary.txt" > "$TMP/deepseek-normalized.txt"
check "deepseek_summary_keeps_reasoning_and_terminal_install_shape" "grep -qx 'Compaction summary preserves all findings.' '$TMP/deepseek-normalized.txt' && [ \"\$(tail -2 '$TMP/deepseek-normalized.txt')\" = \"\$(printf '## Verdict\\nAPPROVE')\" ]"
printf 'Early findings\n## Verdict\nAPPROVE\nLater blocking finding\n## Verdict\nREJECT\nSummary after final decision\n' > "$TMP/deepseek-multiple.txt"
deepseek_terminal_report < "$TMP/deepseek-multiple.txt" > "$TMP/deepseek-last.txt"
check "deepseek_normalization_uses_authentic_last_decision" "[ \"\$(tail -2 '$TMP/deepseek-last.txt')\" = \"\$(printf '## Verdict\\nREJECT')\" ] && grep -qx 'Later blocking finding' '$TMP/deepseek-last.txt' && grep -qx 'Summary after final decision' '$TMP/deepseek-last.txt'"
printf '## Verdict\nAPPROVE\n## Verdict\nPROVISIONAL\n' > "$TMP/deepseek-invalid-final.txt"
check "deepseek_invalid_final_never_resurrects_earlier_approval" "! deepseek_terminal_report < '$TMP/deepseek-invalid-final.txt' > '$TMP/deepseek-invalid-normalized.txt' && test ! -s '$TMP/deepseek-invalid-normalized.txt'"
printf 'Findings without a verdict\n' > "$TMP/deepseek-no-verdict.txt"
check "deepseek_normalization_never_invents_absent_approval" "! deepseek_terminal_report < '$TMP/deepseek-no-verdict.txt' > '$TMP/deepseek-none-normalized.txt' && test ! -s '$TMP/deepseek-none-normalized.txt'"
printf '## Verdict\nAPPROVE\n## Verdict\n' > "$TMP/deepseek-empty-final.txt"
check "deepseek_empty_final_never_resurrects_earlier_approval" "! deepseek_terminal_report < '$TMP/deepseek-empty-final.txt' > '$TMP/deepseek-empty-normalized.txt' && test ! -s '$TMP/deepseek-empty-normalized.txt'"
check "core_declares_one_stamp" "grep -q 'RLC_STAMP=\"review-lifecycle-core/1\"' '$CORE'"
check "core_owns_report_floor" "grep -q 'MIN_REPORT_CHARS=' '$CORE' && grep -q 'rlc_report_substance' '$CORE'"
check "core_owns_store_before_delete" "grep -q 'rlc_packet_store' '$CORE' && grep -q 'rlc_cleanup_after_store' '$CORE'"
check "core_unifies_tag_and_dir_budgets" "grep -q 'RLC_TAG_MAX=48' '$CORE' && grep -q 'RLC_DIR_MAX=64' '$CORE'"
check "core_owns_both_contracts" "grep -q 'rlc_run_review' '$CORE' && grep -q 'rlc_run_implement' '$CORE'"

# --- durable report publish (plan step 4) -----------------------------------
# rlc_write_report must leave a complete report at OUT after the writing
# process exits: regular file, verdict + head bound, temp cleaned up. This is
# the Windows-path-safe publish helper every completed review uses.
. "$CORE"
DURABLE_HEAD=0123456789abcdef0123456789abcdef01234567
DURABLE_BODY="$TMP/durable-body.md"
printf 'Substantive analysis of the reviewed change.\n## Verdict\nAPPROVE\nReviewed commit `%s`\n' "$DURABLE_HEAD" > "$DURABLE_BODY"
DURABLE_OUT="$TMP/durable-out/report.md"
mkdir -p "$(dirname "$DURABLE_OUT")"
rlc_write_report "$DURABLE_OUT" mock diff-review "$TMP/srcrepo" "$DURABLE_HEAD" deadbeefcafe run-durable caller-x 1 "$DURABLE_BODY" "" >/dev/null
check "durable_report_publish_survives_process_exit" \
  "[ -f '$DURABLE_OUT' ] && [ ! -L '$DURABLE_OUT' ] && [ -s '$DURABLE_OUT' ] \
   && grep -q '## Verdict' '$DURABLE_OUT' && grep -q 'APPROVE' '$DURABLE_OUT' \
   && grep -q '$DURABLE_HEAD' '$DURABLE_OUT' \
   && [ -z \"\$(find '$TMP/durable-out' -name '.rlc-report.*' 2>/dev/null)\" ]"
check "durable_report_is_readable_after_writer_exit" \
  "grep -q 'review-lifecycle-core/1' '$DURABLE_OUT' && grep -q 'reviewed commit' '$DURABLE_OUT'"

# --- tag budget -------------------------------------------------------------
# shellcheck disable=SC1090
. "$CORE"
cat > "$TMP/mock-packet-builder" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  build)
    printf '%s' "${AI_REVIEW_SOURCE_RECEIPT_FILE-unset}" > "$PACKET_BUILD_ENV"
    printf '%s\n' "$PACKET_BUILD_RESULT" ;;
  verify)
    printf '%s' "${AI_REVIEW_SOURCE_RECEIPT_FILE-unset}" > "$PACKET_VERIFY_ENV"
    printf '%s\n' "$*" > "$PACKET_VERIFY_ARGS" ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$TMP/mock-packet-builder"
RLC_PACKET="$TMP/mock-packet-builder"
PACKET_BUILD_ENV="$TMP/packet-build-env"
PACKET_VERIFY_ENV="$TMP/packet-verify-env"
PACKET_VERIFY_ARGS="$TMP/packet-verify-args"
PACKET_BUILD_RESULT="$TMP/mock-packet"
PACKET_IDENTITY="$TMP/packet-identity.json"
printf '{}\n' > "$PACKET_IDENTITY"
export RLC_PACKET PACKET_BUILD_ENV PACKET_VERIFY_ENV PACKET_VERIFY_ARGS PACKET_BUILD_RESULT
export AI_REVIEW_SOURCE_RECEIPT_FILE="$TMP/provider-final-receipt.json"
PREPARATORY_PACKET="$(rlc_packet_build "$TMP" receipt-isolation "$PACKET_IDENTITY")"
check "preparatory_packet_verification_does_not_claim_provider_receipt" "[ '$PREPARATORY_PACKET' = '$TMP/mock-packet' ] && [ \"\$(cat '$PACKET_BUILD_ENV')\" = '$TMP/provider-final-receipt.json' ] && [ \"\$(cat '$PACKET_VERIFY_ENV')\" = unset ] && grep -q -- '--identity $PACKET_IDENTITY' '$PACKET_VERIFY_ARGS' && [ \"\$AI_REVIEW_SOURCE_RECEIPT_FILE\" = '$TMP/provider-final-receipt.json' ]"
unset AI_REVIEW_SOURCE_RECEIPT_FILE RLC_PACKET PACKET_BUILD_ENV PACKET_VERIFY_ENV PACKET_VERIFY_ARGS PACKET_BUILD_RESULT
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
VERDICT_BLANK="$TMP/verdict-blank.md"
VERDICT_INTERVENING="$TMP/verdict-intervening.md"
VERDICT_EOF="$TMP/verdict-eof.md"
printf '## Verdict\n\nREJECT\n' > "$VERDICT_BLANK"
printf '## Verdict\ncommentary\nREJECT\n' > "$VERDICT_INTERVENING"
printf '## Verdict\n\n' > "$VERDICT_EOF"
check "core_parser_accepts_exact_reject_after_blank_lines" "[ \"\$(rlc_parse_verdict '$VERDICT_BLANK')\" = REJECT ]"
check "core_parser_refuses_intervening_text_before_token" "! rlc_parse_verdict '$VERDICT_INTERVENING' >/dev/null 2>&1"
check "core_parser_refuses_empty_verdict_until_eof" "! rlc_parse_verdict '$VERDICT_EOF' >/dev/null 2>&1"

# --- structural forcing function: door refuses without the runner token -----
echo '== structural forcing function (doors)'
set +e
( unset AI_REVIEW_RUNNER_CORE; bash "$GROK_DOOR" review ) >"$TMP/door-bypass.out" 2>"$TMP/door-bypass.err"
DOOR_BYPASS_RC=$?
set -e
check "door_refuses_without_runner_token" "test '$DOOR_BYPASS_RC' -ne 0 && grep -q 'bypasses the shared runner' '$TMP/door-bypass.err'"
check "door_refusal_is_exit_2" "test '$DOOR_BYPASS_RC' -eq 2"

# Every rotation reviewer has a registered door: the four migrated in
# mimo/phasee-four-doors plus the two already proven. A missing door or a
# missing registry row is the Phase D completeness gap that nulls packet
# identity for that provider.
echo '== doors registry completeness (six rotation reviewers)'
check "registry_lists_grok" "jq -e 'has(\"grok\")' '$DOORS_JSON' >/dev/null"
check "registry_lists_deepseek" "jq -e 'has(\"deepseek\")' '$DOORS_JSON' >/dev/null"
check "registry_lists_muse" "jq -e 'has(\"muse\")' '$DOORS_JSON' >/dev/null"
check "registry_lists_qwen" "jq -e 'has(\"qwen\")' '$DOORS_JSON' >/dev/null"
check "registry_lists_gemini" "jq -e 'has(\"gemini\")' '$DOORS_JSON' >/dev/null"
check "registry_lists_stepfun" "jq -e 'has(\"stepfun\")' '$DOORS_JSON' >/dev/null"
check "registry_door_files_exist" "for p in grok deepseek muse qwen gemini stepfun; do test -f \"\$REPO_ROOT/\$(jq -r --arg p \"\$p\" '.[\$p].door' '$DOORS_JSON')\" || exit 1; done"

for _door_pair in "muse:$MUSE_DOOR" "qwen:$QWEN_DOOR" "gemini:$GEMINI_DOOR" "stepfun:$STEPFUN_DOOR"; do
  _dname="${_door_pair%%:*}"
  _dpath="${_door_pair#*:}"
  set +e
  ( unset AI_REVIEW_RUNNER_CORE; bash "$_dpath" review ) >"$TMP/door-$_dname-bypass.out" 2>"$TMP/door-$_dname-bypass.err"
  _drc=$?
  set -e
  check "door_${_dname}_refuses_without_runner_token" "test '$_drc' -eq 2 && grep -q 'bypasses the shared runner' '$TMP/door-$_dname-bypass.err'"
done
unset _door_pair _dname _dpath _drc

# Git for Windows leaves the managed qwen.cmd launcher without an execute bit;
# the door must still find it (edge-dev, #1409), as bin/ai-qwen already does.
echo '== Qwen door finds a non-executable Windows .cmd launcher'
mkdir -p "$TMP/qwen-lad/qwen-code/bin"
printf '@echo off\r\n' >"$TMP/qwen-lad/qwen-code/bin/qwen.cmd"
chmod -x "$TMP/qwen-lad/qwen-code/bin/qwen.cmd"
sed -n '/^qwen_door_usable_bin() {/,/^}/p;/^resolve_qwen() {/,/^}/p' "$QWEN_DOOR" >"$TMP/qwen-resolve.sh"
_qout="$(env -i PATH=/usr/bin:/bin HOME="$TMP/qwen-nohome" LOCALAPPDATA="$TMP/qwen-lad" bash -c ". '$TMP/qwen-resolve.sh'; resolve_qwen" 2>/dev/null || true)"
check "qwen_door_resolves_nonexec_cmd_launcher" "test '$_qout' = '$TMP/qwen-lad/qwen-code/bin/qwen.cmd'"
_qout="$(env -i PATH=/usr/bin:/bin HOME="$TMP/qwen-nohome" LOCALAPPDATA="$TMP/qwen-none" bash -c ". '$TMP/qwen-resolve.sh'; resolve_qwen" 2>&1 || true)"
check "qwen_door_still_reports_missing_binary" "printf '%s' '$_qout' | grep -q 'qwen binary not found'"
unset _qout

# The Linux StepFun door must launch a dynamically linked StepCode binary
# inside its real bubblewrap command. A shell stub misses a missing ELF loader.
echo '== StepFun door Linux loader'
if [ "$(uname -s)" = Linux ] && command -v bwrap >/dev/null 2>&1 && command -v cc >/dev/null 2>&1 && command -v readelf >/dev/null 2>&1 &&
   bwrap --ro-bind / / -- /usr/bin/true >/dev/null 2>&1; then
  mkdir -p "$TMP/stepfun-door/bin" "$TMP/stepfun-door/work" "$TMP/stepfun-door/packet"
  cat > "$TMP/stepfun-door/step.c" <<'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
static int check_isolation(void) {
    char catalog[4096];
    snprintf(catalog, sizeof(catalog), "%s/.stepcode/models.json", getenv("HOME"));
    FILE *source = fopen(catalog, "r");
    if (!source) { fputs("StepCode catalog missing from isolated HOME\n", stderr); return 1; }
    FILE *copy = fopen("captured-models.json", "w");
    if (!copy) return 1;
    int byte;
    while ((byte = fgetc(source)) != EOF) fputc(byte, copy);
    fclose(copy);
    fclose(source);
    FILE *write_test = fopen(catalog, "a");
    if (write_test) { fclose(write_test); fputs("StepCode catalog is writable\n", stderr); return 1; }
    FILE *resolver = fopen("/etc/resolv.conf", "r");
    if (!resolver) { fputs("Resolver target missing inside sandbox\n", stderr); return 1; }
    fclose(resolver);
  return 0;
}

int main(int argc, char **argv) {
  if (argc > 1 && strcmp(argv[1], "--help") == 0) { puts("step - AI coding assistant"); return 0; }
  if (argc > 1 && strcmp(argv[1], "--version") == 0) { puts("step-fixture-version"); return 0; }
  if (argc > 1 && strcmp(argv[1], "-p") == 0) {
    const char *approval = NULL, *fallback = NULL;
    for (int i = 2; i + 1 < argc; i++) {
      if (strcmp(argv[i], "--approval-mode") == 0) approval = argv[i + 1];
      if (strcmp(argv[i], "--non-interactive-approval") == 0) fallback = argv[i + 1];
    }
    if (!approval || strcmp(approval, "auto") != 0) {
      fprintf(stderr, "Error: Invalid approval mode. Valid values: confirm, auto, strict\n");
      return 1;
    }
    if (!fallback || strcmp(fallback, "allow") != 0) return 1;
    if (check_isolation() != 0) return 1;
    char *args[] = {argv[0], "--version", NULL};
    execv(argv[0], args);
  }
  if (argc > 2 && strcmp(argv[1], "--mode") == 0 && strcmp(argv[2], "rpc") == 0) {
    /* The door's RPC turn: prompt, settle, then the last assistant text. */
    static char line[1 << 20];
    if (check_isolation() != 0) return 1;
    if (!fgets(line, sizeof line, stdin)) return 3;
    puts("{\"id\":\"door-prompt\",\"type\":\"response\",\"success\":true}");
    puts("{\"type\":\"agent_settled\"}"); fflush(stdout);
    if (!fgets(line, sizeof line, stdin)) return 3;
    puts("{\"id\":\"door-text\",\"type\":\"response\",\"data\":{\"text\":\"step-fixture-version\"}}");
    fflush(stdout);
    return 0;
  }
  return 2;
}
EOF
  if cc -o "$TMP/stepfun-door/bin/step" "$TMP/stepfun-door/step.c"; then
    if "$TMP/stepfun-door/bin/step" -p --approval-mode acceptEdits --non-interactive-approval allow \
      > "$TMP/stepfun-door/invalid-mode.out" 2>&1; then
      bad 'StepFun fixture rejects unsupported approval mode'
    else
      check 'StepFun fixture rejects unsupported approval mode' \
        "grep -q 'Invalid approval mode' '$TMP/stepfun-door/invalid-mode.out'"
    fi
    STEP_DOOR_INTERPRETER="$(readelf -l "$TMP/stepfun-door/bin/step" | sed -n 's/.*Requesting program interpreter: \([^]]*\)].*/\1/p')"
    case "$STEP_DOOR_INTERPRETER" in
      /lib/*|/lib64/*)
        if bwrap --ro-bind /usr /usr --ro-bind /etc /etc --dev /dev --proc /proc \
          --tmpfs /tmp --tmpfs /run --ro-bind "$TMP/stepfun-door/bin" "$TMP/stepfun-door/bin" -- \
          "$TMP/stepfun-door/bin/step" --version > "$TMP/stepfun-door/no-loader.out" 2>&1; then
          bad 'StepFun door fixture requires the missing ELF interpreter'
        else
          check 'StepFun door fixture reproduces missing ELF interpreter' \
            "grep -q 'No such file or directory' '$TMP/stepfun-door/no-loader.out'"
        fi
        printf 'Review this fixture.\n' > "$TMP/stepfun-door/prompt"
        if AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 AI_STEPFUN_STEP_BIN="$TMP/stepfun-door/bin/step" \
          AI_STEPFUN_ALLOW_NO_CREDS=1 DOOR_TIMEOUT=10 DOOR_WORKDIR="$TMP/stepfun-door/work" \
          DOOR_PACKET_DIR="$TMP/stepfun-door/packet" DOOR_PROMPT_FILE="$TMP/stepfun-door/prompt" \
          DOOR_REPORT_OUT="$TMP/stepfun-door/report" DOOR_HEAD="$(git -C "$REPO_ROOT" rev-parse HEAD)" \
          bash "$STEPFUN_DOOR" implement > "$TMP/stepfun-door/door.out" 2>&1; then
          check 'StepFun door uses supported writable approval and runs step --version' \
            "grep -q 'step-fixture-version' '$TMP/stepfun-door/report'"
          check 'StepFun door binds only the pinned nonsecret model read-only' \
            "jq -e '.providers | keys == [\"step\"] and .step.api == \"openai-completions\" and .step.apiKey == \"\$STEP_API_KEY\" and (.step.models | map(.id) == [\"step-5-preview\"])' '$TMP/stepfun-door/work/captured-models.json' >/dev/null"
          # The fixture captured the actual door-generated catalog. Where the
          # pinned binary is installed, prove its offline model discovery with
          # that same catalog and with the catalog absent in an empty HOME.
          STEP_REAL_BIN="$(command -v step 2>/dev/null || true)"
          [ -x "$STEP_REAL_BIN" ] || STEP_REAL_BIN="${HOME:-}/.stepcode/bin/step"
          if [ -x "$STEP_REAL_BIN" ] && NO_COLOR=1 "$STEP_REAL_BIN" --help 2>/dev/null | head -n1 |
            sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g' | grep -q '^step - AI coding assistant'; then
            mkdir -p "$TMP/stepfun-door/real-home"
            STEP_REAL_LOADER=()
            for _step_top in /lib /lib64; do
              if [ -L "$_step_top" ]; then STEP_REAL_LOADER+=(--symlink "$(readlink "$_step_top")" "$_step_top")
              elif [ -d "$_step_top" ]; then STEP_REAL_LOADER+=(--ro-bind "$_step_top" "$_step_top"); fi
            done
            env -i HOME="$TMP/stepfun-door/real-home" PATH=/usr/local/bin:/usr/bin:/bin STEP_API_KEY=nonsecret-test-value \
              bwrap --die-with-parent --unshare-all --ro-bind /usr /usr "${STEP_REAL_LOADER[@]}" \
              --ro-bind /etc /etc --dev /dev --proc /proc --tmpfs /tmp --tmpfs /run \
              --tmpfs "$TMP/stepfun-door/real-home" --ro-bind "$(dirname "$STEP_REAL_BIN")" "$(dirname "$STEP_REAL_BIN")" \
              -- "$STEP_REAL_BIN" --no-extensions --list-models > "$TMP/stepfun-door/empty-models.out" 2>&1
            check 'Pinned StepCode refuses an empty isolated catalog' \
              "grep -q 'No models available' '$TMP/stepfun-door/empty-models.out'"
            env -i HOME="$TMP/stepfun-door/real-home" PATH=/usr/local/bin:/usr/bin:/bin STEP_API_KEY=nonsecret-test-value \
              bwrap --die-with-parent --unshare-all --ro-bind /usr /usr "${STEP_REAL_LOADER[@]}" \
              --ro-bind /etc /etc --dev /dev --proc /proc --tmpfs /tmp --tmpfs /run \
              --tmpfs "$TMP/stepfun-door/real-home" --dir "$TMP/stepfun-door/real-home/.stepcode" \
              --ro-bind "$TMP/stepfun-door/work/captured-models.json" "$TMP/stepfun-door/real-home/.stepcode/models.json" \
              --ro-bind "$(dirname "$STEP_REAL_BIN")" "$(dirname "$STEP_REAL_BIN")" \
              -- "$STEP_REAL_BIN" --no-extensions --list-models > "$TMP/stepfun-door/isolated-models.out" 2>&1
            check 'Pinned StepCode lists only the door-pinned model offline' \
              "test \"\$(awk 'NR > 1 {print \$1 \"/\" \$2}' '$TMP/stepfun-door/isolated-models.out')\" = step/step-5-preview"
          else
            skip 'Pinned StepCode offline catalog proof requires the installed StepCode binary'
          fi
          # The fixture exits immediately after its final RPC response. Delay
          # the parent's next read so Bash has reaped the named coprocess: its
          # original descriptors are gone, but the door must retain the reply.
          jq() {
            local jq_rc
            command jq "$@"; jq_rc=$?
            [[ "$*" != *get_last_assistant_text* ]] || sleep 0.1
            return "$jq_rc"
          }
          export -f jq
          if AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 AI_STEPFUN_STEP_BIN="$TMP/stepfun-door/bin/step" \
            AI_STEPFUN_MODEL=step/step-3.7-flash AI_STEPFUN_ALLOW_NO_CREDS=1 DOOR_TIMEOUT=10 \
            DOOR_WORKDIR="$TMP/stepfun-door/work" DOOR_PACKET_DIR="$TMP/stepfun-door/packet" \
            DOOR_PROMPT_FILE="$TMP/stepfun-door/prompt" DOOR_REPORT_OUT="$TMP/stepfun-door/override-report" \
            DOOR_HEAD="$(git -C "$REPO_ROOT" rev-parse HEAD)" bash "$STEPFUN_DOOR" implement \
            > "$TMP/stepfun-door/override-door.out" 2>&1; then
            check 'StepFun door catalog follows an explicit Step model override' \
              "jq -e '.providers.step.models | map(.id) == [\"step-3.7-flash\"]' '$TMP/stepfun-door/work/captured-models.json' >/dev/null"
          else
            cat "$TMP/stepfun-door/override-door.out"
            bad 'StepFun door catalog follows an explicit Step model override'
          fi
          unset -f jq
        else
          bad 'StepFun door uses supported writable approval and runs step --version'
        fi
        ;;
      *) skip 'StepFun door loader regression requires an ELF interpreter under /lib or /lib64' ;;
    esac
  else
    bad 'StepFun door dynamic fixture compiles'
  fi
else
  skip 'StepFun door loader regression requires Linux, cc, readelf, and usable bubblewrap'
fi

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

# Unregistered providers would keep their legacy session-runner path, but all
# six pool providers are now registered doors, so that path has no live subject
# among them. The honest replacement guard: every pool provider IS a registered
# door (so a plain AI_POOL_RUNNER_* substitution is refused as a bypass), and
# the legacy fallback remains in the pool for any future unregistered provider.
echo '== pool providers are all registered doors (legacy path has no live subject)'
for _pp in grok muse qwen gemini deepseek stepfun; do
  check "pool_provider_${_pp}_is_a_registered_door" "jq -e 'has(\"'$_pp'\")' '$DOORS_JSON' >/dev/null"
done
unset _pp
check "pool_keeps_legacy_fallback_for_future_unregistered_providers" \
  "grep -q 'Legacy session-runner fallback only' '$POOL' && grep -q 'AI_POOL_RUNNER_MUSE' '$POOL'"
# A plain substitution for a registered door is a bypass and must be refused.
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
check "pool_refuses_runner_substitution_for_registered_door" \
  "test '$POOL_MUSE_RC' -ne 0 && grep -q 'bypasses the shared review runner' '$TMP/pool-muse.err' && ! grep -q 'must never be used' '$TMP/pool-muse.err'"

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
for _pdoor in "$GROK_DOOR" "$DEEPSEEK_DOOR" "$MUSE_DOOR" "$QWEN_DOOR" "$GEMINI_DOOR" "$STEPFUN_DOOR"; do
  _pname="$(basename "$_pdoor" .sh)"
  check "adapter_${_pname}_has_no_packet_remove" "! grep -nE 'PACKET(_BIN)?[[:space:]]+remove|ai-review-packet[[:space:]]+remove' '$_pdoor' | grep -q ."
  check "adapter_${_pname}_has_no_sandbox_delete" "! grep -nE 'remove-copy|remove_code_only|sandbox.*remove' '$_pdoor' | grep -q ."
  check "adapter_${_pname}_has_no_lifecycle_terminal" "! grep -nE 'ai-review-lifecycle|rlc_lifecycle|lifecycle (finish|fail|begin)' '$_pdoor' | grep -q ."
  check "adapter_${_pname}_has_no_lock_or_cleanup" "! grep -nE 'lock_acquire|unlock_session|cleanup_after_store|PACKET remove' '$_pdoor' | grep -q ."
  check "adapter_${_pname}_keeps_provider_bits" "grep -q 'extract_report' '$_pdoor' && grep -qE 'MODEL=' '$_pdoor'"
done
unset _pdoor _pname
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

# A provider still routed through the legacy pool has no engine door. Reject
# the mistaken request before any invocation or sandbox can be created.
for unavailable_contract in review implement; do
  unavailable_state="$TMP/unavailable-$unavailable_contract-state"
  unavailable_sandbox="$TMP/unavailable-$unavailable_contract-sandboxes"
  unavailable_rc=0
  AI_REVIEW_LIFECYCLE_DIR="$unavailable_state" \
    AI_REVIEW_SANDBOX_DIR="$unavailable_sandbox" \
    bash "$ENGINE" "$unavailable_contract" --provider glm --name no-glm-door \
      --repo "$MREPO" >"$TMP/unavailable-$unavailable_contract.out" \
      2>"$TMP/unavailable-$unavailable_contract.err" || unavailable_rc=$?
  check "engine_${unavailable_contract}_missing_door_creates_no_invocation" \
    "test '$unavailable_rc' -ne 0 && grep -q 'no door registered' '$TMP/unavailable-$unavailable_contract.err' && test ! -d '$unavailable_state/runs' && test ! -d '$unavailable_sandbox'"
done

missing_override_rc=0
AI_REVIEW_DOOR_GROK="$TMP/missing-provider-door.sh" \
  AI_REVIEW_LIFECYCLE_DIR="$TMP/missing-override-state" \
  AI_REVIEW_SCOREBOARD_DIR="$TMP/missing-override-scoreboard" \
  AI_REVIEW_SCOREBOARD_FILE="$TMP/missing-override-scoreboard/reviews.jsonl" \
  bash "$ENGINE" review --provider grok --name missing-door-override \
    --repo "$MREPO" >"$TMP/missing-override.out" \
    2>"$TMP/missing-override.err" || missing_override_rc=$?
check "engine_missing_door_override_is_local_admission_failure" \
  "test '$missing_override_rc' -ne 0 && grep -q 'door override is not a file' '$TMP/missing-override.err' && test ! -d '$TMP/missing-override-state/runs' && test ! -e '$TMP/missing-override-scoreboard/reviews.jsonl'"

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

# GLM remains on the legacy pool route until it has a registered engine door.
# Exercise that route offline: lifecycle record-tests must persist the exact
# test command/output digest before the fake GLM runner can start, and the
# child test command must not receive the caller's source-receipt path.
POOL_LIFECYCLE_WRAPPER="$TMP/pool-lifecycle-wrapper"
cat > "$POOL_LIFECYCLE_WRAPPER" <<'EOF'
#!/usr/bin/env bash
set -e
command_name="${1:-}"
state=""
shift || true
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  if [ "${args[$i]}" = --state ] && [ $((i+1)) -lt ${#args[@]} ]; then state="${args[$((i+1))]}"; fi
done
if [ "$command_name" = record-tests ] && [ "${AI_POOL_FAIL_RECORD:-0}" = 1 ]; then
  printf '%s\n' "$state" > "$AI_POOL_TEST_STATE_FILE"
  exit 1
fi
"$AI_POOL_REAL_LIFECYCLE" "$command_name" "${args[@]}"
if [ "$command_name" = record-tests ]; then
  printf '%s\n' "$state" > "$AI_POOL_TEST_STATE_FILE"
  printf 'record-tests\n' >> "$AI_POOL_ORDER_FILE"
fi
EOF
chmod +x "$POOL_LIFECYCLE_WRAPPER"
POOL_GLM_STUB="$TMP/pool-glm-stub"
cat > "$POOL_GLM_STUB" <<'EOF'
#!/usr/bin/env bash
printf 'runner\n' >> "$AI_POOL_ORDER_FILE"
state="$(cat "$AI_POOL_TEST_STATE_FILE")"
jq -e --arg cmd "$AI_POOL_TEST_COMMAND" '.tests.exit==0 and .tests.command==$cmd and (.tests.output_sha256|test("^[0-9a-f]{64}$"))' "$state" >/dev/null || exit 88
exit 99
EOF
chmod +x "$POOL_GLM_STUB"
POOL_TEST_COMMAND="printf '%s' \"\${AI_REVIEW_SOURCE_RECEIPT_FILE-unset}\" > '$TMP/pool-tests-receipt'; printf 'pool-test-evidence\\n'"
POOL_ORDER_FILE="$TMP/pool-order"
POOL_TEST_STATE_FILE="$TMP/pool-test-state"
rm -f "$POOL_ORDER_FILE" "$POOL_TEST_STATE_FILE" "$TMP/pool-tests-receipt"
set +e
( cd "$PREPO" && AI_POOL_TEST_HOOKS=1 AI_POOL_RUNNER_GLM="$POOL_GLM_STUB" \
    AI_POOL_CALLER=codex AI_REVIEW_LIFECYCLE_BIN="$POOL_LIFECYCLE_WRAPPER" \
    AI_POOL_REAL_LIFECYCLE="$REPO_ROOT/bin/ai-review-lifecycle" \
    AI_POOL_ORDER_FILE="$POOL_ORDER_FILE" AI_POOL_TEST_STATE_FILE="$POOL_TEST_STATE_FILE" \
    AI_POOL_TEST_COMMAND="$POOL_TEST_COMMAND" AI_REVIEW_PREFLIGHT_BIN="$PREFLIGHT_STUB" \
    AI_REVIEW_LIFECYCLE_DIR="$TMP/pool-glm-lifecycle" AI_REVIEW_SANDBOX_DIR="$TMP/pool-glm-sandboxes" \
    AI_REVIEW_SCOREBOARD_DIR="$TMP/pool-glm-scoreboard" AI_REVIEW_SCOREBOARD_FILE="$TMP/pool-glm-scoreboard/reviews.jsonl" \
    AI_REVIEW_SOURCE_RECEIPT_FILE="$TMP/private-source-receipt.json" \
    AI_REVIEW_EVENT_DIR="$TMP/pool-glm-events" AI_REVIEW_PRIVACY_BASE="$TMP/pool-glm-privacy" \
    AI_DEVOPS_MODELS_ENV="$TMP/no-models-env" \
    bash "$POOL" glm diff-review --tests "$POOL_TEST_COMMAND" ) >"$TMP/pool-glm-tests.out" 2>"$TMP/pool-glm-tests.err"
POOL_GLM_TESTS_RC=$?
set -e
check "legacy_glm_records_passing_tests_before_dispatch" \
  "test '$POOL_GLM_TESTS_RC' -ne 0 && [ \"\$(cat '$POOL_ORDER_FILE')\" = \"\$(printf 'record-tests\\nrunner')\" ] && jq -e '.tests.exit==0 and (.tests.output_sha256|test(\"^[0-9a-f]{64}$\"))' \"\$(cat '$POOL_TEST_STATE_FILE')\" >/dev/null"
check "legacy_glm_test_child_does_not_receive_source_receipt" "[ \"\$(cat '$TMP/pool-tests-receipt')\" = unset ]"
check "legacy_glm_test_failure_does_not_claim_provider_success" "grep -q 'glm runner exited nonzero (99)' '$TMP/pool-glm-tests.err'"
POOL_FAIL_ORDER_FILE="$TMP/pool-fail-order"
POOL_FAIL_STATE_FILE="$TMP/pool-fail-test-state"
POOL_FAIL_RUNNER_FILE="$TMP/pool-fail-runner"
rm -f "$POOL_FAIL_ORDER_FILE" "$POOL_FAIL_STATE_FILE" "$POOL_FAIL_RUNNER_FILE"
set +e
( cd "$PREPO" && AI_POOL_TEST_HOOKS=1 AI_POOL_RUNNER_GLM="$POOL_GLM_STUB" \
    AI_POOL_CALLER=codex AI_REVIEW_LIFECYCLE_BIN="$POOL_LIFECYCLE_WRAPPER" \
    AI_POOL_REAL_LIFECYCLE="$REPO_ROOT/bin/ai-review-lifecycle" \
    AI_POOL_ORDER_FILE="$POOL_FAIL_ORDER_FILE" AI_POOL_TEST_STATE_FILE="$POOL_FAIL_STATE_FILE" \
    AI_POOL_TEST_COMMAND="$POOL_TEST_COMMAND" AI_POOL_FAIL_RECORD=1 AI_REVIEW_PREFLIGHT_BIN="$PREFLIGHT_STUB" \
    AI_REVIEW_LIFECYCLE_DIR="$TMP/pool-glm-failed-record-lifecycle" AI_REVIEW_SANDBOX_DIR="$TMP/pool-glm-failed-record-sandboxes" \
    AI_REVIEW_SCOREBOARD_DIR="$TMP/pool-glm-failed-record-scoreboard" AI_REVIEW_SCOREBOARD_FILE="$TMP/pool-glm-failed-record-scoreboard/reviews.jsonl" \
    AI_REVIEW_SOURCE_RECEIPT_FILE="$TMP/private-source-receipt.json" \
    AI_REVIEW_EVENT_DIR="$TMP/pool-glm-failed-record-events" AI_REVIEW_PRIVACY_BASE="$TMP/pool-glm-failed-record-privacy" \
    AI_DEVOPS_MODELS_ENV="$TMP/no-models-env" \
    bash "$POOL" glm diff-review --tests "$POOL_TEST_COMMAND" ) >"$TMP/pool-glm-record-fail.out" 2>"$TMP/pool-glm-record-fail.err"
POOL_GLM_RECORD_FAIL_RC=$?
set -e
check "legacy_glm_record_failure_is_terminal_without_dispatch" \
  "test '$POOL_GLM_RECORD_FAIL_RC' -ne 0 && grep -q 'no review was dispatched' '$TMP/pool-glm-record-fail.err' && test ! -s '$POOL_FAIL_ORDER_FILE' && jq -e '.status==\"failed\" and .failure_class==\"tests-evidence-recording-failed\"' \"\$(cat '$POOL_FAIL_STATE_FILE')\" >/dev/null"

export AI_REVIEW_PREFLIGHT_BIN="$PREFLIGHT_STUB"
export AI_REVIEW_SCOREBOARD_BIN="$SCOREBOARD_STUB"
export AI_REVIEW_DOOR_GROK="$MOCK_DOOR"
export AI_REVIEW_RUNNER_DOORS_JSON="$REPO_ROOT/config/review-runner-doors.json"
CORE_TEST_MARKER="$TMP/core-tests-receipt"
CORE_TEST_COMMAND="printf '%s' \"\${AI_REVIEW_SOURCE_RECEIPT_FILE-unset}\" > '$CORE_TEST_MARKER'; printf 'native-core-test-output\\n'"
# A governed receipt must live in the source's ignored .ai/reviews; the core
# publishes it after a qualified final for every core door (#1783).
mkdir -p "$MREPO/.ai/reviews"
CORE_RECEIPT="$(cd "$MREPO" && pwd -P)/.ai/reviews/private-source-receipt.json"
export AI_REVIEW_SOURCE_RECEIPT_FILE="$CORE_RECEIPT"

set +e
( cd "$MREPO" && timeout 90 "$ENGINE" review --provider grok --name engine-e2e --repo "$MREPO" \
    --mode diff-review --caller codex --tests "$CORE_TEST_COMMAND" ) >"$TMP/e2e.out" 2>"$TMP/e2e.err"
E2E_RC=$?
set -e
check "review_contract_succeeds_through_runner" "test '$E2E_RC' -eq 0"
REPORT_PATH="$(tail -1 "$TMP/e2e.out" 2>/dev/null || true)"
check "review_contract_leaves_report" "test -s '$REPORT_PATH' && grep -q '## Verdict' '$REPORT_PATH'"
check "report_records_runner_stamp" "grep -q 'review-lifecycle-core/1' '$REPORT_PATH'"
check "report_binds_reviewed_head" "grep -q '$HEAD_SHA' '$REPORT_PATH'"
check "review_contract_leaves_durable_packet" "test -d '$AI_REVIEW_PACKET_STORE' && find '$AI_REVIEW_PACKET_STORE' -name MANIFEST.md | grep -q ."
check "cleanup_removed_working_sandbox_after_store" "! find '${TMP}' -maxdepth 2 -type d -name '*engine-e2e*' 2>/dev/null | grep -v packet-store | grep -q ."
# Step 4 (plan_edge-dev-reviewer-repair-no-review): after the engine process
# has exited the report is still a complete, openable artifact outside every
# sandbox, and a later orphan sweep cannot take it.
check "durable_report_openable_after_engine_exit" \
  "test -s '$REPORT_PATH' && [ -f '$REPORT_PATH' ] && [ ! -L '$REPORT_PATH' ] \
   && grep -q '## Verdict' '$REPORT_PATH' && grep -q '$HEAD_SHA' '$REPORT_PATH' \
   && grep -q 'review-lifecycle-core/1' '$REPORT_PATH' \
   && case '$REPORT_PATH' in '$AI_REVIEW_SANDBOX_DIR'/*) false ;; *) true ;; esac"
set +e
"$REPO_ROOT/bin/ai-review-sandbox" sweep-orphans --max-age-seconds 0 --max-removals 32 \
  >/dev/null 2>&1
set -e
check "durable_report_survives_later_orphan_sweep" \
  "test -s '$REPORT_PATH' && grep -q '## Verdict' '$REPORT_PATH' && grep -q '$HEAD_SHA' '$REPORT_PATH'"
CORE_TEST_STATE=""
while IFS= read -r _core_state; do
  if jq -e '.tests.exit==0 and (.tests.command|contains("core-tests-receipt")) and (.tests.output_sha256|test("^[0-9a-f]{64}$"))' "$_core_state" >/dev/null 2>&1; then CORE_TEST_STATE="$_core_state"; break; fi
done < <(find "$AI_REVIEW_LIFECYCLE_DIR/runs" -type f -name '*.json' -print 2>/dev/null)
check "core_test_child_does_not_receive_source_receipt" "[ \"\$(cat '$CORE_TEST_MARKER')\" = unset ] && [ \"\$AI_REVIEW_SOURCE_RECEIPT_FILE\" = '$CORE_RECEIPT' ]"
check "core_door_final_publishes_governed_receipt" "jq -e '.schema_version==1 and (.packet_sha256|test(\"^[0-9a-f]{64}$\"))' '$CORE_RECEIPT' >/dev/null"
check "core_tests_are_recorded_with_output_hash" "test -n '$CORE_TEST_STATE' && jq -e '.tests.exit==0 and (.tests.command|contains(\"core-tests-receipt\")) and (.tests.output_sha256|test(\"^[0-9a-f]{64}$\"))' '$CORE_TEST_STATE' >/dev/null"
unset AI_REVIEW_SOURCE_RECEIPT_FILE
CORE_NEVER_DOOR="$TMP/core-never-door"
cat > "$CORE_NEVER_DOOR" <<'EOF'
#!/usr/bin/env bash
printf 'called\n' >> "$CORE_DOOR_CALLS"
exit 99
EOF
chmod +x "$CORE_NEVER_DOOR"
CORE_FAIL_STATE_FILE="$TMP/core-fail-test-state"
CORE_FAIL_DOOR_CALLS="$TMP/core-fail-door-calls"
rm -f "$CORE_FAIL_STATE_FILE" "$CORE_FAIL_DOOR_CALLS"
set +e
( cd "$MREPO" && env AI_REVIEW_LIFECYCLE_BIN="$POOL_LIFECYCLE_WRAPPER" \
    AI_POOL_REAL_LIFECYCLE="$REPO_ROOT/bin/ai-review-lifecycle" AI_POOL_FAIL_RECORD=1 \
    AI_POOL_TEST_STATE_FILE="$CORE_FAIL_STATE_FILE" AI_POOL_ORDER_FILE="$TMP/core-fail-order" \
    AI_REVIEW_DOOR_GROK="$CORE_NEVER_DOOR" CORE_DOOR_CALLS="$CORE_FAIL_DOOR_CALLS" \
    AI_REVIEW_PREFLIGHT_BIN="$PREFLIGHT_STUB" AI_REVIEW_LIFECYCLE_DIR="$TMP/core-record-fail-lifecycle" \
    AI_REVIEW_SANDBOX_DIR="$TMP/core-record-fail-sandboxes" \
    AI_REVIEW_SCOREBOARD_BIN="$SCOREBOARD_STUB" AI_REVIEW_SCOREBOARD_DIR="$TMP/core-record-fail-scoreboard" \
    AI_REVIEW_SCOREBOARD_FILE="$TMP/core-record-fail-scoreboard/reviews.jsonl" \
    AI_REVIEW_EVENT_DIR="$TMP/core-record-fail-events" AI_REVIEW_PRIVACY_BASE="$TMP/core-record-fail-privacy" \
    AI_REVIEW_RUNNER_DOORS_JSON="$REPO_ROOT/config/review-runner-doors.json" \
    AI_DEVOPS_TEST_MODE=1 AI_TASK_GATES_MODE=none \
    "$ENGINE" review --provider grok --name core-record-failure --repo "$MREPO" \
      --mode diff-review --caller codex --tests "printf 'core failure test\\n'" ) \
    >"$TMP/core-record-fail.out" 2>"$TMP/core-record-fail.err"
CORE_RECORD_FAIL_RC=$?
set -e
check "core_test_recording_failure_is_terminal_without_door_dispatch" \
  "test '$CORE_RECORD_FAIL_RC' -ne 0 && grep -q 'no review was dispatched' '$TMP/core-record-fail.err' && test ! -e '$CORE_FAIL_DOOR_CALLS' && jq -e '.status==\"failed\" and .failure_class==\"tests-evidence-recording-failed\"' \"\$(cat '$CORE_FAIL_STATE_FILE')\" >/dev/null"

# Lifecycle terminal carries packet identity (Phase A contract, used by the runner).
STATE_FILE="$(grep -Rsl '"status": "completed"' "$AI_REVIEW_LIFECYCLE_DIR/runs" 2>/dev/null | head -1)"
check "lifecycle_records_packet_identity" "test -n '$STATE_FILE' && jq -e '.packet_sha256|test(\"^[0-9a-f]{64}\")' '$STATE_FILE' && jq -e '.packet_dir|type==\"string\" and length>0' '$STATE_FILE'"
check "lifecycle_records_completed_verdict" "test -n '$STATE_FILE' && jq -e '.status==\"completed\" and .verdict==\"APPROVE\"' '$STATE_FILE'"
check "lifecycle_records_runner_fields_on_report" "grep -q 'runner | \`ai-review-engine\`' '$REPORT_PATH'"

# --- Phase D completeness: each migrated door emits packet identity ---------
# The four doors migrated in mimo/phasee-four-doors must finish through the
# same packet-aware lifecycle terminal as grok/deepseek. A mock door stands
# in for the provider; the runner (not the door) owns packet seal/store and
# writes packet_dir + packet_sha256 into the lifecycle state.
echo '== packet identity per migrated door (mock door through the runner)'
for _prov in muse qwen gemini stepfun; do
  _mock="$TMP/mock-door-$_prov.sh"
  cat > "$_mock" <<EOF
#!/usr/bin/env bash
set -euo pipefail
[ "\${AI_REVIEW_RUNNER_CORE:-}" = "review-lifecycle-core/1" ] || { echo 'mock: missing runner token' >&2; exit 2; }
[ -f "\${DOOR_PACKET_DIR:-/nonexistent}/MANIFEST.md" ] || { echo 'mock: packet missing' >&2; exit 2; }
body='Reviewed head is quoted above. The change is correct on its own terms, the surrounding module was checked for sibling defects and none remain, and the tests that cover this path are present and meaningful. No blocking findings in this change set. The evidence packet was read first and every claim below is grounded in it.'
{
  printf '# %s mock review\n\n' '$_prov'
  printf 'Reviewed head: %s\n\n' "\$DOOR_HEAD"
  printf '%s\n\n' "\$body"
  printf -- '---\n\n## Verdict\nAPPROVE\n'
} > "\$DOOR_REPORT_OUT"
exit 0
EOF
  chmod +x "$_mock"
  _ov="AI_REVIEW_DOOR_$(printf '%s' "$_prov" | tr '[:lower:]' '[:upper:]')"
  set +e
  ( cd "$MREPO" && env "$_ov=$_mock" timeout 90 "$ENGINE" review --provider "$_prov" \
      --name "engine-$_prov" --repo "$MREPO" --mode diff-review --caller codex ) \
    >"$TMP/e2e-$_prov.out" 2>"$TMP/e2e-$_prov.err"
  _prc=$?
  set -e
  check "door_${_prov}_review_succeeds_through_runner" "test '$_prc' -eq 0"
  _pstate="$(grep -Rsl '"provider": "'"$_prov"'"' "$AI_REVIEW_LIFECYCLE_DIR/runs" 2>/dev/null | head -1)"
  check "door_${_prov}_lifecycle_records_packet_sha256" \
    "test -n '$_pstate' && jq -e '.packet_sha256|test(\"^[0-9a-f]{64}\")' '$_pstate'"
  check "door_${_prov}_lifecycle_records_packet_dir" \
    "test -n '$_pstate' && jq -e '.packet_dir|type==\"string\" and length>0' '$_pstate'"
  check "door_${_prov}_leaves_durable_packet" \
    "find '$AI_REVIEW_PACKET_STORE' -name MANIFEST.md | grep -q ."
done
unset _prov _mock _ov _prc _pstate

# A real StepFun engine-path fixture with the provider's reported formatting:
# the exact REJECT token follows a blank line, and lifecycle must finish REJECT.
STEPFUN_BLANK_REJECT="$TMP/stepfun-blank-reject-door.sh"
cat > "$STEPFUN_BLANK_REJECT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "${AI_REVIEW_RUNNER_CORE:-}" = "review-lifecycle-core/1" ]
{
  printf 'Reviewed exact head %s. ' "$DOOR_HEAD"
  printf 'The complete change, sibling paths, evidence binding, source identity, fail-closed checks, lifecycle behavior and tests were examined. '
  printf 'This analysis is deliberately long enough to satisfy the report floor and records a substantive rejection. '
  printf 'No approval is granted because the tested fixture models the exact StepFun report shape under review.

## Verdict

REJECT
'
} > "$DOOR_REPORT_OUT"
EOF
chmod +x "$STEPFUN_BLANK_REJECT"
set +e
( cd "$MREPO" && AI_REVIEW_DOOR_STEPFUN="$STEPFUN_BLANK_REJECT" timeout 90 "$ENGINE" review --provider stepfun \
    --name engine-stepfun-blank-reject --repo "$MREPO" --mode final-check --caller codex ) \
    >"$TMP/stepfun-blank-reject.out" 2>"$TMP/stepfun-blank-reject.err"
STEPFUN_BLANK_REJECT_RC=$?
set -e
STEPFUN_BLANK_REJECT_REPORT="$(tail -1 "$TMP/stepfun-blank-reject.out" 2>/dev/null || true)"
STEPFUN_BLANK_REJECT_STATE="$(grep -RslF "$STEPFUN_BLANK_REJECT_REPORT" "$AI_REVIEW_LIFECYCLE_DIR/runs" 2>/dev/null | head -1)"
check "stepfun_engine_blankline_reject_completes_not_missing_verdict" \
  "test '$STEPFUN_BLANK_REJECT_RC' -eq 0 && test -s '$STEPFUN_BLANK_REJECT_REPORT' && jq -e '.status==\"completed\" and .verdict==\"REJECT\" and .failure_class==null' '$STEPFUN_BLANK_REJECT_STATE' >/dev/null"
check "stepfun_engine_blankline_reject_keeps_reject_in_report" \
  "test -s '$STEPFUN_BLANK_REJECT_REPORT' && tail -2 '$STEPFUN_BLANK_REJECT_REPORT' | grep -qx REJECT && ! grep -q 'no valid ## Verdict' '$TMP/stepfun-blank-reject.err'"

# Exercise the original StepFun route end to end: a fake StepCode CLI emits the
# provider's blank-line verdict shape, the real StepFun adapter builds the
# report, and the shared engine must record semantic REJECT (not missing).
SF_E2E="$TMP/stepfun-real-adapter"
mkdir -p "$SF_E2E/home/.config/ai-devops/secrets" "$SF_E2E/bin"
printf 'synthetic-test-key\n' > "$SF_E2E/home/.config/ai-devops/secrets/stepfun-api-key"
chmod 600 "$SF_E2E/home/.config/ai-devops/secrets/stepfun-api-key"
cat > "$SF_E2E/bin/step" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = --help ]; then echo 'step - AI coding assistant'; exit 0; fi
if [ "${1:-}" = --version ]; then echo '0.1.1'; exit 0; fi
case " $* " in *' rpc '*) ;; *) exit 2;; esac
read -r request
prompt="$(jq -r '.message' <<<"$request")"
head="HEAD_PLACEHOLDER"
echo '{"id":"door-prompt","type":"response","command":"prompt","success":true}'
echo '{"type":"agent_settled"}'
read -r request
text="Reviewed exact head $head. The packet identity, source binding, report lifecycle, rejection preservation, whitespace parsing, invalid intervening text, empty verdict handling, and downstream caller impact were checked in detail. The adapter preserves the substantive findings and terminal decision exactly, and the lifecycle records the review as completed with no failure classification. This is a meaningful negative review result that must remain visible to callers and release gates. No approval is granted."
text+=$'\n\n## Verdict\n\nREJECT'
jq -cn --arg text "$text" \
  '{id:"door-text",type:"response",data:{text:$text}}'
EOF
sed -i "s/HEAD_PLACEHOLDER/$HEAD_SHA/" "$SF_E2E/bin/step"
chmod 700 "$SF_E2E/bin/step"
cat > "$SF_E2E/bin/bwrap" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
while [ "$#" -gt 0 ]; do
  case "$1" in
    --) shift; break ;;
    --chdir) shift 2 ;;
    --setenv) export "$2=$3"; shift 3 ;;
    --ro-bind|--bind|--symlink) shift 3 ;;
    --tmpfs|--dev|--proc|--dir) shift 2 ;;
    --unshare-all|--die-with-parent|--new-session|--share-net) shift ;;
    *) echo "unexpected bwrap argument" >&2; exit 2 ;;
  esac
done
exec "$@"
EOF
chmod 700 "$SF_E2E/bin/bwrap"
SF_E2E_RC=0
env -i PATH="$PATH" HOME="$SF_E2E/home" AI_DEVOPS_TEST_MODE=1 AI_TASK_GATES_MODE=none \
  AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes" AI_REVIEW_LIFECYCLE_DIR="$AI_REVIEW_LIFECYCLE_DIR" \
  AI_REVIEW_SCOREBOARD_DIR="$AI_REVIEW_SCOREBOARD_DIR" AI_REVIEW_SCOREBOARD_FILE="$AI_REVIEW_SCOREBOARD_FILE" \
  AI_REVIEW_PACKET_STORE="$AI_REVIEW_PACKET_STORE" AI_REVIEW_IMPLEMENT_ROOT="$AI_REVIEW_IMPLEMENT_ROOT" \
  AI_REVIEW_PREFLIGHT_BIN="$PREFLIGHT_STUB" AI_REVIEW_SCOREBOARD_BIN="$SCOREBOARD_STUB" \
  AI_REVIEW_DOOR_STEPFUN="$STEPFUN_DOOR" AI_STEPFUN_ENGINE=stepcode \
  AI_STEPFUN_STEP_BIN="$SF_E2E/bin/step" AI_STEPFUN_BWRAP="$SF_E2E/bin/bwrap" \
  AI_STEPFUN_KEY_STORE="$SF_E2E/home/.config/ai-devops/secrets/stepfun-api-key" \
  AI_STEPFUN_STATE_DIR="$SF_E2E/home/.local/state/ai-devops/stepfun" \
  AI_STEPFUN_RATE_PAUSE=0 AI_STEPFUN_RPM=100000 timeout 90 "$ENGINE" review --provider stepfun \
    --name engine-stepfun-real-adapter-blank-reject --repo "$MREPO" --mode final-check --caller codex \
    >"$SF_E2E/stdout" 2>"$SF_E2E/stderr" || SF_E2E_RC=$?
SF_E2E_REPORT="$(tail -1 "$SF_E2E/stdout" 2>/dev/null || true)"
SF_E2E_STATE="$(find "$AI_REVIEW_LIFECYCLE_DIR/runs" -path '*/stepfun/codex/*.json' -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)"
if [ "$SF_E2E_RC" -ne 0 ]; then
  cat "$SF_E2E/stderr" >&2
  if [ -n "$SF_E2E_STATE" ]; then cat "$SF_E2E_STATE.diagnostics/report.md" "$SF_E2E_STATE.failure-diagnostics/report.md" 2>/dev/null >&2 || true; fi
fi
check "stepfun_real_adapter_blankline_reject_completes_semantically_through_engine" \
  "test '$SF_E2E_RC' -eq 0 && test -s '$SF_E2E_REPORT' && jq -e '.status==\"completed\" and .verdict==\"REJECT\" and .failure_class==null' '$SF_E2E_STATE' >/dev/null"
check "stepfun_real_adapter_blankline_reject_preserves_terminal_report" \
  "test -s '$SF_E2E_REPORT' && tail -2 '$SF_E2E_REPORT' | grep -qx REJECT && ! grep -q 'no valid ## Verdict' '$SF_E2E/stderr'"

# A door's out-of-credit exit (92, rotation rule 10) must survive the runner,
# as ai-review-pool keeps it for wrappers; anything else is provider-failed.
echo '== out of credit through the runner'
CREDIT_DOOR="$TMP/credit-door.sh"
cat > "$CREDIT_DOOR" <<'EOF'
#!/usr/bin/env bash
printf 'AI_REVIEWER_OUT_OF_CREDIT provider=stepfun code=insufficient_quota\n' >&2
exit 92
EOF
set +e
( cd "$MREPO" && AI_REVIEW_DOOR_STEPFUN="$CREDIT_DOOR" timeout 90 "$ENGINE" review --provider stepfun \
    --name engine-credit --repo "$MREPO" --mode diff-review --caller codex ) >"$TMP/e2e-credit.out" 2>"$TMP/e2e-credit.err"
_crc=$?
set -e
check "runner_keeps_door_out_of_credit_exit_92" "test '$_crc' -eq 92 && grep -q '^AI_REVIEWER_OUT_OF_CREDIT ' '$TMP/e2e-credit.err'"
check "runner_books_out_of_credit_failure" "grep -Rqs '\"out-of-credit\"' '$AI_REVIEW_LIFECYCLE_DIR/runs'"
capacity_retention_refusal_case() {
  local provider="$1" fixture="$TMP/capacity-retention-$1" rc=0
  mkdir -p "$fixture/home" "$fixture/work" "$fixture/old-evidence"
  printf 'immutable earlier diagnostic\n' > "$fixture/old-evidence/sentinel"
  printf 'Implement the synthetic fixture.\n' > "$fixture/prompt"
  if [ "$provider" = deepseek ]; then
    cat > "$fixture/native" <<'EOF'
#!/usr/bin/env bash
cat <<'JSON'
{"type":"error","error":{"data":{"statusCode":402,"message":"Insufficient Balance"}}}
JSON
exit 1
EOF
  else
    cat > "$fixture/native" <<'EOF'
#!/usr/bin/env bash
printf '402: {"message":"You exceeded your current quota, please check your plan and billing details","type":"quota_exceeded"}\n' >&2
exit 1
EOF
  fi
  chmod +x "$fixture/native"
  HOME="$fixture/home" AI_DEVOPS_CONFIG_DIR="$fixture/config" \
    AI_REVIEW_TEST_ISOLATION=1 AI_REVIEWER_STATE_BASE="$fixture/state" \
    AI_REVIEW_EVENT_DIR="$fixture/events" AI_REVIEW_SCOREBOARD_DIR="$fixture/scoreboard" \
    AI_REVIEW_SCOREBOARD_FILE="$fixture/scoreboard/events.jsonl" \
    AI_REVIEW_QUARANTINE_DIR="$fixture/quarantine" \
    AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 \
    AI_DEEPSEEK_OPENCODE="$fixture/native" AI_DEEPSEEK_ALLOW_NO_CREDS=1 \
    AI_STEPFUN_ENGINE=opencode AI_STEPFUN_OPENCODE="$fixture/native" AI_STEPFUN_ALLOW_NO_CREDS=1 \
    AI_STEPFUN_KEY_STORE="$fixture/no-key" AI_STEPFUN_STATE_DIR="$fixture/stepfun-state" \
    AI_STEPFUN_RATE_RETRIES=0 AI_STEPFUN_RPM=100000 \
    DOOR_WORKDIR="$fixture/work" DOOR_PACKET_DIR="$fixture/work" \
    DOOR_PROMPT_FILE="$fixture/prompt" DOOR_REPORT_OUT="$fixture/report.md" \
    DOOR_DIAGNOSTICS_DIR="$fixture/old-evidence" DOOR_HEAD="$HEAD_SHA" \
    bash "$REPO_ROOT/tools/lib/review-doors/$provider.sh" implement \
    > "$fixture/stdout" 2> "$fixture/stderr" || rc=$?
  [ "$rc" = 92 ] &&
    grep -q "AI_REVIEWER_OUT_OF_CREDIT provider=$provider" "$fixture/stderr" &&
    grep -q 'both retained' "$fixture/stderr" &&
    ls -d "$fixture"/old-evidence.collision-* >/dev/null 2>&1 &&
    test -s "$(ls -d "$fixture"/old-evidence.collision-* | head -1)/report.md" &&
    grep -q 'private diagnostic retention refused' "$fixture/stderr" &&
    grep -qx 'immutable earlier diagnostic' "$fixture/old-evidence/sentinel" &&
    [ ! -e "$fixture/old-evidence/native.jsonl" ] && [ ! -e "$fixture/report.md" ]
}
check 'deepseek_capacity_exit_92_survives_real_immutable_retention_refusal' 'capacity_retention_refusal_case deepseek'
check 'stepfun_capacity_exit_92_survives_real_immutable_retention_refusal' 'capacity_retention_refusal_case stepfun'
unset _crc

# --- --operation install-gate contract through the runner -------------------
# A named installation operation must reach the reviewer request as the exact
# approval line the install gate greps for, and the report must record it
# (issue #658). The mock door echoes its prompt so the brief is inspectable.
echo '== --operation through the runner (install gate)'
OP_DOOR="$TMP/op-door.sh"
cat > "$OP_DOOR" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "${AI_REVIEW_RUNNER_CORE:-}" = "review-lifecycle-core/1" ] || exit 2
body='Reviewed head is quoted in the request. The installation operation under review was checked against the change, the surrounding launcher paths show no sibling defects, and the tests covering this path are present. No blocking findings in this change set. The evidence packet was read first and every claim below is grounded in it.'
{
  printf '# operation mock review\n\n'
  printf 'Reviewed head: %s\n\n' "$DOOR_HEAD"
  printf '%s\n\n' "$body"
  printf -- '---\n\n## Request as given to the reviewer\n\n'
  cat "$DOOR_PROMPT_FILE"
  printf -- '\n---\n\n## Verdict\nAPPROVE\n'
} > "$DOOR_REPORT_OUT"
exit 0
EOF
chmod +x "$OP_DOOR"
set +e
( cd "$MREPO" && env AI_REVIEW_DOOR_QWEN="$OP_DOOR" timeout 90 "$ENGINE" review --provider qwen \
    --name engine-op --repo "$MREPO" --mode final-check --caller codex \
    --operation legacy-managed-launcher-refresh ) >"$TMP/op.out" 2>"$TMP/op.err"
OP_RC=$?
set -e
check "operation_review_succeeds_through_runner" "test '$OP_RC' -eq 0"
OP_REPORT="$(tail -1 "$TMP/op.out" 2>/dev/null || true)"
check "operation_report_records_operation" "test -s '$OP_REPORT' && grep -Fq '| operation | \`legacy-managed-launcher-refresh\` |' '$OP_REPORT'"
check "operation_brief_requests_exact_line" "test -s '$OP_REPORT' && grep -Fqx 'Approved legacy-managed-launcher-refresh.' '$OP_REPORT'"
# The executed --tests output reaches the reviewer (#1562): a reviewer that
# cannot run tests itself must see what ran, not only that it exited 0.
rm -f "$AI_REVIEW_LIFECYCLE_DIR/runs"/* 2>/dev/null || true
set +e
( cd "$MREPO" && env AI_REVIEW_DOOR_QWEN="$OP_DOOR" timeout 90 "$ENGINE" review --provider qwen \
    --name engine-tests-evidence --repo "$MREPO" --mode final-check --caller codex \
    --tests 'echo evidence-sentinel-1562; echo 7 passed, 0 failed' ) >"$TMP/te.out" 2>"$TMP/te.err"
TE_RC=$?
set -e
TE_REPORT="$(tail -1 "$TMP/te.out" 2>/dev/null || true)"
check "executed_tests_output_reaches_reviewer" "test '$TE_RC' -eq 0 && test -s '$TE_REPORT' && grep -Fq 'Executed test output' '$TE_REPORT' && grep -Fqx 'evidence-sentinel-1562' '$TE_REPORT' && grep -Fqx '7 passed, 0 failed' '$TE_REPORT'"
# An unknown operation must never dispatch, and a non-final-check mode must
# never dispatch either.
rm -f "$AI_REVIEW_LIFECYCLE_DIR/runs"/* 2>/dev/null || true
set +e
( cd "$MREPO" && env AI_REVIEW_DOOR_QWEN="$OP_DOOR" timeout 90 "$ENGINE" review --provider qwen \
    --name engine-opbad --repo "$MREPO" --mode final-check --caller codex \
    --operation not-a-real-operation ) >"$TMP/opbad.out" 2>"$TMP/opbad.err"
OPBAD_RC=$?
set -e
check "operation_unknown_never_dispatches" "test '$OPBAD_RC' -ne 0 && grep -qi 'unknown review operation' '$TMP/opbad.err'"
set +e
( cd "$MREPO" && env AI_REVIEW_DOOR_QWEN="$OP_DOOR" timeout 90 "$ENGINE" review --provider qwen \
    --name engine-opmode --repo "$MREPO" --mode diff-review --caller codex \
    --operation first-managed-install ) >"$TMP/opmode.out" 2>"$TMP/opmode.err"
OPMODE_RC=$?
set -e
check "operation_outside_final_check_never_dispatches" "test '$OPMODE_RC' -ne 0 && grep -qi 'final-check' '$TMP/opmode.err'"

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
check "floor_failure_report_survives_temp_cleanup_with_bound_native_body" \
  "python3 - '$AI_REVIEW_LIFECYCLE_DIR/runs' <<'PY'
import hashlib, json, pathlib, sys
states = [json.loads(p.read_text()) for p in pathlib.Path(sys.argv[1]).rglob('*.json')]
state = next(d for d in states if d.get('failure_class') == 'report-floor')
report = pathlib.Path(state['report_path'])
assert report.is_file() and hashlib.sha256(report.read_bytes()).hexdigest() == state['report_sha256']
summary = json.loads(report.read_text().splitlines()[-1])
native = report.parent / 'native.jsonl'
assert native.is_file() and hashlib.sha256(native.read_bytes()).hexdigest() == summary['native_stdout_sha256']
assert b'## Verdict' in native.read_bytes()
PY"

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

# --- governed native Muse final source receipt (real pool/core/packet) --------
echo '== native Muse final source receipt'
RF_DOOR="$TMP/receipt-door"
cat > "$RF_DOOR" <<'DOOR'
#!/usr/bin/env bash
set -euo pipefail
# The provider consumes the same packet later verified by the core. It must
# never receive an already-published receipt from preparatory verification.
jq -n --arg snapshot "$DOOR_WORKDIR" --arg packet "$DOOR_PACKET_DIR" \
  --arg hash "$(cat "$DOOR_PACKET_DIR/MANIFEST.sha256")" \
  --argjson early "$([ -e "$RF_RECEIPT" ] && printf true || printf false)" \
  '{snapshot:$snapshot,packet:$packet,hash:$hash,early:$early}' > "$RF_FACTS"
case "$RF_CASE" in
  provider-fail) exit 19 ;;
  packet-drift) printf '\nchanged after provider read\n' >> "$DOOR_PACKET_DIR/MANIFEST.md" ;;
  source-drift) printf '\nsource moved\n' >> "$RF_SOURCE/a.txt" ;;
esac
bash "$RF_MOCK_DOOR" "$@"
if [ "$RF_CASE" = reject ]; then sed 's/^APPROVE$/REJECT/' "$DOOR_REPORT_OUT" > "$DOOR_REPORT_OUT.new"; mv "$DOOR_REPORT_OUT.new" "$DOOR_REPORT_OUT"; fi
DOOR
chmod +x "$RF_DOOR"
RF_PACKET_WRAPPER="$TMP/receipt-packet-wrapper"
cat > "$RF_PACKET_WRAPPER" <<'PACKET'
#!/usr/bin/env bash
set -euo pipefail
if [ "$1" != retain ]; then exec "$RF_REAL_PACKET" "$@"; fi
stored="$("$RF_REAL_PACKET" "$@")" || exit $?
case "$RF_CASE" in
  post-store-source-drift) printf '\nlate source change\n' >> "$RF_SOURCE/a.txt" ;;
  receipt-race) printf 'late conflicting receipt\n' > "$RF_RECEIPT" ;;
  retained-drift) printf '\nretained evidence changed\n' >> "$stored/MANIFEST.md" ;;
  post-store-identical) "$RF_REAL_PACKET" verify "$2" >/dev/null ;;
esac
printf '%s\n' "$stored"
PACKET
chmod +x "$RF_PACKET_WRAPPER"
rf_run() {
  local scenario="$1" provider="${2:-muse}" dir="$TMP/receipt-$1-${2:-muse}" source receipt store rc=0 state expected door_var
  mkdir -p "$dir"
  git clone --quiet --no-hardlinks "$MREPO" "$dir/source" || return 1
  source="$(cd "$dir/source" && pwd -P)"
  mkdir -p "$source/.ai/reviews"
  receipt="$source/.ai/reviews/governed.json"; store="$dir/store"
  case "$scenario" in
    conflict) printf 'original conflicting receipt\n' > "$receipt" ;;
    linked) printf 'protected original\n' > "$dir/protected"; ln -s "$dir/protected" "$receipt" || return 1 ;;
    outside) receipt="$dir/outside.json" ;;
    store-fail) printf 'not a store\n' > "$dir/store-file"; store="$dir/store-file" ;;
  esac
  expected="$("$REPO_ROOT/bin/ai-review-packet" resolve "$source" --base HEAD~1 --assert-head "$HEAD_SHA")" || return 1
  door_var="AI_REVIEW_DOOR_$(printf '%s' "$provider" | tr '[:lower:]' '[:upper:]')"
  ( cd "$source" && env AI_POOL_CALLER=codex "$door_var=$RF_DOOR" \
      RF_SOURCE="$source" RF_RECEIPT="$receipt" RF_FACTS="$dir/facts.json" RF_CASE="$scenario" RF_MOCK_DOOR="$MOCK_DOOR" \
      RF_REAL_PACKET="$REPO_ROOT/bin/ai-review-packet" AI_REVIEW_PACKET_BIN="$RF_PACKET_WRAPPER" \
      AI_REVIEW_SOURCE_RECEIPT_FILE="$receipt" AI_REVIEW_PACKET_STORE="$store" \
      AI_REVIEW_LIFECYCLE_DIR="$dir/lifecycle" AI_REVIEW_SANDBOX_DIR="$dir/sandboxes" \
      bash "$POOL" "$provider" final-check --base HEAD~1 --assert-head "$HEAD_SHA" \
      --tests "test -z \"\${AI_REVIEW_SOURCE_RECEIPT_FILE+x}\" && test ! -e '$dir/facts.json'"
  ) > "$dir/stdout" 2> "$dir/stderr" || rc=$?
  state="$(find "$dir/lifecycle/runs" -type f -name '*.json' -print 2>/dev/null | head -1)"
  [ -n "$state" ] || return 1
  case "$scenario" in
    approve|reject|post-store-identical)
      [ "$rc" = 0 ] && [ -s "$receipt" ] || return 1
      jq -e --argjson expected "$expected" --slurpfile facts "$dir/facts.json" \
        '.identity==$expected and .packet_sha256==$facts[0].hash and $facts[0].early==false and .identity.repository!=$facts[0].snapshot' "$receipt" >/dev/null || return 1
      jq -e --arg verdict "$([ "$scenario" = reject ] && printf REJECT || printf APPROVE)" \
        '.status=="completed" and .verdict==$verdict and (.tests.output_sha256|length==64)' "$state" >/dev/null || return 1
      local packet; packet="$(jq -r .packet_dir "$state")"
      [ "$(jq -r .packet_sha256 "$receipt")" = "$(sed -n '4p' "$packet/.ai-review-packet")" ] || return 1
      "$REPO_ROOT/bin/ai-review-packet" verify-retained "$packet" >/dev/null || return 1
      ;;
    *)
      [ "$rc" != 0 ] || return 1
      case "$scenario" in
        conflict) grep -qx 'original conflicting receipt' "$receipt" || return 1 ;;
        linked) [ -L "$receipt" ] && grep -qx 'protected original' "$dir/protected" || return 1 ;;
        receipt-race) grep -qx 'late conflicting receipt' "$receipt" || return 1 ;;
        *) [ ! -e "$receipt" ] || return 1 ;;
      esac
      jq -e '.status!="completed"' "$state" >/dev/null || return 1
      if [ "$scenario" != provider-fail ] && [ "$scenario" != source-drift ]; then
        if [ "$scenario" = post-store-source-drift ]; then
          jq -e '.failure_class=="stale-source" and .stale==true' "$state" >/dev/null || return 1
        else
          jq -e '.failure_class=="source-receipt-publication-failed"' "$state" >/dev/null || return 1
        fi
        local report; report="$(find "$source/.ai/reviews" -maxdepth 1 -name "$provider-final-check-*.md" -print | head -1)"
        [ -s "$report" ] && grep -q '^APPROVE$' "$report" || return 1
        [ -d "$(jq -r .packet "$dir/facts.json")" ] || return 1
      fi
      ;;
  esac
}
for rf_case in approve reject post-store-identical conflict linked outside store-fail packet-drift retained-drift source-drift post-store-source-drift receipt-race provider-fail; do
  check "native_muse_final_receipt_${rf_case}" "rf_run '$rf_case'"
done
# governed_call_skips_pool_reuse (#1783): after a passing review of this head,
# a governed call (no --tests) must run fresh and publish its own receipt
# instead of reusing the cached report.
rf_reuse() {
  local dir="$TMP/receipt-approve-muse" source receipt2 rc=0
  source="$(cd "$dir/source" && pwd -P)"; receipt2="$source/.ai/reviews/governed-second.json"
  ( cd "$source" && env AI_POOL_CALLER=codex AI_REVIEW_DOOR_MUSE="$RF_DOOR" \
      RF_SOURCE="$source" RF_RECEIPT="$receipt2" RF_FACTS="$dir/facts2.json" RF_CASE=approve RF_MOCK_DOOR="$MOCK_DOOR" \
      RF_REAL_PACKET="$REPO_ROOT/bin/ai-review-packet" AI_REVIEW_PACKET_BIN="$RF_PACKET_WRAPPER" \
      AI_REVIEW_SOURCE_RECEIPT_FILE="$receipt2" AI_REVIEW_PACKET_STORE="$dir/store" \
      AI_REVIEW_LIFECYCLE_DIR="$dir/lifecycle" AI_REVIEW_SANDBOX_DIR="$dir/sandboxes" \
      bash "$POOL" muse final-check --base HEAD~1 --assert-head "$HEAD_SHA"
  ) > "$dir/stdout2" 2> "$dir/stderr2" || rc=$?
  [ "$rc" = 0 ] && grep -q 'governed source receipt requested; passing-report reuse skipped' "$dir/stderr2" \
    && ! grep -q 'reusing passing' "$dir/stderr2" && [ -s "$receipt2" ] && [ -s "$dir/facts2.json" ]
}
check "governed_call_skips_pool_reuse" "rf_reuse"
# governed_receipt_published_for_every_core_door (#1783): DeepSeek and StepFun
# go through the same core and must publish, and still refuse on conflict.
for rf_provider in deepseek stepfun; do
  for rf_case in approve reject conflict; do
    check "core_final_receipt_${rf_provider}_${rf_case}" "rf_run '$rf_case' '$rf_provider'"
  done
done

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

# An inherited diagnostics destination must not reach the implement door (#1562).
IMPL_DOOR_DIAG="$TMP/impl-door-diag.sh"
printf '#!/usr/bin/env bash\nprintf "%%s" "${DOOR_DIAGNOSTICS_DIR:-}" > "%s"\nexit 1\n' "$TMP/impl-diag-seen" > "$IMPL_DOOR_DIAG"
chmod +x "$IMPL_DOOR_DIAG"
mkdir -p "$TMP/inherited-diag"
set +e
( cd "$MREPO" && timeout 90 env AI_REVIEW_DOOR_GROK="$IMPL_DOOR_DIAG" RLC_DOOR_DIAGNOSTICS_DIR="$TMP/inherited-diag" \
    "$ENGINE" implement --provider grok --name engine-impl-diag --repo "$MREPO" \
    --prompt-file "$TMP/impl-prompt.txt" --caller codex ) >/dev/null 2>&1
set -e
check "implement_door_gets_no_inherited_diagnostics_dir" "test -f '$TMP/impl-diag-seen' && test ! -s '$TMP/impl-diag-seen'"

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

# #1650: newer Grok CLIs log {"type":"turn_ended","outcome":"cancelled",
# "cancellation_category":"permission_cancelled"} in the session log and may
# exit nonzero with NO JSON. The door must resume once-bounded, and when the
# refusal persists classify it permission-cancelled (never provider-failed),
# naming the refused step and retaining diagnostics.
STUB_PN="$TMP/stub-grok-pn"
cat > "$STUB_PN" <<'STUBEOF'
#!/usr/bin/env bash
resumed=0; mt=""
while [ $# -gt 0 ]; do
  case "$1" in -r) resumed=1; shift 2 ;; --max-turns) mt="$2"; shift 2 ;; *) shift ;; esac
done
d="$GROK_HOME/sessions/C--work/sid-pn1"; mkdir -p "$d"
if [ "$resumed" = 1 ]; then echo "resumed:$mt" >> "$PN_CALLS"; else echo "first:$mt" >> "$PN_CALLS"; fi
if [ "$resumed" = 1 ] && [ "$PN_PERSIST" != 1 ]; then
  printf '%s\n' '{"ts":"2026-10-13T02:20:00Z","type":"turn_ended","outcome":"completed"}' >> "$d/events.jsonl"
  printf '%s\n' '{"text":"## Verdict\nAPPROVE","stopReason":"end_turn","num_turns":1,"sessionId":"sid-pn1","requestId":"req-2","modelUsage":{"grok-4.6-build":{}}}'
  exit 0
fi
printf '%s\n' '{"ts":"2026-10-13T02:10:57Z","type":"tool_call","input":{"command":"rm -rf .git/review-scratch"}}' >> "$d/events.jsonl"
printf '%s\n' '{"ts":"2026-10-13T02:10:58.427Z","type":"turn_ended","outcome":"cancelled","cancellation_category":"permission_cancelled"}' >> "$d/events.jsonl"
exit 1
STUBEOF
chmod +x "$STUB_PN"
run_pn_door() { # run_pn_door PERSIST TAG -> sets PN_RC
  rm -rf "$TMP/pn-home-$2" "$TMP/pn-diag-$2"; : > "$TMP/pn-calls-$2"
  set +e
  AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 GROK_HOME="$TMP/pn-home-$2" \
    PN_PERSIST="$1" PN_CALLS="$TMP/pn-calls-$2" DOOR_MAX_TURNS=10 AI_GROK_PERMISSION_RESUMES=1 \
    AI_GROK_BIN="$STUB_PN" AI_GROK_ALLOW_NO_CREDS=1 DOOR_DIAGNOSTICS_DIR="$TMP/pn-diag-$2" \
    DOOR_MODE=review DOOR_WORKDIR="$MREPO" DOOR_PACKET_DIR="$MREPO" \
    DOOR_PROMPT_FILE="$TMP/impl-prompt.txt" DOOR_REPORT_OUT="$TMP/pn-report-$2.md" \
    DOOR_HEAD="$HEAD_SHA" \
    bash "$GROK_DOOR" review >/dev/null 2>"$TMP/pn-door-$2.err"
  PN_RC=$?
  set -e
}
run_pn_door 0 ok
check "grok_door_resumes_turn_ended_permission_cancelled_without_json" \
  "test '$PN_RC' -eq 0 && grep -q APPROVE '$TMP/pn-report-ok.md' && test \"\$(tr '\n' ' ' < '$TMP/pn-calls-ok')\" = 'first:10 resumed:9 ' && grep -q 'rm -rf .git/review-scratch' '$TMP/pn-door-ok.err'"
run_pn_door 1 persist
check "grok_door_persistent_permission_cancel_is_classified_not_provider_failed" \
  "test '$PN_RC' -eq 1 && test \"\$(tr '\n' ' ' < '$TMP/pn-calls-persist')\" = 'first:10 resumed:9 ' && tail -n 1 '$TMP/pn-diag-persist/report.md' | jq -e '.reason == \"permission-cancelled\"' >/dev/null && ! grep -q 'provider call failed' '$TMP/pn-door-persist.err' && grep -q 'refused a shell command: rm -rf .git/review-scratch' '$TMP/pn-door-persist.err' && grep -q 'refused_step=rm -rf' '$TMP/pn-diag-persist/native.stderr'"
check "lifecycle_maps_permission_cancelled_door_reason" \
  "grep -q 'permission-cancelled) door_failure=permission-cancelled' '$REPO_ROOT/tools/lib/review-lifecycle-core.sh'"
check "preflight_explains_permission_cancelled" \
  "'$REPO_ROOT/bin/ai-review-preflight' explain permission-cancelled 2>/dev/null | grep -q 'unattended permission check'"

# Owner rule "remove the paid fallback": an exported paid key must never reach
# a grok child on review, implement, or the PermissionCancelled resume.
STUB_KEY="$TMP/stub-grok-key"
cat > "$STUB_KEY" <<'STUBEOF'
#!/usr/bin/env bash
resumed=0; for a in "$@"; do [ "$a" = -r ] && resumed=1; done
seen=none
for n in XAI_API_KEY GROK_CODE_XAI_API_KEY GROK_API_KEY XAI_OTHER_FIXTURE; do
  [ -n "${!n+x}" ] && seen="$seen,$n"
done
printf '%s|%s|%s\n' "$KEY_MODE" "$resumed" "$seen" >> "$KEY_CALLS"
case "$*" in *xai-fixture*) echo argv-leak >> "$KEY_CALLS" ;; esac
if [ "$KEY_MODE" = resume ] && [ "$resumed" = 0 ]; then
  mkdir -p "$GROK_HOME/sessions/x/sid-k1"
  printf '%s\n' '{"params": {"sessionId": "sid-k1", "update": {"sessionUpdate": "turn_completed", "prompt_id": "req-1", "stop_reason": "cancelled"}, "_meta": {"cancellationCategory": "PermissionCancelled"}}}' > "$GROK_HOME/sessions/x/sid-k1/updates.jsonl"
  printf '%s\n' '{"text":"","stopReason":"cancelled","num_turns":1,"sessionId":"sid-k1","requestId":"req-1"}'
  exit 0
fi
printf '%s\n' '{"text":"## Verdict\nAPPROVE","stopReason":"end_turn","num_turns":1,"sessionId":"sid-k1","requestId":"req-2","modelUsage":{"grok-4.6-build":{}}}'
STUBEOF
chmod +x "$STUB_KEY"
: > "$TMP/key-calls"
for km in review implement resume; do
  dm=review; [ "$km" = implement ] && dm=implement
  rm -rf "$TMP/key-home-$km"
  set +e
  AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 GROK_HOME="$TMP/key-home-$km" \
    XAI_API_KEY=xai-fixture-exported-key GROK_CODE_XAI_API_KEY=xai-fixture-code \
    GROK_API_KEY=xai-fixture-grok XAI_OTHER_FIXTURE=xai-fixture-other \
    KEY_MODE="$km" KEY_CALLS="$TMP/key-calls" DOOR_MAX_TURNS=10 \
    AI_GROK_BIN="$STUB_KEY" AI_GROK_ALLOW_NO_CREDS=1 \
    DOOR_MODE="$dm" DOOR_WORKDIR="$MREPO" DOOR_PACKET_DIR="$MREPO" \
    DOOR_PROMPT_FILE="$TMP/impl-prompt.txt" DOOR_REPORT_OUT="$TMP/key-report-$km.md" \
    DOOR_HEAD="$HEAD_SHA" \
    bash "$GROK_DOOR" "$dm" >/dev/null 2>"$TMP/key-door-$km.err"
  set -e
done
check "grok_door_review_never_forwards_paid_key" "grep -qx 'review|0|none' '$TMP/key-calls'"
check "grok_door_implement_never_forwards_paid_key" "grep -qx 'implement|0|none' '$TMP/key-calls'"
check "grok_door_permission_resume_never_forwards_paid_key" "grep -qx 'resume|0|none' '$TMP/key-calls' && grep -qx 'resume|1|none' '$TMP/key-calls'"
check "grok_door_every_child_saw_no_paid_key" "test \"\$(wc -l < '$TMP/key-calls')\" -eq 4 && ! grep -q 'none,\\|argv-leak' '$TMP/key-calls'"

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
# #1562: runner-executed test output is authoritative; Windows gets a larger,
# still bounded default timeout. Evaluate the door's real timeout block under a
# faked platform so the default is proven, not only grepped.
check "deepseek_brief_trusts_runner_test_output" \
  "grep -Fq 'was produced by the review runner on the exact head and is authoritative. Do not re-run full test suites' '$DS_DOOR'"
ds_timeout_for() {
  ( _os="$1"; uname() { printf '%s\n' "$_os"; }; unset DOOR_TIMEOUT AI_DEEPSEEK_TIMEOUT; [ -z "${2:-}" ] || export AI_DEEPSEEK_TIMEOUT="$2"
    eval "$(sed -n '/^case "$(uname -s .*in$/,/^DS_TIMEOUT=/p' "$DS_DOOR")"; printf '%s' "$DS_TIMEOUT" )
}
check "deepseek_timeout_default_linux_3600" "[ \"\$(ds_timeout_for Linux)\" = 3600 ]"
check "deepseek_timeout_default_windows_7200" "[ \"\$(ds_timeout_for MINGW64_NT-10.0)\" = 7200 ] && [ \"\$(ds_timeout_for MSYS_NT-10.0)\" = 7200 ]"
check "deepseek_timeout_override_still_wins" "[ \"\$(ds_timeout_for MINGW64_NT-10.0 900)\" = 900 ]"
check "deepseek_timeout_stays_bounded" "grep -Fq -- '--timeout-seconds \"\$DS_TIMEOUT\"' '$DS_DOOR' && grep -Fq -- '-- timeout \"\$DS_TIMEOUT\"' '$DS_DOOR'"
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
# #1427: ai-review strips generic pay-per-use keys before dispatch.
cat > "$TMP/stub-pool-env" <<EOF
#!/usr/bin/env bash
env > "$TMP/stub-pool-env.log"
exit 0
EOF
chmod +x "$TMP/stub-pool-env"; rm -f "$TMP/stub-pool-env.log"
set +e
( cd "$PREPO" && export OPENAI_API_KEY=fake-1427 CODEX_API_KEY=fake-1427 GEMINI_API_KEY=fake-1427 GOOGLE_API_KEY=fake-1427 \
    AI_GEMINI_KEY=fake-1427 AI_QWEN_KEY=fake-1427 ANTHROPIC_API_KEY=fake-1427 && AI_POOL_TEST_HOOKS=1 AI_REVIEW_POOL_BIN="$TMP/stub-pool-env" \
    AI_POOL_CALLER=codex bash "$FRONT" deepseek diff-review ) >"$TMP/front-keys.out" 2>"$TMP/front-keys.err"
set -e
check "ai_review_strips_generic_keys" \
  "test -s '$TMP/stub-pool-env.log' && ! grep -q 'fake-1427' '$TMP/stub-pool-env.log'"
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
# Same directory can appear as MSYS $PWD (C:/...) and cygpath -w (C:\...).
# Workdir identity must compare resolved paths, not raw path spellings.
PATH_ID_SH="$TMP/path_id.sh"
cat > "$PATH_ID_SH" <<'PID'
path_id() {
  # Collapse Windows backslashes so MSYS C:/... and cygpath -w C:\... compare
  # equal; Linux paths have no backslashes and pass through unchanged.
  python3 -c 'import sys; print(sys.argv[1].replace("\\", "/"), end="")' "$1"
}
PID
. "$PATH_ID_SH"

STUB_OC="$TMP/stub-opencode"
cat > "$STUB_OC" <<EOF
#!/usr/bin/env bash
# Offline stub OpenCode: accepts the door's run contract and emits JSONL.
. "$PATH_ID_SH" || exit 1
if [ -n "\${DS_STUB_PROFILE_OUT:-}" ]; then
  env | grep '^OPENCODE_DISABLE_' | sort > "\$DS_STUB_PROFILE_OUT"
  cp "\$XDG_CONFIG_HOME/opencode/AGENTS.md" "\$DS_STUB_PROFILE_OUT.rules" 2>/dev/null || true
fi
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
prompt="\$(cat)"
if [ "\${DS_TEST_RUN_UNITTEST:-0}" = 1 ]; then
  # Model the native engine following MANIFEST's original directory unless
  # the final trusted instruction explicitly binds its execution workspace.
  original="\$(sed -n 's/^Directory you are reading: //p' "\$DS_TEST_MANIFEST")"
  selected="\$(printf '%s\\n' "\$prompt" | sed -n 's/^Trusted execution workspace: //p' | tail -1)"
  target="\${selected:-\$original}"
  test "\$(path_id "\$target")" = "\$(path_id "\$dir")" || exit 1
  printf '%s\\n' "\$prompt" | grep -q 'Original MANIFEST snapshot paths are immutable provenance only' || exit 1
  # Exercise inherited process cwd, not merely the advertised --dir option.
  printf '%s' "\$PWD" > "\$DS_TEST_DIR_RECORD"
  test "\$(path_id "\$PWD")" = "\$(path_id "\$dir")" || exit 1
  cd "\$target" || exit 1
  # Force bytecode even when the caller's environment suppresses or redirects
  # it (edge-dev3 exports PYTHONDONTWRITEBYTECODE=1), so the immutability
  # check below always faces real __pycache__ writes.
  env -u PYTHONDONTWRITEBYTECODE -u PYTHONPYCACHEPREFIX python3 -m unittest test_allocation.py >&2 || exit 1
  test -d __pycache__ || exit 1
fi
if [ -n "\${DS_JSONL:-}" ]; then cat "\$DS_JSONL"; exit 0; fi
cat <<'JSON'
{"type":"sessionID","sessionID":"stub-session-1"}
{"type":"text","part":{"text":"I read the evidence packet and every changed hunk against the stated intent. The lock release path is correct, the digest is recomputed at the terminal transition, and no path writes outside managed storage. The scoreboard append is checked and an accounting failure keeps the lock for recovery rather than reporting success. Sibling issues of the same class were checked across the module and none remain. No blocking findings in this change set."}}
{"type":"tool_use","part":{"state":{"status":"ok"}}}
{"type":"text","part":{"text":"## Verdict\nAPPROVE"}}
JSON
EOF
chmod 0700 "$STUB_OC"

DS_REPORT="$TMP/ds-stub-report.md"
set +e
AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 \
  AI_DEEPSEEK_OPENCODE="$STUB_OC" AI_DEEPSEEK_ALLOW_NO_CREDS=1 DS_STUB_PROFILE_OUT="$TMP/ds-stub-profile" \
  DOOR_MODE=review DOOR_WORKDIR="$MREPO" DOOR_PACKET_DIR="$MREPO" \
  DOOR_PROMPT_FILE="$TMP/impl-prompt.txt" DOOR_REPORT_OUT="$DS_REPORT" \
  DOOR_HEAD="$HEAD_SHA" \
  bash "$DS_DOOR" review >"$TMP/ds-stub-door.out" 2>"$TMP/ds-stub-door.err"
DS_STUB_RC=$?
set -e
# #1881: a DeepSeek review sees only the reviewer rules, never the owner's
# ~/.claude/CLAUDE.md or the ~/.claude and ~/.agents skill lists.
check "deepseek_review_loads_only_reviewer_rules" \
  "cmp -s '$REPO_ROOT/templates/system/REVIEWER-global.md' '$TMP/ds-stub-profile.rules' && printf 'OPENCODE_DISABLE_CLAUDE_CODE=1\nOPENCODE_DISABLE_EXTERNAL_SKILLS=1\n' | cmp -s - '$TMP/ds-stub-profile'"
check "deepseek_door_parses_opencode_envelope_to_report_shape" \
  "test '$DS_STUB_RC' -eq 0 && grep -q '## Verdict' '$DS_REPORT'"
check "deepseek_door_report_carries_opencode_metadata" \
  "grep -q 'opencode' '$DS_REPORT' && grep -q 'deepseek-api/deepseek-flash' '$DS_REPORT'"
check "deepseek_door_report_binds_reviewed_head" "grep -q '$HEAD_SHA' '$DS_REPORT'"
check "deepseek_door_requires_runner_token_even_with_stub" \
  "! (unset AI_REVIEW_RUNNER_CORE; AI_DEEPSEEK_OPENCODE='$STUB_OC' AI_DEEPSEEK_ALLOW_NO_CREDS=1 DOOR_MODE=review DOOR_WORKDIR='$MREPO' DOOR_PACKET_DIR='$MREPO' DOOR_PROMPT_FILE='$TMP/impl-prompt.txt' DOOR_REPORT_OUT='$TMP/ds-x.md' DOOR_HEAD='$HEAD_SHA' bash '$DS_DOOR' review) 2>/dev/null"

for broken_event in '{invalid-json' '[]'; do
  bad_id="${bad_id:-0}"; bad_id=$((bad_id + 1))
  printf '%s\n' '{"type":"text","part":{"text":"## Verdict\nAPPROVE"}}' "$broken_event" > "$TMP/ds-invalid-$bad_id.jsonl"
  bad_rc=0
  DS_JSONL="$TMP/ds-invalid-$bad_id.jsonl" AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 \
    AI_DEEPSEEK_OPENCODE="$STUB_OC" AI_DEEPSEEK_ALLOW_NO_CREDS=1 \
    DOOR_WORKDIR="$MREPO" DOOR_PACKET_DIR="$MREPO" DOOR_PROMPT_FILE="$TMP/impl-prompt.txt" \
    DOOR_REPORT_OUT="$TMP/ds-invalid-$bad_id.md" DOOR_DIAGNOSTICS_DIR="$TMP/ds-invalid-$bad_id.private" \
    DOOR_HEAD="$HEAD_SHA" bash "$DS_DOOR" review > "$TMP/ds-invalid-$bad_id.out" 2>&1 || bad_rc=$?
  check "deepseek_invalid_native_event_${bad_id}_never_accepts_prior_approval" \
    "test '$bad_rc' -ne 0 && grep -q invalid-response-json '$TMP/ds-invalid-$bad_id.private/report.md' && ! grep -q '^APPROVE$' '$TMP/ds-invalid-$bad_id.md'"
done
# Real Python test execution creates bytecode. It belongs in the door's own
# scratch workspace, never the runner's immutable source snapshot.
DS_ARTIFACT_SOURCE="$TMP/artifact-source"
cp -a "$MREPO" "$DS_ARTIFACT_SOURCE"
cat > "$DS_ARTIFACT_SOURCE/test_allocation.py" <<'PY'
import unittest
class AllocationTest(unittest.TestCase):
    def test_example(self): self.assertEqual(2 + 2, 4)
PY
printf 'Directory you are reading: %s\n' "$DS_ARTIFACT_SOURCE" > "$DS_ARTIFACT_SOURCE/MANIFEST.md"
DS_ARTIFACT_DIGEST="$($REPO_ROOT/bin/ai-review-sandbox digest "$DS_ARTIFACT_SOURCE")"
DS_ARTIFACT_RC=0
# Regression: an ambient bytecode-suppressing environment must not break the
# fixture on any machine; pin it here so every run exercises that hazard.
PYTHONDONTWRITEBYTECODE=1 PYTHONPYCACHEPREFIX="$TMP/ds-pycache-prefix" \
DS_TEST_RUN_UNITTEST=1 DS_TEST_MANIFEST="$DS_ARTIFACT_SOURCE/MANIFEST.md" DS_TEST_DIR_RECORD="$TMP/ds-artifact-dir" \
  AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 AI_DEEPSEEK_OPENCODE="$STUB_OC" \
  AI_DEEPSEEK_ALLOW_NO_CREDS=1 DOOR_MODE=review DOOR_WORKDIR="$DS_ARTIFACT_SOURCE" \
  DOOR_PACKET_DIR="$DS_ARTIFACT_SOURCE" DOOR_PROMPT_FILE="$TMP/impl-prompt.txt" \
  DOOR_REPORT_OUT="$TMP/ds-artifact-report" DOOR_HEAD="$HEAD_SHA" \
  bash "$DS_DOOR" review >"$TMP/ds-artifact-out" 2>"$TMP/ds-artifact-err" || DS_ARTIFACT_RC=$?
DS_ARTIFACT_AFTER="$($REPO_ROOT/bin/ai-review-sandbox digest "$DS_ARTIFACT_SOURCE")"
DS_ACTUAL_WORKDIR="$(cat "$TMP/ds-artifact-dir" 2>/dev/null || true)"
check "deepseek_real_unittest_keeps_immutable_snapshot_digest" \
  "test '$DS_ARTIFACT_RC' -eq 0 && test '$DS_ARTIFACT_DIGEST' = '$DS_ARTIFACT_AFTER' && test ! -d '$DS_ARTIFACT_SOURCE/__pycache__'"
check "deepseek_tests_run_in_owned_scratch_and_remove_it" \
  "test -n '$DS_ACTUAL_WORKDIR' && test '$DS_ACTUAL_WORKDIR' != '$DS_ARTIFACT_SOURCE' && test ! -e '$DS_ACTUAL_WORKDIR'"
# Adversarial: equivalent Windows spellings are the same workdir; a different
# directory is never accepted. Guards against loosening workdir identity into
# a raw-string mismatch or a prefix/any-path match.
check "deepseek_workdir_identity_matches_equivalent_path_spellings" \
  "test \"\$(path_id 'C:/Users/x/work')\" = \"\$(path_id 'C:\\Users\\x\\work')\""
check "deepseek_workdir_identity_rejects_different_directory" \
  "test \"\$(path_id 'C:/Users/x/work')\" != \"\$(path_id 'C:/Users/x/other')\" && test \"\$(path_id 'C:/Users/x/work')\" != \"\$(path_id 'C:/Users/x/work/child')\""

# The grep presence check must not close the JSONL text producer early under
# pipefail. Exercise a large multi-event report and retain all fail-closed
# report shapes through the same existing OpenCode door fixture.
python3 - "$TMP/ds-large.jsonl" <<'PY'
import json, sys
with open(sys.argv[1], "w", encoding="utf-8") as f:
    f.write(json.dumps({"type":"text", "part":{"text":"## Verdict\nPROVISIONAL"}}) + "\n")
    long_evidence = "Later multiline review evidence. " + ("x" * 120 + "\n") * 2500
    f.write(json.dumps({"type":"text", "part":{"text":long_evidence}}) + "\n")
    f.write(json.dumps({"type":"tool_use", "part":{"state":{"status":"ok"}}}) + "\n")
    f.write(json.dumps({"type":"text", "part":{"text":"## Verdict\nAPPROVE"}}) + "\n")
PY
DS_LARGE_REPORT="$TMP/ds-large-report.md"
DS_LARGE_RC=0
DS_JSONL="$TMP/ds-large.jsonl" AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 \
  AI_DEEPSEEK_OPENCODE="$STUB_OC" AI_DEEPSEEK_ALLOW_NO_CREDS=1 \
  DOOR_MODE=review DOOR_WORKDIR="$MREPO" DOOR_PACKET_DIR="$MREPO" \
  DOOR_PROMPT_FILE="$TMP/impl-prompt.txt" DOOR_REPORT_OUT="$DS_LARGE_REPORT" \
  DOOR_HEAD="$HEAD_SHA" bash "$DS_DOOR" review || DS_LARGE_RC=$?
check "deepseek_large_multievent_report_keeps_exact_head_and_approve" \
  "test '$DS_LARGE_RC' -eq 0 && grep -q '$HEAD_SHA' '$DS_LARGE_REPORT' && tail -2 '$DS_LARGE_REPORT' | grep -qx APPROVE && ! grep -q '^BLOCKED$' '$DS_LARGE_REPORT'"

printf '%s\n' '{"type":"text","part":{"text":"## Verdict\nREJECT"}}' > "$TMP/ds-reject.jsonl"
DS_REJECT_REPORT="$TMP/ds-reject-report.md"
DS_REJECT_RC=0
DS_JSONL="$TMP/ds-reject.jsonl" AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 \
  AI_DEEPSEEK_OPENCODE="$STUB_OC" AI_DEEPSEEK_ALLOW_NO_CREDS=1 \
  DOOR_MODE=review DOOR_WORKDIR="$MREPO" DOOR_PACKET_DIR="$MREPO" \
  DOOR_PROMPT_FILE="$TMP/impl-prompt.txt" DOOR_REPORT_OUT="$DS_REJECT_REPORT" \
  DOOR_HEAD="$HEAD_SHA" bash "$DS_DOOR" review || DS_REJECT_RC=$?
check "deepseek_short_reject_is_preserved" \
  "test '$DS_REJECT_RC' -eq 0 && tail -2 '$DS_REJECT_REPORT' | grep -qx REJECT"

printf '%s\n' '{"type":"text","part":{"text":"No final verdict."}}' > "$TMP/ds-missing-verdict.jsonl"
DS_MISSING_REPORT="$TMP/ds-missing-report.md"
DS_MISSING_RC=0
DS_JSONL="$TMP/ds-missing-verdict.jsonl" AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 \
  AI_DEEPSEEK_OPENCODE="$STUB_OC" AI_DEEPSEEK_ALLOW_NO_CREDS=1 \
  DOOR_MODE=review DOOR_WORKDIR="$MREPO" DOOR_PACKET_DIR="$MREPO" \
  DOOR_PROMPT_FILE="$TMP/impl-prompt.txt" DOOR_REPORT_OUT="$DS_MISSING_REPORT" \
  DOOR_HEAD="$HEAD_SHA" bash "$DS_DOOR" review || DS_MISSING_RC=$?
check "deepseek_absent_verdict_still_becomes_blocked" \
  "test '$DS_MISSING_RC' -eq 0 && tail -2 '$DS_MISSING_REPORT' | grep -qx BLOCKED"

printf '## Verdict\nMAYBE\n' > "$TMP/ds-malformed-report.md"
check "lifecycle_validator_rejects_nonfinal_deepseek_verdict" \
  "! (source '$CORE'; rlc_parse_verdict '$TMP/ds-malformed-report.md') >/dev/null 2>&1"

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

# A native error is a failed invocation even if an earlier text part looks
# like approval. Exact raw evidence survives temp cleanup, but no model or
# secret text is echoed into the diagnostic summary.
cat > "$TMP/ds-native-error.jsonl" <<'JSON'
{"type":"text","part":{"text":"## Verdict\nAPPROVE"}}
{"type":"error","error":{"data":{"statusCode":503,"message":"synthetic-secret-should-stay-private"}}}
JSON
DS_FAILED_RC=0
( cd "$MREPO" && DS_JSONL="$TMP/ds-native-error.jsonl" \
  AI_DEEPSEEK_OPENCODE="$STUB_OC" AI_DEEPSEEK_ALLOW_NO_CREDS=1 \
  AI_REVIEW_DOOR_DEEPSEEK="$DS_DOOR" \
  "$ENGINE" review --provider deepseek --name engine-ds-native-error --repo "$MREPO" \
  --mode diff-review --caller codex ) >"$TMP/ds-failed.out" 2>"$TMP/ds-failed.err" || DS_FAILED_RC=$?
check "deepseek_native_error_never_authorizes_earlier_approval" "test '$DS_FAILED_RC' -ne 0"
DS_FAILED_STATE="$(find "$AI_REVIEW_LIFECYCLE_DIR/runs" -name engine-ds-native-error.json | head -1)"
# Lifecycle IDs are generated; select the failed DeepSeek state by verdict.
DS_FAILED_STATE="$(python3 - "$AI_REVIEW_LIFECYCLE_DIR/runs" <<'PY'
import json, pathlib, sys
for p in pathlib.Path(sys.argv[1]).rglob('*.json'):
    try: d = json.loads(p.read_text())
    except ValueError: continue
    if d.get('provider') == 'deepseek' and d.get('failure_class') == 'provider-native-error':
        print(p); break
PY
)"
DS_FAILED_REPORT="$(jq -r '.report_path // empty' "$DS_FAILED_STATE" 2>/dev/null || true)"
check "deepseek_failed_lifecycle_keeps_durable_nonempty_diagnostic" \
  "test -s '$DS_FAILED_REPORT' && grep -q native-error-envelope '$DS_FAILED_REPORT' && grep -q 503 '$DS_FAILED_REPORT'"
check "deepseek_diagnostic_summary_excludes_provider_text" \
  "! grep -q synthetic-secret-should-stay-private '$DS_FAILED_REPORT'"
check "deepseek_private_native_failure_retains_exact_bytes" \
  "cmp '$TMP/ds-native-error.jsonl' '${DS_FAILED_REPORT%/*}/native.jsonl'"
check "deepseek_private_diagnostic_permissions" \
  "test \"\$(stat -c %a '${DS_FAILED_REPORT%/*}' 2>/dev/null)\" = 700 && test \"\$(stat -c %a '$DS_FAILED_REPORT' 2>/dev/null)\" = 600"

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

# Both native engines cross the same secret-file / clean-environment boundary.
muse_boundary_offline() {
  local engine="$1" dir="$TMP/muse-boundary-$1" result rc
  mkdir -p "$dir/work" "$dir/packet"
  printf 'review fixture' > "$dir/prompt"
  cat > "$dir/provider" <<'FIXTURE'
#!/usr/bin/env bash
# Only fake sentinels enter this process; inspect names, never dump values.
case "$*" in *fake-native-provider*|*fake-foreign*) exit 78;; esac
for name in STEPFUN_API_KEY SUPABASE_ACCESS_TOKEN SUPABASE_SERVICE_ROLE_KEY TRIGGER_ACCESS_TOKEN TRIGGER_SECRET_KEY TYPESAFE_API_KEY ZAI_API_KEY ARBITRARY_CALLER_SECRET AI_MUSE_KEY AI_MUSE_SECRET_FILE AI_MUSE_KEY_ENV AI_MUSE_TEST_DIR MUSE_STUB_SECRET; do
  [ -z "${!name+x}" ] || exit 73
done
/usr/bin/bash --noprofile --norc -c 'for name in STEPFUN_API_KEY SUPABASE_ACCESS_TOKEN SUPABASE_SERVICE_ROLE_KEY TRIGGER_ACCESS_TOKEN TRIGGER_SECRET_KEY TYPESAFE_API_KEY ZAI_API_KEY ARBITRARY_CALLER_SECRET; do [ -z "${!name+x}" ] || exit 77; done' || exit 77
case "$1" in
  exec) prior=''; prompt_file=''; for arg in "$@"; do [ "$prior" != --prompt-file ] || prompt_file="$arg"; prior="$arg"; done
    grep -qF 'Repository tool-read root is the actual current directory (.)' "$prompt_file" || exit 79
    grep -qF 'provenance metadata only; never read or retry those host paths' "$prompt_file" || exit 79
    [ "${META_API_KEY:-}" = fake-native-provider ] && [ -z "${MODEL_API_KEY+x}" ] || exit 74
    printf '%s\n' '{"payload_type":"run.terminal.completed","payload":{"terminal":"completed","text":"## Verdict\nAPPROVE"}}';;
  run) [ "${MODEL_API_KEY:-}" = fake-native-provider ] && [ -z "${META_API_KEY+x}" ] || exit 75
    # #1881: only the reviewer rules, never the owner's CLAUDE.md or user skills.
    head -1 "$XDG_CONFIG_HOME/opencode/AGENTS.md" | grep -qx '# Reviewer instructions' || exit 80
    [ "${OPENCODE_DISABLE_CLAUDE_CODE:-}" = 1 ] && [ "${OPENCODE_DISABLE_EXTERNAL_SKILLS:-}" = 1 ] || exit 80
    prompt_text="$(cat)"
    printf '%s' "$prompt_text" | grep -qF 'Repository tool-read root is the actual current directory (.)' || exit 79
    printf '%s' "$prompt_text" | grep -qF 'provenance metadata only; never read or retry those host paths' || exit 79
    printf '%s\n' '{"type":"text","part":{"text":"## Verdict\nAPPROVE"}}';;
  *) exit 76;;
esac
FIXTURE
  chmod 700 "$dir/provider"
  env -i PATH="$PATH" HOME="$dir" AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 \
    DOOR_WORKDIR="$dir/work" DOOR_PACKET_DIR="$dir/packet" DOOR_PROMPT_FILE="$dir/prompt" DOOR_REPORT_OUT="$dir/report" DOOR_HEAD=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa DOOR_TIMEOUT=10 \
    AI_MUSE_ENGINE="$engine" AI_MUSE_BIN="$dir/provider" AI_MUSE_OPENCODE="$dir/provider" AI_MUSE_KEY=fake-native-provider \
    STEPFUN_API_KEY=fake-foreign SUPABASE_ACCESS_TOKEN=fake-foreign SUPABASE_SERVICE_ROLE_KEY=fake-foreign TRIGGER_ACCESS_TOKEN=fake-foreign TRIGGER_SECRET_KEY=fake-foreign TYPESAFE_API_KEY=fake-foreign ZAI_API_KEY=fake-foreign ARBITRARY_CALLER_SECRET=fake-foreign AI_MUSE_TEST_DIR=fake-test-path MUSE_STUB_SECRET=fake-foreign \
    bash "$MUSE_DOOR" review >"$dir/stdout" 2>"$dir/stderr" || return 1
  grep -q APPROVE "$dir/report" && ! grep -rq 'fake-native-provider\|fake-foreign' "$dir/report" "$dir/stdout" "$dir/stderr"
}
for engine in muse-code opencode; do
  if muse_boundary_offline "$engine"; then PASS=$((PASS+1)); printf 'PASS native %s clean credential boundary\n' "$engine"; else FAIL=$((FAIL+1)); printf 'FAIL native %s clean credential boundary\n' "$engine"; fi
done

# The shared boundary refuses linked handoffs and consumes private files before exec.
set +e
(
  . "$REPO_ROOT/tools/lib/muse-credential-boundary.sh"
  printf 'fake-boundary-key\n' > "$TMP/boundary-key"; chmod 600 "$TMP/boundary-key"
  ln -s "$TMP/boundary-key" "$TMP/boundary-link"
  env -i AI_MUSE_SECRET_FILE="$TMP/boundary-link" /usr/bin/bash --noprofile --norc -c "$MUSE_CREDENTIAL_BOUNDARY" fixture /usr/bin/true
) >/dev/null 2>"$TMP/boundary-refusal.err"
rc=$?
if [ "$rc" = 86 ] && [ -f "$TMP/boundary-key" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
(
  . "$REPO_ROOT/tools/lib/muse-credential-boundary.sh"
  env -i AI_MUSE_SECRET_FILE="$TMP/boundary-key" /usr/bin/bash --noprofile --norc -c "$MUSE_CREDENTIAL_BOUNDARY" fixture /usr/bin/false
) >/dev/null 2>"$TMP/boundary-provider-failure.err"
rc=$?
if [ "$rc" = 1 ] && [ ! -e "$TMP/boundary-key" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi

set -e

# First installation can explicitly use the existing attachment API when no
# provider executable is installed. Fixtures never call a provider or read keys.
ds_without_runtime() {
  (
    unset AI_DEEPSEEK_OPENCODE AI_DEEPSEEK_ENGINE
    export HOME="$TMP/no-opencode-home" USERPROFILE=''
    mkdir -p "$HOME"
    command() {
      if [ "$#" = 2 ] && [ "$1" = -v ] && [ "$2" = opencode ]; then return 1; fi
      builtin command "$@"
    }
    export -f command
    "$@"
  )
}
ds_missing_runtime() {
  local rc=0
  ds_without_runtime env AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 \
    DOOR_WORKDIR="$MREPO" DOOR_PACKET_DIR="$MREPO" DOOR_PROMPT_FILE="$TMP/impl-prompt.txt" \
    DOOR_REPORT_OUT="$TMP/missing-runtime-report.md" DOOR_HEAD="$HEAD_SHA" \
    DOOR_DIAGNOSTICS_DIR="$TMP/missing-runtime-native" \
    bash "$DEEPSEEK_DOOR" review > "$TMP/missing-runtime.out" 2> "$TMP/missing-runtime.err" || rc=$?
  [ "$rc" = 127 ] && grep -q 'local OpenCode dependency unavailable' "$TMP/missing-runtime.err" &&
    grep -q 'local-dependency-unavailable' "$TMP/missing-runtime-report.md"
}
check 'ordinary_deepseek_door_refuses_the_same_missing_runtime_as_readiness' 'ds_missing_runtime'
grok_missing_runtime() {
  (
    unset AI_GROK_BIN
    export HOME="$TMP/no-grok-home"
    mkdir -p "$HOME"
    command() {
      if [ "$#" = 2 ] && [ "$1" = -v ] && [ "$2" = grok ]; then return 1; fi
      builtin command "$@"
    }
    function [() {
      if builtin [ "$#" = 3 ] && builtin [ "$1" = -x ]; then
        case "$2" in /home/ai/.local/bin/grok|/usr/local/bin/grok) return 1;; esac
      fi
      builtin [ "$@"
    }
    export -f command '['
    local rc=0
    AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 DOOR_WORKDIR="$MREPO" \
      DOOR_PACKET_DIR="$MREPO" DOOR_PROMPT_FILE="$TMP/impl-prompt.txt" \
      DOOR_REPORT_OUT="$TMP/grok-missing-runtime.md" DOOR_HEAD="$HEAD_SHA" \
      bash "$GROK_DOOR" review > "$TMP/grok-missing-runtime.out" 2> "$TMP/grok-missing-runtime.err" || rc=$?
    [ "$rc" = 127 ] && grep -q 'local_dependency_unavailable: grok binary not found' "$TMP/grok-missing-runtime.err"
  )
}
check 'ordinary_grok_door_refuses_the_same_missing_runtime_as_readiness' 'grok_missing_runtime'
DS_API_ROOT="$TMP/ds-api"
mkdir -p "$DS_API_ROOT/tools/lib/review-doors" "$DS_API_ROOT/bin" "$DS_API_ROOT/config/opencode" "$DS_API_ROOT/config/opencode-deepseek"
cp "$DEEPSEEK_DOOR" "$DS_API_ROOT/tools/lib/review-doors/deepseek.sh"
cp "$REPO_ROOT/tools/lib/deepseek-opencode.sh" "$DS_API_ROOT/tools/lib/deepseek-opencode.sh"
cp "$REPO_ROOT/tools/lib/reviewer-instructions.sh" "$DS_API_ROOT/tools/lib/reviewer-instructions.sh"
: > "$DS_API_ROOT/tools/reviewer_event_guard.sh"
printf 'fixture\n' > "$DS_API_ROOT/config/opencode/version"
sed -n '/^review_verdict() {/,/^take_governed_head()/p' "$REPO_ROOT/bin/ai-deepseek-agent" | sed '$d' > "$DS_API_ROOT/validator"
cat > "$DS_API_ROOT/bin/ai-deepseek-agent" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$DS_API_ARGS"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --file) cat "$2" >> "$DS_API_ARGS"; shift ;;
    --governed-verdict) printf 'Wrong terminal contract\n' >&2; exit 2 ;;
  esac
  shift
done
case "${DS_API_RESULT:-approve}" in
  missing-operation) reply=$(printf 'Reviewed %s\n## Verdict\nAPPROVE\n' "$DOOR_HEAD") ;;
  wrong-head) reply=$(printf 'Reviewed wrong\nApproved first-managed-install.\n## Verdict\nAPPROVE\n') ;;
  malformed) reply=$(printf 'Reviewed %s\nApproved first-managed-install.\n## Verdict\nAPPROVE\ntrailing text\n' "$DOOR_HEAD") ;;
  reject) reply=$(printf 'Reviewed %s\n## Verdict\nREJECT\n' "$DOOR_HEAD") ;;
  failure) exit 92 ;;
  *) reply=$(printf 'Reviewed %s\nApproved first-managed-install.\n## Verdict\nAPPROVE\n' "$DOOR_HEAD") ;;
esac
# Reuse the real API agent validator, rather than inventing a fixture grammar.
. "$DS_API_VALIDATOR"
PYTHON=python3; GOVERNED_HEAD=''
review_verdict "$reply" >/dev/null || exit 1
printf '%s\n' "$reply"
EOF
chmod +x "$DS_API_ROOT/bin/ai-deepseek-agent"
git init -q "$DS_API_ROOT/source"
printf 'untrusted tracked source\n' > "$DS_API_ROOT/source/installation.sh"
git -C "$DS_API_ROOT/source" add installation.sh
printf 'Final check of source installation.\n' > "$DS_API_ROOT/prompt"
ds_api_case() {
  local engine="$1" operation="$2" contract="$3" result="$4"
  rm -f "$DS_API_ROOT/args" "$DS_API_ROOT/report"
  AI_REVIEW_RUNNER_CORE=review-lifecycle-core/1 AI_DEEPSEEK_ENGINE="$engine" \
    DOOR_OPERATION="$operation" DOOR_REVIEW_MODE="${DS_API_REVIEW_MODE:-final-check}" DOOR_MODE="$contract" DOOR_WORKDIR="$DS_API_ROOT/source" \
    DOOR_PACKET_DIR="$DS_API_ROOT" DOOR_PROMPT_FILE="$DS_API_ROOT/prompt" \
    DOOR_REPORT_OUT="$DS_API_ROOT/report" DOOR_HEAD=1111111111111111111111111111111111111111 \
    DS_API_RESULT="$result" DS_API_ARGS="$DS_API_ROOT/args" DS_API_VALIDATOR="$DS_API_ROOT/validator" \
    bash "$DS_API_ROOT/tools/lib/review-doors/deepseek.sh" "$contract" > "$DS_API_ROOT/stdout" 2> "$DS_API_ROOT/stderr"
}
check 'attachment_api_approves_exact_native_head_and_inventory' \
  "ds_without_runtime ds_api_case attachment-api first-managed-install review approve && grep -q 'installation.sh' '$DS_API_ROOT/args' && grep -q -- '--assert-head' '$DS_API_ROOT/args' && grep -q '^APPROVE$' '$DS_API_ROOT/report'"
check 'attachment_api_refuses_other_operation_before_provider' \
  "! ds_api_case attachment-api legacy-managed-launcher-refresh review approve && ! test -e '$DS_API_ROOT/args'"
check 'attachment_api_refuses_ordinary_review_before_provider' \
  "! ds_api_case attachment-api '' review approve && ! test -e '$DS_API_ROOT/args'"
check 'attachment_api_refuses_other_review_mode_before_provider' \
  "DS_API_REVIEW_MODE=diff-review; ! ds_api_case attachment-api first-managed-install review approve && ! test -e '$DS_API_ROOT/args'; unset DS_API_REVIEW_MODE"
check 'attachment_api_refuses_implementation_before_provider' \
  "! ds_api_case attachment-api first-managed-install implement approve && ! test -e '$DS_API_ROOT/args'"
check 'attachment_api_refuses_wrong_terminal_head' \
  "! ds_api_case attachment-api first-managed-install review wrong-head && ! test -s '$DS_API_ROOT/report'"
check 'attachment_api_uses_real_ordinary_terminal_contract' \
  "! ds_api_case attachment-api first-managed-install review malformed && ! test -s '$DS_API_ROOT/report'"
check 'attachment_api_refuses_missing_operation_approval' \
  "! ds_api_case attachment-api first-managed-install review missing-operation && ! test -s '$DS_API_ROOT/report'"
check 'attachment_api_preserves_provider_rejection' \
  "ds_api_case attachment-api first-managed-install review reject && grep -q '^REJECT$' '$DS_API_ROOT/report'"
check 'attachment_api_preserves_credit_exit' \
  "ds_api_case attachment-api first-managed-install review failure; test \"\$?\" = 92"
check 'attachment_api_refuses_unknown_engine_before_provider' \
  "! ds_api_case invented first-managed-install review approve && ! test -e '$DS_API_ROOT/args'"

# --- closing report rules and the production-risk block (#1783) -----------
echo '== closing report rules'
RISK_DOOR="$TMP/risk-door.sh"
cat > "$RISK_DOOR" <<'EOF'
#!/usr/bin/env bash
[ "${AI_REVIEW_RUNNER_CORE:-}" = "review-lifecycle-core/1" ] || exit 2
cp "$DOOR_PROMPT_FILE" "$RISK_BRIEF_COPY"
{
  printf 'Reviewed head %s. ' "$DOOR_HEAD"
  for i in $(seq 1 40); do printf 'The change is additive and every path was checked line by line. '; done
  printf '\n'
  if [ "${RISK_WITH_BLOCK:-0}" = 1 ]; then printf '```production-risk-assessment\n{"schema":"x"}\n```\n'; fi
  printf '\n## Verdict\nAPPROVE\n'
} > "$DOOR_REPORT_OUT"
EOF
chmod +x "$RISK_DOOR"
printf 'Include exactly one fenced production-risk-assessment block if you approve.\n' > "$TMP/risk-request.md"
risk_case() { # risk_case WITH_BLOCK TAG -> exit status of the review
  rm -f "$AI_REVIEW_LIFECYCLE_DIR/runs"/* 2>/dev/null || true
  ( cd "$MREPO" && timeout 90 env AI_REVIEW_DOOR_GROK="$RISK_DOOR" RISK_WITH_BLOCK="$1" RISK_BRIEF_COPY="$TMP/risk-brief-$2.md" \
      "$ENGINE" review --provider grok --name "engine-risk-$2" --repo "$MREPO" --mode diff-review --caller codex \
      --prompt-file "$TMP/risk-request.md" ) >"$TMP/risk-$2.out" 2>"$TMP/risk-$2.err"
}
set +e; risk_case 0 missing; RISK_MISSING_RC=$?; risk_case 1 present; RISK_PRESENT_RC=$?; set -e
check "approval_without_requested_risk_block_is_refused" \
  "test '$RISK_MISSING_RC' -ne 0 && grep -q 'production-risk-assessment block' '$TMP/risk-missing.err'"
check "approval_with_requested_risk_block_is_accepted" "test '$RISK_PRESENT_RC' -eq 0"
check "brief_ends_with_single_decision_rule" \
  "grep -q 'Do not give an early, provisional or second decision' '$TMP/risk-brief-present.md' && test \"\$(grep -n 'Report rules' '$TMP/risk-brief-present.md' | cut -d: -f1)\" -gt \"\$(grep -n 'fenced production-risk-assessment block if you approve' '$TMP/risk-brief-present.md' | cut -d: -f1)\""
check "brief_restates_risk_block_rule_when_requested" "grep -q 'MUST contain exactly one fenced block' '$TMP/risk-brief-present.md'"
check "brief_says_missing_tool_is_not_blocked" "grep -q 'is not by itself grounds for BLOCKED' '$TMP/risk-brief-present.md'"

# --- per-session skip and --detach at the front door (plan_reviewer-observation-week steps 2-3)
echo '== per-session skip and detached reviews'
FRONT="$REPO_ROOT/bin/ai-review"
OW="$TMP/observation-week"; mkdir -p "$OW"
export AI_REVIEW_SESSION_SKIP_DIR="$OW/skip" AI_REVIEW_DETACH_DIR="$OW/detached"
OW_POOL="$OW/pool-stub"
cat > "$OW_POOL" <<'EOF'
#!/usr/bin/env bash
# Stands in for ai-review-pool: records what the front door handed it.
printf '%s\n' "$*" >> "$OW_POOL_LOG"
[ -z "${AI_REVIEW_DETACH_ID:-}" ] || sleep 3
d="$AI_REVIEW_LIFECYCLE_DIR/runs/k/$1/c"; mkdir -p "$d" "$(dirname "$AI_REVIEW_SCOREBOARD_FILE")"
rep="$OW_DIR/report-${AI_REVIEW_DETACH_ID:-sync}.md"
printf 'Analysis.\n## Verdict\nAPPROVE\n' > "$rep"
jq -n --arg id "${AI_REVIEW_DETACH_ID:-}" --arg r "$rep" --arg s "$AI_CALLER_SESSION_ID" \
  '{status:"completed",verdict:"APPROVE",report_path:$r,detach_id:(if $id=="" then null else $id end),caller_session_id:$s}' > "$d/run-${AI_REVIEW_DETACH_ID:-sync}.json"
printf '{"provider":"%s","detach_id":"%s","caller_session_id":"%s"}\n' "$1" "${AI_REVIEW_DETACH_ID:-}" "$AI_CALLER_SESSION_ID" >> "$AI_REVIEW_SCOREBOARD_FILE"
printf '%s\n' "$rep"
EOF
chmod +x "$OW_POOL"
export OW_POOL_LOG="$OW/pool.log" OW_DIR="$OW"
ow_front(){ ( cd "$MREPO" && AI_POOL_TEST_HOOKS=1 AI_REVIEW_POOL_BIN="$OW_POOL" "$FRONT" "$@" ); }
(
  . "$REPO_ROOT/tools/lib/review-session-skip.sh"
  skip_add ow-session-a muse fast-fail-silent-start
)
rc=0; AI_CALLER_SESSION_ID=ow-session-a ow_front muse diff-review --force >"$OW/a.out" 2>"$OW/a.err" || rc=$?
check "skip_excludes_provider_within_session" "[ '$rc' = 77 ] && grep -q 'muse skipped for this session (fast-fail-silent-start' '$OW/a.err' && ! grep -q . '$OW_POOL_LOG' 2>/dev/null"
rc=0; AI_CALLER_SESSION_ID=ow-session-b ow_front muse diff-review --force >"$OW/b.out" 2>"$OW/b.err" || rc=$?
check "skip_does_not_leak_to_other_session" "[ '$rc' = 0 ] && grep -q '^muse diff-review' '$OW_POOL_LOG'"
(
  . "$REPO_ROOT/tools/lib/review-session-skip.sh"
  for p in deepseek glm stepfun; do skip_add ow-session-a "$p" provider-failed; done
)
rc=0; AI_CALLER_SESSION_ID=ow-session-a ow_front stepfun diff-review --force >"$OW/c.out" 2>"$OW/c.err" || rc=$?
check "all_skipped_exits_75" "[ '$rc' = 75 ] && grep -q 'all reviewers skipped this session' '$OW/c.err' && grep -lq '\"status\":\"all-skipped\"' '$AI_REVIEW_DETACH_DIR'/s*.json"

: > "$OW_POOL_LOG"
SECONDS_BEFORE=$SECONDS
rc=0; AI_CALLER_SESSION_ID=ow-session-c ow_front muse final-check --force --detach >"$OW/d.out" 2>"$OW/d.err" || rc=$?
DETACH_SECS=$((SECONDS - SECONDS_BEFORE))
DETACH_ID="$(tail -1 "$OW/d.out" | tr -d '\r')"
check "detach_returns_run_id_in_under_10s" "[ '$rc' = 0 ] && [ '$DETACH_SECS' -lt 10 ] && [[ '$DETACH_ID' =~ ^d[0-9A-Za-z-]+$ ]] && grep -q 'ai-review outcome $DETACH_ID' '$OW/d.err'"
FIRST_OUTCOME="$("$FRONT" outcome "$DETACH_ID" 2>/dev/null | head -1)"
FINAL_OUTCOME="$("$FRONT" outcome "$DETACH_ID" --wait 60 2>/dev/null | head -1)"
check "outcome_reports_pending_then_verdict" "[ '$FIRST_OUTCOME' = pending ] && [ '$FINAL_OUTCOME' = APPROVE ]"
check "detached_run_records_scoreboard_row" "jq -e --arg id '$DETACH_ID' 'select(.detach_id==\$id and .caller_session_id==\"ow-session-c\" and .provider==\"muse\")' '$AI_REVIEW_SCOREBOARD_FILE' >/dev/null && grep -q -- '--force' '$OW_POOL_LOG' && ! grep -q -- '--detach' '$OW_POOL_LOG'"
check "detached_record_binds_exact_head" "jq -e --arg h \"\$(git -C '$MREPO' rev-parse HEAD)\" '.head==\$h and .status==\"finished\" and .exit_code==0' '$AI_REVIEW_DETACH_DIR/$DETACH_ID.json' >/dev/null"
unset AI_REVIEW_SESSION_SKIP_DIR AI_REVIEW_DETACH_DIR OW_POOL_LOG OW_DIR

# --- engine doctor ----------------------------------------------------------
echo '== engine doctor'
check "engine_doctor_reports_core_stamp" "'$ENGINE' doctor | grep -q 'review-lifecycle-core/1'"

echo
printf '== test-ai-review-engine: %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
