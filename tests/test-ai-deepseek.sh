#!/usr/bin/env bash
# Offline checks for bin/ai-deepseek: argument validation, profile guardrails,
# and the full implement/ask/diff/cleanup lifecycle against a fake OpenCode.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$REPO_ROOT/bin/ai-deepseek"
T="$(mktemp -d)"; trap 'cat "$T/fake.log.argv" 2>/dev/null; rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1" >&2; fail=1; fi; }

# Fake OpenCode: records its arguments and environment, edits and commits in --dir.
cat > "$T/opencode" <<'FAKE'
#!/usr/bin/env bash
dir=""; session=""
while [ $# -gt 0 ]; do case "$1" in --dir) dir="$2"; shift 2;; --session) session="$2"; shift 2;; *) shift;; esac; done
prompt="$(cat)"
# Every process argv in this run's tree must be free of the key. Git Bash has
# /proc too; a host without it records that the scan could not run.
if compgen -G '/proc/[0-9]*/cmdline' >/dev/null; then
  for c in /proc/[0-9]*/cmdline; do tr '\0' ' ' < "$c" 2>/dev/null; echo; done | grep "test-key-[s]ecret" >> "$FAKE_LOG.argv" && echo "ARGV_LEAK" >> "$FAKE_LOG"
else echo "ARGV_UNCHECKED" >> "$FAKE_LOG"; fi
printf '%s\n' "remote=$(git -C "$dir" remote | wc -l) key=${DEEPSEEK_API_KEY:-} op=${OP_SERVICE_ACCOUNT_TOKEN:-unset} xdg=$XDG_CONFIG_HOME session=$session" >> "$FAKE_LOG"
if [ -z "$session" ]; then
  echo change > "$dir/file.txt"; git -C "$dir" add file.txt; git -C "$dir" -c user.name=t -c user.email=t@t commit -qm change
fi
sid="${session:-ses_fake1}"
printf '{"type":"step_start","sessionID":"%s"}\n' "$sid"
printf '{"type":"tool_use","sessionID":"%s","part":{"state":{"status":"completed"}}}\n' "$sid"
printf '{"type":"text","sessionID":"%s","part":{"text":"reply to: %s"}}\n' "$sid" "$prompt"
FAKE
chmod +x "$T/opencode"
# AI_DEEPSEEK_TEST_DIR lets the Windows trusted-op check accept the fixture op.
export AI_DEEPSEEK_OPENCODE="$T/opencode" AI_DEEPSEEK_STATE_DIR="$T/state" FAKE_LOG="$T/fake.log" AI_DEEPSEEK_TEST_DIR="$T"
# Fake 1Password: the real resolution path runs, reading the managed reference.
mkdir -p "$T/fakebin" "$T/cfg"
cat > "$T/fakebin/op" <<'OP'
#!/usr/bin/env bash
[ "$1 $2" = "read op://vault/deepseek/credential" ] && [ "$OP_SERVICE_ACCOUNT_TOKEN" = sa-token ] && printf 'test-key-secret\n'
OP
chmod +x "$T/fakebin/op"
echo sa-token > "$T/cfg/op-service-account"
echo 'DEEPSEEK_API_KEY=op://vault/deepseek/credential' > "$T/cfg/mcp.env"
export PATH="$T/fakebin:$PATH" AI_DEVOPS_CONFIG_DIR="$T/cfg" OP_SERVICE_ACCOUNT_TOKEN=must-not-leak
unset DEEPSEEK_API_KEY

git init -q --bare -b main "$T/origin.git"
git clone -q "$T/origin.git" "$T/src" 2>/dev/null
echo base > "$T/src/readme"; git -C "$T/src" add readme
git -C "$T/src" -c user.name=t -c user.email=t@t commit -qm base; git -C "$T/src" push -q origin main
git -C "$T/src" remote set-head origin main

check "rejects bad task name" '! "$BIN" implement "../x" --repo "$T/src" --prompt hi 2>/dev/null'
check "rejects unknown model" '! "$BIN" implement ok --repo "$T/src" --model gpt --prompt hi 2>/dev/null'
check "requires --repo" '! "$BIN" implement ok --prompt hi 2>/dev/null'

out="$("$BIN" implement t1 --repo "$T/src" --prompt "do it")"
check "implement prints reply" 'grep -q "reply to: do it" <<<"$out"'
check "implement records session" '[ "$(jq -r .session "$T/state/tasks/t1/meta.json")" = ses_fake1 ]'
check "clone is on its own branch" '[ "$(git -C "$T/state/work/t1" branch --show-current)" = deepseek/t1 ]'
check "real repository untouched before land" '! git -C "$T/src" rev-parse -q --verify deepseek/t1 >/dev/null'
check "key from 1Password reaches OpenCode" 'grep -q "key=test-key-secret" "$FAKE_LOG"'
if grep -q ARGV_UNCHECKED "$FAKE_LOG"; then echo "SKIP: key never appears in any argv (no /proc on this host)"
else check "key never appears in any argv" '! grep -q ARGV_LEAK "$FAKE_LOG"'; fi
check "1Password token withheld from OpenCode" 'grep -q "op=unset" "$FAKE_LOG" && ! grep -q must-not-leak "$FAKE_LOG"'
check "DeepSeek runs in a clone with no remote" 'grep -q "remote=0" "$FAKE_LOG" && [ -z "$(git -C "$T/state/work/t1" remote)" ]'
check "profile installed from repository" 'cmp -s "$REPO_ROOT/config/opencode-deepseek/agent/deepseek-implement.md" "$T/state/xdg/config/opencode/agent/deepseek-implement.md"'
check "duplicate task refused" '! "$BIN" implement t1 --repo "$T/src" --prompt again 2>/dev/null'

out="$("$BIN" ask t1 --prompt "next")"
check "ask resumes the same session" 'tail -1 "$FAKE_LOG" | grep -q "session=ses_fake1" && grep -q "reply to: next" <<<"$out"'
check "diff shows the commit" '"$BIN" diff t1 | grep -q "+change"'
check "list shows the task" '"$BIN" list | grep -q "^t1"'
check "nothing was pushed" '[ "$(git -C "$T/origin.git" rev-list --all | wc -l)" = 1 ]'
check "cleanup refuses unlanded commits" '! "$BIN" cleanup t1 2>/dev/null && [ -d "$T/state/work/t1" ]'
check "land fetches the branch into the repository" '"$BIN" land t1 >/dev/null && [ "$(git -C "$T/src" rev-parse deepseek/t1)" = "$(git -C "$T/state/work/t1" rev-parse HEAD)" ]'
check "cleanup after land removes the clone" '"$BIN" cleanup t1 >/dev/null && [ ! -d "$T/state/work/t1" ] && [ ! -d "$T/state/tasks/t1" ]'
echo 'DEEPSEEK_API_KEY=op://vault/other/credential' >> "$T/cfg/mcp.env"
check "ambiguous 1Password reference refused" '! "$BIN" implement t2 --repo "$T/src" --prompt x 2>/dev/null'

agent="$REPO_ROOT/config/opencode-deepseek/agent/deepseek-implement.md"
for rule in '"git push*": deny' '"git remote*": deny' '"gh *": deny' '"op *": deny'; do
  check "agent denies $rule" 'grep -qF "$rule" "$agent"'
done
check "agent has no web tool" 'grep -q "^  webfetch: false" "$agent"'
check "profile pins official endpoint" 'jq -e ".provider[\"deepseek-api\"].options.baseURL == \"https://api.deepseek.com/v1\"" "$REPO_ROOT/config/opencode-deepseek/opencode.json" >/dev/null'
exit "$fail"
