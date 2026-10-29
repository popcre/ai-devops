#!/usr/bin/env bash
# Offline tests for the shared OpenCode verdict-stop plugin
# (config/opencode-plugins/verdict-stop.js): the installer helper, that every
# OpenCode reviewer entry point installs it (Windows and Linux share these
# Bash paths), its behaviour, and the pinned OpenCode hook contract.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/config/opencode-plugins/verdict-stop.js"
PASS=0; FAIL=0; SKIP=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
HOME_REAL="$HOME"   # only to find the installed pinned OpenCode binary
export HOME="$TMP/home"

# The helper copies the one shared file and refuses when it is missing.
. "$ROOT/tools/lib/reviewer-instructions.sh"
check "helper installs the shared plugin into a per-run config home" "reviewer_opencode_verdict_stop '$TMP/xdg/opencode' && cmp -s '$PLUGIN' '$TMP/xdg/opencode/plugin/verdict-stop.js'"
check "helper refuses when the shared plugin is missing" "! (REVIEWER_INSTRUCTIONS_ROOT='$TMP/empty'; reviewer_opencode_verdict_stop '$TMP/xdg2/opencode') 2>/dev/null && [ ! -e '$TMP/xdg2/opencode/plugin/verdict-stop.js' ]"
check "no per-reviewer copy of the plugin remains" "[ -z \"\$(cd '$ROOT' && git ls-files 'config/opencode-*/plugin/*')\" ]"

# Every OpenCode reviewer entry point loads the helper and calls it from the
# function that builds its per-run OpenCode config home.
installs(){ # installs FILE FUNCTION: FUNCTION's body calls the helper
  awk -v f="$2" '$0 ~ "^"f"[(][)]" || $0 ~ "^"f"[(][)] *[{]" {on=1} on && /reviewer_opencode_verdict_stop/ {hit=1} on && /^}/ {on=0} END {exit !hit}' "$1" \
    && grep -q 'tools/lib/reviewer-instructions.sh"' "$1"
}
check "StepFun review door installs the plugin" "installs '$ROOT/tools/lib/review-doors/stepfun.sh' install_opencode_profile"
check "DeepSeek review door installs the plugin" "installs '$ROOT/tools/lib/review-doors/deepseek.sh' install_profile"
check "Muse review door (OpenCode engine) installs the plugin" "installs '$ROOT/tools/lib/review-doors/muse.sh' install_opencode_profile"
check "ai-stepfun installs the plugin" "installs '$ROOT/bin/ai-stepfun' install_oc_profile"
check "ai-deepseek installs the plugin" "installs '$ROOT/bin/ai-deepseek' install_profile"
check "ai-muse stages the plugin in its per-run reviewer config home" "grep -q 'reviewer_opencode_verdict_stop \"\$XDG_CONFIG_HOME/opencode\"' '$ROOT/bin/ai-muse' && grep -q 'tools/lib/reviewer-instructions.sh\"' '$ROOT/bin/ai-muse'"
# Every reviewer profile that keeps compaction.auto on is covered above.
for prof in "$ROOT"/config/opencode-*/opencode.json; do
  name="$(basename "$(dirname "$prof")")"
  case "$name" in opencode-stepfun|opencode-deepseek|opencode-muse) ;;
    *) check "$name keeps compaction.auto off or is wired to the plugin" "! jq -e '.compaction.auto == true' '$prof' >/dev/null" ;;
  esac
done

if command -v node >/dev/null 2>&1; then
  check "verdict-stop plugin continues before the verdict and stops after it" "node '$ROOT/tests/opencode-verdict-stop-plugin.mjs' '$PLUGIN'"
else
  skip "verdict-stop plugin behaviour (node is not installed)"
fi
# Pinned-binary contract: OpenCode 1.18.12 fires both hooks with the payload
# shapes the plugin reads (sessionID input; enabled / text outputs), and the
# synthetic continue the plugin declines is the one gated by the hook.
OC_PIN="$(tr -d ' \r\n' < "$ROOT/config/opencode/version")"
OC_PINNED_BIN=""
for c in "$HOME_REAL/.local/lib/ai-devops/opencode/$OC_PIN/node_modules/opencode-ai/bin/opencode.exe" \
         "$HOME_REAL/.local/lib/ai-devops/opencode/$OC_PIN/node_modules/opencode-ai/bin/.opencode" \
         "$HOME_REAL/.local/lib/ai-devops/opencode/$OC_PIN/node_modules/opencode-ai/bin/opencode"; do
  [ -f "$c" ] && [ "$(head -c 2 "$c")" != '#!' ] && { OC_PINNED_BIN="$c"; break; }
done
if [ -n "$OC_PINNED_BIN" ] && [ "$OC_PIN" = 1.18.12 ]; then
  check "pinned OpenCode gates the post-compaction continue on the autocontinue hook" "LC_ALL=C grep -aFq 'trigger(\"experimental.compaction.autocontinue\",{sessionID:w.sessionID' '$OC_PINNED_BIN' && LC_ALL=C grep -aFq '{enabled:!0})).enabled)' '$OC_PINNED_BIN'"
  check "pinned OpenCode passes the whole text part to experimental.text.complete" "LC_ALL=C grep -aFq 'trigger(\"experimental.text.complete\",{sessionID:a.sessionID,messageID:a.assistantMessage.id,partID:a.currentText.id},{text:a.currentText.text})' '$OC_PINNED_BIN'"
else
  skip "pinned OpenCode hook contract (OpenCode ${OC_PIN:-?} binary not installed here)"
fi

printf '\n%s passed, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ]
