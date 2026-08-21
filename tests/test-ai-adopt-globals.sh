#!/usr/bin/env bash
# Offline tests for bin/ai-adopt-globals.
#
# The behaviour that matters is NOT "did it exit 0" — it is:
#   * a machine section is detected, saved, and restored byte-identically;
#   * a machine with no machine section is handled without inventing one;
#   * an undetectable boundary never causes a silent guess;
#   * the installed body ends up exactly equal to the repo template.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

TEMPLATE_CLAUDE=$'# Global rules\n\nBody line one.\nBody line two.\n'
TEMPLATE_CODEX=$'# Codex global rules\n\nCodex body.\n'
SECTION_CLAUDE=$'## testbox — dev machine (machine-specific; not from the hub template)\n\n- A fact that exists nowhere else.\n- Another one.\n'
SECTION_CODEX=$'# Machine facts — testbox\n\n- Codex-side machine fact.\n'

make_fixture() {
  local fixture=$1
  mkdir -p "$fixture/bin" "$fixture/templates/system" "$fixture/config" \
           "$fixture/skills/shared/shared-one"
  cp "$REPO_ROOT/bin/ai-install-skills" "$fixture/bin/ai-install-skills"
  cp "$REPO_ROOT/bin/ai-adopt-globals"  "$fixture/bin/ai-adopt-globals"
  cp "$REPO_ROOT/config/retired-skills.txt" "$fixture/config/retired-skills.txt"
  printf '%s\n' '---' 'name: shared-one' 'description: test' '---' \
    > "$fixture/skills/shared/shared-one/SKILL.md"
  printf '%s' "$TEMPLATE_CLAUDE" > "$fixture/templates/system/CLAUDE-global.md"
  printf '%s' "$TEMPLATE_CODEX"  > "$fixture/templates/system/AGENTS-global-codex.md"
}

run_adopt() {
  local fixture=$1 claude_home=$2 codex_home=$3; shift 3
  mkdir -p "$claude_home" "$codex_home"
  AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE=1 HOME="$BASE_BACKUP_HOME" USERPROFILE= \
  CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" \
    bash "$fixture/bin/ai-adopt-globals" "$@" 2>&1
}

# The script derives the machine name from `hostname`. Put a stub first on PATH
# so the fixture headings are recognisable on any real machine.
BASE_BACKUP_HOME="$TMP_ROOT/fakehome"
mkdir -p "$BASE_BACKUP_HOME"
STUB_BIN="$TMP_ROOT/stub-bin"
mkdir -p "$STUB_BIN"
printf '%s\n' '#!/usr/bin/env bash' 'echo testbox' > "$STUB_BIN/hostname"
chmod +x "$STUB_BIN/hostname"
export PATH="$STUB_BIN:$PATH"

echo "1/8 machine section is detected, saved and restored byte-identically"
fixture="$TMP_ROOT/keep/repo"; claude="$TMP_ROOT/keep/claude"; codex="$TMP_ROOT/keep/codex"
make_fixture "$fixture"; mkdir -p "$claude" "$codex"
printf '%s\n---\n\n%s' "$TEMPLATE_CLAUDE" "$SECTION_CLAUDE" > "$claude/CLAUDE.md"
printf '%s\n---\n\n%s' "$TEMPLATE_CODEX"  "$SECTION_CODEX"  > "$codex/AGENTS.md"
output="$(run_adopt "$fixture" "$claude" "$codex")" || fail "adopt exited non-zero: $output"
grep -Fq 'machine section restored and diffs CLEAN' <<<"$output" \
  || fail "no clean-restore line: $output"
grep -Fq 'A fact that exists nowhere else.' "$claude/CLAUDE.md" \
  || fail "Claude machine section lost"
grep -Fq 'Codex-side machine fact.' "$codex/AGENTS.md" \
  || fail "Codex machine section lost"
grep -Fq 'Body line two.' "$claude/CLAUDE.md" || fail "repo body not installed"

echo "2/8 installed body equals the repo template exactly"
grep -Fq 'installed body matches the repo template exactly' <<<"$output" \
  || fail "body verification did not run or did not pass: $output"

echo "3/8 a machine with no machine section is handled without inventing one"
fixture="$TMP_ROOT/none/repo"; claude="$TMP_ROOT/none/claude"; codex="$TMP_ROOT/none/codex"
make_fixture "$fixture"; mkdir -p "$claude" "$codex"
printf '%s\nAn old locally-edited line.\n' "$TEMPLATE_CLAUDE" > "$claude/CLAUDE.md"
printf '%s' "$TEMPLATE_CODEX" > "$codex/AGENTS.md"
output="$(run_adopt "$fixture" "$claude" "$codex")" || fail "adopt exited non-zero: $output"
grep -Fq 'no machine section found' <<<"$output" || fail "did not report the absent section: $output"
grep -Fq 'An old locally-edited line.' <<<"$output" \
  || fail "did not show the tail so a human can judge it: $output"
grep -Fq 'nothing to re-append' <<<"$output" || fail "did not say it appended nothing: $output"
diff "$claude/CLAUDE.md" "$fixture/templates/system/CLAUDE-global.md" >/dev/null \
  || fail "installed global is not exactly the template when there is no section"

echo "4/8 --dry-run changes nothing"
fixture="$TMP_ROOT/dry/repo"; claude="$TMP_ROOT/dry/claude"; codex="$TMP_ROOT/dry/codex"
make_fixture "$fixture"; mkdir -p "$claude" "$codex"
printf '%s\n---\n\n%s' "$TEMPLATE_CLAUDE" "$SECTION_CLAUDE" > "$claude/CLAUDE.md"
before="$(cat "$claude/CLAUDE.md")"
output="$(run_adopt "$fixture" "$claude" "$codex" --dry-run)" || fail "dry-run exited non-zero: $output"
grep -Fq 'Nothing was changed.' <<<"$output" || fail "dry-run did not say so: $output"
[[ "$(cat "$claude/CLAUDE.md")" == "$before" ]] || fail "dry-run modified the global"
[[ ! -d "$claude/skills" ]] || fail "dry-run installed skills"

echo "5/8 originals are always recoverable"
fixture="$TMP_ROOT/backup/repo"; claude="$TMP_ROOT/backup/claude"; codex="$TMP_ROOT/backup/codex"
home="$TMP_ROOT/backup/home"
make_fixture "$fixture"; mkdir -p "$claude" "$codex" "$home"
printf '%s\n---\n\n%s' "$TEMPLATE_CLAUDE" "$SECTION_CLAUDE" > "$claude/CLAUDE.md"
printf '%s' "$TEMPLATE_CODEX" > "$codex/AGENTS.md"
AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE=1 HOME="$home" USERPROFILE= \
  CLAUDE_HOME="$claude" CODEX_HOME="$codex" \
  bash "$fixture/bin/ai-adopt-globals" >/dev/null 2>&1 || fail "adopt exited non-zero"
found="$(find "$home/.ai-globals-backup" -name 'Claude-BEFORE.md' | head -n 1)"
[[ -n "$found" ]] || fail "no timestamped backup of the original Claude global"
grep -Fq 'A fact that exists nowhere else.' "$found" || fail "backup does not hold the original"

echo "6/8 an interleaved tail keeps machine facts and drops re-synced template blocks"
# This is albt16's real shape: machine atlas, a local standing addition, then
# several blocks pasted in by earlier template syncs whose text the repo
# template now carries. Note the atlas heading names OTHER machines, so hostname
# matching alone would report "no machine section" on a file that has one.
fixture="$TMP_ROOT/interleaved/repo"; claude="$TMP_ROOT/interleaved/claude"; codex="$TMP_ROOT/interleaved/codex"
make_fixture "$fixture"; mkdir -p "$claude" "$codex"
printf '%s\n' '# Codex global rules' '' 'Codex body.' '' \
  '# Machine atlas - 916 ("916-alien") and t16 and 4837 - Windows 11 dev machines' '' \
  '- dflow working copies live on D: here.' '' \
  '# Local standing addition retained from previous AGENTS.md' '' \
  '## Host changes route through Ansible' '' \
  '- Never hand-edit the box.' '' \
  '## Production infrastructure safety (absolute rule - added from ai-devops template sync)' '' \
  '- Duplicated safety text the template already carries.' '' \
  '# Response Style' '' \
  '## Rules' '' \
  '- A sub-section of a block the template owns.' \
  > "$codex/AGENTS.md"
printf '%s\n' '# Codex global rules' '' 'Codex body.' '' '# Response Style' '' 'Talk plainly.' \
  > "$fixture/templates/system/AGENTS-global-codex.md"
interleaved_home="$TMP_ROOT/interleaved/home"; mkdir -p "$interleaved_home"
output="$(AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE=1 HOME="$interleaved_home" USERPROFILE= \
  CLAUDE_HOME="$claude" CODEX_HOME="$codex" \
  bash "$fixture/bin/ai-adopt-globals" 2>&1)" || fail "adopt exited non-zero: $output"
grep -Fq 'KEPT:    # Machine atlas' <<<"$output" || fail "machine atlas not kept: $output"
grep -Fq 'KEPT:    # Local standing addition' <<<"$output" || fail "local addition not kept: $output"
grep -Fq 'KEPT:    ## Host changes route through Ansible' <<<"$output" || fail "local sub-section not kept"
grep -Fq 'DROPPED (declares itself a template sync): ## Production infrastructure safety' <<<"$output" \
  || fail "self-declared template sync not dropped: $output"
grep -Fq 'DROPPED (the hub template now owns this heading): # Response Style' <<<"$output" \
  || fail "template-owned heading not dropped: $output"
grep -Fq 'dflow working copies live on D: here.' "$codex/AGENTS.md" || fail "machine fact lost"
grep -Fq 'Never hand-edit the box.' "$codex/AGENTS.md" || fail "local standing addition lost"
grep -Fq 'Duplicated safety text' "$codex/AGENTS.md" && fail "re-synced template block was re-appended"
grep -Fq 'A sub-section of a block the template owns.' "$codex/AGENTS.md" \
  && fail "sub-section of a dropped heading was re-appended"

echo "7/8 a dropped block is still recoverable in the backup"
found="$(find "$interleaved_home/.ai-globals-backup" -name 'Codex-BEFORE.md' | head -n 1)"
[[ -n "$found" ]] || fail "no backup of the original Codex global"
grep -Fq 'Duplicated safety text' "$found" || fail "backup does not hold the dropped block"

echo "8/8 an old installed sync skill adopts globals on its first post-pull install"
fixture="$TMP_ROOT/bootstrap/repo"; claude="$TMP_ROOT/bootstrap/claude"; codex="$TMP_ROOT/bootstrap/codex"
home="$TMP_ROOT/bootstrap/home"
make_fixture "$fixture"
mkdir -p "$fixture/skills/claude/sync-dotfiles" "$claude/skills/sync-dotfiles" "$codex" "$home"
printf '%s\n' '---' 'name: sync-dotfiles' 'description: current test skill' '---' \
  'Run bin/ai-adopt-globals during every sync.' \
  > "$fixture/skills/claude/sync-dotfiles/SKILL.md"
printf '%s\n' '---' 'name: sync-dotfiles' 'description: old test skill' '---' \
  'Run bin/ai-install-skills during every sync.' \
  > "$claude/skills/sync-dotfiles/SKILL.md"
: > "$claude/skills/sync-dotfiles/.ai-devops-managed"
printf '%s\n' '# Old Claude global' 'stale body' > "$claude/CLAUDE.md"
printf '%s\n' '# Old Codex global' 'stale body' > "$codex/AGENTS.md"
output="$(AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE=1 HOME="$home" USERPROFILE= \
  CLAUDE_HOME="$claude" CODEX_HOME="$codex" \
  bash "$fixture/bin/ai-install-skills" 2>&1)" || fail "bootstrap install failed: $output"
grep -Fq 'First-sync bridge: adopting current global instructions safely.' <<<"$output" \
  || fail "first-sync bridge did not run: $output"
diff "$claude/CLAUDE.md" "$fixture/templates/system/CLAUDE-global.md" >/dev/null \
  || fail "first-sync bridge did not adopt the Claude global"
diff "$codex/AGENTS.md" "$fixture/templates/system/AGENTS-global-codex.md" >/dev/null \
  || fail "first-sync bridge did not adopt the Codex global"
output="$(AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE=1 HOME="$home" USERPROFILE= \
  CLAUDE_HOME="$claude" CODEX_HOME="$codex" \
  bash "$fixture/bin/ai-install-skills" 2>&1)" || fail "second install failed: $output"
grep -Fq 'First-sync bridge:' <<<"$output" && fail "one-time bridge ran again"

echo "ALL TESTS PASSED"
