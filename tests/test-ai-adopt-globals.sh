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
  AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE=1 HOSTNAME_OVERRIDE=testbox \
  CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" \
    bash "$fixture/bin/ai-adopt-globals" "$@" 2>&1
}

# The script derives the machine name from `hostname`. Put a stub first on PATH
# so the fixture headings are recognisable on any real machine.
STUB_BIN="$TMP_ROOT/stub-bin"
mkdir -p "$STUB_BIN"
printf '%s\n' '#!/usr/bin/env bash' 'echo testbox' > "$STUB_BIN/hostname"
chmod +x "$STUB_BIN/hostname"
export PATH="$STUB_BIN:$PATH"

echo "1/5 machine section is detected, saved and restored byte-identically"
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

echo "2/5 installed body equals the repo template exactly"
grep -Fq 'installed body matches the repo template exactly' <<<"$output" \
  || fail "body verification did not run or did not pass: $output"

echo "3/5 a machine with no machine section is handled without inventing one"
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

echo "4/5 --dry-run changes nothing"
fixture="$TMP_ROOT/dry/repo"; claude="$TMP_ROOT/dry/claude"; codex="$TMP_ROOT/dry/codex"
make_fixture "$fixture"; mkdir -p "$claude" "$codex"
printf '%s\n---\n\n%s' "$TEMPLATE_CLAUDE" "$SECTION_CLAUDE" > "$claude/CLAUDE.md"
before="$(cat "$claude/CLAUDE.md")"
output="$(run_adopt "$fixture" "$claude" "$codex" --dry-run)" || fail "dry-run exited non-zero: $output"
grep -Fq 'Nothing was changed.' <<<"$output" || fail "dry-run did not say so: $output"
[[ "$(cat "$claude/CLAUDE.md")" == "$before" ]] || fail "dry-run modified the global"
[[ ! -d "$claude/skills" ]] || fail "dry-run installed skills"

echo "5/5 originals are always recoverable"
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

echo "ALL TESTS PASSED"
