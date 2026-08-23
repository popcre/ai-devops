#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-muse"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

check 'wrapper parses' "bash -n '$SCRIPT'"
check 'installed symlink resolution is implemented' "grep -q 'REAL_SELF=.*readlink -f' '$SCRIPT' && grep -q 'dirname \"\$SELF\"' '$SCRIPT'"
check 'setup parses' "bash -n '$ROOT/bin/setup-opencode-muse.sh'"
check 'setup resolves its installed symlink' "grep -q 'REAL_SELF=.*readlink -f' '$ROOT/bin/setup-opencode-muse.sh' && grep -q 'dirname \"\$SELF\"' '$ROOT/bin/setup-opencode-muse.sh'"
check 'wrapper and setup share the local profile root' "grep -q 'PROFILE_HOME=.*USERPROFILE:-\$HOME' '$SCRIPT' && grep -q 'CFG=.*PROFILE_HOME' '$SCRIPT' && grep -q 'BIN=.*PROFILE_HOME' '$SCRIPT' && grep -q 'HOME_DIR=.*USERPROFILE:-\$HOME' '$ROOT/bin/setup-opencode-muse.sh' && grep -q 'CFG=.*HOME_DIR' '$ROOT/bin/setup-opencode-muse.sh' && grep -q 'BIN=.*HOME_DIR' '$ROOT/bin/setup-opencode-muse.sh'"
check 'Ubuntu install provisions the protected Muse profile' "grep -q 'run_stage required \"Protected Muse review profile\"' '$ROOT/install.sh' && grep -q '\"\$REPO_ROOT/bin/setup-opencode-muse.sh\"' '$ROOT/install.sh'"
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
check 'one held-open report staging file is reserved before provider contact and revalidated' "grep -q 'reserve_report_staging' '$SCRIPT' && grep -q 'finish_report_staging' '$SCRIPT' && grep -q 'exec {PUBLISH_FD}' '$SCRIPT' && test \"\$(grep -c 'reserve_report_staging \"\$root\"; before=' '$SCRIPT')\" -eq 2"
check 'delete takes the same session lock' "grep -q 'cmd_delete.*lock_session' '$SCRIPT'"
check 'compatibility review still requires a verdict' "grep -q 'REQUIRE_VERDICT=1' '$SCRIPT'"
check 'review uses a disposable copy' "grep -q 'ensure-copy' '$SCRIPT'"
check 'review builds an evidence packet' "grep -q 'ai-review-packet' '$SCRIPT'"
check 'old generated reports are removed from each snapshot' "grep -q 'clean -fdq -- .ai/reviews' '$SCRIPT'"
check 'local runtime failure is distinct' "grep -q 'local_dependency_unavailable.*LOCAL OpenCode' '$SCRIPT'"
check 'config pins exact protected provider and model' "jq -e '.model==\"meta-model-api/muse-spark-1.2-contributor\" and .small_model==.model and .share==\"disabled\" and .autoupdate==false and .provider[\"meta-model-api\"].options.baseURL==\"https://api.meta.ai/v1\" and .provider[\"meta-model-api\"].options.apiKey==\"{env:MODEL_API_KEY}\"' '$ROOT/config/opencode-muse/opencode.json'"
check 'runtime revalidates protected configuration' "grep -q 'Muse protection configuration changed' '$SCRIPT'"
check 'doctor validates the full protected configuration' "grep -q 'trusted provider configuration is installed byte-for-byte' '$SCRIPT'"
check 'live doctor requires an exact bounded provider response' "grep -q 'MUSE_REVIEWER_HEALTHY' '$SCRIPT' && grep -q 'AI_MUSE_DOCTOR_TIMEOUT' '$SCRIPT'"
check 'installed profile must exactly match its trusted source' "grep -q 'cmp -s.*config/opencode-muse/agent/muse-review.md' '$SCRIPT'"
check '1Password reads use one global credential lock' "grep -q 'credential.lock.d' '$SCRIPT' && grep -q 'release_credential_lock' '$SCRIPT'"
check 'Muse key reaches the provider through a private handoff, never argv or the heartbeat parent' "grep -q 'unset MODEL_API_KEY' '$SCRIPT' && grep -q 'internal credential-boundary failure: Muse key reached the heartbeat parent' '$SCRIPT' && grep -q 'AI_MUSE_SECRET_FILE=\$key_file' '$SCRIPT' && ! grep -q '\"MODEL_API_KEY=\$provider_key\"' '$SCRIPT' && grep -q 'env_bin.*-i' '$SCRIPT'"
check 'new session metadata uses atomic replacement' "grep -q 'tmp=\"\$(tmp_file)\"; jq -n --arg name' '$SCRIPT'"
check 'new publishes preparing state before snapshot preparation' "fn=\$(sed -n '/^cmd_new()/,/^cmd_ask()/p' '$SCRIPT'); state_line=\$(printf '%s\n' \"\$fn\" | grep -n 'status:\"preparing\"' | head -1 | cut -d: -f1); prepare_line=\$(printf '%s\n' \"\$fn\" | grep -n 'prepare \"\$root\"' | head -1 | cut -d: -f1); test \"\$state_line\" -lt \"\$prepare_line\""
check 'review profile explicitly removes dangerous tools' "for tool in write edit patch bash webfetch task; do grep -q \"^  \$tool: false\$\" '$ROOT/config/opencode-muse/agent/muse-review.md' || exit 1; done"
check 'caller identity is explicit' "! AI_MUSE_CALLER= bash '$SCRIPT' --help 2>/dev/null"
check 'shared skill selects the real client and all recovery guidance carries it' "grep -q 'AI_MUSE_CALLER=codex ai-muse doctor' '$ROOT/docs/muse-opencode.md' && grep -q 'AI_MUSE_CALLER=codex ai-muse doctor' '$ROOT/bin/setup-opencode-muse.sh' && grep -q 'export AI_MUSE_CALLER=codex' '$ROOT/skills/shared/ask-muse/SKILL.md' && grep -q 'export AI_MUSE_CALLER=claude' '$ROOT/skills/shared/ask-muse/SKILL.md' && grep -q 'AI_MUSE_CALLER=\"\$AI_MUSE_CALLER\" ai-muse transcript' '$ROOT/skills/shared/ask-muse/SKILL.md' && grep -q 'AI_MUSE_CALLER=\"\$AI_MUSE_CALLER\" ai-muse reconcile' '$ROOT/skills/shared/ask-muse/SKILL.md' && grep -q 'AI_MUSE_CALLER=\$CALLER ai-muse transcript' '$SCRIPT' && grep -q \"AI_MUSE_CALLER='codex'\" '$ROOT/bin/setup-machine.ps1'"
check 'report destination is proven exact, ignored, untracked and unlinked' "grep -q 'exact destination is not Git-ignored' '$SCRIPT' && grep -q 'exact destination is tracked' '$SCRIPT' && grep -q 'is a linked path' '$SCRIPT'"
check 'report refusal explains the exact remedies' "grep -q 'Add .ai/reviews/ to .gitignore, then retry' '$SCRIPT' && grep -q 'git rm --cached' '$SCRIPT'"
check 'private Windows ACL is revalidated even when a marker already exists' "! grep -Fq 'if [ ! -f \"\$dir/.ai-devops-private-reviews-v1\" ]' '$SCRIPT'"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export AI_MUSE_TEST_DIR="$TMP"
mkdir -p "$TMP/installed/bin"
if MSYS=winsymlinks:nativestrict ln -s "$SCRIPT" "$TMP/installed/bin/ai-muse" 2>/dev/null && [ -L "$TMP/installed/bin/ai-muse" ]; then
  check 'installed symlink executes with repository configuration' "AI_MUSE_CALLER=codex '$TMP/installed/bin/ai-muse' --help"
else
  rm -f -- "$TMP/installed/bin/ai-muse"
  ok 'installed symlink execution fixture unavailable on this host'
fi
if MSYS=winsymlinks:nativestrict ln -s "$ROOT/bin/setup-opencode-muse.sh" "$TMP/installed/bin/setup-opencode-muse.sh" 2>/dev/null && [ -L "$TMP/installed/bin/setup-opencode-muse.sh" ]; then
  SETUP_HOME="$TMP/setup-home"; SETUP_VERSION="$(tr -d ' \r\n' < "$ROOT/config/opencode/version")"
  SETUP_BIN="$SETUP_HOME/.local/lib/ai-devops/opencode/$SETUP_VERSION/node_modules/opencode-ai/bin"
  mkdir -p "$SETUP_BIN"; printf '#!/usr/bin/env bash\nexit 0\n' > "$SETUP_BIN/opencode.exe"; chmod +x "$SETUP_BIN/opencode.exe"
  check 'installed setup symlink locates repository configuration' "USERPROFILE= AI_MUSE_CONFIG_DIR= HOME='$SETUP_HOME' '$TMP/installed/bin/setup-opencode-muse.sh' >/dev/null && cmp -s '$ROOT/config/opencode-muse/opencode.json' '$SETUP_HOME/.config/ai-devops-muse/opencode-xdg/opencode/opencode.json' && cmp -s '$ROOT/config/opencode-muse/agent/muse-review.md' '$SETUP_HOME/.config/ai-devops-muse/opencode-xdg/opencode/agent/muse-review.md'"
else
  rm -f -- "$TMP/installed/bin/setup-opencode-muse.sh"
  ok 'installed setup symlink fixture unavailable on this host'
fi
HOME_FIX="$TMP/home"; REPO="$TMP/repo"; mkdir -p "$HOME_FIX" "$REPO"
git -C "$REPO" init -q; git -C "$REPO" config user.name Test; git -C "$REPO" config user.email t@example.com
printf '.ai/\n' > "$REPO/.gitignore"; printf 'marker\n' > "$REPO/a.txt"; git -C "$REPO" add .gitignore a.txt; git -C "$REPO" commit -qm init
VERSION="$(tr -d ' \r\n' < "$ROOT/config/opencode/version")"
BIN="$HOME_FIX/.local/lib/ai-devops/opencode/$VERSION/node_modules/opencode-ai/bin"; mkdir -p "$BIN" "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/agent" "$TMP/bin"
cp "$ROOT/config/opencode-muse/opencode.json" "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/opencode.json"
cp "$ROOT/config/opencode-muse/agent/muse-review.md" "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/agent/muse-review.md"
mkdir -p "$REPO/.ai/reviews"; printf 'historic\n' > "$REPO/.ai/reviews/historic.md"; git -C "$REPO" add -f .ai/reviews/historic.md; git -C "$REPO" commit -qm 'tracked historic review'
cat > "$TMP/bin/op" <<'EOF'
#!/usr/bin/env bash
printf fake-key
EOF
cat > "$BIN/opencode.exe" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  --version) echo 1.18.12;;
  run)
    [ -z "${MUSE_STUB_ENV_FILE:-}" ] || env | sort > "$MUSE_STUB_ENV_FILE"
    if [ -n "${MUSE_STUB_CMDLINE_FILE:-}" ]; then
      { tr '\0' ' ' < "/proc/$$/cmdline" 2>/dev/null || true; printf '\n'; tr '\0' ' ' < "/proc/$PPID/cmdline" 2>/dev/null || true; } > "$MUSE_STUB_CMDLINE_FILE"
    fi
    if [ -n "${MUSE_STUB_FD_LEAK_FILE:-}" ]; then
      for fd_path in /proc/$$/fd/*; do case "$(readlink "$fd_path" 2>/dev/null || true)" in *.muse-stage.*) printf leaked > "$MUSE_STUB_FD_LEAK_FILE";; esac; done
    fi
    [ "${MUSE_STUB_MODE:-}" = fail ] && exit 7
    [ "${MUSE_STUB_MODE:-}" = malformed ] && { printf 'not-json\n'; exit 0; }
    [ "${MUSE_STUB_MODE:-}" = partialmalformed ] && { printf '{"type":"step_start","sessionID":"ses_partial","part":{}}\nnot-json\n'; exit 0; }
    [ "${MUSE_STUB_MODE:-}" = slow ] && { [ -z "${MUSE_STUB_PID_FILE:-}" ] || printf '%s\n' "$$" > "$MUSE_STUB_PID_FILE"; trap '[ -z "${MUSE_STUB_TERM_MARKER:-}" ] || printf stopped > "$MUSE_STUB_TERM_MARKER"; exit 143' HUP INT TERM; sleep "${MUSE_STUB_DELAY:-2}"; }
    if [ -n "${MUSE_STUB_SWAP_REVIEWS:-}" ]; then
      mv "$MUSE_STUB_SWAP_REVIEWS" "$MUSE_STUB_SWAP_REVIEWS.safe"
      ln -s "$MUSE_STUB_OUTSIDE" "$MUSE_STUB_SWAP_REVIEWS" || { mv "$MUSE_STUB_SWAP_REVIEWS.safe" "$MUSE_STUB_SWAP_REVIEWS"; exit 71; }
      printf done > "$MUSE_STUB_SWAP_DONE"
    fi
    sid=ses_new; prior=''
    while [ $# -gt 0 ]; do [ "$1" = --session ] && { sid="$2"; prior=1; shift 2; continue; }; shift; done
    [ "${MUSE_STUB_MODE:-}" = wrongsid ] && sid=ses_wrong
    printf '{"type":"step_start","sessionID":"%s","part":{"type":"step-start"}}\n' "$sid"
    [ "${MUSE_STUB_MODE:-}" = mixedstart ] && printf '{"type":"step_start","sessionID":"ses_other","part":{"type":"step-start"}}\n'
    [ -z "${MUSE_STUB_TOUCH:-}" ] || printf changed >> "$MUSE_STUB_TOUCH"
    [ -z "${MUSE_STUB_PREAMBLE:-}" ] || printf '{"type":"text","sessionID":"%s","part":{"type":"text","text":"%s"}}\n' "$sid" "$MUSE_STUB_PREAMBLE"
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
ENV="USERPROFILE='$HOME_FIX' HOME='$TMP/roaming-home' PATH='$TMP/bin:$PATH' AI_MUSE_STATE_DIR='$TMP/state' AI_REVIEW_SANDBOX_DIR='$TMP/sandboxes' AI_MUSE_CALLER=codex MUSE_STUB_FD_LEAK_FILE='$TMP/provider-fd-leak' MUSE_STUB_ENV_FILE='$TMP/provider-env'"
mkdir -p "$TMP/link-probe-target"
if ln -s "$TMP/link-probe-target" "$TMP/link-probe" 2>/dev/null; then
  rm -rf -- "$TMP/link-probe"; OUTSIDE_REPORTS="$TMP/outside-reports"; mkdir -p "$OUTSIDE_REPORTS"; printf safe > "$OUTSIDE_REPORTS/sentinel"
  check 'destination replacement rejects publication, cleans moved staging, and never writes outside' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_SWAP_REVIEWS='$REPO/.ai/reviews' MUSE_STUB_OUTSIDE='$OUTSIDE_REPORTS' MUSE_STUB_SWAP_DONE='$TMP/swap-done' '$SCRIPT' new report-race --prompt test\"; test -f '$TMP/swap-done'; grep -qx safe '$OUTSIDE_REPORTS/sentinel'; test \"\$(find '$OUTSIDE_REPORTS' -type f | wc -l)\" -eq 1; test -z \"\$(find '$REPO/.ai/reviews.safe' -name '.muse-stage.*' -print -quit 2>/dev/null)\""
  if [ -e "$REPO/.ai/reviews.safe" ]; then rm -rf -- "$REPO/.ai/reviews"; mv "$REPO/.ai/reviews.safe" "$REPO/.ai/reviews"; fi
else
  ok 'destination replacement race fixture unavailable on this host'
fi
check 'offline doctor does not contact the provider' "cd '$REPO' && eval \"$ENV MUSE_STUB_TOUCH='$TMP/doctor-called' '$SCRIPT' doctor\" && test ! -e '$TMP/doctor-called'"
check 'live doctor contacts Muse and proves its exact response' "cd '$REPO' && eval \"$ENV MUSE_STUB_TOUCH='$TMP/doctor-called' MUSE_STUB_TEXT=MUSE_REVIEWER_HEALTHY '$SCRIPT' doctor --live\" | grep -q 'live provider response' && test -e '$TMP/doctor-called'"
check 'live doctor accepts provider progress before the exact final response' "cd '$REPO' && eval \"$ENV MUSE_STUB_PREAMBLE=checking MUSE_STUB_TEXT=MUSE_REVIEWER_HEALTHY '$SCRIPT' doctor --live\" | grep -q 'live provider response'"
export DEVOPS_MCP_TOKEN=must-not-reach-muse OP_SERVICE_ACCOUNT_TOKEN=must-not-reach-muse SUPABASE_ACCESS_TOKEN=must-not-reach-muse
check 'Muse provider receives only its own key and the minimal runtime environment' "cd '$REPO' && eval \"$ENV MUSE_STUB_TEXT=MUSE_REVIEWER_HEALTHY '$SCRIPT' doctor --live\" >/dev/null && grep -qx 'MODEL_API_KEY=fake-key' '$TMP/provider-env' && ! grep -Eq 'DEVOPS_MCP_TOKEN|OP_SERVICE_ACCOUNT_TOKEN|SUPABASE_ACCESS_TOKEN' '$TMP/provider-env'"
check 'Muse key is absent from the provider process chain arguments' "cd '$REPO' && eval \"$ENV MUSE_STUB_CMDLINE_FILE='$TMP/provider-cmdline' MUSE_STUB_TEXT=MUSE_REVIEWER_HEALTHY '$SCRIPT' doctor --live\" >/dev/null && ! grep -q 'fake-key' '$TMP/provider-cmdline'"
unset DEVOPS_MCP_TOKEN OP_SERVICE_ACCOUNT_TOKEN SUPABASE_ACCESS_TOKEN
check 'live doctor rejects unexpected provider text' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_TEXT=unexpected '$SCRIPT' doctor --live\""
rm -f "$TMP/muse-post-open"; (cd "$REPO" && exec env USERPROFILE="$HOME_FIX" HOME="$TMP/roaming-home" PATH="$TMP/bin:$PATH" AI_MUSE_STATE_DIR="$TMP/state" AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes" AI_MUSE_CALLER=codex AI_MUSE_TEST_POST_OPEN_MARKER="$TMP/muse-post-open" AI_MUSE_TEST_POST_OPEN_DELAY=3 "$SCRIPT" new post-open-swap --prompt test >/dev/null 2>&1) & MUSE_POST_OPEN_PID=$!
for _ in $(seq 1 300); do [ -s "$TMP/muse-post-open" ] && break; sleep .1; done
MUSE_POST_OPEN="$(cat "$TMP/muse-post-open" 2>/dev/null || true)"; if [ -n "$MUSE_POST_OPEN" ]; then mv "$MUSE_POST_OPEN" "$MUSE_POST_OPEN.held"; printf attacker-preserved > "$MUSE_POST_OPEN"; fi
MUSE_POST_OPEN_RC=0; wait "$MUSE_POST_OPEN_PID" || MUSE_POST_OPEN_RC=$?
check 'post-open staging substitution is rejected against the held descriptor' "test '$MUSE_POST_OPEN_RC' -ne 0 && grep -qx attacker-preserved '$MUSE_POST_OPEN' && test ! -e '$MUSE_POST_OPEN.held'"
rm -f -- "$MUSE_POST_OPEN" "$MUSE_POST_OPEN.held" "$TMP/muse-pre-open"; printf 'must-not-truncate\n' > "$TMP/muse-pre-open-target"
(cd "$REPO" && exec env USERPROFILE="$HOME_FIX" HOME="$TMP/roaming-home" PATH="$TMP/bin:$PATH" AI_MUSE_STATE_DIR="$TMP/state" AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes" AI_MUSE_CALLER=codex AI_MUSE_TEST_PRE_OPEN_MARKER="$TMP/muse-pre-open" AI_MUSE_TEST_PRE_OPEN_DELAY=3 "$SCRIPT" new pre-open-substitution --prompt test >/dev/null 2>&1) & MUSE_PRE_OPEN_PID=$!
for _ in $(seq 1 300); do [ -s "$TMP/muse-pre-open" ] && break; sleep .1; done
MUSE_PRE_OPEN="$(cat "$TMP/muse-pre-open" 2>/dev/null || true)"
if [ -n "$MUSE_PRE_OPEN" ]; then MSYS=winsymlinks:nativestrict ln -s "$TMP/muse-pre-open-target" "$MUSE_PRE_OPEN" 2>/dev/null || cp "$TMP/muse-pre-open-target" "$MUSE_PRE_OPEN"; fi
MUSE_PRE_OPEN_RC=0; wait "$MUSE_PRE_OPEN_PID" || MUSE_PRE_OPEN_RC=$?
check 'exclusive pre-open staging reservation rejects an attacker path without truncation' "test '$MUSE_PRE_OPEN_RC' -ne 0 && grep -qx must-not-truncate '$TMP/muse-pre-open-target'"
rm -f -- "$MUSE_PRE_OPEN"
rm -f -- "$MUSE_POST_OPEN"
POST_LOG="$TMP/post-process.log"; (cd "$REPO" && exec env USERPROFILE="$HOME_FIX" HOME="$TMP/roaming-home" PATH="$TMP/bin:$PATH" AI_MUSE_STATE_DIR="$TMP/state" AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes" AI_MUSE_CALLER=codex AI_MUSE_TEST_POST_PROCESS_MARKER="$TMP/post-process-reached" AI_MUSE_TEST_POST_PROCESS_DELAY=20 "$SCRIPT" new post-process-interrupt --prompt test >"$POST_LOG" 2>&1) & POST_PID=$!
for _ in $(seq 1 300); do [ -f "$TMP/post-process-reached" ] && break; sleep .1; done
POST_META="$(find "$TMP/state" -name 'codex--post-process-interrupt.json' -type f -print -quit)"
kill -TERM "$POST_PID" 2>/dev/null || true; wait "$POST_PID" 2>/dev/null || true
check 'interrupt after provider exit but before classification marks outcome uncertain' "test -f '$POST_META' && jq -e '.status==\"provider_outcome_uncertain\"' '$POST_META'"
rm -f "$TMP/muse-child-pid" "$TMP/muse-child-stopped"
(cd "$REPO" && exec env USERPROFILE="$HOME_FIX" HOME="$TMP/roaming-home" PATH="$TMP/bin:$PATH" AI_MUSE_STATE_DIR="$TMP/state" AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes" AI_MUSE_CALLER=codex MUSE_STUB_MODE=slow MUSE_STUB_DELAY=30 MUSE_STUB_PID_FILE="$TMP/muse-child-pid" MUSE_STUB_TERM_MARKER="$TMP/muse-child-stopped" "$SCRIPT" new hup-turn --prompt test >/dev/null 2>&1) & MUSE_HUP_PID=$!
for _ in $(seq 1 300); do [ -s "$TMP/muse-child-pid" ] && break; sleep .1; done
MUSE_CHILD_PID="$(cat "$TMP/muse-child-pid" 2>/dev/null || echo 0)"; kill -HUP "$MUSE_HUP_PID" 2>/dev/null || true; wait "$MUSE_HUP_PID" 2>/dev/null || true
MUSE_HUP_META="$(find "$TMP/state" -name 'codex--hup-turn.json' -type f -print -quit)"
check 'HUP stops and waits for the provider child before releasing an uncertain session' "test -f '$TMP/muse-child-stopped' && ! kill -0 '$MUSE_CHILD_PID' 2>/dev/null && jq -e '.status==\"provider_outcome_uncertain\"' '$MUSE_HUP_META'"
rm -f "$TMP/muse-publish-target"
(cd "$REPO" && exec env USERPROFILE="$HOME_FIX" HOME="$TMP/roaming-home" PATH="$TMP/bin:$PATH" AI_MUSE_STATE_DIR="$TMP/state" AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes" AI_MUSE_CALLER=codex AI_MUSE_TEST_PRE_PUBLISH_MARKER="$TMP/muse-publish-target" AI_MUSE_TEST_PRE_PUBLISH_DELAY=3 "$SCRIPT" new no-clobber --prompt test >/dev/null 2>&1) & MUSE_TARGET_PID=$!
for _ in $(seq 1 300); do [ -s "$TMP/muse-publish-target" ] && break; sleep .1; done
MUSE_TARGET="$(cat "$TMP/muse-publish-target" 2>/dev/null || true)"; printf owner-target > "$MUSE_TARGET"; MUSE_TARGET_RC=0; wait "$MUSE_TARGET_PID" || MUSE_TARGET_RC=$?
check 'exact Muse report target creation is refused without overwrite' "test '$MUSE_TARGET_RC' -ne 0 && grep -qx owner-target '$MUSE_TARGET'"
rm -f "$TMP/muse-late-target"
(cd "$REPO" && exec env USERPROFILE="$HOME_FIX" HOME="$TMP/roaming-home" PATH="$TMP/bin:$PATH" AI_MUSE_STATE_DIR="$TMP/state" AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes" AI_MUSE_CALLER=codex AI_MUSE_TEST_PRE_PUBLISH_MARKER="$TMP/muse-late-target" AI_MUSE_TEST_PRE_PUBLISH_DELAY=20 "$SCRIPT" new late-interrupt --prompt test >/dev/null 2>&1) & MUSE_LATE_PID=$!
for _ in $(seq 1 300); do [ -s "$TMP/muse-late-target" ] && break; sleep .1; done
MUSE_LATE_TARGET="$(cat "$TMP/muse-late-target" 2>/dev/null || true)"; kill -TERM "$MUSE_LATE_PID" 2>/dev/null || true; wait "$MUSE_LATE_PID" 2>/dev/null || true
MUSE_LATE_META="$(find "$TMP/state" -name 'codex--late-interrupt.json' -type f -print -quit)"
check 'interruption during final publication keeps session uncertain and publishes no report' "jq -e '.status==\"provider_outcome_uncertain\"' '$MUSE_LATE_META' && test -n '$MUSE_LATE_TARGET' && test ! -e '$MUSE_LATE_TARGET'"
OUTSIDE_FINAL="$TMP/outside-final"; mkdir -p "$OUTSIDE_FINAL"; printf safe > "$OUTSIDE_FINAL/sentinel"; rm -f "$TMP/muse-final-swap-target"
(cd "$REPO" && exec env USERPROFILE="$HOME_FIX" HOME="$TMP/roaming-home" PATH="$TMP/bin:$PATH" AI_MUSE_STATE_DIR="$TMP/state" AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes" AI_MUSE_CALLER=codex AI_MUSE_TEST_PRE_PUBLISH_MARKER="$TMP/muse-final-swap-target" AI_MUSE_TEST_PRE_PUBLISH_DELAY=3 "$SCRIPT" new final-dir-swap --prompt test >/dev/null 2>&1) & MUSE_FINAL_SWAP_PID=$!
for _ in $(seq 1 300); do [ -s "$TMP/muse-final-swap-target" ] && break; sleep .1; done
if mv "$REPO/.ai/reviews" "$REPO/.ai/reviews.final-safe" 2>/dev/null && ln -s "$OUTSIDE_FINAL" "$REPO/.ai/reviews" 2>/dev/null; then
  MUSE_FINAL_SWAP_RC=0; wait "$MUSE_FINAL_SWAP_PID" || MUSE_FINAL_SWAP_RC=$?
  check 'late report-directory replacement is rejected without outside publication' "test '$MUSE_FINAL_SWAP_RC' -ne 0 && grep -qx safe '$OUTSIDE_FINAL/sentinel' && test \"\$(find '$OUTSIDE_FINAL' -type f | wc -l)\" -eq 1"
  rm -f "$REPO/.ai/reviews"; mv "$REPO/.ai/reviews.final-safe" "$REPO/.ai/reviews"
else
  ok 'late report-directory replacement fixture unavailable on this host'
  wait "$MUSE_FINAL_SWAP_PID" 2>/dev/null || true
  [ ! -e "$REPO/.ai/reviews.final-safe" ] || { rm -f "$REPO/.ai/reviews"; mv "$REPO/.ai/reviews.final-safe" "$REPO/.ai/reviews"; }
fi
rm -f "$TMP/muse-staging-path" "$TMP/muse-staging-target"
(cd "$REPO" && exec env USERPROFILE="$HOME_FIX" HOME="$TMP/roaming-home" PATH="$TMP/bin:$PATH" AI_MUSE_STATE_DIR="$TMP/state" AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes" AI_MUSE_CALLER=codex AI_MUSE_TEST_STAGING_MARKER="$TMP/muse-staging-path" AI_MUSE_TEST_PRE_PUBLISH_MARKER="$TMP/muse-staging-target" AI_MUSE_TEST_PRE_PUBLISH_DELAY=3 "$SCRIPT" new staging-replacement --prompt test >/dev/null 2>&1) & MUSE_STAGING_PID=$!
for _ in $(seq 1 300); do [ -s "$TMP/muse-staging-path" ] && [ -s "$TMP/muse-staging-target" ] && break; sleep .1; done
MUSE_STAGING="$(cat "$TMP/muse-staging-path" 2>/dev/null || true)"; MUSE_STAGING_TARGET="$(cat "$TMP/muse-staging-target" 2>/dev/null || true)"
if [ -n "$MUSE_STAGING" ] && mv "$MUSE_STAGING" "$MUSE_STAGING.held" 2>/dev/null; then printf attacker > "$MUSE_STAGING"; fi
MUSE_DECOY="$REPO/.ai/decoy/$(basename "$MUSE_STAGING")"; mkdir -p "$(dirname "$MUSE_DECOY")"; printf preserve-me > "$MUSE_DECOY"
MUSE_STAGING_RC=0; wait "$MUSE_STAGING_PID" || MUSE_STAGING_RC=$?
check 'staging-file replacement is rejected and cannot publish attacker bytes' "test '$MUSE_STAGING_RC' -ne 0 && test -n '$MUSE_STAGING_TARGET' && test ! -e '$MUSE_STAGING_TARGET'"
check 'cleanup preserves a same-basename file it does not own' "grep -qx preserve-me '$MUSE_DECOY'"
check 'cleanup finds and removes its moved reserved inode under a different basename' "test ! -e '$MUSE_STAGING.held'"
rm -f -- "$MUSE_STAGING" "$MUSE_STAGING.held"
rm -rf -- "$REPO/.ai/decoy"
check 'doctor rejects unknown options' "cd '$REPO' && ! eval \"$ENV '$SCRIPT' doctor --unknown\""
check 'zero heartbeat interval is rejected before provider contact' "cd '$REPO' && ! eval \"$ENV AI_MUSE_HEARTBEAT_INTERVAL=0 MUSE_STUB_TOUCH='$TMP/heartbeat-called' '$SCRIPT' new invalid-heartbeat --prompt test\" && test ! -e '$TMP/heartbeat-called'"
check 'nonnumeric heartbeat interval is rejected before provider contact' "cd '$REPO' && ! eval \"$ENV AI_MUSE_HEARTBEAT_INTERVAL=nope MUSE_STUB_TOUCH='$TMP/heartbeat-called' '$SCRIPT' new invalid-heartbeat-text --prompt test\" && test ! -e '$TMP/heartbeat-called'"
check 'invalid heartbeat creates no stuck new-session metadata' "test -z \"\$(find '$TMP/state' -type f -name '*invalid-heartbeat*' -print -quit 2>/dev/null)\""
printf '\nbash: true\n' >> "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/agent/muse-review.md"
check 'hostile installed profile is rejected before a turn' "cd '$REPO' && ! eval \"$ENV '$SCRIPT' new hostile --prompt test\""
cp "$ROOT/config/opencode-muse/agent/muse-review.md" "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/agent/muse-review.md"
tmpcfg="$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/opencode.json.tmp"; jq '.provider["meta-model-api"].npm="untrusted"' "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/opencode.json" > "$tmpcfg"; mv "$tmpcfg" "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/opencode.json"
check 'hostile provider package is rejected before a turn' "cd '$REPO' && ! eval \"$ENV '$SCRIPT' new hostile-provider --prompt test\""
cp "$ROOT/config/opencode-muse/opencode.json" "$HOME_FIX/.config/ai-devops-muse/opencode-xdg/opencode/opencode.json"
PREP_LOG="$TMP/prepare-visible.log"; PREP_MARKER="$TMP/prepare-visible.marker"
(cd "$REPO" && eval "$ENV AI_MUSE_TEST_PREPARE_MARKER='$PREP_MARKER' AI_MUSE_TEST_PREPARE_DELAY=3 '$SCRIPT' new prepare-visible --prompt test" >"$PREP_LOG" 2>&1) & PREP_PID=$!
for _ in $(seq 1 100); do [ -s "$PREP_MARKER" ] && break; sleep .1; done
PREP_META="$(find "$TMP/state" -name 'codex--prepare-visible.json' -type f -print -quit)"
check 'preparation cannot hang without visible durable state' "test -f '$PREP_META' && jq -e '.status==\"preparing\" and .turn_kind==\"new\" and .session_id==null' '$PREP_META' && grep -q 'Muse session started: prepare-visible' '$PREP_LOG' && grep -Fq 'State: $PREP_META' '$PREP_LOG'"
wait "$PREP_PID"
check 'prepared session advances from visible startup state' "jq -e '.status==\"active\" and .session_id==\"ses_new\"' '$PREP_META'"
check 'visible preparation session remains normally deletable' "cd '$REPO' && eval \"$ENV '$SCRIPT' delete prepare-visible\" && test ! -e '$PREP_META'"
PREP_INT_LOG="$TMP/prepare-interrupt.log"; PREP_INT_MARKER="$TMP/prepare-interrupt.marker"
(cd "$REPO" && exec env HOME="$HOME_FIX" PATH="$TMP/bin:$PATH" AI_MUSE_STATE_DIR="$TMP/state" AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes" AI_MUSE_CALLER=codex AI_MUSE_TEST_PREPARE_MARKER="$PREP_INT_MARKER" AI_MUSE_TEST_PREPARE_DELAY=30 "$SCRIPT" new prepare-interrupt --prompt test >"$PREP_INT_LOG" 2>&1) & PREP_INT_PID=$!
for _ in $(seq 1 100); do [ -s "$PREP_INT_MARKER" ] && break; sleep .1; done
PREP_INT_META="$(find "$TMP/state" -name 'codex--prepare-interrupt.json' -type f -print -quit)"
kill -TERM "$PREP_INT_PID" 2>/dev/null || true; PREP_INT_RC=0; wait "$PREP_INT_PID" || PREP_INT_RC=$?
check 'pre-provider interruption is recoverable without inventing provider uncertainty' "test '$PREP_INT_RC' -ne 0 && jq -e '.status==\"preparation_failed\" and .session_id==null and .failure_reason==\"interrupted-local-observer\"' '$PREP_INT_META'"
check 'interrupted pre-provider session can be deleted and retried' "cd '$REPO' && eval \"$ENV '$SCRIPT' delete prepare-interrupt\" && test ! -e '$PREP_INT_META' && eval \"$ENV '$SCRIPT' new prepare-interrupt --prompt retry\" >/dev/null && eval \"$ENV '$SCRIPT' delete prepare-interrupt\" >/dev/null"
SETUP_FAIL_OUT="$(cd "$REPO" && eval "$ENV AI_MUSE_TIMEOUT_BIN='$TMP/missing-timeout' '$SCRIPT' new setup-fail --prompt test" 2>&1 || true)"; SETUP_FAIL_META="$(find "$TMP/state" -name 'codex--setup-fail.json' -type f -print -quit)"
check 'local setup failure stays pre-provider and recoverable' "printf '%s' \"\$SETUP_FAIL_OUT\" | grep -q 'trusted timeout executable is unavailable' && jq -e '.status==\"preparation_failed\" and .session_id==null and .failure_reason==\"local_preparation_incomplete\"' '$SETUP_FAIL_META'"
check 'local setup failure can be deleted' "cd '$REPO' && eval \"$ENV '$SCRIPT' delete setup-fail\" && test ! -e '$SETUP_FAIL_META'"
PRE_LAUNCH_LOG="$TMP/pre-launch-interrupt.log"; PRE_LAUNCH_MARKER="$TMP/pre-launch-interrupt.marker"
(cd "$REPO" && exec env HOME="$HOME_FIX" PATH="$TMP/bin:$PATH" AI_MUSE_STATE_DIR="$TMP/state" AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes" AI_MUSE_CALLER=codex AI_MUSE_TEST_PRE_LAUNCH_MARKER="$PRE_LAUNCH_MARKER" AI_MUSE_TEST_PRE_LAUNCH_DELAY=30 "$SCRIPT" new pre-launch-interrupt --prompt test >"$PRE_LAUNCH_LOG" 2>&1) & PRE_LAUNCH_PID=$!
for _ in $(seq 1 300); do [ -s "$PRE_LAUNCH_MARKER" ] && break; sleep .1; done
PRE_LAUNCH_META="$(find "$TMP/state" -name 'codex--pre-launch-interrupt.json' -type f -print -quit)"
kill -TERM "$PRE_LAUNCH_PID" 2>/dev/null || true; PRE_LAUNCH_RC=0; wait "$PRE_LAUNCH_PID" || PRE_LAUNCH_RC=$?
check 'interruption immediately before provider launch stays recoverable' "test '$PRE_LAUNCH_RC' -ne 0 && jq -e '.status==\"preparation_failed\" and .session_id==null and .failure_reason==\"interrupted-local-observer\"' '$PRE_LAUNCH_META'"
check 'pre-launch interruption can be deleted' "cd '$REPO' && eval \"$ENV '$SCRIPT' delete pre-launch-interrupt\" && test ! -e '$PRE_LAUNCH_META'"
POST_LAUNCH_LOG="$TMP/post-launch-interrupt.log"; POST_LAUNCH_MARKER="$TMP/post-launch-interrupt.marker"
(cd "$REPO" && exec env HOME="$HOME_FIX" PATH="$TMP/bin:$PATH" AI_MUSE_STATE_DIR="$TMP/state" AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes" AI_MUSE_CALLER=codex AI_MUSE_TEST_POST_LAUNCH_MARKER="$POST_LAUNCH_MARKER" AI_MUSE_TEST_POST_LAUNCH_DELAY=30 MUSE_STUB_MODE=slow MUSE_STUB_DELAY=30 "$SCRIPT" new post-launch-interrupt --prompt test >"$POST_LAUNCH_LOG" 2>&1) & POST_LAUNCH_PID=$!
for _ in $(seq 1 300); do [ -s "$POST_LAUNCH_MARKER" ] && break; sleep .1; done
POST_LAUNCH_META="$(find "$TMP/state" -name 'codex--post-launch-interrupt.json' -type f -print -quit)"
kill -TERM "$POST_LAUNCH_PID" 2>/dev/null || true; POST_LAUNCH_RC=0; wait "$POST_LAUNCH_PID" || POST_LAUNCH_RC=$?
check 'post-launch interruption cannot be misclassified as local preparation failure' "test '$POST_LAUNCH_RC' -ne 0 && jq -e '.status==\"provider_outcome_uncertain\" and .session_id==null and .failure_reason==\"interrupted-local-observer\"' '$POST_LAUNCH_META'"
check 'unknown launched provider work cannot be deleted reconciled or retried' "cd '$REPO' && ! eval \"$ENV '$SCRIPT' delete post-launch-interrupt\" && ! eval \"$ENV '$SCRIPT' reconcile post-launch-interrupt\" && ! eval \"$ENV '$SCRIPT' new post-launch-interrupt --prompt duplicate\""
mkdir -p "$TMP/state/credential.lock.d"; touch -d '5 minutes ago' "$TMP/state/credential.lock.d"
NEW_OUT="$(cd "$REPO" && eval "$ENV '$SCRIPT' new debate --prompt first" 2>&1)"
check 'tracked historic reports do not block a new exact destination' "printf '%s' \"\$NEW_OUT\" | grep -q '^first'"
check 'old credential lock without an owner is reconciled' "test ! -e '$TMP/state/credential.lock.d'"
check 'new returns first response' "printf '%s' \"\$NEW_OUT\" | grep -q '^first'"
check 'provider child never inherits the writable report descriptor' "test ! -e '$TMP/provider-fd-leak'"
META="$(find "$TMP/state" -name 'codex--debate.json' -type f)"
check 'new stores exact session id' "jq -e '.session_id==\"ses_new\" and .name==\"debate\"' '$META'"
rm -f "$TMP/heartbeat-ask-called"
check 'invalid heartbeat leaves an existing session active without provider contact' "cd '$REPO' && ! eval \"$ENV AI_MUSE_HEARTBEAT_INTERVAL=0 MUSE_STUB_TOUCH='$TMP/heartbeat-ask-called' '$SCRIPT' ask debate --prompt invalid\"; test ! -e '$TMP/heartbeat-ask-called'; jq -e '.status==\"active\"' '$META'"
ASK_OUT="$(cd "$REPO" && eval "$ENV '$SCRIPT' ask debate --prompt followup" 2>&1)"
check 'ask resumes and returns remembered response' "printf '%s' \"\$ASK_OUT\" | grep -q '^remembered'"
check 'ask emits its session and exact state path before provider completion' "printf '%s' \"\$ASK_OUT\" | grep -q 'Muse session continuing: debate' && printf '%s' \"\$ASK_OUT\" | grep -Fq 'State: $META'"
check 'list shows named session' "cd '$REPO' && eval \"$ENV '$SCRIPT' list\" | grep -q debate"
check 'show returns stored identity' "cd '$REPO' && eval \"$ENV '$SCRIPT' show debate\" | jq -e '.session_id==\"ses_new\"'"
check 'transcript exports exact session' "cd '$REPO' && eval \"$ENV '$SCRIPT' transcript debate\" | jq -e '.sessionID==\"ses_new\"'"
check 'reports are written for both turns' "test \"\$(find '$REPO/.ai/reviews' -name 'muse-debate-*.md' | wc -l)\" -ge 2"
if [ -n "${SYSTEMROOT:-}" ]; then
  check 'Muse report storage has a private Windows ACL' "! icacls.exe \"\$(cygpath -w '$REPO/.ai/reviews')\" | grep -Ei 'BUILTIN\\\\Users|Authenticated Users|Everyone'"
else
  check 'Muse report storage is mode 0700' "test \"\$(stat -c %a '$REPO/.ai/reviews')\" = 700"
fi
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
SLOW_LOG="$TMP/slow.log"; SLOW_PROVIDER_PID="$TMP/slow-provider.pid"; (cd "$REPO" && eval "$ENV AI_MUSE_HEARTBEAT_INTERVAL=1 MUSE_STUB_MODE=slow MUSE_STUB_DELAY=8 MUSE_STUB_PID_FILE='$SLOW_PROVIDER_PID' '$SCRIPT' new visible-slow --prompt test" >"$SLOW_LOG" 2>&1) & SLOW_PID=$!
for _ in $(seq 1 300); do [ -s "$SLOW_PROVIDER_PID" ] && break; sleep .1; done
SLOW_META=""; for _ in $(seq 1 50); do SLOW_META="$(find "$TMP/state" -name 'codex--visible-slow.json' -type f -print -quit)"; [ -n "$SLOW_META" ] && jq -e '.status=="turn_in_progress" and (.worker_pid|type)=="number" and (.last_heartbeat_at|length)>0' "$SLOW_META" >/dev/null 2>&1 && break; sleep .1; done
check 'slow turn publishes durable in-progress state before completion' "test -f '$SLOW_META' && jq -e '.status==\"turn_in_progress\" and (.worker_pid|type)==\"number\" and (.last_heartbeat_at|length)>0' '$SLOW_META'"
wait "$SLOW_PID"
check 'new emits its session and exact state path before provider completion' "grep -q 'Muse session started: visible-slow' '$SLOW_LOG' && grep -Fq 'State: $SLOW_META' '$SLOW_LOG'"
check 'slow turn emits bounded progress' "grep -q 'Muse turn active:' '$SLOW_LOG'"
check 'failed provider turns preserve incomplete evidence' "test \"\$(find '$REPO/.ai/reviews' -name 'muse-*-incomplete-*.md' | wc -l)\" -ge 4"
check 'failed follow-up is marked uncertain' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_MODE=fail '$SCRIPT' ask stale --prompt retry\"; jq -e '.status==\"provider_outcome_uncertain\" and (.last_failure_report|length>0)' '$STALE_META'"
check 'uncertain session cannot continue without reconciliation' "cd '$REPO' && ! eval \"$ENV '$SCRIPT' ask stale --prompt blocked\""
check 'interrupted turn state cannot continue without reconciliation' "tmp='${STALE_META}.tmp'; jq '.status=\"turn_in_progress\"' '$STALE_META' > \"\$tmp\" && mv \"\$tmp\" '$STALE_META'; cd '$REPO' && ! eval \"$ENV '$SCRIPT' ask stale --prompt blocked\""
check 'wrong resumed session is rejected without replacing canonical identity' "cd '$REPO' && eval \"$ENV '$SCRIPT' reconcile stale\" >/dev/null; ! eval \"$ENV MUSE_STUB_MODE=wrongsid '$SCRIPT' ask stale --prompt wrong\"; jq -e '.status==\"provider_outcome_uncertain\" and .session_id==\"ses_new\" and .returned_session_id==\"ses_wrong\"' '$STALE_META'"
check 'mixed-session event stream is rejected' "cd '$REPO' && eval \"$ENV '$SCRIPT' reconcile stale\" >/dev/null; ! eval \"$ENV MUSE_STUB_MODE=mixed '$SCRIPT' ask stale --prompt mixed\""
check 'conflicting start-event session is rejected' "cd '$REPO' && eval \"$ENV '$SCRIPT' reconcile stale\" >/dev/null; ! eval \"$ENV MUSE_STUB_MODE=mixedstart '$SCRIPT' ask stale --prompt mixed\""
RETRY_OUT="$(cd "$REPO" && eval "$ENV '$SCRIPT' new retry-delete --prompt test" 2>&1)"; RETRY_META="$(find "$TMP/state" -name 'codex--retry-delete.json' -type f)"; RETRY_TMP="${RETRY_META}.tmp"; jq '.status="provider_deleted"' "$RETRY_META" > "$RETRY_TMP"; mv "$RETRY_TMP" "$RETRY_META"
check 'delete safely retries after provider was already removed' "cd '$REPO' && eval \"$ENV MUSE_STUB_DELETE_FAIL=1 '$SCRIPT' delete retry-delete\" && test ! -e '$RETRY_META'"
FAIL_DELETE_OUT="$(cd "$REPO" && eval "$ENV '$SCRIPT' new fail-delete --prompt test" 2>&1)"; FAIL_DELETE_META="$(find "$TMP/state" -name 'codex--fail-delete.json' -type f)"
check 'unconfirmed provider deletion preserves recovery record' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_DELETE_FAIL=1 MUSE_STUB_EXPORT_FAIL=1 '$SCRIPT' delete fail-delete\" && test -f '$FAIL_DELETE_META'"
RECON_DELETE_TMP="${FAIL_DELETE_META}.tmp"; jq '.status="provider_deleted"' "$FAIL_DELETE_META" > "$RECON_DELETE_TMP"; mv "$RECON_DELETE_TMP" "$FAIL_DELETE_META"
check 'deleted provider session cannot be reconciled' "cd '$REPO' && ! eval \"$ENV '$SCRIPT' reconcile fail-delete\""
check 'incomplete reports omit raw provider bodies' "! grep -Rq 'Structured output\|Error output' '$REPO/.ai/reviews'"
printf 'PIPE-COMPAT\n' | (cd "$REPO" && eval "$ENV MUSE_STUB_TEXT='VERDICT: NO FINDINGS' '$SCRIPT' review '$REPO'") >/dev/null 2>&1
check 'compatibility review reads piped requests' "grep -Rlq 'PIPE-COMPAT' '$REPO/.ai/reviews'"
git -C "$REPO" checkout -q -- a.txt
check 'compatibility review rejects a stopped answer without verdict' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_TEXT=narration '$SCRIPT' review '$REPO' test\""
check 'compatibility review rejects a verdict before the final line' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_TEXT='VERDICT: NO FINDINGS\\nqualification' '$SCRIPT' review '$REPO' test\""
check 'compatibility review rejects an undefined verdict' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_TEXT='VERDICT: UNKNOWN' '$SCRIPT' review '$REPO' test\""
check 'compatibility review rejects a legacy undefined verdict' "cd '$REPO' && ! eval \"$ENV MUSE_STUB_TEXT='VERDICT: APPROVE' '$SCRIPT' review '$REPO' test\""
check 'compatibility review accepts an explicit verdict' "cd '$REPO' && eval \"$ENV MUSE_STUB_TEXT='VERDICT: NO FINDINGS' '$SCRIPT' review '$REPO' test\" | grep -q 'VERDICT: NO FINDINGS'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
