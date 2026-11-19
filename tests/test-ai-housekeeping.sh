#!/usr/bin/env bash
# tests/test-ai-housekeeping.sh — named cases for bin/ai-housekeeping.
# Cases 3/4 encode D1/D3, case 8 encodes R4, cases 10/11 encode D3a,
# case 15 encodes the batched issue lookup (#1646 M3).
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
TOOL="$ROOT/bin/ai-housekeeping"
# Keep the run out of the real agent-job state directory: its inventory scan
# of thousands of files dominated wall time on Windows and coupled the suite
# to whatever a developer machine had lying around. No case asserts counts.
export AI_HOUSEKEEPING_STATE_DIR="$TMP/agent-state"

# --- fixture helpers -------------------------------------------------------
new_repo() {
  local dir="$1"
  git init -q "$dir"
  git -C "$dir" config user.name test
  git -C "$dir" config user.email test@example.invalid
  printf 'seed\n' > "$dir/seed.txt"
  git -C "$dir" add seed.txt
  git -C "$dir" commit -qm seed
  git -C "$dir" branch -M main
}

# Stub gh: honors STUB_PR_JSON, STUB_ISSUE_STATE, STUB_ISSUE_LIST, and logs
# every invocation to STUB_CALL_LOG when that is set (#1646 M3 batch check).
make_gh_stub() {
  local path="$1"
  cat > "$path" <<'STUB'
#!/usr/bin/env bash
if [[ -n "${STUB_CALL_LOG:-}" ]]; then
  printf '%s\n' "$*" >> "$STUB_CALL_LOG"
fi
case "${1:-}" in
  auth) exit 1 ;;
  issue)
    if [[ "${2:-}" == "view" ]]; then
      printf '%s\n' "${STUB_ISSUE_STATE:-OPEN}"
      exit 0
    fi
    if [[ "${2:-}" == "list" ]]; then
      # Inline JSON (no filesystem dependency across the stub boundary).
      if [[ -n "${STUB_ISSUE_LIST_JSON:-}" ]]; then
        printf '%s\n' "$STUB_ISSUE_LIST_JSON"
      else
        st="${STUB_ISSUE_STATE:-OPEN}"
        printf '[{"number":4242,"state":"%s"},{"number":999,"state":"%s"}]\n' "$st" "$st"
      fi
      exit 0
    fi
    ;;
  pr)
    if [[ "${2:-}" == "list" ]]; then
      if [[ -n "${STUB_PR_JSON:-}" && -f "${STUB_PR_JSON}" ]]; then
        cat "${STUB_PR_JSON}"
      else
        echo '[]'
      fi
      exit "${STUB_PR_EXIT:-0}"
    fi
    ;;
esac
exit 0
STUB
  chmod +x "$path"
}

run_tool() {
  # usage: run_tool <workdir> <outfile> [args...]
  local workdir="$1" outfile="$2"
  shift 2
  ( cd "$workdir" && AI_HOUSEKEEPING_GH="${AI_HOUSEKEEPING_GH:-}" \
      bash "$TOOL" "$@" ) > "$outfile" 2>&1
}

# ---------------------------------------------------------------------------
# 1. refuses outside a git repository
# ---------------------------------------------------------------------------
case1="$TMP/outside"
mkdir -p "$case1"
set +e
( cd "$case1" && AI_HOUSEKEEPING_GH= bash "$TOOL" ) > "$TMP/c1.out" 2>&1
c1=$?
set -e
if [[ "$c1" -ne 0 ]] && grep -qi 'not inside a git repository' "$TMP/c1.out"; then
  ok "refuses outside a git repository"
else
  bad "refuses outside a git repository (exit=$c1)"
fi

# ---------------------------------------------------------------------------
# 2. never mutates the repository
# ---------------------------------------------------------------------------
case2="$TMP/mutate"
new_repo "$case2"
git -C "$case2" branch fixture-dirty-branch
mkdir -p "$case2/HANDOFF.d"
printf -- '---\nissue: none\nstatus: OPEN\nowner: test\n---\nbody\n' > "$case2/HANDOFF.d/2026-01-01T0000Z-test-agent-note.md"
before_status="$(git -C "$case2" status --porcelain)"
before_wt="$(git -C "$case2" worktree list)"
before_br="$(git -C "$case2" branch)"
AI_HOUSEKEEPING_GH= run_tool "$case2" "$TMP/c2.out" --details
after_status="$(git -C "$case2" status --porcelain)"
after_wt="$(git -C "$case2" worktree list)"
after_br="$(git -C "$case2" branch)"
if [[ "$before_status" == "$after_status" && "$before_wt" == "$after_wt" && "$before_br" == "$after_br" ]]; then
  ok "never mutates the repository"
else
  bad "never mutates the repository"
fi

# ---------------------------------------------------------------------------
# 3. contains no destructive execution path
# ---------------------------------------------------------------------------
case3="$TMP/destructive"
new_repo "$case3"
inst="$TMP/instr"
mkdir -p "$inst"
MUTLOG="$TMP/mutations.log"
: > "$MUTLOG"
# Instrumented git: log every call; refuse mutating subcommands.
# type -P always yields an absolute path so the stub cannot recurse into itself.
REAL_GIT="$(type -P git)"
if [[ -z "$REAL_GIT" ]]; then
  bad "cannot locate a real git binary for instrumentation"
  printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
  exit 1
fi
cat > "$inst/git" <<EOF
#!/usr/bin/env bash
printf 'git %s\n' "\$*" >> "$MUTLOG"
cmd="\${1:-}"
case "\$cmd" in
  commit|checkout|reset|clean|merge|rebase|cherry-pick|gc|prune|push|pull|fetch|add|stash|tag|rm|mv)
    printf 'MUTATION git %s\n' "\$*" >> "$MUTLOG"
    exit 99 ;;
  branch)
    for a in "\$@"; do
      case "\$a" in
        -d|-D|-m|-M|--delete|--move|--force)
          printf 'MUTATION git %s\n' "\$*" >> "$MUTLOG"; exit 99 ;;
      esac
    done
    ;;
  worktree)
    sub="\${2:-}"
    case "\$sub" in
      remove|prune|move|lock|unlock|repair)
        printf 'MUTATION git %s\n' "\$*" >> "$MUTLOG"; exit 99 ;;
    esac
    ;;
esac
exec "$REAL_GIT" "\$@"
EOF
cat > "$inst/rm" <<EOF
#!/usr/bin/env bash
printf 'MUTATION rm %s\n' "\$*" >> "$MUTLOG"
exit 99
EOF
chmod +x "$inst/git" "$inst/rm"
for flag in "" "--details" "--quiet" "--log"; do
  # shellcheck disable=SC2086
  ( cd "$case3" && PATH="$inst:$PATH" AI_HOUSEKEEPING_GH= HOME="$TMP/fakehome" \
      bash "$TOOL" $flag ) > "$TMP/c3.out" 2>&1 || true
done
if grep -q '^MUTATION ' "$MUTLOG"; then
  bad "contains no destructive execution path"
else
  ok "contains no destructive execution path"
fi

# ---------------------------------------------------------------------------
# 4. never calls git branch --merged  (D3 / finding 4)
# ---------------------------------------------------------------------------
if grep -nE 'git branch --merged|git branch -merged|branch --merged' "$TOOL" >/dev/null 2>&1; then
  bad "never calls git branch --merged"
else
  ok "never calls git branch --merged"
fi

# ---------------------------------------------------------------------------
# 5. reports UNKNOWN when gh is unavailable
# ---------------------------------------------------------------------------
case5="$TMP/nogh"
new_repo "$case5"
git -C "$case5" branch feature-nogh
set +e
( cd "$case5" && AI_HOUSEKEEPING_GH= bash "$TOOL" ) > "$TMP/c5.out" 2>&1
c5=$?
set -e
if [[ "$c5" -eq 0 ]] && grep -q 'UNKNOWN' "$TMP/c5.out" && grep -qi 'gh unavailable\|GitHub unavailable' "$TMP/c5.out"; then
  ok "reports UNKNOWN when gh is unavailable"
else
  bad "reports UNKNOWN when gh is unavailable (exit=$c5)"
fi

# ---------------------------------------------------------------------------
# 6. classifies a closed-issue handoff for SUCCESSOR REVIEW
# ---------------------------------------------------------------------------
case6="$TMP/handoff-closed"
new_repo "$case6"
mkdir -p "$case6/HANDOFF.d"
cat > "$case6/HANDOFF.d/2026-01-02T0000Z-test-agent-closed.md" <<'EOF'
---
issue: 4242
status: OPEN
owner: test/session-closed
---
Work that claims its issue is closed.
EOF
stub6="$TMP/gh6"
make_gh_stub "$stub6"
( cd "$case6" && AI_HOUSEKEEPING_GH="$stub6" STUB_ISSUE_STATE=CLOSED \
    bash "$TOOL" --details ) > "$TMP/c6.out" 2>&1
if grep -q 'SUCCESSOR REVIEW' "$TMP/c6.out" &&
   ! grep -qiE '\b(finished|safe|STALE)\b' "$TMP/c6.out"; then
  ok "classifies a closed-issue handoff for SUCCESSOR REVIEW"
else
  bad "classifies a closed-issue handoff for SUCCESSOR REVIEW"
fi

# ---------------------------------------------------------------------------
# 7. classifies a handoff with no contract block as UNATTRIBUTED
# ---------------------------------------------------------------------------
case7="$TMP/handoff-unattr"
new_repo "$case7"
mkdir -p "$case7/HANDOFF.d"
printf 'just some notes with no contract block\n' > "$case7/HANDOFF.d/2026-01-03T0000Z-test-agent-plain.md"
stub7="$TMP/gh7"
make_gh_stub "$stub7"
( cd "$case7" && AI_HOUSEKEEPING_GH="$stub7" bash "$TOOL" --details ) > "$TMP/c7.out" 2>&1
if grep -q 'UNATTRIBUTED' "$TMP/c7.out"; then
  ok "classifies a handoff with no contract block as UNATTRIBUTED"
else
  bad "classifies a handoff with no contract block as UNATTRIBUTED"
fi

# ---------------------------------------------------------------------------
# 8. labels an all-done plan file as a retained record  (R4)
# ---------------------------------------------------------------------------
case8="$TMP/plan-done"
new_repo "$case8"
cat > "$case8/plan_done_record.md" <<'EOF'
# Implementation plan: sample

## STATUS

| # | Step | Status | Evidence |
|---|---|---|---|
| 1 | First | ✅ done | abc |
| 2 | Second | ✅ done | def |
EOF
stub8="$TMP/gh8"
make_gh_stub "$stub8"
( cd "$case8" && AI_HOUSEKEEPING_GH="$stub8" bash "$TOOL" --details ) > "$TMP/c8.out" 2>&1
if grep -q 'retained record' "$TMP/c8.out" && grep -q 'do not delete' "$TMP/c8.out"; then
  ok "labels an all-done plan file as a retained record"
else
  bad "labels an all-done plan file as a retained record"
fi

# ---------------------------------------------------------------------------
# 9. exits 0 when it finds review candidates
# ---------------------------------------------------------------------------
case9="$TMP/candidates"
new_repo "$case9"
mkdir -p "$case9/HANDOFF.d"
cat > "$case9/HANDOFF.d/2026-01-04T0000Z-test-agent-succ.md" <<'EOF'
---
issue: 999
status: OPEN
owner: test/candidate
---
EOF
stub9="$TMP/gh9"
make_gh_stub "$stub9"
set +e
( cd "$case9" && AI_HOUSEKEEPING_GH="$stub9" STUB_ISSUE_STATE=CLOSED \
    bash "$TOOL" ) > "$TMP/c9.out" 2>&1
c9=$?
set -e
if [[ "$c9" -eq 0 ]] && grep -q 'SUCCESSOR REVIEW' "$TMP/c9.out"; then
  ok "exits 0 when it finds review candidates"
else
  bad "exits 0 when it finds review candidates (exit=$c9)"
fi

# ---------------------------------------------------------------------------
# 10. historical merged PR with newer local commits is UNKNOWN  (D3a)
# ---------------------------------------------------------------------------
case10="$TMP/pr-stale"
new_repo "$case10"
git -C "$case10" branch feature-stale
local_sha="$(git -C "$case10" rev-parse feature-stale)"
old_sha="0000000000000000000000000000000000000001"
cat > "$TMP/pr10.json" <<EOF
[
  {
    "state": "MERGED",
    "headRefName": "feature-stale",
    "headRefOid": "$old_sha",
    "mergedAt": "2026-01-01T00:00:00Z",
    "url": "https://example.invalid/pr/1"
  }
]
EOF
stub10="$TMP/gh10"
make_gh_stub "$stub10"
( cd "$case10" && AI_HOUSEKEEPING_GH="$stub10" STUB_PR_JSON="$TMP/pr10.json" \
    bash "$TOOL" --details ) > "$TMP/c10.out" 2>&1
# The summary prints the label "MERGED CANDIDATE" as a category even at
# count 0; only a detail row starting with that label is a classification.
if ! grep -qE '^[[:space:]]*MERGED CANDIDATE[[:space:]]' "$TMP/c10.out" &&
   grep -q 'feature-stale' "$TMP/c10.out" &&
   grep -q 'UNKNOWN  feature-stale' "$TMP/c10.out"; then
  ok "historical merged PR with newer local commits is UNKNOWN"
else
  bad "historical merged PR with newer local commits is UNKNOWN (local=$local_sha)"
fi

# ---------------------------------------------------------------------------
# 11. exact merged PR head is only a MERGED CANDIDATE  (D3a)
# ---------------------------------------------------------------------------
case11="$TMP/pr-exact"
new_repo "$case11"
git -C "$case11" branch feature-exact
exact_sha="$(git -C "$case11" rev-parse feature-exact)"
cat > "$TMP/pr11.json" <<EOF
[
  {
    "state": "MERGED",
    "headRefName": "feature-exact",
    "headRefOid": "$exact_sha",
    "mergedAt": "2026-01-01T00:00:00Z",
    "url": "https://example.invalid/pr/2"
  }
]
EOF
stub11="$TMP/gh11"
make_gh_stub "$stub11"
( cd "$case11" && AI_HOUSEKEEPING_GH="$stub11" STUB_PR_JSON="$TMP/pr11.json" \
    bash "$TOOL" --details ) > "$TMP/c11.out" 2>&1
if grep -qE '^[[:space:]]*MERGED CANDIDATE[[:space:]]' "$TMP/c11.out" &&
   grep -q 'cleanup-worktree' "$TMP/c11.out" &&
   ! grep -qi '\bsafe\b' "$TMP/c11.out"; then
  ok "exact merged PR head is only a MERGED CANDIDATE"
else
  bad "exact merged PR head is only a MERGED CANDIDATE"
fi

# ---------------------------------------------------------------------------
# 12. default is one-screen summary and details are opt-in
# ---------------------------------------------------------------------------
case12="$TMP/layout"
new_repo "$case12"
git -C "$case12" branch fixture-distinctive-name-xyz
stub12="$TMP/gh12"
make_gh_stub "$stub12"
( cd "$case12" && AI_HOUSEKEEPING_GH="$stub12" bash "$TOOL" ) > "$TMP/c12-sum.out" 2>&1
( cd "$case12" && AI_HOUSEKEEPING_GH="$stub12" bash "$TOOL" --details ) > "$TMP/c12-det.out" 2>&1
if ! grep -q 'B\. Worktrees' "$TMP/c12-sum.out" &&
   ! grep -q 'fixture-distinctive-name-xyz' "$TMP/c12-sum.out" &&
   grep -q 'B\. Worktrees' "$TMP/c12-det.out" &&
   grep -q 'fixture-distinctive-name-xyz' "$TMP/c12-det.out"; then
  ok "default is one-screen summary and details are opt-in"
else
  bad "default is one-screen summary and details are opt-in"
fi

# ---------------------------------------------------------------------------
# 13. --log writes a dated block and retains only the latest 30 daily blocks
# ---------------------------------------------------------------------------
case13="$TMP/retention"
new_repo "$case13"
stub13="$TMP/gh13"
make_gh_stub "$stub13"
export AI_HOUSEKEEPING_LOG="$TMP/hk-retention.log"
# Seed 35 dated daily blocks, then one real --log run.
: > "$AI_HOUSEKEEPING_LOG"
for i in $(seq 1 35); do
  {
    printf '===== 2026-01-%02dT00:00:00Z ai-housekeeping =====\n' "$i"
    printf 'seed block %s\n' "$i"
  } >> "$AI_HOUSEKEEPING_LOG"
done
( cd "$case13" && AI_HOUSEKEEPING_GH="$stub13" bash "$TOOL" --log --quiet ) > "$TMP/c13.out" 2>&1
blocks13="$(grep -c '^===== .* ai-housekeeping =====$' "$AI_HOUSEKEEPING_LOG" || true)"
if grep -q 'seed block 35' "$AI_HOUSEKEEPING_LOG" && \
   ! grep -q 'seed block 1$' "$AI_HOUSEKEEPING_LOG" && \
   [[ "$blocks13" -le 30 ]]; then
  ok "keeps the latest 30 dated daily blocks in the log"
else
  bad "keeps the latest 30 dated daily blocks in the log (blocks=$blocks13)"
fi
unset AI_HOUSEKEEPING_LOG

stub_deferred="$TMP/gh-deferred"
make_gh_stub "$stub_deferred"
( cd "$case13" && STUB_PR_EXIT=75 STUB_CALL_LOG="$TMP/deferred-calls.log" \
    AI_HOUSEKEEPING_GH="$stub_deferred" bash "$TOOL" ) > "$TMP/deferred.out" 2>&1
if grep -q 'GitHub: UNKNOWN (GitHub probe deferred by the shared throttle)' "$TMP/deferred.out" && \
   ! grep -q 'Install and authenticate gh' "$TMP/deferred.out" && \
   [[ "$(cat "$TMP/deferred-calls.log")" == 'pr list --state all --limit 200 --json state,headRefName,headRefOid,mergedAt,url' ]]; then
  ok "deferred PR listing reports UNKNOWN without additional requests or diagnosing sign-in"
else
  bad "deferred GitHub probe was not distinguished from unavailable authentication"
fi

# ---------------------------------------------------------------------------
# 14. offline --log still records UNKNOWN and exits 0 (D3)
# ---------------------------------------------------------------------------
case14="$TMP/offline-log"
new_repo "$case14"
git -C "$case14" branch feature-offline-log
export AI_HOUSEKEEPING_LOG="$TMP/hk-offline.log"
: > "$AI_HOUSEKEEPING_LOG"
set +e
( cd "$case14" && AI_HOUSEKEEPING_GH= bash "$TOOL" --log ) > "$TMP/c14.out" 2>&1
c14=$?
set -e
if [[ "$c14" -eq 0 ]] && grep -q 'UNKNOWN' "$AI_HOUSEKEEPING_LOG" && \
   grep -q '^===== .* ai-housekeeping =====$' "$AI_HOUSEKEEPING_LOG"; then
  ok "offline --log records UNKNOWN in a dated block and exits 0"
else
  bad "offline --log records UNKNOWN in a dated block and exits 0 (exit=$c14)"
fi
unset AI_HOUSEKEEPING_LOG

# ---------------------------------------------------------------------------
# 15. numeric handoffs batch into ONE issue list round trip  (#1646 M3)
# ---------------------------------------------------------------------------
case15="$TMP/handoff-batch"
new_repo "$case15"
mkdir -p "$case15/HANDOFF.d"
cat > "$case15/HANDOFF.d/2026-01-05T0000Z-test-agent-a.md" <<'EOF'
---
issue: 4242
status: OPEN
owner: test/batch-a
---
EOF
cat > "$case15/HANDOFF.d/2026-01-05T0001Z-test-agent-b.md" <<'EOF'
---
issue: 999
status: OPEN
owner: test/batch-b
---
EOF
stub15="$TMP/gh15"
make_gh_stub "$stub15"
: > "$TMP/gh15-calls.log"
( cd "$case15" && STUB_CALL_LOG="$TMP/gh15-calls.log" \
    STUB_ISSUE_LIST_JSON='[{"number":4242,"state":"CLOSED"},{"number":999,"state":"OPEN"}]' \
    AI_HOUSEKEEPING_GH="$stub15" bash "$TOOL" --details ) > "$TMP/c15.out" 2>&1
list_calls="$(grep -c '^issue list ' "$TMP/gh15-calls.log" || true)"
view_calls="$(grep -c '^issue view ' "$TMP/gh15-calls.log" || true)"
pr_calls="$(grep -c '^pr list ' "$TMP/gh15-calls.log" || true)"
if [[ "$pr_calls" -eq 1 ]] && ! grep -q '^auth ' "$TMP/gh15-calls.log" &&
   grep -q 'GitHub: available' "$TMP/c15.out"; then
  ok "a successful PR listing also proves GitHub availability without an auth probe"
else
  bad "GitHub availability did not reuse exactly one PR listing"
fi
if [[ "$list_calls" -eq 1 && "$view_calls" -eq 0 ]] &&
   grep -q 'Handoffs (git-shared): 1 OPEN, 1 SUCCESSOR REVIEW' "$TMP/c15.out"; then
  ok "numeric handoffs resolve from a single batched issue list (1 list, 0 views)"
else
  bad "issue lookups not batched (list=$list_calls views=$view_calls) or classification wrong | $(grep -m1 'Handoffs (git-shared)' "$TMP/c15.out" || echo NO_SUMMARY) | calls: $(tr '\n' ';' < "$TMP/gh15-calls.log")"
fi

# housekeeping_schedule_tmp_lifetime_is_safe (#1783): the EXIT trap must not
# reference the function-local temp path after it goes out of scope, and a
# crontab refusal must still fail the command (no false PASS).
# Windows schedules through schtasks.exe, not crontab; never touch a real task.
if ! command -v schtasks.exe >/dev/null 2>&1; then
cron16="$TMP/cron16"; mkdir -p "$cron16/bin"
cat > "$cron16/bin/crontab" <<CRON
#!/bin/sh
[ "\$1" = -l ] && exit 1
[ -n "\${CRON16_REFUSE:-}" ] && exit 1
cat "\$1" > "$cron16/installed"; exit 0
CRON
chmod +x "$cron16/bin/crontab"
for sub in schedule unschedule; do
  rc16=0
  PATH="$cron16/bin:$PATH" HOME="$cron16" bash "$TOOL" "$sub" > "$TMP/c16-$sub.out" 2>&1 || rc16=$?
  if [[ "$rc16" -eq 0 ]] && ! grep -q 'unbound variable' "$TMP/c16-$sub.out"; then
    ok "$sub exits 0 with no unbound-variable trap error"
  else
    bad "$sub rc=$rc16 | $(tr '\n' ';' < "$TMP/c16-$sub.out")"
  fi
done
rc16=0
CRON16_REFUSE=1 PATH="$cron16/bin:$PATH" HOME="$cron16" bash "$TOOL" schedule > "$TMP/c16-refuse.out" 2>&1 || rc16=$?
if [[ "$rc16" -ne 0 ]] && grep -q 'refused' "$TMP/c16-refuse.out" && ! grep -q 'unbound variable' "$TMP/c16-refuse.out"; then
  ok "crontab refusal fails schedule truthfully"
else
  bad "crontab refusal rc=$rc16 | $(tr '\n' ';' < "$TMP/c16-refuse.out")"
fi
fi

# ---------------------------------------------------------------------------
# 17. the transport runs through bash: a launcher exec() cannot run directly
#     must still probe, so the report is not falsely UNKNOWN (Git Bash)
# ---------------------------------------------------------------------------
case17="$TMP/bash-route"
new_repo "$case17"
stub17="$TMP/gh17"
cat > "$stub17" <<'STUB'
#!/nonexistent/interp
case "${1:-}" in
  pr) printf '[]\n'; exit 0 ;;
esac
exit 1
STUB
chmod +x "$stub17"
( cd "$case17" && AI_HOUSEKEEPING_GH="$stub17" bash "$TOOL" ) > "$TMP/c17.out" 2>&1
if grep -q 'GitHub: available' "$TMP/c17.out"; then
  ok "probe routes the transport through bash (unexec-able launcher still works)"
else
  bad "transport not routed through bash | $(grep -m1 'GitHub:' "$TMP/c17.out" || echo NO_GH_LINE)"
fi

# ---------------------------------------------------------------------------
# 18. a probe that outruns its bound reports throttle timeout, never the
#     "install and authenticate gh" misdiagnosis
# ---------------------------------------------------------------------------
case18="$TMP/probe-timeout"
new_repo "$case18"
stub18="$TMP/gh18"
cat > "$stub18" <<'STUB'
#!/usr/bin/env bash
sleep 5
exit 0
STUB
chmod +x "$stub18"
( cd "$case18" && AI_HOUSEKEEPING_GH="$stub18" \
    AI_HOUSEKEEPING_GH_TIMEOUT_SECONDS=1 bash "$TOOL" ) > "$TMP/c18.out" 2>&1
if grep -q 'timed out' "$TMP/c18.out" && ! grep -qi 'install and authenticate' "$TMP/c18.out"; then
  ok "probe timeout reports throttle timeout, not an install/authentication hint"
else
  bad "probe timeout not reported honestly | $(tr '\n' ';' < "$TMP/c18.out" | cut -c1-300)"
fi

# An exit-zero response that isn't a PR list cannot prove availability.
printf '%s\n' '{"error":"invalid response"}' > "$TMP/non-array.json"
( cd "$case13" && STUB_PR_JSON="$TMP/non-array.json" \
    AI_HOUSEKEEPING_GH="$stub13" bash "$TOOL" ) > "$TMP/non-array.out" 2>&1
if grep -q 'GitHub: UNKNOWN (GitHub unavailable)' "$TMP/non-array.out"; then
  ok "invalid PR response leaves GitHub availability UNKNOWN"
else
  bad "invalid PR response reported GitHub available"
fi

# A report must defer, never sleep, through a GitHub back-off (it once sat
# silent for 10+ minutes): every GitHub call carries AI_GH_NO_WAIT=1.
stub_nowait="$TMP/gh-nowait"
cat > "$stub_nowait" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "${AI_GH_NO_WAIT:-unset}" >> "$STUB_ENV_LOG"
exit 75
STUB
chmod +x "$stub_nowait"
( cd "$case13" && STUB_ENV_LOG="$TMP/nowait-env.log" \
    AI_HOUSEKEEPING_GH="$stub_nowait" bash "$TOOL" ) > "$TMP/nowait.out" 2>&1
if [[ "$(sort -u "$TMP/nowait-env.log")" == "1" ]] && \
   grep -q 'GitHub probe deferred' "$TMP/nowait.out"; then
  ok "GitHub calls never wait through a throttle back-off"
else
  bad "GitHub calls may sleep through a throttle back-off"
fi

# The shared run budget bounds every call, so a jammed throttle cannot spend
# the call bound on the probe and freeze the report (#2691: 580s silent).
case19="$TMP/budget-cap"
new_repo "$case19"
stub19="$TMP/gh19"
cat > "$stub19" <<'STUB'
#!/usr/bin/env bash
sleep 30
exit 0
STUB
chmod +x "$stub19"
start19=$SECONDS
set +e
( cd "$case19" && AI_HOUSEKEEPING_GH="$stub19" \
    AI_HOUSEKEEPING_STATE_DIR="$TMP/state19" \
    AI_HOUSEKEEPING_GH_TIMEOUT_SECONDS=30 AI_HOUSEKEEPING_GH_BUDGET_SECONDS=2 \
    bash "$TOOL" ) > "$TMP/c19.out" 2>&1
c19=$?
set -e
elapsed19=$(( SECONDS - start19 ))
if [[ "$c19" -eq 0 ]] && [[ "$elapsed19" -lt 15 ]] && \
   grep -q 'Housekeeping summary' "$TMP/c19.out" && grep -q 'timed out' "$TMP/c19.out"; then
  ok "shared GitHub budget caps a stuck call and the summary still prints"
else
  bad "report stalled past its GitHub budget (exit=$c19 elapsed=${elapsed19}s) | $(tr '\n' ';' < "$TMP/c19.out" | cut -c1-200)"
fi

# The budget is shared across calls: after a quick probe, a slow second call
# gets only what is left of the run budget, not a fresh call bound.
case20="$TMP/budget-shared"
new_repo "$case20"
mkdir -p "$case20/HANDOFF.d"
cat > "$case20/HANDOFF.d/2026-01-05T0000Z-test-agent-a.md" <<'EOF'
---
issue: 4242
status: OPEN
owner: test/shared-a
---
EOF
stub20="$TMP/gh20"
cat > "$stub20" <<'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  issue) sleep 30; exit 0 ;;
  pr) printf '[]\n'; exit 0 ;;
esac
exit 0
STUB
chmod +x "$stub20"
start20=$SECONDS
set +e
( cd "$case20" && AI_HOUSEKEEPING_GH="$stub20" \
    AI_HOUSEKEEPING_STATE_DIR="$TMP/state20" \
    AI_HOUSEKEEPING_GH_TIMEOUT_SECONDS=30 AI_HOUSEKEEPING_GH_BUDGET_SECONDS=3 \
    bash "$TOOL" ) > "$TMP/c20.out" 2>&1
c20=$?
set -e
elapsed20=$(( SECONDS - start20 ))
if [[ "$c20" -eq 0 ]] && [[ "$elapsed20" -lt 15 ]] && \
   grep -q 'Housekeeping summary' "$TMP/c20.out"; then
  ok "second GitHub call spends only the remaining shared budget"
else
  bad "second call waited out a fresh call bound (exit=$c20 elapsed=${elapsed20}s) | $(tr '\n' ';' < "$TMP/c20.out" | cut -c1-200)"
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
