#!/usr/bin/env bash
# Recoverable uninstall for artifacts recorded by install-manifest.tsv.
#
# Usage:
#   ./uninstall.sh --dry-run       # exact preview, writes nothing
#   ./uninstall.sh                 # minimal: remove owned command symlinks
#   ./uninstall.sh --purge         # minimal + archive and remove config
#   ./uninstall.sh --full          # archive config/repo, then remove both
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ETC_DIR="/etc/ai-devops"
BIN_TARGET="/usr/local/bin"
ARCHIVE_ROOT="$HOME/.local/state/ai-devops/uninstall"
DRY_RUN=0; PURGE=0; REMOVE_REPO=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --purge) PURGE=1; shift ;;
    --remove-repo) REMOVE_REPO=1; shift ;;
    --full) PURGE=1; REMOVE_REPO=1; shift ;;
    --repo-root) REPO_ROOT="$2"; shift 2 ;;
    --config-dir) ETC_DIR="$2"; shift 2 ;;
    --bin-target) BIN_TARGET="$2"; shift 2 ;;
    --archive-root) ARCHIVE_ROOT="$2"; shift 2 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
info() { printf '\033[1m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$1"; }

resolved_etc="$(realpath -m "$ETC_DIR")"
resolved_repo="$(realpath -m "$REPO_ROOT")"
resolved_bin="$(realpath -m "$BIN_TARGET")"
case "$resolved_etc" in /|"$HOME"|"$resolved_repo") echo "REFUSED unsafe config target: $resolved_etc" >&2; exit 1;; esac
case "$resolved_repo" in /|"$HOME"|/worksp) echo "REFUSED unsafe repo target: $resolved_repo" >&2; exit 1;; esac
case "$resolved_bin" in /|"$HOME") echo "REFUSED unsafe bin target: $resolved_bin" >&2; exit 1;; esac

manifest="$resolved_etc/install-manifest.tsv"
[ -f "$manifest" ] || { echo "REFUSED: managed artifact manifest missing at $manifest" >&2; exit 1; }
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
archive="$ARCHIVE_ROOT/$stamp"

if [ "$REMOVE_REPO" -eq 1 ]; then
  repo_status="$(git -C "$resolved_repo" status --porcelain 2>/dev/null)" || {
    echo 'REFUSED: repo state could not be inspected.' >&2; exit 1; }
  [ -z "$repo_status" ] || { echo 'REFUSED: repo has local changes or untracked files; preserve them first.' >&2; exit 1; }
fi

info "Mode: $(if [ "$REMOVE_REPO" -eq 1 ]; then echo full; elif [ "$PURGE" -eq 1 ]; then echo purge; else echo minimal; fi) dry_run=$DRY_RUN"
while IFS=$'\t' read -r type path source hash; do
  [ "$type" = symlink ] || continue
  resolved_path="$(realpath -m "$(dirname "$path")")/$(basename "$path")"
  case "$resolved_path" in "$resolved_bin"/*) ;; *) echo "REFUSED manifest path outside bin target: $path" >&2; exit 1;; esac
  if [ -L "$path" ]; then
    actual="$(readlink -f "$path" 2>/dev/null || true)"
    expected="$(readlink -f "$source" 2>/dev/null || true)"
    if [ "$actual" = "$expected" ] && [ "$(sha256sum "$source" 2>/dev/null | cut -d' ' -f1)" = "$hash" ]; then
      echo "REMOVE owned symlink $path -> $source"
      [ "$DRY_RUN" -eq 1 ] || rm -f -- "$path" || exit 1
    else
      warn "PRESERVE drifted symlink $path"
    fi
  fi
done < "$manifest"

if [ "$PURGE" -eq 1 ]; then
  echo "ARCHIVE config $resolved_etc -> $archive/etc-ai-devops.tar.gz"
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$archive" || exit 1; chmod 700 "$ARCHIVE_ROOT" "$archive" 2>/dev/null || exit 1
    tar -czf "$archive/etc-ai-devops.tar.gz" -C "$(dirname "$resolved_etc")" "$(basename "$resolved_etc")" || exit 1
    tar -tzf "$archive/etc-ai-devops.tar.gz" >/dev/null || exit 1
    sha256sum "$archive/etc-ai-devops.tar.gz" > "$archive/etc-ai-devops.tar.gz.sha256" || exit 1
    rm -rf -- "$resolved_etc" || exit 1
    info "Config archived and removed. Restore: tar -xzf '$archive/etc-ai-devops.tar.gz' -C '$(dirname "$resolved_etc")'"
  fi
else
  info "Keeping $resolved_etc"
fi

info 'Leaving Claude/Codex/gh auth and login state untouched.'
if [ "$REMOVE_REPO" -eq 1 ]; then
  echo "ARCHIVE repo refs -> $archive/ai-devops.bundle"
  echo "REMOVE repo $resolved_repo"
  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$archive" || exit 1; chmod 700 "$ARCHIVE_ROOT" "$archive" 2>/dev/null || exit 1
    git -C "$resolved_repo" bundle create "$archive/ai-devops.bundle" --all || exit 1
    git bundle verify "$archive/ai-devops.bundle" >/dev/null || exit 1
    cd / || exit 1
    rm -rf -- "$resolved_repo" || exit 1
  fi
else
  info "Keeping $resolved_repo"
fi
info 'uninstall.sh complete.'
