#!/usr/bin/env bash
# Contract tests for bin/install-ai-provider-clis.sh.
# Nothing here downloads or installs anything: every test either uses --dry-run,
# a fake already-installed provider on PATH, or an argument-validation path that
# exits before the first network call.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo/bin/install-ai-provider-clis.sh"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

[[ -x "$script" ]] || { echo "FAIL: installer is not executable"; exit 1; }

# --- help and argument validation -----------------------------------------
bash "$script" --help | grep -q 'Providers: grok kimi qwen'

if bash "$script" --dry-run bogus >"$tmp/bogus" 2>&1; then
  echo "FAIL: unknown provider was accepted"; exit 1
fi
grep -q "unknown provider 'bogus'" "$tmp/bogus"

if bash "$script" --nonsense >"$tmp/opt" 2>&1; then
  echo "FAIL: unknown option was accepted"; exit 1
fi
grep -q 'Unknown option' "$tmp/opt"

# --- dry run installs nothing and covers every provider --------------------
# Run against an empty HOME and a minimal PATH so the result does not depend on
# which providers happen to be installed on the machine running the test.
# PATH keeps only the directories holding the tools the installer requires, so
# a provider already installed on this machine cannot leak in and turn a
# "would install" into a "SKIP". Works on Git Bash (curl lives in /mingw64/bin)
# as well as Ubuntu.
clean="$tmp/clean-home"; mkdir -p "$clean"
minimal_path="$(dirname "$(command -v curl)"):$(dirname "$(command -v bash)"):/usr/bin:/bin"
clean_run() { env HOME="$clean" PATH="$minimal_path" bash "$script" "$@"; }

for p in grok kimi qwen; do
  if env PATH="$minimal_path" command -v "$p" >/dev/null 2>&1; then
    echo "FAIL: test PATH is not clean, it still resolves $p"; exit 1
  fi
done

clean_run --dry-run >"$tmp/all" 2>&1
for p in grok kimi qwen; do grep -q "would install $p" "$tmp/all" || {
  echo "FAIL: dry run skipped $p"; exit 1; }
done

# Naming one provider must not touch the others.
clean_run --dry-run qwen >"$tmp/one" 2>&1
grep -q 'would install qwen' "$tmp/one"
! grep -q 'would install grok' "$tmp/one"

# --- an already-installed provider is skipped, not reinstalled -------------
fake="$tmp/fakebin"; mkdir -p "$fake"
printf '#!/usr/bin/env bash\nexit 0\n' >"$fake/grok"; chmod +x "$fake/grok"
PATH="$fake:$PATH" bash "$script" --dry-run grok >"$tmp/skip" 2>&1
grep -q 'SKIP grok already installed' "$tmp/skip"

# --force overrides that skip.
PATH="$fake:$PATH" bash "$script" --dry-run --force grok >"$tmp/force" 2>&1
grep -q 'would install grok' "$tmp/force"

# --- root guard ------------------------------------------------------------
# The guard must exist and must be escapable only by explicit opt-in, because
# the vendor installers write into $HOME and root's $HOME is not the session
# user's. We assert on the source rather than by becoming root.
grep -q 'refusing to run as root' "$script"
grep -q 'allow-root' "$script"

# --- no silent failure -----------------------------------------------------
# Every provider must be verified after its installer runs.
grep -q 'installer finished but neither' "$script"
grep -q 'downloaded installer was empty' "$script"

# --- qwen must NOT be installed via npm ------------------------------------
# hetz runs Node 20; the npm package needs Node 22+ and yields a broken command.
! grep -q '@qwen-code/qwen-code' "$script"

# --- install paths match what the vendor installers actually use -----------
grep -q '\.grok/bin/grok' "$script"
grep -q '\.kimi-code/bin/kimi' "$script"
grep -q '\.local/bin/qwen' "$script"

# --- the doctor's complaint now has a documented cure ----------------------
grep -q 'provider unavailable' "$repo/bin/ai-machine-tools-doctor"
grep -q 'install-ai-provider-clis' "$repo/bin/ai-machine-tools-doctor"

echo 'PASS: provider CLI installer contract'
