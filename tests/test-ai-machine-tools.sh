#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
target="$tmp/bin"
bash "$repo/bin/install-machine-tools.sh" --target-dir "$target" >/dev/null
bash "$repo/bin/ai-machine-tools-doctor" --platform ubuntu --target-dir "$target" | grep -q 'OK local AI command'
for n in ai-grok-review ai-grok-implement ai-kimi ai-deepseek-agent ai-glm; do [[ -e "$target/$n" ]]; done
bash "$repo/bin/install-machine-tools.sh" --target-dir "$target" >/dev/null
rm "$target/ai-kimi"
if bash "$repo/bin/ai-machine-tools-doctor" --platform ubuntu --target-dir "$target" >"$tmp/out" 2>&1; then exit 1; fi
grep -q 'ai-kimi' "$tmp/out"
touch "$target/ai-kimi"
if bash "$repo/bin/install-machine-tools.sh" --target-dir "$target" >"$tmp/conflict" 2>&1; then exit 1; fi
grep -q 'refusing to replace unrelated file' "$tmp/conflict"
grep -q $'ai-glm\tbin/ai-glm\tcmd-only-external\tyes\tnone\tsetup-opencode-glm.ps1' "$repo/config/machine-tools.tsv"
grep -q 'install-machine-tools.ps1' "$repo/bin/setup-machine.ps1"
! grep -q 'foreach (\$grokWrapper' "$repo/bin/setup-machine.ps1"
grep -q "SYNC INCOMPLETE — do not report success; rerun 'sync my dotfiles'." "$repo/bin/ai-install-skills"
for skill in "$repo/skills/claude/sync-dotfiles/SKILL.md" "$repo/skills/codex/codex-sync-dotfiles/SKILL.md"; do
  grep -q 'ai-machine-tools-doctor' "$skill"; grep -q 'install-machine-tools' "$skill"
done
grep -q 'would reconcile and verify local AI command launchers' "$repo/bin/ai-install-skills"
grep -q 'if \$DRY_RUN; then' "$repo/bin/ai-install-skills"
for forbidden in 'op-service-account' 'mcp-launch' 'ai-sync-memory' 'apt-get' 'ai-glm doctor'; do
  ! grep -q "$forbidden" "$repo/bin/install-machine-tools.ps1" "$repo/bin/install-machine-tools.sh"
done
echo 'PASS: machine tool catalog, repair, doctor, bootstrap, and skill contracts'
