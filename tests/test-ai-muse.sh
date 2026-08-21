#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-muse"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

check 'wrapper parses' "bash -n '$SCRIPT'"
check 'setup parses' "bash -n '$ROOT/bin/setup-opencode-muse.sh'"
check 'exact Contributor model is pinned' "grep -q 'meta-model-api/muse-spark-1.2-contributor' '$SCRIPT'"
check 'persistent new command exists' "grep -q 'cmd_new' '$SCRIPT'"
check 'persistent ask command exists' "grep -q 'cmd_ask' '$SCRIPT'"
check 'ask resumes exact session' "grep -q -- '--session \"\$sid\"' '$SCRIPT'"
check 'same named session is locked across turns' "grep -q 'lock_session \"\$rid\" \"\$name\"' '$SCRIPT'"
check 'failed lock acquisition cannot remove its owner' "grep -q 'LOCK=\"\$candidate\"' '$SCRIPT'"
check 'caller names are path-safe' "grep -q 'name_ok \"\$CALLER\"' '$SCRIPT'"
check 'completion requires stop' "grep -q '\[ \"\$FINISH\" != stop \]' '$SCRIPT'"
check 'source state is checked after every turn' "test \"\$(grep -c 'stale response rejected' '$SCRIPT')\" -eq 2"
check 'temporary files use a securely created directory' "grep -q 'mktemp -d' '$SCRIPT' && grep -q 'trap cleanup EXIT' '$SCRIPT'"
check 'report writes fail closed' "grep -q 'could not write Muse report' '$SCRIPT'"
check 'delete takes the same session lock' "grep -q 'cmd_delete.*lock_session' '$SCRIPT'"
check 'compatibility review still requires a verdict' "grep -q 'REQUIRE_VERDICT=1' '$SCRIPT'"
check 'review uses a disposable copy' "grep -q 'ensure-copy' '$SCRIPT'"
check 'review builds an evidence packet' "grep -q 'ai-review-packet' '$SCRIPT'"
check 'old generated reports are removed from each snapshot' "grep -q 'clean -fdq -- .ai/reviews' '$SCRIPT'"
check 'local runtime failure is distinct' "grep -q 'local_dependency_unavailable.*LOCAL OpenCode' '$SCRIPT'"
check 'config pins exact protected provider and model' "jq -e '.model==\"meta-model-api/muse-spark-1.2-contributor\" and .small_model==.model and .share==\"disabled\" and .autoupdate==false and .provider[\"meta-model-api\"].options.baseURL==\"https://api.meta.ai/v1\" and .provider[\"meta-model-api\"].options.apiKey==\"{env:MODEL_API_KEY}\"' '$ROOT/config/opencode-muse/opencode.json'"
check 'runtime revalidates protected configuration' "grep -q 'Muse protection configuration changed' '$SCRIPT'"
check 'doctor validates the full protected configuration' "grep -q 'trusted provider configuration is installed byte-for-byte' '$SCRIPT'"
check 'installed profile must exactly match its trusted source' "grep -q 'cmp -s.*config/opencode-muse/agent/muse-review.md' '$SCRIPT'"
check '1Password reads use one global credential lock' "grep -q 'credential.lock.d' '$SCRIPT' && grep -q 'release_credential_lock' '$SCRIPT'"
check 'new session metadata uses atomic replacement' "grep -q 'tmp=\"\$(tmp_file)\"; jq -n --arg name' '$SCRIPT'"
check 'review profile explicitly removes dangerous tools' "for tool in write edit patch bash webfetch task; do grep -q \"^  \$tool: false\$\" '$ROOT/config/opencode-muse/agent/muse-review.md' || exit 1; done"
check 'report destination probes the paths this run will write' "grep -q 'muse-.name-.stamp.md' '$SCRIPT' && grep -q 'muse-.name-incomplete-.stamp.md' '$SCRIPT' && grep -q 'is a linked path' '$SCRIPT'"
check 'report destination derives its directory outside the local declaration' "! grep -Eq 'local root=.*dir=' '$SCRIPT'"
check 'report destination no longer asserts the whole directory is untracked' "! grep -q 'contains tracked files' '$SCRIPT'"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
HOME_FIX="$TMP/home"; REPO="$TMP/repo"; mkdir -p "$HOME_FIX" "$REPO"
git -C "$REPO" init -q; git -C "$REPO" config user.name Test; git -C "$REPO" config user.email t@example.com
printf '.ai/\n' > "$REPO/.gitignore"; printf 'marker\n' > "$REPO/a.txt"; git -C "$REPO" add .gitignore a.txt; git -C "$REPO" commit -qm init
VERSION="$(tr -d ' \r\n' < "$ROOT/config/opencode/version")"
BIN="$HOME_FIX/.local/lib/ai-devops/opencode/$VERSION/node_modules/opencode-ai/bin"; mkdir -p "$BIN" "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/agent" "$TMP/bin"
cp "$ROOT/config/opencode-muse/opencode.json" "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/opencode.json"
cp "$ROOT/config/opencode-muse/agent/muse-review.md" "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/agent/muse-review.md"
cat > "$TMP/bin/op" <<'EOF'
#!/usr/bin/env bash
printf fake-key
EOF
cat > "$BIN/opencode.exe" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo 1.18.12;;
  run)
    [ "${MUSE_STUB_MODE:-}" = fail ] && exit 7
    [ "${MUSE_STUB_MODE:-}" = malformed ] && { printf 'not-json\n'; exit 0; }
    [ "${MUSE_STUB_MODE:-}" = partialmalformed ] && { printf '{"type":"step_start","sessionID":"ses_partial","part":{}}\nnot-json\n'; exit 0; }
    [ "${MUSE_STUB_MODE:-}" = slow ] && sleep 2
    sid=ses_new; prior=''
    while [ $# -gt 0 ]; do [ "$1" = --session ] && { sid="$2"; prior=1; shift 2; continue; }; shift; done
    [ "${MUSE_STUB_MODE:-}" = wrongsid ] && sid=ses_wrong
    printf '{"type":"step_start","sessionID":"%s","part":{"type":"step-start"}}\n' "$sid"
    [ "${MUSE_STUB_MODE:-}" = mixedstart ] && printf '{"type":"step_start","sessionID":"ses_other","part":{"type":"step-start"}}\n'
    [ -z "${MUSE_STUB_TOUCH:-}" ] || printf changed >> "$MUSE_STUB_TOUCH"
    text="${MUSE_STUB_TEXT:-$([ -n "$prior" ] && echo remembered || echo first)}"
    printf '{"type":"text","sessionID":"%s","part":{"type":"text","text":"%s"}}\n' "$sid" "$text"
    [ "${MUSE_STUB_MODE:-}" = mixed ] && printf '{"type":"text","sessionID":"ses_other","part":{"type":"text","text":"wrong"}}\n'
    [ "${MUSE_STUB_MODE:-}" = nostop ] || printf '{"type":"step_finish","sessionID":"%s","part":{"type":"step-finish","reason":"stop","tokens":{"total":3}}}\n' "$sid";;
  export) [ -z "${MUSE_STUB_EXPORT_FAIL:-}" ] || exit 7; printf '{"sessionID":"%s","messages":[]}' "$2";;
  session) [ "$2" = delete ] && [ -z "${MUSE_STUB_DELETE_FAIL:-}" ];;
  *) exit 2;;
esac
EOF
chmod +x "$TMP/bin/op" "$BIN/opencode.exe"
ENV="HOME='$HOME_FIX' PATH='$TMP/bin:$PATH' AI_MUSE_STATE_DIR='$TMP/state' AI_REVIEW_SANDBOX_DIR='$TMP/sandboxes' AI_MUSE_CALLER=codex"
printf '\nbash: true\n' >> "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/agent/muse-review.md"
check 'hostile installed profile is rejected before a turn' "cd '$REPO' && ! eval \"$ENV '$SCRIPT' new hostile --prompt test\""
cp "$ROOT/config/opencode-muse/agent/muse-review.md" "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/agent/muse-review.md"
tmpcfg="$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/opencode.json.tmp"; jq '.provider["meta-model-api"].npm="untrusted"' "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/opencode.json" > "$tmpcfg"; mv "$tmpcfg" "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/opencode.json"
check 'hostile provider package is rejected before a turn' "cd '$REPO' && ! eval \"$ENV '$SCRIPT' new hostile-provider --prompt test\""
cp "$ROOT/config/opencode-muse/opencode.json" "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/opencode.json"
mkdir -p "$TMP/state/credential.lock.d"; touch -d '5 minutes ago' "$TMP/state/credential.lock.d"
NEW_OUT="$(cd "$REPO" && eval "$ENV '$SCRIPT' new debate --prompt first" 2>&1)"
check 'old credential lock without an owner is reconciled' "test ! -e '$TMP/state/credential.lock.d'"
check 'new returns first response' "printf '%s' \"\$NEW_OUT\" | grep -q '^first'"
META="$(find "$TMP/state" -name 'codex--debate.json' -type f)"
check 'new stores exact session id' "jq -e '.session_id==\"ses_new\" and .name==\"debate\"' '$META'"
ASK_OUT="$(cd "$REPO" && eval "$ENV '$SCRIPT' ask debate --prompt followup" 2>&1)"
check 'ask resumes and returns remembered response' "printf '%s' \"\$ASK_OUT\" | grep -q '^remembered'"
check 'list shows named session' "cd '$REPO' && eval \"$ENV '$SCRIPT' list\" | grep -q debate"
check 'show returns stored identity' "cd '$REPO' && eval \"$ENV '$SCRIPT' show debate\" | jq -e '.session_id==\"ses_new\"'"
check 'transcript exports exact session' "cd '$REPO' && eval \"$ENV '$SCRIPT' transcript debate\" | jq -e '.sessionID==\"ses_new\"'"
check 'reports are written for both turns' "test \"\$(find '$REPO/.ai/reviews' -name 'muse-debate-*.md' | wc -l)\" -ge 2"
check 'reports bind the exact reviewed code' "grep -Rq 'reviewed commit.*[0-9a-f]' '$REPO/.ai/reviews' && grep -Rq 'evidence fingerprint' '$REPO/.ai/reviews'"
STALE_ASK_OUT="$(cd "$REPO" && eval "$ENV MUSE_STUB_TOUCH='$REPO/a.txt' '$SCRIPT' ask debate --prompt changed" 2>&1 || true)"
check 'source changes reject an advanced follow-up' "printf '%s' \"\$STALE_ASK_OUT\" | grep -q 'advanced session was preserved'"
check 'rejected follow-up is marked for recovery' "jq -e '.status==\"completed_pending_local_checks\"' '$META'"
git -C "$REPO" checkout -q -- a.txt
LOCK="$TMP/state/locks/$(jq -r .repository_id "$META")--codex--debate.lock.d"; mkdir -p "$LOCK"
check 'delete refuses an active session' "cd '$REPO' && ! eval \"$ENV '$SCRIPT' delete debate\""
check 'refused delete preserves the active lock' "test -d '$LOCK'"
rm -rf "$LOCK"
check 'delete removes metadata and snapshot' "cd '$REPO' && eval \"$ENV '$SCRIPT' delete debate\" && test ! -e '$META'"
DEAD_META_OUT="$(cd "$REPO" && eval "$ENV '$SCRIPT' new dead-owner --prompt test" 2>&1)"
DEAD_META="$(find "$TMP/state" -name 'codex--dead-owner.json' -type f)"; DEAD_LOCK="$TMP/state/locks/$(jq -r .repository_id "$DEAD_META")--codex--dead-owner.lock.d"; mkdir -p "$DEAD_LOCK"; printf '99999999\n' > "$DEAD_LOCK/pid"
check 'dead lock owner is reconciled' "cd '$REPO' && eval \"$ENV '$SCRIPT' delete dead-owner\" && test ! -e '$DEAD_LOCK'"
MISSING_OUT="$(cd "$REPO" && eval "$ENV '$SCRIPT' new missing-owner --prompt test" 2>&1)"; MISSING_META="$(find "$TMP/state" -name 'codex--missing-owner.json' -type f)"; MISSING_LOCK="$TMP/state/locks/$(jq -r .repository_id "$MISSING_META")--codex--missing-owner.lock.d"; mkdir -p "$MISSING_LOCK"; touch -d '5 minutes ago' "$MISSING_LOCK"
check 'old lock with missing owner is reconciled' "cd '$REPO' && eval \"$ENV '$SCRIPT' delete missing-owner\""
STALE_OUT="$(cd "$REPO" && eval "$ENV MUSE_STUB_TOUCH='$REPO/a.txt' '$SCRIPT' new stale --prompt test" 2>&1 || true)"
check 'source changes during a turn reject stale output' "printf '%s' \"\$STALE_OUT\" | grep -q 'stale response rejected'"
STALE_META="$(find "$TMP/state" -name 'codex--stale.json' -type f)"
check 'rejected stale turn preserves its Muse session' "jq -e '.status==\"completed_pending_local_checks\" and .session_id==\"ses_new\"' '$STALE_META'"
check 'pending session cannot continue without reconciliation' "cd '$REPO' && ! eval \"$ENV '$SCRIPT' ask stale --prompt blocked\""
check 'explicit reconciliation re-enables continuation' "cd '$REPO' && eval \"$ENV '$SCRIPT' reconcile stale\"; jq -e '.status==\"active\" and (.reconciled_at|length>0)' '$STALE_META'"
check 'unsafe caller names are rejected' "cd '$REPO' && ! eval \"$ENV AI_MUSE_CALLER='../unsafe' '$SCRIPT' list\""
check 'unsafe names are rejected by every metadata command' "cd '$REPO' && for cmd in show transcript delete; do ! eval \"$ENV '$SCRIPT' \$cmd '../unsafe'\" || exit 1; done"
check 'provider failure is rejected' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_MODE=fail '$SCRIPT' new provider-fail --prompt test\""
check 'malformed provider output is rejected' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_MODE=malformed '$SCRIPT' new malformed --prompt test\""
check 'partly malformed output preserves a recoverable session' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_MODE=partialmalformed '$SCRIPT' new partial --prompt test\"; meta=\$(find '$TMP/state' -name 'codex--partial.json' -type f); jq -e '.session_id==\"ses_partial\" and .status==\"provider_outcome_uncertain\"' \"\$meta\""
check 'missing completion is rejected' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_MODE=nostop '$SCRIPT' new nostop --prompt test\""
check 'provider timeout is rejected' "cd '$REPO' && ! eval \"$ENV AI_MUSE_TIMEOUT=1 MUSE_STUB_MODE=slow '$SCRIPT' new timeout --prompt test\""
check 'failed provider turns preserve incomplete evidence' "test \"\$(find '$REPO/.ai/reviews' -name 'muse-*-incomplete-*.md' | wc -l)\" -ge 4"
check 'failed follow-up is marked uncertain' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_MODE=fail '$SCRIPT' ask stale --prompt retry\"; jq -e '.status==\"provider_outcome_uncertain\" and (.last_failure_report|length>0)' '$STALE_META'"
check 'uncertain session cannot continue without reconciliation' "cd '$REPO' && ! eval \"$ENV '$SCRIPT' ask stale --prompt blocked\""
check 'interrupted turn state cannot continue without reconciliation' "tmp='${STALE_META}.tmp'; jq '.status=\"turn_in_progress\"' '$STALE_META' > \"\$tmp\" && mv \"\$tmp\" '$STALE_META'; cd '$REPO' && ! eval \"$ENV '$SCRIPT' ask stale --prompt blocked\""
check 'wrong resumed session is rejected with evidence' "cd '$REPO' && eval \"$ENV '$SCRIPT' reconcile stale\" >/dev/null; ! eval \"$ENV MUSE_STUB_MODE=wrongsid '$SCRIPT' ask stale --prompt wrong\"; jq -e '.status==\"provider_outcome_uncertain\"' '$STALE_META'"
check 'mixed-session event stream is rejected' "cd '$REPO' && eval \"$ENV '$SCRIPT' reconcile stale\" >/dev/null; ! eval \"$ENV MUSE_STUB_MODE=mixed '$SCRIPT' ask stale --prompt mixed\""
check 'conflicting start-event session is rejected' "cd '$REPO' && eval \"$ENV '$SCRIPT' reconcile stale\" >/dev/null; ! eval \"$ENV MUSE_STUB_MODE=mixedstart '$SCRIPT' ask stale --prompt mixed\""
RETRY_OUT="$(cd "$REPO" && eval "$ENV '$SCRIPT' new retry-delete --prompt test" 2>&1)"; RETRY_META="$(find "$TMP/state" -name 'codex--retry-delete.json' -type f)"; RETRY_TMP="${RETRY_META}.tmp"; jq '.status="provider_deleted"' "$RETRY_META" > "$RETRY_TMP"; mv "$RETRY_TMP" "$RETRY_META"
check 'delete safely retries after provider was already removed' "cd '$REPO' && eval \"$ENV MUSE_STUB_DELETE_FAIL=1 '$SCRIPT' delete retry-delete\" && test ! -e '$RETRY_META'"
FAIL_DELETE_OUT="$(cd "$REPO" && eval "$ENV '$SCRIPT' new fail-delete --prompt test" 2>&1)"; FAIL_DELETE_META="$(find "$TMP/state" -name 'codex--fail-delete.json' -type f)"
check 'unconfirmed provider deletion preserves recovery record' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_DELETE_FAIL=1 MUSE_STUB_EXPORT_FAIL=1 '$SCRIPT' delete fail-delete\" && test -f '$FAIL_DELETE_META'"
RECON_DELETE_TMP="${FAIL_DELETE_META}.tmp"; jq '.status="provider_deleted"' "$FAIL_DELETE_META" > "$RECON_DELETE_TMP"; mv "$RECON_DELETE_TMP" "$FAIL_DELETE_META"
check 'deleted provider session cannot be reconciled' "cd '$REPO' && ! eval \"$ENV '$SCRIPT' reconcile fail-delete\""
check 'incomplete reports omit raw provider bodies' "! grep -Rq 'Structured output\|Error output' '$REPO/.ai/reviews'"
printf 'PIPE-COMPAT\n' | (cd "$REPO" && eval "$ENV MUSE_STUB_TEXT='VERDICT: APPROVE' '$SCRIPT' review '$REPO'") >/dev/null 2>&1
check 'compatibility review reads piped requests' "grep -Rlq 'PIPE-COMPAT' '$REPO/.ai/reviews'"
git -C "$REPO" checkout -q -- a.txt
check 'compatibility review rejects a stopped answer without verdict' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_TEXT=narration '$SCRIPT' review '$REPO' test\""
check 'compatibility review rejects a verdict before the final line' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_TEXT='VERDICT: APPROVE\\nqualification' '$SCRIPT' review '$REPO' test\""
check 'compatibility review accepts an explicit verdict' "cd '$REPO' && eval \"$ENV MUSE_STUB_TEXT='VERDICT: APPROVE' '$SCRIPT' review '$REPO' test\" | grep -q 'VERDICT: APPROVE'"

# shared-db#1351: `.ai/reviews` there permanently TRACKS 25 review reports as
# named .gitignore exceptions, cited by path from a migration header and four
# permanent documents. That is a legitimate repository state and must not stop
# Muse from writing a NEW report, which .gitignore still covers.
git -C "$REPO" add -f .ai/reviews/muse-debate-*.md
git -C "$REPO" -c user.name=Test -c user.email=t@example.com commit -qm 'track a review report as a named exception'
check 'a tracked prior report does not block a new Muse turn' "cd '$REPO' && eval \"$ENV '$SCRIPT' new named-exception --prompt test\" | grep -q '^first'"
check 'the tracked prior report is left tracked and unmodified' "test -z \"\$(git -C '$REPO' status --porcelain -- '.ai/reviews/muse-debate-*.md')\""

# The narrower probe must still fail closed: a rule that would re-include a NEW
# report is exactly what the old blanket assertion was guarding against.
cp "$REPO/.gitignore" "$TMP/gitignore.bak"
printf '.ai/*\n!.ai/reviews/\n!.ai/reviews/muse-*\n' > "$REPO/.gitignore"
check 'a gitignore rule that would commit the new report is refused' "cd '$REPO' && ! eval \"$ENV '$SCRIPT' new reincluded --prompt test\""
REINCLUDED_OUT="$(cd "$REPO" && eval "$ENV '$SCRIPT' new reincluded2 --prompt test" 2>&1 || true)"
check 'the refusal names the unignored report path' "printf '%s' \"\$REINCLUDED_OUT\" | grep -q 'muse-reincluded2-.*must be Git-ignored'"
cp "$TMP/gitignore.bak" "$REPO/.gitignore"


printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
