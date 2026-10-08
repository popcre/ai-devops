#!/usr/bin/env bash
# Offline suite for bin/ai-install-session-tmp (install, check, idempotence, remove).
set -u
PASS=0; FAIL=0
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib-test-harness.sh"
inst="$here/../bin/ai-install-session-tmp"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
export HOME="$work/home" XDG_CONFIG_HOME="$work/home/.config"; mkdir -p "$HOME/.claude"
s="$HOME/.claude/settings.json"
printf '{"model":"x","hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"foreign"}]}]}}\n' > "$s"
bash "$inst" --no-timer >/dev/null; check "install succeeds" '[ $? -eq 0 ]'
check "hook, sweep and lib copied" '[ -x "$HOME/.config/ai-devops/session-tmp-hook" ] && [ -x "$HOME/.config/ai-devops/session-tmp-sweep" ] && [ -f "$HOME/.config/ai-devops/session-tmp.sh" ]'
check "SessionStart and SessionEnd registered" 'jq -e "(.hooks.SessionStart|tostring|contains(\"session-tmp-hook\")) and (.hooks.SessionEnd|tostring|contains(\"session-tmp-hook\"))" "$s"'
check "foreign hook and settings preserved" 'jq -e ".model==\"x\" and (.hooks.SessionStart|tostring|contains(\"foreign\"))" "$s"'
bash "$inst" --no-timer >/dev/null
check "second install is idempotent" '[ "$(jq "[.hooks.SessionStart[],.hooks.SessionEnd[]]|length" "$s")" = 3 ]'
check "--check passes after install" 'bash "$inst" --check --no-timer >/dev/null'
printf 'not json' > "$work/bad.json"; cp "$work/bad.json" "$s.bad"
bash "$inst" --remove --dry-run >/dev/null
check "dry-run remove changes nothing" 'jq -e ".hooks.SessionEnd|tostring|contains(\"session-tmp-hook\")" "$s"'
bash "$inst" --remove >/dev/null
check "remove drops only our hooks" 'jq -e "(.hooks|tostring|contains(\"session-tmp-hook\")|not) and (.hooks.SessionStart|tostring|contains(\"foreign\"))" "$s"'
check "remove deletes the copies" '[ ! -e "$HOME/.config/ai-devops/session-tmp-hook" ]'
check "--check fails after remove" '! bash "$inst" --check --no-timer >/dev/null'
printf 'not json' > "$s"
check "refuses an unparseable settings file" '! bash "$inst" --no-timer >/dev/null 2>&1 && [ "$(cat "$s")" = "not json" ]'
printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
