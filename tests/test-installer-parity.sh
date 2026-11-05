#!/usr/bin/env bash
#
# Both installers must produce the SAME managed outcome from the same source.
#
# Why this test exists: Windows has two installers (bin/ai-install-skills for
# Git Bash, bin/install-ai-devops-windows.ps1 for native PowerShell), and step 7
# gave both a reconciliation engine. If they drift apart, a machine installed
# with one and refreshed with the other sees phantom local edits and pointless
# backups. The managed marker is the contract, so it is compared byte for byte.
#
# Skips (exit 0) when pwsh is not installed — Linux/macOS have one installer.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v pwsh >/dev/null 2>&1; then
  echo "SKIP: pwsh not installed — nothing to compare against."
  exit 0
fi

# The production installer is deliberately Windows PowerShell 5.1-safe. Use
# that runtime for the cross-installer direction when Windows provides it, so
# CI cannot pass under pwsh 7 while the documented install command is broken.
PS_CROSS_BIN=pwsh
command -v powershell.exe >/dev/null 2>&1 && PS_CROSS_BIN=powershell.exe

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

fixture="$TMP_ROOT/repo"
mkdir -p "$fixture/bin" "$fixture/config" "$fixture/templates/system" \
  "$fixture/skills/claude/client-claude" "$fixture/skills/codex/client-codex" \
  "$fixture/skills/shared/shared-one/agents"
cp "$REPO_ROOT/bin/ai-install-skills" "$fixture/bin/ai-install-skills"
mkdir -p "$fixture/tools/lib" && cp "$REPO_ROOT/tools/lib/globals-common.sh" "$fixture/tools/lib/globals-common.sh"
printf '%s\n' '---' 'name: client-claude' 'description: test' '---' > "$fixture/skills/claude/client-claude/SKILL.md"
printf '%s\n' '---' 'name: client-codex' 'description: test' '---' > "$fixture/skills/codex/client-codex/SKILL.md"
printf '%s\n' '---' 'name: shared-one' 'description: test' '---' > "$fixture/skills/shared/shared-one/SKILL.md"
# A nested file proves both engines record sub-paths the same way.
printf '%s\n' 'model: test' > "$fixture/skills/shared/shared-one/agents/openai.yaml"
: > "$fixture/config/retired-skills.txt"
printf '%s\n' '# test Claude global' > "$fixture/templates/system/CLAUDE-global.md"
printf '%s\n' '# test Codex global' > "$fixture/templates/system/AGENTS-global-codex.md"
printf '%s\n' '# test ZCode global' > "$fixture/templates/system/AGENTS-global-zcode.md"
printf '%s\n' '# test MiMo global' > "$fixture/templates/system/AGENTS-global-mimo.md"
git -C "$fixture" init -q -b main
git -C "$fixture" config core.autocrlf false
git -C "$fixture" -c user.name=t -c user.email=t@example.invalid \
  -c commit.gpgsign=false add . >/dev/null
git -C "$fixture" -c user.name=t -c user.email=t@example.invalid \
  -c commit.gpgsign=false commit -qm fixture >/dev/null
remote="$TMP_ROOT/remote.git"
git init -q --bare "$remote"
git -C "$fixture" remote add origin "$remote"
git -C "$fixture" push -q -u origin main
remote_url="$(git -C "$fixture" remote get-url origin)"

echo "1/2 fresh install: Bash and PowerShell agree file for file"
mkdir -p "$TMP_ROOT/bash/codex" "$TMP_ROOT/ps/codex" "$TMP_ROOT/ps/mimo" "$TMP_ROOT/bash/mimo"
mkdir -p "$TMP_ROOT/bash/zcode" "$TMP_ROOT/ps/zcode"
mkdir -p "$TMP_ROOT/profile"
profile_native="$(cygpath -w "$TMP_ROOT/profile" 2>/dev/null || echo "$TMP_ROOT/profile")"
locked_installer="$(cygpath -w "$REPO_ROOT/tests/fixtures/installer-parity-locked.ps1" 2>/dev/null || echo "$REPO_ROOT/tests/fixtures/installer-parity-locked.ps1")"
"$PS_CROSS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$locked_installer" -TestLockContract || fail 'parity lock contract failed'
# The fixture repo holds skills and templates only, not bin/ai-git-identity, so
# the installer's machine-tools gate must be skipped here — exactly as
# tests/test-ai-install-skills.sh does. Without it the installer correctly exits
# 1 with "SYNC INCOMPLETE" and this whole suite dies at its first step.
AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE=1 \
USERPROFILE="$profile_native" \
CLAUDE_HOME="$TMP_ROOT/bash/claude" CODEX_HOME="$TMP_ROOT/bash/codex" \
ZCODE_HOME="$TMP_ROOT/bash/zcode" MIMO_HOME="$TMP_ROOT/bash/mimo" \
  bash "$fixture/bin/ai-install-skills" >"$TMP_ROOT/bash-install.log" 2>&1 || {
    cat "$TMP_ROOT/bash-install.log" >&2
    fail 'Bash fixture install failed'
  }
USERPROFILE="$profile_native" \
AI_DEVOPS_INSTALL_TEST_MODE=1 AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE=1 AI_DEVOPS_TEST_EXPECTED_REMOTE="$remote_url" \
"$PS_CROSS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$locked_installer" \
  -Installer "$(cygpath -w "$REPO_ROOT/bin/install-ai-devops-windows.ps1" 2>/dev/null || echo "$REPO_ROOT/bin/install-ai-devops-windows.ps1")" \
  -RepoPath "$(cygpath -w "$fixture" 2>/dev/null || echo "$fixture")" \
  -ClaudeHome "$(cygpath -w "$TMP_ROOT/ps/claude" 2>/dev/null || echo "$TMP_ROOT/ps/claude")" \
  -CodexHome "$(cygpath -w "$TMP_ROOT/ps/codex" 2>/dev/null || echo "$TMP_ROOT/ps/codex")" \
  -ZCodeHome "$(cygpath -w "$TMP_ROOT/ps/zcode" 2>/dev/null || echo "$TMP_ROOT/ps/zcode")" \
  -MimoHome "$(cygpath -w "$TMP_ROOT/ps/mimo" 2>/dev/null || echo "$TMP_ROOT/ps/mimo")" \
  >"$TMP_ROOT/powershell-install.log" 2>&1 || {
    cat "$TMP_ROOT/powershell-install.log" >&2
    fail 'PowerShell fixture install failed'
  }

listing() { (cd "$1" && find skills -type f | LC_ALL=C sort); }
for client in claude codex; do
  diff <(listing "$TMP_ROOT/bash/$client") <(listing "$TMP_ROOT/ps/$client") \
    || fail "$client: installers wrote different file sets"
  # The marker is the contract between the two engines: same hashes, same paths.
  diff "$TMP_ROOT/bash/$client/skills/shared-one/.ai-devops-managed" \
       "$TMP_ROOT/ps/$client/skills/shared-one/.ai-devops-managed" \
    || fail "$client: managed markers differ between installers"
done
for client in zcode mimo; do
  diff "$TMP_ROOT/bash/$client/AGENTS.md" "$TMP_ROOT/ps/$client/AGENTS.md" \
    || fail "$client: installers wrote different global instructions"
done

echo "2/2 cross-installer refresh reports 'up to date', not local edits"
# The real failure this guards: install with one, refresh with the other. If the
# marker formats disagreed at all, the second installer would see local edits,
# back everything up, and rewrite it.
out="$(AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE=1 \
  USERPROFILE="$profile_native" \
  CLAUDE_HOME="$TMP_ROOT/ps/claude" CODEX_HOME="$TMP_ROOT/ps/codex" \
  ZCODE_HOME="$TMP_ROOT/ps/zcode" MIMO_HOME="$TMP_ROOT/ps/mimo" \
  bash "$fixture/bin/ai-install-skills" 2>&1)"
if grep -Fq 'LOCAL EDITS' <<<"$out"; then printf '%s\n' "$out" >&2; fail "Bash saw PowerShell's install as locally edited"; fi
grep -Fq '= shared-one (shared) up to date' <<<"$out" || fail "Bash did not accept PowerShell's install"
[[ -e "$TMP_ROOT/ps/claude/skills-backup" ]] && fail "cross-installer refresh made a backup"

# Force the optional GitHub login probe to be unauthenticated. Windows
# PowerShell 5.1 must treat that ordinary native nonzero exit as information,
# not a terminating NativeCommandError that aborts an otherwise valid install.
gh_config_dir="$TMP_ROOT/empty-gh-config"
mkdir -p "$gh_config_dir"
gh_config_native="$(cygpath -w "$gh_config_dir" 2>/dev/null || echo "$gh_config_dir")"
# Prove the real native-probe helper and the real optional-login decision with
# deterministic native exits. Shared-runner admission can legitimately return
# 75 without attempting authentication; that is deferral, never login success.
cat > "$TMP_ROOT/native-probe-contract.ps1" <<'PS'
param([string]$Installer, [string]$Scratch)
$ErrorActionPreference = 'Stop'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($Installer, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'installer parse failed' }
$function = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-NativeProbe' }, $true)
if (-not $function) { throw 'native probe helper absent' }
Invoke-Expression $function.Extent.Text
$decision = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.IfStatementAst] -and $n.Extent.Text.StartsWith('if ($ghProbe.ExitCode -eq 75)') }, $true)
if (-not $decision) { throw 'optional probe decision absent' }
function Write-Note { param([string]$Text) $script:note = $Text }
$native = (Get-Process -Id $PID).Path
foreach ($code in @(1, 75)) {
    $scriptPath = Join-Path $Scratch "probe-$code.ps1"
    [IO.File]::WriteAllText($scriptPath, "[Console]::Error.WriteLine('fixture native failure'); exit $code")
    $ghProbe = Invoke-NativeProbe -Command $native -Arguments @('-NoProfile', '-File', $scriptPath)
    if ($ghProbe.ExitCode -ne $code -or $ghProbe.ExitCode -eq 0) { throw 'native exit was lost' }
    if ($ErrorActionPreference -ne 'Stop') { throw 'native probe changed caller error handling' }
    $script:note = $null
    Invoke-Expression $decision.Extent.Text
    if ($code -eq 75) {
        if ($script:note -ne 'GitHub login check deferred because Git Bash or the shared GitHub gate is unavailable.') { throw '75 was not bounded deferral' }
        if ($script:note -match 'logged in|success') { throw 'deferral became authentication success' }
    } elseif ($script:note -ne 'GitHub CLI is installed but not logged in. Run: gh auth login') {
        throw 'unauthenticated exit was not reported'
    }
}
PS
"$PS_CROSS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$TMP_ROOT/native-probe-contract.ps1" 2>/dev/null || echo "$TMP_ROOT/native-probe-contract.ps1")" \
  -Installer "$(cygpath -w "$REPO_ROOT/bin/install-ai-devops-windows.ps1" 2>/dev/null || echo "$REPO_ROOT/bin/install-ai-devops-windows.ps1")" \
  -Scratch "$(cygpath -w "$TMP_ROOT" 2>/dev/null || echo "$TMP_ROOT")" \
  || fail 'deterministic native optional-probe contract failed'
set +e
out="$(GH_CONFIG_DIR="$gh_config_native" GH_TOKEN= GITHUB_TOKEN= \
  USERPROFILE="$profile_native" \
  AI_DEVOPS_INSTALL_TEST_MODE=1 AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE=1 AI_DEVOPS_TEST_EXPECTED_REMOTE="$remote_url" \
  "$PS_CROSS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$locked_installer" \
  -Installer "$(cygpath -w "$REPO_ROOT/bin/install-ai-devops-windows.ps1" 2>/dev/null || echo "$REPO_ROOT/bin/install-ai-devops-windows.ps1")" \
  -RepoPath "$(cygpath -w "$fixture" 2>/dev/null || echo "$fixture")" \
  -ClaudeHome "$(cygpath -w "$TMP_ROOT/bash/claude" 2>/dev/null || echo "$TMP_ROOT/bash/claude")" \
  -CodexHome "$(cygpath -w "$TMP_ROOT/bash/codex" 2>/dev/null || echo "$TMP_ROOT/bash/codex")" \
  -ZCodeHome "$(cygpath -w "$TMP_ROOT/bash/zcode" 2>/dev/null || echo "$TMP_ROOT/bash/zcode")" \
  -MimoHome "$(cygpath -w "$TMP_ROOT/bash/mimo" 2>/dev/null || echo "$TMP_ROOT/bash/mimo")" \
  2>&1)"
cross_rc=$?
set -e
if [ "$cross_rc" -ne 0 ]; then printf '%s\n' "$out" >&2; fail "PowerShell cross-installer refresh exited $cross_rc"; fi
if command -v gh >/dev/null 2>&1; then
  grep -Eq 'GitHub CLI is installed but not logged in|GitHub login check deferred because Git Bash or the shared GitHub gate is unavailable\.' <<<"$out" \
    || fail "PowerShell cross-installer did not report unauthenticated or bounded-deferred optional GitHub probe"
else
  grep -Fq 'GitHub CLI not found' <<<"$out" \
    || fail "PowerShell cross-installer did not handle a missing optional GitHub CLI"
fi
if grep -Fq 'LOCAL EDITS' <<<"$out"; then printf '%s\n' "$out" >&2; fail "PowerShell saw Bash's install as locally edited"; fi
grep -Fq '= shared-one (shared) up to date' <<<"$out" || fail "PowerShell did not accept Bash's install"
[[ -e "$TMP_ROOT/bash/claude/skills-backup" ]] && fail "cross-installer refresh made a backup"
[[ "$PS_CROSS_BIN" != powershell.exe ]] || powershell.exe -NoProfile -Command '$PSVersionTable.PSVersion.Major' | tr -d '\r' | grep -qx 5 \
  || fail "cross-installer check did not run under Windows PowerShell 5.1"

echo "PASS: installer parity"
