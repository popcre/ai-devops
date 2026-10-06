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

# Synthetic test repositories are intentionally unregistered. Declare only
# these fixtures public; the production path still fails closed on unknowns.
mkdir -p "$TMP/mockbin"
cat > "$TMP/mockbin/ai-task-gates" <<'EOF'
#!/usr/bin/env bash
printf '{"identity_resolved":true,"effective_class":"code","observed_class":"code"}\n'
EOF
chmod +x "$TMP/mockbin/ai-task-gates"
export PATH="$TMP/mockbin:$PATH"

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

# A governed review brief can exceed the kernel's per-argument limit. Keep the
# entire request in the sealed manifest without routing it through argv.
LONG_DECISION="$TMP/long-decision.txt"
{ printf 'START-LONG-BRIEF\n'; head -c 220000 /dev/zero | tr '\0' X; printf '\nEND-LONG-BRIEF\n'; } > "$LONG_DECISION"
LONG_PKT="$("$SCRIPT" build "$R" long-decision --decision-file "$LONG_DECISION")"
check "large_decision_file_is_preserved_exactly" "python3 - '$LONG_DECISION' '$LONG_PKT/MANIFEST.md' <<'PY'
import pathlib, sys
decision = pathlib.Path(sys.argv[1]).read_text().rstrip('\\n')
manifest = pathlib.Path(sys.argv[2]).read_text()
actual = manifest.split('## 6. The decision requested\\n\\n', 1)[1].split('\\n\\n## 7. Scope', 1)[0]
assert actual == decision
PY"
check "large_decision_packet_verifies" "'$SCRIPT' verify '$LONG_PKT'"
check "decision_file_and_text_are_exclusive" "! '$SCRIPT' build '$R' invalid-decision --decision text --decision-file '$LONG_DECISION' >/dev/null 2>&1 && ! '$SCRIPT' build '$R' invalid-decision --decision-file '$LONG_DECISION' --decision text >/dev/null 2>&1"
# On Windows CI runners, ln -s may fall back to a copy; only assert the
# symlink refusal on a real link (same pattern as test-ai-review-sandbox-delete-guard).
ln -s "$LONG_DECISION" "$TMP/decision-link" 2>/dev/null
if [ -L "$TMP/decision-link" ]; then
  check "decision_file_symlink_is_refused" "! '$SCRIPT' build '$R' invalid-decision --decision-file '$TMP/decision-link' >/dev/null 2>&1"
else
  skip "decision_file_symlink_is_refused (this filesystem cannot create a real symlink)"
fi
check "missing_decision_file_is_refused" "! '$SCRIPT' build '$R' invalid-decision --decision-file '$TMP/missing-decision' >/dev/null 2>&1"
check "empty_decision_file_is_refused" ": > '$TMP/empty-decision' && ! '$SCRIPT' build '$R' invalid-decision --decision-file '$TMP/empty-decision' >/dev/null 2>&1"

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
check "manifest_demands_every_finding_and_sibling_issues" "grep -q 'report EVERY finding' '$M' && grep -q 'sibling issues' '$M'"
for wrapper in ai-claude-review ai-codex-review ai-deepseek-agent ai-gemini ai-glm ai-grok-review ai-kimi ai-muse ai-qwen ai-stepfun; do
  check "reviewer_${wrapper}_reads_the_shared_manifest_prompt" "grep -q 'MANIFEST[.]md' '$REPO_ROOT/bin/$wrapper' && grep -Eq 'Return ALL findings|MANIFEST[.]md first|MANIFEST[.]md in this directory|source_files=[(]..saved/MANIFEST' '$REPO_ROOT/bin/$wrapper'"
done

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

# --- evidence duration warning (issue #608, Fix A) -----------------------------
# The convention: --tests attaches the FOCUSED unit suite (seconds); full suites
# belong to PR CI and the merge queue. A slow command must warn on stderr AND
# seal a ⚠️ into the manifest the reviewer reads — but never fail the build.
SLOW_ERR="$TMP/slow-evidence.stderr"
PKT_SLOW="$(AI_REVIEW_TEST_WARN_SECONDS=0 "$SCRIPT" build "$R" slowev --tests 'true' 2>"$SLOW_ERR")"
check "slow_test_command_warns" \
  "[ -d '$PKT_SLOW' ] && grep -q 'ai-review-packet: warning:' '$SLOW_ERR' && grep -q 'focused unit suite' '$SLOW_ERR' && grep -q 'evidence command was slow' '$PKT_SLOW/MANIFEST.md' && grep -qF '⚠️' '$PKT_SLOW/MANIFEST.md'"
check "slow_evidence_warning_is_advisory_not_fatal" "'$SCRIPT' verify '$PKT_SLOW'"
"$SCRIPT" remove "$R" slowev
FAST_ERR="$TMP/fast-evidence.stderr"
PKT_FAST="$("$SCRIPT" build "$R" fastev --tests 'true' 2>"$FAST_ERR")"
check "fast_test_command_is_not_flagged" \
  "[ -d '$PKT_FAST' ] && ! grep -q 'ai-review-packet: warning:' '$FAST_ERR' && ! grep -qF '⚠️' '$PKT_FAST/MANIFEST.md'"
"$SCRIPT" remove "$R" fastev

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

# --- CRLF-emitting jq (#1266 residual) ----------------------------------------
# jq.exe on Windows ends every -r line with CRLF, so identity fields captured
# for verification carried a trailing CR and verify died with
# source-head-mismatch / source-base-mismatch. A jq shim reproducing the
# artifact must leave resolve+verify working.
CRLF_BIN="$TMP/crlfjq"; mkdir -p "$CRLF_BIN"
REAL_JQ="$(command -v jq)"
cat > "$CRLF_BIN/jq" <<SHIM
#!/bin/sh
# jq.exe on Windows: CRLF on every stdout line, exit codes intact (jq -e
# truthiness decides privacy classification), so the shim keeps both.
_t="\$(mktemp 2>/dev/null)" || _t="./.jq-crlf.\$\$"
"$REAL_JQ" "\$@" > "\$_t"
_rc=\$?
sed 's/\$/\r/' "\$_t"
rm -f "\$_t"
exit "\$_rc"
SHIM
chmod +x "$CRLF_BIN/jq"
printf '{"a":"b"}\n' | "$CRLF_BIN/jq" -r .a | od -c | grep -q '\\r' \
  || bad 'crlf jq shim does not emit CR'
CRLF_ID="$TMP/crlf-identity.json"
PATH="$CRLF_BIN:$PATH" "$SCRIPT" resolve "$R" > "$CRLF_ID" 2>/dev/null
if PATH="$CRLF_BIN:$PATH" "$SCRIPT" verify "$PKT" --identity "$CRLF_ID" >/dev/null 2>&1; then
  ok crlf_jq_resolve_and_verify_succeed
else
  bad crlf_jq_resolve_and_verify_succeed
fi
# A value that GENUINELY ends in CR must survive byte-exact on an LF-emitting
# jq (codex final-check rounds 2 and 3): an unconditional strip would silently
# accept this identity against the clean repository path, so the refusal is
# the proof. The rewrite goes through python, not sed: $R contains the sed
# delimiter and a broken substitution would fake the refusal.
CR_ID="$TMP/cr-identity.json"
PATH="$CRLF_BIN:$PATH" "$SCRIPT" resolve "$R" 2>/dev/null > "$CR_ID"
CR_OK=0
python - "$CR_ID" "$R" <<'PY' || CR_OK=1
import json, sys
path, repo = sys.argv[1], sys.argv[2]
data = json.load(open(path, encoding="utf-8"))
data["repository"] = repo + "\r"
with open(path, "w", encoding="utf-8", newline="") as fh:
    json.dump(data, fh)
PY
if [ "$CR_OK" = 1 ]; then
  bad genuine_trailing_cr_rewrite_failed
elif PATH="$CRLF_BIN:$PATH" "$SCRIPT" verify "$PKT" --identity "$CR_ID" >/dev/null 2>&1; then
  bad genuine_trailing_cr_repository_is_stripped
else
  ok genuine_trailing_cr_repository_refused_byte_exact
fi

check "live-source_packet_is_not_retained_evidence" "! '$SCRIPT' verify-retained '$PKT'"
check "hash_mismatch_fails_verification" \
  "echo tamper >> '$PKT/patch.diff'; ! '$SCRIPT' verify '$PKT'"
check "retained_verification_rejects_tampering" "! '$SCRIPT' verify-retained '$PKT'"
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
# The snapshot request forwards the explicit base exactly as the wrappers do
# (issue #711: bounded snapshots carry the base-ref candidates plus the
# caller's AI_REVIEW_SANDBOX_BASE hint, and no longer every branch).
git -C "$STALE" branch release "$STALE_REMOTE_SHA"
IDENTITY="$TMP/source-identity.json"
mkdir -p "$STALE/.ai-review-notes"
printf 'legitimate untracked source\n' > "$STALE/.ai-review-notes/feature.txt"
"$SCRIPT" resolve "$STALE" --base release --assert-head "$(git -C "$STALE" rev-parse HEAD)" > "$IDENTITY"
IDENTITY_SNAPSHOT="$(AI_REVIEW_SANDBOX_BASE=release "$REPO_ROOT/bin/ai-review-sandbox" ensure-copy "$STALE" identity-contract)"
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
check "retained_packet_survives_proven_source_movement" "'$SCRIPT' verify-retained '$IDENTITY_PACKET'"
check "retained_verification_preserves_stale_evidence_without_receipt" "AI_REVIEW_SOURCE_RECEIPT_FILE='$STALE/.ai/reviews/retained-must-not-authorize.json' '$SCRIPT' verify-retained '$IDENTITY_PACKET' > '$TMP/retained.log' && grep -q NON-AUTHORIZING '$TMP/retained.log' && test ! -e '$STALE/.ai/reviews/retained-must-not-authorize.json'"
echo snapshot-tamper > "$IDENTITY_SNAPSHOT/retained-tamper.txt"
check "retained_verification_refuses_changed_snapshot" "! '$SCRIPT' verify-retained '$IDENTITY_PACKET'"
rm "$IDENTITY_SNAPSHOT/retained-tamper.txt"
printf 'tamper' >> "$IDENTITY_PACKET/MANIFEST.md"
check "retained_verification_refuses_changed_packet" "! '$SCRIPT' verify-retained '$IDENTITY_PACKET'"
head -c -6 "$IDENTITY_PACKET/MANIFEST.md" > "$TMP/restored-manifest"; mv "$TMP/restored-manifest" "$IDENTITY_PACKET/MANIFEST.md"
rm "$STALE/identity-new.txt"
# Re-scoped 2026-09-18 (issue #608) — re-scoped, NEVER deleted: this check used
# to move the target ref FORWARD to HEAD and expect refusal. A forward move that
# keeps the recorded tip an ancestor of the live tip is now tolerated (covered
# by forward_moved_target_still_verifies below). What must still refuse is a
# REWRITE that orphans the recorded tip: $STALE_LOCAL_SHA is stale main (A),
# which does NOT contain the recorded release tip (B), so pointing release at
# it is exactly that rewrite.
git -C "$STALE" update-ref refs/heads/release "$STALE_LOCAL_SHA"
check "identity_rejects_target_movement" "! '$SCRIPT' verify '$IDENTITY_PACKET' --identity '$IDENTITY' 2> '$TMP/rescoped-rewrite.log' && grep -q 'source-target-rewritten' '$TMP/rescoped-rewrite.log' && grep -q 'refs/ai-review-packets/identity-contract' '$TMP/rescoped-rewrite.log'"
git -C "$STALE" update-ref refs/heads/release "$STALE_REMOTE_SHA"
check "unchanged_identity_verifies_after_restoring_target" "'$SCRIPT' verify '$IDENTITY_PACKET' --identity '$IDENTITY'"
"$REPO_ROOT/bin/ai-review-sandbox" remove-copy "$STALE" identity-contract

# The per-tag private base ref pins the recorded base in the REAL source
# checkout. Prove the full anti-GC property: with the release ref, the fetched
# origin/main, and EVERY branch that contains the recorded base deleted (HEAD
# detached onto stale main first so feature can go), plus reflogs expired, a
# prune-gc must still find the recorded base — held only by
# refs/ai-review-packets/identity-contract.
check "base_ref_survives_for_retained_evidence" \
  "git -C '$STALE' update-ref -d refs/ai-review-packets/stale-origin && git -C '$STALE' update-ref -d refs/heads/release && git -C '$STALE' update-ref --no-deref -d refs/remotes/origin/HEAD && git -C '$STALE' update-ref -d refs/remotes/origin/feature && git -C '$STALE' update-ref -d refs/remotes/origin/main && git -C '$STALE' checkout -q --detach '$STALE_LOCAL_SHA' && git -C '$STALE' branch -D feature main >/dev/null && git -C '$STALE' reflog expire --expire=now --all && git -C '$STALE' gc --prune=now --quiet && [ \"\$(git -C '$STALE' for-each-ref --format='x' 'refs/heads' 'refs/remotes' | wc -l)\" -eq 0 ] && [ \"\$(git -C '$STALE' rev-parse refs/ai-review-packets/identity-contract)\" = '$STALE_REMOTE_SHA' ] && git -C '$STALE' cat-file -e '$STALE_REMOTE_SHA'"

# --- target ref movement under sealed evidence (issue #608, Fix B) -------------
# The 2026-09-17/18 incident: unrelated work landing on the target ref during a
# slow evidence run destroyed two complete review rounds. A FORWARD move of the
# target ref is now tolerated — the recorded tip is still an ancestor of the
# live tip, so the sealed base..head diff is byte-identical — while a rewrite,
# a deletion, or a HEAD move still refuses loudly.
FWD="$TMP/forward-move"
mkdir -p "$FWD"
git -C "$FWD" init -q -b main
git -C "$FWD" config user.email t@example.com
git -C "$FWD" config user.name Test
echo fork > "$FWD/f.txt"
git -C "$FWD" add -A; git -C "$FWD" commit -qm fork
git -C "$FWD" checkout -q -b feature
echo reviewed > "$FWD/feature.txt"
git -C "$FWD" add -A; git -C "$FWD" commit -qm feature
# Advance main once BEFORE sealing so the recorded target tip differs from the
# recorded base (the merge-base) — the exact shape the incident had.
git -C "$FWD" checkout -q main
echo landed > "$FWD/landed.txt"
git -C "$FWD" add -A; git -C "$FWD" commit -qm landed-before-seal
git -C "$FWD" checkout -q feature
FWD_RECORDED_TIP="$(git -C "$FWD" rev-parse main)"
FWD_BASE="$(git -C "$FWD" merge-base feature main)"
[ "$FWD_RECORDED_TIP" != "$FWD_BASE" ] || { echo "fixture broken: target tip equals merge-base" >&2; exit 1; }
FWD_PKT="$("$SCRIPT" build "$FWD" fwd --tests 'true')"
check "forward_fixture_records_main_as_target" "grep -qF '\"target_ref\": \"main\"' '$FWD_PKT/identity.json' && grep -q '$FWD_RECORDED_TIP' '$FWD_PKT/identity.json'"
check "base_ref_written_at_build" "[ \"\$(git -C '$FWD' rev-parse refs/ai-review-packets/fwd)\" = '$FWD_BASE' ]"

# The target ref moves FORWARD by one commit after sealing — without touching
# the checked-out feature worktree — and the sealed packet must still verify,
# with one explicit line naming the ref, the recorded tip, and the current tip.
FWD_NEW_TIP="$(git -C "$FWD" commit-tree "$(git -C "$FWD" rev-parse 'main^{tree}')" -p "$FWD_RECORDED_TIP" -m landed-after-seal)"
git -C "$FWD" update-ref refs/heads/main "$FWD_NEW_TIP"
check "forward_moved_target_still_verifies" "'$SCRIPT' verify '$FWD_PKT' > '$TMP/forward.log' 2>&1 && grep -q 'moved forward' '$TMP/forward.log' && grep -q '$FWD_RECORDED_TIP' '$TMP/forward.log' && grep -q '$FWD_NEW_TIP' '$TMP/forward.log'"

# A REWRITE that orphans the recorded tip must refuse loudly, naming the rewrite
# and the private ref that preserved the base — and the base object must still
# be there, pinned by that ref.
FWD_REWRITE="$(git -C "$FWD" commit-tree "$(git -C "$FWD" rev-parse 'main^{tree}')" -m rewritten-history)"
git -C "$FWD" update-ref refs/heads/main "$FWD_REWRITE"
check "rewritten_target_refuses_loudly" "! '$SCRIPT' verify '$FWD_PKT' > '$TMP/rewrite.log' 2>&1 && grep -q 'source-target-rewritten' '$TMP/rewrite.log' && grep -q 'refs/ai-review-packets/fwd' '$TMP/rewrite.log' && grep -q '$FWD_RECORDED_TIP' '$TMP/rewrite.log' && git -C '$FWD' cat-file -e '$FWD_BASE'"

# A DELETED target ref refuses as missing.
git -C "$FWD" update-ref -d refs/heads/main
check "deleted_target_ref_refuses" "! '$SCRIPT' verify '$FWD_PKT' 2> '$TMP/deleted.log' && grep -q 'source-target-missing' '$TMP/deleted.log'"

# HEAD movement stays byte-strict: it fires before the (already unreachable)
# target checks and names the real cause.
echo moved >> "$FWD/feature.txt"
git -C "$FWD" add -A; git -C "$FWD" commit -qm head-moved
check "head_movement_still_refuses" "! '$SCRIPT' verify '$FWD_PKT' 2> '$TMP/head.log' && grep -q 'source-head-mismatch' '$TMP/head.log'"

# remove deletes only its own tag's private base ref, never another tag's.
"$SCRIPT" build "$R" refkeep >/dev/null
"$SCRIPT" build "$R" refgone >/dev/null
"$SCRIPT" remove "$R" refgone
check "remove_deletes_only_own_base_ref" "! git -C '$R' rev-parse --verify --quiet refs/ai-review-packets/refgone >/dev/null && git -C '$R' rev-parse --verify --quiet refs/ai-review-packets/refkeep >/dev/null"
"$SCRIPT" remove "$R" refkeep

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

# --- store-before-delete evidence retention (#1111) ---------------------------
# Deleting a managed packet must leave a full durable copy in the ignored
# .ai/reviews/packets/ store, and that copy must still pass verify-retained
# after the original review root is gone. If the store cannot be written and
# verified, the delete is skipped so the only copy is never lost.

RET_R="$TMP/retain-repo"
mkdir -p "$RET_R"
git -C "$RET_R" init -q -b main
git -C "$RET_R" config user.email t@example.com
git -C "$RET_R" config user.name Test
echo base > "$RET_R/a.txt"
git -C "$RET_R" add -A; git -C "$RET_R" commit -qm init
git -C "$RET_R" checkout -q -b feature
echo changed > "$RET_R/a.txt"
git -C "$RET_R" add -A; git -C "$RET_R" commit -qm feature

# 1. remove_packet stores a full managed packet before delete.
RET_PKT="$("$SCRIPT" build "$RET_R" retainer --tests 'true')"
"$SCRIPT" remove "$RET_R" retainer
RET_DEST="$RET_R/.ai/reviews/packets/.ai-review-retainer"
check "remove_stores_full_packet_before_delete" \
  "[ ! -d '$RET_PKT' ] && [ -d '$RET_DEST' ]"
check "retained_copy_has_manifest"            "[ -s '$RET_DEST/MANIFEST.md' ]"
check "retained_copy_has_patch"               "[ -s '$RET_DEST/patch.diff' ]"
check "retained_copy_has_identity"            "[ -f '$RET_DEST/identity.json' ]"
check "retained_copy_has_seal"                "[ -s '$RET_DEST/MANIFEST.sha256' ]"
check "retained_copy_has_marker"              "[ -f '$RET_DEST/.ai-review-packet' ]"
check "retained_copy_marker_rebinds" \
  "case \"\$(sed -n '3p' '$RET_DEST/.ai-review-packet')\" in retained|retained-live) [ -n \"\$(sed -n '4p' '$RET_DEST/.ai-review-packet')\" ] ;; *) false ;; esac"

# 2. If store/verify fails, delete is skipped and the original remains.
RET2_PKT="$("$SCRIPT" build "$RET_R" skipdel --tests 'true')"
echo tamper >> "$RET2_PKT/patch.diff"
check "corrupt_packet_remove_skips_delete" \
  "! '$SCRIPT' remove '$RET_R' skipdel 2>/dev/null && [ -d '$RET2_PKT' ]"

# 3. A correctly retained isolated-snapshot packet passes verify-retained after
#    relocation (the re-bind fix). A live-source retained copy must NOT.
RET_WT="$TMP/retain-wt"
git -C "$RET_R" worktree add -q -b retain-branch "$RET_WT" >/dev/null 2>&1
echo snap-only > "$RET_WT/snap.txt"
git -C "$RET_WT" add -A; git -C "$RET_WT" commit -qm snap
RET_SNAP="$("$REPO_ROOT/bin/ai-review-sandbox" ensure-copy "$RET_R" relocate)"
RET_IPKT="$("$SCRIPT" build "$RET_SNAP" relocate --tests 'true')"
check "snapshot_packet_verifies_retained_while_root_lives" \
  "'$SCRIPT' verify-retained '$RET_IPKT'"
RET_IDEST="$("$SCRIPT" retain "$RET_IPKT")"
check "retain_prints_durable_path" \
  "[ -d '$RET_IDEST' ] && [ \"\$(basename '$RET_IDEST')\" = '.ai-review-relocate' ]"
check "isolated_retained_marker_says_retained" \
  "[ \"\$(sed -n '3p' '$RET_IDEST/.ai-review-packet')\" = retained ]"
check "live_source_retained_copy_is_not_retained_evidence" \
  "! '$SCRIPT' verify-retained '$RET_DEST'"
"$REPO_ROOT/bin/ai-review-sandbox" remove-copy "$RET_R" relocate
check "retained_packet_passes_verify_retained_after_relocation" \
  "'$SCRIPT' verify-retained '$RET_IDEST'"
check "retained_copy_survives_original_root_deletion" \
  "[ ! -d '$RET_SNAP' ] && [ -s '$RET_IDEST/MANIFEST.md' ]"

# 4. Tampered dest (matching line-4 orig_hash but damaged evidence) is never
#    accepted as already-retained. retain must not return success while the
#    store is still broken, and remove must not delete the only good copy.
RET3_PKT="$("$SCRIPT" build "$RET_R" tamperdest --tests 'true')"
RET3_DEST="$("$SCRIPT" retain "$RET3_PKT")"
echo RETAIN-TAMPER >> "$RET3_DEST/patch.diff"
check "tampered_dest_is_not_accepted_as_already_retained" \
  "! '$SCRIPT' retain '$RET3_PKT' >/dev/null 2>&1"
check "remove_with_unverified_dest_skips_delete" \
  "! '$SCRIPT' remove '$RET_R' tamperdest 2>/dev/null && [ -d '$RET3_PKT' ]"

# 5. retain of a packet already at its durable destination (dest == d) must
#    not rm/cp onto its own input. Already-in-store only when that copy verifies.
RET4_PKT="$("$SCRIPT" build "$RET_R" selfstore --tests 'true')"
RET4_DEST="$("$SCRIPT" retain "$RET4_PKT")"
check "retain_of_packet_already_at_dest_does_not_destroy_input" \
  "'$SCRIPT' retain '$RET4_DEST' >/dev/null && [ -d '$RET4_DEST' ] && [ -s '$RET4_DEST/MANIFEST.md' ] && [ -f '$RET4_DEST/identity.json' ] && [ -s '$RET4_DEST/patch.diff' ] && [ -s '$RET4_DEST/MANIFEST.sha256' ]"
echo RETAIN-TAMPER2 >> "$RET4_DEST/patch.diff"
check "retain_of_broken_packet_at_dest_fails_without_deleting" \
  "! '$SCRIPT' retain '$RET4_DEST' >/dev/null 2>&1 && [ -d '$RET4_DEST' ] && [ -s '$RET4_DEST/MANIFEST.md' ]"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
