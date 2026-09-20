#!/usr/bin/env bash
# Offline tests for bin/ai-helper-global and its wiring into every helper
# wrapper. No provider is called: the checks are on the command itself and on
# the prompt-assembly code paths that prepend it.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SCRIPT="$ROOT/bin/ai-helper-global"
PASS=0; FAIL=0; ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

echo "ai-helper-global"
check "the command is executable"            "[ -x '$SCRIPT' ]"
check "--check passes with the shipped file" "'$SCRIPT' --check"
check "--path names the shipped template"    "'$SCRIPT' --path | grep -q 'templates/system/AGENTS-global-helper.md'"
check "printing emits the standing rules"    "'$SCRIPT' | grep -q 'Standing rules for a delegated helper'"
check "an unknown option exits 2"            "'$SCRIPT' --nope; [ \$? -eq 2 ]"
: > "$TMP/empty.md"
check "an empty source file is refused"      "! AI_HELPER_GLOBAL_FILE='$TMP/empty.md' '$SCRIPT' --check"

echo "the rules carry the load-bearing instructions"
for phrase in "You advise; the calling session decides" "verbatim evidence line" "Never wait" "Read-only unless" "Never handle secrets"; do
  check "rule present: $phrase" "'$SCRIPT' | grep -q '$phrase'"
done

echo "every helper wrapper prepends it"
# ai-deepseek-agent puts the rules in the user message (its review mode owns
# messages[0] byte for byte), so it carries helper_global_text, not the file form.
for w in ai-grok-review ai-qwen ai-kimi ai-glm ai-muse ai-gemini; do
  check "$w defines helper_global_prefix" "grep -q '^helper_global_prefix() {' '$ROOT/bin/$w'"
  check "$w calls it on the prompt"       "grep -q 'helper_global_prefix \"' '$ROOT/bin/$w'"
  check "$w still parses"                 "bash -n '$ROOT/bin/$w'"
done
check "ai-deepseek-agent defines helper_global_text" "grep -q '^helper_global_text() {' '$ROOT/bin/ai-deepseek-agent'"
check "ai-deepseek-agent prepends to the user message" "grep -q 'MSG=\"\$(helper_global_text)\$MSG\"' '$ROOT/bin/ai-deepseek-agent'"
check "ai-deepseek-agent still parses" "bash -n '$ROOT/bin/ai-deepseek-agent'"
check "no wrapper puts the rules in DeepSeek's system message" "! grep -q 'helper_global_text' <(grep 'build_candidate' '$ROOT/bin/ai-deepseek-agent')"

echo "the prepend is fail-open and can be switched off"
cat > "$TMP/probe.sh" <<'PROBE'
set -euo pipefail
sed -n '/^helper_global_prefix() {/,/^}/p' "$1" > "$2/fn.sh"
. "$2/fn.sh"
printf 'BODY\n' > "$2/p.txt"
helper_global_prefix "$2/p.txt"
cat "$2/p.txt"
PROBE
run_probe(){ PATH="$ROOT/bin:$PATH" bash "$TMP/probe.sh" "$ROOT/bin/ai-muse" "$TMP"; }
run_probe > "$TMP/out1.txt" 2>/dev/null
check "prepend adds the rules above the prompt body" "head -1 '$TMP/out1.txt' | grep -q 'Standing rules'"
check "prepend keeps the prompt body"                "grep -qx BODY '$TMP/out1.txt'"
AI_HELPER_GLOBAL_DISABLE=1 run_probe > "$TMP/out2.txt" 2>/dev/null
check "AI_HELPER_GLOBAL_DISABLE=1 leaves the prompt untouched" "[ \"\$(cat '$TMP/out2.txt')\" = BODY ]"
# The repo bin is off PATH and no ai-helper-global sits beside the sourced
# function, so the prepend must find nothing and leave the prompt alone.
bash "$TMP/probe.sh" "$ROOT/bin/ai-muse" "$TMP" > "$TMP/out3.txt" 2>/dev/null
check "a missing command leaves the prompt untouched (fail-open)" "[ \"\$(cat '$TMP/out3.txt')\" = BODY ]"

echo "registered for machine install"
check "listed in config/machine-tools.tsv" "grep -q '^ai-helper-global\b' '$ROOT/config/machine-tools.tsv'"
check "has a Windows launcher"             "[ -f '$ROOT/bin/ai-helper-global.cmd' ]"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
