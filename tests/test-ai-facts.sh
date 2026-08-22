#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SCRIPT="$ROOT/bin/ai-facts"
PASS=0; FAIL=0; ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }; check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT; mkdir -p "$TMP/hub/facts"
printf '# Known fix\n\nStatus 000 means local transport health.\n' > "$TMP/hub/facts/glm.md"
printf '# Other\n\nUnrelated portable fact.\n' > "$TMP/hub/MEMORY.md"
git -C "$TMP/hub" init -q; printf 'ignored.md\n' > "$TMP/hub/.gitignore"; printf 'secret ignored fact\n' > "$TMP/hub/ignored.md"
printf 'tracked then deleted\n' > "$TMP/hub/deleted.md"; git -C "$TMP/hub" add deleted.md; rm "$TMP/hub/deleted.md"
printf 'hidden portable fact\n' > "$TMP/hub/.hidden.md"
export AI_DEVOPS_MEMORY_HOME="$TMP/hub" AI_FACTS_ALLOW_FIXTURE=1
result="$($SCRIPT search --json 'status 000')"
check 'search returns a known portable fact' "jq -e 'length==1 and .[0].path==\"facts/glm.md\" and (.[] .text|contains(\"local transport\"))' <<<\"\$result\""
check 'search is case insensitive' "'$SCRIPT' search 'STATUS 000' | grep -Fq 'local transport health'"
check 'no match is successful and empty' "[ -z \"\$('$SCRIPT' search missing-phrase)\" ]"
check 'JSON no match is successful and empty' "'$SCRIPT' search --json missing-phrase | jq -e 'length==0'"
check 'index reports Markdown coverage only' "'$SCRIPT' index | jq -e '.markdown_files==2 and .mode==\"read-only\"'"
# The Windows runner can temporarily lack ripgrep even though the installed
# machine health check requires it. Fact lookup must retain its read-only core
# behavior through that recoverable dependency gap.
check 'search falls back safely when ripgrep is unavailable' "AI_FACTS_DISABLE_RG=1 '$SCRIPT' search --json 'status 000' | jq -e 'length==1 and .[0].path==\"facts/glm.md\"'"
for i in $(seq 1 60); do printf 'limit fixture %s\n' "$i"; done > "$TMP/hub/facts/limit.md"
check 'ripgrep and fallback both enforce the 50-result cap' "[ \"\$('$SCRIPT' search --json 'limit fixture' | jq length)\" -eq 50 ] && [ \"\$(AI_FACTS_DISABLE_RG=1 '$SCRIPT' search --json 'limit fixture' | jq length)\" -eq 50 ]"
check 'plain fallback keeps the normal relative path format' "AI_FACTS_DISABLE_RG=1 '$SCRIPT' search 'status 000' | grep -Fq './facts/glm.md:'"
check 'fallback excludes ignored memory files like ripgrep' "AI_FACTS_DISABLE_RG=1 '$SCRIPT' search --json 'secret ignored fact' | jq -e 'length==0'"
check 'fallback skips hidden memory files like ripgrep' "AI_FACTS_DISABLE_RG=1 '$SCRIPT' search --json 'hidden portable fact' | jq -e 'length==0'"
check 'index skips tracked files deleted from disk' "AI_FACTS_DISABLE_RG=1 '$SCRIPT' index | jq -e '.markdown_files==3'"
before="$(find "$TMP/hub" -type f -printf '%P %s %T@\n' | sort)"; "$SCRIPT" search fact >/dev/null; after="$(find "$TMP/hub" -type f -printf '%P %s %T@\n' | sort)"
[ "$before" = "$after" ] && ok 'fact access never writes the hub' || bad 'fact access never writes the hub'
unset AI_FACTS_ALLOW_FIXTURE
check 'noncanonical root is refused without fixture override' "! '$SCRIPT' index >/dev/null 2>&1"
check 'skill forbids Codex SQLite access' "grep -Fq 'Never read or synchronize Codex SQLite memory' '$ROOT/skills/codex/codex-portable-facts/SKILL.md'"
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
