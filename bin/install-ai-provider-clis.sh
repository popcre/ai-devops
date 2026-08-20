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

After install, each provider needs ONE interactive login, which this script
deliberately does not automate:
  grok            # then follow the sign-in prompt
  kimi login
  qwen            # then complete the OAuth flow
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

failed=0
installed_any=0
needs_path=()

for entry in "${PROVIDERS[@]}"; do
  IFS='|' read -r name cmd url home_rel <<<"$entry"
  wants "$name" || continue

  if existing="$(resolve "$cmd" "$home_rel")" && ((FORCE == 0)); then
    echo "SKIP $name already installed ($existing)"
    # Still repair reachability: "installed but not on PATH" is the exact state
    # that makes the doctor report the provider unavailable.
    ((DRY_RUN)) || link_into_local_bin "$cmd" "$existing"
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
    echo "OK   $name installed ($resolved)"
    installed_any=1
    link_into_local_bin "$cmd" "$resolved"
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
  echo "  qwen            # complete the OAuth flow"
  echo "Then prove the full path:  ai-qwen doctor --live"
fi

((failed == 0)) || die "one or more providers failed to install."
echo "OK provider CLIs are current."
