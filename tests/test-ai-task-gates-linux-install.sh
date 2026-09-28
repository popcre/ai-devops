#!/usr/bin/env bash
# Exercise the real Linux source gate using only temporary checkouts and
# launcher/manifest paths. The fixture mode refuses GitHub origins.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d /tmp/ai-task-gates-linux.XXXXXX)"
trap 'rm -rf -- "$TMP"' EXIT
export AI_TASK_GATES_INSTALL_TEST_MODE=1 AI_TASK_GATES_TEST_ROOT="$TMP" AI_TASK_GATES_DIR="$TMP/state"
export AI_TASK_GATES_FILE="$ROOT/config/task-gates.json"
mkdir -p "$TMP/state" "$TMP/bin" "$TMP/etc" "$TMP/installed/bin" "$TMP/installed/tools/lib" "$TMP/installed/config" "$TMP/installed/.ai-devops"
git init -q --bare --initial-branch=main "$TMP/origin.git"
git init -q --initial-branch=main "$TMP/installed"
git -C "$TMP/installed" config user.name Test
git -C "$TMP/installed" config user.email test@example.invalid
git -C "$TMP/installed" remote add origin "file://$TMP/origin.git"
cp "$ROOT/bin/ai-task-gates" "$TMP/installed/bin/ai-task-gates"
cp "$ROOT/bin/ai-review-sandbox" "$TMP/installed/bin/ai-review-sandbox"
cp "$ROOT/bin/ai-review-lifecycle" "$TMP/installed/bin/ai-review-lifecycle"
cp "$ROOT/tools/lib/task-gates.sh" "$TMP/installed/tools/lib/task-gates.sh"
cp "$ROOT/config/task-gates.json" "$TMP/installed/config/task-gates.json"
cp "$ROOT/.ai-devops/task-gates.json" "$TMP/installed/.ai-devops/task-gates.json"
printf 'old\n' > "$TMP/installed/tools/helper.sh"
git -C "$TMP/installed" add .
git -C "$TMP/installed" commit -qm base
old="$(git -C "$TMP/installed" rev-parse HEAD)"
git -C "$TMP/installed" push -q origin main
git -C "$TMP/installed" worktree add -q -b candidate "$TMP/candidate" "$old"
ln -s "$TMP/installed/bin/ai-task-gates" "$TMP/bin/ai-task-gates"
manifest(){
  local sha="$1" hash
  hash="$(git -C "$TMP/installed" show "$sha:bin/ai-task-gates" | sha256sum | cut -d' ' -f1)"
  printf 'meta\tsource_sha\t%s\t-\nsymlink\t%s\t%s\t%s\n' "$sha" "$TMP/bin/ai-task-gates" "$TMP/installed/bin/ai-task-gates" "$hash" > "$TMP/etc/install-manifest.tsv"
}
manifest "$old"
gate(){ (cd "$2" && "$2/bin/ai-task-gates" install-verify --phase "$1" --target-head "$3" --installed-checkout "$TMP/installed" --installed-launcher "$TMP/bin/ai-task-gates" "${@:4}"); }
expect_ok(){ local name="$1"; shift; if "$@" > "$TMP/last-output" 2>&1; then printf 'PASS: %s\n' "$name"; else printf 'FAIL: %s\n' "$name"; tail -n 4 "$TMP/last-output"; exit 1; fi; }
expect_stop(){ local name="$1"; shift; if "$@" >/dev/null 2>&1; then printf 'FAIL: %s\n' "$name"; exit 1; else printf 'PASS: %s\n' "$name"; fi; }

(cd "$TMP/candidate" && bin/ai-task-gates start --class installation) >/dev/null
printf 'new\n' > "$TMP/candidate/tools/helper.sh"
git -C "$TMP/candidate" add tools/helper.sh
git -C "$TMP/candidate" commit -qm ordinary
ordinary="$(git -C "$TMP/candidate" rev-parse HEAD)"
git -C "$TMP/candidate" push -q origin HEAD:main
git -C "$TMP/installed" fetch -q origin
expect_ok 'ordinary update preflight records transaction' gate preflight "$TMP/candidate" "$ordinary"
git -C "$TMP/installed" merge -q --ff-only "$ordinary"
expect_ok 'ordinary updated checkout resumes' gate resume "$TMP/installed" "$ordinary"
expect_stop 'finalize refuses before installed manifest is refreshed' gate finalize "$TMP/installed" "$ordinary"
manifest "$ordinary"
expect_ok 'ordinary update finalizes with completed receipt' gate finalize "$TMP/installed" "$ordinary"
expect_stop 'same-source reinstall needs task and owner request' gate resume "$TMP/installed" "$ordinary"
(cd "$TMP/installed" && bin/ai-task-gates start --class installation) >/dev/null
expect_ok 'trusted same-source reinstall retains capability' gate resume "$TMP/installed" "$ordinary" --owner-request 'Owner requested maintenance reinstall'
expect_ok 'trusted same-source reinstall finalizes' gate finalize "$TMP/installed" "$ordinary"

(cd "$TMP/candidate" && bin/ai-task-gates start --class installation) >/dev/null
printf '#!/bin/sh\n' > "$TMP/candidate/bin/ai-grok-review"
git -C "$TMP/candidate" add bin/ai-grok-review
git -C "$TMP/candidate" commit -qm protected
protected="$(git -C "$TMP/candidate" rev-parse HEAD)"
git -C "$TMP/candidate" push -q origin HEAD:main
git -C "$TMP/installed" fetch -q origin
expect_stop 'provider wrapper needs reviewed authority' gate preflight "$TMP/candidate" "$protected" --caller-pinned
git -C "$TMP/installed" worktree add -q --detach "$TMP/reviewed" "$protected"
printf '.ai/reviews/\n' >> "$(git -C "$TMP/installed" rev-parse --path-format=absolute --git-path info/exclude)"
mkdir -p "$TMP/reviewed/.ai/reviews" "$TMP/review-lifecycle"
export AI_REVIEW_LIFECYCLE_DIR="$TMP/review-lifecycle"
digest="$("$TMP/candidate/bin/ai-review-sandbox" digest "$TMP/candidate")"
report="$TMP/reviewed/.ai/reviews/approved.md"
printf '# Review\n\n| reviewed commit | `%s` |\n| source digest | `%s` |\n\nApproved protected toolkit source.\n\n## Verdict\nAPPROVE\n' "$protected" "$digest" > "$report"
report_hash="$(sha256sum "$report" | cut -d' ' -f1)"
key="$("$TMP/reviewed/bin/ai-review-lifecycle" identity "$TMP/reviewed" | jq -r .repository_key)"
mkdir -p "$AI_REVIEW_LIFECYCLE_DIR/runs/$key/codex/codex"
jq -nc --arg h "$protected" --arg d "$digest" --arg p "$report" --arg s "$report_hash" \
  '{status:"completed",verdict:"APPROVE",stale:false,head:$h,source_digest:$d,report_path:$p,report_sha256:$s}' > "$AI_REVIEW_LIFECYCLE_DIR/runs/$key/codex/codex/approved.json"
policy_digest="$(printf '%s\n%s\n' "$(git -C "$TMP/candidate" rev-parse "$protected:config/task-gates.json")" "$(git -C "$TMP/candidate" rev-parse "$protected:.ai-devops/task-gates.json")" | sha256sum | cut -d' ' -f1)"
auth="$TMP/state/install-authorizations/$protected.json"
mkdir -p "$(dirname "$auth")"
jq -nc --arg target "$protected" --arg old "$ordinary" --arg path "$TMP/installed" --arg launcher "$TMP/bin/ai-task-gates" \
  --arg policy "$policy_digest" --arg digest "$digest" --arg report "$report" --arg report_hash "$report_hash" \
  --arg manifest_hash "$(sha256sum "$TMP/etc/install-manifest.tsv" | cut -d' ' -f1)" --arg link "$TMP/installed/bin/ai-task-gates" \
  '{schema_version:1,target_head:$target,installed_head:$old,installed_checkout:$path,installed_launcher:$launcher,policy_digest:$policy,source_digest:$digest,review_report:$report,review_report_sha256:$report_hash,owner_request:"Owner requested reviewed Linux install",legacy_migration:false,first_install:false,recover_launchers:false,linux_manifest_sha256:$manifest_hash,linux_link_target:$link}' > "$auth"
expect_ok 'reviewed protected update reserves exact authority' gate preflight "$TMP/candidate" "$protected" --caller-pinned
expect_ok 'failed advance may retry same reserved target' gate preflight "$TMP/candidate" "$protected" --caller-pinned
git -C "$TMP/installed" merge -q --ff-only "$protected"
expect_ok 'protected install resumes with reviewed pending authority' gate resume "$TMP/installed" "$protected"
manifest "$protected"
mv "$auth.consuming" "$TMP/pending-backup"
expect_stop 'stamped manifest cannot hide lost protected authority' gate resume "$TMP/installed" "$protected" --owner-request 'Owner requested maintenance reinstall'
expect_stop 'finalize refuses missing protected transaction' gate finalize "$TMP/installed" "$protected"
mv "$TMP/pending-backup" "$auth.consuming"
expect_ok 'protected install finalizes only with live reviewed authority' gate finalize "$TMP/installed" "$protected"
expect_stop 'one-use protected authority cannot replay' gate finalize "$TMP/installed" "$protected"
