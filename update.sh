#!/usr/bin/env bash
# update.sh — pin, authorize, fast-forward, install, and re-qualify the toolkit.
set -uo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The protected updater is the only sanctioned advance of the installed checkout;
# the post-merge detector skips runs made with this set.
export AI_DEVOPS_PROTECTED_UPDATE=1
info() { printf '\033[1m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$1"; }
# Path identity (#1835): one shared helper, CR-safe and Windows-aware.
source "$SOURCE_ROOT/tools/lib/path-identity.sh"
same_path() { ai_same_path "$@"; }

expected_head=""
installed_checkout=""
owner_authorization=""
activate_glm_formal=0
activation_only=0
install_args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --expected-head)
      [ "$#" -ge 2 ] || { warn '--expected-head needs a full commit SHA'; exit 2; }
      expected_head="$2"; shift 2 ;;
    --installed-checkout)
      [ "$#" -ge 2 ] || { warn '--installed-checkout needs a path'; exit 2; }
      installed_checkout="$2"; shift 2 ;;
    --owner-authorization)
      [ "$#" -ge 2 ] && [ -n "$2" ] || { warn '--owner-authorization needs the owner authorization text'; exit 2; }
      owner_authorization="$2"; shift 2 ;;
    --activation-only) activation_only=1; shift ;;
    --activate-glm-formal) activate_glm_formal=1; install_args+=("$1"); shift ;;
    --require-secrets|--skip-secrets) install_args+=("$1"); shift ;;
    -h|--help)
      echo 'usage: ./update.sh [--installed-checkout PATH --expected-head FULL_SHA] [--require-secrets|--skip-secrets] [--activate-glm-formal [--activation-only --owner-authorization TEXT]]'
      exit 0 ;;
    *) warn "unknown option: $1"; exit 2 ;;
  esac
done
if [ "$activation_only" -eq 1 ] && [ "$(uname -s)" != Linux ]; then
  warn 'activation-only is a Linux formal-profile operation'; exit 2
fi
if [ "$activation_only" -eq 1 ] && { [ "$activate_glm_formal" -ne 1 ] || [ -z "$expected_head" ] || [ -z "$owner_authorization" ]; }; then
  warn '--activation-only requires --activate-glm-formal, --expected-head and --owner-authorization'; exit 2
fi
if [ "$activate_glm_formal" -eq 1 ]; then source "$SOURCE_ROOT/tools/lib/opencode-maintenance-lock.sh"; fi
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
  same_path "$source_top" "$SOURCE_ROOT" && same_path "$installed_top" "$REPO_ROOT" || {
    warn 'candidate or installed path is not a Git worktree root'; exit 1;
  }
  source_common="$(git -C "$SOURCE_ROOT" rev-parse --path-format=absolute --git-common-dir)" || exit 1
  installed_common="$(git -C "$REPO_ROOT" rev-parse --path-format=absolute --git-common-dir)" || exit 1
  same_path "$source_common" "$installed_common" || {
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
install_original_umask="$(umask)"
umask 077
mkdir -p "$install_lock_dir" || exit 1
install_lock_file="$install_lock_dir/$install_lock_name"
exec 9>"$install_lock_file" || exit 1
if command -v flock >/dev/null 2>&1; then
  flock -n 9 || { warn 'another installation is active for this checkout'; exit 1; }
else
  install_lock_fallback="${install_lock_file}.d"
  mkdir "$install_lock_fallback" 2>/dev/null || { warn 'another installation is active for this checkout'; exit 1; }
  trap 'rmdir -- "$install_lock_fallback" 2>/dev/null' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
fi
umask "$install_original_umask"
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

# Explicit same-release transaction: no fetch, source advance, reinstall,
# qualification turn, or recovery-marker manufacture. The original readiness
# deadline is consumed unchanged while the real fd9 install lock remains held.
if [ "$activation_only" -eq 1 ]; then
  [ "$previous_head" = "$expected_head" ] && [ "$(git -C "$SOURCE_ROOT" rev-parse HEAD)" = "$expected_head" ] || {
    warn 'activation-only requires the exact already installed source'; exit 1;
  }
  (cd "$SOURCE_ROOT" && "$SOURCE_ROOT/bin/ai-task-gates" check --before infrastructure \
    --acknowledge "$owner_authorization") || exit 1
  (cd "$SOURCE_ROOT" && "$SOURCE_ROOT/bin/ai-task-gates" install-verify --phase activation \
    --target-head "$expected_head" --installed-checkout "$REPO_ROOT" \
    --installed-launcher /usr/local/bin/ai-task-gates) || exit 1
  glm_formal_activation_publish "$REPO_ROOT" || exit 1
  info "Explicit activation completed at already installed source $expected_head"
  exit 0
fi

# Fetching objects does not alter the installed checkout. The target code runs
# from an isolated candidate; only its successful preflight permits advancement.
info 'Fetching origin main'
git fetch --atomic --no-tags origin \
  refs/heads/main:refs/remotes/origin/main || exit 1
fetched_main="$(git rev-parse refs/remotes/origin/main)" || exit 1
[ "$fetched_main" = "$(git rev-parse FETCH_HEAD)" ] || {
  warn 'fetched commit and origin/main differ'; exit 1;
}
# The installed target must be a merged release: the exact pinned SHA when the
# caller pins one, otherwise the fetched tip. A pinned SHA need not be the tip;
# later merges may land between review/authorization and this run, but the
# pinned commit itself must already be in fetched origin/main history.
if [ -n "$expected_head" ]; then
  target_head="$expected_head"
  git cat-file -e "$target_head^{commit}" 2>/dev/null &&
    git merge-base --is-ancestor "$target_head" "$fetched_main" || {
    warn 'explicitly approved commit is not in fetched origin/main history'; exit 1;
  }
else
  target_head="$fetched_main"
fi
[ -z "$installed_checkout" ] || [ "$(git -C "$SOURCE_ROOT" rev-parse HEAD)" = "$target_head" ] || {
  warn 'candidate checkout is not the exact approved target'; exit 1;
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
  [ -z "${install_lock_fallback:-}" ] || rmdir -- "$install_lock_fallback" 2>/dev/null || true
}
trap cleanup EXIT
git -c core.hooksPath="$hooks_dir" worktree add --detach "$candidate" "$target_head" >/dev/null || exit 1
candidate_added=1
# Task declarations are scoped to one worktree. The disposable exact-target
# candidate must declare its own installation task before its gate preflight;
# an earlier declaration in the caller's worktree cannot stand in for it.
declaration_reason="Pinned installation candidate for $target_head"
(cd "$candidate" && "$candidate/bin/ai-task-gates" start --class installation \
  --base "$previous_head" --reason "$declaration_reason") || {
  warn 'candidate installation task declaration failed before checkout advance'
  exit 1
}
gate_args=(install-verify --phase preflight --target-head "$target_head"
  --installed-checkout "$REPO_ROOT" --installed-launcher /usr/local/bin/ai-task-gates)
[ -z "$expected_head" ] || gate_args+=(--caller-pinned)
preflight_output="$(cd "$candidate" && "$candidate/bin/ai-task-gates" "${gate_args[@]}")" || {
  warn 'installation preflight refused; installed checkout was not advanced'
  exit 1
}
printf '%s\n' "$preflight_output"
if [ "$preflight_output" = "AI_DEVOPS_INSTALL_RECOVERED=$target_head" ]; then
  git worktree remove --force "$candidate" >/dev/null || exit 1
  candidate_added=0
  if [ "$activate_glm_formal" -eq 1 ]; then glm_formal_activation_publish "$REPO_ROOT" || exit 1; fi
  info "Prior installation of $target_head was already complete; finalization cleanup recovered"
  exit 0
fi
git worktree remove --force "$candidate" >/dev/null || exit 1
candidate_added=0

# Protect an existing immutable formal profile before any canonical advance.
# Unrelated provider/app edits pass; changed GLM/shared safety code requires a
# separately qualified exclusive profile upgrade, rather than breaking clients.
if [ -e "$HOME/.config/ai-devops/glm-formal/activation.json" ] || [ -L "$HOME/.config/ai-devops/glm-formal/activation.json" ]; then
  python3 "$REPO_ROOT/tools/glm_formal_profile.py" upgrade-check --repo "$REPO_ROOT" --target "$target_head" || {
    warn 'active formal GLM profile needs qualified upgrade; installed checkout was not advanced'; exit 1;
  }
fi
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
if [ "$activate_glm_formal" -eq 1 ]; then
  glm_formal_activation_publish "$REPO_ROOT" || { warn 'formal activation failed; explicit activation retry required'; exit 1; }
fi
# Acknowledge the protected advance so earlier unprotected records stop warning.
{ mkdir -p "${AI_TASK_GATES_DIR:-$HOME/.local/state/ai-devops/task-gates}" && printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$REPO_ROOT" protected "$source_sha" >> "${AI_TASK_GATES_DIR:-$HOME/.local/state/ai-devops/task-gates}/unprotected-advances.log"; } 2>/dev/null || true
info "update.sh installed source SHA $source_sha"
