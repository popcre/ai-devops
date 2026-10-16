#!/usr/bin/env bash
# Shared Linux mutex for authenticated ai-glm clients and server maintenance.
# The lock file contains no data and is never removed: its inode is the mutex.

# Called only by the protected install/update transaction after finalization.
# Python independently validates the inherited real installer fd and source.
glm_formal_activation_publish() (
  local repo="$1"
  glm_maintenance_lock_acquire "$HOME/.config/ai-devops/glm-formal" exclusive \
    "${AI_GLM_MAINTENANCE_LOCK_TIMEOUT:-300}" || exit 1
  python3 "$repo/tools/glm_formal_profile.py" activate --repo "$repo"
)

glm_maintenance_lock_acquire() {
  local directory="${1:-}" mode="${2:-}" timeout="${3:-${AI_GLM_MAINTENANCE_LOCK_TIMEOUT:-300}}"
  local canonical dir_info dir_uid dir_gid lock_path created=0 before fd_info after dir_after fd
  local _dir_dev _dir_ino _dir_mode _lock_dev _lock_ino _lock_uid _lock_gid _lock_mode _lock_links _lock_size _lock_type
  local expected_uid expected_gid prior_umask had_noclobber

  case "$(uname -s 2>/dev/null || true)" in
    Linux) ;;
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 0 ;;
  esac
  case "$mode" in shared|exclusive) ;; *) printf 'ai-glm: invalid maintenance lock mode.\n' >&2; return 2 ;; esac
  case "$timeout" in ''|*[!0-9.]*|.*|*.) printf 'ai-glm: invalid maintenance lock timeout.\n' >&2; return 2 ;; esac
  [[ "$timeout" =~ ^[0-9]+([.][0-9]+)?$ ]] || { printf 'ai-glm: invalid maintenance lock timeout.\n' >&2; return 2; }
  awk -v seconds="$timeout" 'BEGIN { exit !(seconds >= 0 && seconds <= 300) }' || {
    printf 'ai-glm: maintenance lock timeout must be between 0 and 300 seconds.\n' >&2; return 2;
  }
  [[ "$directory" = /* && -d "$directory" && ! -L "$directory" ]] || {
    printf 'ai-glm: private OpenCode password directory is missing or unsafe.\n' >&2; return 1;
  }
  canonical="$(realpath -e -- "$directory" 2>/dev/null)" || return 1
  [[ "$canonical" = "$directory" ]] || { printf 'ai-glm: private OpenCode password path is not canonical.\n' >&2; return 1; }
  dir_info="$(stat -c '%d:%i:%u:%g:%a' -- "$directory" 2>/dev/null)" || return 1
  IFS=: read -r _dir_dev _dir_ino dir_uid dir_gid _dir_mode <<<"$dir_info"
  [[ "$_dir_mode" = 700 ]] || { printf 'ai-glm: private OpenCode password directory must be mode 0700.\n' >&2; return 1; }
  [[ "$(id -u)" = "$dir_uid" || "$(id -u)" = 0 ]] || { printf 'ai-glm: maintenance lock directory belongs to another user.\n' >&2; return 1; }

  # If a password is present, refuse unsafe ownership or path metadata before
  # taking a lock that would imply the authenticated client is safe to proceed.
  if [[ -e "$directory/server-password" || -L "$directory/server-password" ]]; then
    [[ -f "$directory/server-password" && ! -L "$directory/server-password" ]] || {
      printf 'ai-glm: server password path is not a regular file.\n' >&2; return 1;
    }
    local password_info password_uid password_mode password_links
    password_info="$(stat -c '%u:%a:%h' -- "$directory/server-password" 2>/dev/null)" || return 1
    IFS=: read -r password_uid password_mode password_links <<<"$password_info"
    [[ "$password_uid" = "$dir_uid" && "$password_mode" = 600 && "$password_links" = 1 ]] || {
      printf 'ai-glm: server password file has unsafe ownership or permissions.\n' >&2; return 1;
    }
  fi

  command -v flock >/dev/null 2>&1 || { printf 'ai-glm: flock is required for Linux service coordination.\n' >&2; return 1; }
  lock_path="$directory/maintenance.lock"
  if [[ ! -e "$lock_path" && ! -L "$lock_path" ]]; then
    prior_umask="$(umask)"
    case "$-" in *C*) had_noclobber=1 ;; *) had_noclobber=0 ;; esac
    umask 077
    set -o noclobber
    # O_EXCL prevents replacing a pre-existing leaf. The opened inode is checked
    # against the path again after it is opened and before any privileged repair.
    if ( umask 077; set -o noclobber; : > "$lock_path" ) 2>/dev/null; then created=1; fi
    [[ "$had_noclobber" = 1 ]] || set +o noclobber
    umask "$prior_umask"
  fi
  [[ -f "$lock_path" && ! -L "$lock_path" ]] || { printf 'ai-glm: maintenance lock path is missing or unsafe.\n' >&2; return 1; }
  before="$(stat -c '%d:%i:%u:%g:%a:%h:%s:%F' -- "$lock_path" 2>/dev/null)" || return 1
  IFS=: read -r _lock_dev _lock_ino _lock_uid _lock_gid _lock_mode _lock_links _lock_size _lock_type <<<"$before"
  [[ "$_lock_mode" = 600 && "$_lock_links" = 1 && "$_lock_size" = 0 && "$_lock_type" = 'regular empty file' ]] || {
    printf 'ai-glm: maintenance lock file has unsafe type, mode, links, or content.\n' >&2; return 1;
  }
  exec {fd}<> "$lock_path" || return 1
  fd_info="$(stat -Lc '%d:%i:%u:%g:%a:%h:%s:%F' -- "/proc/$$/fd/$fd" 2>/dev/null)" || { exec {fd}>&-; return 1; }
  [[ "$fd_info" = "$before" ]] || { exec {fd}>&-; printf 'ai-glm: maintenance lock path changed while opening.\n' >&2; return 1; }
  if [[ "$created" = 1 ]]; then
    expected_uid="$_lock_uid"; expected_gid="$_lock_gid"
    if [[ "$(id -u)" = 0 && ( "$dir_uid" != 0 || "$dir_gid" != "$_lock_gid" ) ]]; then
      # Root may attach to another user's server. Confirm the parent and pathname
      # still identify this exact root-created inode before changing its owner.
      [[ "$_lock_uid" = 0 ]] || { exec {fd}>&-; printf 'ai-glm: new maintenance lock is not root-owned before owner repair.\n' >&2; return 1; }
      dir_after="$(stat -c '%d:%i:%u:%g:%a' -- "$directory" 2>/dev/null)" || dir_after=''
      after="$(stat -c '%d:%i:%u:%g:%a:%h:%s:%F' -- "$lock_path" 2>/dev/null)" || after=''
      [[ "$dir_after" = "$dir_info" && "$after" = "$fd_info" && ! -L "$lock_path" ]] || {
        exec {fd}>&-; printf 'ai-glm: maintenance lock path changed before owner repair.\n' >&2; return 1;
      }
      chown "$dir_uid:$dir_gid" "/proc/$$/fd/$fd" 2>/dev/null || { exec {fd}>&-; return 1; }
      chmod 0600 "/proc/$$/fd/$fd" 2>/dev/null || { exec {fd}>&-; return 1; }
      expected_uid="$dir_uid"; expected_gid="$dir_gid"
    else
      [[ "$_lock_uid" = "$dir_uid" && "$_lock_gid" = "$dir_gid" ]] || {
        exec {fd}>&-; printf 'ai-glm: new maintenance lock has unexpected ownership.\n' >&2; return 1;
      }
    fi
  else
    [[ "$_lock_uid" = "$dir_uid" && "$_lock_gid" = "$dir_gid" ]] || {
      printf 'ai-glm: maintenance lock file has a foreign owner.\n' >&2; return 1;
    }
    expected_uid="$dir_uid"; expected_gid="$dir_gid"
  fi

  fd_info="$(stat -Lc '%d:%i:%u:%g:%a:%h:%s:%F' -- "/proc/$$/fd/$fd" 2>/dev/null)" || { exec {fd}>&-; return 1; }
  [[ "$_lock_dev:$_lock_ino:$expected_uid:$expected_gid:$_lock_mode:$_lock_links:$_lock_size:$_lock_type" = "$fd_info" ]] || {
    exec {fd}>&-; printf 'ai-glm: maintenance lock fd metadata changed during validation.\n' >&2; return 1;
  }
  before="$fd_info"
  dir_after="$(stat -c '%d:%i:%u:%g:%a' -- "$directory" 2>/dev/null)" || dir_after=''
  after="$(stat -c '%d:%i:%u:%g:%a:%h:%s:%F' -- "$lock_path" 2>/dev/null)" || after=''
  [[ "$dir_after" = "$dir_info" && "$after" = "$fd_info" && ! -L "$lock_path" ]] || {
    exec {fd}>&-; printf 'ai-glm: maintenance lock path changed during acquisition.\n' >&2; return 1;
  }

  if [[ "$mode" = shared ]]; then
    flock -s -w "$timeout" "$fd" || { exec {fd}>&-; printf 'ai-glm: service maintenance is in progress; retry after it finishes.\n' >&2; return 1; }
  else
    flock -x -w "$timeout" "$fd" || { exec {fd}>&-; printf 'ai-glm: another GLM client or maintenance action is active; retry after it finishes.\n' >&2; return 1; }
  fi

  dir_after="$(stat -c '%d:%i:%u:%g:%a' -- "$directory" 2>/dev/null)" || dir_after=''
  after="$(stat -c '%d:%i:%u:%g:%a:%h:%s:%F' -- "$lock_path" 2>/dev/null)" || after=''
  fd_info="$(stat -Lc '%d:%i:%u:%g:%a:%h:%s:%F' -- "/proc/$$/fd/$fd" 2>/dev/null)" || fd_info=''
  if [[ "$dir_after" != "$dir_info" || "$after" != "$before" || "$after" != "$fd_info" || -L "$lock_path" || \
        "$(stat -Lc '%u:%g:%a:%h:%s:%F' -- "/proc/$$/fd/$fd" 2>/dev/null)" != "$expected_uid:$expected_gid:600:1:0:regular empty file" ]]; then
    flock -u "$fd" 2>/dev/null || true
    exec {fd}>&-
    printf 'ai-glm: maintenance lock path changed during acquisition.\n' >&2
    return 1
  fi
}
