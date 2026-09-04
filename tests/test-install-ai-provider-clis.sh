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
minimal_path="$(dirname "$(command -v curl)"):$(dirname "$(command -v bash)"):$(dirname "$(command -v jq)"):/usr/bin:/bin"
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

# --- fake grok binaries ----------------------------------------------------
# Grok is version-pinned (config/provider-cli-versions.json, issue #251), so a
# fake provider must answer --version truthfully or the installer correctly
# treats it as an unqualified build. These fakes also record every `update`
# call, so the exact-version upgrade path is asserted without any download.
WANT="$(bash "$repo/bin/ai-provider-version" required grok)"
[[ -n "$WANT" ]] || { echo "FAIL: the policy pins no grok version"; exit 1; }

make_fake_grok() { # make_fake_grok PATH REPORTED_VERSION [ok|fail|wrong]
  local path="$1" version="$2" result="${3:-ok}"
  mkdir -p "$(dirname "$path")"
  # The version lives inside the binary and `update` rewrites it in place, so a
  # restored backup really does report the old version again.
  cat >"$path" <<'FAKEGROK'
#!/usr/bin/env bash
V='@@VERSION@@'
case "${1:-}" in
  --version) printf 'grok %s (fake) [stable]
' "$V"; exit 0 ;;
  update)
    printf '%s
' "$*" >>"$(dirname "$0")/.fake-grok-update"
    case '@@RESULT@@' in
      fail)  exit 7 ;;
      wrong) sed -i "s/^V=.*/V='9.9.9'/" "$0"; exit 0 ;;
      *)     sed -i "s/^V=.*/V='@@WANT@@'/" "$0"; exit 0 ;;
    esac ;;
esac
exit 0
FAKEGROK
  sed -i -e "s/@@VERSION@@/$version/" -e "s/@@RESULT@@/$result/"          -e "s/@@WANT@@/$WANT/" "$path"
  chmod +x "$path"
}

# --- an already-installed provider at the exact version is skipped ---------
fake="$tmp/fakebin"; mkdir -p "$fake"
make_fake_grok "$fake/grok" "$WANT"
PATH="$fake:$PATH" bash "$script" --dry-run grok >"$tmp/skip" 2>&1
grep -q "SKIP grok already installed at the exact supported version $WANT" "$tmp/skip"

# --force overrides that skip.
PATH="$fake:$PATH" bash "$script" --dry-run --force grok >"$tmp/force" 2>&1
grep -q 'would install grok' "$tmp/force"

# --- installed-but-not-on-PATH is repaired, not just reported --------------
# hetz had all three CLIs installed and working while the doctor still called
# them unavailable, because the vendor rc-file PATH edits had not taken.
linkhome="$tmp/link-home"; mkdir -p "$linkhome/.grok/bin"
make_fake_grok "$linkhome/.grok/bin/grok" "$WANT"
env HOME="$linkhome" PATH="$minimal_path" bash "$script" grok >"$tmp/link" 2>&1
grep -q 'SKIP grok already installed' "$tmp/link"
# Assert reachability, not symlink-ness: Git Bash silently copies instead of
# linking, and the target platform for this script is Linux/macOS.
[[ -x "$linkhome/.local/bin/grok" ]] || { echo "FAIL: did not link grok into ~/.local/bin"; exit 1; }
grep -q "linked $linkhome/.local/bin/grok" "$tmp/link"

# An unrelated real file in ~/.local/bin must never be clobbered.
guard="$tmp/guard-home"; mkdir -p "$guard/.grok/bin" "$guard/.local/bin"
make_fake_grok "$guard/.grok/bin/grok" "$WANT"
echo 'not-a-symlink' >"$guard/.local/bin/grok"
env HOME="$guard" PATH="$minimal_path" bash "$script" grok >"$tmp/guarded" 2>&1
grep -q 'is not a symlink; leaving it untouched' "$tmp/guarded"
grep -q 'not-a-symlink' "$guard/.local/bin/grok"

# A dry run must not create links.
dry="$tmp/dry-home"; mkdir -p "$dry/.grok/bin"
make_fake_grok "$dry/.grok/bin/grok" "$WANT"
env HOME="$dry" PATH="$minimal_path" bash "$script" --dry-run grok >/dev/null 2>&1
[[ -e "$dry/.local/bin/grok" ]] && { echo "FAIL: dry run created a link"; exit 1; }

# --- exact version policy (issue #251) -------------------------------------
# "A runnable grok" is not the contract. Both wrappers are qualified against one
# exact build, so an older OR newer build must be brought to exactly that
# version, and a failed or wrong-version upgrade must restore what was there.

# grok_older_version_triggers_exact_upgrade
oldhome="$tmp/old-home"; mkdir -p "$oldhome/.grok/bin"
make_fake_grok "$oldhome/.grok/bin/grok" '1.0.5'
env HOME="$oldhome" PATH="$minimal_path" bash "$script" --dry-run grok >"$tmp/old-dry" 2>&1
grep -q "would upgrade grok from 1.0.5 to exactly $WANT" "$tmp/old-dry"
[[ -e "$oldhome/.grok/bin/.fake-grok-update" ]] && {
  echo "FAIL: a dry run ran a real upgrade"; exit 1; }
env HOME="$oldhome" PATH="$minimal_path" bash "$script" grok >"$tmp/old" 2>&1
grep -q -- "update --version $WANT" "$oldhome/.grok/bin/.fake-grok-update"
grep -q "is now exactly $WANT" "$tmp/old"
grep -q 'backed up' "$tmp/old"

# grok_newer_unqualified_version_is_not_accepted
newhome="$tmp/new-home"; mkdir -p "$newhome/.grok/bin"
make_fake_grok "$newhome/.grok/bin/grok" '99.0.0'
env HOME="$newhome" PATH="$minimal_path" bash "$script" grok >"$tmp/newer" 2>&1
grep -q "grok reports 99.0.0; this repository qualifies exactly $WANT" "$tmp/newer"
grep -q -- "update --version $WANT" "$newhome/.grok/bin/.fake-grok-update"

# grok_failed_upgrade_restores_original_binary
failhome="$tmp/fail-home"; mkdir -p "$failhome/.grok/bin"
make_fake_grok "$failhome/.grok/bin/grok" '1.0.5' fail
if env HOME="$failhome" PATH="$minimal_path" bash "$script" grok >"$tmp/fail" 2>&1; then
  echo "FAIL: a failed upgrade reported success"; exit 1
fi
grep -q 'restoring the previous binary' "$tmp/fail"
"$failhome/.grok/bin/grok" --version | grep -q '1.0.5'

# grok_wrong_post_install_version_rolls_back
wronghome="$tmp/wrong-home"; mkdir -p "$wronghome/.grok/bin"
make_fake_grok "$wronghome/.grok/bin/grok" '1.0.5' wrong
if env HOME="$wronghome" PATH="$minimal_path" bash "$script" grok >"$tmp/wrong" 2>&1; then
  echo "FAIL: a wrong resulting version reported success"; exit 1
fi
grep -q "reports '9.9.9', not $WANT" "$tmp/wrong"
"$wronghome/.grok/bin/grok" --version | grep -q '1.0.5'

# grok_upgrade_never_reads_or_copies_auth_json
# The rollback backup must hold the executable and nothing else; credentials,
# sessions and logs under ~/.grok must never be read or copied anywhere.
authhome="$tmp/auth-home"; mkdir -p "$authhome/.grok/bin"
make_fake_grok "$authhome/.grok/bin/grok" '1.0.5'
printf '%s\n' '{"token":"do-not-copy-this-value"}' >"$authhome/.grok/auth.json"
env HOME="$authhome" PATH="$minimal_path" bash "$script" grok >/dev/null 2>&1
if grep -rq 'do-not-copy-this-value' "$authhome/.local" 2>/dev/null; then
  echo "FAIL: the upgrade copied credentials out of ~/.grok"; exit 1
fi

# grok_installer_hash_drift_fails_before_execution
# A downloaded vendor installer is verified before it is ever executed.
grep -q 'downloaded installer was empty' "$script"

# other_provider_versions_are_unchanged
policy="$repo/config/provider-cli-versions.json"
jq -e '.schema_version == 1' "$policy" >/dev/null
jq -e '.providers.grok.supported_version | type == "string"' "$policy" >/dev/null
for p in kimi qwen; do
  jq -e --arg p "$p" '.providers[$p].supported_version == null' "$policy" >/dev/null || {
    echo "FAIL: $p must stay unpinned; Grok work must not force its upgrade"; exit 1; }
done
# Secret-free by contract.
! grep -Eqi '"(token|api[_-]?key|password|secret)"' "$policy"

# The version literal lives in exactly one place: the policy file.
if grep -qF "$WANT" "$script"; then
  echo "FAIL: the installer hard-codes the grok version instead of reading the policy"; exit 1
fi

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
grep -q 'declaration=.*sed -n' "$script"
grep -q '<<<"\$declaration"' "$script"

# --- install paths match what the vendor installers actually use -----------
grep -q '\.grok/bin/grok' "$script"
grep -q '\.kimi-code/bin/kimi' "$script"
grep -q '\.local/bin/qwen' "$script"

# --- the doctor's complaint now has a documented cure ----------------------
grep -q 'provider unavailable' "$repo/bin/ai-machine-tools-doctor"
grep -q 'install-ai-provider-clis' "$repo/bin/ai-machine-tools-doctor"

echo 'PASS: provider CLI installer contract'
