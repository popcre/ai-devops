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
printf '%s\n' '---' 'name: client-claude' 'description: test' '---' > "$fixture/skills/claude/client-claude/SKILL.md"
printf '%s\n' '---' 'name: client-codex' 'description: test' '---' > "$fixture/skills/codex/client-codex/SKILL.md"
printf '%s\n' '---' 'name: shared-one' 'description: test' '---' > "$fixture/skills/shared/shared-one/SKILL.md"
# A nested file proves both engines record sub-paths the same way.
printf '%s\n' 'model: test' > "$fixture/skills/shared/shared-one/agents/openai.yaml"
: > "$fixture/config/retired-skills.txt"
printf '%s\n' '# test Claude global' > "$fixture/templates/system/CLAUDE-global.md"
printf '%s\n' '# test Codex global' > "$fixture/templates/system/AGENTS-global-codex.md"
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
mkdir -p "$TMP_ROOT/bash/codex" "$TMP_ROOT/ps/codex"
# The fixture repo holds skills and templates only, not bin/ai-git-identity, so
# the installer's machine-tools gate must be skipped here — exactly as
# tests/test-ai-install-skills.sh does. Without it the installer correctly exits
# 1 with "SYNC INCOMPLETE" and this whole suite dies at its first step.
AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE=1 \
CLAUDE_HOME="$TMP_ROOT/bash/claude" CODEX_HOME="$TMP_ROOT/bash/codex" \
  bash "$fixture/bin/ai-install-skills" >/dev/null 2>&1
AI_DEVOPS_INSTALL_TEST_MODE=1 AI_DEVOPS_TEST_EXPECTED_REMOTE="$remote_url" \
pwsh -NoProfile -File "$REPO_ROOT/bin/install-ai-devops-windows.ps1" \
  -RepoPath "$(cygpath -w "$fixture" 2>/dev/null || echo "$fixture")" \
  -ClaudeHome "$(cygpath -w "$TMP_ROOT/ps/claude" 2>/dev/null || echo "$TMP_ROOT/ps/claude")" \
  -CodexHome "$(cygpath -w "$TMP_ROOT/ps/codex" 2>/dev/null || echo "$TMP_ROOT/ps/codex")" \
  -SkipGitInstall >/dev/null 2>&1

listing() { (cd "$1" && find skills -type f | LC_ALL=C sort); }
for client in claude codex; do
  diff <(listing "$TMP_ROOT/bash/$client") <(listing "$TMP_ROOT/ps/$client") \
    || fail "$client: installers wrote different file sets"
  # The marker is the contract between the two engines: same hashes, same paths.
  diff "$TMP_ROOT/bash/$client/skills/shared-one/.ai-devops-managed" \
       "$TMP_ROOT/ps/$client/skills/shared-one/.ai-devops-managed" \
    || fail "$client: managed markers differ between installers"
done

echo "2/2 cross-installer refresh reports 'up to date', not local edits"
# The real failure this guards: install with one, refresh with the other. If the
# marker formats disagreed at all, the second installer would see local edits,
# back everything up, and rewrite it.
out="$(AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE=1 \
  CLAUDE_HOME="$TMP_ROOT/ps/claude" CODEX_HOME="$TMP_ROOT/ps/codex" \
  bash "$fixture/bin/ai-install-skills" 2>&1)"
if grep -Fq 'LOCAL EDITS' <<<"$out"; then printf '%s\n' "$out" >&2; fail "Bash saw PowerShell's install as locally edited"; fi
grep -Fq '= shared-one (shared) up to date' <<<"$out" || fail "Bash did not accept PowerShell's install"
[[ -e "$TMP_ROOT/ps/claude/skills-backup" ]] && fail "cross-installer refresh made a backup"

set +e
out="$(AI_DEVOPS_INSTALL_TEST_MODE=1 AI_DEVOPS_TEST_EXPECTED_REMOTE="$remote_url" \
  "$PS_CROSS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$REPO_ROOT/bin/install-ai-devops-windows.ps1" \
  -RepoPath "$(cygpath -w "$fixture" 2>/dev/null || echo "$fixture")" \
  -ClaudeHome "$(cygpath -w "$TMP_ROOT/bash/claude" 2>/dev/null || echo "$TMP_ROOT/bash/claude")" \
  -CodexHome "$(cygpath -w "$TMP_ROOT/bash/codex" 2>/dev/null || echo "$TMP_ROOT/bash/codex")" \
  -SkipGitInstall 2>&1)"
cross_rc=$?
set -e
if [ "$cross_rc" -ne 0 ]; then printf '%s\n' "$out" >&2; fail "PowerShell cross-installer refresh exited $cross_rc"; fi
if grep -Fq 'LOCAL EDITS' <<<"$out"; then printf '%s\n' "$out" >&2; fail "PowerShell saw Bash's install as locally edited"; fi
grep -Fq '= shared-one (shared) up to date' <<<"$out" || fail "PowerShell did not accept Bash's install"
[[ -e "$TMP_ROOT/bash/claude/skills-backup" ]] && fail "cross-installer refresh made a backup"
[[ "$PS_CROSS_BIN" != powershell.exe ]] || powershell.exe -NoProfile -Command '$PSVersionTable.PSVersion.Major' | tr -d '\r' | grep -qx 5 \
  || fail "cross-installer check did not run under Windows PowerShell 5.1"

echo "PASS: installer parity"
