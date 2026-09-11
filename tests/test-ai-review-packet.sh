#!/usr/bin/env bash
# Tests for bin/ai-review-packet.
#
# Fully offline: real git, no network, no provider calls.
#
# The tests that matter most and must never be weakened:
#   - reviewer_retains_access_outside_the_packet : the packet is ADDITIVE. If a
#     future change turns it into a sealed room, the reviewer loses the
#     background it needs to judge a change and we have fixed the wrong problem.
#     See the header of bin/ai-review-packet and §6a of
#     plan_reviewer-system-repair.md.
#   - policy_files_are_referenced_not_inlined : the other half of that balance.
#     Inlining readable files buries the diff and re-creates the token blowout
#     this whole system exists to stop.
#   - oversized_patch_is_split_not_truncated : standing rule, no silent failures.
#   - remove_refuses_unmanaged : nothing this script did not create may be deleted.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-review-packet"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- a repo with a main branch, a feature branch, edits and an untracked file --
R="$TMP/repo"
mkdir -p "$R"
git -C "$R" init -q -b main
git -C "$R" config user.email t@example.com
git -C "$R" config user.name Test
mkdir -p "$R/docs"
echo base > "$R/a.txt"
echo 'policy text that must never be inlined' > "$R/docs/policy.md"
git -C "$R" add -A; git -C "$R" commit -qm init
BASE_SHA="$(git -C "$R" rev-parse HEAD)"

git -C "$R" checkout -q -b feature
echo changed > "$R/a.txt"
echo added > "$R/newfile.txt"
git -C "$R" add -A; git -C "$R" commit -qm feature
HEAD_SHA="$(git -C "$R" rev-parse HEAD)"
echo uncommitted >> "$R/a.txt"
echo brand-new > "$R/untracked.txt"

echo '== ai-review-packet'

PKT="$("$SCRIPT" build "$R" testtag --tests 'true' \
        --decision 'Approve or reject for production merge.' \
        --scope 'The patch in full.' --exclude 'Unrelated documentation.' \
        --pointer 'docs/policy.md:the rule this change must obey')"
M="$PKT/MANIFEST.md"

check "build_prints_the_packet_directory"     "[ -d '$PKT' ]"
check "packet_lives_inside_the_review_dir"    "[ \"\$(cd \"\$(dirname '$PKT')\" && pwd -P)\" = \"\$(cd '$R' && pwd -P)\" ] && [ \"\$(basename '$PKT')\" = '.ai-review-testtag' ]"
check "manifest_exists"                       "[ -s '$M' ]"

# Loaded Grok readiness waits observe this test-only marker while the packet is
# still being prepared. Production builds must ignore it completely.
PROGRESS_FILE="$TMP/packet-progress"
"$SCRIPT" remove "$R" progress
AI_DEVOPS_TEST_MODE=1 AI_REVIEW_SANDBOX_PROGRESS_FILE="$PROGRESS_FILE" \
  "$SCRIPT" build "$R" progress >/dev/null
check "test_mode_exposes_concrete_packet_phase_progress" "test \"\$(wc -l < '$PROGRESS_FILE')\" -ge 7"
rm -f "$PROGRESS_FILE"
"$SCRIPT" remove "$R" production-progress
AI_REVIEW_SANDBOX_PROGRESS_FILE="$PROGRESS_FILE" \
  "$SCRIPT" build "$R" production-progress >/dev/null
check "production_packet_build_ignores_test_progress_instrumentation" "test ! -e '$PROGRESS_FILE'"

# --- identity: full SHAs, derived by the wrapper -----------------------------
check "manifest_carries_full_head_sha"        "grep -qF '$HEAD_SHA' '$M'"
check "manifest_carries_full_base_sha"        "grep -qF '$BASE_SHA' '$M'"
check "shas_are_40_characters"                "[ \${#HEAD_SHA} -eq 40 ]"
check "base_selection_rule_is_stated"         "grep -q 'Base selection rule:' '$M'"
check "verdict_is_bound_to_head"              "grep -q 'applies to head' '$M'"

# shared-db #2709: fetched origin/main is authoritative when local main is
# stale. Otherwise an update-from-main merge makes unrelated mainline files
# appear to be undeclared branch work.
REMOTE_BASE_REPO="$TMP/remote-base"
mkdir -p "$REMOTE_BASE_REPO"
git -C "$REMOTE_BASE_REPO" init -q -b main
git -C "$REMOTE_BASE_REPO" config user.email t@example.com
git -C "$REMOTE_BASE_REPO" config user.name Test
echo base > "$REMOTE_BASE_REPO/base.txt"
git -C "$REMOTE_BASE_REPO" add -A && git -C "$REMOTE_BASE_REPO" commit -qm base
STALE_MAIN="$(git -C "$REMOTE_BASE_REPO" rev-parse HEAD)"
git -C "$REMOTE_BASE_REPO" checkout -q -b review-branch
echo reviewed > "$REMOTE_BASE_REPO/reviewed.txt"
git -C "$REMOTE_BASE_REPO" add reviewed.txt && git -C "$REMOTE_BASE_REPO" commit -qm reviewed
git -C "$REMOTE_BASE_REPO" checkout -q main
echo current-main > "$REMOTE_BASE_REPO/current-main.txt"
git -C "$REMOTE_BASE_REPO" add current-main.txt && git -C "$REMOTE_BASE_REPO" commit -qm current-main
CURRENT_MAIN="$(git -C "$REMOTE_BASE_REPO" rev-parse HEAD)"
git -C "$REMOTE_BASE_REPO" update-ref refs/remotes/origin/main "$CURRENT_MAIN"
git -C "$REMOTE_BASE_REPO" reset -q --hard "$STALE_MAIN"
git -C "$REMOTE_BASE_REPO" checkout -q review-branch
git -C "$REMOTE_BASE_REPO" merge -q --no-ff -m update-from-main refs/remotes/origin/main
REMOTE_PKT="$("$SCRIPT" build "$REMOTE_BASE_REPO" remote-base)"
check "packet_prefers_current_origin_main_over_stale_local_main" "grep -q '$CURRENT_MAIN' '$REMOTE_PKT/MANIFEST.md'"
check "remote_base_packet_keeps_only_reviewed_scope" "grep -q 'reviewed.txt' '$REMOTE_PKT/MANIFEST.md' && ! grep -q 'current-main.txt' '$REMOTE_PKT/MANIFEST.md'"

# --- what changed -------------------------------------------------------------
check "changed_files_listed"                  "grep -q 'a.txt' '$M' && grep -q 'newfile.txt' '$M'"
check "uncommitted_edits_listed"              "grep -q 'Uncommitted edits' '$M'"
check "untracked_files_listed"                "grep -q 'untracked.txt' '$M'"
check "packet_dir_not_listed_as_untracked"    "! grep -q '^.ai-review' '$M'"

# --- the patch ----------------------------------------------------------------
check "patch_file_written"                    "[ -s '$PKT/patch.diff' ]"
check "patch_contains_committed_change"       "grep -q '^+changed' '$PKT/patch.diff'"
check "patch_contains_uncommitted_change"     "grep -q '^+uncommitted' '$PKT/patch.diff'"
check "patch_not_inlined_into_manifest"       "! grep -q '^+uncommitted' '$M'"

# --- tests --------------------------------------------------------------------
check "test_result_recorded"                  "grep -q 'Exit code' '$M' && grep -q 'PASSED' '$M'"
check "test_duration_recorded"                "grep -q 'Measured duration:' '$M'"

"$SCRIPT" remove "$R"
PKT2="$("$SCRIPT" build "$R" notests)"
check "absent_tests_are_stated_not_implied"   "grep -q 'No tests were run' '$PKT2/MANIFEST.md'"
check "absent_tests_are_not_a_pass"           "! grep -q 'PASSED' '$PKT2/MANIFEST.md'"

FAILPKT="$TMP/failpkt"
"$SCRIPT" remove "$R"
PKT3="$("$SCRIPT" build "$R" failing --tests 'exit 3')"
check "failing_tests_recorded_as_failed"      "grep -q 'FAILED' '$PKT3/MANIFEST.md'"

# --- THE additive property ----------------------------------------------------
# The reviewer must still be able to read the repository. The packet adds; it
# never subtracts. Both halves are asserted: the file is reachable AND the
# manifest says so in words the model will act on.
check "reviewer_retains_access_outside_the_packet" \
  "[ -r '$R/docs/policy.md' ] && grep -q 'starting point, not a fence' '$PKT3/MANIFEST.md'"
check "manifest_invites_opening_other_files"  "grep -q 'Open anything you need' '$PKT3/MANIFEST.md'"

# --- the other half: pointers, not copies -------------------------------------
"$SCRIPT" remove "$R"
PKT="$("$SCRIPT" build "$R" ptr --pointer 'docs/policy.md:the rule this change must obey')"
M="$PKT/MANIFEST.md"
check "pointer_is_listed_by_path"             "grep -q 'docs/policy.md' '$M'"
check "policy_files_are_referenced_not_inlined" \
  "! grep -q 'policy text that must never be inlined' '$M'"
check "missing_pointer_is_flagged_loudly" \
  "'$SCRIPT' remove '$R'; '$SCRIPT' build '$R' miss --pointer 'docs/nope.md:x' >/dev/null && grep -q 'NOT PRESENT' '$R/.ai-review-miss/MANIFEST.md'"

# --- verdict contract ---------------------------------------------------------
"$SCRIPT" remove "$R"
PKT="$("$SCRIPT" build "$R" verdict)"
M="$PKT/MANIFEST.md"
check "requires_the_literal_verdict_heading"  "grep -qF '## Verdict' '$M'"
check "verdict_vocabulary_is_fixed"           "grep -q 'APPROVE' '$M' && grep -q 'BLOCKED' '$M'"
check "provisional_verdict_is_requested"      "grep -q 'Provisional verdict' '$M'"
check "provisional_cannot_approve"            "grep -q 'cannot approve a change' '$M'"

# --- hashing ------------------------------------------------------------------
check "hash_file_written"                     "[ -s '$PKT/MANIFEST.sha256' ]"
check "fresh_packet_verifies"                 "'$SCRIPT' verify '$PKT'"
check "hash_mismatch_fails_verification" \
  "echo tamper >> '$PKT/patch.diff'; ! '$SCRIPT' verify '$PKT'"
check "verify_rejects_a_non_packet"           "! '$SCRIPT' verify '$TMP'"

# --- oversized patch ----------------------------------------------------------
"$SCRIPT" remove "$R"
head -c 40000 /dev/urandom | base64 > "$R/big.txt"
git -C "$R" add -A; git -C "$R" commit -qm big
PKT="$(AI_REVIEW_PATCH_MAX_BYTES=2000 "$SCRIPT" build "$R" big)"
check "oversized_patch_is_split_not_truncated" \
  "[ -s '$PKT/patch.full.diff' ] && grep -q 'SPLIT BY ai-review-packet' '$PKT/patch.diff'"
check "split_is_announced_in_the_manifest"    "grep -q 'patch was split' '$PKT/MANIFEST.md'"
PART_COUNT="$(find "$PKT" -name 'patch.part-*' | wc -l)"
check "split_has_directly_readable_numbered_parts" \
  "[ '$PART_COUNT' -gt 1 ] && grep -q 'patch.part-000' '$PKT/MANIFEST.md'"
check "split_packet_still_verifies"           "'$SCRIPT' verify '$PKT'"

# --- long file lists ----------------------------------------------------------
# Regression for 2026-08-18: an unrelated untracked scratch directory produced a
# 33 KB manifest of filenames that buried the single changed file.
"$SCRIPT" remove "$R"
mkdir -p "$R/scratch"
for i in $(seq 1 60); do echo x > "$R/scratch/f$i.tmp"; done
PKT="$("$SCRIPT" build "$R" longlist)"
M="$PKT/MANIFEST.md"
check "long_untracked_list_spills_to_a_file"  "[ -s '$PKT/untracked-files.txt' ]"
check "spill_is_announced_in_the_manifest"    "grep -q 'COMPLETE list is in' '$M'"
check "spill_states_the_real_total"           "grep -q '6[0-9] entries in total' '$M'"
check "spill_drops_nothing"                   "[ \"\$(wc -l < '$PKT/untracked-files.txt')\" -ge 60 ]"
check "manifest_stays_small_despite_the_list" "[ \"\$(wc -c < '$M')\" -lt 12000 ]"
check "changed_file_is_still_visible"         "grep -q 'big.txt' '$M' || grep -q 'a.txt' '$M'"
rm -rf "$R/scratch"

# --- git hygiene --------------------------------------------------------------
check "packet_is_excluded_from_git"           "[ -z \"\$(git -C '$R' status --porcelain | grep ai-review)\" ]"
check "exclusion_is_not_written_to_gitignore" "[ ! -f '$R/.gitignore' ]"

# --- base resolution ----------------------------------------------------------
"$SCRIPT" remove "$R"
PKT="$("$SCRIPT" build "$R" explicitbase --base "$BASE_SHA")"
check "explicit_base_is_honoured"             "grep -q 'explicitly requested' '$PKT/MANIFEST.md'"
check "bad_base_is_refused_loudly"            "'$SCRIPT' remove '$R'; ! '$SCRIPT' build '$R' badbase --base deadbeefdeadbeef"

# A fetched target branch is authoritative over a stale local branch. This is
# the A/B/C regression: local main remains at A, origin/main advances to B, and
# the feature head C is based on B. Selecting A would include B's unrelated
# file in the review.
STALE="$TMP/stale-base"
ORIGIN="$TMP/stale-origin.git"
git init -q --bare --initial-branch=main "$ORIGIN"
git clone -q "$R" "$STALE"
git -C "$STALE" config user.email t@example.com
git -C "$STALE" config user.name Test
git -C "$STALE" remote set-url origin "$ORIGIN"
git -C "$STALE" checkout -q -B main "$BASE_SHA"
git -C "$STALE" push -q -u origin main
UPSTREAM="$TMP/stale-upstream"
git clone -q "$ORIGIN" "$UPSTREAM"
git -C "$UPSTREAM" config user.email t@example.com
git -C "$UPSTREAM" config user.name Test
echo target-only > "$UPSTREAM/target-only.txt"
git -C "$UPSTREAM" add -A && git -C "$UPSTREAM" commit -qm target-advanced && git -C "$UPSTREAM" push -q origin main
git -C "$STALE" fetch -q origin
STALE_REMOTE_SHA="$(git -C "$STALE" rev-parse origin/main)"
STALE_LOCAL_SHA="$(git -C "$STALE" rev-parse main)"
git -C "$STALE" checkout -q -B feature origin/main
echo feature-only > "$STALE/feature-only.txt"
git -C "$STALE" add -A && git -C "$STALE" commit -qm feature
STALE_PKT="$($SCRIPT build "$STALE" stale-origin)"
check "stale_local_main_differs_from_fetched_origin" "[ '$STALE_LOCAL_SHA' != '$STALE_REMOTE_SHA' ]"
check "fetched_origin_base_beats_stale_local_main" "grep -q '$STALE_REMOTE_SHA' '$STALE_PKT/MANIFEST.md'"
check "stale_base_packet_excludes_target_branch_work" "! grep -q 'target-only.txt' '$STALE_PKT/patch.diff' && grep -q 'feature-only.txt' '$STALE_PKT/patch.diff'"

# The caller resolves once, before the snapshot, and the sealed packet must
# preserve that identity. Wrong or moved input is refused before any provider.
git -C "$STALE" branch release "$STALE_REMOTE_SHA"
IDENTITY="$TMP/source-identity.json"
mkdir -p "$STALE/.ai-review-notes"
printf 'legitimate untracked source\n' > "$STALE/.ai-review-notes/feature.txt"
"$SCRIPT" resolve "$STALE" --base release --assert-head "$(git -C "$STALE" rev-parse HEAD)" > "$IDENTITY"
IDENTITY_SNAPSHOT="$("$REPO_ROOT/bin/ai-review-sandbox" ensure-copy "$STALE" identity-contract)"
IDENTITY_PACKET="$("$SCRIPT" build "$IDENTITY_SNAPSHOT" identity-contract --identity "$IDENTITY")"
check "non_main_target_survives_snapshot" "git -C '$IDENTITY_SNAPSHOT' rev-parse release >/dev/null && '$SCRIPT' verify '$IDENTITY_PACKET' --identity '$IDENTITY'"
check "packet_seals_original_repository_identity" "cmp -s '$IDENTITY' '$IDENTITY_PACKET/identity.json'"
check "packet_preserves_user_prefixed_source_directory" "grep -q '.ai-review-notes/feature.txt' '$IDENTITY_PACKET/MANIFEST.md' && test -f '$IDENTITY_SNAPSHOT/.ai-review-notes/feature.txt' && '$SCRIPT' verify '$IDENTITY_PACKET' --identity '$IDENTITY'"
mkdir -p "$STALE/.ai/reviews"
printf '.ai/\n' >> "$STALE/.git/info/exclude"
RECEIPT="$STALE/.ai/reviews/source-receipt.json"
check "verified_packet_publishes_exact_receipt" "AI_REVIEW_SOURCE_RECEIPT_FILE='$RECEIPT' '$SCRIPT' verify '$IDENTITY_PACKET' --identity '$IDENTITY' && jq -e --arg h \"\$(cat '$IDENTITY_PACKET/MANIFEST.sha256')\" '.packet_sha256==\$h and .schema_version==1' '$RECEIPT'"
check "same_receipt_publication_is_idempotent" "AI_REVIEW_SOURCE_RECEIPT_FILE='$RECEIPT' '$SCRIPT' verify '$IDENTITY_PACKET' --identity '$IDENTITY'"
printf '{}' > "$STALE/.ai/reviews/conflicting-receipt.json"
check "receipt_refuses_overwrite_of_other_evidence" "! AI_REVIEW_SOURCE_RECEIPT_FILE='$STALE/.ai/reviews/conflicting-receipt.json' '$SCRIPT' verify '$IDENTITY_PACKET' --identity '$IDENTITY'"
check "receipt_cannot_escape_private_report_directory" "! AI_REVIEW_SOURCE_RECEIPT_FILE='$TMP/outside-receipt.json' '$SCRIPT' verify '$IDENTITY_PACKET' --identity '$IDENTITY' && test ! -e '$TMP/outside-receipt.json'"
check "resolve_rejects_wrong_expected_head" "! '$SCRIPT' resolve '$STALE' --assert-head '$STALE_REMOTE_SHA'"
check "resolve_rejects_missing_target" "! '$SCRIPT' resolve '$STALE' --base refs/heads/missing"
jq --arg bad "$STALE_LOCAL_SHA" '.base=$bad' "$IDENTITY" > "$TMP/wrong-base.json"
check "build_rejects_forged_base_identity" "! '$SCRIPT' build '$IDENTITY_SNAPSHOT' wrong-base --identity '$TMP/wrong-base.json'"
jq --arg bad "$BASE_SHA" '.head=$bad' "$IDENTITY" > "$TMP/wrong-head.json"
check "build_rejects_forged_head_identity" "! '$SCRIPT' build '$IDENTITY_SNAPSHOT' wrong-head --identity '$TMP/wrong-head.json'"
echo changed-untracked > "$STALE/identity-new.txt"
check "identity_rejects_untracked_source_movement" "! '$SCRIPT' verify '$IDENTITY_PACKET' --identity '$IDENTITY'"
rm "$STALE/identity-new.txt"
git -C "$STALE" update-ref refs/heads/release HEAD
check "identity_rejects_target_movement" "! '$SCRIPT' verify '$IDENTITY_PACKET' --identity '$IDENTITY'"
git -C "$STALE" update-ref refs/heads/release "$STALE_REMOTE_SHA"
check "unchanged_identity_verifies_after_restoring_target" "'$SCRIPT' verify '$IDENTITY_PACKET' --identity '$IDENTITY'"
"$REPO_ROOT/bin/ai-review-sandbox" remove-copy "$STALE" identity-contract

# --- linked worktrees ---------------------------------------------------------
# A raw worktree kills a reviewer before it reads code. Refuse at the door and
# name the fix, rather than emitting a packet nobody can use.
WT="$TMP/wt"
git -C "$R" worktree add -q -b wtbranch "$WT" >/dev/null 2>&1
check "raw_worktree_is_refused"               "! '$SCRIPT' build '$WT' wt"
check "worktree_refusal_names_the_fix"        "'$SCRIPT' build '$WT' wt 2>&1 | grep -q 'ai-review-sandbox ensure'"

SNAP="$("$REPO_ROOT/bin/ai-review-sandbox" ensure "$WT" packettest)"
check "sandbox_snapshot_is_accepted"          "'$SCRIPT' build '$SNAP' wt >/dev/null"
check "snapshot_packet_verifies"              "'$SCRIPT' verify '$SNAP/.ai-review-wt'"
check "packet_manifest_binds_snapshot_digest" \
  "grep -Eq 'Whole-source digest: .[0-9a-f]{64}.' '$SNAP/.ai-review-wt/MANIFEST.md'"
echo stale-after-snapshot >> "$SNAP/a.txt"
check "stale_snapshot_digest_is_refused"      "! '$SCRIPT' build '$SNAP' stale-snapshot >/dev/null 2>&1"
check "stale_snapshot_packet_is_not_published" "[ ! -e '$SNAP/.ai-review-stale-snapshot' ]"
"$REPO_ROOT/bin/ai-review-sandbox" remove "$WT" packettest

# --- deletion safety ----------------------------------------------------------
"$SCRIPT" build "$R" deltag >/dev/null
"$SCRIPT" remove "$R" deltag
check "remove_deletes_its_own_packet"         "[ ! -d '$R/.ai-review-deltag' ]"
check "remove_is_idempotent"                  "'$SCRIPT' remove '$R' deltag"
GUARD="$TMP/guard/.ai-review"
mkdir -p "$GUARD"; touch "$GUARD/someone-elses-file"
git -C "$TMP/guard" init -q 2>/dev/null
check "remove_refuses_unmanaged"              "! '$SCRIPT' remove '$TMP/guard'; [ -f '$GUARD/someone-elses-file' ]"

# --- defects found by an independent Grok review, 2026-08-18 -------------------
# The original tests always removed the packet before rebuilding, so none of
# these were exercised. That blind spot is the reason they existed.
"$SCRIPT" remove "$R"

# 1. A rebuild must never inherit files from the previous run. patch.full.diff
#    only exists on oversized runs; if it survived into a small run it would be
#    hashed into the seal and `verify` would bless the mixture.
PKT="$(AI_REVIEW_PATCH_MAX_BYTES=2000 "$SCRIPT" build "$R" reb)"
check "setup: oversized run wrote a full patch"  "[ -f '$PKT/patch.full.diff' ]"
PKT="$("$SCRIPT" build "$R" reb)"
check "rebuild does not inherit stale files"     "[ ! -f '$PKT/patch.full.diff' ]"
check "rebuild verifies cleanly"                 "'$SCRIPT' verify '$PKT'"

# 2. An unmanaged .ai-review must be refused LOUDLY, not silently.
"$SCRIPT" remove "$R"
mkdir -p "$R/.ai-review-clash"; echo mine > "$R/.ai-review-clash/someone-elses-file"
check "unmanaged packet dir is refused"          "! '$SCRIPT' build '$R' clash"
check "refusal is not silent"                    "'$SCRIPT' build '$R' clash 2>&1 | grep -q 'refusing to overwrite'"
check "unmanaged packet dir survives"            "[ -f '$R/.ai-review-clash/someone-elses-file' ]"
rm -rf "$R/.ai-review-clash"

# 3. A --tests command that changes the tree must be announced, because the
#    patch and the file lists then describe the post-test tree.
PKT="$("$SCRIPT" build "$R" mut --tests 'echo mutated > side-effect.txt')"
check "tree change during tests is announced"    "grep -q 'test command changed the working tree' '$PKT/MANIFEST.md'"
rm -f "$R/side-effect.txt"
"$SCRIPT" remove "$R"
PKT="$("$SCRIPT" build "$R" nomut --tests 'true')"
check "a clean test run is not falsely flagged"  "! grep -q 'changed the working tree' '$PKT/MANIFEST.md'"

# 4. In a snapshot, the manifest must name the REAL checkout, not the throwaway.
"$SCRIPT" remove "$R"
SNAP="$("$REPO_ROOT/bin/ai-review-sandbox" ensure "$WT" realroot)"
"$SCRIPT" build "$SNAP" snap >/dev/null
check "manifest names the real checkout"         "grep -qF \"\$(cd '$WT' && pwd -P)\" '$SNAP/.ai-review-snap/MANIFEST.md'"
check "manifest says it is a snapshot"           "grep -q 'disposable snapshot' '$SNAP/.ai-review-snap/MANIFEST.md'"
"$REPO_ROOT/bin/ai-review-sandbox" remove "$WT" realroot

# --- two reviewers, one checkout (shared-db#1296) ------------------------------
# The defect: the packet directory was the single fixed name `.ai-review`, so a
# second reviewer starting from the SAME checkout deleted and rebuilt the first
# one's evidence while it was still being read. The first reviewer then judged a
# different change and its verdict looked completely normal.
#
# These are the properties that make that impossible. Do not relax them into
# warnings: silence is the entire failure mode.
PKT_A="$("$SCRIPT" build "$R" reviewer-alpha --decision 'Alpha decision.')"
PKT_B="$("$SCRIPT" build "$R" reviewer-beta  --decision 'Beta decision.')"
check "concurrent_sessions_get_separate_packets" "[ '$PKT_A' != '$PKT_B' ]"
check "first_packet_survives_the_second_build"   "[ -s '$PKT_A/MANIFEST.md' ]"
check "first_packet_still_verifies"              "'$SCRIPT' verify '$PKT_A'"
# The seal binds names and empty entries, not merely concatenated contents.
mv "$PKT_A/patch.diff" "$PKT_A/renamed.diff"
check "renamed_packet_file_breaks_seal"          "! '$SCRIPT' verify '$PKT_A'"
mv "$PKT_A/renamed.diff" "$PKT_A/patch.diff"
check "restored_packet_name_verifies"            "'$SCRIPT' verify '$PKT_A'"
touch "$PKT_A/empty-added.txt"
check "added_empty_file_breaks_seal"             "! '$SCRIPT' verify '$PKT_A'"
rm "$PKT_A/empty-added.txt"
mkdir -p "$PKT_A/nested"; printf nested > "$PKT_A/nested/MANIFEST.sha256"
check "nested_reserved_name_breaks_seal"          "! '$SCRIPT' verify '$PKT_A'"
rm -rf "$PKT_A/nested"
check "each_packet_keeps_its_own_brief"          "grep -q 'Alpha decision' '$PKT_A/MANIFEST.md' && grep -q 'Beta decision' '$PKT_B/MANIFEST.md'"
check "packet_is_named_after_the_session_tag"    "[ \"\$(basename '$PKT_A')\" = '.ai-review-reviewer-alpha' ]"

# Removing one session's packet must not touch the other's.
"$SCRIPT" remove "$R" reviewer-beta
check "remove_targets_only_the_named_session"    "[ ! -d '$PKT_B' ] && [ -s '$PKT_A/MANIFEST.md' ]"

# A tag too long for a sane directory name still gets its OWN packet: truncation
# that mapped two sessions onto one directory would reintroduce the defect.
LONG_A="session-$(printf 'x%.0s' $(seq 1 60))-alpha"
LONG_B="session-$(printf 'x%.0s' $(seq 1 60))-beta"
P1="$("$SCRIPT" build "$R" "$LONG_A")"; P2="$("$SCRIPT" build "$R" "$LONG_B")"
check "over_long_tags_do_not_collide"            "[ '$P1' != '$P2' ] && [ -s '$P1/MANIFEST.md' ]"
check "over_long_packet_name_stays_bounded"      "name=\$(basename '$P1'); [ \"\${#name}\" -le 59 ]"

# THE BACKSTOP. Per-tag naming already keeps sessions apart, so a build that
# lands on a packet owned by another tag means something is wrong. It must
# refuse and name both tags rather than delete evidence a reviewer is reading.
cp -r "$PKT_A" "$R/.ai-review-impostor"
check "foreign_owner_build_is_refused"           "! '$SCRIPT' build '$R' impostor"
check "refusal_names_both_tags"                  "'$SCRIPT' build '$R' impostor 2>&1 | grep -q 'reviewer-alpha' && '$SCRIPT' build '$R' impostor 2>&1 | grep -q 'impostor'"
check "refusal_leaves_the_evidence_intact"       "[ -s '$R/.ai-review-impostor/MANIFEST.md' ]"
check "refusal_says_how_to_clear_it"             "'$SCRIPT' build '$R' impostor 2>&1 | grep -q 'ai-review-packet remove'"
rm -rf "$R/.ai-review-impostor"

# Same tag = the same session rebuilding its own packet each turn. Always allowed.
PKT_A2="$("$SCRIPT" build "$R" reviewer-alpha)"
check "same_session_may_rebuild_its_own_packet"  "[ '$PKT_A2' = '$PKT_A' ] && '$SCRIPT' verify '$PKT_A2'"

# Every session's packet stays out of the change under review, not just one.
check "all_session_packets_excluded_from_git"    "[ -z \"\$(git -C '$R' status --porcelain | grep ai-review)\" ]"
"$SCRIPT" remove "$R" reviewer-alpha; "$SCRIPT" remove "$R" "$LONG_A"; "$SCRIPT" remove "$R" "$LONG_B"

# --- interface ----------------------------------------------------------------
check "path_creates_nothing"                  "'$SCRIPT' path '$R' nonesuch >/dev/null && [ ! -d '$R/.ai-review-nonesuch' ]"
check "unknown_subcommand_rejected"           "! '$SCRIPT' nonsense"
check "unknown_option_rejected"               "! '$SCRIPT' build '$R' t --bogus x"
check "non_git_directory_rejected"            "mkdir -p '$TMP/plain' && ! '$SCRIPT' build '$TMP/plain' t"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
