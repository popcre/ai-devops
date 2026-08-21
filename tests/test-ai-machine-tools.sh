#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
target="$tmp/bin"
bash "$repo/bin/install-machine-tools.sh" --target-dir "$target" >/dev/null
bash "$repo/bin/ai-machine-tools-doctor" --platform ubuntu --target-dir "$target" | grep -q 'OK local AI command'
for n in ai-grok-review ai-grok-implement ai-gemini ai-kimi ai-qwen ai-deepseek-agent ai-glm ai-headroom; do [[ -e "$target/$n" ]]; done
# Every bash+cmd tool must be EXECUTABLE in git. The Ubuntu installer only
# symlinks and prints "OK installed", so a 100644 source installs "successfully"
# and then dies with Permission denied on first use. ai-headroom shipped that
# way once (chmod +x on Windows never reaches the git index).
while IFS=$'	' read -r name source form _rest; do
  [[ -z "$name" || "$name" == \#* || "$form" != "bash+cmd" ]] && continue
  mode="$(git -C "$repo" ls-files -s -- "$source" | awk '{print $1}')"
  [[ "$mode" == "100755" ]] || { echo "NOT EXECUTABLE in git: $source (mode $mode)" >&2; exit 1; }
done < "$repo/config/machine-tools.tsv"
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
