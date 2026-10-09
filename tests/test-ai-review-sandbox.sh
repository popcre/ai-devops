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
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Synthetic test repositories have no registered GitHub identity. Keep their
# historic public-snapshot assertions while the production classifier correctly
# refuses an unclassified source.
mkdir -p "$TMP/mockbin"
cat > "$TMP/mockbin/ai-task-gates" <<'EOF'
#!/usr/bin/env bash
printf '{"identity_resolved":true,"effective_class":"code","observed_class":"code"}\n'
EOF
chmod +x "$TMP/mockbin/ai-task-gates"
export PATH="$TMP/mockbin:$PATH"

export AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes"
export AI_REVIEW_EVENT_DIR="$TMP/reviewer-events"

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
printf 'source helper\n' > "$MAIN/.ai-review-helper.py"
mkdir -p "$MAIN/.ai-review-notes"; printf 'source notes\n' > "$MAIN/.ai-review-notes/feature.txt"
COPY_STAGE="$("$SCRIPT" ensure-copy "$MAIN" preflight)"
check "ensure_copy_isolates_ordinary_clone"   "[ '$COPY_STAGE' != '$MAIN' ] && [ -d '$COPY_STAGE/.git' ]"
check "ensure_copy_excludes_live_packet"      "[ ! -e '$COPY_STAGE/.ai-review' ] && grep -qx live '$MAIN/.ai-review/sentinel'"
check "review_prefix_source_file_is_preserved" "cmp '$MAIN/.ai-review-helper.py' '$COPY_STAGE/.ai-review-helper.py'"
check "review_prefix_source_directory_is_preserved" "cmp '$MAIN/.ai-review-notes/feature.txt' '$COPY_STAGE/.ai-review-notes/feature.txt'"
PREFIX_DIGEST="$("$SCRIPT" digest "$MAIN")"
printf 'changed source helper\n' > "$MAIN/.ai-review-helper.py"
check "review_prefix_source_change_affects_identity" "[ '$PREFIX_DIGEST' != \"\$('$SCRIPT' digest '$MAIN')\" ]"
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
check "snapshot_records_whole_source_digest" \
  "grep -qx \"source_digest=\$('$SCRIPT' digest '$WT')\" '$STAGE/.ai-review-sandbox'"
PROGRESS_FILE="$TMP/source-inventory.progress"
AI_DEVOPS_TEST_MODE=1 AI_REVIEW_SANDBOX_PROGRESS_FILE="$PROGRESS_FILE" "$SCRIPT" digest "$WT" >/dev/null
check "test-mode digest exposes real inventory progress" "test -f '$PROGRESS_FILE'"
rm -f "$PROGRESS_FILE"
AI_REVIEW_SANDBOX_PROGRESS_FILE="$PROGRESS_FILE" "$SCRIPT" digest "$WT" >/dev/null
check "production digest ignores test progress instrumentation" "test ! -e '$PROGRESS_FILE'"
# #754: a stray PowerShell module cache at the checkout root is tool state, not
# source. It must not change the digest, must not be copied, and the snapshot
# built while it exists must still match the source digest.
PS_BEFORE="$("$SCRIPT" digest "$MAIN")"
mkdir -p "$MAIN/Microsoft/Windows/PowerShell"
printf 'cache\n' > "$MAIN/Microsoft/Windows/PowerShell/ModuleAnalysisCache"
check "powershell_cache_does_not_change_source_digest" "[ '$PS_BEFORE' = \"\$('$SCRIPT' digest '$MAIN')\" ]"
PS_STAGE="$("$SCRIPT" ensure-copy "$MAIN" pscache)"
check "powershell_cache_is_not_copied_into_snapshot" "[ ! -e '$PS_STAGE/Microsoft/Windows/PowerShell/ModuleAnalysisCache' ]"
check "snapshot_digest_matches_with_powershell_cache_present" \
  "grep -qx \"source_digest=\$('$SCRIPT' digest '$MAIN')\" '$PS_STAGE/.ai-review-sandbox'"
printf 'nested\n' > "$MAIN/Microsoft/Windows/PowerShell/other.txt"
check "other_files_beside_the_cache_still_count" "[ '$PS_BEFORE' != \"\$('$SCRIPT' digest '$MAIN')\" ]"
"$SCRIPT" remove-copy "$MAIN" pscache
rm -rf "$MAIN/Microsoft"

# A shallow snapshot has a smaller object database than the full source, so git
# abbreviates the `index` line in `git diff` to a different width. Hashing that
# text made source and snapshot digests disagree (snapshot-digest-mismatch).
FULL_ODB="$TMP/full-odb"
mkdir -p "$FULL_ODB"
git -C "$FULL_ODB" init -q
git -C "$FULL_ODB" config user.email t@example.com
git -C "$FULL_ODB" config user.name Test
echo base > "$FULL_ODB/a.txt"
git -C "$FULL_ODB" add -A
git -C "$FULL_ODB" commit -qm init
i=0
while [ "$i" -lt 30 ]; do
  echo "filler-$i" > "$FULL_ODB/filler-$i.txt"
  git -C "$FULL_ODB" add -A
  git -C "$FULL_ODB" commit -qm "filler $i"
  i=$((i + 1))
done
echo changed >> "$FULL_ODB/a.txt"
SHALLOW_ODB="$TMP/shallow-odb"
git clone -q --depth 1 "file://$FULL_ODB" "$SHALLOW_ODB"
echo changed >> "$SHALLOW_ODB/a.txt"
check "shallow_and_full_odb_agree_on_source_digest" \
  "[ \"\$('$SCRIPT' digest '$FULL_ODB')\" = \"\$('$SCRIPT' digest '$SHALLOW_ODB')\" ]"
check "head_matches_the_worktree" \
  "[ \"\$(git -C '$WT' rev-parse HEAD)\" = \"\$(git -C '$STAGE' rev-parse HEAD)\" ]"

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
check "sandbox_is_labelled_for_the_reviewer"  "grep -q 'Review snapshot' '$STAGE/AI-REVIEW-SANDBOX.md'"
check "sandbox_scaffolding_is_not_review_noise" \
  "[ -z \"\$(git -C '$STAGE' status --porcelain -- AI-REVIEW-SANDBOX.md .ai-review-sandbox)\" ]"
# All-or-nothing hostile cases. A copy/diff failure must preserve the prior good
# snapshot and leave no building directory behind.
PRESERVE_STAGE="$STAGE"
PRESERVE_HASH="$(sha256sum "$PRESERVE_STAGE/a.txt" | cut -d' ' -f1)"
check "failed_untracked_copy_is_fatal" \
  "AI_DEVOPS_TEST_MODE=1 AI_REVIEW_SANDBOX_TEST_FAIL_COPY=c.txt '$SCRIPT' ensure '$WT' reviewtag >/dev/null 2>&1; [ \$? -ne 0 ]"
check "failed_copy_preserves_previous_snapshot" \
  "[ '$PRESERVE_HASH' = \"\$(sha256sum '$PRESERVE_STAGE/a.txt' | cut -d' ' -f1)\" ]"
check "failed_copy_removes_partial_snapshot" \
  "! compgen -G '$PRESERVE_STAGE.building.*' >/dev/null"
check "failed_diff_is_fatal_and_unpublished" \
  "! AI_DEVOPS_TEST_MODE=1 AI_REVIEW_SANDBOX_TEST_FAIL_DIFF=1 '$SCRIPT' ensure '$WT' failed-diff >/dev/null 2>&1; [ ! -e \"\$('$SCRIPT' path '$WT' failed-diff)\" ]"

# A change during copy retries once and publishes only a stable second attempt.
HOOK_ONCE="$TMP/mutate-once.sh"
cat > "$HOOK_ONCE" <<'EOF'
#!/usr/bin/env bash
[ "$1" = after-copy ] || exit 0
[ "$3" = 1 ] || exit 0
printf 'mutation-during-copy\n' >> "$2/a.txt"
EOF
chmod +x "$HOOK_ONCE"
MUTATION_STAGE="$(AI_DEVOPS_TEST_MODE=1 AI_REVIEW_SANDBOX_TEST_HOOK="$HOOK_ONCE" "$SCRIPT" ensure "$WT" mutation-once)"
check "mid_copy_mutation_retries_to_stable_source" \
  "grep -q mutation-during-copy '$MUTATION_STAGE/a.txt'"
check "retried_snapshot_digest_matches_source" \
  "grep -qx \"source_digest=\$('$SCRIPT' digest '$WT')\" '$MUTATION_STAGE/.ai-review-sandbox'"

HOOK_ALWAYS="$TMP/mutate-always.sh"
cat > "$HOOK_ALWAYS" <<'EOF'
#!/usr/bin/env bash
[ "$1" = after-copy ] || exit 0
printf 'mutation-%s\n' "$3" >> "$2/a.txt"
EOF
chmod +x "$HOOK_ALWAYS"
ALWAYS_STAGE="$($SCRIPT path "$WT" mutation-always)"
check "two_mid_copy_mutations_fail_closed" \
  "! AI_DEVOPS_TEST_MODE=1 AI_REVIEW_SANDBOX_TEST_HOOK='$HOOK_ALWAYS' '$SCRIPT' ensure '$WT' mutation-always >/dev/null 2>&1"
check "unstable_snapshot_is_never_published" \
  "[ ! -e '$ALWAYS_STAGE' ] && ! compgen -G '$ALWAYS_STAGE.building.*' >/dev/null"

# A disappearing untracked file is handled as a source change: the first mixed
# copy is discarded and the stable retry reflects the now-current tree.
echo vanishing > "$WT/vanish.txt"
HOOK_VANISH="$TMP/vanish-once.sh"
cat > "$HOOK_VANISH" <<'EOF'
#!/usr/bin/env bash
[ "$1:$3" = after-copy:1 ] || exit 0
rm -f "$2/vanish.txt"
EOF
chmod +x "$HOOK_VANISH"
VANISH_STAGE="$(AI_DEVOPS_TEST_MODE=1 AI_REVIEW_SANDBOX_TEST_HOOK="$HOOK_VANISH" "$SCRIPT" ensure "$WT" disappearing)"
check "disappearing_file_never_survives_mixed_snapshot" "[ ! -e '$VANISH_STAGE/vanish.txt' ]"
check "disappearing_file_retry_is_digest_bound" \
  "grep -qx \"source_digest=\$('$SCRIPT' digest '$WT')\" '$VANISH_STAGE/.ai-review-sandbox'"

# A duplicate owner for the same tag is rejected instead of racing publication.
LOCK_STAGE="$($SCRIPT path "$WT" duplicate-lock)"; mkdir -p "$LOCK_STAGE.lock"
check "duplicate_snapshot_lock_is_rejected" "! '$SCRIPT' ensure '$WT' duplicate-lock >/dev/null 2>&1"
rmdir "$LOCK_STAGE.lock"

# A failed build must release its lock and partial copy. The EXIT trap runs
# after create_or_refresh's frame is gone, so a trap reading function locals
# died on `set -u` ("lock: unbound variable") and left a stale lock that blocked
# every later build for the tag.
FAIL_PROGRESS_DIR="$TMP/failing-inventory"
FAIL_ERR="$TMP/failing-inventory.err"
FAIL_STAGE="$($SCRIPT path "$WT" failing-inventory)"
AI_DEVOPS_TEST_MODE=1 AI_REVIEW_SANDBOX_PROGRESS_FILE="$FAIL_PROGRESS_DIR/missing/progress" \
  "$SCRIPT" ensure-copy "$WT" failing-inventory >/dev/null 2>"$FAIL_ERR"
check "failed_inventory_is_reported" "grep -q 'could not read the complete review-visible source inventory' '$FAIL_ERR'"
check "failed_inventory_trap_has_no_unbound_variable" "! grep -q 'unbound variable' '$FAIL_ERR'"
check "failed_inventory_releases_snapshot_lock" "[ ! -e '$FAIL_STAGE.lock' ]"
check "failed_inventory_publishes_nothing" "[ ! -e '$FAIL_STAGE' ]"
check "failed_inventory_tag_can_be_rebuilt" "'$SCRIPT' ensure-copy '$WT' failing-inventory >/dev/null 2>&1 && [ -d '$FAIL_STAGE/.git' ]"
"$SCRIPT" remove-copy "$WT" failing-inventory

# The same failure after the partial copy exists must remove that copy too.
HOOK_BREAK_INVENTORY="$TMP/break-inventory.sh"
cat > "$HOOK_BREAK_INVENTORY" <<'HOOK'
#!/usr/bin/env bash
[ "$1:$3" = after-copy:1 ] || exit 0
rm -rf "$AI_REVIEW_SANDBOX_PROGRESS_FILE_DIR"
HOOK
chmod +x "$HOOK_BREAK_INVENTORY"
mkdir -p "$FAIL_PROGRESS_DIR"
LATE_STAGE="$($SCRIPT path "$WT" failing-late)"
AI_DEVOPS_TEST_MODE=1 AI_REVIEW_SANDBOX_TEST_HOOK="$HOOK_BREAK_INVENTORY" \
  AI_REVIEW_SANDBOX_PROGRESS_FILE_DIR="$FAIL_PROGRESS_DIR" AI_REVIEW_SANDBOX_PROGRESS_FILE="$FAIL_PROGRESS_DIR/progress" \
  "$SCRIPT" ensure-copy "$WT" failing-late >/dev/null 2>"$FAIL_ERR"
check "late_failed_inventory_is_reported" "grep -q 'could not read the complete review-visible source inventory' '$FAIL_ERR' && ! grep -q 'unbound variable' '$FAIL_ERR'"
check "late_failed_inventory_releases_snapshot_lock" "[ ! -e '$LATE_STAGE.lock' ]"
check "late_failed_inventory_removes_partial_copy" "! ls -d '$LATE_STAGE'.building.* >/dev/null 2>&1 && [ ! -e '$LATE_STAGE' ]"

# Keep a non-trivial path in the inventory to guard accidental newline/space or
# path-truncation rewrites. (The production clone also enables core.longpaths.)
LONG_REL="long directory/segment-012345678901234567890123456789/segment-abcdefghij/file with spaces.txt"
mkdir -p "$WT/$(dirname "$LONG_REL")"; echo long-path > "$WT/$LONG_REL"
LONG_STAGE="$($SCRIPT ensure "$WT" long-path)"
check "long_and_spaced_path_is_copied_exactly" "grep -qx long-path '$LONG_STAGE/$LONG_REL'"
check "long_path_snapshot_is_digest_bound" \
  "grep -qx \"source_digest=\$('$SCRIPT' digest '$WT')\" '$LONG_STAGE/.ai-review-sandbox'"

# path is pure: same answer, no side effects.
check "path_matches_ensure"                   "[ \"\$('$SCRIPT' path '$WT' reviewtag)\" = '$STAGE' ]"
check "path_creates_nothing_new" \
  "rm -rf '$STAGE' && '$SCRIPT' path '$WT' othertag >/dev/null && [ ! -d '$STAGE' ]"

# Refresh: a later turn must see later edits, and new commits must not go stale.
PYTHON="$(command -v python3 || command -v python)"
EVENTS="$REPO_ROOT/tools/reviewer_events.py"
OWNED="$("$SCRIPT" ensure-copy "$WT" durable-proof)"
EVENT_ID="$(cd "$WT" && "$PYTHON" "$EVENTS" begin grok)"
"$PYTHON" "$EVENTS" require-report grok "$EVENT_ID" "$OWNED"
check "unpublished_paid_evidence_refuses_later_snapshot_removal" \
  "! '$SCRIPT' remove-copy '$WT' durable-proof >/dev/null 2>&1 && [ -d '$OWNED' ]"
check "unpublished_paid_evidence_refuses_snapshot_refresh" \
  "! '$SCRIPT' ensure-copy '$WT' durable-proof >/dev/null 2>&1 && [ -d '$OWNED' ]"
printf '# Synthetic completed review\n' > "$TMP/durable-report.md"
"$PYTHON" "$EVENTS" publish-report grok "$EVENT_ID" "$TMP/durable-report.md" >/dev/null
rm -f "$TMP/durable-report.md"
check "durable_receipt_allows_exact_cleanup_after_original_report_is_gone" \
  "'$SCRIPT' remove-copy '$WT' durable-proof && [ ! -d '$OWNED' ] && '$PYTHON' '$EVENTS' verify-reports grok '$EVENT_ID' >/dev/null"

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

# A directory-bound reviewer must keep one recorded path even after the source
# checkout moves. Only an existing managed snapshot with the exact tag may be
# refreshed this way.
ALIASED_SANDBOX_DIR="$TMP/alias/../sandboxes"; mkdir -p "$TMP/alias"
RECORDED="$(AI_REVIEW_SANDBOX_DIR="$ALIASED_SANDBOX_DIR" "$SCRIPT" ensure-copy "$MAIN" stable-move)"
RECORDED_ID="$(cat "$RECORDED/.git/opencode" 2>/dev/null)"
MOVED_SOURCE="$TMP/moved-source"; git clone -q "$MAIN" "$MOVED_SOURCE"
git -C "$MOVED_SOURCE" config user.email t@example.com
git -C "$MOVED_SOURCE" config user.name Test
echo moved-source > "$MOVED_SOURCE/moved.txt"; git -C "$MOVED_SOURCE" add moved.txt; git -C "$MOVED_SOURCE" commit -qm moved-source
REFRESHED="$(AI_REVIEW_SANDBOX_DIR="$ALIASED_SANDBOX_DIR" "$SCRIPT" refresh-copy "$MOVED_SOURCE" stable-move "$RECORDED")"
check "recorded_copy_refresh_keeps_exact_directory" "[ '$REFRESHED' = '$RECORDED' ]"
check "recorded_copy_refresh_uses_current_source" "grep -qx moved-source '$RECORDED/moved.txt' && [ \"\$(git -C '$RECORDED' rev-parse HEAD)\" = \"\$(git -C '$MOVED_SOURCE' rev-parse HEAD)\" ]"
check "recorded_copy_refresh_keeps_project_identity" "printf '%s\n' '$RECORDED_ID' | grep -Eqx '[0-9a-f]{40}' && [ \"\$(cat '$RECORDED/.git/opencode')\" = '$RECORDED_ID' ]"
check "recorded_copy_refresh_rejects_wrong_tag" "! AI_REVIEW_SANDBOX_DIR='$ALIASED_SANDBOX_DIR' '$SCRIPT' refresh-copy '$MOVED_SOURCE' wrong-tag '$RECORDED'"
UNMANAGED_REFRESH="$TMP/sandboxes/unmanaged-refresh"; mkdir -p "$UNMANAGED_REFRESH"; touch "$UNMANAGED_REFRESH/preserve"
check "recorded_copy_refresh_rejects_unmanaged_target" "! '$SCRIPT' refresh-copy '$MOVED_SOURCE' stable-move '$UNMANAGED_REFRESH'"
check "rejected_unmanaged_refresh_preserves_target" "test -f '$UNMANAGED_REFRESH/preserve'"
check "recorded_copy_removal_rejects_wrong_tag" "! AI_REVIEW_SANDBOX_DIR='$ALIASED_SANDBOX_DIR' '$SCRIPT' remove-recorded wrong-tag '$RECORDED'"
check "recorded_copy_removal_rejects_unmanaged_target" "! '$SCRIPT' remove-recorded stable-move '$UNMANAGED_REFRESH'"
check "recorded_copy_removal_deletes_exact_snapshot" "AI_REVIEW_SANDBOX_DIR='$ALIASED_SANDBOX_DIR' '$SCRIPT' remove-recorded stable-move '$RECORDED' && test ! -e '$RECORDED'"

# Tags isolate concurrent sessions.
STAGE_B="$("$SCRIPT" ensure "$WT" second-session)"
check "tags_are_isolated"                     "[ '$STAGE_B' != '$STAGE2' ] && [ -d '$STAGE_B' ]"
# Issue #430: snapshots of one repository must not share an OpenCode project,
# or every server boot rescans all of them.
check "snapshots_get_distinct_opencode_projects" \
  "grep -Eqx '[0-9a-f]{40}' '$STAGE_B/.git/opencode' && grep -Eqx '[0-9a-f]{40}' '$STAGE2/.git/opencode' && [ \"\$(cat '$STAGE_B/.git/opencode')\" != \"\$(cat '$STAGE2/.git/opencode')\" ]"
check "snapshot_project_is_not_the_root_commit" \
  "grep -Eqx '[0-9a-f]{40}' '$STAGE_B/.git/opencode' && [ \"\$(cat '$STAGE_B/.git/opencode')\" != \"\$(git -C '$WT' rev-list --max-parents=0 HEAD)\" ]"

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

# --- base refs survive the snapshot (shared-db PR #2155 regression) ------------
# The snapshot is a clone with its origin remote removed, which used to delete
# every ref it had. ai-review-packet then found no main/master, fell through to
# HEAD~1, and on a MERGE commit that made "what changed" mean everything the
# merge brought in from main -- so the reviewer judged files the change never
# touched. Two Codex runs on shared-db PR #2155 did exactly that.
MERGE_SRC="$TMP/mergerepo"
MERGE_ORIGIN="$TMP/merge-origin.git"
mkdir -p "$MERGE_SRC"
git -C "$MERGE_SRC" init -q -b main
git -C "$MERGE_SRC" config user.email t@example.com
git -C "$MERGE_SRC" config user.name Test
echo base > "$MERGE_SRC/base.txt"
git -C "$MERGE_SRC" add -A && git -C "$MERGE_SRC" commit -qm init
git init -q --bare --initial-branch=main "$MERGE_ORIGIN"
git -C "$MERGE_SRC" remote add origin "$MERGE_ORIGIN"
git -C "$MERGE_SRC" push -q -u origin main
git -C "$MERGE_SRC" checkout -q -b topic
echo change > "$MERGE_SRC/the-actual-change.txt"
git -C "$MERGE_SRC" add -A && git -C "$MERGE_SRC" commit -qm topic
MERGE_UPSTREAM="$TMP/merge-upstream"
git clone -q "$MERGE_ORIGIN" "$MERGE_UPSTREAM"
git -C "$MERGE_UPSTREAM" config user.email t@example.com
git -C "$MERGE_UPSTREAM" config user.name Test
echo unrelated > "$MERGE_UPSTREAM/not-part-of-the-change.txt"
git -C "$MERGE_UPSTREAM" add -A && git -C "$MERGE_UPSTREAM" commit -qm main-moved && git -C "$MERGE_UPSTREAM" push -q origin main
git -C "$MERGE_SRC" fetch -q origin
git -C "$MERGE_SRC" merge -q --no-ff -m 'Merge origin/main into topic' origin/main
MERGE_SNAP="$("$SCRIPT" ensure-copy "$MERGE_SRC" mergebase)"
MERGE_MAIN_SHA="$(git -C "$MERGE_SRC" rev-parse origin/main)"
MERGE_HEAD_SHA="$(git -C "$MERGE_SRC" rev-parse topic)"
SNAP_MAIN_SHA="$(git -C "$MERGE_SNAP" rev-parse origin/main 2>/dev/null || true)"
SNAP_HEAD_SHA="$(git -C "$MERGE_SNAP" rev-parse HEAD)"
check "snapshot_carries_the_fetched_base_branch" "[ '$SNAP_MAIN_SHA' = '$MERGE_MAIN_SHA' ]"
check "snapshot_head_is_still_detached"        "! git -C '$MERGE_SNAP' symbolic-ref -q HEAD"
check "snapshot_head_is_the_merge_commit"      "[ '$SNAP_HEAD_SHA' = '$MERGE_HEAD_SHA' ]"
MERGE_PKT="$("$REPO_ROOT/bin/ai-review-packet" build "$MERGE_SNAP" mergebase)"
check "merge_packet_base_is_the_base_branch"   "grep -q '$MERGE_MAIN_SHA' '$MERGE_PKT/MANIFEST.md'"
check "merge_packet_shows_the_real_change"     "grep -q 'the-actual-change.txt' '$MERGE_PKT/MANIFEST.md'"
check "merge_packet_omits_unrelated_main_work" "! grep -q 'not-part-of-the-change.txt' '$MERGE_PKT/MANIFEST.md'"
check "merge_patch_omits_unrelated_main_work" "! grep -q 'not-part-of-the-change.txt' '$MERGE_PKT/patch.diff'"

# The sandbox removes the network remote but preserves both ref namespaces.
# Packet resolution prefers origin/main; an explicit local main still means main.
git -C "$MERGE_SRC" update-ref refs/heads/main "$(git -C "$MERGE_SRC" rev-list --max-parents=0 HEAD)"
STALE_LOCAL_MAIN="$(git -C "$MERGE_SRC" rev-parse main)"
git -C "$MERGE_SRC" update-ref refs/remotes/origin/main "$MERGE_MAIN_SHA"
REMOTE_SNAP="$("$SCRIPT" ensure-copy "$MERGE_SRC" remote-wins)"
check "snapshot_preserves_current_origin_and_explicit_local_main" "[ \"$(git -C "$REMOTE_SNAP" rev-parse origin/main)\" = '$MERGE_MAIN_SHA' ] && [ \"$(git -C "$REMOTE_SNAP" rev-parse main)\" = '$STALE_LOCAL_MAIN' ] && [ '$STALE_LOCAL_MAIN' != '$MERGE_MAIN_SHA' ]"

# Another worktree can publish a new ref tip after the objects are fetched.
# Snapshot refs must describe the tips captured BEFORE the fetch, never a
# later live ref transaction. (Since the bounded-snapshot change, issue #711,
# the snapshot carries only the base-ref candidates ai-review-packet resolves,
# so the freeze is proven on origin/main — a ref it does carry — rather than on
# an unrelated topic branch it no longer carries.)
REF_HOOK="$TMP/advance-ref-after-clone.sh"
cat > "$REF_HOOK" <<'EOF'
#!/usr/bin/env bash
[ "$1" = after-clone ] || exit 0
tree="$(git -C "$2" rev-parse HEAD^{tree})"
new="$(printf 'concurrent snapshot regression\n' | git -C "$2" commit-tree "$tree" -p HEAD)" || exit 1
git -C "$2" update-ref refs/remotes/origin/main "$new"
EOF
chmod +x "$REF_HOOK"
REF_SNAP="$(AI_DEVOPS_TEST_MODE=1 AI_REVIEW_SANDBOX_TEST_HOOK="$REF_HOOK" "$SCRIPT" ensure-copy "$MERGE_SRC" concurrent-refs)"
check "snapshot freezes ref identities before copying objects" "test -n '$REF_SNAP' && test \"$(git -C "$REF_SNAP" rev-parse origin/main 2>/dev/null)\" = '$MERGE_MAIN_SHA' && test \"$(git -C "$MERGE_SRC" rev-parse origin/main)\" != '$MERGE_MAIN_SHA'"

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
# ai-codex-review now uses the same complete, digest-bound disposable snapshot
# as the other directory-aware reviewers. DeepSeek still receives evidence as
# text and deliberately does not receive a repository directory.
check "codex_review_uses_snapshot_boundary"   "grep -q 'ensure-copy' '$REPO_ROOT/bin/ai-codex-review' && grep -q 'remove-copy' '$REPO_ROOT/bin/ai-codex-review'"
check "codex_review_hands_snapshot_to_model"  "grep -q -- '--cd \"\$REVIEW_DIR\"' '$REPO_ROOT/bin/ai-codex-review'"
check "deepseek_hands_over_no_directory"      "! grep -qE -- '--cd |--cwd ' '$REPO_ROOT/bin/ai-deepseek-agent'"

check "invalid_tag_rejected"                  "! '$SCRIPT' ensure '$WT' 'bad tag'"
check "unknown_subcommand_rejected"           "! '$SCRIPT' nonsense"

# Path-length class: a tag of any length maps to a bounded directory name, two
# long tags sharing a prefix never collide, and a short tag keeps its name.
LONG_TAG_A="gemini-$(printf 'x%.0s' $(seq 1 200))-a"; LONG_TAG_B="gemini-$(printf 'x%.0s' $(seq 1 200))-b"
LONG_PATH_A="$("$SCRIPT" path "$WT" "$LONG_TAG_A")"; LONG_PATH_B="$("$SCRIPT" path "$WT" "$LONG_TAG_B")"
check "long_tag_directory_name_is_bounded"    "test \"\$(basename '$LONG_PATH_A' | wc -c)\" -le 78"
check "long_tags_with_shared_prefix_differ"   "test '$LONG_PATH_A' != '$LONG_PATH_B'"
check "short_tag_directory_name_unchanged"    "basename \"\$('$SCRIPT' path '$WT' short-tag)\" | grep -Eq '^short-tag-[0-9a-f]{12}\$'"
mkdir -p "$TMP/isolated-long-home"
LONG_COPY="$(HOME="$TMP/isolated-long-home" "$SCRIPT" ensure-copy "$WT" "$LONG_TAG_A")"
check "long_tag_copy_builds_and_records_full_tag" "test -f '$LONG_COPY/AI-REVIEW-SANDBOX.md' && grep -Fqx 'Snapshot tag: $LONG_TAG_A' '$LONG_COPY/AI-REVIEW-SANDBOX.md'"
check "isolated_long_copy_keeps_bytes_and_reads_objects" "grep -qx long-path '$LONG_COPY/$LONG_REL' && HOME='$TMP/isolated-long-home' git -C '$LONG_COPY' show HEAD:a.txt | grep -qx base"
check "long_tag_copy_removes_by_recorded_tag"     "'$SCRIPT' remove-recorded '$LONG_TAG_A' '$LONG_COPY' && test ! -e '$LONG_COPY'"

# Keep false-source config on short paths: native source reads must remain
# possible before the snapshot gets its own independent long-path support.
FALSE_SOURCE="$TMP/short-source"
git init -q "$FALSE_SOURCE"
git -C "$FALSE_SOURCE" config user.email t@example.com
git -C "$FALSE_SOURCE" config user.name Test
printf 'short-file\n' > "$FALSE_SOURCE/a.txt"
git -C "$FALSE_SOURCE" add a.txt
git -C "$FALSE_SOURCE" commit -qm short-file
git -C "$FALSE_SOURCE" config core.longpaths false
FALSE_COPY="$(HOME="$TMP/isolated-long-home" "$SCRIPT" ensure-copy "$FALSE_SOURCE" source-false)"
check "source_false_copy_keeps_bytes_and_reads_objects" "grep -qx short-file '$FALSE_COPY/a.txt' && HOME='$TMP/isolated-long-home' git -C '$FALSE_COPY' show HEAD:a.txt | grep -qx short-file"
check "source_false_cannot_disable_owned_copy" "test \"\$(git -C '$FALSE_SOURCE' config --local --get core.longpaths)\" = false && test \"\$(HOME='$TMP/isolated-long-home' git -C '$FALSE_COPY' config --local --get core.longpaths)\" = true"

# --- store-before-delete for packets inside a sandbox (#1111) -----------------
# remove_sandbox must retain every managed packet before destroying the
# snapshot, because the sandbox may hold the only copy of review evidence.
PACKET_BIN="$REPO_ROOT/bin/ai-review-packet"
RET_STAGE="$("$SCRIPT" ensure-copy "$MAIN" retain-pkt)"
RET_PKT_DIR="$("$PACKET_BIN" build "$RET_STAGE" retain-pkt --tests 'true')"
check "sandbox_retain_fixture_builds_packet"  "[ -d '$RET_PKT_DIR' ] && [ -s '$RET_PKT_DIR/MANIFEST.md' ]"
"$SCRIPT" remove-copy "$MAIN" retain-pkt
check "remove_copy_retains_packet_before_delete" \
  "[ ! -d '$RET_STAGE' ] && [ -d '$MAIN/.ai/reviews/packets/.ai-review-retain-pkt' ]"
check "retained_sandbox_packet_has_full_evidence" \
  "[ -s '$MAIN/.ai/reviews/packets/.ai-review-retain-pkt/MANIFEST.md' ] && [ -s '$MAIN/.ai/reviews/packets/.ai-review-retain-pkt/patch.diff' ] && [ -f '$MAIN/.ai/reviews/packets/.ai-review-retain-pkt/identity.json' ] && [ -s '$MAIN/.ai/reviews/packets/.ai-review-retain-pkt/MANIFEST.sha256' ]"
check "retained_sandbox_packet_rebinds_marker" \
  "[ \"\$(sed -n '3p' '$MAIN/.ai/reviews/packets/.ai-review-retain-pkt/.ai-review-packet')\" = retained ]"

# #1355: batched stat/sha256sum must give the per-file reader's exact digest,
# including escaped names, and a failing or CRLF-emitting stat must not change it.
BATCH="$(mktemp -d)"; git init -q "$BATCH/r"
( cd "$BATCH/r" && echo a > t && git add t && git -c user.name=t -c user.email=t@t commit -qm i \
  && echo b >> t && printf x > '-lead' && printf y > $'new\nline' && printf z > 'back\slash' \
  && : > empty && ln -s t link && mkdir d && for i in $(seq 1 400); do echo "$i" > "d/file_with_a_long_enough_name_$i"; done )
mkdir -p "$BATCH/broken" "$BATCH/crlf"
printf '#!/bin/sh\nexit 1\n' > "$BATCH/broken/stat"
printf '#!/bin/sh\n%s "$@" | sed "s/$/\\r/"\n' "$(command -v stat)" > "$BATCH/crlf/stat"
chmod +x "$BATCH/broken/stat" "$BATCH/crlf/stat"
BATCH_FAST="$("$SCRIPT" digest "$BATCH/r")"
check "batched_digest_matches_per_file_fallback" \
  "[ -n '$BATCH_FAST' ] && [ \"\$(PATH='$BATCH/broken':\"\$PATH\" '$SCRIPT' digest '$BATCH/r')\" = '$BATCH_FAST' ]"
check "batched_digest_tolerates_crlf_stat" \
  "[ \"\$(PATH='$BATCH/crlf':\"\$PATH\" '$SCRIPT' digest '$BATCH/r')\" = '$BATCH_FAST' ]"
rm -rf "$BATCH"

# --- one privacy verdict per review (#1355) ---------------------------------
# A counting gate proves how often the classifier really runs. Reuse happens
# only inside a review's private scope, and only while every bound input holds.
PV="$TMP/privacy"; mkdir -p "$PV/bin" "$PV/scope"; chmod 700 "$PV/scope"
cat > "$PV/bin/ai-task-gates" <<'GATE'
#!/usr/bin/env bash
printf x >> "${PV_COUNT:?}"
class="$(cat "${PV_CLASS:?}")"
# Name inputs the way the real gate does (AI_TASK_GATES_INPUTS_TO), unless told not to.
if [ -n "${AI_TASK_GATES_INPUTS_TO:-}" ] && [ -z "${PV_NO_INPUTS:-}" ]; then
  { printf '%s\n' "$0" "${PV_STATE:?}" "$PWD/.ai-devops/task-gates.json"; [ -z "${PV_POLICY:-}" ] || printf '%s\n' "$PV_POLICY"; } > "$AI_TASK_GATES_INPUTS_TO"
fi
if [ -n "${PV_POLICY:-}" ]; then
  printf '{"effective_class":"%s","policy_file":"%s"}\n' "$class" "$PV_POLICY"
else
  printf '{"effective_class":"%s"}\n' "$class"
fi
GATE
chmod +x "$PV/bin/ai-task-gates"
git -C "$PV" init -q r; echo a > "$PV/r/a.txt"
export PV_COUNT="$PV/count" PV_CLASS="$PV/class" PV_STATE="$PV/state.json"
pv_runs(){ local c; c="$(cat "$PV_COUNT" 2>/dev/null)"; printf '%s' "${#c}"; }
pv(){ AI_TASK_GATES_BIN="$PV/bin/ai-task-gates" AI_REVIEW_PRIVACY_SCOPE="$PV/scope" "$SCRIPT" "$@" >/dev/null 2>&1; }
pv_reset(){ rm -f "$PV_COUNT" "$PV/scope"/*; echo "$1" > "$PV_CLASS"; echo '{}' > "$PV_STATE"; }
# A review this suite runs inside must not lend its scope to these cases.
unset AI_REVIEW_PRIVACY_SCOPE

pv_reset code
pv is-private "$PV/r"; r1=$?
pv assert-public "$PV/r"; r2=$?
pv is-private "$PV/r"; r3=$?
check "privacy_verdict_public_reused_within_scope" "[ $r1 = 1 ] && [ $r2 = 0 ] && [ $r3 = 1 ] && [ \"\$(pv_runs)\" = 1 ]"

pv_reset code
pv is-private "$PV/r"
echo new > "$PV/r/new.txt"
echo private-evidence > "$PV_CLASS"
pv is-private "$PV/r"; r=$?
check "privacy_verdict_new_file_reclassifies" "[ $r = 0 ] && [ \"\$(pv_runs)\" = 2 ]"
rm -f "$PV/r/new.txt"

pv_reset code
mkdir -p "$PV/r/.ai-devops"; echo '{}' > "$PV/r/.ai-devops/task-gates.json"
pv is-private "$PV/r"
echo '{"x":1}' > "$PV/r/.ai-devops/task-gates.json"
echo private-tooling > "$PV_CLASS"
pv is-private "$PV/r"; r=$?
check "privacy_verdict_declaration_change_reclassifies" "[ $r = 0 ] && [ \"\$(pv_runs)\" = 2 ]"
rm -rf "$PV/r/.ai-devops"

pv_reset code
echo v1 > "$PV/policy.json"
PV_POLICY="$PV/policy.json" pv is-private "$PV/r"
echo v2 > "$PV/policy.json"; echo private-evidence > "$PV_CLASS"
PV_POLICY="$PV/policy.json" pv is-private "$PV/r"; r=$?
check "privacy_verdict_policy_change_reclassifies" "[ $r = 0 ] && [ \"\$(pv_runs)\" = 2 ]"

pv_reset code
git -C "$PV/r" remote add origin https://example.invalid/a/b.git
pv is-private "$PV/r"
git -C "$PV/r" remote set-url origin https://example.invalid/a/c.git
pv is-private "$PV/r"
check "privacy_verdict_remote_change_reclassifies" "[ \"\$(pv_runs)\" = 2 ]"

pv_reset private-evidence
pv is-private "$PV/r"
pv assert-public "$PV/r"; r=$?
check "privacy_verdict_private_stays_private" "[ $r != 0 ] && [ \"\$(pv_runs)\" = 1 ]"

pv_reset none
pv is-private "$PV/r"; r1=$?
pv is-private "$PV/r"; r2=$?
check "privacy_verdict_unknown_never_stored" "[ $r1 = 2 ] && [ $r2 = 2 ] && [ \"\$(pv_runs)\" = 2 ]"

pv_reset code
for i in 1 2; do AI_TASK_GATES_BIN="$PV/bin/ai-task-gates" "$SCRIPT" is-private "$PV/r" >/dev/null 2>&1; done
check "privacy_verdict_no_scope_always_classifies" "[ \"\$(pv_runs)\" = 2 ]"

pv_reset code
ln -s "$PV/scope" "$PV/scope-link"
for i in 1 2; do AI_TASK_GATES_BIN="$PV/bin/ai-task-gates" AI_REVIEW_PRIVACY_SCOPE="$PV/scope-link" "$SCRIPT" is-private "$PV/r" >/dev/null 2>&1; done
check "privacy_verdict_linked_scope_ignored" "[ \"\$(pv_runs)\" = 2 ]"

pv_reset code
pv is-private "$PV/r"
for f in "$PV/scope"/*; do mv "$f" "$PV/planted"; ln -s "$PV/planted" "$f"; done
echo private-evidence > "$PV_CLASS"
pv is-private "$PV/r"; r=$?
# MSYS `ln -s` may copy instead of linking; only a real link proves this case.
if [ -L "$(ls -d "$PV/scope"/* | head -1)" ] || [ "$r" = 0 ]; then
  check "privacy_verdict_linked_record_ignored" "[ $r = 0 ] && [ \"\$(pv_runs)\" = 2 ]"
fi

pv_reset code
pv is-private "$PV/r"
echo '#' >> "$PV/bin/ai-task-gates"
pv is-private "$PV/r"
check "privacy_verdict_gate_change_reclassifies" "[ \"\$(pv_runs)\" = 2 ]"
pv_reset code
pv is-private "$PV/r"
echo '{"declared_class":"private-evidence"}' > "$PV_STATE"; echo private-evidence > "$PV_CLASS"
pv is-private "$PV/r"; r=$?
check "privacy_verdict_task_state_change_reclassifies" "[ $r = 0 ] && [ \"\$(pv_runs)\" = 2 ]"

pv_reset code
PV_NO_INPUTS=1 pv is-private "$PV/r"
PV_NO_INPUTS=1 pv is-private "$PV/r"
check "privacy_verdict_gate_without_inputs_never_stored" "[ \"\$(pv_runs)\" = 2 ] && [ -z \"\$(ls -A '$PV/scope')\" ]"

pv_reset code
pv is-private "$PV/r"
AI_TASK_GATES_FILE="$PV/other.json" pv is-private "$PV/r"
check "privacy_verdict_gate_setting_change_reclassifies" "[ \"\$(pv_runs)\" = 2 ]"

pv_reset code
pv is-private "$PV/r"
for f in "$PV/scope"/*; do chmod 644 "$f"; done
pv is-private "$PV/r"
check "privacy_verdict_shared_record_ignored" "[ \"\$(pv_runs)\" = 2 ]"

pv_reset code
pv is-private "$PV/r"
for f in "$PV/scope"/*; do printf 'ai-review-privacy-verdict-v1 %s public\n' "${f##*/}" > "$f"; chmod 600 "$f"; done
echo private-evidence > "$PV_CLASS"
pv is-private "$PV/r"; r=$?
check "privacy_verdict_record_without_inputs_ignored" "[ $r = 0 ] && [ \"\$(pv_runs)\" = 2 ]"
unset PV_COUNT PV_CLASS PV_STATE

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
