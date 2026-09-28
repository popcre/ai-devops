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

publish_stage_report() {
  local report_dir="$HOME/.local/state/ai-devops/task-gates/install-stage-reports" tmp
  [ ! -L "$report_dir" ] || return 1
  mkdir -p -m 700 "$report_dir" && chmod 700 "$report_dir" || return 1
  STAGE_REPORT="$report_dir/$target_head.tsv"
  [ ! -L "$STAGE_REPORT" ] || return 1
  [ ! -e "$STAGE_REPORT" ] || [ -f "$STAGE_REPORT" ] || return 1
  tmp="$(mktemp "$report_dir/.stage.$target_head.XXXXXXXX")" || return 1
  chmod 600 "$tmp" || { rm -f -- "$tmp"; return 1; }
  if ! printf '%b\n' "${stage_results[@]}" > "$tmp" || ! mv -f -- "$tmp" "$STAGE_REPORT"; then
    rm -f -- "$tmp"
    return 1
  fi
  [ "$(stat -c %a "$STAGE_REPORT")" = 600 ]
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
  run_stage optional blocker-watch test_stage blocker-watch
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
AUTHORIZATION_TEST_ONLY=0
reviewer_approval=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --require-secrets) REQUIRE_SECRETS=yes; shift ;;
    --skip-secrets) REQUIRE_SECRETS=no; shift ;;
    --reviewer-approval)
      [ "$#" -ge 2 ] && [ -f "$2" ] || { warn '--reviewer-approval needs the assigned AI reviewer exact-head APPROVE report'; exit 2; }
      reviewer_approval="$(realpath -- "$2")"; shift 2 ;;
    --test-authorization-only) AUTHORIZATION_TEST_ONLY=1; shift ;;
    -h|--help)
      echo "usage: ./install.sh [--require-secrets|--skip-secrets] [--reviewer-approval REPORT]"
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
if [ "$AUTHORIZATION_TEST_ONLY" -eq 1 ]; then
  fixture_root="$(realpath -e "$REPO_ROOT")" || exit 2
  fixture_origin="$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null)" || exit 2
  case "$fixture_root" in /tmp/*) ;; *) warn 'authorization test needs a disposable /tmp checkout'; exit 2 ;; esac
  case "$fixture_origin" in file:///tmp/*|/tmp/*) ;; *) warn 'authorization test needs a local /tmp origin'; exit 2 ;; esac
fi
install_launcher="$BIN_TARGET/ai-task-gates"
if [ "$AUTHORIZATION_TEST_ONLY" -eq 1 ] && [ "${AI_TASK_GATES_INSTALL_TEST_MODE:-0}" = 1 ]; then
  test_root="$(realpath -e "${AI_TASK_GATES_TEST_ROOT:-/nonexistent}")" || exit 2
  case "$fixture_root" in "$test_root"/*) ;; *) warn 'authorization fixture root differs from checkout'; exit 2 ;; esac
  install_launcher="$test_root/bin/ai-task-gates"
fi

# A direct installer and an updater share one checkout lock. An updater passes
# its open descriptor to its direct child; neither an environment flag nor a
# stale lock-file name alone is accepted as ownership.
install_lock_dir="$HOME/.local/state/ai-devops/task-gates"
install_lock_name="install-$(printf '%s' "$REPO_ROOT" | sha256sum | cut -c1-16).lock"
install_original_umask="$(umask)"
umask 077
mkdir -p "$install_lock_dir" || exit 1
install_lock_file="$install_lock_dir/$install_lock_name"
if [ "${AI_DEVOPS_INSTALL_LOCK_FD:-}" = 9 ]; then
  [ "${AI_DEVOPS_INSTALL_LOCK_PARENT:-}" = "$PPID" ] &&
    [ "$(readlink /proc/$$/fd/9 2>/dev/null)" = "$install_lock_file" ] &&
    flock -n 9 || { warn 'installer did not inherit the updater checkout lock'; exit 1; }
else
  exec 9>"$install_lock_file" || exit 1
  flock -n 9 || { warn 'another installation is active for this checkout'; exit 1; }
fi
umask "$install_original_umask"
if [ "${AI_DEVOPS_INSTALL_DEFER_FINALIZE:-0}" = 1 ] &&
   [ "${AI_DEVOPS_INSTALL_LOCK_FD:-}" != 9 ]; then
  warn 'only the lock-owning updater may defer finalization'
  exit 1
fi

# Resume verifies the installed baseline and pending authorization before the
# first dependency, protected config, symlink, or per-user installation stage.
target_head="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)" || exit 1
issued_auth="${AI_TASK_GATES_DIR:-$HOME/.local/state/ai-devops/task-gates}/install-authorizations/$target_head.json"
if [ -f "$issued_auth" ]; then
  # Direct first installs and exact-commit migrations begin with issued
  # authority. Reserve it from the already checked-out target before resume.
  (cd "$REPO_ROOT" && "$REPO_ROOT/bin/ai-task-gates" install-verify --phase preflight \
    --target-head "$target_head" --installed-checkout "$REPO_ROOT" \
    --installed-launcher "$install_launcher" --caller-pinned) || {
      warn 'direct installation preflight refused before any machine changes'; exit 1;
    }
fi
resume_args=(install-verify --phase resume --target-head "$target_head"
  --installed-checkout "$REPO_ROOT" --installed-launcher "$install_launcher")
[ -z "$reviewer_approval" ] || resume_args+=(--reviewer-approval "$reviewer_approval")
resume_output="$(cd "$REPO_ROOT" && "$REPO_ROOT/bin/ai-task-gates" "${resume_args[@]}")" || {
  warn 'installation authorization refused before any machine changes'; exit 1;
}
printf '%s\n' "$resume_output"
if [ "$resume_output" = "AI_DEVOPS_INSTALL_RECOVERED=$target_head" ]; then
  info "Prior installation of $target_head was already complete; finalization cleanup recovered"
  exit 0
fi
[ "$AUTHORIZATION_TEST_ONLY" -eq 0 ] || exit 0

# Pick a sudo prefix only if we are not already root.
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    warn "Not root and sudo not found; system-path steps may fail."
  fi
fi

# Preserve versioned protected files before the first installer stage. The
# backup remains owner-protected for recovery; no value enters output.
backup_protected_config() {
  local f
  BACKUP_DIR=""
  $SUDO install -d -m 700 /var/backups/ai-devops || return 1
  BACKUP_DIR="$($SUDO mktemp -d /var/backups/ai-devops/install.XXXXXXXX)" || return 1
  for f in models.env server.env config-state.json install-manifest.tsv; do
    [ ! -L "$ETC_DIR/$f" ] || { warn "refusing symlinked protected config: $f"; return 1; }
    if [ -e "$ETC_DIR/$f" ]; then
      [ -f "$ETC_DIR/$f" ] || return 1
      $SUDO cp -p "$ETC_DIR/$f" "$BACKUP_DIR/$f" || return 1
      [ "$($SUDO sha256sum "$ETC_DIR/$f" | cut -d' ' -f1)" = \
        "$($SUDO sha256sum "$BACKUP_DIR/$f" | cut -d' ' -f1)" ] || return 1
    else
      $SUDO touch "$BACKUP_DIR/absent.$f" || return 1
    fi
  done
  $SUDO chmod 700 "$BACKUP_DIR"
}
restore_protected_config() {
  local f failed=0
  [ -n "${BACKUP_DIR:-}" ] && $SUDO test -d "$BACKUP_DIR" || return 1
  for f in models.env server.env config-state.json install-manifest.tsv; do
    [ ! -L "$ETC_DIR/$f" ] || { failed=1; continue; }
    if $SUDO test -f "$BACKUP_DIR/$f"; then
      $SUDO cp -p "$BACKUP_DIR/$f" "$ETC_DIR/$f" || failed=1
    elif $SUDO test -f "$BACKUP_DIR/absent.$f"; then
      $SUDO rm -f -- "$ETC_DIR/$f" || failed=1
    else
      failed=1
    fi
  done
  [ "$failed" -eq 0 ]
}
backup_install_routing() {
  local dest src name target tmp
  local -A seen=()
  tmp="$(mktemp)" || return 1
  chmod 600 "$tmp" || return 1
  for src in "$REPO_ROOT"/bin/*; do
    [ -f "$src" ] && [ -x "$src" ] || continue
    name="$(basename "$src")"; dest="$BIN_TARGET/$name"; seen["$dest"]=1
    case "$dest" in *$'\t'*|*$'\n'*) return 1 ;; esac
    if [ -L "$dest" ]; then
      target="$(readlink "$dest")" || return 1
      case "$target" in *$'\t'*|*$'\n'*) return 1 ;; esac
      printf '%s\tsymlink\t%s\n' "$dest" "$target" >> "$tmp"
    elif [ -e "$dest" ]; then
      printf '%s\tregular\t-\n' "$dest" >> "$tmp"
    else
      printf '%s\tabsent\t-\n' "$dest" >> "$tmp"
    fi
  done
  # The installer also removes stale links into its bin tree. Capture those.
  for dest in "$BIN_TARGET"/*; do
    [ -L "$dest" ] && [ -z "${seen[$dest]:-}" ] || continue
    target="$(readlink "$dest")" || return 1
    case "$target" in
      "$REPO_ROOT"/bin/*)
        case "$dest$target" in *$'\t'*|*$'\n'*) return 1 ;; esac
        printf '%s\tsymlink\t%s\n' "$dest" "$target" >> "$tmp" ;;
    esac
  done
  $SUDO install -m 600 "$tmp" "$BACKUP_DIR/symlinks.tsv" || return 1
  rm -f -- "$tmp"
}
restore_install_routing() {
  local dest kind prior current failed=0 tmp
  $SUDO test -f "$BACKUP_DIR/symlinks.tsv" || return 1
  tmp="$(mktemp)" || return 1
  chmod 600 "$tmp" || return 1
  $SUDO cat "$BACKUP_DIR/symlinks.tsv" > "$tmp" || { rm -f -- "$tmp"; return 1; }
  while IFS=$'\t' read -r dest kind prior; do
    case "$dest" in "$BIN_TARGET"/*) ;; *) failed=1; continue ;; esac
    if [ -L "$dest" ]; then
      current="$(readlink "$dest")" || { failed=1; continue; }
      case "$current" in "$REPO_ROOT"/bin/*) ;; "$prior") ;; *) failed=1; continue ;; esac
    elif [ -e "$dest" ]; then
      [ "$kind" = regular ] || failed=1
      continue
    fi
    case "$kind" in
      symlink) $SUDO ln -sfn -- "$prior" "$dest" || failed=1 ;;
      absent) [ ! -L "$dest" ] || $SUDO rm -f -- "$dest" || failed=1 ;;
      regular) { [ -e "$dest" ] && [ ! -L "$dest" ]; } || failed=1 ;;
      *) failed=1 ;;
    esac
  done < "$tmp"
  rm -f -- "$tmp"
  [ "$failed" -eq 0 ]
}
backup_install_crontab() {
  local tmp err
  tmp="$(mktemp)" || return 1
  err="$(mktemp)" || return 1
  if crontab -l > "$tmp" 2>"$err"; then
    $SUDO install -m 600 "$tmp" "$BACKUP_DIR/crontab" || return 1
  elif grep -qi '^no crontab for ' "$err"; then
    $SUDO touch "$BACKUP_DIR/crontab.absent" || return 1
  else
    rm -f -- "$tmp" "$err"
    return 1
  fi
  rm -f -- "$tmp" "$err"
}
restore_install_crontab() {
  local tmp
  strip_managed_cron() {
    awk -v bw="$REPO_ROOT/bin/ai-blocker-watch" \
        -v reap="$REPO_ROOT/bin/ai-reap-shared-db-worktrees" '
      index($0,"# ai-devops blocker-watch (managed by ai-blocker-watch schedule") == 0 &&
      index($0,"# ai-devops worktree-reap (managed by ai-reap-shared-db-worktrees schedule") == 0 &&
      index($0,"\047" bw "\047 tick") == 0 &&
      index($0,"\047" reap "\047 run") == 0 { print }
    '
  }
  if $SUDO test -f "$BACKUP_DIR/crontab"; then
    tmp="$(mktemp)" || return 1
    chmod 600 "$tmp" || return 1
    $SUDO cat "$BACKUP_DIR/crontab" > "$tmp" || { rm -f -- "$tmp"; return 1; }
    cmp -s <(strip_managed_cron < "$tmp") \
      <(crontab -l 2>/dev/null | strip_managed_cron) || { rm -f -- "$tmp"; return 1; }
    crontab "$tmp"
    local rc=$?
    rm -f -- "$tmp"
    return "$rc"
  elif $SUDO test -f "$BACKUP_DIR/crontab.absent"; then
    # Remove only the two installer-owned entries; retain anything another
    # actor added during this attempt.
    [ -z "$(crontab -l 2>/dev/null | strip_managed_cron)" ] || return 1
    "$REPO_ROOT/bin/ai-blocker-watch" unschedule &&
      "$REPO_ROOT/bin/ai-reap-shared-db-worktrees" unschedule
  else
    return 1
  fi
}
backup_private_checkout() {
  PRIVATE_ROOT="$HOME/.local/share/ai-devops-private-config"
  if [ -d "$PRIVATE_ROOT/.git" ]; then
    [ -z "$(git -C "$PRIVATE_ROOT" status --porcelain)" ] || return 1
    "$REPO_ROOT/bin/ai-private-config" doctor >/dev/null || return 1
    git -C "$PRIVATE_ROOT" rev-parse HEAD | $SUDO tee "$BACKUP_DIR/private-head" >/dev/null
  else
    $SUDO touch "$BACKUP_DIR/private.absent"
  fi
}
restore_private_checkout() {
  local prior current
  if $SUDO test -f "$BACKUP_DIR/private.absent"; then
    # A first-time clone is retained for inspection; no prior commit existed.
    return 0
  fi
  $SUDO test -f "$BACKUP_DIR/private-head" || return 1
  prior="$($SUDO cat "$BACKUP_DIR/private-head")"
  [ -d "$PRIVATE_ROOT/.git" ] && [ -z "$(git -C "$PRIVATE_ROOT" status --porcelain)" ] || return 1
  "$REPO_ROOT/bin/ai-private-config" doctor >/dev/null || return 1
  current="$(git -C "$PRIVATE_ROOT" rev-parse HEAD)" || return 1
  [ "$current" = "$prior" ] && return 0
  git -C "$PRIVATE_ROOT" merge-base --is-ancestor "$prior" "$current" || return 1
  git -C "$PRIVATE_ROOT" -c core.hooksPath=/dev/null reset --hard "$prior" >/dev/null
}
backup_reviewer_hook() {
  local common
  common="$(git -C "$REPO_ROOT" rev-parse --path-format=absolute --git-common-dir)" || return 1
  HOOK_TARGET="$common/hooks/post-merge"
  [ ! -L "$HOOK_TARGET" ] || { warn 'refusing symlinked reviewer hook'; return 1; }
  if [ -f "$HOOK_TARGET" ]; then
    $SUDO cp -p "$HOOK_TARGET" "$BACKUP_DIR/post-merge" || return 1
    if grep -q '^# ai-devops-managed: reviewer auto-requalification' "$HOOK_TARGET"; then
      $SUDO touch "$BACKUP_DIR/post-merge.managed"
    else
      $SUDO touch "$BACKUP_DIR/post-merge.foreign"
    fi
  elif [ -e "$HOOK_TARGET" ]; then
    warn 'reviewer hook path is not a regular file'; return 1
  else
    $SUDO touch "$BACKUP_DIR/post-merge.absent"
  fi
}
restore_reviewer_hook() {
  local prior_mode current_mode
  [ ! -L "$HOOK_TARGET" ] || return 1
  if $SUDO test -f "$BACKUP_DIR/post-merge.absent"; then
    [ ! -e "$HOOK_TARGET" ] && return 0
    [ -f "$HOOK_TARGET" ] && cmp -s "$REPO_ROOT/hooks/post-merge" "$HOOK_TARGET" || return 1
    $SUDO rm -f -- "$HOOK_TARGET"
  elif $SUDO test -f "$BACKUP_DIR/post-merge.foreign"; then
    [ -f "$HOOK_TARGET" ] || return 1
    $SUDO cmp -s "$BACKUP_DIR/post-merge" "$HOOK_TARGET" || return 1
    prior_mode="$($SUDO stat -c %a "$BACKUP_DIR/post-merge")"
    current_mode="$(stat -c %a "$HOOK_TARGET")"
    [ "$prior_mode" = "$current_mode" ]
  elif $SUDO test -f "$BACKUP_DIR/post-merge.managed"; then
    [ -f "$HOOK_TARGET" ] || return 1
    if $SUDO cmp -s "$BACKUP_DIR/post-merge" "$HOOK_TARGET"; then
      prior_mode="$($SUDO stat -c %a "$BACKUP_DIR/post-merge")"
      current_mode="$($SUDO stat -c %a "$HOOK_TARGET")"
      [ "$prior_mode" = "$current_mode" ] && return 0
    fi
    cmp -s "$REPO_ROOT/hooks/post-merge" "$HOOK_TARGET" || return 1
    $SUDO cp -p "$BACKUP_DIR/post-merge" "$HOOK_TARGET"
  else
    return 1
  fi
}
backup_protected_config || {
  warn 'protected config backup failed; installation did not start'
  exit 1
}
backup_install_routing && backup_install_crontab && backup_private_checkout &&
  backup_reviewer_hook || {
  warn 'installed routing or protected source backup failed; installation did not start'
  exit 1
}
restore_install_state() {
  local failed=0
  restore_protected_config || failed=1
  restore_install_routing || failed=1
  restore_install_crontab || failed=1
  restore_private_checkout || failed=1
  restore_reviewer_hook || failed=1
  [ "$failed" -eq 0 ] || warn "installation rollback needs repair from $BACKUP_DIR"
  [ "$failed" -eq 0 ]
}
record_restored_state() {
  [ "${SOURCE_ROLLBACK_SAFE:-0}" = 1 ] || return 0
  [ "${AI_DEVOPS_INSTALL_LOCK_FD:-}" = 9 ] || return 0
  [ -n "${AI_DEVOPS_INSTALL_ROLLBACK_PROOF_FILE:-}" ] || return 0
  [ -f "$AI_DEVOPS_INSTALL_ROLLBACK_PROOF_FILE" ] &&
    [ ! -L "$AI_DEVOPS_INSTALL_ROLLBACK_PROOF_FILE" ] || return 1
  printf '%s\n' "$target_head" > "$AI_DEVOPS_INSTALL_ROLLBACK_PROOF_FILE"
}
invalidate_stage_marker() {
  local marker="$HOME/.local/state/ai-devops/task-gates/install-stages/$target_head.json"
  [ ! -L "$marker" ] || { warn 'refusing symlinked installation stage marker'; return 1; }
  [ -e "$marker" ] || return 0
  [ -f "$marker" ] && [ "$(stat -c %u "$marker")" = "$(id -u)" ] &&
    [ "$(stat -c %a "$marker")" = 600 ] || {
      warn 'refusing malformed installation stage marker'; return 1;
    }
  jq -e --arg target "$target_head" --arg checkout "$REPO_ROOT" \
    '.schema_version==1 and .target_head==$target and .installed_checkout==$checkout' \
    "$marker" >/dev/null 2>&1 || {
      warn 'installation stage marker belongs to another transaction'; return 1;
    }
  rm -f -- "$marker"
}
restore_failed_install() {
  # A prior completed attempt can leave a stage marker while a direct retry
  # re-runs stages. Remove only this transaction's verified marker before
  # restoring its older manifest; otherwise resume would reject the mismatch.
  invalidate_stage_marker || {
    warn 'installation stage marker needs manual repair; target remains pending'
    return 1
  }
  if restore_install_state; then record_restored_state || true; return 0; fi
  return 1
}
SOURCE_ROLLBACK_SAFE=1

install_dependencies() {
  local apt_packages=(git curl jq ripgrep unzip python3 python3-pip gh tar)
  local missing=() command_name
  for command_name in git curl jq rg unzip python3 pip3 gh tar; do
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
  require_commands git curl jq rg unzip python3 pip3 gh tar
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
  # The example names the server layout (/worksp/ai-devops). A machine with the
  # checkout elsewhere (e.g. ~/repos on a desktop) records where it really is.
  local home
  home="$(. "$ETC_DIR/server.env" 2>/dev/null; echo "${AI_DEVOPS_HOME:-}")"
  if [ ! -d "$home" ] && [ "$home" != "$REPO_ROOT" ]; then
    info "AI_DEVOPS_HOME $home does not exist; recording $REPO_ROOT"
    $SUDO sed -i "s#^AI_DEVOPS_HOME=.*#AI_DEVOPS_HOME=\"$REPO_ROOT\"#" "$ETC_DIR/server.env" || return 1
  fi
}
run_stage required "Configuration seed" install_configs
migrate_configuration() {
  local source_sha
  source_sha="$(git -C "$REPO_ROOT" rev-parse HEAD)" || return 1
  $SUDO "$REPO_ROOT/bin/ai-config-migrate" --repo-root "$REPO_ROOT" --config-dir "$ETC_DIR" --source-sha "$source_sha"
}
run_stage required "Configuration migration and validation" migrate_configuration

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
# 4.1 Reviewer auto-requalification post-merge hook (#804). Pulling new
#     reviewer wrapper code invalidates the affected reviewer's live
#     qualification; without this hook it stays quarantined until a person
#     re-qualifies by hand. bin/ai-install-post-merge-hook owns the marker
#     rules (foreign hooks are never touched) so both installers and
#     uninstall.sh share one implementation.
# --------------------------------------------------------------------------
run_stage required "Reviewer auto-requalification hook" "$REPO_ROOT/bin/ai-install-post-merge-hook"

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
# Skills are copied into two user homes and have their own backup semantics.
# The checkout cannot safely rewind after this point without proving every
# copied byte and permission. Leave the target pending for explicit repair.
SOURCE_ROLLBACK_SAFE=0
run_stage required "Claude and Codex skills" "$REPO_ROOT/bin/ai-install-skills"

# Machine topology and provider identifiers are restored from the protected
# configuration repository before any generated config consumes them.
run_stage required "Protected machine configuration" "$REPO_ROOT/bin/ai-private-config" sync

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
# 4.8 Claude closeout (completion-check) hook. The Stop hook is what makes a
#     session that ends on waiting language hold an `ai-blocker-watch wait`;
#     without it that rule is honor-system only (issue #878: edge-dev3 had no
#     hook and a session skipped BlockerWatch registration). Idempotent and
#     strictly additive to ~/.claude/settings.json.
# --------------------------------------------------------------------------
run_stage required "Claude closeout hook" "$REPO_ROOT/bin/ai-install-completion-check-hook" --client claude

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
# Desktop GUI apps (Claude Desktop, ChatGPT/Codex). Skips any app not installed
# and does nothing without the catalog the secrets stage writes.
run_stage optional "Desktop app MCP wiring" "$REPO_ROOT/bin/setup-desktop-apps.sh"

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

# --------------------------------------------------------------------------
# 4c-b. Blocker watch scheduling (#549). A waiting session is only woken by a
#     machine that runs `ai-blocker-watch tick`, so every agent machine gets
#     the schedule from its installer: a marked, idempotent USER crontab entry
#     here, the Scheduled Task on Windows (bin/install-ai-devops-windows.ps1
#     runs the same `schedule` command). Optional on purpose — a machine with
#     neither crontab nor schtasks still installs everything else, and reruns
#     are safe. Exactly one machine ALSO propagates blocker comments; that is
#     decided by propagate_on_host in config/blocker-watch.json, never by this
#     stage, so every machine can run this installer without double-posting.
#     (Unlike ai-memory-sync's cron above, this does not wait for Ansible:
#     wakes are needed on EVERY machine that runs sessions, including the
#     Windows boxes Ansible does not manage.)
# --------------------------------------------------------------------------
run_stage optional "Blocker watch scheduling" "$REPO_ROOT/bin/ai-blocker-watch" schedule

# Optional: retire shared-db worktrees whose pull requests already merged.
# Same shape as the blocker-watch stage — one marked, idempotent `schedule`
# command per platform. Machines with no shared-db checkout schedule the sweep
# anyway; the run itself exits 0 with "nothing to reap" until one appears.
run_stage optional "Shared-db worktree reap scheduling" "$REPO_ROOT/bin/ai-reap-shared-db-worktrees" schedule

publish_install_manifest() {
  local source_sha staged owner group
  source_sha="$(git -C "$REPO_ROOT" rev-parse HEAD)" || return 1
  staged="$(mktemp)" || return 1
  owner="$(id -un)"; group="$(id -gn)"
  "$REPO_ROOT/bin/ai-install-manifest" --repo-root "$REPO_ROOT" --config-dir "$ETC_DIR" \
    --bin-target "$BIN_TARGET" --home "$HOME" --source-sha "$source_sha" --output "$staged" || {
      rm -f "$staged"; return 1;
    }
  $SUDO install -o "$owner" -g "$group" -m 600 "$staged" "$ETC_DIR/install-manifest.tsv" || {
    rm -f "$staged"; return 1;
  }
  rm -f "$staged"
}
run_stage required "Managed artifact manifest" publish_install_manifest

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
  run_stage required "Protected Muse review profile" \
    "$REPO_ROOT/bin/setup-opencode-muse.sh"
else
  stage_results+=("SKIP\toptional\tOpenCode GLM server (no protected token)")
  stage_results+=("SKIP\toptional\tProtected Muse review profile (OpenCode unavailable)")
  info "  No 1Password service-account token yet — skipping. Run: setup-opencode-glm.sh"
fi

# Muse key store: every machine gets the protected per-user copy of the Muse
# key automatically, so review turns do not depend on 1Password. Idempotent:
# a valid store is left alone. The key moves op -> ai-muse -> file inside one
# process; it never appears in argv or in this installer's output.
if [ "$(id -u)" -eq 0 ]; then
  stage_results+=("SKIP\toptional\tMuse key store (root install)")
elif ! command -v op >/dev/null 2>&1; then
  stage_results+=("SKIP\toptional\tMuse key store (1Password CLI not on PATH)")
elif [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ ! -s "$HOME/.config/ai-devops/op-service-account" ]; then
  stage_results+=("SKIP\toptional\tMuse key store (no 1Password service-account token yet)")
else
  # Hand op the protected service-account token and no terminal: without a
  # token, an interactive op offers to add a personal 1Password account, which
  # this setup never uses.
  muse_key_store() {
    local token="${OP_SERVICE_ACCOUNT_TOKEN:-}"
    [ -n "$token" ] || token="$(cat "$HOME/.config/ai-devops/op-service-account")"
    OP_SERVICE_ACCOUNT_TOKEN="$token" AI_MUSE_CALLER=installer \
      "$REPO_ROOT/bin/ai-muse" store-key --if-missing </dev/null
  }
  run_stage optional "Muse key store" muse_key_store
fi

# StepFun key store (Linux only; StepCode has no Windows build yet). Same
# pattern as the Muse store: op -> ai-stepfun -> owner-only file, never argv.
if [ "$(uname -s)" != Linux ] || [ "$(id -u)" -eq 0 ]; then
  stage_results+=("SKIP\toptional\tStepFun key store (Linux user install only)")
elif ! command -v op >/dev/null 2>&1; then
  stage_results+=("SKIP\toptional\tStepFun key store (1Password CLI not on PATH)")
elif [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ ! -s "$HOME/.config/ai-devops/op-service-account" ]; then
  stage_results+=("SKIP\toptional\tStepFun key store (no 1Password service-account token yet)")
else
  stepfun_key_store() {
    local token="${OP_SERVICE_ACCOUNT_TOKEN:-}"
    [ -n "$token" ] || token="$(cat "$HOME/.config/ai-devops/op-service-account")"
    OP_SERVICE_ACCOUNT_TOKEN="$token" "$REPO_ROOT/bin/ai-stepfun" store-key --if-missing </dev/null
  }
  run_stage optional "StepFun key store" stepfun_key_store
fi

# Qwen reviews read only this owner-protected store. Resolve its managed
# 1Password reference during installation, never inside a provider turn.
if [ "$(id -u)" -eq 0 ]; then
  stage_results+=("SKIP\toptional\tQwen key store (root install)")
elif ! command -v op >/dev/null 2>&1; then
  stage_results+=("SKIP\toptional\tQwen key store (1Password CLI not on PATH)")
elif [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ ! -s "$HOME/.config/ai-devops/op-service-account" ]; then
  stage_results+=("SKIP\toptional\tQwen key store (no 1Password service-account token yet)")
else
  qwen_key_store() {
    local token="${OP_SERVICE_ACCOUNT_TOKEN:-}"
    [ -n "$token" ] || token="$(cat "$HOME/.config/ai-devops/op-service-account")"
    OP_SERVICE_ACCOUNT_TOKEN="$token" "$REPO_ROOT/bin/ai-qwen" store-key --if-missing </dev/null
  }
  run_stage optional "Qwen key store" qwen_key_store
fi

# DeepSeek provider turns read only this protected store. A missing store
# leaves formal reviews unavailable until this explicit install-time refresh.
if [ "$(id -u)" -eq 0 ]; then
  stage_results+=("SKIP\toptional\tDeepSeek key store (root install)")
elif ! command -v op >/dev/null 2>&1; then
  stage_results+=("SKIP\toptional\tDeepSeek key store (1Password CLI not on PATH)")
elif [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ ! -s "$HOME/.config/ai-devops/op-service-account" ]; then
  stage_results+=("SKIP\toptional\tDeepSeek key store (no 1Password service-account token yet)")
else
  deepseek_key_store() {
    local token="${OP_SERVICE_ACCOUNT_TOKEN:-}"
    [ -n "$token" ] || token="$(cat "$HOME/.config/ai-devops/op-service-account")"
    OP_SERVICE_ACCOUNT_TOKEN="$token" "$REPO_ROOT/bin/ai-deepseek-agent" store-key --if-missing </dev/null
  }
  run_stage optional "DeepSeek key store" deepseek_key_store
fi

# Muse Code on Linux: when the pinned binary is absent, run Meta's official
# installer (Albert approved automatic install, 2026-09-25), then verify the
# pinned version and SHA-256. ai-muse runs only that hashed file.
if [ "$(uname -s)" = Linux ] && [ "$(id -u)" -ne 0 ]; then
  install_muse_code_linux() {
    local pin="$REPO_ROOT/config/muse-code/linux-$(uname -m)" ver want bin
    [ -f "$pin/version" ] || { echo "no Muse Code pin for $(uname -m)"; return 1; }
    ver="$(tr -d ' \r\n' < "$pin/version")"; want="$(tr -d ' \r\n' < "$pin/sha256")"; bin="$HOME/.local/bin/muse-bin-$ver"
    if [ ! -f "$bin" ]; then
      local script; script="$(mktemp)" || return 1
      curl -fsSL https://dev.meta.ai/install.sh -o "$script" </dev/null && bash "$script" </dev/null >/dev/null
      local rc=$?; rm -f -- "$script"; [ "$rc" -eq 0 ] || { echo "Meta's Muse Code installer failed"; return 1; }
    fi
    [ -f "$bin" ] || { echo "Meta installed a different Muse Code than the pinned $ver; re-pin $pin"; return 1; }
    [ "$(sha256sum "$bin" | cut -d' ' -f1)" = "$want" ] || { echo "Muse Code $ver does not match the pinned SHA-256"; return 1; }
  }
  run_stage optional "Muse Code (Linux)" install_muse_code_linux
fi

# Reviewer provider CLIs (Grok Build, Kimi Code, Qwen Code, Antigravity for Gemini, and StepCode on Linux). Per-user and
# idempotent: current installs are skipped. Sign-in stays manual.
if [ "$(id -u)" -eq 0 ]; then
  stage_results+=("SKIP\toptional\tReviewer provider CLIs (root install)")
else
  install_provider_clis() { "$REPO_ROOT/bin/install-ai-provider-clis.sh" </dev/null; }
  run_stage optional "Reviewer provider CLIs" install_provider_clis
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
# A reviewer whose wrapper changed must be qualified before the pending
# installation authority is consumed. This also runs on a direct retry after
# an interrupted or failed update.
run_stage required "Reviewer requalification" "$REPO_ROOT/bin/ai-review-preflight" requalify

echo
if ! print_summary; then
  restore_failed_install || true
  exit 1
fi
# Publish the exact stage results in protected local state. The gate binds
# this report to the transaction before finalize can consume it.
publish_stage_report || {
  restore_failed_install || true
  warn 'stage result report could not be published; authorization remains pending'
  exit 1
}
(cd "$REPO_ROOT" && "$REPO_ROOT/bin/ai-task-gates" install-verify --phase stages-complete \
  --target-head "$target_head" --installed-checkout "$REPO_ROOT" \
  --installed-launcher /usr/local/bin/ai-task-gates --stage-report "$STAGE_REPORT") || {
    restore_failed_install || true
    warn 'installation stage receipt refused; authorization remains pending for repair'
    exit 1
  }
if [ "${AI_DEVOPS_INSTALL_DEFER_FINALIZE:-0}" != 1 ]; then
  (cd "$REPO_ROOT" && "$REPO_ROOT/bin/ai-task-gates" install-verify --phase finalize \
    --target-head "$target_head" --installed-checkout "$REPO_ROOT" \
  --installed-launcher /usr/local/bin/ai-task-gates) || {
    # Required stages and their protected receipt succeeded. Keep their
    # coherent target state for a direct retry of finalize; restoring only a
    # subset now would invalidate the stage receipt and strand the transaction.
    warn 'installation finalization refused; target remains pending for direct retry'
    exit 1
  }
fi
info "install.sh complete. source=$target_head"
