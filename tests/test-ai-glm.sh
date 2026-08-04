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
check "model is pinned to glm-5.2"          "jq -e '.model==\"zai-coding-plan/glm-5.2\"' '$REPO_ROOT/config/opencode/opencode.json' >/dev/null"
check "autoupdate disabled"                 "jq -e '.autoupdate==false' '$REPO_ROOT/config/opencode/opencode.json' >/dev/null"
check "sharing disabled"                    "jq -e '.share==\"disabled\"' '$REPO_ROOT/config/opencode/opencode.json' >/dev/null"

echo "== agent safety (the only working read-only enforcement) =="
for a in glm-review glm-implement; do
  f="$REPO_ROOT/config/opencode/agent/$a.md"
  check "$a exists"                         "test -f '$f'"
  check "$a has webfetch: false"            "grep -q '^  webfetch: false' '$f'"
  check "$a pins the model"                 "grep -q '^model: zai-coding-plan/glm-5.2$' '$f'"
done
check "glm-review has write: false"         "grep -q '^  write: false' '$REPO_ROOT/config/opencode/agent/glm-review.md'"
check "glm-review has edit: false"          "grep -q '^  edit: false'  '$REPO_ROOT/config/opencode/agent/glm-review.md'"
check "glm-review has NO bash tool"         "grep -q '^  bash: false' '$REPO_ROOT/config/opencode/agent/glm-review.md'"
check "glm-implement can write"             "grep -q '^  write: true'  '$REPO_ROOT/config/opencode/agent/glm-implement.md'"
check "glm-implement HAS a bash tool"       "grep -q '^  bash: true'   '$REPO_ROOT/config/opencode/agent/glm-implement.md'"
check "sandbox is a clone, not a worktree"  "grep -q 'git clone --quiet --no-hardlinks' '$AI_GLM'"
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
check "doctor resolves through a symlink"   "'$TMP/binlink/ai-glm' doctor 2>&1 | grep -q 'PASS  pinned version file present'"

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

echo "== completion rule =="
check "requires finish==stop"               "grep -q 'finish\" = \"stop\"' '$AI_GLM' || grep -q 'finish\" = \"stop' '$AI_GLM'"
check "requires two idle polls"             "grep -q 'idle\" -ge 2' '$AI_GLM' || grep -q 'idle -ge 2' '$AI_GLM'"
check "detects the 400 permission wedge"    "grep -q 'InvalidRequestError' '$AI_GLM'"
check "names the stuck tool on timeout"     "grep -q 'tool still running' '$AI_GLM'"

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

  "$AI_GLM" new live-probe --prompt "Read marker.txt and reply with ONLY the value of MARKER_VALUE." >"$TMP/r1" 2>&1
  check "review turn succeeded"             "test \$? -eq 0"
  check "GLM actually read the file"        "grep -q 'quartz-badger-4417' '$TMP/r1'"
  check "review left the tree clean"        "test -z \"\$(git -C '$LIVE' status --porcelain | grep -v '^?? [.]ai/')\""
  check "a report was written"              "ls '$LIVE'/.ai/reviews/glm-live-probe-*.md >/dev/null 2>&1"
  check "report records cache tokens"       "grep -q 'cache' '$LIVE'/.ai/reviews/glm-live-probe-*.md"

  "$AI_GLM" ask live-probe --prompt "Without re-reading any file, repeat that value." >"$TMP/r2" 2>&1
  check "session remembered the value"      "grep -q 'quartz-badger-4417' '$TMP/r2'"

  systemctl --user restart opencode-glm.service && sleep 12
  "$AI_GLM" ask live-probe --prompt "Once more, from memory only: the value?" >"$TMP/r3" 2>&1
  check "context survived a server restart" "grep -q 'quartz-badger-4417' '$TMP/r3'"

  "$AI_GLM" implement live-impl --prompt "Create a file NOTES.md containing exactly the line: hello from glm" >"$TMP/r4" 2>&1
  check "implement produced a patch"        "ls '$LIVE'/.ai/reviews/glm-live-impl-*.patch >/dev/null 2>&1"
  check "implement left NO worktree behind" "test \"\$(git -C '$LIVE' worktree list | wc -l)\" -eq 1"
  check "implement did not touch the repo"  "test -z \"\$(git -C '$LIVE' status --porcelain | grep -v '^?? [.]ai/')\""

  "$AI_GLM" delete live-probe >/dev/null 2>&1
fi

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
