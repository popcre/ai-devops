#!/usr/bin/env bash
# Install the pinned OpenCode server that hosts GLM for `ai-glm`.
#
# Idempotent. Safe to re-run. Run as your normal user, never as root: the server is a
# systemd USER service and its config lives in your home directory.
#
# What it does:
#   1. Installs the exact OpenCode version from config/opencode/version into a private
#      prefix (never a global npm install, never "latest").
#   2. Copies the canonical OpenCode config + agents into an isolated XDG config home.
#   3. Generates a random loopback server password if one does not exist yet.
#   4. Installs a launcher that resolves the Z.ai key from 1Password at exec time.
#   5. Installs, enables, and starts the systemd user service.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG_DIR="${AI_DEVOPS_CONFIG_DIR:-$HOME/.config/ai-devops}"
OC_HOME="$CFG_DIR/opencode"            # our own metadata (password, installed-version)
OC_XDG="$CFG_DIR/opencode-xdg"         # becomes XDG_CONFIG_HOME for the server
OC_CONF="$OC_XDG/opencode"             # opencode.json + agent/ live here, and ONLY here
LIB_ROOT="$HOME/.local/lib/ai-devops/opencode"
BIN_DIR="$HOME/.local/bin"
STATE_DIR="$HOME/.local/state/ai-devops/glm"
UNIT_DIR="$HOME/.config/systemd/user"
PORT="${AI_GLM_PORT:-4096}"

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "Do not run as root. The OpenCode GLM server is a systemd USER service; running as root would install it under /root."

VERSION_FILE="$REPO_ROOT/config/opencode/version"
[ -s "$VERSION_FILE" ] || die "missing $VERSION_FILE"
VERSION="$(tr -d ' \t\r\n' < "$VERSION_FILE")"
[ -n "$VERSION" ] || die "config/opencode/version is empty"

command -v npm >/dev/null 2>&1 || die "npm is required to install the pinned OpenCode release."
command -v jq  >/dev/null 2>&1 || die "jq is required by ai-glm."
command -v op  >/dev/null 2>&1 || die "1Password CLI (op) is required."

# ---------------------------------------------------------------------------
# 1. Pinned OpenCode binary
# ---------------------------------------------------------------------------
PREFIX="$LIB_ROOT/$VERSION"
BINARY="$PREFIX/node_modules/opencode-ai/bin/opencode.exe"   # yes, .exe on Linux too
if [ ! -x "$BINARY" ]; then
  info "Installing opencode-ai@$VERSION into $PREFIX"
  mkdir -p "$PREFIX"
  npm install --prefix "$PREFIX" "opencode-ai@$VERSION" --no-audit --no-fund >/dev/null
  # npm's allow-scripts gate blocks the postinstall that materializes the platform
  # binary, so run it explicitly instead of hoping npm did it.
  if [ ! -x "$BINARY" ]; then
    info "Running opencode postinstall to materialize the platform binary"
    node "$PREFIX/node_modules/opencode-ai/postinstall.mjs"
  fi
  [ -x "$BINARY" ] || die "OpenCode binary missing after install: $BINARY"
else
  info "opencode-ai@$VERSION already installed"
fi

ACTUAL="$("$BINARY" --version 2>/dev/null | tail -1 | tr -d ' \r')"
[ "$ACTUAL" = "$VERSION" ] || die "pinned version is $VERSION but the installed binary reports '$ACTUAL'"

mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/opencode-ai-devops" <<EOF
#!/usr/bin/env bash
# Managed by ai-devops setup-opencode-glm.sh. Resolves to the pinned OpenCode build.
exec "$BINARY" "\$@"
EOF
chmod 0755 "$BIN_DIR/opencode-ai-devops"

# ---------------------------------------------------------------------------
# 2. Canonical config + agents
#
# INTENTIONAL EXCEPTION to this repo's usual "copy only if absent" rule for config
# files (see AGENTS.md). These are safety-critical: the agents' `tools:` map is the
# ONLY working read-only enforcement in OpenCode 1.18.12, so the repo copy must always
# win. Machine-local tuning goes in AI_GLM_PORT, not in an edited opencode.json.
# Do not "fix" this to match the no-overwrite pattern.
# ---------------------------------------------------------------------------
info "Installing canonical OpenCode config into $OC_CONF"
mkdir -p "$OC_CONF/agent" "$OC_HOME" "$STATE_DIR"/{sessions,locks,transcripts,wt,logs}
chmod 0700 "$CFG_DIR" "$OC_HOME" "$OC_XDG" 2>/dev/null || true
install -m 0644 "$REPO_ROOT/config/opencode/opencode.json" "$OC_CONF/opencode.json"
rm -f "$OC_CONF/agent"/*.md
install -m 0644 "$REPO_ROOT/config/opencode/agent"/*.md "$OC_CONF/agent/"
printf '%s\n' "$VERSION" > "$OC_HOME/installed-version"

# ---------------------------------------------------------------------------
# 3. Loopback server password
# ---------------------------------------------------------------------------
PW_FILE="$OC_HOME/server-password"
if [ ! -s "$PW_FILE" ]; then
  info "Generating loopback server password"
  ( umask 077; head -c 32 /dev/urandom | base64 | tr -d '\n=/+' > "$PW_FILE" )
fi
chmod 0600 "$PW_FILE"

# ---------------------------------------------------------------------------
# 4. Launcher (resolves the Z.ai key at exec time; no plaintext key at rest)
# ---------------------------------------------------------------------------
info "Installing $BIN_DIR/opencode-glm-launch"
cat > "$BIN_DIR/opencode-glm-launch" <<EOF
#!/usr/bin/env bash
# Managed by ai-devops setup-opencode-glm.sh.
# systemd -> this launcher -> op run -> opencode serve. The Z.ai key never touches
# a unit file, an argv, or a file at rest.
set -euo pipefail
CFG_DIR="\${AI_DEVOPS_CONFIG_DIR:-\$HOME/.config/ai-devops}"
TOKEN_FILE="\$CFG_DIR/op-service-account"
MCP_ENV="\$CFG_DIR/mcp.env"
OC_HOME="\$CFG_DIR/opencode"

export XDG_CONFIG_HOME="\$CFG_DIR/opencode-xdg"
export XDG_DATA_HOME="\$HOME/.local/share/ai-devops/opencode"
export XDG_STATE_HOME="\$HOME/.local/state/ai-devops/opencode"
export XDG_CACHE_HOME="\$HOME/.cache/ai-devops/opencode"
mkdir -p "\$XDG_DATA_HOME" "\$XDG_STATE_HOME" "\$XDG_CACHE_HOME"

if [ -z "\${ZAI_API_KEY:-}" ]; then
  # Loud-failure guard against an unbounded re-exec loop. If we have ALREADY re-exec'd
  # under \`op run\` and the key is still empty, the op:// reference points at a blank
  # field (op returns "" with exit 0). Do NOT re-exec again.
  if [ -n "\${AI_GLM_LAUNCH_REEXEC:-}" ]; then
    echo "FATAL: ZAI_API_KEY resolved EMPTY from \$MCP_ENV after 'op run'." >&2
    echo "       Fix the ZAI_API_KEY op:// reference to point at the populated field." >&2
    exit 1
  fi
  command -v op >/dev/null 2>&1 || { echo "FATAL: 1Password CLI (op) not found." >&2; exit 1; }
  [ -s "\$TOKEN_FILE" ] || { echo "FATAL: missing \$TOKEN_FILE" >&2; exit 1; }
  [ -f "\$MCP_ENV" ]    || { echo "FATAL: missing \$MCP_ENV" >&2; exit 1; }
  OP_SERVICE_ACCOUNT_TOKEN="\$(<"\$TOKEN_FILE")"
  export OP_SERVICE_ACCOUNT_TOKEN AI_GLM_LAUNCH_REEXEC=1
  exec op run --env-file "\$MCP_ENV" -- "\$0" "\$@"
fi

# OpenCode's built-in zai-coding-plan provider reads ZHIPU_API_KEY.
export ZHIPU_API_KEY="\$ZAI_API_KEY"
unset ZAI_API_KEY
export OPENCODE_SERVER_USERNAME="\${OPENCODE_SERVER_USERNAME:-opencode}"
OPENCODE_SERVER_PASSWORD="\$(<"\$OC_HOME/server-password")"
export OPENCODE_SERVER_PASSWORD
[ -n "\$OPENCODE_SERVER_PASSWORD" ] || { echo "FATAL: empty server password." >&2; exit 1; }

exec "$BIN_DIR/opencode-ai-devops" serve --hostname 127.0.0.1 --port "\${AI_GLM_PORT:-$PORT}"
EOF
chmod 0700 "$BIN_DIR/opencode-glm-launch"

# ---------------------------------------------------------------------------
# 5. systemd user service
# ---------------------------------------------------------------------------
info "Installing systemd user unit"
mkdir -p "$UNIT_DIR"
install -m 0644 "$REPO_ROOT/config/systemd/opencode-glm.service" "$UNIT_DIR/opencode-glm.service"

if command -v loginctl >/dev/null 2>&1; then
  if [ "$(loginctl show-user "$USER" -p Linger --value 2>/dev/null || echo no)" != "yes" ]; then
    info "Enabling linger so the GLM server survives logout (loginctl enable-linger $USER)"
    loginctl enable-linger "$USER" 2>/dev/null || warn "could not enable linger; the server will stop when you log out"
  fi
fi

systemctl --user daemon-reload
systemctl --user enable opencode-glm.service >/dev/null 2>&1 || true
systemctl --user restart opencode-glm.service

info "Waiting for the server to become healthy"
PW="$(<"$PW_FILE")"
ok=0
for _ in $(seq 1 30); do
  if curl -fsS -m 3 -u "opencode:$PW" "http://127.0.0.1:$PORT/global/health" >/dev/null 2>&1; then ok=1; break; fi
  sleep 2
done
[ "$ok" = 1 ] || die "server did not become healthy. Check: systemctl --user status opencode-glm; journalctl --user -u opencode-glm -n 50"

info "OpenCode GLM server is up on 127.0.0.1:$PORT (pinned $VERSION)"
info "Next: ai-glm doctor"
