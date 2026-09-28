# shellcheck shell=bash
# mint_reviewer_approval <out-dir> <action> <head> <repository> [jq-override]
# Writes a lifecycle-recorded APPROVE report for <head> and the 0600 approval
# record that names it (popcre/ai-devops#996), then prints the record path.
# Requires AI_REVIEW_LIFECYCLE_DIR to point at the suite's private state.
mint_reviewer_approval(){
  local dir="$1" action="$2" head="$3" repo="$4" extra="${5:-.}" base report state file hash
  base="$(mktemp -d "$dir/approval.XXXXXX")"
  report="$base/report.md"; file="$base/approval.json"
  printf '| reviewed commit | `%s` |\n\n## Verdict\nAPPROVE\n' "$head" > "$report"
  hash="$(sha256sum "$report" | cut -d' ' -f1)"
  state="$AI_REVIEW_LIFECYCLE_DIR/runs/fixture/grok/test/$(basename "$base").json"
  mkdir -p "$(dirname "$state")"
  jq -n --arg h "$head" --arg p "$report" --arg s "$hash" \
    '{provider:"grok",status:"completed",verdict:"APPROVE",stale:false,head:$h,report_path:$p,report_sha256:$s}' > "$state"
  jq -n --arg a "$action" --arg h "$head" --arg r "$repo" --arg p "$report" \
    '{schema_version:1,verdict:"APPROVE",reviewer_engine:"grok",implementer_engine:"claude",assignment:"alloc-test-1",action:$a,repository:$r,head:$h,report:$p}' \
    | jq "$extra" > "$file"
  chmod 600 "$file"
  printf '%s\n' "$file"
}
