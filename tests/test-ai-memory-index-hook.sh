#!/usr/bin/env bash
# Offline tests for bin/ai-memory-index-hook and bin/ai-install-memory-hook.
#
# The hook runs on EVERY Write/Edit, so "stays silent and cheap on non-memory files"
# is as important as "warns on an unindexed memory". The installer edits the user's
# settings.json, so "never corrupts it, never removes an existing hook" is the point.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/bin/ai-memory-index-hook"
INSTALL="$ROOT/bin/ai-install-memory-hook"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
MEM="$TMP/projects/demo/memory"; mkdir -p "$MEM"
printf 'body\n' > "$MEM/indexed.md"
printf 'body\n' > "$MEM/orphan.md"
printf '# Memory index\n\n- [Indexed](indexed.md) — hook\n' > "$MEM/MEMORY.md"

fire() { printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$1" | bash "$HOOK" 2>/dev/null; }

# --- the case that matters -----------------------------------------------------
out="$(fire "$MEM/orphan.md")"
check "unindexed memory produces a warning" "printf '%s' \"\$out\" | grep -q 'orphan.md is not in'"
check "warning is valid JSON" "printf '%s' \"\$out\" | jq -e . >/dev/null"
check "warning reaches the model as context" "printf '%s' \"\$out\" | grep -q additionalContext"
check "warning reaches the user as a message" "printf '%s' \"\$out\" | grep -q systemMessage"

# --- silence where silence is correct -----------------------------------------
check "indexed memory is silent" "[ -z \"\$(fire \"$MEM/indexed.md\")\" ]"
check "MEMORY.md itself is silent" "[ -z \"\$(fire \"$MEM/MEMORY.md\")\" ]"
check "ordinary source file is silent" "[ -z \"\$(fire \"$TMP/src/app.ts\")\" ]"
check "path merely containing 'memory' is silent" "[ -z \"\$(fire \"$TMP/src/memory-manager.ts\")\" ]"

# --- a folder with no index at all ---------------------------------------------
NOIDX="$TMP/projects/noindex/memory"; mkdir -p "$NOIDX"; printf 'body\n' > "$NOIDX/lonely.md"
out="$(fire "$NOIDX/lonely.md")"
check "missing index is reported" "printf '%s' \"\$out\" | grep -q 'no MEMORY.md index'"

# --- robustness: the hook must never break a turn ------------------------------
check "empty stdin exits 0" "echo '' | bash \"$HOOK\"; [ \$? -eq 0 ]"
check "malformed JSON exits 0" "echo 'not json' | bash \"$HOOK\"; [ \$? -eq 0 ]"
check "payload without a path exits 0" "echo '{\"tool_name\":\"Bash\"}' | bash \"$HOOK\"; [ \$? -eq 0 ]"
check "nonexistent file exits 0" "fire \"$TMP/gone/memory/x.md\" >/dev/null; [ \$? -eq 0 ]"

# --- installer -----------------------------------------------------------------
CH="$TMP/claudehome"; mkdir -p "$CH"
printf '{"theme":"dark","hooks":{"PostToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo pre-existing"}]}]}}\n' > "$CH/settings.json"
HOME="$TMP/fakehome" bash "$INSTALL" --claude-home "$CH" --repo-root "$ROOT" >/dev/null 2>&1
check "installer registers the hook" "grep -q 'memory-index-hook' \"$CH/settings.json\""
check "installer keeps the pre-existing hook" "grep -q 'pre-existing' \"$CH/settings.json\""
check "installer keeps unrelated settings" "grep -q '\"theme\"' \"$CH/settings.json\""
check "installer leaves valid JSON" "jq -e 'type == \"object\"' \"$CH/settings.json\""
check "installer backs the file up" "[ -f \"$CH/settings.json.aidevops.bak\" ]"
check "installer copies the hook script" "[ -f \"$TMP/fakehome/.config/ai-devops/memory-index-hook\" ]"

before="$(md5sum < "$CH/settings.json")"
HOME="$TMP/fakehome" bash "$INSTALL" --claude-home "$CH" --repo-root "$ROOT" >/dev/null 2>&1
after="$(md5sum < "$CH/settings.json")"
check "installer is idempotent" "[ \"$before\" = \"$after\" ]"
HOME="$TMP/fakehome" bash "$INSTALL" --check --claude-home "$CH" --repo-root "$ROOT" >/dev/null 2>&1
check "--check passes once installed" "[ \$? -eq 0 ]"

# --- installer must refuse a broken settings file ------------------------------
BAD="$TMP/badhome"; mkdir -p "$BAD"; printf '{ this is not json' > "$BAD/settings.json"
HOME="$TMP/fakehome2" bash "$INSTALL" --claude-home "$BAD" --repo-root "$ROOT" >/dev/null 2>&1; rc=$?
check "installer fails on unparseable settings" "[ $rc -ne 0 ]"
check "installer did not rewrite the broken file" "grep -q 'this is not json' \"$BAD/settings.json\""

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
