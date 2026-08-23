#!/usr/bin/env bash
# Install the direct, protected persistent Muse profile. Safe to re-run.
set -euo pipefail

SELF="${BASH_SOURCE[0]}"
REAL_SELF="$(readlink -f "$SELF" 2>/dev/null || true)"
[ -z "$REAL_SELF" ] || SELF="$REAL_SELF"
ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"
VERSION="$(tr -d ' \r\n' < "$ROOT/config/opencode/version")"
HOME_DIR="${USERPROFILE:-$HOME}"
case "$HOME_DIR" in [A-Za-z]:*) HOME_DIR="/$(printf '%s' "$HOME_DIR" | sed 's#\\#/#g; s#:#/#')";; esac
CFG="${AI_MUSE_CONFIG_DIR:-$HOME_DIR/.config/ai-devops-muse}"
BIN="$HOME_DIR/.local/lib/ai-devops/opencode/$VERSION/node_modules/opencode-ai/bin/opencode.exe"

[ -x "$BIN" ] || {
  echo "OpenCode $VERSION is not installed. Run bin/setup-opencode-glm.sh first." >&2
  exit 1
}
mkdir -p "$CFG/opencode-xdg/opencode/agent"
cp "$ROOT/config/opencode-muse/opencode.json" "$CFG/opencode-xdg/opencode/opencode.json"
cp "$ROOT/config/opencode-muse/agent/muse-review.md" "$CFG/opencode-xdg/opencode/agent/muse-review.md"
chmod 700 "$CFG" "$CFG/opencode-xdg" 2>/dev/null || true
echo "Muse persistent conversation profile installed. Check: AI_MUSE_CALLER=codex ai-muse doctor"
