#!/usr/bin/env bash
# update.sh — pin, authorize, fast-forward, install, and re-qualify the toolkit.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info() { printf '\033[1m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$1"; }

expected_head=""
install_args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --expected-head)
      [ "$#" -ge 2 ] || { warn '--expected-head needs a full commit SHA'; exit 2; }
      expected_head="$2"; shift 2 ;;
    --require-secrets|--skip-secrets) install_args+=("$1"); shift ;;
    -h|--help)
      echo 'usage: ./update.sh [--expected-head FULL_SHA] [--require-secrets|--skip-secrets]'
      exit 0 ;;
    *) warn "unknown option: $1"; exit 2 ;;
  esac
done
if [ -n "$expected_head" ] && ! [[ "$expected_head" =~ ^[0-9a-f]{40}$ ]]; then
  warn '--expected-head must be a full lowercase commit SHA'; exit 2
fi

cd "$REPO_ROOT" || exit 1
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { warn 'not a Git checkout'; exit 1; }
# One lock spans fetch, candidate preflight, checkout advance, installation,
# requalification, and finalization. The child installer checks this exact fd.
install_lock_dir="$HOME/.local/state/ai-devops/task-gates"
install_lock_name="install-$(printf '%s' "$REPO_ROOT" | sha256sum | cut -c1-16).lock"
umask 077
mkdir -p "$install_lock_dir" || exit 1
install_lock_file="$install_lock_dir/$install_lock_name"
exec 9>"$install_lock_file" || exit 1
flock -n 9 || { warn 'another installation is active for this checkout'; exit 1; }
if [ -n "$(git status --porcelain)" ]; then
  warn 'checkout has local changes; preserve and reconcile them before updating'
  exit 1
fi
previous_head="$(git rev-parse HEAD)" || exit 1
branch="$(git symbolic-ref --short -q HEAD || true)"
remote=origin; remote_ref=refs/heads/main
if [ -n "$branch" ]; then
  remote="$(git config "branch.$branch.remote" || printf origin)"
  remote_ref="$(git config "branch.$branch.merge" || printf refs/heads/main)"
fi
case "$remote" in ''|.|*' '*|*'/'*|*'..'*) warn 'unsafe upstream remote'; exit 1 ;; esac
case "$remote_ref" in refs/heads/*) ;; *) warn 'unsafe upstream ref'; exit 1 ;; esac

# Fetching objects does not alter the installed checkout. The target code runs
# from an isolated candidate; only its successful preflight permits advancement.
info "Fetching $remote ${remote_ref#refs/heads/}"
git fetch --no-tags "$remote" "$remote_ref" || exit 1
target_head="$(git rev-parse FETCH_HEAD)" || exit 1
[ -z "$expected_head" ] || [ "$target_head" = "$expected_head" ] || {
  warn 'fetched target differs from the explicitly approved commit'; exit 1;
}
git merge-base --is-ancestor "$previous_head" "$target_head" || {
  warn 'target is not a fast-forward of the installed checkout'; exit 1;
}

candidate_parent="$(mktemp -d)" || exit 1
hooks_dir="$(mktemp -d)" || exit 1
candidate="$candidate_parent/candidate"
candidate_added=0
proof_file=""
cleanup() {
  if [ "$candidate_added" -eq 1 ]; then git worktree remove --force "$candidate" >/dev/null 2>&1 || true; fi
  [ -z "$proof_file" ] || rm -f -- "$proof_file"
  rmdir "$candidate_parent" "$hooks_dir" 2>/dev/null || true
}
trap cleanup EXIT
git -c core.hooksPath="$hooks_dir" worktree add --detach "$candidate" "$target_head" >/dev/null || exit 1
candidate_added=1
gate_args=(install-verify --phase preflight --target-head "$target_head"
  --installed-checkout "$REPO_ROOT" --installed-launcher /usr/local/bin/ai-task-gates)
[ -z "$expected_head" ] || gate_args+=(--caller-pinned)
"$candidate/bin/ai-task-gates" "${gate_args[@]}" || {
  warn 'installation preflight refused; installed checkout was not advanced'
  exit 1
}
git worktree remove --force "$candidate" >/dev/null || exit 1
candidate_added=0

info "Advancing installed checkout to $target_head"
if [ -n "$branch" ]; then
  git -c core.hooksPath="$hooks_dir" merge --ff-only "$target_head" || exit 1
else
  git -c core.hooksPath="$hooks_dir" checkout --detach "$target_head" || exit 1
fi
[ "$(git rev-parse HEAD)" = "$target_head" ] || { warn 'checkout moved to an unexpected commit'; exit 1; }

info 'Re-running install.sh'
source_sha="$target_head"
proof_file="$(mktemp "$install_lock_dir/rollback.XXXXXXXX")" || exit 1
rollback_checkout() {
  [ -z "$(git status --porcelain)" ] || { warn 'checkout has new local edits; automatic source rollback refused'; return 1; }
  [ "$(git rev-parse HEAD)" = "$target_head" ] || { warn 'checkout moved during install; automatic source rollback refused'; return 1; }
  git -c core.hooksPath="$hooks_dir" checkout --detach "$previous_head" >/dev/null || return 1
  [ "$(git rev-parse HEAD)" = "$previous_head" ] && [ -z "$(git status --porcelain)" ]
}
if ! AI_DEVOPS_INSTALL_LOCK_FD=9 AI_DEVOPS_INSTALL_LOCK_PARENT="$$" \
  AI_DEVOPS_INSTALL_DEFER_FINALIZE=1 AI_DEVOPS_INSTALL_ROLLBACK_PROOF_FILE="$proof_file" \
  "$REPO_ROOT/install.sh" "${install_args[@]}"; then
  warn "update.sh failed while installing source SHA $source_sha"
  if [ "$(cat "$proof_file")" = "$target_head" ] && rollback_checkout; then
    warn "restored prior checkout SHA $previous_head; authorization remains pending for safe retry"
  else
    warn "checkout remains at $target_head or needs repair; authorization remains pending"
  fi
  exit 1
fi

# The checkout pull runs with hooks disabled. Requalification happens once,
# after installation, and remains required before authorization is consumed.
info 'Re-qualifying reviewers whose qualification the update invalidated'
if ! "$REPO_ROOT/bin/ai-review-preflight" requalify; then
  warn "automatic reviewer requalification failed for source SHA $source_sha; it is recorded as a reviewer issue"
  exit 1
fi
"$REPO_ROOT/bin/ai-task-gates" install-verify --phase finalize \
  --target-head "$target_head" --installed-checkout "$REPO_ROOT" \
  --installed-launcher /usr/local/bin/ai-task-gates || {
  warn 'installation finalization refused; authorization remains pending for safe retry'
  exit 1
}
info "update.sh installed source SHA $source_sha"
