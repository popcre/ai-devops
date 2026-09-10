#!/usr/bin/env bash
# test-ai-merge-group-evidence.sh — the merge-queue evidence gate is fail-closed.
#
# The failure being guarded: issue #204 took the long Windows jobs off the
# merge queue and left the Windows proof resting on the pull-request run of the
# queued head commit. Nothing checked that the run existed, matched the commit,
# finished, or passed. These cases prove the gate refuses each of those, and
# that it accepts only complete, matching, successful evidence.
#
# Everything here runs offline against stub `gh` and `git` commands.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD="$ROOT/bin/ai-merge-group-evidence"
export AI_DEVOPS_TEST_MODE=1
export AI_TASK_GATES_MODE=none
pass=0; fail=0
check() {
  if eval "$2" >/dev/null 2>&1; then printf '  ok   %s\n' "$1"; pass=$(( pass + 1 ))
  else printf '  FAIL %s\n' "$1"; fail=$(( fail + 1 )); fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"

# The stubs read their answers from files, so each case sets the world it wants
# without a network call. HEAD_SHA empty means "the pull request cannot be read".
write_stubs() {
  cat > "$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "pr view") cat "$STUB_DIR/head_sha" ;;
  "run list") cat "$STUB_DIR/runs" ;;
  "run view") cat "$STUB_DIR/jobs" ;;
  "api graphql") cat "$STUB_DIR/queued_head" ;;
  *) exit 1 ;;
esac
STUB
  chmod +x "$TMP/bin/gh"
}
write_stubs
export STUB_DIR="$TMP"
RUN() { PATH="$TMP/bin:$PATH" bash "$CMD" "$@" 2>&1; }

REF='refs/heads/gh-readonly-queue/main/pr-357-b418c2c25ffe877fd3c3987b0aad68483f382078'
GOOD_HEAD='0178be4a0178be4a0178be4a0178be4a0178be4a'
set_world() {
  printf '%s\n' "$1" > "$TMP/head_sha"
  printf '%s\n' "$2" > "$TMP/queued_head"
  printf '%s' "$3" > "$TMP/runs"
  printf '%s' "$4" > "$TMP/jobs"
}

check "the evidence gate exists and is executable" "test -x '$CMD'"
check "it parses as valid bash" "bash -n '$CMD'"

set_world "$GOOD_HEAD" "$GOOD_HEAD" "$(printf '9001\tcompleted\tsuccess\n')" "$(printf 'windows-offline\tsuccess\nlinux-offline\tsuccess\n')"

OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require windows-offline)"; RC=$?
check "matching, complete, successful evidence is accepted" \
  "test '$RC' -eq 0 && printf '%s' \"\$OUT\" | grep -q 'verified by'"

# A configuration or usage mistake must never read as evidence, so it exits 2,
# distinct from the exit 1 that means 'the evidence is not good enough'.
OUT="$(RUN --merge-group-sha deadbeef)"; RC=$?
check "a missing merge-group ref is a configuration error, not a pass" "test '$RC' -eq 2"
OUT="$(RUN --ref "$REF")"; RC=$?
check "a missing merge-group commit is a configuration error, not a pass" "test '$RC' -eq 2"
OUT="$(RUN --ref refs/heads/main --merge-group-sha deadbeef)"; RC=$?
check "a ref that is not a merge-queue ref is refused" \
  "test '$RC' -eq 2 && printf '%s' \"\$OUT\" | grep -q 'not a merge-queue ref'"
OUT="$(RUN --ref 'refs/heads/gh-readonly-queue/main/pr-abc-1234' --merge-group-sha deadbeef)"; RC=$?
check "a ref with no readable pull-request number is refused" "test '$RC' -eq 2"

set_world '' "$GOOD_HEAD" '' ''
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops)"; RC=$?
check "an unreadable pull-request head is a configuration error, not a pass" "test '$RC' -eq 2"

# The live queue entry must be frozen to the same head whose proof is checked.
set_world "$GOOD_HEAD" aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa "$(printf '9001\tcompleted\tsuccess\n')" ''
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops)"; RC=$?
check "evidence for a head different from the live queue entry is rejected as stale" \
  "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'queue froze head'"

set_world "$GOOD_HEAD" "$GOOD_HEAD" '' ''
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops)"; RC=$?
check "silence is not evidence: no run at all is rejected" \
  "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'no verify.yml run exists'"

set_world "$GOOD_HEAD" "$GOOD_HEAD" "$(printf '9001\tin_progress\t\n')" ''
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops)"; RC=$?
check "an unfinished run is not evidence" \
  "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'not evidence'"

set_world "$GOOD_HEAD" "$GOOD_HEAD" "$(printf '9001\tcompleted\tfailure\n')" ''
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops)"; RC=$?
check "a failed run is not evidence" "test '$RC' -eq 1"

set_world "$GOOD_HEAD" "$GOOD_HEAD" "$(printf '9001\tcompleted\tsuccess\n')" "$(printf 'linux-offline\tsuccess\n')"
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require windows-offline)"; RC=$?
check "a run that never ran a required job is rejected" \
  "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'never ran the required job'"

set_world "$GOOD_HEAD" "$GOOD_HEAD" "$(printf '9001\tcompleted\tsuccess\n')" "$(printf 'windows-offline\tskipped\n')"
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require windows-offline)"; RC=$?
check "a required job that was skipped is rejected, not read as success" \
  "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'concluded skipped'"

set_world "$GOOD_HEAD" "$GOOD_HEAD" "$(printf '9001\tcompleted\tsuccess\n')" ''
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require windows-offline)"; RC=$?
check "a run reporting no jobs cannot confirm coverage" "test '$RC' -eq 1"

# Two runs on the same commit: the older one failing must not be papered over
# by a newer success, because a failure on that commit is a real signal.
set_world "$GOOD_HEAD" "$GOOD_HEAD" "$(printf '9002\tcompleted\tsuccess\n9001\tcompleted\tfailure\n')" ''
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops)"; RC=$?
check "a failed earlier run on the same commit still rejects" "test '$RC' -eq 1"

printf '\n%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
