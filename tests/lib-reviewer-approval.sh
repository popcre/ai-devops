# shellcheck shell=bash
# mint_reviewer_approval <scratch-dir> <worktree> [mode] [head] [jq-row-override]
# Fixture for popcre/ai-devops#996: writes a reviewer report and the reviewer
# lifecycle row that records it as a completed APPROVE of <worktree>'s exact
# head and source digest, then prints the report path for --reviewer-approval.
# Requires AI_REVIEW_LIFECYCLE_DIR to point at the suite's private state and
# LIB_REVIEWER_APPROVAL_BIN at the bin/ directory under test.
mint_reviewer_approval(){
  local dir="$1" worktree="$2" mode="${3:-final-check}" head="${4:-}" extra="${5:-.}" base report identity key digest run state hash
  identity="$("$LIB_REVIEWER_APPROVAL_BIN/ai-review-lifecycle" identity "$worktree")" || return 1
  key="$(jq -r .repository_key <<<"$identity")"; digest="$(jq -r .source_digest <<<"$identity")"
  [ -n "$head" ] || head="$(jq -r .head <<<"$identity")"
  base="$(mktemp -d "$dir/approval.XXXXXX")"; run="$(basename "$base" | tr -c 'A-Za-z0-9\n' x)"
  report="$base/grok-$mode-$run.md"
  printf '| reviewed commit | `%s` |\n\n## Verdict\nAPPROVE\n' "$head" > "$report"
  report="$(realpath -- "$report")"; hash="$(sha256sum "$report" | cut -d' ' -f1)"
  state="$AI_REVIEW_LIFECYCLE_DIR/runs/$key/grok/claude/$run.json"
  mkdir -p "$(dirname "$state")"
  jq -n --arg h "$head" --arg p "$report" --arg s "$hash" --arg k "$key" --arg d "$digest" --arg r "$run" --arg m "$mode" \
    '{schema_version:1,status:"completed",provider:"grok",caller:"zcode",implementer_engine:"claude",review_mode:$m,run_id:$r,repository_key:$k,source_digest:$d,head:$h,verdict:"APPROVE",stale:false,report_path:$p,report_sha256:$s}' \
    | jq "$extra" > "$state"
  printf '%s\n' "$report"
}
