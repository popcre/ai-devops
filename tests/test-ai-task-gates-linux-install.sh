#!/usr/bin/env bash
# Exercise the real Linux source gate using only temporary checkouts and
# launcher/manifest paths. The fixture mode refuses GitHub origins.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d /tmp/ai-task-gates-linux.XXXXXX)"
trap 'rm -rf -- "$TMP"' EXIT
export AI_TASK_GATES_INSTALL_TEST_MODE=1 AI_TASK_GATES_TEST_ROOT="$TMP" AI_TASK_GATES_DIR="$TMP/state"
export AI_TASK_GATES_FILE="$ROOT/config/task-gates.json"
export AI_REVIEW_LIFECYCLE_DIR="$TMP/review-lifecycle"
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-reviewer-approval.sh"
mkdir -p "$TMP/state" "$TMP/bin" "$TMP/etc" "$TMP/installed/bin" "$TMP/installed/tools/lib" "$TMP/installed/config" "$TMP/installed/.ai-devops"
git init -q --bare --initial-branch=main "$TMP/origin.git"
git init -q --initial-branch=main "$TMP/installed"
git -C "$TMP/installed" config user.name Test
git -C "$TMP/installed" config user.email test@example.invalid
git -C "$TMP/installed" remote add origin "file://$TMP/origin.git"
cp "$ROOT/bin/ai-task-gates" "$TMP/installed/bin/ai-task-gates"
cp "$ROOT/bin/ai-review-sandbox" "$TMP/installed/bin/ai-review-sandbox"
cp "$ROOT/bin/ai-review-lifecycle" "$TMP/installed/bin/ai-review-lifecycle"
cp "$ROOT/install.sh" "$TMP/installed/install.sh"
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
stage_report(){
  local target="$1" name report="$TMP/state/install-stage-reports/$1.tsv"
  mkdir -p "$(dirname "$report")"
  for name in 'Base dependencies' 'Node toolchain (node/npm/npx)' 'System directories' 'Configuration seed' 'Configuration migration and validation' 'Unix entrypoints' 'Reviewer auto-requalification hook' 'Claude and Codex skills' 'Protected machine configuration' 'Git commit identity' 'Claude tool permissions' 'Claude closeout hook' 'Private memory seed' 'Managed artifact manifest' 'ai-devops doctor' 'Reviewer requalification'; do
    printf 'PASS\trequired\t%s\n' "$name"
  done > "$report"
  chmod 600 "$report"
  printf '%s\n' "$report"
}
manifest "$old"
gate(){ (cd "$2" && "$2/bin/ai-task-gates" install-verify --phase "$1" --target-head "$3" --installed-checkout "$TMP/installed" --installed-launcher "$TMP/bin/ai-task-gates" "${@:4}"); }
expect_ok(){ local name="$1"; shift; if "$@" > "$TMP/last-output" 2>&1; then printf 'PASS: %s\n' "$name"; else printf 'FAIL: %s\n' "$name"; tail -n 4 "$TMP/last-output"; exit 1; fi; }
appr(){ mint_reviewer_approval "$TMP" deploy "$1" popcre/ai-devops "${2:+.implementer_engine=\"$2\" | .reviewer_engine=\"$2\"}"; }
expect_stop(){ local name="$1"; shift; if "$@" >/dev/null 2>&1; then printf 'FAIL: %s\n' "$name"; exit 1; else printf 'PASS: %s\n' "$name"; fi; }

(cd "$TMP/candidate" && bin/ai-task-gates start --class installation) >/dev/null
printf 'new\n' > "$TMP/candidate/tools/helper.sh"
git -C "$TMP/candidate" add tools/helper.sh
git -C "$TMP/candidate" commit -qm ordinary
ordinary="$(git -C "$TMP/candidate" rev-parse HEAD)"
git -C "$TMP/candidate" push -q origin HEAD:main
git -C "$TMP/installed" fetch -q origin
expect_stop 'ordinary update requires an assigned AI reviewer approval' gate preflight "$TMP/candidate" "$ordinary"
expect_stop 'ordinary update refuses a same-engine approval' gate preflight "$TMP/candidate" "$ordinary" --reviewer-approval "$(appr "$ordinary" claude)"
expect_stop 'ordinary update refuses an approval for another head' gate preflight "$TMP/candidate" "$ordinary" --reviewer-approval "$(appr "$old")"
expect_ok 'ordinary update preflight records transaction' gate preflight "$TMP/candidate" "$ordinary" --reviewer-approval "$(appr "$ordinary")"
git -C "$TMP/installed" merge -q --ff-only "$ordinary"
expect_ok 'ordinary updated checkout resumes' gate resume "$TMP/installed" "$ordinary"
expect_stop 'finalize refuses before installed manifest is refreshed' gate finalize "$TMP/installed" "$ordinary"
manifest "$ordinary"
expect_stop 'finalize requires exact required-stage receipt' gate finalize "$TMP/installed" "$ordinary"
stage_path="$(stage_report "$ordinary")"
expect_ok 'ordinary required stages bind to transaction' gate stages-complete "$TMP/installed" "$ordinary" --stage-report "$stage_path"
expect_ok 'ordinary update finalizes with completed receipt' gate finalize "$TMP/installed" "$ordinary"
expect_stop 'same-source reinstall needs task and reviewer approval' gate resume "$TMP/installed" "$ordinary"
(cd "$TMP/installed" && bin/ai-task-gates start --class installation) >/dev/null
expect_ok 'trusted same-source reinstall retains capability' gate resume "$TMP/installed" "$ordinary" --reviewer-approval "$(appr "$ordinary")"
expect_ok 'same-source required stages bind to transaction' gate stages-complete "$TMP/installed" "$ordinary" --stage-report "$stage_path"
expect_ok 'trusted same-source reinstall finalizes' gate finalize "$TMP/installed" "$ordinary"
for crash_point in completion authority marker; do
  expect_ok "ordinary maintenance begins before $crash_point interruption" gate resume "$TMP/installed" "$ordinary" --reviewer-approval "$(appr "$ordinary")"
  expect_ok "ordinary stages bind before $crash_point interruption" gate stages-complete "$TMP/installed" "$ordinary" --stage-report "$stage_path"
  export AI_TASK_GATES_TEST_FINALIZE_CRASH_AFTER="$crash_point"
  expect_stop "ordinary finalize is interrupted after $crash_point" gate finalize "$TMP/installed" "$ordinary"
  unset AI_TASK_GATES_TEST_FINALIZE_CRASH_AFTER
  expect_ok "interrupted ordinary finalize resumes after $crash_point" gate finalize "$TMP/installed" "$ordinary"
  [ ! -e "$TMP/state/install-authorizations/$ordinary.json.ordinary" ] &&
    [ ! -e "$TMP/state/install-stages/$ordinary.json" ] || { echo 'FAIL: recovered ordinary cleanup left a transaction'; exit 1; }
done
# A previously installed machine may have a completion receipt from the older
# schema. It must still be able to receive a new, separately authorized target.
jq 'del(.transaction_sha256,.stage_marker_sha256,.manifest_sha256,.stage_report_sha256)' \
  "$TMP/state/install-completions/last.json" > "$TMP/old-completion.json"
cp "$TMP/old-completion.json" "$TMP/state/install-completions/last.json"

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
  '{schema_version:1,target_head:$target,installed_head:$old,installed_checkout:$path,installed_launcher:$launcher,policy_digest:$policy,source_digest:$digest,review_report:$report,review_report_sha256:$report_hash,reviewer_approval:"Owner requested reviewed Linux install",legacy_migration:false,first_install:false,recover_launchers:false,linux_manifest_sha256:$manifest_hash,linux_link_target:$link}' > "$auth"
cp "$auth" "$TMP/auth-original"
jq '.first_install=true' "$TMP/auth-original" > "$auth"
expect_stop 'first-install approval cannot replace upgrade approval' gate preflight "$TMP/candidate" "$protected" --caller-pinned
cp "$TMP/auth-original" "$auth"
printf '# tampered\n' >> "$TMP/etc/install-manifest.tsv"
expect_stop 'manifest changed after authorization' gate preflight "$TMP/candidate" "$protected" --caller-pinned
manifest "$ordinary"
printf '# tampered review\n' >> "$report"
expect_stop 'review changed after authorization' gate preflight "$TMP/candidate" "$protected" --caller-pinned
sed -i '$d' "$report"
expect_ok 'reviewed protected update reserves exact authority' gate preflight "$TMP/candidate" "$protected" --caller-pinned
expect_ok 'failed advance may retry same reserved target' gate preflight "$TMP/candidate" "$protected" --caller-pinned
git -C "$TMP/installed" merge -q --ff-only "$protected"
expect_ok 'protected install resumes with reviewed pending authority' gate resume "$TMP/installed" "$protected"
manifest "$protected"
mv "$auth.consuming" "$TMP/pending-backup"
expect_stop 'stamped manifest cannot hide lost protected authority' gate resume "$TMP/installed" "$protected" --reviewer-approval "$(appr "$protected")"
expect_stop 'finalize refuses missing protected transaction' gate finalize "$TMP/installed" "$protected"
mv "$TMP/pending-backup" "$auth.consuming"
stage_path="$(stage_report "$protected")"
expect_ok 'protected required stages bind to reviewed authority' gate stages-complete "$TMP/installed" "$protected" --stage-report "$stage_path"
marker="$TMP/state/install-stages/$protected.json"
cp "$marker" "$TMP/marker-original"
jq '.required_stages_pass=false' "$TMP/marker-original" > "$marker"
chmod 600 "$marker"
expect_stop 'tampered stage receipt cannot finalize' gate finalize "$TMP/installed" "$protected"
cp "$TMP/marker-original" "$marker"
printf 'FAIL(1)\trequired\tReviewer requalification\n' >> "$stage_path"
expect_stop 'altered stage result refuses finalize' gate finalize "$TMP/installed" "$protected"
printf 'FAIL(1)\trequired\tReviewer requalification\n' > "$stage_path"
expect_stop 'failed required stage cannot be sealed' gate stages-complete "$TMP/installed" "$protected" --stage-report "$stage_path"
stage_path="$(stage_report "$protected")"
expect_ok 'failed finalize can rebind repaired stage results' gate stages-complete "$TMP/installed" "$protected" --stage-report "$stage_path"
expect_ok 'completed stages permit protected resume after target manifest' gate resume "$TMP/installed" "$protected"
cp -a "$TMP/state" "$TMP/state-before-protected-finalize"
expect_ok 'protected install finalizes only with live reviewed authority' gate finalize "$TMP/installed" "$protected"
expect_ok 'completed protected finalize is idempotent without reminting authority' gate finalize "$TMP/installed" "$protected"
cp -a "$TMP/state" "$TMP/state-after-protected-finalize"
for crash_point in completion authority marker; do
  rm -rf -- "$TMP/state"
  cp -a "$TMP/state-before-protected-finalize" "$TMP/state"
  export AI_TASK_GATES_TEST_FINALIZE_CRASH_AFTER="$crash_point"
  expect_stop "protected finalize is interrupted after $crash_point" gate finalize "$TMP/installed" "$protected"
  unset AI_TASK_GATES_TEST_FINALIZE_CRASH_AFTER
  [ "$(jq -r .target_head "$TMP/state/install-completions/last.json")" = "$protected" ] || { echo 'FAIL: interrupted completion target changed'; exit 1; }
  if [ "$crash_point" = completion ]; then
    printf '# altered\n' >> "$TMP/state/install-stages/$protected.json"
    expect_stop 'tampered surviving stage marker cannot recover' gate finalize "$TMP/installed" "$protected"
    cp "$TMP/state-before-protected-finalize/install-stages/$protected.json" "$TMP/state/install-stages/$protected.json"
    printf '# altered\n' >> "$auth.consuming"
    expect_stop 'tampered surviving protected authority cannot recover' gate finalize "$TMP/installed" "$protected"
    cp "$TMP/state-before-protected-finalize/install-authorizations/$protected.json.consuming" "$auth.consuming"
  fi
  if [ "$crash_point" = authority ]; then
    expect_ok 'updater preflight recovers completed protected install without reminting authority' gate preflight "$TMP/candidate" "$protected" --caller-pinned
  elif [ "$crash_point" = completion ]; then
    expect_ok 'direct installer resume recovers completed protected install' gate resume "$TMP/installed" "$protected"
  else
    expect_ok "interrupted protected finalize resumes after $crash_point" gate finalize "$TMP/installed" "$protected"
  fi
  expect_ok 'completed protected finalize remains idempotent after cleanup' gate finalize "$TMP/installed" "$protected"
  [ ! -e "$auth.consuming" ] && [ ! -e "$TMP/state/install-stages/$protected.json" ] || { echo 'FAIL: recovered protected cleanup left a transaction'; exit 1; }
  expect_stop 'completed protected authority cannot reopen preflight' gate preflight "$TMP/candidate" "$protected" --caller-pinned
done
rm -rf -- "$TMP/state"
cp -a "$TMP/state-after-protected-finalize" "$TMP/state"

# A genuinely absent managed installation has its own reviewed first-install
# operation. A foreign launcher cannot be swapped into that pending grant.
rm -f "$TMP/bin/ai-task-gates" "$TMP/etc/install-manifest.tsv" "$TMP/state/install-completions/last.json"
printf '# Review\n\n| reviewed commit | `%s` |\n| source digest | `%s` |\n\nApproved first-managed-install.\n\n## Verdict\nAPPROVE\n' "$protected" "$digest" > "$report"
report_hash="$(sha256sum "$report" | cut -d' ' -f1)"
jq -nc --arg h "$protected" --arg d "$digest" --arg p "$report" --arg s "$report_hash" \
  '{status:"completed",verdict:"APPROVE",stale:false,head:$h,source_digest:$d,report_path:$p,report_sha256:$s}' > "$AI_REVIEW_LIFECYCLE_DIR/runs/$key/codex/codex/approved.json"
jq -nc --arg target "$protected" --arg path "$TMP/installed" --arg launcher "$TMP/bin/ai-task-gates" \
  --arg policy "$policy_digest" --arg digest "$digest" --arg report "$report" --arg report_hash "$report_hash" \
  '{schema_version:1,target_head:$target,installed_head:$target,installed_checkout:$path,installed_launcher:$launcher,policy_digest:$policy,source_digest:$digest,review_report:$report,review_report_sha256:$report_hash,reviewer_approval:"Owner requested reviewed first install",legacy_migration:false,first_install:true,recover_launchers:false,linux_manifest_sha256:"",linux_link_target:""}' > "$auth"
(cd "$TMP/candidate" && bin/ai-task-gates start --class installation) >/dev/null
mkdir -p "$TMP/home"
expect_ok 'documented first install reserves and resumes reviewed authority' env HOME="$TMP/home" \
  "$TMP/installed/install.sh" --test-authorization-only
[ ! -e "$auth" ] && [ -f "$auth.consuming" ] || { echo 'FAIL: direct first install did not reserve one-use authority'; exit 1; }
ln -s /tmp/foreign-gate "$TMP/bin/ai-task-gates"
expect_stop 'foreign launcher cannot enter first-install retry' gate resume "$TMP/installed" "$protected"
rm -f "$TMP/bin/ai-task-gates"
expect_ok 'first managed install resumes with launcher absent' gate resume "$TMP/installed" "$protected"
ln -s "$TMP/installed/bin/ai-task-gates" "$TMP/bin/ai-task-gates"
manifest "$protected"
stage_path="$(stage_report "$protected")"
expect_ok 'first-install required stages bind to authority' gate stages-complete "$TMP/installed" "$protected" --stage-report "$stage_path"
expect_ok 'first managed install finalizes after receipt publication' gate finalize "$TMP/installed" "$protected"

# A pre-receipt symlink needs a separate same-commit migration review.
rm -f "$TMP/etc/install-manifest.tsv" "$TMP/state/install-completions/last.json"
printf '# Review\n\n| reviewed commit | `%s` |\n| source digest | `%s` |\n\nApproved legacy-managed-launcher-refresh.\n\n## Verdict\nAPPROVE\n' "$protected" "$digest" > "$report"
report_hash="$(sha256sum "$report" | cut -d' ' -f1)"
jq -nc --arg h "$protected" --arg d "$digest" --arg p "$report" --arg s "$report_hash" \
  '{status:"completed",verdict:"APPROVE",stale:false,head:$h,source_digest:$d,report_path:$p,report_sha256:$s}' > "$AI_REVIEW_LIFECYCLE_DIR/runs/$key/codex/codex/approved.json"
source_hash="$(sha256sum "$TMP/installed/bin/ai-task-gates" | cut -d' ' -f1)"
jq -nc --arg target "$protected" --arg path "$TMP/installed" --arg launcher "$TMP/bin/ai-task-gates" \
  --arg policy "$policy_digest" --arg digest "$digest" --arg report "$report" --arg report_hash "$report_hash" --arg link "$TMP/installed/bin/ai-task-gates" --arg source_hash "$source_hash" \
  '{schema_version:1,target_head:$target,installed_head:$target,installed_checkout:$path,installed_launcher:$launcher,policy_digest:$policy,source_digest:$digest,review_report:$report,review_report_sha256:$report_hash,reviewer_approval:"Owner requested reviewed legacy migration",legacy_migration:true,first_install:false,recover_launchers:false,linux_manifest_sha256:"",linux_link_target:$link,installed_source_sha256:$source_hash}' > "$auth"
expect_ok 'documented same-commit migration reserves and resumes reviewed authority' env HOME="$TMP/home" \
  "$TMP/installed/install.sh" --test-authorization-only
[ ! -e "$auth" ] && [ -f "$auth.consuming" ] || { echo 'FAIL: direct legacy migration did not reserve one-use authority'; exit 1; }
manifest "$protected"
stage_path="$(stage_report "$protected")"
expect_ok 'legacy required stages bind to authority' gate stages-complete "$TMP/installed" "$protected" --stage-report "$stage_path"
expect_ok 'legacy symlink migration finalizes with new receipt' gate finalize "$TMP/installed" "$protected"

# A historical manifest can lag the live checkout after an earlier unguarded
# update. It must be reviewed as a distinct recovery operation covering the
# full manifest-to-target range and the live source bytes.
rm -f "$TMP/state/install-completions/last.json"
printf '# changed gate bytes\n' >> "$TMP/candidate/bin/ai-task-gates"
git -C "$TMP/candidate" add bin/ai-task-gates
git -C "$TMP/candidate" commit -qm drifted-gate-source
drifted="$(git -C "$TMP/candidate" rev-parse HEAD)"
git -C "$TMP/candidate" push -q origin HEAD:main
git -C "$TMP/installed" fetch -q origin
git -C "$TMP/installed" merge -q --ff-only "$drifted"
expect_stop 'stale manifest without reviewed recovery stops' gate preflight "$TMP/candidate" "$drifted" --caller-pinned
git -C "$TMP/installed" worktree add -q --detach "$TMP/drift-reviewed" "$drifted"
mkdir -p "$TMP/drift-reviewed/.ai/reviews"
drift_digest="$("$TMP/candidate/bin/ai-review-sandbox" digest "$TMP/candidate")"
drift_report="$TMP/drift-reviewed/.ai/reviews/approved.md"
manifest_hash="$(sha256sum "$TMP/etc/install-manifest.tsv" | cut -d' ' -f1)"
live_hash="$(sha256sum "$TMP/installed/bin/ai-task-gates" | cut -d' ' -f1)"
printf '# Review\n\n| reviewed commit | `%s` |\n| source digest | `%s` |\n| stale manifest SHA | `%s` |\n| stale manifest hash | `%s` |\n| live installed SHA | `%s` |\n| live gate hash | `%s` |\n\nApproved stale-linux-manifest-recovery.\n\n## Verdict\nAPPROVE\n' \
  "$drifted" "$drift_digest" "$protected" "$manifest_hash" "$drifted" "$live_hash" > "$drift_report"
drift_report_hash="$(sha256sum "$drift_report" | cut -d' ' -f1)"
drift_key="$("$TMP/drift-reviewed/bin/ai-review-lifecycle" identity "$TMP/drift-reviewed" | jq -r .repository_key)"
mkdir -p "$AI_REVIEW_LIFECYCLE_DIR/runs/$drift_key/codex/codex"
jq -nc --arg h "$drifted" --arg d "$drift_digest" --arg p "$drift_report" --arg s "$drift_report_hash" \
  '{status:"completed",verdict:"APPROVE",stale:false,head:$h,source_digest:$d,report_path:$p,report_sha256:$s}' > "$AI_REVIEW_LIFECYCLE_DIR/runs/$drift_key/codex/codex/approved.json"
drift_policy="$(printf '%s\n%s\n' "$(git -C "$TMP/candidate" rev-parse "$drifted:config/task-gates.json")" "$(git -C "$TMP/candidate" rev-parse "$drifted:.ai-devops/task-gates.json")" | sha256sum | cut -d' ' -f1)"
drift_auth="$TMP/state/install-authorizations/$drifted.json"
jq -nc --arg target "$drifted" --arg recorded "$protected" --arg path "$TMP/installed" --arg launcher "$TMP/bin/ai-task-gates" \
  --arg policy "$drift_policy" --arg digest "$drift_digest" --arg report "$drift_report" --arg report_hash "$drift_report_hash" \
  --arg manifest_hash "$manifest_hash" --arg link "$TMP/installed/bin/ai-task-gates" --arg live_hash "$live_hash" \
  '{schema_version:1,target_head:$target,installed_head:$target,installed_checkout:$path,installed_launcher:$launcher,policy_digest:$policy,source_digest:$digest,review_report:$report,review_report_sha256:$report_hash,reviewer_approval:"Owner requested reviewed manifest recovery",legacy_migration:false,first_install:false,recover_launchers:false,stale_manifest_recovery:true,linux_manifest_sha256:$manifest_hash,linux_manifest_recorded_sha:$recorded,linux_link_target:$link,installed_source_sha256:$live_hash}' > "$drift_auth"
cp "$drift_auth" "$TMP/drift-auth-original"
jq '.stale_manifest_recovery=false' "$TMP/drift-auth-original" > "$drift_auth"
expect_stop 'stale recovery cannot be presented as ordinary upgrade' gate preflight "$TMP/candidate" "$drifted" --caller-pinned
jq '.installed_source_sha256="0000000000000000000000000000000000000000000000000000000000000000"' "$TMP/drift-auth-original" > "$drift_auth"
expect_stop 'stale recovery refuses mismatched live source hash' gate preflight "$TMP/candidate" "$drifted" --caller-pinned
cp "$TMP/drift-auth-original" "$drift_auth"
printf '# tampered manifest\n' >> "$TMP/etc/install-manifest.tsv"
expect_stop 'stale recovery refuses modified manifest bytes' gate preflight "$TMP/candidate" "$drifted" --caller-pinned
manifest "$protected"
expect_ok 'reviewed stale recovery reserves exact host state' gate preflight "$TMP/candidate" "$drifted" --caller-pinned
expect_ok 'reviewed stale recovery resumes despite prior source drift' gate resume "$TMP/installed" "$drifted"
manifest "$drifted"
stage_path="$(stage_report "$drifted")"
expect_ok 'stale recovery required stages bind to authority' gate stages-complete "$TMP/installed" "$drifted" --stage-report "$stage_path"
expect_ok 'reviewed stale recovery finalizes new aligned receipt' gate finalize "$TMP/installed" "$drifted"
