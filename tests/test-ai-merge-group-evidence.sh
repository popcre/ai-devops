#!/usr/bin/env bash
# test-ai-merge-group-evidence.sh — the merge-queue evidence gate is fail-closed.
#
# The failure being guarded: issue #204 took the long Windows jobs off the
# merge queue and left the Windows proof resting on the pull-request run of the
# queued head commit. Nothing checked that the run existed, matched the commit,
# finished, or passed. These cases prove the gate refuses each of those, and
# that it accepts only complete, matching, successful evidence.
#
# Everything runs offline against stub GitHub responses and real Git fixtures.
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
mkdir -p "$TMP/bin" "$TMP/repo"
git -C "$TMP/repo" init -q
git -C "$TMP/repo" config user.name Test
git -C "$TMP/repo" config user.email test@example.com
printf 'base\n' > "$TMP/repo/README.md"
git -C "$TMP/repo" add README.md
git -C "$TMP/repo" commit -qm base
BASE_SHA="$(git -C "$TMP/repo" rev-parse HEAD)"
mkdir -p "$TMP/repo/bin"
printf '#!/bin/sh\nexit 0\n' > "$TMP/repo/bin/ai-example"
git -C "$TMP/repo" add bin/ai-example
git -C "$TMP/repo" commit -qm code
GOOD_HEAD="$(git -C "$TMP/repo" rev-parse HEAD)"
mkdir -p "$TMP/repo/docs"
git -C "$TMP/repo" mv bin/ai-example docs/example.md
git -C "$TMP/repo" commit -qm rename-code-to-doc
RENAME_HEAD="$(git -C "$TMP/repo" rev-parse HEAD)"
git -C "$TMP/repo" checkout -qb prose "$BASE_SHA"
mkdir -p "$TMP/repo/docs"
printf 'prose only\n' > "$TMP/repo/docs/queue-note.md"
git -C "$TMP/repo" add docs/queue-note.md
git -C "$TMP/repo" commit -qm prose
PROSE_HEAD="$(git -C "$TMP/repo" rev-parse HEAD)"
git -C "$TMP/repo" checkout -qb mixed "$GOOD_HEAD"
mkdir -p "$TMP/repo/docs"
printf 'mixed docs\n' > "$TMP/repo/docs/mixed.md"
git -C "$TMP/repo" add docs/mixed.md
git -C "$TMP/repo" commit -qm mixed
MIXED_HEAD="$(git -C "$TMP/repo" rev-parse HEAD)"
git -C "$TMP/repo" checkout -qb skill "$BASE_SHA"
mkdir -p "$TMP/repo/skills/example"
printf 'skill instructions\n' > "$TMP/repo/skills/example/SKILL.md"
git -C "$TMP/repo" add skills/example/SKILL.md
git -C "$TMP/repo" commit -qm skill
SKILL_HEAD="$(git -C "$TMP/repo" rev-parse HEAD)"

# The stubs read their answers from files, so each case sets the world it wants
# without a network call. HEAD_SHA empty means "the pull request cannot be read".
write_stubs() {
  cat > "$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
case "$1 $2" in
  "run list") cat "$STUB_DIR/runs" ;;
  "run view") cat "$STUB_DIR/jobs" ;;
  "api graphql")
    state="$STUB_DIR/queue_state"
    if [ -f "$STUB_DIR/queue-read" ] && [ -f "$STUB_DIR/queue-after" ]; then state="$STUB_DIR/queue-after"; fi
    case "$*" in *baseRefOid*) cat "$state" ;; *) cut -d'|' -f1-2 "$state" ;; esac
    : > "$STUB_DIR/queue-read" ;;
  *) exit 1 ;;
esac
STUB
  chmod +x "$TMP/bin/gh"
}
write_stubs
export STUB_DIR="$TMP"
RUN() { (cd "$TMP/repo" && PATH="$TMP/bin:$PATH" bash "$CMD" "$@" 2>&1); }

REF='refs/heads/gh-readonly-queue/main/pr-357-b418c2c25ffe877fd3c3987b0aad68483f382078'
set_world() {
  rm -f "$TMP/queue-read" "$TMP/queue-after"
  printf '%s|%s|%s\n' "$1" "$2" "${5:-$BASE_SHA}" > "$TMP/queue_state"
  printf '%s' "$3" > "$TMP/runs"
  printf '%s' "$4" > "$TMP/jobs"
}

check "the evidence gate exists and is executable" "test -x '$CMD'"
check "it parses as valid bash" "bash -n '$CMD'"

set_world "$GOOD_HEAD" deadbeef "$(printf '9001\tcompleted\tsuccess\n')" "$(printf 'windows-offline\tsuccess\nlinux-offline\tsuccess\n')"

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

set_world '' deadbeef '' ''
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops)"; RC=$?
check "an unreadable pull-request head is a configuration error, not a pass" "test '$RC' -eq 2"

# This workflow must still be the live queue entry for the named PR.
set_world "$GOOD_HEAD" aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa "$(printf '9001\tcompleted\tsuccess\n')" ''
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops)"; RC=$?
check "evidence from a superseded merge-group workflow is rejected as stale" \
  "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'not workflow commit'"

set_world "$GOOD_HEAD" deadbeef '' ''
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops)"; RC=$?
check "silence is not evidence: no run at all is rejected" \
  "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'no verify.yml run exists'"

set_world "$GOOD_HEAD" deadbeef "$(printf '9001\tin_progress\t\n')" ''
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops)"; RC=$?
check "an unfinished run is not evidence" \
  "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'not evidence'"

set_world "$GOOD_HEAD" deadbeef "$(printf '9001\tcompleted\tfailure\n')" ''
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops)"; RC=$?
check "a failed run is not evidence" "test '$RC' -eq 1"

set_world "$GOOD_HEAD" deadbeef "$(printf '9001\tcompleted\tsuccess\n')" "$(printf 'linux-offline\tsuccess\n')"
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require windows-offline)"; RC=$?
check "a run that never ran a required job is rejected" \
  "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'never ran the required job'"

set_world "$GOOD_HEAD" deadbeef "$(printf '9001\tcompleted\tsuccess\n')" "$(printf 'windows-offline\tskipped\n')"
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require windows-offline)"; RC=$?
check "a required job that was skipped is rejected, not read as success" \
  "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'concluded skipped'"

set_world "$GOOD_HEAD" deadbeef "$(printf '9001\tcompleted\tsuccess\n')" ''
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require windows-offline)"; RC=$?
check "a run reporting no jobs cannot confirm coverage" "test '$RC' -eq 1"

# Two runs on the same commit: the older one failing must not be papered over
# by a newer success, because a failure on that commit is a real signal.
set_world "$GOOD_HEAD" deadbeef "$(printf '9002\tcompleted\tsuccess\n9001\tcompleted\tfailure\n')" ''
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops)"; RC=$?
check "a failed earlier run on the same commit still rejects" "test '$RC' -eq 1"

set_world "$PROSE_HEAD" deadbeef "$(printf '9001\tcompleted\tsuccess\n')" "$(printf 'windows-offline\tsuccess\nwindows-reviewer-safety\tskipped\n')"
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require windows-offline --require windows-reviewer-safety)"; RC=$?
check "real prose-only changes accept intentionally skipped Windows safety" "test '$RC' -eq 0 && printf '%s' \"\$OUT\" | grep -q prose"

for strict_head in "$GOOD_HEAD" "$MIXED_HEAD" "$SKILL_HEAD"; do
  set_world "$strict_head" deadbeef "$(printf '9001\tcompleted\tsuccess\n')" "$(printf 'windows-reviewer-safety\tskipped\n')"
  OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require windows-reviewer-safety)"; RC=$?
  check "code, mixed changes and skill Markdown still require successful safety proof" "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'concluded skipped'"
done
set_world "$RENAME_HEAD" deadbeef "$(printf '9001\tcompleted\tsuccess\n')" "$(printf 'windows-reviewer-safety\tskipped\n')" "$GOOD_HEAD"
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require windows-reviewer-safety)"; RC=$?
check "moving a script into docs cannot hide its deleted code path" "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'concluded skipped'"

set_world "$PROSE_HEAD" deadbeef "$(printf '9001\tcompleted\tsuccess\n')" "$(printf 'linux-offline\tsuccess\n')"
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require windows-reviewer-safety)"; RC=$?
check "prose never excuses missing required job evidence" "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'never ran the required job'"
set_world "$PROSE_HEAD" deadbeef "$(printf '9001\tcompleted\tsuccess\n')" "$(printf 'windows-reviewer-safety\tfailure\n')"
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require windows-reviewer-safety)"; RC=$?
check "prose never excuses a failed required job" "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'concluded failure'"
set_world "$PROSE_HEAD" deadbeef "$(printf '9001\tcompleted\tsuccess\n')" "$(printf 'other-required-job\tskipped\n')"
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require other-required-job)"; RC=$?
check "prose allowance applies only to intentionally skipped Windows jobs" "test '$RC' -eq 1"

set_world "$BASE_SHA" deadbeef "$(printf '9001\tcompleted\tsuccess\n')" "$(printf 'windows-reviewer-safety\tskipped\n')"
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require windows-reviewer-safety)"; RC=$?
check "empty changes do not invent prose-only coverage" "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'diff is empty'"
set_world "$PROSE_HEAD" deadbeef "$(printf '9001\tcompleted\tsuccess\n')" "$(printf 'windows-reviewer-safety\tskipped\n')" aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require windows-reviewer-safety)"; RC=$?
check "unavailable exact base refuses the skip allowance" "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'diff is unavailable'"
for changed_state in "$GOOD_HEAD|deadbeef|$BASE_SHA" "$PROSE_HEAD|deadbeef|$GOOD_HEAD" "$PROSE_HEAD|changed-group|$BASE_SHA"; do
  set_world "$PROSE_HEAD" deadbeef "$(printf '9001\tcompleted\tsuccess\n')" "$(printf 'windows-reviewer-safety\tskipped\n')"
  printf '%s\n' "$changed_state" > "$TMP/queue-after"
  OUT="$(RUN --ref "$REF" --merge-group-sha deadbeef --repo popcre/ai-devops --require windows-reviewer-safety)"; RC=$?
  check "head, base or queue movement invalidates path classification" "test '$RC' -eq 1 && printf '%s' \"\$OUT\" | grep -q 'changed during path classification'"
done

printf '\n%s passed, %s failed, 0 skipped\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
