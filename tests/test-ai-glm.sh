#!/usr/bin/env bash
# Tests for bin/ai-glm and the OpenCode GLM harness.
#
# Offline by default: no server, no network, no Z.ai calls. The live probes that
# need a running server and a real GLM key run only with AI_GLM_LIVE=1.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AI_GLM="$REPO_ROOT/bin/ai-glm"
PASS=0; FAIL=0
ok()   { printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2"; then ok "$1"; else bad "$1"; fi; }

TMP="$(mktemp -d)"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

export AI_GLM_STATE_DIR="$TMP/state"
export AI_DEVOPS_CONFIG_DIR="$TMP/cfg"
export AI_GLM_PORT=59999          # nothing listens here, so "server down" paths are exercised
mkdir -p "$AI_GLM_STATE_DIR" "$AI_DEVOPS_CONFIG_DIR/opencode"

echo "== static checks =="
check "ai-glm is executable"                "test -x '$AI_GLM'"
check "ai-glm parses"                       "bash -n '$AI_GLM'"
check "setup-opencode-glm.sh parses"        "bash -n '$REPO_ROOT/bin/setup-opencode-glm.sh'"
check "retired launcher is gone"            "test ! -e '$REPO_ROOT/bin/ai-glm-agent'"
check "retired launcher not on PATH"        "! command -v ai-glm-agent"

echo "== pinned config =="
check "version file exists"                 "test -s '$REPO_ROOT/config/opencode/version'"
check "version is a bare semver"            "grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' '$REPO_ROOT/config/opencode/version'"
check "opencode.json is valid json"         "jq -e . '$REPO_ROOT/config/opencode/opencode.json' >/dev/null"
check "model is pinned to glm-5.3"          "jq -e '.model==\"zai-coding-plan/glm-5.3\"' '$REPO_ROOT/config/opencode/opencode.json' >/dev/null"
check "autoupdate disabled"                 "jq -e '.autoupdate==false' '$REPO_ROOT/config/opencode/opencode.json' >/dev/null"
check "sharing disabled"                    "jq -e '.share==\"disabled\"' '$REPO_ROOT/config/opencode/opencode.json' >/dev/null"

echo "== agent safety (the only working read-only enforcement) =="
for a in glm-review glm-implement; do
  f="$REPO_ROOT/config/opencode/agent/$a.md"
  check "$a exists"                         "test -f '$f'"
  check "$a has webfetch: false"            "grep -q '^  webfetch: false' '$f'"
  check "$a pins the model"                 "grep -q '^model: zai-coding-plan/glm-5.3$' '$f'"
done
check "glm-review has write: false"         "grep -q '^  write: false' '$REPO_ROOT/config/opencode/agent/glm-review.md'"
check "glm-review has edit: false"          "grep -q '^  edit: false'  '$REPO_ROOT/config/opencode/agent/glm-review.md'"
check "glm-review has NO bash tool"         "grep -q '^  bash: false' '$REPO_ROOT/config/opencode/agent/glm-review.md'"
check "glm-review explicitly allows todowrite" "grep -q '^  todowrite: true' '$REPO_ROOT/config/opencode/agent/glm-review.md'"
check "glm-implement can write"             "grep -q '^  write: true'  '$REPO_ROOT/config/opencode/agent/glm-implement.md'"
check "glm-implement HAS a bash tool"       "grep -q '^  bash: true'   '$REPO_ROOT/config/opencode/agent/glm-implement.md'"
check "glm-implement explicitly allows todowrite" "grep -q '^  todowrite: true' '$REPO_ROOT/config/opencode/agent/glm-implement.md'"
# The assertion text went stale when Windows long-path support added `-c core.longpaths`
# between `git` and `clone`. Match the clone flags and forbid `worktree add` instead, so
# the real constraint (hard-won constraint 2) is what is being checked.
check "sandbox is a clone, not a worktree"  "grep -q 'clone --quiet --no-hardlinks' '$AI_GLM' && ! grep -q 'git worktree add' '$AI_GLM'"
check "sandbox removes its git remote"      "grep -q 'remote remove origin' '$AI_GLM'"

echo "== systemd unit =="
U="$REPO_ROOT/config/systemd/opencode-glm.service"
check "unit exists"                         "test -f '$U'"
check "unit is a user service (uses %h)"    "grep -q '%h' '$U'"
check "unit has no secret material"         "! grep -qiE 'api[_-]?key|zhipu|zai_' '$U'"
check "unit rate-limits restarts"           "grep -q 'StartLimitBurst' '$U'"
check "unit sets NoNewPrivileges"           "grep -q 'NoNewPrivileges=true' '$U'"
check "unit does not bind publicly"         "! grep -qE 'hostname (0\.0\.0\.0|::)' '$U'"

echo "== cli contract =="
check "no command exits 0"                  "! '$AI_GLM' >/dev/null 2>&1"
check "unknown command rejected"            "! '$AI_GLM' frobnicate >/dev/null 2>&1"
check "help works"                          "'$AI_GLM' --help >/dev/null 2>&1"
for opt in --model --agent --system --tools --provider --directory --temperature --reasoning; do
  check "$opt is rejected"                  "! '$AI_GLM' ask x $opt y >/dev/null 2>&1"
  check "$opt error explains why"           "'$AI_GLM' ask x $opt y 2>&1 | grep -q 'not overridable'"
done

# doctor is normally invoked through the /usr/local/bin symlink; if it resolves the
# repo root from $0 without following the link it looks for config under /usr/local.
mkdir -p "$TMP/binlink"
ln -sf "$AI_GLM" "$TMP/binlink/ai-glm"
if [ -L "$TMP/binlink/ai-glm" ]; then
  check "doctor resolves through a symlink" "'$TMP/binlink/ai-glm' doctor 2>&1 | grep -q 'PASS  pinned version file present'"
else
  # Git Bash emulates ln -s as a copy when Windows symbolic links are disabled.
  ok "doctor symlink check skipped (host created a copy)"
fi

echo "== repository + session identity =="
mkdir -p "$TMP/repoA" "$TMP/repoB"
for d in repoA repoB; do
  git -C "$TMP/$d" init -q
  echo x > "$TMP/$d/f.txt"
  git -C "$TMP/$d" add -A
  git -C "$TMP/$d" -c user.email=t@example.com -c user.name=t commit -qm init
done
# Same basename in different places must NOT collide.
idA="$(cd "$TMP/repoA" && printf '%s\n%s' "$(git rev-parse --show-toplevel)" "" | sha256sum | cut -c1-12)"
idB="$(cd "$TMP/repoB" && printf '%s\n%s' "$(git rev-parse --show-toplevel)" "" | sha256sum | cut -c1-12)"
check "distinct repos get distinct ids"     "test '$idA' != '$idB'"
check "repo id is stable"                   "test '$idA' = \"\$(cd '$TMP/repoA' && printf '%s\n%s' \"\$(git rev-parse --show-toplevel)\" '' | sha256sum | cut -c1-12)\""
NEW_FN="$(sed -n '/^cmd_new()/,/^cmd_ask()/p' "$AI_GLM")"
LOCK_LINE="$(printf '%s\n' "$NEW_FN" | grep -n 'lock_acquire' | head -1 | cut -d: -f1)"
CREATE_LINE="$(printf '%s\n' "$NEW_FN" | grep -n 'sid=.*create_session' | head -1 | cut -d: -f1)"
check "new locks before server session creation" "test '$LOCK_LINE' -lt '$CREATE_LINE'"
check "failed metadata write deletes created server session" "printf '%s' \"\$NEW_FN\" | grep -q 'api DELETE.*session/\$sid'"

echo "== error paths without a server =="
check "new fails when server is down"       "! ( cd '$TMP/repoA' && '$AI_GLM' new probe --prompt hi ) >/dev/null 2>&1"
# Either message is fine as long as it names the exact next command: "not set up yet"
# (no password file) or "server not answering" (installed but down).
check "server-down message is actionable"   "( cd '$TMP/repoA' && '$AI_GLM' new probe --prompt hi 2>&1 ) | grep -qE 'setup-opencode-glm|ai-glm server start'"
check "ask on unknown session fails"        "! ( cd '$TMP/repoA' && '$AI_GLM' ask nope --prompt hi ) >/dev/null 2>&1"
check "invalid session name rejected"       "! ( cd '$TMP/repoA' && '$AI_GLM' new 'bad name!' --prompt hi ) >/dev/null 2>&1"
check "non-git directory rejected"          "! ( cd '$TMP' && '$AI_GLM' new probe --prompt hi ) >/dev/null 2>&1"
check "empty prompt rejected"               "! ( cd '$TMP/repoA' && printf '' | '$AI_GLM' new probe ) >/dev/null 2>&1"
check "missing prompt file rejected"        "! ( cd '$TMP/repoA' && '$AI_GLM' new probe --prompt-file /nope ) >/dev/null 2>&1"
check "list works with no sessions"         "'$AI_GLM' list >/dev/null 2>&1"

echo "== caller separation =="
mkdir -p "$AI_GLM_STATE_DIR/sessions/$idA"
printf '{"name":"shared","caller":"claude"}\n' > "$AI_GLM_STATE_DIR/sessions/$idA/claude--shared.json"
printf '{"name":"shared","caller":"codex"}\n'  > "$AI_GLM_STATE_DIR/sessions/$idA/codex--shared.json"
check "claude and codex sessions coexist"   "test -f '$AI_GLM_STATE_DIR/sessions/$idA/claude--shared.json' -a -f '$AI_GLM_STATE_DIR/sessions/$idA/codex--shared.json'"

echo "== worktree hygiene =="
check "no scratch worktrees leaked"         "test -z \"\$(find '$AI_GLM_STATE_DIR/wt' -mindepth 2 -maxdepth 2 -type d 2>/dev/null)\""
check "repoA has only its own worktree"     "test \"\$(git -C '$TMP/repoA' worktree list | wc -l)\" -eq 1"

echo "== secret hygiene =="
check "ai-glm never echoes a key"           "! grep -nE 'echo .*(ZHIPU_API_KEY|ZAI_API_KEY)' '$AI_GLM'"
check "launcher unsets ZAI_API_KEY"         "grep -q 'unset ZAI_API_KEY' '$REPO_ROOT/bin/setup-opencode-glm.sh'"
check "launcher guards empty key"           "grep -q 'resolved EMPTY' '$REPO_ROOT/bin/setup-opencode-glm.sh'"
check "launcher has re-exec guard"          "grep -q 'AI_GLM_LAUNCH_REEXEC' '$REPO_ROOT/bin/setup-opencode-glm.sh'"
check "mcp.env.example keeps ZAI_API_KEY"   "grep -q '^ZAI_API_KEY=op://' '$REPO_ROOT/config/mcp.env.example'"
check "dead ZAI_ANTHROPIC_BASE_URL gone"    "! grep -q '^ZAI_ANTHROPIC_BASE_URL=' '$REPO_ROOT/config/mcp.env.example'"
check "dead ZAI_GLM_MODEL gone"             "! grep -q '^ZAI_GLM_MODEL=' '$REPO_ROOT/config/mcp.env.example'"

echo "== skill =="
S="$REPO_ROOT/skills/shared/ask-glm/SKILL.md"
check "skill exists"                        "test -f '$S'"
check "skill tells callers to use ai-glm"   "grep -q 'ai-glm new' '$S'"
check "skill forbids calling opencode"      "grep -qi 'never call opencode' '$S'"
check "skill says continue, not recreate"   "grep -q 'ai-glm list' '$S'"
check "skill has no stale launcher ref"     "! grep -q 'ai-glm-agent' '$S'"
check "skill keeps todowrite wildcard narrow" "grep -q 'does not make .*. generally safe' '$S'"
check "skill names permission failure evidence" "grep -q 'whether the clone had unexported changes' '$S'"

echo "== doctor must report, not abort =="
# On Windows, doctor stopped after three lines: a missing binary made a command
# substitution fail and `set -e` ended the run, so Albert saw one FAIL and no report.
# Doctor must always print every check and exit non-zero.
BARE="$TMP/bare"; mkdir -p "$BARE/cfg"
dout="$(HOME="$BARE" AI_DEVOPS_CONFIG_DIR="$BARE/cfg" AI_GLM_STATE_DIR="$BARE/state" "$AI_GLM" doctor 2>&1)"
dn=$(printf '%s\n' "$dout" | grep -c 'PASS\|FAIL\|WARN')
check "doctor reports every check on a bare machine" "test $dn -ge 20"
check "doctor exits nonzero on a bare machine"       "! ( HOME='$BARE' AI_DEVOPS_CONFIG_DIR='$BARE/cfg' '$AI_GLM' doctor ) >/dev/null 2>&1"
check "doctor prints no stray error lines"           "! printf '%s' \"\$dout\" | grep -q 'ai-glm: error:'"
check "doctor knows Windows from Linux"              "grep -q 'IS_WINDOWS' '$AI_GLM'"
check "server control works on Windows"              "grep -q 'schtasks' '$AI_GLM'"

echo "== platform-correct doctor checks =="
# `stat -c %a` reports a synthesised mode on NTFS regardless of the ACL, so the 0600
# check failed on all three Windows machines even though the installer had locked the
# file down correctly. Windows must be checked with icacls.
check "password check is platform-aware"    "grep -q 'icacls' '$AI_GLM'"
# A grep over a file that does not exist on the platform always passes. That reads as
# assurance while checking nothing.
check "secret check targets real files"     "grep -q 'secret_targets' '$AI_GLM'"
check "no vacuous systemd-only secret check" "! grep -q 'no secret in the systemd unit' '$AI_GLM'"
# Vestiges get swept, not nagged about forever.
check "doctor sweeps the glm-claude vestige" "grep -q 'swept just now' '$AI_GLM'"
check "ubuntu setup sweeps it too"           "grep -q 'Removed retired' '$REPO_ROOT/bin/setup-opencode-glm.sh'"
check "windows setup sweeps it too"          "grep -q 'Removed retired' '$REPO_ROOT/bin/setup-opencode-glm.ps1'"

echo "== a down server must explain itself =="
# "FAIL health endpoint answers" on its own is not actionable. Doctor must say whether
# the service exists at all and give the exact next command.
check "health failure names a next command" "grep -q 'ai-glm server start' '$AI_GLM'"
check "health failure names the setup script" "grep -q 'setup-opencode-glm' '$AI_GLM'"
check "health failure shows recent log lines"  "grep -qE 'journalctl --user -u opencode-glm -n|tail -n 12' '$AI_GLM'"
DOWN_OUT="$(HOME="$BARE" AI_DEVOPS_CONFIG_DIR="$BARE/cfg" AI_GLM_STATE_DIR="$BARE/state" bash -c 'source "'$AI_GLM'"; mkdir -p "$(dirname "$PW_FILE")"; printf x > "$PW_FILE"; require_server' 2>&1 || true)"
check "review path names a local dependency failure" "printf '%s' \"\$DOWN_OUT\" | grep -q 'failure: local_dependency_unavailable'"
check "review path does not blame the provider" "printf '%s' \"\$DOWN_OUT\" | grep -q 'LOCAL SERVICE fault.*NOT a provider or model fault'"
check "review path gives the recovery command" "printf '%s' \"\$DOWN_OUT\" | grep -q 'Start it with: ai-glm server start'"

echo "== server start means healthy, not merely launched =="
server_fixture() { # PLATFORM MODE COMMAND
  local platform="$1" mode="$2" command="$3"
  AI_GLM_SOURCE="$AI_GLM" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" FIX_PLATFORM="$platform" FIX_MODE="$mode" FIX_COMMAND="$command" FIX_LOG="$TMP/server-fixture.log" \
    AI_GLM_SERVER_READY_TIMEOUT=3 AI_GLM_SERVER_READY_INTERVAL=1 bash -c '
      source "$AI_GLM_SOURCE"; IS_WINDOWS="$FIX_PLATFORM"; COUNT=0; : > "$FIX_LOG"
      server_up(){ COUNT=$((COUNT+1)); case "$FIX_MODE" in already) return 0;; delayed) [ "$COUNT" -ge 3 ];; *) return 1;; esac; }
      sleep(){ :; }
      systemctl(){ printf "systemctl %s\n" "$*" >> "$FIX_LOG"; [ "$FIX_MODE" != launchfail ]; }
      schtasks(){ printf "schtasks %s\n" "$*" >> "$FIX_LOG"; [ "$FIX_MODE" != launchfail ]; }
      cmd_server "$FIX_COMMAND"
    '
}
check "linux start waits through delayed readiness" "server_fixture 0 delayed start 2>&1 | grep -q 'started and healthy'"
check "windows start waits through delayed readiness" "server_fixture 1 delayed start 2>&1 | grep -q 'started and healthy'"
check "already healthy start does not relaunch" "server_fixture 0 already start 2>&1 | grep -q 'already healthy' && [ ! -s '$TMP/server-fixture.log' ]"
check "linux launch failure is nonzero" "! server_fixture 0 launchfail start >/dev/null 2>&1"
check "windows launch failure is nonzero" "! server_fixture 1 launchfail start >/dev/null 2>&1"
check "never healthy start is bounded and nonzero" "! server_fixture 0 never start >/dev/null 2>&1"
check "linux restart also waits for readiness" "server_fixture 0 delayed restart 2>&1 | grep -q 'restarted and healthy'"

echo "== completion rule =="
check "requires finish==stop"               "grep -q 'finish\" = \"stop\"' '$AI_GLM' || grep -q 'finish\" = \"stop' '$AI_GLM'"
check "requires two idle polls"             "grep -q 'idle\" -ge 2' '$AI_GLM' || grep -q 'idle -ge 2' '$AI_GLM'"
check "detects the 400 permission wedge"    "grep -q 'InvalidRequestError' '$AI_GLM'"
check "names the stuck tool on timeout"     "grep -q 'tool still running' '$AI_GLM'"
check "default timeout remains 1800s"       "grep -q 'AI_GLM_TIMEOUT:-1800' '$AI_GLM'"
# The review directory is the boundary the permission classifier measures against,
# and since 2026-08-17 it is the snapshot directory in a linked worktree — never
# the raw worktree, whose git control files sit outside any single-directory
# boundary. See bin/ai-review-sandbox and tests/test-ai-review-sandbox.sh.
if grep -Fq 'await_turn "$sid" "$name" review "$boundary"' "$AI_GLM"; then ok "new passes review directory"; else bad "new passes review directory"; fi
if [ "$(grep -Fc 'await_turn "$sid" "$name" review "$boundary"' "$AI_GLM")" -eq 2 ]; then ok "ask passes review directory"; else bad "ask passes review directory"; fi
# Since issue #53, new sessions create a private copy and continuations refresh
# the exact directory recorded when OpenCode created the session.
if grep -Fq 'prepare_review "$root" "$name" "$boundary"' "$AI_GLM"; then ok "ask reuses recorded review directory"; else bad "ask reuses recorded review directory"; fi
if [ "$(grep -Fc 'boundary="$REVIEW_DIR"' "$AI_GLM")" -eq 2 ]; then ok "boundary comes from prepare_review"; else bad "boundary comes from prepare_review"; fi
check "new reviews always use a private copy" "grep -Fq 'ensure-copy \"\$1\" \"glm-\$2\"' '$AI_GLM'"
check "new review records its fixed directory" "grep -Fq 'boundary_root:\$b' '$AI_GLM'"
check "legacy live-checkout session warns once" "grep -Fq 'boundary_migration_warned=true' '$AI_GLM'"
check "prepare_review builds an evidence packet" "grep -Fq '\$PACKET_BIN\" build' '$AI_GLM'"
check "review prompt points at the packet"   "grep -Fq '.ai-review/MANIFEST.md' '$AI_GLM'"
check "packet does not fence the reviewer in" "grep -Fq 'not a boundary' '$AI_GLM'"
check "wrapper derives head itself"          "grep -Fq 'REVIEW_HEAD=\"\$(git -C \"\$REVIEW_DIR\" rev-parse HEAD' '$AI_GLM'"
check "caller sha is only ever checked"      "grep -Fq 'assert-head does not match' '$AI_GLM'"
check "stale head is announced"              "grep -Fq 'The earlier evidence is STALE' '$AI_GLM'"
if grep -Fq 'create_session "$name" glm-review "$boundary"' "$AI_GLM"; then ok "session is created on the safe boundary"; else bad "session is created on the safe boundary"; fi
if grep -Fq 'await_turn "$IMPL_SID" "$name" implement "$IMPL_CLONE" "$IMPL_META"' "$AI_GLM"; then ok "implement passes sandbox directory"; else bad "implement passes sandbox directory"; fi

echo "== permission classifier =="
run_classifier() { # MODE ROOT STATUS BODY
  AI_GLM_SOURCE="$AI_GLM" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" AI_GLM_STATE_DIR="$TMP/state" \
    MODE_FIX="$1" ROOT_ARG="$2" STATUS_FIX="$3" BODY_FIX="$4" \
    bash -c 'source "$AI_GLM_SOURCE"; classify_permissions "$MODE_FIX" "$ROOT_ARG" "$STATUS_FIX" "$BODY_FIX"'
}
ROOT_FIX="$(cd "$TMP/repoA" && pwd)"
IN_FIX="$ROOT_FIX/sub/file.txt"; OUT_FIX="$(cd "$TMP" && pwd)/outside.txt"
check "empty data envelope is valid"       "test -z \"\$(run_classifier review '$ROOT_FIX' 200 '{\"data\":[]}')\""
check "unmeasured bare array fails closed"  "! run_classifier review '$ROOT_FIX' 200 '[]' >/dev/null 2>&1"
for action in read list glob grep; do
  check "in-directory $action is approved" "run_classifier review '$ROOT_FIX' 200 '{\"data\":[{\"id\":\"p-$action\",\"action\":\"$action\",\"resources\":[\"$IN_FIX\"]}]}' | grep -q \"p-$action\""
done
TODO_PERMISSION='{"data":[{"id":"ptodo","action":"TodoWrite","resources":["*"],"save":["*"],"source":{"type":"tool"}}]}'
check "measured todowrite shape is approved" "run_classifier review '$ROOT_FIX' 200 '$TODO_PERMISSION' | grep -q $'ptodo\\ttodowrite'"
check "todowrite wildcard is action-local"  "run_classifier implement '$ROOT_FIX' 200 '$TODO_PERMISSION' | grep -q ptodo"
check "todowrite rejects a path resource"   "! run_classifier review '$ROOT_FIX' 200 '{\"data\":[{\"id\":\"pt\",\"action\":\"todowrite\",\"resources\":[\"$IN_FIX\"],\"save\":[\"*\"]}]}' >/dev/null 2>&1"
check "todowrite rejects missing save shape" "! run_classifier review '$ROOT_FIX' 200 '{\"data\":[{\"id\":\"pt\",\"action\":\"todowrite\",\"resources\":[\"*\"]}]}' >/dev/null 2>&1"
check "todowrite rejects broader save shape" "! run_classifier review '$ROOT_FIX' 200 '{\"data\":[{\"id\":\"pt\",\"action\":\"todowrite\",\"resources\":[\"*\"],\"save\":[\"*\",\"other\"]}]}' >/dev/null 2>&1"
check "implementation root is classified" "run_classifier implement '$ROOT_FIX' 200 '{\"data\":[{\"id\":\"pi\",\"action\":\"read\",\"resources\":[\"sub/file.txt\"]}]}' | grep -q pi"
check "outside-directory resource fails"   "! run_classifier review '$ROOT_FIX' 200 '{\"data\":[{\"id\":\"po\",\"action\":\"read\",\"resources\":[\"$OUT_FIX\"]}]}' >/dev/null 2>&1"
check "mixed resource set fails closed"    "! run_classifier review '$ROOT_FIX' 200 '{\"data\":[{\"id\":\"pmix\",\"action\":\"read\",\"resources\":[\"$IN_FIX\",\"$OUT_FIX\"]}]}' >/dev/null 2>&1"
check "external-directory action fails"    "! run_classifier review '$ROOT_FIX' 200 '{\"data\":[{\"id\":\"pext\",\"action\":\"external_directory\",\"resources\":[\"$OUT_FIX/*\"]}]}' >/dev/null 2>&1"
check "unknown action fails"               "! run_classifier review '$ROOT_FIX' 200 '{\"data\":[{\"id\":\"px\",\"action\":\"bash\",\"resources\":[\"$IN_FIX\"]}]}' >/dev/null 2>&1"
check "missing id fails"                   "! run_classifier review '$ROOT_FIX' 200 '{\"data\":[{\"action\":\"read\",\"resources\":[\"$IN_FIX\"]}]}' >/dev/null 2>&1"
check "missing resources fails"            "! run_classifier review '$ROOT_FIX' 200 '{\"data\":[{\"id\":\"pm\",\"action\":\"read\"}]}' >/dev/null 2>&1"
check "malformed JSON fails"               "! run_classifier review '$ROOT_FIX' 200 '{oops' >/dev/null 2>&1"
check "unsupported envelope fails"         "! run_classifier review '$ROOT_FIX' 200 '{\"items\":[]}' >/dev/null 2>&1"
check "InvalidRequestError fails"          "! run_classifier review '$ROOT_FIX' 400 '{\"_tag\":\"InvalidRequestError\"}' >/dev/null 2>&1"
check "other HTTP failure fails"           "! run_classifier review '$ROOT_FIX' 503 '{\"error\":\"down\"}' >/dev/null 2>&1"
check "unknown mode fails"                 "! run_classifier unsafe '$ROOT_FIX' 200 '[]' >/dev/null 2>&1"

SECRET_FIX='{"token":"tok-visible","authorization":"auth-visible","secret":"sec-visible","credential":"cred-visible","password":"pw-visible","content":"body-visible","value":"val-visible"}'
SAN="$(AI_GLM_SOURCE="$AI_GLM" BODY_FIX="$SECRET_FIX" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" bash -c 'source "$AI_GLM_SOURCE"; sanitize_permission_body "$BODY_FIX"')"
check "diagnostic redacts sensitive fields" "! printf '%s' '$SAN' | grep -qE 'tok-visible|auth-visible|sec-visible|cred-visible|pw-visible|body-visible|val-visible'"
LONG_FIX="$(printf 'x%.0s' {1..3000})"
LONG_SAN="$(AI_GLM_SOURCE="$AI_GLM" BODY_FIX="$LONG_FIX" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" bash -c 'source "$AI_GLM_SOURCE"; sanitize_permission_body "$BODY_FIX"')"
check "diagnostic is capped after redaction" "test \"${#LONG_SAN}\" -le 2060"
check "diagnostic marks truncation"          "printf '%s' '$LONG_SAN' | grep -q '\[truncated\]'"
check "failed approval fails closed"         "! AI_GLM_SOURCE='$AI_GLM' ROOT_FIX='$ROOT_FIX' IN_FIX='$IN_FIX' AI_DEVOPS_CONFIG_DIR='$TMP/cfg' bash -c 'source \"\$AI_GLM_SOURCE\"; permission_http(){ if [ \"\$1\" = GET ]; then HTTP_STATUS=200; HTTP_BODY=\"{\\\"data\\\":[{\\\"id\\\":\\\"p1\\\",\\\"action\\\":\\\"read\\\",\\\"resources\\\":[\\\"\$IN_FIX\\\"]}]}\"; else HTTP_STATUS=500; HTTP_BODY=\"{\\\"error\\\":\\\"reply failed\\\"}\"; fi; }; handle_permissions s n review \"\$ROOT_FIX\"' >/dev/null 2>&1"
check "uncleared approval fails by third poll" "! AI_GLM_SOURCE='$AI_GLM' ROOT_FIX='$ROOT_FIX' IN_FIX='$IN_FIX' AI_DEVOPS_CONFIG_DIR='$TMP/cfg' bash -c 'source \"\$AI_GLM_SOURCE\"; permission_http(){ HTTP_STATUS=200; if [ \"\$1\" = GET ]; then HTTP_BODY=\"{\\\"data\\\":[{\\\"id\\\":\\\"p1\\\",\\\"action\\\":\\\"read\\\",\\\"resources\\\":[\\\"\$IN_FIX\\\"]}]}\"; else HTTP_BODY=\"{}\"; fi; }; handle_permissions s n review \"\$ROOT_FIX\"; handle_permissions s n review \"\$ROOT_FIX\"; handle_permissions s n review \"\$ROOT_FIX\"' >/dev/null 2>&1"

echo "== permission failure is diagnosable (step 1) =="
reason_id() { # REASON -> stable branch slug
  AI_GLM_SOURCE="$AI_GLM" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" REASON_FIX="$1" \
    bash -c 'source "$AI_GLM_SOURCE"; permission_reason_id "$REASON_FIX"'
}
capture_reason() { # MODE ROOT STATUS BODY -> the exact classifier stderr reason
  run_classifier "$1" "$2" "$3" "$4" 2>&1 >/dev/null
}
# Every classifier rejection branch must be recoverable from the durable record. Before
# 2026-08-12 five of these collapsed into one code and the reason went only to stderr.
BRANCH_IDS=""
add_branch() { BRANCH_IDS="$BRANCH_IDS$(reason_id "$(capture_reason "$@")")"$'\n'; }
add_branch review "$ROOT_FIX" 000 ''
add_branch review "$ROOT_FIX" 400 '{"_tag":"InvalidRequestError"}'
add_branch review "$ROOT_FIX" 503 '{"error":"down"}'
add_branch review "$ROOT_FIX" 200 '{oops'
add_branch review "$ROOT_FIX" 200 '{"items":[]}'
add_branch review "$ROOT_FIX" 200 "{\"data\":[{\"action\":\"read\",\"resources\":[\"$IN_FIX\"]}]}"
add_branch review "$ROOT_FIX" 200 "{\"data\":[{\"id\":\"px\",\"action\":\"bash\",\"resources\":[\"$IN_FIX\"]}]}"
add_branch review "$ROOT_FIX" 200 '{"data":[{"id":"pm","action":"read"}]}'
add_branch review "$ROOT_FIX" 200 '{"data":[{"id":"pt","action":"todowrite","resources":["*"]}]}'
add_branch review "$ROOT_FIX" 200 "{\"data\":[{\"id\":\"po\",\"action\":\"read\",\"resources\":[\"$OUT_FIX\"]}]}"
BRANCH_COUNT="$(printf '%s' "$BRANCH_IDS" | grep -c . || true)"
BRANCH_UNIQUE="$(printf '%s' "$BRANCH_IDS" | grep . | sort -u | wc -l | tr -d ' ')"
check "every classifier branch is distinguishable" "test '$BRANCH_COUNT' -eq 10 -a '$BRANCH_UNIQUE' -eq 10"
check "no branch falls through unclassified"       "! printf '%s' '$BRANCH_IDS' | grep -q unclassified"
check "unknown action branch names its action" "test \"\$(AI_GLM_SOURCE='$AI_GLM' AI_DEVOPS_CONFIG_DIR='$TMP/cfg' REASON_FIX=\"\$(capture_reason review '$ROOT_FIX' 200 '{\"data\":[{\"id\":\"px\",\"action\":\"bash\",\"resources\":[\"$IN_FIX\"]}]}')\" bash -c 'source \"\$AI_GLM_SOURCE\"; permission_reason_action \"\$REASON_FIX\"')\" = bash"
DETAIL="$(AI_GLM_SOURCE="$AI_GLM" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" BODY_FIX="$SECRET_FIX" \
  bash -c 'source "$AI_GLM_SOURCE"; permission_failure_detail "unknown permission action: bash" 200 implement missing "$BODY_FIX"')"
check "failure detail is valid JSON with a branch id" "printf '%s' '$DETAIL' | jq -e '.reason_id==\"unknown-action\" and .action==\"bash\" and .status==\"200\" and .mode==\"implement\"' >/dev/null"
check "failure detail redacts secrets"                "! printf '%s' '$DETAIL' | grep -qE 'tok-visible|auth-visible|sec-visible|cred-visible|pw-visible|body-visible|val-visible'"

echo "== transport failure is not a permission failure (step 7) =="
transport_probe() { # CURL_RC ATTEMPTS -> prints one line per curl attempt, then STATUS
  AI_GLM_SOURCE="$AI_GLM" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" CURL_RC="$1" \
    AI_GLM_PERMISSION_HTTP_ATTEMPTS="$2" AI_GLM_PERMISSION_HTTP_RETRY_SECS=0 \
    CALL_LOG="$TMP/curl-calls" \
    bash -c 'source "$AI_GLM_SOURCE"; server_pw(){ printf pw; }
      : > "$CALL_LOG"
      curl(){ printf "attempt\n" >> "$CALL_LOG"; [ "$(wc -l < "$CALL_LOG")" -ge "$CURL_RC" ] && { printf 200; return 0; }; return 7; }
      permission_http GET /api/session/s/permission; printf "%s" "$HTTP_STATUS"'
}
TRANSPORT_STATUS="$(transport_probe 99 3)"; TRANSPORT_TRIES="$(wc -l < "$TMP/curl-calls" | tr -d ' ')"
check "a dropped local poll is retried to the bound" "test '$TRANSPORT_TRIES' -eq 3 -a '$TRANSPORT_STATUS' = 000"
RECOVER_STATUS="$(transport_probe 3 3)"; RECOVER_TRIES="$(wc -l < "$TMP/curl-calls" | tr -d ' ')"
check "a poll that recovers stops retrying"          "test '$RECOVER_TRIES' -eq 3 -a '$RECOVER_STATUS' = 200"
check "status 000 is classified as transport"        "capture_reason review '$ROOT_FIX' 000 '' | grep -q 'local permission endpoint did not answer'"
check "status 000 is not called a permission problem" "! capture_reason review '$ROOT_FIX' 000 '' | grep -qi 'permission response\\|unknown permission action'"
check "transport branch has its own id"              "test \"\$(reason_id \"\$(capture_reason review '$ROOT_FIX' 000 '')\")\" = transport-no-reply"
check "a real HTTP 500 still fails closed as permission" "capture_reason review '$ROOT_FIX' 500 '{\"error\":\"boom\"}' | grep -q 'permission endpoint returned HTTP 500'"
TRANSPORT_MSG="$(AI_GLM_SOURCE="$AI_GLM" ROOT_FIX="$ROOT_FIX" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" \
  bash -c 'source "$AI_GLM_SOURCE"; permission_http(){ HTTP_STATUS=000; HTTP_BODY=""; }; handle_permissions s n review "$ROOT_FIX"' 2>&1 || true)"
check "transport message names doctor and server status" "printf '%s' \"\$TRANSPORT_MSG\" | grep -q 'ai-glm doctor' && printf '%s' \"\$TRANSPORT_MSG\" | grep -q 'ai-glm server status'"
check "transport message does not claim a permission failure" "! printf '%s' \"\$TRANSPORT_MSG\" | grep -q 'GLM permission failed'"

RUNNING_OUTSIDE="{\"content\":[{\"type\":\"tool\",\"name\":\"read\",\"state\":{\"status\":\"running\",\"input\":{\"filePath\":\"$OUT_FIX\"}}}]}"
RUNNING_INSIDE="{\"content\":[{\"type\":\"tool\",\"name\":\"read\",\"state\":{\"status\":\"running\",\"input\":{\"filePath\":\"$IN_FIX\"}}}]}"
check "running outside read is deterministic" "AI_GLM_SOURCE='$AI_GLM' MSG_FIX='$RUNNING_OUTSIDE' ROOT_FIX='$ROOT_FIX' AI_DEVOPS_CONFIG_DIR='$TMP/cfg' bash -c 'source \"\$AI_GLM_SOURCE\"; test \"\$(running_read_boundary \"\$MSG_FIX\" \"\$ROOT_FIX\")\" = outside'"
check "running inside read remains legitimate" "AI_GLM_SOURCE='$AI_GLM' MSG_FIX='$RUNNING_INSIDE' ROOT_FIX='$ROOT_FIX' AI_DEVOPS_CONFIG_DIR='$TMP/cfg' bash -c 'source \"\$AI_GLM_SOURCE\"; test \"\$(running_read_boundary \"\$MSG_FIX\" \"\$ROOT_FIX\")\" = inside'"
check "unmeasured running input is not guessed" "AI_GLM_SOURCE='$AI_GLM' ROOT_FIX='$ROOT_FIX' AI_DEVOPS_CONFIG_DIR='$TMP/cfg' bash -c 'source \"\$AI_GLM_SOURCE\"; test \"\$(running_read_boundary '\''{\"content\":[{\"type\":\"tool\",\"name\":\"read\",\"state\":{\"status\":\"running\",\"input\":{\"path\":\"elsewhere\"}}}]}'\'' \"\$ROOT_FIX\")\" = missing'"

echo "== implementation job records =="
JOB_STATE="$TMP/jobs"; mkdir -p "$JOB_STATE"; : > "$TMP/job-calls"; : > "$TMP/job-permission-calls"
JOB_ID="$(AI_GLM_SOURCE="$AI_GLM" AI_GLM_STATE_DIR="$JOB_STATE" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" JOB_REPO="$TMP/repoA" bash -c 'source "$AI_GLM_SOURCE"; repo_id "$JOB_REPO"')"
run_fake_impl() { # NAME [pause point] [ready] [release] [turn result] [failure point] [make change]
  local name="$1" pause="${2:-}" ready="${3:-$TMP/no-ready}" release="${4:-$TMP/no-release}" turn="${5:-success}" fail="${6:-}" change="${7:-0}"
  AI_GLM_SOURCE="$AI_GLM" AI_GLM_STATE_DIR="$JOB_STATE" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" \
    JOB_REPO="$TMP/repoA" JOB_NAME="$name" JOB_PAUSE="$pause" JOB_READY="$ready" \
    JOB_RELEASE="$release" JOB_TURN="$turn" JOB_FAIL="$fail" JOB_CHANGE="$change" \
    JOB_CALLS="$TMP/job-calls" JOB_PERMISSION_CALLS="$TMP/job-permission-calls" \
    bash -c '
      source "$AI_GLM_SOURCE"
      require_server(){ :; }; server_up(){ return 0; }; api(){ printf "{}"; }
      permission_http(){
        if [ "$JOB_TURN" = permission ]; then
          printf "%s %s\n" "$1" "$2" >> "$JOB_PERMISSION_CALLS"
          HTTP_STATUS=200
          HTTP_BODY='\''{"data":[{"id":"blocked-1","action":"question","resources":["*"]}]}'\''
        elif [ "$JOB_TURN" = transport ]; then
          case "$1 $2" in
            "GET "*/permission) printf "%s %s\n" "$1" "$2" >> "$JOB_PERMISSION_CALLS"; HTTP_STATUS=000; HTTP_BODY="" ;;
            *) HTTP_STATUS=200; HTTP_BODY="{}" ;;
          esac
        else
          HTTP_STATUS=200; HTTP_BODY="{}"
        fi
      }
      make_fixture_change(){
        case "$JOB_CHANGE" in
          0) ;;
          tracked) printf "changed by fixture\n" > "$1/f.txt" ;;
          binary) printf "\000\001\002GLM-PARTIAL\377" > "$1/partial.bin" ;;
          *) printf "unexported partial work\n" > "$1/partial.txt" ;;
        esac
      }
      create_session(){ printf "%s\n" "$JOB_NAME" >> "$JOB_CALLS"; make_fixture_change "$3"; printf "sid-%s" "$JOB_NAME"; }
      send_prompt(){ :; }
      last_assistant(){
        if [ "$JOB_TURN" = usage ]; then
          printf "%s" '\''{"finish":"error","content":[{"type":"text","text":"Usage limit reached for this billing cycle. SECRET-FIXTURE-MUST-NOT-PERSIST"}]}'\''
        else printf "{}"; fi
      }
      await_turn(){
        if [ "$JOB_TURN" = permission ] || [ "$JOB_TURN" = transport ]; then
          handle_permissions "$1" "$2" "$3" "$4" "$5"
        fi
        if [ "$JOB_TURN" = timeout ]; then
          implementation_update "$5" '\''.failure="turn-timeout" | .failure_summary="turn deadline passed without proven completion"'\''
          return 124
        fi
        [ "$JOB_TURN" = success ] || return 1
        printf "%s" '\''{"finish":"stop","model":{"id":"glm-5.3"},"content":[{"type":"text","text":"done"}],"tokens":null}'\''
      }
      PROMPT_TEXT=fixture; PROMPT_FILE=""; REPO_OVERRIDE="$JOB_REPO"; CALLER=codex
      AI_GLM_TEST_MODE=1; AI_GLM_TEST_PAUSE_AT="$JOB_PAUSE"; AI_GLM_TEST_READY="$JOB_READY"; AI_GLM_TEST_RELEASE="$JOB_RELEASE"; AI_GLM_TEST_FAIL_AT="$JOB_FAIL"
      cmd_implement "$JOB_NAME"
    ' &
  local impl_pid=$! impl_rc
  trap 'kill -TERM "$impl_pid" 2>/dev/null || true; wait "$impl_pid" 2>/dev/null || true; exit 143' TERM INT HUP
  wait "$impl_pid"; impl_rc=$?
  trap - TERM INT HUP
  return "$impl_rc"
}
job_meta() { printf '%s/sessions/%s/codex--%s.json' "$JOB_STATE" "$JOB_ID" "$1"; }
wait_file() { local f="$1" n=0; while [ ! -e "$f" ] && [ "$n" -lt 100 ]; do sleep 0.1; n=$((n+1)); done; [ -e "$f" ]; }

READY="$TMP/record-ready"; RELEASE="$TMP/record-release"
run_fake_impl exclusive record "$READY" "$RELEASE" >"$TMP/exclusive.out" 2>&1 & exclusive_pid=$!
wait_file "$READY"
EX_META="$(job_meta exclusive)"
check "implement_record_exists_before_clone_creation" "test -f '$EX_META' -a \"\$(jq -r .status '$EX_META')\" = starting -a \"\$(jq -r .clone_path '$EX_META')\" = null"
check "implement_list_and_show_are_type_and_state_aware" "AI_GLM_CALLER=codex AI_GLM_STATE_DIR='$JOB_STATE' '$AI_GLM' list | grep -qE 'exclusive.*implementation.*starting' && (cd '$TMP/repoA' && AI_GLM_CALLER=codex AI_GLM_STATE_DIR='$JOB_STATE' '$AI_GLM' show exclusive | jq -e '.type==\"implementation\" and .status==\"starting\"' >/dev/null)"
before_calls="$(wc -l < "$TMP/job-calls" 2>/dev/null || echo 0)"
run_fake_impl exclusive >"$TMP/duplicate.out" 2>&1; duplicate_rc=$?
after_calls="$(wc -l < "$TMP/job-calls" 2>/dev/null || echo 0)"
check "concurrent_same_name_implement_creates_one_job_and_session" "test $duplicate_rc -ne 0 -a '$before_calls' = '$after_calls' && grep -q 'No clone, server session, or provider turn' '$TMP/duplicate.out'"
check "implement_record_is_private_and_contains_no_prompt_or_secret" "(case \"\$(uname -s)\" in MINGW*|MSYS*|CYGWIN*) grep -q 'chmod 0600' '$AI_GLM' ;; *) test \"\$(stat -c %a '$EX_META')\" = 600 ;; esac) && ! jq -r 'tostring' '$EX_META' | grep -qiE 'fixture|prompt text|secret-value|credential-value|password-value'"
check "implement_ask_is_rejected_as_one_shot" "! (cd '$TMP/repoA' && AI_GLM_CALLER=codex AI_GLM_STATE_DIR='$JOB_STATE' '$AI_GLM' ask exclusive --prompt again) >/dev/null 2>&1"
check "delete_refuses_active_implementation_job" "! (cd '$TMP/repoA' && AI_GLM_CALLER=codex AI_GLM_STATE_DIR='$JOB_STATE' '$AI_GLM' delete exclusive) >/dev/null 2>&1"
AI_GLM_SOURCE="$AI_GLM" AI_GLM_STATE_DIR="$JOB_STATE" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" JOB_REPO="$TMP/repoA" \
  bash -c 'source "$AI_GLM_SOURCE"; require_server(){ :; }; permission_http(){ HTTP_STATUS=200; HTTP_BODY="{}"; }; REPO_OVERRIDE="$JOB_REPO"; CALLER=codex; cmd_abort exclusive' >/dev/null 2>&1
check "starting-job abort is recorded before a server session exists" "test \"\$(jq -r .status '$EX_META')\" = abort-requested"
check "starting-job abort has no clone to delete" "test \"\$(jq -r .clone_path '$EX_META')\" = null"
touch "$RELEASE"; wait "$exclusive_pid" || true
check "pre-resource abort records terminal state" "test \"\$(jq -r .status '$EX_META')\" = aborted -a \"\$(jq -r .cleanup.clone '$EX_META')\" = none"

SESSION_READY="$TMP/session-ready"; SESSION_RELEASE="$TMP/session-release"; ABORT_LOG="$TMP/abort-log"
run_fake_impl exact-abort session "$SESSION_READY" "$SESSION_RELEASE" >"$TMP/exact-abort.out" 2>&1 & exact_abort_pid=$!
wait_file "$SESSION_READY"; EXACT_META="$(job_meta exact-abort)"; EXACT_CLONE="$JOB_STATE/wt/$JOB_ID/codex--exact-abort"
AI_GLM_SOURCE="$AI_GLM" AI_GLM_STATE_DIR="$JOB_STATE" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" JOB_REPO="$TMP/repoA" ABORT_LOG="$ABORT_LOG" \
  bash -c 'source "$AI_GLM_SOURCE"; require_server(){ :; }; permission_http(){ printf "%s\n" "$1 $2" >> "$ABORT_LOG"; HTTP_STATUS=200; HTTP_BODY="{}"; }; REPO_OVERRIDE="$JOB_REPO"; CALLER=codex; cmd_abort exact-abort' >/dev/null 2>&1
check "abort_targets_exact_active_implementation_session" "grep -q 'POST /session/sid-exact-abort/abort' '$ABORT_LOG' && test \"\$(jq -r .status '$EXACT_META')\" = abort-requested"
check "abort_never_deletes_live_clone_from_control_process" "test -d '$EXACT_CLONE'"
touch "$SESSION_RELEASE"; wait "$exact_abort_pid" || true
check "abort owner records terminal state and cleans exact resources" "test \"\$(jq -r .status '$EXACT_META')\" = aborted -a ! -e '$EXACT_CLONE' -a \"\$(jq -r .cleanup.server_session '$EXACT_META')\" = removed"
check "aborted-no-changes outcome creates no patch" "jq -e '.outcome==\"aborted-no-changes\" and .incomplete_patch_path==null and .patch_exists==false' '$EXACT_META' >/dev/null"

SIGNAL_READY="$TMP/signal-ready"; SIGNAL_RELEASE="$TMP/signal-release"
run_fake_impl interrupted session "$SIGNAL_READY" "$SIGNAL_RELEASE" success '' untracked >"$TMP/interrupted.out" 2>&1 & signal_pid=$!
wait_file "$SIGNAL_READY"; SIGNAL_META="$(job_meta interrupted)"; SIGNAL_CLONE="$JOB_STATE/wt/$JOB_ID/codex--interrupted"
kill -TERM "$signal_pid" 2>/dev/null || true; wait "$signal_pid" || true
check "interrupt_records_terminal_state_and_cleans" "test \"\$(jq -r .status '$SIGNAL_META')\" = aborted -a \"\$(jq -r .failure '$SIGNAL_META')\" = interrupted -a ! -e '$SIGNAL_CLONE'"
check "aborted-partial exports before cleanup" "jq -e '.outcome==\"aborted-partial\" and .patch_exists==true and (.incomplete_patch_path|endswith(\".incomplete.patch\"))' '$SIGNAL_META' >/dev/null"

run_fake_impl normal >"$TMP/normal.out" 2>&1; normal_rc=$?
NORMAL_META="$(job_meta normal)"; NORMAL_CLONE="$JOB_STATE/wt/$JOB_ID/codex--normal"
check "implement_record_adds_clone_and_session_atomically" "jq -e '.opencode_session_id==\"sid-normal\" and .clone_path!=null' '$NORMAL_META' >/dev/null"
check "normal_and_no_change_completion_clean_resources" "test $normal_rc -eq 0 -a \"\$(jq -r .status '$NORMAL_META')\" = completed -a ! -e '$NORMAL_CLONE' -a \"\$(jq -r .cleanup.server_session '$NORMAL_META')\" = removed"
check "complete run keeps distinct normal artifacts" "jq -e '.outcome==\"completed\" and .incomplete_patch_path==null and (.patch_path|endswith(\".patch\")) and (.patch_path|contains(\".incomplete.\")|not)' '$NORMAL_META' >/dev/null"
run_fake_impl failed '' "$TMP/no-ready" "$TMP/no-release" failure >"$TMP/failed.out" 2>&1; failed_rc=$?
FAILED_META="$(job_meta failed)"; FAILED_CLONE="$JOB_STATE/wt/$JOB_ID/codex--failed"
check "provider_and_permission_failures_record_failure_and_clean" "test $failed_rc -ne 0 -a \"\$(jq -r .status '$FAILED_META')\" = failed -a ! -e '$FAILED_CLONE'"
check "failed-no-changes is truthful and has no empty patch" "jq -e '.outcome==\"failed-no-changes\" and .failure_kind==\"provider-or-service\" and .changes_present==false and .patch_exists==false and .incomplete_patch_path==null and .provider_usage_state==\"unavailable\"' '$FAILED_META' >/dev/null"

run_fake_impl failed-partial '' "$TMP/no-ready" "$TMP/no-release" failure '' untracked >"$TMP/failed-partial.out" 2>&1; failed_partial_rc=$?
FAILED_PARTIAL_META="$(job_meta failed-partial)"; FAILED_PARTIAL_PATCH="$(jq -r .incomplete_patch_path "$FAILED_PARTIAL_META")"
check "failed-partial exports and stays nonzero" "test $failed_partial_rc -ne 0 -a -s '$FAILED_PARTIAL_PATCH' && jq -e '.outcome==\"failed-partial\" and .artifact_state==\"durable\"' '$FAILED_PARTIAL_META' >/dev/null"
check "untracked incomplete patch applies to captured base" "git -C '$TMP/repoA' apply --check '$FAILED_PARTIAL_PATCH'"

run_fake_impl usage-partial '' "$TMP/no-ready" "$TMP/no-release" usage '' binary >"$TMP/usage-partial.out" 2>&1; usage_partial_rc=$?
USAGE_META="$(job_meta usage-partial)"; USAGE_PATCH="$(jq -r .incomplete_patch_path "$USAGE_META")"; USAGE_REPORT="$(jq -r .incomplete_report_path "$USAGE_META")"
check "usage-limit-partial is truthful and binary" "test $usage_partial_rc -ne 0 -a -s '$USAGE_PATCH' && grep -q 'GIT binary patch' '$USAGE_PATCH' && jq -e '.outcome==\"usage-limit-partial\" and .failure_kind==\"usage-limit\"' '$USAGE_META' >/dev/null"
check "incomplete report is clear bounded and secret-safe" "grep -q 'INCOMPLETE' '$USAGE_REPORT' && grep -q 'Tests: not confirmed complete' '$USAGE_REPORT' && grep -q 'git apply --check' '$USAGE_REPORT' && ! grep -q 'SECRET-FIXTURE-MUST-NOT-PERSIST' '$USAGE_REPORT' && test \"\$(wc -c < '$USAGE_REPORT')\" -lt 8192"
check "in-progress or failed usage is never zero" "jq -e '.provider_usage_state==\"unavailable\" and .provider_tokens==null' '$USAGE_META' >/dev/null"

run_fake_impl usage-none '' "$TMP/no-ready" "$TMP/no-release" usage >"$TMP/usage-none.out" 2>&1; usage_none_rc=$?
USAGE_NONE_META="$(job_meta usage-none)"
check "usage-limit-no-changes creates no patch" "test $usage_none_rc -ne 0 && jq -e '.outcome==\"usage-limit-no-changes\" and .incomplete_patch_path==null and .patch_exists==false' '$USAGE_NONE_META' >/dev/null"

run_fake_impl timeout-partial '' "$TMP/no-ready" "$TMP/no-release" timeout '' tracked >"$TMP/timeout-partial.out" 2>&1; timeout_partial_rc=$?
TIMEOUT_META="$(job_meta timeout-partial)"
check "timed-out-partial is truthful" "test $timeout_partial_rc -ne 0 && jq -e '.outcome==\"timed-out-partial\" and .failure_kind==\"timed-out\" and .patch_exists==true' '$TIMEOUT_META' >/dev/null"
run_fake_impl timeout-none '' "$TMP/no-ready" "$TMP/no-release" timeout >"$TMP/timeout-none.out" 2>&1; timeout_none_rc=$?
check "timed-out-no-changes is truthful" "test $timeout_none_rc -ne 0 && jq -e '.outcome==\"timed-out-no-changes\" and .patch_exists==false' \"$(job_meta timeout-none)\" >/dev/null"
run_fake_impl permission-failed '' "$TMP/no-ready" "$TMP/no-release" permission '' 1 >"$TMP/permission-failed.out" 2>&1; permission_rc=$?
PERMISSION_META="$(job_meta permission-failed)"; PERMISSION_CLONE="$JOB_STATE/wt/$JOB_ID/codex--permission-failed"
check "unsupported permission fails on first exposed poll" "test $permission_rc -ne 0 -a \"\$(grep -c '^GET /api/session/.*/permission$' '$TMP/job-permission-calls')\" -eq 1"
check "permission failure records truthful terminal evidence" "jq -e '.status==\"failed\" and .failure==\"permission-unsupported-action\" and .outcome==\"permission-failed-partial\" and .failure_kind==\"permission-failed\" and (.failure_summary|contains(\"first observable poll\")) and .changes_present==true and .patch_exists==true and (.incomplete_patch_path|endswith(\".incomplete.patch\"))' '$PERMISSION_META' >/dev/null"
check "permission failure exports incomplete work then cleans" "test ! -e '$PERMISSION_CLONE' -a -s \"\$(jq -r .incomplete_patch_path '$PERMISSION_META')\" -a \"\$(jq -r .cleanup.clone '$PERMISSION_META')\" = removed -a \"\$(jq -r .cleanup.server_session '$PERMISSION_META')\" = removed"
check "permission failure records the exact classifier branch" "jq -e '.failure_detail.reason_id==\"unknown-action\" and .failure_detail.action==\"question\" and (.failure_detail.reason|startswith(\"unknown permission action\"))' '$PERMISSION_META' >/dev/null"
check "show exposes the durable failure detail" "(cd '$TMP/repoA' && AI_GLM_CALLER=codex AI_GLM_STATE_DIR='$JOB_STATE' '$AI_GLM' show permission-failed | jq -e '.failure_detail.reason_id==\"unknown-action\"' >/dev/null)"
run_fake_impl transport-drop '' "$TMP/no-ready" "$TMP/no-release" transport '' 1 >"$TMP/transport-drop.out" 2>&1; transport_rc=$?
TRANSPORT_META="$(job_meta transport-drop)"; TRANSPORT_CLONE="$JOB_STATE/wt/$JOB_ID/codex--transport-drop"
check "a dropped poll is recorded as transport, not permission" "test $transport_rc -ne 0 && jq -e '.failure==\"transport-failed\" and .failure_kind==\"transport-failed\" and .failure_detail.reason_id==\"transport-no-reply\"' '$TRANSPORT_META' >/dev/null"
check "transport failure still preserves incomplete work" "test ! -e '$TRANSPORT_CLONE' && jq -e '.outcome==\"failed-partial\" and .changes_present==true and .artifact_state==\"durable\"' '$TRANSPORT_META' >/dev/null"
check "transport failure message avoids permission wording" "! grep -q 'GLM permission failed' '$TMP/transport-drop.out' && grep -q 'transport failure' '$TMP/transport-drop.out'"
run_fake_impl permission-none '' "$TMP/no-ready" "$TMP/no-release" permission >"$TMP/permission-none.out" 2>&1; permission_none_rc=$?
PERMISSION_NONE_META="$(job_meta permission-none)"
check "permission-failed-no-changes creates no patch" "test $permission_none_rc -ne 0 && jq -e '.outcome==\"permission-failed-no-changes\" and .failure_kind==\"permission-failed\" and .patch_exists==false' '$PERMISSION_NONE_META' >/dev/null"
cp "$PERMISSION_META" "$PERMISSION_META.saved"
jq '.cleanup={clone:"pending",server_session:"pending"}' "$PERMISSION_META.saved" > "$PERMISSION_META"
check "failed job cannot be deleted before cleanup finishes" "! (cd '$TMP/repoA' && AI_GLM_CALLER=codex AI_GLM_STATE_DIR='$JOB_STATE' '$AI_GLM' delete permission-failed) >/dev/null 2>&1"
mv "$PERMISSION_META.saved" "$PERMISSION_META"
run_fake_impl metadata-failed '' "$TMP/no-ready" "$TMP/no-release" success session-metadata >"$TMP/metadata-failed.out" 2>&1; metadata_rc=$?
METADATA_META="$(job_meta metadata-failed)"; METADATA_CLONE="$JOB_STATE/wt/$JOB_ID/codex--metadata-failed"
check "metadata_failure_cleans_new_server_session" "test $metadata_rc -ne 0 -a \"\$(jq -r .status '$METADATA_META')\" = failed -a ! -e '$METADATA_CLONE' -a \"\$(jq -r .cleanup.server_session '$METADATA_META')\" = removed"
run_fake_impl clone-create-failed '' "$TMP/no-ready" "$TMP/no-release" success clone-create >"$TMP/clone-create-failed.out" 2>&1; clone_create_rc=$?
CLONE_CREATE_META="$(job_meta clone-create-failed)"; CLONE_CREATE_PATH="$JOB_STATE/wt/$JOB_ID/codex--clone-create-failed"
check "partial clone failure is not mislabeled as recovery work" "test $clone_create_rc -ne 0 -a ! -e '$CLONE_CREATE_PATH' && jq -e '.outcome==\"failed-no-changes\" and .failure_kind==\"wrapper-setup-failed\" and .artifact_state==\"none\" and .cleanup.clone==\"removed\" and .incomplete_patch_path==null' '$CLONE_CREATE_META' >/dev/null"
check "Windows clone enables long paths before checkout" "grep -q 'git -c core.longpaths=true clone' '$AI_GLM'"
check "Windows exact cleanup uses Git long-path removal" "grep -q 'core.longpaths=true -C.*rm -rf' '$AI_GLM'"
run_fake_impl patch-failed '' "$TMP/no-ready" "$TMP/no-release" success patch >"$TMP/patch-failed.out" 2>&1; patch_rc=$?
PATCH_META="$(job_meta patch-failed)"; PATCH_CLONE="$JOB_STATE/wt/$JOB_ID/codex--patch-failed"
check "patch_failure_preserves_recovery_evidence" "test $patch_rc -ne 0 -a \"\$(jq -r .status '$PATCH_META')\" = failed -a \"\$(jq -r .failure '$PATCH_META')\" = patch-export-failed -a \"\$(jq -r .report_path '$PATCH_META')\" != null -a ! -e '$PATCH_CLONE'"

for export_fail in incomplete-destination incomplete-move incomplete-metadata; do
  run_fake_impl "export-$export_fail" '' "$TMP/no-ready" "$TMP/no-release" failure "$export_fail" untracked >"$TMP/export-$export_fail.out" 2>&1; export_rc=$?
  EXPORT_META="$(job_meta "export-$export_fail")"; EXPORT_CLONE="$JOB_STATE/wt/$JOB_ID/codex--export-$export_fail"
  check "$export_fail records artifact-export-failed" "test $export_rc -ne 0 -a -d '$EXPORT_CLONE' && jq -e '.outcome==\"artifact-export-failed\" and .failure_kind==\"artifact-export-failed\" and .artifact_state==\"failed\" and .cleanup.clone==\"preserved\"' '$EXPORT_META' >/dev/null"
  check "$export_fail gives loud exact recovery" "grep -q 'exact recovery clone was preserved' '$TMP/export-$export_fail.out' && grep -qF '$EXPORT_CLONE' '$TMP/export-$export_fail.out'"
done

OWN_META="$(job_meta export-incomplete-destination)"; OWN_CLONE="$JOB_STATE/wt/$JOB_ID/codex--export-incomplete-destination"
OWN_LOCK="$JOB_STATE/locks/$JOB_ID--codex--export-incomplete-destination.lock.d"; mkdir -p "$OWN_LOCK"; printf 99999999 > "$OWN_LOCK/pid"
AI_GLM_SOURCE="$AI_GLM" AI_GLM_STATE_DIR="$JOB_STATE" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" OWN_META="$OWN_META" OWN_CLONE="$OWN_CLONE" OWN_LOCK="$OWN_LOCK" \
  bash -c 'source "$AI_GLM_SOURCE"; CALLER=codex; IMPL_META="$OWN_META"; IMPL_CLONE="$OWN_CLONE"; IMPL_LOCK="$OWN_LOCK"; ! write_incomplete_artifacts "$OWN_META" "$OWN_CLONE" turn-failed' >/dev/null 2>&1
check "artifact export requires exact live lock ownership" "test -d '$OWN_CLONE' -a \"\$(cat '$OWN_LOCK/pid')\" = 99999999"

NORMAL_HASH_BEFORE="$(sha256sum "$NORMAL_META" | awk '{print $1}')"
AI_GLM_SOURCE="$AI_GLM" AI_GLM_STATE_DIR="$JOB_STATE" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" NORMAL_META="$NORMAL_META" \
  bash -c 'source "$AI_GLM_SOURCE"; IMPL_META="$NORMAL_META"; IMPL_CLONE="$(jq -r .clone_path "$NORMAL_META")"; implementation_cleanup 0; implementation_cleanup 0' >/dev/null 2>&1
NORMAL_HASH_AFTER="$(sha256sum "$NORMAL_META" | awk '{print $1}')"
check "repeated finalization is idempotent" "test '$NORMAL_HASH_BEFORE' = '$NORMAL_HASH_AFTER'"

RECON_META="$(job_meta reconcile-dead)"; RECON_CLONE="$JOB_STATE/wt/$JOB_ID/codex--reconcile-dead"; RECON_LOCK="$JOB_STATE/locks/$JOB_ID--codex--reconcile-dead.lock.d"
mkdir -p "$RECON_CLONE" "$RECON_LOCK"
jq --arg n reconcile-dead --arg clone "$RECON_CLONE" --argjson pid 99999999 \
  '.name=$n | .status="running" | .owner_pid=$pid | .clone_path=$clone | .opencode_session_id=null | .finished_at=null | .failure=null | .cleanup={clone:"pending",server_session:"pending"}' \
  "$FAILED_META" > "$RECON_META"
printf 99999999 > "$RECON_LOCK/pid"
AI_GLM_SOURCE="$AI_GLM" AI_GLM_STATE_DIR="$JOB_STATE" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" RECON_META="$RECON_META" \
  bash -c 'source "$AI_GLM_SOURCE"; CALLER=codex; reconcile_implementation_record "$RECON_META"' >/dev/null 2>&1
check "dead_owner_reconciliation_requires_all_safety_checks" "test \"\$(jq -r .status '$RECON_META')\" = failed -a \"\$(jq -r .failure '$RECON_META')\" = owner-process-died -a ! -e '$RECON_CLONE' -a ! -e '$RECON_LOCK'"

PERM_RECON_META="$(job_meta permission-reconcile)"; PERM_RECON_CLONE="$JOB_STATE/wt/$JOB_ID/codex--permission-reconcile"; PERM_RECON_LOCK="$JOB_STATE/locks/$JOB_ID--codex--permission-reconcile.lock.d"
mkdir -p "$PERM_RECON_CLONE" "$PERM_RECON_LOCK"
jq --arg n permission-reconcile --arg clone "$PERM_RECON_CLONE" --argjson pid 99999998 \
  '.name=$n | .owner_pid=$pid | .clone_path=$clone | .opencode_session_id=null | .finished_at=null | .exit_code=null | .cleanup={clone:"pending",server_session:"pending"}' \
  "$PERMISSION_META" > "$PERM_RECON_META"
printf 99999998 > "$PERM_RECON_LOCK/pid"
AI_GLM_SOURCE="$AI_GLM" AI_GLM_STATE_DIR="$JOB_STATE" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" PERM_RECON_META="$PERM_RECON_META" \
  bash -c 'source "$AI_GLM_SOURCE"; CALLER=codex; reconcile_implementation_record "$PERM_RECON_META"' >/dev/null 2>&1
check "dead permission-failure owner completes cleanup without losing cause" "test \"\$(jq -r .status '$PERM_RECON_META')\" = failed -a \"\$(jq -r .failure '$PERM_RECON_META')\" = permission-unsupported-action -a \"\$(jq -r .cleanup.clone '$PERM_RECON_META')\" = removed -a ! -e '$PERM_RECON_CLONE' -a ! -e '$PERM_RECON_LOCK'"

FORGED_META="$(job_meta forged-outside)"; FORGED_CLONE="$TMP/outside-owned-by-user"; FORGED_LOCK="$JOB_STATE/locks/$JOB_ID--codex--forged-outside.lock.d"
mkdir -p "$FORGED_CLONE" "$FORGED_LOCK"
jq --arg n forged-outside --arg clone "$FORGED_CLONE" --argjson pid 99999999 \
  '.name=$n | .status="running" | .owner_pid=$pid | .clone_path=$clone | .opencode_session_id=null | .finished_at=null | .failure=null' \
  "$FAILED_META" > "$FORGED_META"
printf 99999999 > "$FORGED_LOCK/pid"
AI_GLM_SOURCE="$AI_GLM" AI_GLM_STATE_DIR="$JOB_STATE" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" FORGED_META="$FORGED_META" \
  bash -c 'source "$AI_GLM_SOURCE"; CALLER=codex; reconcile_implementation_record "$FORGED_META" || true' >/dev/null 2>&1
check "live_owner_and_forged_or_outside_paths_are_never_swept" "test -d '$FORGED_CLONE' -a -f '$FORGED_META' -a \"\$(jq -r .status '$FORGED_META')\" = running"

READY_A="$TMP/a-ready"; READY_B="$TMP/b-ready"; RELEASE_A="$TMP/a-release"; RELEASE_B="$TMP/b-release"
run_fake_impl parallel-a record "$READY_A" "$RELEASE_A" >"$TMP/a.out" 2>&1 & pid_a=$!
run_fake_impl parallel-b record "$READY_B" "$RELEASE_B" >"$TMP/b.out" 2>&1 & pid_b=$!
wait_file "$READY_A"; wait_file "$READY_B"
check "different_implementation_names_run_independently" "test -f \"\$(job_meta parallel-a)\" -a -f \"\$(job_meta parallel-b)\""
touch "$RELEASE_A" "$RELEASE_B"; wait "$pid_a"; wait "$pid_b"

RACE_READY="$TMP/race-ready"; RACE_RELEASE="$TMP/race-release"
run_fake_impl completion-race completed-turn "$RACE_READY" "$RACE_RELEASE" success '' tracked >"$TMP/completion-race.out" 2>&1 & race_pid=$!
wait_file "$RACE_READY"; RACE_META="$(job_meta completion-race)"
AI_GLM_SOURCE="$AI_GLM" AI_GLM_STATE_DIR="$JOB_STATE" AI_DEVOPS_CONFIG_DIR="$TMP/cfg" JOB_REPO="$TMP/repoA" \
  bash -c 'source "$AI_GLM_SOURCE"; require_server(){ :; }; permission_http(){ HTTP_STATUS=200; HTTP_BODY="{}"; }; REPO_OVERRIDE="$JOB_REPO"; CALLER=codex; cmd_abort completion-race' >/dev/null 2>&1
touch "$RACE_RELEASE"; wait "$race_pid" || true
check "abort_completion_race_records_observed_truth" "jq -e '.status==\"completed\" and .outcome==\"completed\" and .incomplete_patch_path==null' '$RACE_META' >/dev/null"
check "ambiguous_server_state_is_reported_not_deleted" "grep -q 'server state.*ambiguous' '$AI_GLM'"
(cd "$TMP/repoA" && AI_GLM_CALLER=codex AI_GLM_STATE_DIR="$JOB_STATE" "$AI_GLM" delete normal >/dev/null 2>&1)
check "terminal_record_can_be_cleared_for_safe_name_reuse" "test ! -e '$NORMAL_META'"

# ---------------------------------------------------------------------------
# Live probes. Need a healthy server and a working Z.ai key.
#   AI_GLM_LIVE=1 tests/test-ai-glm.sh
# ---------------------------------------------------------------------------
if [ "${AI_GLM_LIVE:-0}" = "1" ]; then
  echo "== live =="
  unset AI_GLM_STATE_DIR AI_DEVOPS_CONFIG_DIR AI_GLM_PORT
  check "doctor passes"                     "'$AI_GLM' doctor >/dev/null"

  LIVE="$TMP/live"; mkdir -p "$LIVE"; cd "$LIVE"
  git init -q
  # Marker file: only a REAL read can report it. Without this, a wedged turn that
  # touches nothing would also leave the tree clean and pass the read-only test.
  printf 'MARKER_VALUE=quartz-badger-4417\n' > marker.txt
  git add -A && git -c user.email=t@example.com -c user.name=t commit -qm init

  TODO_NAME="todowrite-safe-live-$(date -u +%Y%m%d%H%M%S)"
  TODO_OUTSIDE="$(mktemp)"; printf 'TODO_OUTSIDE_MARKER_MUST_NOT_LEAK\n' > "$TODO_OUTSIDE"
  todo_outside_hash="$(sha256sum "$TODO_OUTSIDE" | awk '{print $1}')"
  "$AI_GLM" new "$TODO_NAME" --timeout 90 --prompt \
    "Use TodoWrite once to create two internal items: inspect safety (in_progress) and report result (pending). Do not read files, run shell, use network, or use another tool. Do not inspect or mention $TODO_OUTSIDE. Then reply only PLANNED." \
    >"$TMP/todowrite-live" 2>&1
  todo_rc=$?
  check "live todowrite turn succeeds"       "test $todo_rc -eq 0 -a \"\$(head -1 '$TMP/todowrite-live')\" = PLANNED"
  check "live todowrite leaves tracked repo clean" "test -z \"\$(git -C '$LIVE' status --porcelain | grep -v '^?? [.]ai/')\""
  check "live todowrite cannot reveal outside marker" "! grep -q TODO_OUTSIDE_MARKER_MUST_NOT_LEAK '$TMP/todowrite-live'"
  check "live todowrite cannot change outside marker" "test '$todo_outside_hash' = \"\$(sha256sum '$TODO_OUTSIDE' | awk '{print \$1}')\""
  "$AI_GLM" delete "$TODO_NAME" >/dev/null 2>&1 || true
  rm -f "$TODO_OUTSIDE"

  "$AI_GLM" new live-probe --prompt "Read marker.txt and reply with ONLY the value of MARKER_VALUE." >"$TMP/r1" 2>&1
  review_rc=$?
  check "review turn succeeded"             "test $review_rc -eq 0"
  check "GLM actually read the file"        "grep -q 'quartz-badger-4417' '$TMP/r1'"
  check "review left the tree clean"        "test -z \"\$(git -C '$LIVE' status --porcelain | grep -v '^?? [.]ai/')\""
  check "a report was written"              "ls '$LIVE'/.ai/reviews/glm-live-probe-*.md >/dev/null 2>&1"
  check "report records cache tokens"       "grep -q 'cache' '$LIVE'/.ai/reviews/glm-live-probe-*.md"

  "$AI_GLM" ask live-probe --prompt "Without re-reading any file, repeat that value." >"$TMP/r2" 2>&1
  check "session remembered the value"      "grep -q 'quartz-badger-4417' '$TMP/r2'"

  "$AI_GLM" server restart >/dev/null && sleep 12
  "$AI_GLM" ask live-probe --prompt "Once more, from memory only: the value?" >"$TMP/r3" 2>&1
  check "context survived a server restart" "grep -q 'quartz-badger-4417' '$TMP/r3'"

  OUTSIDE_MARKER="$(mktemp)"
  printf 'OUTSIDE_MARKER_CONTENT_MUST_NOT_LEAK\n' > "$OUTSIDE_MARKER"
  outside_start="$(date +%s)"
  "$AI_GLM" new live-outside-permission --timeout 60 \
    --prompt "Read the file at $OUTSIDE_MARKER and state whether it exists." >"$TMP/outside" 2>&1
  outside_rc=$?; outside_elapsed=$(( $(date +%s) - outside_start ))
  check "outside read fails nonzero"         "test $outside_rc -ne 0"
  check "outside read fails quickly"         "test $outside_elapsed -lt 30"
  check "outside failure names permission"   "grep -qi 'permission failed' '$TMP/outside'"
  check "outside failure gives safe remedy"  "grep -q 'place a safe copy under' '$TMP/outside'"
  check "outside marker content is not leaked" "! grep -q 'OUTSIDE_MARKER_CONTENT_MUST_NOT_LEAK' '$TMP/outside'"
  "$AI_GLM" abort live-outside-permission >/dev/null 2>&1 || true
  "$AI_GLM" delete live-outside-permission >/dev/null 2>&1 || true
  rm -f "$OUTSIDE_MARKER"

  UNSUP_JOB="unsupported-permission-live-$(date -u +%Y%m%d%H%M%S)"
  unsupported_start="$(date +%s)"
  AI_GLM_CALLER=codex "$AI_GLM" implement "$UNSUP_JOB" --timeout 90 --prompt \
    "Before doing anything else, use the question tool to ask exactly: Continue? Do not use TodoWrite. Do not read files, run shell, edit files, or use any other tool." \
    >"$TMP/unsupported-live" 2>&1
  unsupported_rc=$?; unsupported_elapsed=$(( $(date +%s) - unsupported_start ))
  AI_GLM_CALLER=codex "$AI_GLM" show "$UNSUP_JOB" >"$TMP/unsupported-show"
  check "live unsupported permission fails quickly" "test $unsupported_rc -ne 0 -a $unsupported_elapsed -lt 60"
  check "live unsupported permission records first-poll truth" "jq -e '.status==\"failed\" and .failure==\"permission-unsupported-action\" and (.failure_summary|contains(\"first observable poll\")) and .changes_present==false and .patch_exists==false and .patch_path==null' '$TMP/unsupported-show' >/dev/null"
  check "live unsupported permission completes exact cleanup" "jq -e '.cleanup.clone==\"removed\" and .cleanup.server_session==\"removed\" and .finished_at!=null' '$TMP/unsupported-show' >/dev/null"
  AI_GLM_CALLER=codex "$AI_GLM" delete "$UNSUP_JOB" >/dev/null 2>&1 || true

  LIVE_JOB="implementation-job-tracking-live-$(date -u +%Y%m%d%H%M%S)"
  AI_GLM_CALLER=codex "$AI_GLM" implement "$LIVE_JOB" --timeout 120 --prompt \
    "Create harmless-canary.txt containing exactly: bounded canary. Then run sleep 120 with Bash. Do not finish before that sleep." \
    >"$TMP/live-job-owner" 2>&1 & live_job_pid=$!
  LIVE_CLONE=""; LIVE_CHANGED=0
  for _ in {1..60}; do
    AI_GLM_CALLER=codex "$AI_GLM" show "$LIVE_JOB" >"$TMP/live-job-running" 2>/dev/null || true
    LIVE_CLONE="$(jq -r '.clone_path // empty' "$TMP/live-job-running" 2>/dev/null || true)"
    if [ -n "$LIVE_CLONE" ] && [ -f "$LIVE_CLONE/harmless-canary.txt" ]; then LIVE_CHANGED=1; break; fi
    sleep 1
  done
  check "live implementation made harmless isolated change" "test '$LIVE_CHANGED' = 1 -a ! -e '$LIVE/harmless-canary.txt'"
  check "live implementation is visible while active" "AI_GLM_CALLER=codex '$AI_GLM' list | grep -qE '$LIVE_JOB.*implementation.*running'"
  AI_GLM_CALLER=codex "$AI_GLM" implement "$LIVE_JOB" --lock-timeout 0 --prompt duplicate >"$TMP/live-job-duplicate" 2>&1
  live_duplicate_rc=$?
  check "live duplicate is rejected before another session" "test $live_duplicate_rc -ne 0 && grep -q 'No clone, server session, or provider turn' '$TMP/live-job-duplicate'"
  AI_GLM_CALLER=codex "$AI_GLM" abort "$LIVE_JOB" >"$TMP/live-job-abort" 2>&1
  check "live abort targets the named implementation" "grep -q 'abort requested' '$TMP/live-job-abort'"
  wait "$live_job_pid" || true
  AI_GLM_CALLER=codex "$AI_GLM" show "$LIVE_JOB" >"$TMP/live-job-show"
  check "live abort records terminal truth" "jq -e '.status==\"aborted\" and .outcome==\"aborted-partial\" and .cleanup.clone==\"removed\" and .cleanup.server_session==\"removed\"' '$TMP/live-job-show' >/dev/null"
  check "live abort exports incomplete artifact" "test -s \"\$(jq -r .incomplete_patch_path '$TMP/live-job-show')\" && git -C '$LIVE' apply --check \"\$(jq -r .incomplete_patch_path '$TMP/live-job-show')\""
  check "live abort leaves no canonical clone" "test ! -e \"\$(jq -r .clone_path '$TMP/live-job-show')\""
  AI_GLM_CALLER=codex "$AI_GLM" delete "$LIVE_JOB" >/dev/null 2>&1

  "$AI_GLM" implement live-impl --prompt "Create a file NOTES.md containing exactly the line: hello from glm" >"$TMP/r4" 2>&1
  check "implement produced a patch"        "ls '$LIVE'/.ai/reviews/glm-live-impl-*.patch >/dev/null 2>&1"
  check "implement left NO worktree behind" "test \"\$(git -C '$LIVE' worktree list | wc -l)\" -eq 1"
  check "implement did not touch the repo"  "test -z \"\$(git -C '$LIVE' status --porcelain | grep -v '^?? [.]ai/')\""

  "$AI_GLM" delete live-probe >/dev/null 2>&1
  "$AI_GLM" delete live-impl >/dev/null 2>&1 || true
fi

# --- shared-server attach (root/ai parity) -----------------------------------
# On hetz the OpenCode server is owned by `ai`. A root session used to get 17
# doctor failures and "setup never finished" because it had no server-password
# of its own, even though the server it needed was running. ai-glm now falls
# back to the owning user's password file. These guard the mechanics of that.
echo "== shared-server attach =="
SHTMP="$TMP/shared"; mkdir -p "$SHTMP/fakehome/.config/ai-devops/opencode"
printf 'secret-pw\n' > "$SHTMP/fakehome/.config/ai-devops/opencode/server-password"

# The whole script must still LOAD on a machine with no getent (Git Bash). This
# is the regression that broke 21 tests when the fallback was first added: an
# assignment from a failing command substitution aborts under `set -e`.
# Shadow getent with a stub that fails, which is exactly what an absent getent
# does to the command substitution. Keep the rest of PATH so curl/jq still exist.
mkdir -p "$SHTMP/nogetent"
printf '#!/usr/bin/env bash\nexit 127\n' > "$SHTMP/nogetent/getent"
chmod +x "$SHTMP/nogetent/getent"
check "ai-glm loads when getent fails/absent" \
  "PATH='$SHTMP/nogetent:$PATH' AI_DEVOPS_CONFIG_DIR='$SHTMP/empty' bash '$AI_GLM' --help >/dev/null 2>&1"
check "ai-glm parses cleanly"  "bash -n '$AI_GLM'"

# With its own password present, the fallback must NOT engage.
mkdir -p "$SHTMP/own/opencode"; printf 'own-pw\n' > "$SHTMP/own/opencode/server-password"
OUT="$(AI_DEVOPS_CONFIG_DIR="$SHTMP/own" bash "$AI_GLM" doctor 2>&1 || true)"
check "own password wins over the shared one" "! printf '%s' \"\$OUT\" | grep -q 'attached to the OpenCode server'"

# The fallback must only ever read a password this user can already read; it
# grants nothing new. Assert it never copies or writes the file anywhere.
check "fallback never copies the password" \
  "! grep -qE 'cp .*server-password|tee .*server-password' '$AI_GLM'"
check "fallback is limited to a named user" \
  "grep -q 'AI_GLM_SERVER_USER' '$AI_GLM'"

# Running AS the owning user with a bare config dir must NOT "attach to itself":
# that reported "attached to the server owned by ai" while running as ai, and
# short-circuited the full installation report doctor owes a not-yet-set-up
# machine. Caught on Ubuntu; invisible on Windows, where getent does not exist.
OUT="$(AI_GLM_SERVER_USER="$(id -un)" AI_DEVOPS_CONFIG_DIR="$SHTMP/empty2" bash "$AI_GLM" doctor 2>&1 || true)"
check "never attaches to its own account" "! printf '%s' \"\$OUT\" | grep -q 'attached to the OpenCode server'"

# LIVENESS DURING A TURN (shared-db #1298) -- BEHAVIOURAL, not structural.
#
# The first attempt at this fix hooked the stamp to the `/session/status` branch of the
# await_turn poll loop. It did NOT work: on a real review that endpoint returned `{}` for
# the entire turn, so the branch never ran and the field stayed frozen at creation time.
# Four grep-based tests passed the whole time, because the code they looked for existed.
# THAT is why the check below drives the real function and asserts what it DOES.
#
# Contract:
#   last_poll_at          moves every poll            -> the wrapper is alive
#   provider_progress_at  moves only on new output    -> the provider is working
#   last_activity_at      tracks provider progress    -> what a caller should judge on
LIVE_TMP="$(mktemp -d)"
LIVE_META="$LIVE_TMP/meta.json"
printf '{"name":"t","created_at":"2026-01-01T00:00:00Z","last_activity_at":"2026-01-01T00:00:00Z"}' > "$LIVE_META"
(
  set -u
  TURN_META="$LIVE_META"
  eval "$(sed -n '/^LIVENESS_SIG=""/,/^}/p' "$AI_GLM")"
  g(){ jq -r ".$1 // \"absent\"" "$LIVE_META"; }
  touch_liveness '{"text":"chunk one"}'
  a_act=$(g last_activity_at); a_poll=$(g last_poll_at)
  sleep 1; touch_liveness '{"text":"chunk one"}'
  b_act=$(g last_activity_at); b_poll=$(g last_poll_at)
  sleep 1; touch_liveness '{"text":"chunk two is different"}'
  c_act=$(g last_activity_at)
  [ "$a_act" != "2026-01-01T00:00:00Z" ] || exit 1   # stamped at all
  [ "$b_poll" != "$a_poll" ]             || exit 2   # poll moves while idle
  [ "$b_act"  =  "$a_act"  ]             || exit 3   # activity does NOT move without output
  [ "$c_act" != "$b_act"  ]              || exit 4   # activity DOES move on new output
  rm -f "$LIVE_META"; touch_liveness 'x' || exit 5   # best effort with no meta file
)
check "liveness stamping behaves: poll always, activity only on real provider output" "[ $? -eq 0 ]"
rm -rf "$LIVE_TMP"

check "touch_liveness is driven by the assistant message, not /session/status" \
  "awk '/^await_turn\(\)/,/^}/' '$AI_GLM' | grep -q 'touch_liveness \"\$msg\"'"
check "both review call sites arm TURN_META before await_turn" \
  "[ \$(grep -c 'TURN_META=\"\$mp\"' '$AI_GLM') -eq 2 ]"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
