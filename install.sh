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
ok()   { printf '\033[32m[PASS]\033[0m %s\n' "$1"; }

required_failures=()
optional_failures=()
stage_results=()

run_stage() {
  local classification="$1" name="$2"
  shift 2
  info "$name"
  if "$@"; then
    stage_results+=("PASS\t$classification\t$name")
    ok "$name"
  else
    local rc=$?
    stage_results+=("FAIL($rc)\t$classification\t$name")
    if [ "$classification" = "required" ]; then
      required_failures+=("$name")
      warn "REQUIRED stage failed: $name"
    else
      optional_failures+=("$name")
      warn "Optional stage failed: $name"
    fi
  fi
}

print_summary() {
  echo
  info "Install stage summary"
  printf '  %b\n' "${stage_results[@]}"
  if [ "${#optional_failures[@]}" -gt 0 ]; then
    warn "Optional failures: ${optional_failures[*]}"
  fi
  if [ "${#required_failures[@]}" -gt 0 ]; then
    warn "Install incomplete; required failures: ${required_failures[*]}"
    return 1
  fi
  return 0
}

require_commands() {
  local missing=() command_name
  for command_name in "$@"; do
    command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
  done
  [ "${#missing[@]}" -eq 0 ] || {
    warn "Missing required commands after installation attempt: ${missing[*]}"
    return 1
  }
}

# Dependency-light contract used by tests. It exercises the same runner and
# independent Node/npm/npx verification without touching machine state.
if [ "${1:-}" = "--test-stage-runner" ]; then
  test_stage() { [ "${AI_INSTALL_TEST_FAIL_STAGE:-}" != "$1" ]; }
  for test_name in dependencies directories config config-migration tools skills identity permissions memory manifest doctor; do
    run_stage required "$test_name" test_stage "$test_name"
  done
  run_stage optional optional-provider test_stage optional-provider
  test_node_toolchain() {
    [ "${AI_INSTALL_TEST_FAIL_STAGE:-}" != "node-toolchain" ] || return 1
    [ "${AI_INSTALL_TEST_NODE_MODE:-present}" = "present" ] || return 1
    node() { :; }; npm() { :; }; npx() { :; }
    export -f node npm npx
    require_commands node npm npx
  }
  run_stage required node-toolchain test_node_toolchain
  print_summary
  exit $?
fi

REQUIRE_SECRETS=auto
for arg in "$@"; do
  case "$arg" in
    --require-secrets) REQUIRE_SECRETS=yes ;;
    --skip-secrets) REQUIRE_SECRETS=no ;;
    -h|--help)
      echo "usage: ./install.sh [--require-secrets|--skip-secrets]"
      exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

# Pick a sudo prefix only if we are not already root.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    warn "Not root and sudo not found; system-path steps may fail."
  fi
fi

install_dependencies() {
  local apt_packages=(git curl jq ripgrep unzip python3 python3-pip gh)
  local missing=() command_name
  for command_name in git curl jq rg unzip python3 pip3 gh; do
    command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    command -v apt-get >/dev/null 2>&1 || {
      warn "apt-get unavailable; install manually: ${missing[*]}"
      return 1
    }
    $SUDO apt-get update -y || return 1
    $SUDO apt-get install -y "${apt_packages[@]}" || return 1
  fi
  require_commands git curl jq rg unzip python3 pip3 gh
}

install_node_toolchain() {
  local missing=() command_name
  for command_name in node npm npx; do
    command -v "$command_name" >/dev/null 2>&1 || missing+=("$command_name")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    command -v apt-get >/dev/null 2>&1 || {
      warn "apt-get unavailable; install Node.js with node, npm, and npx"
      return 1
    }
    $SUDO apt-get update -y || return 1
    $SUDO apt-get install -y nodejs npm || return 1
  fi
  require_commands node npm npx
}

run_stage required "Base dependencies" install_dependencies
run_stage required "Node toolchain (node/npm/npx)" install_node_toolchain

# --------------------------------------------------------------------------
# 2. System directories
# --------------------------------------------------------------------------
create_system_directories() { $SUDO mkdir -p "$ETC_DIR" "$LOG_DIR"; }
run_stage required "System directories" create_system_directories

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
install_configs() {
  install_config "$REPO_ROOT/config/models.env.example" "$ETC_DIR/models.env" || return 1
  install_config "$REPO_ROOT/config/server.env.example" "$ETC_DIR/server.env" || return 1
}
run_stage required "Configuration seed" install_configs
run_stage required "Configuration migration and validation" \
  "$REPO_ROOT/bin/ai-config-migrate" --repo-root "$REPO_ROOT" --config-dir "$ETC_DIR"

# --------------------------------------------------------------------------
# 4. Symlink bin/* into /usr/local/bin
# --------------------------------------------------------------------------
# First prune symlinks that point into this repo's bin/ but whose target is gone.
# Without this, a retired command (e.g. ai-glm-agent.ps1) leaves a dangling link on
# PATH forever: the loop below skips it because there is no source file to link from.
install_entrypoints() {
  local dest target src name conflicts=0
  for dest in "$BIN_TARGET"/*; do
    [ -L "$dest" ] || continue
    target="$(readlink "$dest")"
    case "$target" in
      "$REPO_ROOT"/bin/*)
        [ -e "$dest" ] || { $SUDO rm -f "$dest" || return 1; info "  removed stale $(basename "$dest")"; } ;;
    esac
  done
  for src in "$REPO_ROOT"/bin/*; do
    [ -f "$src" ] && [ -x "$src" ] || continue
    name="$(basename "$src")"
    dest="$BIN_TARGET/$name"
    if [ -L "$dest" ] || [ ! -e "$dest" ]; then
      $SUDO ln -sfn "$src" "$dest" || return 1
      info "  linked $name"
    else
      warn "  $dest exists and is not a symlink; leaving it untouched"
      conflicts=1
    fi
  done
  [ "$conflicts" -eq 0 ]
}
run_stage required "Unix entrypoints" install_entrypoints

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
run_stage required "Claude and Codex skills" "$REPO_ROOT/bin/ai-install-skills"

# --------------------------------------------------------------------------
# 4.6 Git commit identity. Without a global identity Git does not stop — it
#     silently invents one from the OS account and stamps it on every commit.
#     That already put 231 wrong-identity commits into merged dflow history.
#     Machine-level on purpose: every agent (Claude, Codex, GLM, Grok, Kimi)
#     uses the same git binary, so one setting covers all of them.
# --------------------------------------------------------------------------
run_stage required "Git commit identity" "$REPO_ROOT/bin/ai-git-identity"

# --------------------------------------------------------------------------
# 4.7 Claude tool permissions. Claude Code stops and asks before a tool that is
#     not on the allow list; in a delegated or unattended session nobody is
#     there to answer, so the work stalls and looks like a broken tool. The
#     required entries live in config/claude-permissions.allow and are merged
#     into the USER-level ~/.claude/settings.json, covering every project.
# --------------------------------------------------------------------------
run_stage required "Claude tool permissions" "$REPO_ROOT/bin/ai-claude-permissions"

# --------------------------------------------------------------------------
# 4b. Secrets + Claude launcher (interactive only)
# --------------------------------------------------------------------------
# Wires the vault-locked 1Password service-account token, the central mcp.env
# reference file, and the transparent `claude` launcher. Runs only in an
# interactive terminal (it may prompt once for the token). In automation, run
# `setup-secrets.sh` by hand, or pass OP_SERVICE_ACCOUNT_TOKEN in the env.
secrets_available=0
[ -t 0 ] || [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] || [ -s "$HOME/.config/ai-devops/op-service-account" ] && secrets_available=1
if [ "$REQUIRE_SECRETS" = "yes" ] || { [ "$REQUIRE_SECRETS" = "auto" ] && [ "$secrets_available" -eq 1 ]; }; then
  run_stage required "Secrets wiring" "$REPO_ROOT/bin/setup-secrets.sh"
elif [ "$REQUIRE_SECRETS" = "no" ]; then
  stage_results+=("SKIP\tselected\tSecrets wiring (--skip-secrets)")
else
  stage_results+=("SKIP\toptional\tSecrets wiring (no interactive input or protected token)")
  info "Secrets wiring skipped: no interactive input or protected token"
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
seed_memory() {
  if [ -x "$BIN_TARGET/ai-memory-sync" ]; then
    "$BIN_TARGET/ai-memory-sync"
  else
    "$REPO_ROOT/bin/ai-memory-sync"
  fi
}
run_stage required "Private memory seed" seed_memory

run_stage required "Managed artifact manifest" \
  "$REPO_ROOT/bin/ai-install-manifest" --repo-root "$REPO_ROOT" --config-dir "$ETC_DIR" --bin-target "$BIN_TARGET"

# --------------------------------------------------------------------------
# 4d. OpenCode GLM server (hosts GLM for `ai-glm`)
# --------------------------------------------------------------------------
# Installs the pinned OpenCode release, the canonical GLM agents, and the
# loopback-only systemd USER service. Skipped when running as root, because a
# user service installed under /root would never be the one `ai-glm` talks to.
#
# The setup script deliberately FORCE-COPIES config/opencode/* on every run
# (unlike models.env/server.env, which are copied only if absent). The agent
# files carry the only working read-only enforcement in OpenCode, so the repo
# copy must always win. Do not "fix" this to match the no-overwrite pattern.
if [ "$(id -u)" -eq 0 ]; then
  stage_results+=("SKIP\toptional\tOpenCode GLM server (root install)")
  warn "Running as root — skipping OpenCode GLM server setup. Re-run as your normal user, or run: bin/setup-opencode-glm.sh"
elif [ -s "$HOME/.config/ai-devops/op-service-account" ]; then
  run_stage required "OpenCode GLM server (pinned $(tr -d ' \t\r\n' < "$REPO_ROOT/config/opencode/version"))" \
    "$REPO_ROOT/bin/setup-opencode-glm.sh"
else
  stage_results+=("SKIP\toptional\tOpenCode GLM server (no protected token)")
  info "  No 1Password service-account token yet — skipping. Run: setup-opencode-glm.sh"
fi

# --------------------------------------------------------------------------
# 5. Doctor
# --------------------------------------------------------------------------
run_doctor() {
  echo
  if command -v ai-devops >/dev/null 2>&1; then
    ai-devops doctor
  else
    "$REPO_ROOT/bin/ai-devops" doctor
  fi
}
run_stage required "ai-devops doctor" run_doctor

echo
if print_summary; then
  info "install.sh complete. source=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo unknown)"
  exit 0
fi
exit 1
