#!/usr/bin/env bash
# Tests for bin/ai-review-sandbox.
#
# Fully offline: real git, no network, no provider calls.
#
# The tests that matter most and must never be weakened:
#   - worktree_sandbox_is_self_contained : the regression test for the
#     2026-08-17 failure ("Git control files live outside its review
#     boundary"). If a reviewer can still be pointed at a directory whose
#     `.git` escapes the boundary, the whole fix is worthless.
#   - remove_refuses_unmanaged : nothing outside the sandbox directory, and
#     nothing without the marker, may ever be deleted by this script.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-review-sandbox"
PASS=0; FAIL=0
ok()   { printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes"

# --- a main repo plus a linked worktree --------------------------------------
MAIN="$TMP/main"
mkdir -p "$MAIN"
git -C "$MAIN" init -q
git -C "$MAIN" config user.email t@example.com
git -C "$MAIN" config user.name Test
echo base > "$MAIN/a.txt"
git -C "$MAIN" add -A
git -C "$MAIN" commit -qm init

WT="$TMP/wt"
git -C "$MAIN" worktree add -q -b feature "$WT" >/dev/null 2>&1
echo committed-in-worktree > "$WT/b.txt"
git -C "$WT" add -A
git -C "$WT" commit -qm feature
echo uncommitted >> "$WT/a.txt"
echo brand-new > "$WT/c.txt"
echo outside-secret > "$TMP/outside.txt"

echo '== ai-review-sandbox'

check "is_worktree_true_for_linked_worktree"  "'$SCRIPT' is-worktree '$WT'"
check "is_worktree_false_for_ordinary_clone"  "! '$SCRIPT' is-worktree '$MAIN'"

# An ordinary clone must pass straight through: callers wire this in blindly.
OUT="$("$SCRIPT" ensure "$MAIN" reviewtag)"
check "ordinary_repo_passes_through"          "[ \"\$(cd '$MAIN' && pwd -P)\" = '$OUT' ]"
check "ordinary_repo_creates_no_sandbox"      "[ ! -d '$TMP/sandboxes' ]"

# Preflight must never build or delete a packet in the live ordinary clone.
mkdir -p "$MAIN/.ai-review"; echo live > "$MAIN/.ai-review/sentinel"
COPY_STAGE="$("$SCRIPT" ensure-copy "$MAIN" preflight)"
check "ensure_copy_isolates_ordinary_clone"   "[ '$COPY_STAGE' != '$MAIN' ] && [ -d '$COPY_STAGE/.git' ]"
check "ensure_copy_excludes_live_packet"      "[ ! -e '$COPY_STAGE/.ai-review' ] && grep -qx live '$MAIN/.ai-review/sentinel'"
"$SCRIPT" remove-copy "$MAIN" preflight
check "remove_copy_deletes_only_snapshot"     "[ ! -d '$COPY_STAGE' ] && [ -d '$MAIN/.git' ]"

STAGE="$("$SCRIPT" ensure "$WT" reviewtag)"
check "worktree_gets_a_sandbox_path"          "[ '$STAGE' != '$WT' ] && [ -d '$STAGE' ]"

# THE regression test: the reviewed directory owns its own git control files.
check "worktree_sandbox_is_self_contained" \
  "[ -d '$STAGE/.git' ] && [ ! -f '$STAGE/.git' ] && git -C '$STAGE' status --porcelain >/dev/null"
check "sandbox_git_dir_is_inside_the_boundary" \
  "[ \"\$(cd \"\$(git -C '$STAGE' rev-parse --absolute-git-dir)\" && pwd -P)\" = \"\$(cd '$STAGE/.git' && pwd -P)\" ]"

# Content fidelity: committed, uncommitted and untracked all reproduced.
check "committed_worktree_content_present"    "grep -q committed-in-worktree '$STAGE/b.txt'"
check "uncommitted_edits_reproduced"          "grep -q uncommitted '$STAGE/a.txt'"
check "untracked_files_reproduced"            "grep -q brand-new '$STAGE/c.txt'"

# An untracked link must never import a file outside the repository boundary.
if ln -s "$TMP/outside.txt" "$WT/outside-link" 2>/dev/null && [ -L "$WT/outside-link" ]; then
  check "outside_untracked_link_is_refused"     "! '$SCRIPT' ensure '$WT' hostile-link"
  HOSTILE_STAGE="$("$SCRIPT" path "$WT" hostile-link)"
  check "outside_link_target_never_copied"      "! grep -Rqs outside-secret '$HOSTILE_STAGE' 2>/dev/null"
  rm -f "$WT/outside-link"
fi
# Even a link whose current target is inside the source checkout would remain
# an absolute link back to the live checkout after a preserving copy.
if ln -s "$WT/a.txt" "$WT/inside-absolute-link" 2>/dev/null && [ -L "$WT/inside-absolute-link" ]; then
  check "inside_absolute_untracked_link_is_refused" "! '$SCRIPT' ensure '$WT' inside-absolute-link"
  INSIDE_LINK_STAGE="$("$SCRIPT" path "$WT" inside-absolute-link)"
  check "inside_absolute_link_never_enters_snapshot" "[ ! -L '$INSIDE_LINK_STAGE/inside-absolute-link' ]"
  rm -f "$WT/inside-absolute-link"
fi
if ln -s "$TMP/outside.txt" "$WT/tracked-outside-link" 2>/dev/null && [ -L "$WT/tracked-outside-link" ]; then
  git -C "$WT" add tracked-outside-link
  git -C "$WT" commit -qm tracked-hostile-link
  check "tracked_outside_link_is_refused" "! '$SCRIPT' ensure '$WT' tracked-hostile-link"
  git -C "$WT" rm -q tracked-outside-link
  git -C "$WT" commit -qm remove-tracked-hostile-link
fi
check "head_matches_the_worktree" \
  "[ \"\$(git -C '$WT' rev-parse HEAD)\" = \"\$(git -C '$STAGE' rev-parse HEAD)\" ]"
check "sandbox_is_labelled_for_the_reviewer"  "grep -q 'Review snapshot' '$STAGE/AI-REVIEW-SANDBOX.md'"
check "sandbox_scaffolding_is_not_review_noise" \
  "[ -z \"\$(git -C '$STAGE' status --porcelain -- AI-REVIEW-SANDBOX.md .ai-review-sandbox)\" ]"

# path is pure: same answer, no side effects.
check "path_matches_ensure"                   "[ \"\$('$SCRIPT' path '$WT' reviewtag)\" = '$STAGE' ]"
check "path_creates_nothing_new" \
  "rm -rf '$STAGE' && '$SCRIPT' path '$WT' othertag >/dev/null && [ ! -d '$STAGE' ]"

# Refresh: a later turn must see later edits, and new commits must not go stale.
STAGE="$("$SCRIPT" ensure "$WT" reviewtag)"
echo second-round > "$WT/d.txt"
git -C "$WT" add -A
git -C "$WT" commit -qm second
echo later-edit >> "$WT/a.txt"
STAGE2="$("$SCRIPT" ensure "$WT" reviewtag)"
check "refresh_keeps_the_same_path"           "[ '$STAGE' = '$STAGE2' ]"
check "refresh_picks_up_new_commits"          "grep -q second-round '$STAGE2/d.txt'"
check "refresh_picks_up_new_edits"            "grep -q later-edit '$STAGE2/a.txt'"
check "refresh_head_matches_the_worktree" \
  "[ \"\$(git -C '$WT' rev-parse HEAD)\" = \"\$(git -C '$STAGE2' rev-parse HEAD)\" ]"

# Tags isolate concurrent sessions.
STAGE_B="$("$SCRIPT" ensure "$WT" second-session)"
check "tags_are_isolated"                     "[ '$STAGE_B' != '$STAGE2' ] && [ -d '$STAGE_B' ]"

# Deletion safety (rule: every destructive action must be recoverable/scoped).
"$SCRIPT" remove "$WT" second-session
check "remove_deletes_its_own_sandbox"        "[ ! -d '$STAGE_B' ]"
check "remove_is_idempotent"                  "'$SCRIPT' remove '$WT' second-session"
check "remove_on_ordinary_repo_is_a_noop"     "'$SCRIPT' remove '$MAIN' reviewtag && [ -d '$MAIN' ]"

# Anything sitting at the sandbox path that this script did not create is
# someone else's data: refuse loudly instead of deleting it.
GUARDED="$("$SCRIPT" path "$WT" guarded)"
mkdir -p "$GUARDED"; touch "$GUARDED/someone-elses-file"
check "ensure_refuses_to_clobber_unmarked_dir"  "! '$SCRIPT' ensure '$WT' guarded"
check "unmarked_dir_survives"                   "[ -f '$GUARDED/someone-elses-file' ]"
check "remove_refuses_unmarked_dir"             "! '$SCRIPT' remove '$WT' guarded; [ -f '$GUARDED/someone-elses-file' ]"

# --- wiring contract ----------------------------------------------------------
# The snapshot only helps if the reviewer wrappers actually route their review
# directory through it. These guards fail loudly if a future edit hands a raw
# worktree path back to a delegated reviewer.
for w in ai-glm ai-kimi ai-qwen ai-grok-review; do
  check "${w}_defines_review_boundary"        "grep -q '^review_boundary()' '$REPO_ROOT/bin/$w'"
  if grep -q '^prepare_review()' "$REPO_ROOT/bin/$w"; then
    check "${w}_prepares_through_boundary"     "grep -q 'REVIEW_DIR=\"\$(review_boundary' '$REPO_ROOT/bin/$w'"
    check "${w}_uses_prepared_review_twice"    "[ \"\$(grep -c '^ *prepare_review \"' '$REPO_ROOT/bin/$w')\" -ge 2 ]"
  else
    check "${w}_uses_review_boundary"          "[ \"\$(grep -c 'review_boundary \"' '$REPO_ROOT/bin/$w')\" -ge 2 ]"
  fi
  check "${w}_releases_its_snapshot"          "grep -q 'release_boundary' '$REPO_ROOT/bin/$w'"
done
# ai-codex-review and ai-deepseek-agent send the diff as text and never hand a
# directory to the model, so they are immune and deliberately not wired.
check "codex_review_hands_over_no_directory"  "! grep -qE -- '--cd |--cwd ' '$REPO_ROOT/bin/ai-codex-review'"
check "deepseek_hands_over_no_directory"      "! grep -qE -- '--cd |--cwd ' '$REPO_ROOT/bin/ai-deepseek-agent'"

check "invalid_tag_rejected"                  "! '$SCRIPT' ensure '$WT' 'bad tag'"
check "unknown_subcommand_rejected"           "! '$SCRIPT' nonsense"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
