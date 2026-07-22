#!/usr/bin/env bash
# install.sh — install / verify the AI DevOps toolkit on this machine.
#
# What it does:
#   - Verifies (and, where possible via apt, installs) base dependencies.
#   - Creates /etc/ai-devops and /var/log/ai-devops.
#   - Copies config/*.env.example into /etc/ai-devops ONLY if the real file
#     does not already exist (never overwrites real config).
#   - Symlinks bin/* into /usr/local/bin.
#   - Installs Claude + Codex skills into ~/.claude/skills and ~/.codex/skills
#     (force-updated), and seeds ~/.claude/CLAUDE.md / ~/.codex/AGENTS.md only if
#     missing. Run as your normal user (not sudo) so skills land in your home.
#   - Runs `ai-devops doctor` at the end.
#
# Safe to re-run (idempotent). Uses sudo for system paths.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ETC_DIR="/etc/ai-devops"
LOG_DIR="/var/log/ai-devops"
BIN_TARGET="/usr/local/bin"

info() { printf '\033[1m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$1"; }

# Pick a sudo prefix only if we are not already root.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    warn "Not root and sudo not found; system-path steps may fail."
  fi
fi

# --------------------------------------------------------------------------
# 1. Dependencies
# --------------------------------------------------------------------------
info "Checking dependencies"
APT_PKGS=(git curl jq ripgrep unzip python3 python3-pip)
# nodejs/npm added only if apt can provide them (some servers use nvm instead).
MISSING=()
for bin in git curl jq rg unzip python3 pip3; do
  command -v "$bin" >/dev/null 2>&1 || MISSING+=("$bin")
done

if [ "${#MISSING[@]}" -gt 0 ]; then
  info "Attempting to install missing packages via apt: ${MISSING[*]}"
  if command -v apt-get >/dev/null 2>&1; then
    $SUDO apt-get update -y || warn "apt-get update failed; continuing"
    $SUDO apt-get install -y "${APT_PKGS[@]}" || warn "apt-get install failed for some packages"
    # node/npm are best-effort via apt.
    $SUDO apt-get install -y nodejs npm || warn "nodejs/npm not installed via apt (nvm/other is fine)"
  else
    warn "apt-get not available; install these manually: ${MISSING[*]}"
  fi
else
  info "All base dependencies present"
fi

# gh is required but is not always in apt; verify and instruct if missing.
if ! command -v gh >/dev/null 2>&1; then
  warn "GitHub CLI (gh) not found. Install: https://github.com/cli/cli#installation"
fi

# --------------------------------------------------------------------------
# 2. System directories
# --------------------------------------------------------------------------
info "Creating $ETC_DIR and $LOG_DIR"
$SUDO mkdir -p "$ETC_DIR" "$LOG_DIR"

# --------------------------------------------------------------------------
# 3. Config files (never overwrite real config)
# --------------------------------------------------------------------------
install_config() {
  local example="$1" dest="$2"
  if [ -f "$dest" ]; then
    info "Keeping existing $dest (not overwritten)"
  else
    info "Installing $dest from example"
    $SUDO cp "$example" "$dest"
  fi
}
install_config "$REPO_ROOT/config/models.env.example" "$ETC_DIR/models.env"
install_config "$REPO_ROOT/config/server.env.example" "$ETC_DIR/server.env"

# --------------------------------------------------------------------------
# 4. Symlink bin/* into /usr/local/bin
# --------------------------------------------------------------------------
info "Symlinking Unix entrypoints into $BIN_TARGET"
for src in "$REPO_ROOT"/bin/*; do
  [ -f "$src" ] && [ -x "$src" ] || continue
  name="$(basename "$src")"
  dest="$BIN_TARGET/$name"
  # Only replace if missing or already points into this repo.
  if [ -L "$dest" ] || [ ! -e "$dest" ]; then
    $SUDO ln -sfn "$src" "$dest"
    info "  linked $name"
  else
    warn "  $dest exists and is not a symlink; leaving it untouched"
  fi
done

# --------------------------------------------------------------------------
# 4.5 Claude + Codex skills and global instruction files. Delegate to the one
#     tested installer so client-specific skills, shared skills, collision
#     protection, and recoverable obsolete-skill handling cannot drift here.
#     Skills go into the invoking user's home (run this as your normal user,
#     NOT via sudo, so they don't land under /root).
# --------------------------------------------------------------------------
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
  warn "Running as root via sudo; skills would land under /root. Re-run as your normal user for per-user skill install."
fi
info "Installing Claude + Codex skills into \$HOME"
"$REPO_ROOT/bin/ai-install-skills"

# --------------------------------------------------------------------------
# 4b. Secrets + Claude launcher (interactive only)
# --------------------------------------------------------------------------
# Wires the vault-locked 1Password service-account token, the central mcp.env
# reference file, and the transparent `claude` launcher. Runs only in an
# interactive terminal (it may prompt once for the token). In automation, run
# `setup-secrets.sh` by hand, or pass OP_SERVICE_ACCOUNT_TOKEN in the env.
info "Secrets wiring (1Password service account + claude launcher)"
if [ -t 0 ] || [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] || [ -s "$HOME/.config/ai-devops/op-service-account" ]; then
  "$REPO_ROOT/bin/setup-secrets.sh" || warn "setup-secrets.sh did not complete; run it by hand later."
else
  info "  Non-interactive shell — skipping. Run: setup-secrets.sh"
fi

# --------------------------------------------------------------------------
# 4c. Memory auto-sync (keep Claude memories in sync across machines)
# --------------------------------------------------------------------------
# Runs the safe two-way sync once now (seed). ai-memory-sync uses an isolated
# clone + a secret gate, so it never touches this checkout and never uploads
# anything that looks like a secret.
#
# SCHEDULING (the recurring cron) is NOT added here on purpose: a cron is
# host-level state, which on ansible-managed Ubuntu hosts belongs in
# /worksp/ansible (the `cron_glue` role / `cron_glue_entries`), so it stays
# tracked and reproducible. Windows machines (not ansible-managed) schedule it
# via the Scheduled Task in bin/setup-machine.ps1.
info "Memory auto-sync (one-time seed; schedule is owned by ansible cron_glue)"
"$BIN_TARGET/ai-memory-sync" >/dev/null 2>&1 || "$REPO_ROOT/bin/ai-memory-sync" >/dev/null 2>&1 || true

# --------------------------------------------------------------------------
# 5. Doctor
# --------------------------------------------------------------------------
info "Running ai-devops doctor"
echo
if command -v ai-devops >/dev/null 2>&1; then
  ai-devops doctor || true
else
  "$REPO_ROOT/bin/ai-devops" doctor || true
fi

echo
info "install.sh complete."
