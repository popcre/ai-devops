#!/usr/bin/env bash
# Tests for bin/ai-grok-implement.
#
# Offline: a stub `grok` stands in for the real binary, so no network and no
# cost. Each test guards a failure measured on 2026-08-12 against Grok 0.2.112:
#
#   never_passes_worktree_flag  : --worktree is silently ignored in headless
#                                 mode; passing it is what put Grok in the
#                                 primary checkout.
#   cwd_is_native_path          : `--cwd /c/...` fails with os error 3.
#   detached_head_needs_ref     : inheriting a detached HEAD served stale files.
#   cancelled_is_failure        : stopReason Cancelled is never success.
#   empty_diff_is_failure       : exit 0 + no diff is not a finished run.
#   failure_preserves_worktree  : unique work is never silently deleted.
#   cleanup_proves_removal      : both ledgers must stop showing the worktree.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-grok-implement"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export TMPDIR_FOR_TEST="$TMP"
export AI_GROK_STATE_DIR="$TMP/state"
export AI_GROK_CALLER="claude"

# --- stub grok ---------------------------------------------------------------
STUB="$TMP/bin"; mkdir -p "$STUB"
cat > "$STUB/grok" <<'STUBEOF'
#!/usr/bin/env bash
# The version gate probes `--version` before any billable work. That probe is
# a local identity check, not a Grok session, so it is answered before the
# invocation is recorded.
case "${1:-}" in
  --version) echo "grok ${AI_GROK_TEST_VERSION:-1.0.13} (stub)"; exit 0 ;;
esac
printf '%s\n' "$*" >> "$TMPDIR_FOR_TEST/argv.txt"
case "${1:-}" in
  models)    echo "grok-4.6"; exit 0 ;;
  worktree)  # `list` must never show anything: headless runs are untracked.
             case "${2:-}" in list) echo "No worktrees found." ;; rm) exit 1 ;; esac; exit 0 ;;
esac
# Locate --cwd and honour the mode file.
cwd=""; prev=""; allow_bash=0
for a in "$@"; do
  [ "$prev" = "--cwd" ] && cwd="$a"
  [ "$prev" = "--allow" ] && [ "$a" = "Bash" ] && allow_bash=1
  prev="$a"
done
env > "$TMPDIR_FOR_TEST/child.env" 2>/dev/null || true
mode="$(cat "$TMPDIR_FOR_TEST/mode" 2>/dev/null || echo ok)"
case "$(uname -s)" in
  MSYS*|MINGW*|CYGWIN*)
    case "$cwd" in /*) echo "Error: Failed to set working directory to \"$cwd\": (os error 3)" >&2; exit 1 ;; esac
    posix="$(cygpath -u "$cwd")";;
  *)
    case "$cwd" in /*) posix="$cwd";; *) echo "expected an absolute POSIX cwd: $cwd" >&2; exit 1;; esac;;
esac
case "$mode" in
  ok)        printf 'grok was here\n' > "$posix/made-by-grok.txt"
             [ "$allow_bash" = 1 ] && printf 'HTTP/1.1 200\n' > "$posix/http-canary.txt"
             echo '{"text":"done","stopReason":"EndTurn","sessionId":"s1","num_turns":3,"usage":{"total_tokens":100,"cache_read_input_tokens":10},"total_cost_usd":0.01,"modelUsage":{"grok-4.6-build":{}}}' ;;
  cancelled) printf 'partial\n' > "$posix/partial.txt"
             echo '{"text":"","stopReason":"Cancelled","sessionId":"s2","num_turns":2,"usage":{"total_tokens":50},"total_cost_usd":0.02,"modelUsage":{"grok-4.6-build":{}}}' ;;
  nodiff)    echo '{"text":"nothing to do","stopReason":"EndTurn","sessionId":"s3","num_turns":1,"usage":{"total_tokens":10},"total_cost_usd":0.001,"modelUsage":{"grok-4.6-build":{}}}' ;;
  empty)     : ;;
esac
exit 0
STUBEOF
chmod +x "$STUB/grok"
export AI_GROK_BIN="$STUB/grok"

# --- repo factory ------------------------------------------------------------
mkrepo() { # mkrepo DIR [detached]
  local d="$1"
  mkdir -p "$d.origin" "$d"
  git init -q --bare "$d.origin"
  git init -q -b main "$d"
  git -C "$d" config user.email t@example.com
  git -C "$d" config user.name Test
  echo one > "$d/a.txt"; echo two > "$d/b.txt"
  git -C "$d" add -A; git -C "$d" commit -qm base
  echo one-v2 > "$d/a.txt"; git -C "$d" add -A; git -C "$d" commit -qm second
  git -C "$d" remote add origin "$d.origin"
  git -C "$d" push -q origin main
  git -C "$d" fetch -q origin
  if [ "${2:-}" = detached ]; then git -C "$d" checkout -q HEAD~1; fi
}

BRIEF="$TMP/brief.md"; echo "do the thing" > "$BRIEF"

# =============================================================================
run_case() { # run_case NAME MODE REPO [extra args...]
  local name="$1" mode="$2" repo="$3"; shift 3
  echo "$mode" > "$TMP/mode"
  : > "$TMP/argv.txt"
  "$SCRIPT" run "$name" --repo "$repo" --prompt-file "$BRIEF" "$@" >"$TMP/out.$name" 2>"$TMP/err.$name"
  printf '%s' $?
}

# --- 1. happy path ------------------------------------------------------------
R1="$TMP/r1"; mkrepo "$R1"
rc="$(run_case ok1 ok "$R1")"
[ "$rc" = 0 ] && ok "happy_path_exits_zero" || bad "happy_path_exits_zero (rc=$rc: $(cat "$TMP/err.ok1"))"
grep -q '"stopReason": *"EndTurn"' "$TMP/out.ok1" && ok "happy_path_emits_terminal_json" || bad "happy_path_emits_terminal_json"
[ -s "$AI_GROK_STATE_DIR/implement/claude__ok1.d/changes.diff" ] \
  && ok "diff_survives_cleanup" || bad "diff_survives_cleanup"
grep -q 'made-by-grok' "$AI_GROK_STATE_DIR/implement/claude__ok1.d/changes.diff" \
  && ok "diff_holds_grok_work" || bad "diff_holds_grok_work"
grep -q 'grok-run' "$AI_GROK_STATE_DIR/implement/claude__ok1.d/changes.diff" \
  && bad "diff_excludes_wrapper_scratch" || ok "diff_excludes_wrapper_scratch"

# --- 2. never passes --worktree ----------------------------------------------
if grep -q -- '--worktree' "$TMP/argv.txt"; then
  bad "never_passes_worktree_flag"
else
  ok "never_passes_worktree_flag"
fi
grep -q -- '--permission-mode acceptEdits' "$TMP/argv.txt" && ok "never_uses_permission_mode_auto" || bad "never_uses_permission_mode_auto"
grep -q -- '--max-turns' "$TMP/argv.txt" && ok "max_turns_always_present" || bad "max_turns_always_present"
grep -q -- '--deny Bash' "$TMP/argv.txt" && ok "run_defaults_to_deny_bash" || bad "run_defaults_to_deny_bash"
grep -q -- '--allow Bash' "$TMP/argv.txt" && bad "run_defaults_to_deny_bash_no_allow" || ok "run_defaults_to_deny_bash_no_allow"
grep -q -- '--disable-web-search' "$TMP/argv.txt" && ok "run_disables_web_search" || bad "run_disables_web_search"

# --- 3. --cwd is a native path -----------------------------------------------
# Windows Grok needs a native drive path; Linux Grok needs an absolute POSIX path.
cwd_arg="$(sed -n 's/.*--cwd \([^ ]*\).*/\1/p' "$TMP/argv.txt" | head -1)"
case "$(uname -s)" in
  MSYS*|MINGW*|CYGWIN*) case "$cwd_arg" in /*) bad "cwd_is_native_path (got POSIX: $cwd_arg)";; *) ok "cwd_is_native_path";; esac;;
  *) case "$cwd_arg" in /*) ok "cwd_is_native_path";; *) bad "cwd_is_native_path (not POSIX: $cwd_arg)";; esac;;
esac

# --- 4. cleanup proved in both ledgers ---------------------------------------
[ -e "$R1-grok-worktrees/ok1" ] && bad "cleanup_removes_worktree_dir" || ok "cleanup_removes_worktree_dir"
git -C "$R1" worktree list --porcelain | grep -q 'ok1' && bad "cleanup_proves_removal_git" || ok "cleanup_proves_removal_git"
git -C "$R1" rev-parse --verify --quiet refs/heads/grok/ok1 >/dev/null 2>&1 \
  && bad "cleanup_removes_branch" || ok "cleanup_removes_branch"

# --- 5. primary checkout untouched -------------------------------------------
[ -e "$R1/made-by-grok.txt" ] && bad "primary_checkout_unchanged" || ok "primary_checkout_unchanged"
[ "$(git -C "$R1" status --porcelain)" = "" ] && ok "primary_checkout_clean" || bad "primary_checkout_clean"

# --- 6. detached HEAD: uses origin/main, not HEAD ------------------------------
R2="$TMP/r2"; mkrepo "$R2" detached
rc="$(run_case det ok "$R2" --keep)"
[ "$rc" = 0 ] && ok "detached_head_run_succeeds" || bad "detached_head_run_succeeds ($(cat "$TMP/err.det"))"
base="$(jq -r .base_sha "$AI_GROK_STATE_DIR/implement/claude__det.json" 2>/dev/null)"
want="$(git -C "$R2" rev-parse origin/main)"
[ "$base" = "$want" ] && ok "detached_head_uses_origin_main" || bad "detached_head_uses_origin_main ($base vs $want)"
[ "$(cat "$R2-grok-worktrees/det/a.txt" 2>/dev/null)" = "one-v2" ] \
  && ok "worktree_exposes_fresh_content" || bad "worktree_exposes_fresh_content"
"$SCRIPT" cleanup det >/dev/null 2>&1 && ok "keep_then_cleanup" || bad "keep_then_cleanup"

# --- 7. detached HEAD with no remote must refuse -------------------------------
R3="$TMP/r3"; mkdir -p "$R3"; git init -q -b main "$R3"
git -C "$R3" config user.email t@example.com; git -C "$R3" config user.name Test
echo x > "$R3/a.txt"; git -C "$R3" add -A; git -C "$R3" commit -qm one
echo y > "$R3/a.txt"; git -C "$R3" add -A; git -C "$R3" commit -qm two
git -C "$R3" checkout -q HEAD~1
if "$SCRIPT" run nore --repo "$R3" --prompt-file "$BRIEF" >/dev/null 2>&1; then
  bad "detached_head_without_remote_refuses"
else
  ok "detached_head_without_remote_refuses"
fi

# --- 8. Cancelled is a failure and preserves the worktree ----------------------
R4="$TMP/r4"; mkrepo "$R4"
rc="$(run_case cx cancelled "$R4")"
[ "$rc" != 0 ] && ok "cancelled_is_failure" || bad "cancelled_is_failure"
[ -e "$R4-grok-worktrees/cx/partial.txt" ] && ok "failure_preserves_worktree" || bad "failure_preserves_worktree"
[ -s "$AI_GROK_STATE_DIR/implement/claude__cx.d/changes.diff" ] && ok "failure_preserves_diff" || bad "failure_preserves_diff"
"$SCRIPT" cleanup cx >/dev/null 2>&1 && bad "cleanup_refuses_unique_work" || ok "cleanup_refuses_unique_work"
"$SCRIPT" cleanup cx --force >/dev/null 2>&1 && ok "cleanup_force_removes" || bad "cleanup_force_removes"

# --- 9. empty diff is a failure ------------------------------------------------
R5="$TMP/r5"; mkrepo "$R5"
rc="$(run_case nd nodiff "$R5")"
[ "$rc" != 0 ] && ok "empty_diff_is_failure" || bad "empty_diff_is_failure"
grep -q 'empty-diff' "$TMP/err.nd" && ok "empty_diff_reason_recorded" || bad "empty_diff_reason_recorded"
"$SCRIPT" cleanup nd --force >/dev/null 2>&1

# --- 10. empty output (exit 0, no JSON) is a failure ---------------------------
R6="$TMP/r6"; mkrepo "$R6"
rc="$(run_case mt empty "$R6")"
[ "$rc" != 0 ] && ok "exit_zero_without_json_is_failure" || bad "exit_zero_without_json_is_failure"
"$SCRIPT" cleanup mt --force >/dev/null 2>&1

# --- 11. no arbitrary flag passthrough -----------------------------------------
if "$SCRIPT" run zz --repo "$R6" --prompt-file "$BRIEF" --sandbox danger >/dev/null 2>&1; then
  bad "refuses_arbitrary_flags"
else
  ok "refuses_arbitrary_flags"
fi

# --- 12. doctor ----------------------------------------------------------------
PINNED="$(bash "$REPO_ROOT/bin/ai-provider-version" required grok)"
"$SCRIPT" doctor 2>&1 | grep -q "$PINNED" && ok "doctor_reports_version" || bad "doctor_reports_version"
"$SCRIPT" doctor 2>&1 | grep -q "version policy: OK (exactly $PINNED" \
  && ok "doctor_confirms_the_qualified_version" || bad "doctor_confirms_the_qualified_version"
AI_GROK_TEST_VERSION=1.0.5 "$SCRIPT" doctor 2>&1 | grep -q "UNQUALIFIED .*1\.0\.5.*$PINNED" \
  && ok "doctor_reports_installed_versus_required_version" || bad "doctor_reports_installed_versus_required_version"

# --- 13. version gate ----------------------------------------------------------
# The implementation wrapper writes to a real checkout, so an unqualified build
# must be refused before the provider is ever contacted, not after.
: > "$TMP/argv.txt"
if AI_GROK_TEST_VERSION=1.0.5 "$SCRIPT" run vg --repo "$R6" --prompt-file "$BRIEF" >"$TMP/vg.out" 2>&1; then
  bad "stale_grok_version_fails_before_paid_turn"
else
  if [ -s "$TMP/argv.txt" ]; then
    bad "stale_grok_version_fails_before_paid_turn"
  else
    ok "stale_grok_version_fails_before_paid_turn"
  fi
fi
grep -q '1.0.5' "$TMP/vg.out" && grep -q "$PINNED" "$TMP/vg.out" \
  && ok "stale_version_refusal_names_both_versions" || bad "stale_version_refusal_names_both_versions"
: > "$TMP/argv.txt"
if AI_PROVIDER_VERSIONS_FILE="$TMP/absent-policy.json" "$SCRIPT" run vg2 --repo "$R6" --prompt-file "$BRIEF" >/dev/null 2>&1; then
  bad "missing_version_policy_fails_closed"
else
  [ -s "$TMP/argv.txt" ] && bad "missing_version_policy_fails_closed" || ok "missing_version_policy_fails_closed"
fi
# A refusal must strand nothing: no worktree, no branch. Otherwise the obvious
# retry fails on "worktree path already exists" for a run that never happened.
if [ -z "$(git -C "$R6" worktree list --porcelain | grep -c '^worktree' | grep -v '^1$')" ]; then
  ok "refused_version_creates_no_worktree"
else
  bad "refused_version_creates_no_worktree"
fi
git -C "$R6" branch --list '*vg*' | grep -q . && bad "refused_version_creates_no_branch"   || ok "refused_version_creates_no_branch"

# Unpinned and malformed policies must fail closed too, not fall back to
# "presence is enough".
printf '%s
' '{"schema_version":1,"providers":{"grok":{"command":"grok","supported_version":null}}}' > "$TMP/unpinned.json"
: > "$TMP/argv.txt"
if AI_PROVIDER_VERSIONS_FILE="$TMP/unpinned.json" "$SCRIPT" run vg3 --repo "$R6" --prompt-file "$BRIEF" >/dev/null 2>&1; then
  bad "unpinned_version_policy_fails_closed"
else
  [ -s "$TMP/argv.txt" ] && bad "unpinned_version_policy_fails_closed" || ok "unpinned_version_policy_fails_closed"
fi
printf '%s
' '{"schema_version":99,"providers":{}}' > "$TMP/bad.json"
: > "$TMP/argv.txt"
if AI_PROVIDER_VERSIONS_FILE="$TMP/bad.json" "$SCRIPT" run vg4 --repo "$R6" --prompt-file "$BRIEF" >/dev/null 2>&1; then
  bad "malformed_version_policy_fails_closed"
else
  [ -s "$TMP/argv.txt" ] && bad "malformed_version_policy_fails_closed" || ok "malformed_version_policy_fails_closed"
fi
: > "$TMP/argv.txt"
if AI_GROK_TEST_VERSION=1.0.14 "$SCRIPT" run vg5 --repo "$R6" --prompt-file "$BRIEF" >/dev/null 2>&1; then
  bad "newer_unqualified_version_is_not_accepted"
else
  [ -s "$TMP/argv.txt" ] && bad "newer_unqualified_version_is_not_accepted" || ok "newer_unqualified_version_is_not_accepted"
fi

# Comments explain why blanket approval is refused, so assert on real code only.
if grep -v '^[[:space:]]*#' "$SCRIPT" | grep -qE -e '--always-approve' -e 'permission-mode auto' -e 'bypassPermissions'; then
  bad "implementer_never_uses_blanket_approval"
else
  ok "implementer_never_uses_blanket_approval"
fi
grep -q 'native_home="$(native_path "$user_home")"' "$SCRIPT" \
  && grep -q 'USERPROFILE=$native_home' "$SCRIPT" \
  && ok "investigate_windows_home_is_native" || bad "investigate_windows_home_is_native"
if grep -v '^[[:space:]]*#' "$SCRIPT" | grep -qE 'cp -P .*auth\.json|cp .*auth\.json'; then
  bad "investigate_never_copies_auth"
else
  ok "investigate_never_copies_auth"
fi
grep -q 'rm -rf "$tmp_root"' "$SCRIPT" && ok "investigate_removes_temp_home" || bad "investigate_removes_temp_home"
grep -q 'env -i' "$SCRIPT" && ok "investigate_launches_allowlisted_env" || bad "investigate_launches_allowlisted_env"
grep -q 'auth_src" -ef "$grok_home/auth.json"' "$SCRIPT" && ok "investigate_proves_same_inode_auth" || bad "investigate_proves_same_inode_auth"

# --- 14. investigate (issue #513) --------------------------------------------
inv_case() { # inv_case NAME MODE REPO [extra args...]
  local name="$1" mode="$2" repo="$3"; shift 3
  echo "$mode" > "$TMP/mode"
  : > "$TMP/argv.txt"
  : > "$TMP/child.env"
  "$SCRIPT" investigate "$name" --repo "$repo" --prompt-file "$BRIEF" "$@" >"$TMP/out.$name" 2>"$TMP/err.$name"
  printf '%s' $?
}

"$SCRIPT" --help 2>/dev/null | grep -q 'investigate' && ok "investigate_in_help" || bad "investigate_in_help"
"$SCRIPT" doctor 2>&1 | grep -q 'INVESTIGATION — ADVISORY, NOT FORMAL APPROVAL' \
  && ok "doctor_labels_investigate_advisory" || bad "doctor_labels_investigate_advisory"

R7="$TMP/r7"; mkrepo "$R7"
export OP_SERVICE_ACCOUNT_TOKEN='canary-op-service-token'
export GH_TOKEN='canary-gh-token'
export GITHUB_TOKEN='canary-github-token'
export AI_TEST_OPERATOR_SECRET='canary-operator-secret'
rc="$(inv_case inv1 ok "$R7" --keep)"
[ "$rc" = 0 ] && ok "investigate_happy_path" || bad "investigate_happy_path (rc=$rc: $(cat "$TMP/err.inv1"))"
grep -q -- '--allow Bash' "$TMP/argv.txt" && ok "investigate_allows_bash" || bad "investigate_allows_bash"
grep -q -- '--deny Bash' "$TMP/argv.txt" && bad "investigate_does_not_deny_bash" || ok "investigate_does_not_deny_bash"
grep -q -- '--permission-mode default' "$TMP/argv.txt" && ok "investigate_uses_default_permissions" || bad "investigate_uses_default_permissions"
grep -q -- '--permission-mode acceptEdits' "$TMP/argv.txt" && bad "investigate_does_not_use_acceptEdits" || ok "investigate_does_not_use_acceptEdits"
grep -q -- '--disable-web-search' "$TMP/argv.txt" && ok "investigate_keeps_web_search_disabled" || bad "investigate_keeps_web_search_disabled"
if grep -q -- '--worktree' "$TMP/argv.txt"; then bad "investigate_never_passes_worktree_flag"; else ok "investigate_never_passes_worktree_flag"; fi
grep -q 'INVESTIGATION — ADVISORY, NOT FORMAL APPROVAL' "$AI_GROK_STATE_DIR/implement/claude__inv1.d/brief.md" \
  && ok "investigate_brief_is_advisory" || bad "investigate_brief_is_advisory"
[ -f "$R7-grok-worktrees/inv1/http-canary.txt" ] && ok "investigate_http_canary_via_bash" || bad "investigate_http_canary_via_bash"
[ -z "$(git -C "$R7-grok-worktrees/inv1" remote 2>/dev/null)" ] \
  && ok "investigate_copy_is_remote_less" || bad "investigate_copy_is_remote_less"
[ -e "$R7/made-by-grok.txt" ] && bad "investigate_does_not_write_primary" || ok "investigate_does_not_write_primary"
[ -e "$R7/http-canary.txt" ] && bad "investigate_http_not_in_primary" || ok "investigate_http_not_in_primary"
[ "$(git -C "$R7" status --porcelain)" = "" ] && ok "investigate_primary_clean" || bad "investigate_primary_clean"
if grep -Eq 'canary-op-service-token|canary-gh-token|canary-github-token|canary-operator-secret' "$TMP/child.env" \
     "$AI_GROK_STATE_DIR/implement/claude__inv1.d/brief.md" \
     "$AI_GROK_STATE_DIR/implement/claude__inv1.d/changes.diff" \
     "$AI_GROK_STATE_DIR/implement/claude__inv1.d/result.json" \
     "$TMP/argv.txt" 2>/dev/null; then
  bad "investigate_child_has_no_operator_secrets"
else
  ok "investigate_child_has_no_operator_secrets"
fi
grep -q '"sessionId":"s1"' "$TMP/out.inv1" && ok "investigate_records_session_identity" || bad "investigate_records_session_identity"
"$SCRIPT" cleanup inv1 >/dev/null 2>&1 && ok "investigate_cleanup" || bad "investigate_cleanup"
[ -e "$R7-grok-worktrees/inv1" ] && bad "investigate_cleanup_removes_copy" || ok "investigate_cleanup_removes_copy"
unset OP_SERVICE_ACCOUNT_TOKEN GH_TOKEN GITHUB_TOKEN AI_TEST_OPERATOR_SECRET

R8="$TMP/r8"; mkrepo "$R8"
rc="$(inv_case invnd nodiff "$R8")"
[ "$rc" = 0 ] && ok "investigate_empty_diff_is_success" || bad "investigate_empty_diff_is_success ($(cat "$TMP/err.invnd"))"

R9="$TMP/r9"; mkrepo "$R9"
rc="$(inv_case invcx cancelled "$R9")"
[ "$rc" != 0 ] && ok "investigate_cancelled_is_failure" || bad "investigate_cancelled_is_failure"
[ -e "$R9-grok-worktrees/invcx/partial.txt" ] && ok "investigate_failure_preserves_copy" || bad "investigate_failure_preserves_copy"
"$SCRIPT" cleanup invcx >/dev/null 2>&1 && bad "investigate_cleanup_refuses_unique_work" || ok "investigate_cleanup_refuses_unique_work"
"$SCRIPT" cleanup invcx --force >/dev/null 2>&1 && ok "investigate_cleanup_force" || bad "investigate_cleanup_force"

R10="$TMP/r10"; mkrepo "$R10"
rc="$(inv_case invmt empty "$R10")"
[ "$rc" != 0 ] && ok "investigate_exit_zero_without_json_is_failure" || bad "investigate_exit_zero_without_json_is_failure"
"$SCRIPT" cleanup invmt --force >/dev/null 2>&1

if "$SCRIPT" investigate zz --repo "$R10" --prompt-file "$BRIEF" --sandbox danger >/dev/null 2>&1; then
  bad "investigate_refuses_arbitrary_flags"
else
  ok "investigate_refuses_arbitrary_flags"
fi
if "$SCRIPT" investigate zz --repo "$R10" --prompt-file "$BRIEF" --allow-shell >/dev/null 2>&1; then
  bad "investigate_refuses_allow_shell_flag"
else
  ok "investigate_refuses_allow_shell_flag"
fi

# Default implement path still denies Bash after investigate lands.
R11="$TMP/r11"; mkrepo "$R11"
: > "$TMP/argv.txt"
rc="$(run_case shell0 ok "$R11" --keep)"
[ "$rc" = 0 ] && ok "run_still_works_after_investigate" || bad "run_still_works_after_investigate"
grep -q -- '--deny Bash' "$TMP/argv.txt" && ok "run_still_defaults_to_deny_bash" || bad "run_still_defaults_to_deny_bash"
[ -f "$R11-grok-worktrees/shell0/http-canary.txt" ] && bad "run_without_shell_has_no_http_canary" || ok "run_without_shell_has_no_http_canary"
"$SCRIPT" cleanup shell0 >/dev/null 2>&1

: > "$TMP/argv.txt"
rc="$(run_case shell1 ok "$R11" --allow-shell --keep)"
[ "$rc" = 0 ] && ok "run_allow_shell_still_works" || bad "run_allow_shell_still_works"
grep -q -- '--allow Bash' "$TMP/argv.txt" && ok "run_allow_shell_enables_bash" || bad "run_allow_shell_enables_bash"
"$SCRIPT" cleanup shell1 >/dev/null 2>&1

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
