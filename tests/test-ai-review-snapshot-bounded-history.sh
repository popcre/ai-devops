#!/usr/bin/env bash
# Bounded-history review snapshots (issue #711, Phase 1).
#
# The plan's original test name was test-ai-review-snapshot-has-no-git.sh,
# written for a "files + patch.diff, no .git" snapshot. That shape cannot work
# here: ai-review-packet, ai-review-lifecycle and tools/reviewer_events.py all
# run git INSIDE the snapshot (merge-base, log -1, rev-parse, cat-file, diff),
# and a reviewer boundary still needs a real .git directory (the 2026-08-17
# regression). The sanctioned alternative — a measured-depth shallow snapshot —
# is what bin/ai-review-sandbox builds now, so this suite proves the property
# that matters: the snapshot carries the change under review, its base branch
# and the connecting ancestry, and NOT the repository's deep history.
#
# Fully offline: real git, no network, no provider calls.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-review-sandbox"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes"
export AI_REVIEW_EVENT_DIR="$TMP/reviewer-events"

# A repository with a deliberately long main history (40 commits), a bare
# origin so refs/remotes/origin/main exists exactly as the packet resolver
# expects, and a topic branch 2 commits ahead of main.
MAIN="$TMP/main"
ORIGIN="$TMP/origin.git"
mkdir -p "$MAIN"
git -C "$MAIN" init -q -b main
git -C "$MAIN" config user.email t@example.com
git -C "$MAIN" config user.name Test
for i in $(seq 1 40); do
  printf 'content %s\n' "$i" > "$MAIN/file-$i.txt"
  git -C "$MAIN" add -A
  git -C "$MAIN" commit -qm "main commit $i"
done
git init -q --bare --initial-branch=main "$ORIGIN"
git -C "$MAIN" remote add origin "$ORIGIN"
git -C "$MAIN" push -q -u origin main
git -C "$MAIN" checkout -q -b topic
echo the-change > "$MAIN/the-change.txt"
git -C "$MAIN" add -A && git -C "$MAIN" commit -qm the-change
echo second-change > "$MAIN/second-change.txt"
git -C "$MAIN" add -A && git -C "$MAIN" commit -qm second-change
echo uncommitted >> "$MAIN/file-40.txt"

echo '== bounded review snapshot'

SOURCE_COMMITS="$(git -C "$MAIN" rev-list --count HEAD)"
ROOT_COMMIT="$(git -C "$MAIN" rev-list --max-parents=0 HEAD)"
STARTED="$(date +%s)"
SNAP="$("$SCRIPT" ensure-copy "$MAIN" bounded)"
SECONDS_SPENT="$(( $(date +%s) - STARTED ))"
check "snapshot_is_created"                 "test -n '$SNAP' && test -d '$SNAP'"
check "snapshot_keeps_a_real_git_directory" "test -d '$SNAP/.git' && ! test -f '$SNAP/.git'"
check "snapshot_is_labelled_for_the_reviewer" "grep -q 'Review snapshot' '$SNAP/AI-REVIEW-SANDBOX.md'"
check "snapshot_marker_present"             "test -f '$SNAP/.ai-review-sandbox'"

# THE point of Phase 1: the snapshot's object database holds only the measured
# ancestry (topic 2 + margin 5 => at most a dozen commits), not the 42-commit
# history, and the repository's root commit is simply absent.
SNAP_COMMITS="$(git -C "$SNAP" rev-list --count HEAD)"
check "snapshot_history_is_bounded"         "test '$SNAP_COMMITS' -lt 15 && test '$SOURCE_COMMITS' -eq 42"
check "deep_history_is_absent"              "! git -C '$SNAP' cat-file -e '$ROOT_COMMIT' 2>/dev/null"
check "snapshot_builds_quickly"             "test '$SECONDS_SPENT' -lt 60"

# Everything the evidence tools read back must still be there and correct.
ORIGIN_MAIN_SHA="$(git -C "$MAIN" rev-parse origin/main)"
FORK="$(git -C "$MAIN" merge-base HEAD origin/main)"
check "base_branch_carried_at_exact_tip"    "test \"\$(git -C '$SNAP' rev-parse origin/main)\" = '$ORIGIN_MAIN_SHA'"
check "merge_base_survives_the_snapshot"    "test \"\$(git -C '$SNAP' merge-base HEAD origin/main)\" = '$FORK'"
check "uncommitted_edits_reproduced"        "grep -q uncommitted '$SNAP/file-40.txt'"
check "packet_log_of_base_works"            "git -C '$SNAP' log -1 --format=%s origin/main >/dev/null 2>&1"

# The packet must build INSIDE the bounded snapshot and scope to the real change.
PKT="$($REPO_ROOT/bin/ai-review-packet build "$SNAP" bounded)"
check "packet_builds_in_bounded_snapshot"   "test -f '$PKT/MANIFEST.md' && test -f '$PKT/patch.diff'"
check "packet_shows_the_real_change"        "grep -q 'the-change.txt' '$PKT/MANIFEST.md'"
check "packet_patch_shows_second_change"    "grep -q 'second-change.txt' '$PKT/patch.diff'"
check "packet_base_is_the_base_branch"      "grep -q '$ORIGIN_MAIN_SHA' '$PKT/MANIFEST.md'"
check "packet_omits_old_main_work"          "! grep -q 'file-30.txt' '$PKT/patch.diff'"
"$SCRIPT" remove-copy "$MAIN" bounded

# An explicit base hint is carried too: wrappers forward their --base through
# AI_REVIEW_SANDBOX_BASE so a bounded snapshot never narrows an explicitly
# requested comparison. A nearby base stays bounded; a base at the root commit
# legitimately needs the whole chain and must still be exactly carried.
NEAR_BASE="$(git -C "$MAIN" rev-parse 'origin/main~2')"
git -C "$MAIN" branch legacy "$NEAR_BASE"
HINT_SNAP="$(AI_REVIEW_SANDBOX_BASE=legacy "$SCRIPT" ensure-copy "$MAIN" hinted)"
check "explicit_base_hint_is_carried"       "test \"\$(git -C '$HINT_SNAP' rev-parse legacy 2>/dev/null)\" = '$NEAR_BASE'"
check "hint_snapshot_still_bounded"         "test \"\$(git -C '$HINT_SNAP' rev-list --count HEAD)\" -lt 15"
"$SCRIPT" remove-copy "$MAIN" hinted
git -C "$MAIN" branch -q -f legacy "$ROOT_COMMIT"
ROOT_SNAP="$(AI_REVIEW_SANDBOX_BASE=legacy "$SCRIPT" ensure-copy "$MAIN" root-hint)"
check "root_base_hint_carries_whole_chain"  "test \"\$(git -C '$ROOT_SNAP' rev-parse legacy 2>/dev/null)\" = '$ROOT_COMMIT' && test \"\$(git -C '$ROOT_SNAP' merge-base HEAD legacy)\" = '$ROOT_COMMIT'"
"$SCRIPT" remove-copy "$MAIN" root-hint
git -C "$MAIN" branch -q -D legacy

# An unresolvable hint is ignored with a warning, never fatal: the packet
# build is what must fail loudly if the ref truly mattered.
IGNORED_SNAP="$(AI_REVIEW_SANDBOX_BASE=no-such-ref "$SCRIPT" ensure-copy "$MAIN" ignoredbad 2>"$TMP/hint.err")"
check "unresolvable_hint_is_ignored"        "test -n '$IGNORED_SNAP' && grep -q 'ignoring AI_REVIEW_SANDBOX_BASE' '$TMP/hint.err'"
"$SCRIPT" remove-copy "$MAIN" ignoredbad

# Issue #802: the explicit base hint must also reach the recorded-directory
# refresh path (refresh-copy), not only a fresh ensure-copy. A Kimi session
# created with --base that later refreshes a recorded snapshot must rebuild it
# with the same hinted ref, or the following packet build with --base fails.
NEAR_BASE2="$(git -C "$MAIN" rev-parse 'origin/main~2')"
git -C "$MAIN" branch refresh-hint "$NEAR_BASE2"
RECORDED_HINT="$(AI_REVIEW_SANDBOX_BASE=refresh-hint "$SCRIPT" ensure-copy "$MAIN" refreshhint)"
check "refresh_hint_baseline_is_carried"    "test \"\$(git -C '$RECORDED_HINT' rev-parse refresh-hint 2>/dev/null)\" = '$NEAR_BASE2'"
# Refresh the recorded path WITHOUT a new ensure-copy; the hint must still land.
REFRESHED_HINT="$(AI_REVIEW_SANDBOX_BASE=refresh-hint "$SCRIPT" refresh-copy "$MAIN" refreshhint "$RECORDED_HINT")"
check "refresh_copy_path_is_stable"         "test '$REFRESHED_HINT' = '$RECORDED_HINT'"
check "refresh_copy_forwards_base_hint"     "test \"\$(git -C '$REFRESHED_HINT' rev-parse refresh-hint 2>/dev/null)\" = '$NEAR_BASE2'"
"$SCRIPT" remove-recorded refreshhint "$RECORDED_HINT"
git -C "$MAIN" branch -q -D refresh-hint

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
