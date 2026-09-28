#!/usr/bin/env bash
# update.sh — pin, authorize, fast-forward, install, and re-qualify the toolkit.
set -uo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info() { printf '\033[1m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$1"; }

expected_head=""
installed_checkout=""
owner_request=""
install_args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --expected-head)
      [ "$#" -ge 2 ] || { warn '--expected-head needs a full commit SHA'; exit 2; }
      expected_head="$2"; shift 2 ;;
    --installed-checkout)
      [ "$#" -ge 2 ] || { warn '--installed-checkout needs a path'; exit 2; }
      installed_checkout="$2"; shift 2 ;;
    --owner-request)
      [ "$#" -ge 2 ] && [ -n "$2" ] || { warn '--owner-request needs a reason'; exit 2; }
      owner_request="$2"; shift 2 ;;
    --require-secrets|--skip-secrets) install_args+=("$1"); shift ;;
    -h|--help)
      echo 'usage: ./update.sh [--installed-checkout PATH --expected-head FULL_SHA] [--owner-request TEXT] [--require-secrets|--skip-secrets]'
      exit 0 ;;
    *) warn "unknown option: $1"; exit 2 ;;
  esac
done
if [ -n "$expected_head" ] && ! [[ "$expected_head" =~ ^[0-9a-f]{40}$ ]]; then
  warn '--expected-head must be a full lowercase commit SHA'; exit 2
fi

REPO_ROOT="$SOURCE_ROOT"
if [ -n "$installed_checkout" ]; then
  [ -n "$expected_head" ] || { warn 'a candidate updater requires --expected-head'; exit 2; }
  REPO_ROOT="$(cd "$installed_checkout" 2>/dev/null && pwd -P)" || {
    warn 'installed checkout does not exist'; exit 1;
  }
  [ "$SOURCE_ROOT" != "$REPO_ROOT" ] || { warn 'candidate and installed checkout must differ'; exit 1; }
  source_top="$(git -C "$SOURCE_ROOT" rev-parse --show-toplevel 2>/dev/null)" || exit 1
  installed_top="$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null)" || exit 1
  [ "$source_top" = "$SOURCE_ROOT" ] && [ "$installed_top" = "$REPO_ROOT" ] || {
    warn 'candidate or installed path is not a Git worktree root'; exit 1;
  }
  source_common="$(git -C "$SOURCE_ROOT" rev-parse --path-format=absolute --git-common-dir)" || exit 1
  installed_common="$(git -C "$REPO_ROOT" rev-parse --path-format=absolute --git-common-dir)" || exit 1
  [ "$(realpath "$source_common")" = "$(realpath "$installed_common")" ] || {
    warn 'candidate does not share the installed checkout Git common directory'; exit 1;
  }
  [ -z "$(git -C "$SOURCE_ROOT" status --porcelain)" ] || {
    warn 'candidate checkout has local changes'; exit 1;
  }
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
if [ -n "$branch" ]; then
  [ "$branch" = main ] || { warn 'only main or a detached installed checkout may update'; exit 1; }
  configured_remote="$(git config branch.main.remote || true)"
  configured_ref="$(git config branch.main.merge || true)"
  [ -z "$configured_remote" ] || [ "$configured_remote" = origin ] || {
    warn 'main tracks an unsupported remote'; exit 1;
  }
  [ -z "$configured_ref" ] || [ "$configured_ref" = refs/heads/main ] || {
    warn 'main tracks an unsupported branch'; exit 1;
  }
fi

# Fetching objects does not alter the installed checkout. The target code runs
# from an isolated candidate; only its successful preflight permits advancement.
info 'Fetching origin main'
git fetch --atomic --no-tags origin \
  refs/heads/main:refs/remotes/origin/main || exit 1
target_head="$(git rev-parse refs/remotes/origin/main)" || exit 1
[ "$target_head" = "$(git rev-parse FETCH_HEAD)" ] || {
  warn 'fetched commit and origin/main differ'; exit 1;
}
[ -z "$installed_checkout" ] || [ "$(git -C "$SOURCE_ROOT" rev-parse HEAD)" = "$target_head" ] || {
  warn 'candidate checkout is not the exact fetched target'; exit 1;
}
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
[ -z "$owner_request" ] || gate_args+=(--owner-request "$owner_request")
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
  [ "$(git symbolic-ref --short -q HEAD || true)" = "$branch" ] || {
    warn 'checkout branch changed during install; automatic source rollback refused'; return 1;
  }
  if [ -n "$branch" ]; then
    git -c core.hooksPath="$hooks_dir" reset --hard "$previous_head" >/dev/null || return 1
  else
    git -c core.hooksPath="$hooks_dir" checkout --detach "$previous_head" >/dev/null || return 1
  fi
  [ "$(git rev-parse HEAD)" = "$previous_head" ] &&
    [ "$(git symbolic-ref --short -q HEAD || true)" = "$branch" ] &&
    [ -z "$(git status --porcelain)" ]
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

# install.sh ran reviewer requalification as a required stage before reporting
# success. Only now may the updater consume its pending authorization.
"$REPO_ROOT/bin/ai-task-gates" install-verify --phase finalize \
  --target-head "$target_head" --installed-checkout "$REPO_ROOT" \
  --installed-launcher /usr/local/bin/ai-task-gates || {
  warn 'installation finalization refused; authorization remains pending for safe retry'
  exit 1
}
info "update.sh installed source SHA $source_sha"
