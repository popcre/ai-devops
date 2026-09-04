#!/usr/bin/env bash
# install-ai-provider-clis.sh — install the third-party AI provider CLIs
# (Grok Build, Kimi Code, Qwen Code) on Linux/macOS.
#
# WHY THIS EXISTS
#   `install.sh` and `install-machine-tools.sh` install this repo's OWN wrappers
#   (`ai-grok-review`, `ai-kimi`, `ai-qwen`). They have never installed the
#   vendor CLIs those wrappers call. On Windows that gap is covered by
#   bin/install-windows-ai-provider-clis.ps1; on Ubuntu nothing covered it, so
#   `ai-machine-tools-doctor` reported "grok/kimi/qwen provider unavailable"
#   forever with no supported way to fix it (found on hetz, 2026-08-20).
#
# DESIGN NOTES
#   - Per-user by design. Every vendor installer writes into $HOME. Running this
#     under sudo would install for root and leave the real session user (`ai` on
#     hetz) still broken, so the script refuses to run as root unless the caller
#     genuinely means it (--allow-root).
#   - Authentication stays interactive and manual, exactly as on Windows. This
#     script installs binaries; it never touches a login.
#   - Idempotent: an already-installed provider is skipped unless --force.
#   - Version-pinned where the repository qualifies an exact build. Grok is
#     qualified against exactly one version (config/provider-cli-versions.json)
#     because our wrappers parse that build's JSON, stop reasons, usage keys and
#     session behaviour. "A runnable grok" is NOT good enough: presence-based
#     skipping is what left machines on 1.0.5 indefinitely (issue #251). An
#     off-policy Grok is upgraded to the exact supported version, the resulting
#     version is verified, and a failed upgrade restores the original binary.
#     Credentials under ~/.grok are never read, copied or backed up.
#   - Fails loudly. A provider that installs but does not produce a working
#     command is an error, never a warning.
#   - Qwen uses the vendor's standalone installer, NOT npm: the npm package
#     requires Node 22+ and hetz ships Node 20, where the npm path installs
#     something that cannot run.
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: install-ai-provider-clis.sh [options] [provider ...]

Installs the third-party AI provider CLIs used by this repo's wrappers.
With no provider named, installs all of them.

Providers: grok kimi qwen

Options:
  --force        Reinstall even if the command already works.
  --dry-run      Show what would happen; download and install nothing.
  --allow-root   Permit running as root (installs into /root; rarely correct).
  -h, --help     Show this help.

After install, each provider needs ONE authentication setup, which this script
deliberately does not automate:
  grok            # then follow the sign-in prompt
  kimi login
  qwen            # then configure Alibaba Coding Plan authentication
USAGE
}

# name|command|installer URL|post-install binary to look for under $HOME
PROVIDERS=(
  "grok|grok|https://x.ai/cli/install.sh|.grok/bin/grok"
  "kimi|kimi|https://code.kimi.com/kimi-code/install.sh|.kimi-code/bin/kimi"
  "qwen|qwen|https://qwen-code-assets.oss-cn-hangzhou.aliyuncs.com/installation/install-qwen-standalone.sh|.local/bin/qwen"
)

FORCE=0
DRY_RUN=0
ALLOW_ROOT=0
WANTED=()

while (($#)); do
  case "$1" in
    --force) FORCE=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --allow-root) ALLOW_ROOT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) WANTED+=("$1"); shift ;;
  esac
done

die() { echo "ERROR $*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is required but not installed."
command -v bash >/dev/null 2>&1 || die "bash is required but not installed."
# jq reads config/provider-cli-versions.json, the exact-version policy this
# installer enforces. Without it there is no policy to enforce, so we stop
# rather than fall back to "any build that runs" (issue #251).
command -v jq >/dev/null 2>&1 || die "jq is required to read the provider version policy."

if [ "$(id -u)" -eq 0 ] && ((ALLOW_ROOT == 0)); then
  die "refusing to run as root: vendor installers write into \$HOME, so this would install for root and leave your normal user still broken. Re-run as the user that runs AI sessions (on hetz that is 'ai'), or pass --allow-root if you really mean root."
fi

# Validate requested provider names before doing any work.
known_names() { for entry in "${PROVIDERS[@]}"; do echo "${entry%%|*}"; done; }
if ((${#WANTED[@]})); then
  for want in "${WANTED[@]}"; do
    known_names | grep -qx "$want" || die "unknown provider '$want'. Known: $(known_names | tr '\n' ' ')"
  done
fi

wants() {
  ((${#WANTED[@]} == 0)) && return 0
  printf '%s\n' "${WANTED[@]}" | grep -qx "$1"
}

resolve() {
  # A provider counts as installed if it is on PATH or at its known home path.
  local cmd="$1" home_rel="$2"
  if command -v "$cmd" >/dev/null 2>&1; then echo "$(command -v "$cmd")"; return 0; fi
  if [ -x "$HOME/$home_rel" ]; then echo "$HOME/$home_rel"; return 0; fi
  return 1
}

# Each vendor installer drops its binary in its own directory and edits a shell
# rc file to add that directory to PATH. That is unreliable: on hetz the Kimi
# directory never reached PATH, so `kimi` was installed and working yet the
# doctor still called the provider unavailable (2026-08-20). Rather than trust
# three different rc edits, link every provider into ~/.local/bin, which the
# default Ubuntu profile already puts on PATH.
LOCAL_BIN="$HOME/.local/bin"
link_into_local_bin() {
  local cmd="$1" real="$2" dst="$LOCAL_BIN/$1"
  [ "$real" = "$dst" ] && return 0
  mkdir -p "$LOCAL_BIN"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "WARN $cmd: $dst exists and is not a symlink; leaving it untouched" >&2
    return 0
  fi
  ln -sfn "$real" "$dst"
  echo "     linked $dst -> $real"
}

harden_qwen_child_env() {
  local root="${AI_QWEN_SANITIZER_ROOT:-$HOME/.local/lib/qwen-code}" candidate="" count=0 tmp backup_dir node verify_tool
  [ -d "$root/lib/chunks" ] || { echo "ERROR qwen: installed bundle directory is missing: $root/lib/chunks" >&2; return 1; }
  while IFS= read -r file; do
    grep -q 'function sanitizeChildEnv' "$file" || continue
    candidate="$file"; count=$((count+1))
  done < <(grep -l 'var INTERNAL_SECRET_ENV_VARS' "$root"/lib/chunks/*.js 2>/dev/null || true)
  [ "$count" = 1 ] || { echo "ERROR qwen: expected exactly one child-environment sanitizer bundle under $root; found $count" >&2; return 1; }
  local declaration
  declaration="$(sed -n '/var INTERNAL_SECRET_ENV_VARS[[:space:]]*=[[:space:]]*\[/,/^[[:space:]]*\];/p' "$candidate")"
  [[ -n "$declaration" ]] || die 'the known Qwen sanitizer declaration was not found; refusing an unverified patch'
  if ! grep -q '"BAILIAN_CODING_PLAN_API_KEY"' <<<"$declaration"; then
    backup_dir="$HOME/.local/state/ai-devops/qwen/vendor-backups"
    mkdir -p "$backup_dir"
    cp -p "$candidate" "$backup_dir/$(basename "$candidate").$(date -u +%Y%m%dT%H%M%SZ).bak" || return 1
    tmp="$(mktemp "${candidate}.harden.XXXXXX")" || return 1
    if ! awk '!done && /var INTERNAL_SECRET_ENV_VARS = \[/ { print; print "  \"BAILIAN_CODING_PLAN_API_KEY\","; done=1; next } { print } END { if (!done) exit 42 }' "$candidate" > "$tmp"; then
      rm -f "$tmp"; echo "ERROR qwen: could not patch the known child-environment sanitizer" >&2; return 1
    fi
    chmod --reference="$candidate" "$tmp" 2>/dev/null || true
    mv "$tmp" "$candidate"
  fi
  if [ -x "$root/node/bin/node" ]; then node="$root/node/bin/node"; elif [ -x "$root/node/node.exe" ]; then node="$root/node/node.exe"; else echo "ERROR qwen: bundled Node runtime is missing" >&2; return 1; fi
  verify_tool="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/../tools" 2>/dev/null && pwd)/verify-qwen-child-env-sanitizer.mjs"
  [ -f "$verify_tool" ] && "$node" "$verify_tool" "$root" >/dev/null || { echo "ERROR qwen: child-environment sanitizer failed its behavioral proof" >&2; return 1; }
  echo "OK   qwen child-process sanitizer now strips the Coding Plan credential"
}

# ---------------------------------------------------------------------------
# Exact-version policy (Grok). One source of truth: config/provider-cli-versions.json.
# ---------------------------------------------------------------------------
SELF_REAL="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
VERSION_TOOL="$(dirname "$SELF_REAL")/ai-provider-version"
# -f, not -x: a checkout that lost the executable bit is a packaging problem,
# not a reason to refuse the install. It is run through bash below.
[ -f "$VERSION_TOOL" ] || VERSION_TOOL="$(command -v ai-provider-version 2>/dev/null || true)"

required_version() { # required_version PROVIDER  -> exact version, or empty when unpinned
  [ -n "$VERSION_TOOL" ] && [ -f "$VERSION_TOOL" ]     || die "ai-provider-version is missing; refusing to install a provider without its version policy."
  bash "$VERSION_TOOL" required "$1"
}

reported_version() { # reported_version BINARY -> bare x.y.z, empty when unreadable
  local out; out="$("$1" --version 2>/dev/null | head -1 || true)"
  [ -n "$out" ] || return 0
  bash "$VERSION_TOOL" parse "$out"
}

BACKUP_ROOT="$HOME/.local/state/ai-devops/provider-cli/backups"

backup_binary() { # backup_binary NAME PATH -> prints backup path
  local name="$1" src="$2" dst
  mkdir -p "$BACKUP_ROOT"
  dst="$BACKUP_ROOT/$name.$(date -u +%Y%m%dT%H%M%SZ).bak"
  # Copy only the executable the vendor updater replaces. Never touch ~/.grok
  # credentials, sessions or logs.
  cp -p "$(readlink -f "$src" 2>/dev/null || echo "$src")" "$dst"
  printf '%s' "$dst"
}

restore_binary() { # restore_binary BACKUP TARGET
  local backup="$1" target="$2"
  [ -f "$backup" ] || return 1
  target="$(readlink -f "$target" 2>/dev/null || echo "$target")"
  cp -p "$backup" "$target"
}

# The whole risky sequence runs in a subshell so that ANY failure inside it --
# a non-zero `update`, a wrong post-install version, an unparseable banner, or a
# `set -e` abort from something unexpected -- returns here with the backup still
# on disk. This is the Unix half of the same restore-on-any-failure guarantee the
# Windows installer gets from its `finally` block.
_exact_upgrade_attempt() { # _exact_upgrade_attempt NAME BINARY WANT
  local name="$1" bin_path="$2" want="$3" now
  "$bin_path" update --version "$want" || {
    echo "ERROR $name: 'update --version $want' failed" >&2; return 1; }
  now="$(reported_version "$bin_path" 2>/dev/null || true)"
  if [ "$now" != "$want" ]; then
    echo "ERROR $name: upgrade finished but the binary reports '${now:-unreadable}', not $want" >&2
    return 1
  fi
}

upgrade_to_exact_version() { # upgrade_to_exact_version NAME BINARY WANT
  local name="$1" bin_path="$2" want="$3" backup
  case "$name" in
    grok) ;;
    *) echo "ERROR $name: no exact-version upgrade path is defined for this provider" >&2; return 1 ;;
  esac
  backup="$(backup_binary "$name" "$bin_path")" || {
    echo "ERROR $name: could not back up the existing binary; refusing an unrecoverable upgrade" >&2; return 1; }
  echo "     backed up $bin_path -> $backup"
  if ! ( _exact_upgrade_attempt "$name" "$bin_path" "$want" ); then
    echo "ERROR $name: restoring the previous binary" >&2
    restore_binary "$backup" "$bin_path" || echo "ERROR $name: restore from $backup FAILED; restore it by hand" >&2
    return 1
  fi
  echo "OK   $name is now exactly $want (previous binary kept at $backup)"
}

failed=0
installed_any=0
needs_path=()

for entry in "${PROVIDERS[@]}"; do
  IFS='|' read -r name cmd url home_rel <<<"$entry"
  wants "$name" || continue

  want="$(required_version "$name")"
  # An unpinned entry means "presence is enough", which is right for Kimi and
  # Qwen. For Grok it would silently reinstate the presence-skip this change
  # exists to remove, so an empty pin is a policy error, not a permission.
  if [ "$name" = "grok" ] && [ -z "$want" ]; then
    die "the provider version policy pins no Grok version; Grok must be qualified at an exact version before it is installed."
  fi

  if existing="$(resolve "$cmd" "$home_rel")" && ((FORCE == 0)); then
    if [ -n "$want" ]; then
      have="$(reported_version "$existing")"
      if [ "$have" != "$want" ]; then
        if ((DRY_RUN)); then
          echo "DRY-RUN would upgrade $name from ${have:-unknown} to exactly $want"
          continue
        fi
        echo "==> $name reports ${have:-unknown}; this repository qualifies exactly $want"
        if ! upgrade_to_exact_version "$name" "$existing" "$want"; then failed=1; continue; fi
        link_into_local_bin "$cmd" "$existing"
        continue
      fi
      echo "SKIP $name already installed at the exact supported version $want ($existing)"
    else
      echo "SKIP $name already installed ($existing)"
    fi
    # Still repair reachability: "installed but not on PATH" is the exact state
    # that makes the doctor report the provider unavailable.
    ((DRY_RUN)) || link_into_local_bin "$cmd" "$existing"
    if [ "$name" = qwen ] && ((DRY_RUN == 0)); then harden_qwen_child_env || failed=1; fi
    continue
  fi

  if ((DRY_RUN)); then
    echo "DRY-RUN would install $name from $url"
    continue
  fi

  echo "==> installing $name from its official installer ($url)"
  tmp="$(mktemp)"
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" EXIT
  if ! curl -fsSL "$url" -o "$tmp"; then
    echo "ERROR $name: could not download its installer from $url" >&2
    failed=1; rm -f "$tmp"; trap - EXIT; continue
  fi
  if [ ! -s "$tmp" ]; then
    echo "ERROR $name: downloaded installer was empty; refusing to run it" >&2
    failed=1; rm -f "$tmp"; trap - EXIT; continue
  fi
  if ! bash "$tmp"; then
    echo "ERROR $name: its installer exited non-zero" >&2
    failed=1; rm -f "$tmp"; trap - EXIT; continue
  fi
  rm -f "$tmp"; trap - EXIT

  # Prove it. A vendor installer that "succeeds" without producing a runnable
  # command is exactly the silent failure this repo forbids.
  if resolved="$(resolve "$cmd" "$home_rel")"; then
    if [ -n "$want" ]; then
      have="$(reported_version "$resolved")"
      if [ "$have" != "$want" ]; then
        echo "==> $name installed ${have:-unknown}; pinning to the supported version $want"
        if ! upgrade_to_exact_version "$name" "$resolved" "$want"; then failed=1; continue; fi
      fi
    fi
    echo "OK   $name installed ($resolved)"
    installed_any=1
    link_into_local_bin "$cmd" "$resolved"
    if [ "$name" = qwen ]; then harden_qwen_child_env || failed=1; fi
    command -v "$cmd" >/dev/null 2>&1 || needs_path+=("$LOCAL_BIN")
  else
    echo "ERROR $name: installer finished but neither '$cmd' on PATH nor \$HOME/$home_rel exists" >&2
    failed=1
  fi
done

if ((${#needs_path[@]})); then
  echo
  echo "NOTE these installed but are not on your PATH in this shell:"
  printf '  %s\n' "${needs_path[@]}"
  echo "Open a new login shell, or add them to PATH in ~/.bashrc."
fi

if ((installed_any)) && ((DRY_RUN == 0)); then
  echo
  echo "NEXT sign in once per provider (interactive, deliberately not automated):"
  echo "  grok            # follow the sign-in prompt"
  echo "  kimi login"
  echo "  qwen            # configure Alibaba Coding Plan authentication"
  echo "Then prove the full path:  ai-qwen doctor --live"
fi

((failed == 0)) || die "one or more providers failed to install."
echo "OK provider CLIs are current."
