#!/usr/bin/env bash
# Install the pinned DeepSeek Harness (dsh) used by the candidate
# deepseek-openrouter reviewer route (#2549). Safe to re-run. The review and
# second-opinion paths build a fresh private profile per invocation; nothing
# global is configured here.
set -euo pipefail

SELF="${BASH_SOURCE[0]}"
REAL_SELF="$(readlink -f "$SELF" 2>/dev/null || true)"
[ -z "$REAL_SELF" ] || SELF="$REAL_SELF"
ROOT="$(cd "$(dirname "$SELF")/.." && pwd)"

VERSION_FILE="$ROOT/config/deepseek-harness/version"
[ -s "$VERSION_FILE" ] || { echo "missing $VERSION_FILE" >&2; exit 1; }
VERSION="$(tr -d ' \t\r\n' < "$VERSION_FILE")"
[ -n "$VERSION" ] || { echo "config/deepseek-harness/version is empty" >&2; exit 1; }

HOME_DIR="${USERPROFILE:-$HOME}"
case "$HOME_DIR" in [A-Za-z]:*) HOME_DIR="/$(printf '%s' "$HOME_DIR" | sed 's#\\#/#g; s#:#/#')";; esac
LIB_ROOT="$HOME_DIR/.local/lib/ai-devops/deepseek-harness"
PREFIX="$LIB_ROOT/$VERSION"
BIN="$PREFIX/node_modules/.bin/dsh"
[ "${SYSTEMROOT:-}" != "" ] && [ ! -f "$BIN" ] && [ -f "$BIN.cmd" ] && BIN="$BIN.cmd"

command -v npm >/dev/null 2>&1 || { echo "npm is required to install the pinned DeepSeek Harness." >&2; exit 1; }

if [ ! -x "$BIN" ]; then
  echo "Installing @deepseek-ai/dsh@$VERSION into $PREFIX"
  mkdir -p "$PREFIX"
  npm install --prefix "$PREFIX" "@deepseek-ai/dsh@$VERSION" --no-audit --no-fund >/dev/null
  [ -x "$BIN" ] || { echo "DeepSeek Harness binary missing after install: $BIN" >&2; exit 1; }
else
  echo "@deepseek-ai/dsh@$VERSION already installed"
fi

ACTUAL="$("$BIN" --version 2>/dev/null | tail -1 | tr -d ' \r')"
[ "$ACTUAL" = "$VERSION" ] || { echo "pinned version is $VERSION but the installed binary reports '$ACTUAL'" >&2; exit 1; }
echo "DeepSeek Harness $VERSION ready at $BIN"
