#!/usr/bin/env bash
# update.sh — pull the latest toolkit and re-install.
#
#   - git pull (fast-forward) inside /worksp/ai-devops
#   - re-run install.sh
#   - re-qualify any reviewer whose wrapper, runtime, or preloader changed
#     in the pull (#804); a failed requalification is recorded with
#     ai-reviewer-issue and fails this script, never silently skipped
#   - never overwrites /etc/ai-devops/*.env (install.sh handles that)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info() { printf '\033[1m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$1"; }

cd "$REPO_ROOT" || { echo "Cannot cd to $REPO_ROOT" >&2; exit 1; }

if [ -d .git ]; then
  info "Pulling latest changes in $REPO_ROOT"
  # Hooks stay disabled for this pull on purpose: the post-merge reviewer
  # hook would requalify against the OLD checkout mid-update, and a failed
  # canary would read as a pull failure before install.sh ever ran. The
  # explicit requalify below is the one gate for this update.
  empty_hooks="$(mktemp -d)"
  if ! git -c core.hooksPath="$empty_hooks" pull --ff-only; then
    rmdir "$empty_hooks" 2>/dev/null || true
    warn "git pull --ff-only failed (local changes or diverged history)."
    warn "Resolve manually, then re-run ./update.sh"
    exit 1
  fi
  rmdir "$empty_hooks" 2>/dev/null || true
else
  warn "$REPO_ROOT is not a git checkout; skipping pull."
fi

info "Re-running install.sh"
source_sha="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
if ! "$REPO_ROOT/install.sh" "$@"; then
  warn "update.sh failed while installing source SHA $source_sha"
  exit 1
fi

# The pull above ran with the previously installed post-merge hook (or none,
# on the first update after #804), so re-qualify explicitly here too. On a
# host with no live-qualification records this is a no-op.
info "Re-qualifying reviewers whose qualification the pull invalidated"
if ! "$REPO_ROOT/bin/ai-review-preflight" requalify; then
  warn "automatic reviewer requalification failed for source SHA $source_sha; it is recorded as a reviewer issue"
  exit 1
fi
info "update.sh installed source SHA $source_sha"
