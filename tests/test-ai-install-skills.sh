#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_file() { [[ -f "$1" ]] || fail "missing file $1"; }
assert_dir() { [[ -d "$1" ]] || fail "missing directory $1"; }
assert_absent() { [[ ! -e "$1" ]] || fail "unexpected path $1"; }

make_fixture() {
  local fixture="$1"
  mkdir -p "$fixture/bin" "$fixture/skills/claude/client-claude" \
    "$fixture/skills/codex/client-codex" "$fixture/skills/shared/shared-one" \
    "$fixture/skills/shared/synology-sharesync-triage" "$fixture/templates/system"
  cp "$REPO_ROOT/bin/ai-install-skills" "$fixture/bin/ai-install-skills"
  printf '%s\n' '---' 'name: client-claude' 'description: test' '---' > "$fixture/skills/claude/client-claude/SKILL.md"
  printf '%s\n' '---' 'name: client-codex' 'description: test' '---' > "$fixture/skills/codex/client-codex/SKILL.md"
  printf '%s\n' '---' 'name: shared-one' 'description: test' '---' > "$fixture/skills/shared/shared-one/SKILL.md"
  printf '%s\n' '---' 'name: synology-sharesync-triage' 'description: test' '---' > "$fixture/skills/shared/synology-sharesync-triage/SKILL.md"
  printf '%s\n' '# test Claude global' > "$fixture/templates/system/CLAUDE-global.md"
  printf '%s\n' '# test Codex global' > "$fixture/templates/system/AGENTS-global-codex.md"
}

run_installer() {
  local fixture="$1" claude_home="$2" codex_home="$3"
  shift 3
  mkdir -p "$codex_home"
  CLAUDE_HOME="$claude_home" CODEX_HOME="$codex_home" \
    bash "$fixture/bin/ai-install-skills" "$@"
}

echo "1/5 shared directory absent"
fixture="$TMP_ROOT/absent/repo"; claude="$TMP_ROOT/absent/claude"; codex="$TMP_ROOT/absent/codex"
make_fixture "$fixture"
rm -rf "$fixture/skills/shared"
output="$(run_installer "$fixture" "$claude" "$codex")"
assert_file "$claude/skills/client-claude/SKILL.md"
assert_file "$codex/skills/client-codex/SKILL.md"
grep -Fq '1 Claude skills + 0 shared skills installed for Claude.' <<<"$output" || fail "wrong absent-shared count"

echo "2/5 dual-client install and counts"
fixture="$TMP_ROOT/dual/repo"; claude="$TMP_ROOT/dual/claude"; codex="$TMP_ROOT/dual/codex"
make_fixture "$fixture"
output="$(run_installer "$fixture" "$claude" "$codex")"
assert_file "$claude/skills/shared-one/SKILL.md"
assert_file "$codex/skills/shared-one/SKILL.md"
grep -Fq '1 Claude skills + 2 shared skills installed for Claude.' <<<"$output" || fail "wrong Claude count"
grep -Fq '1 Codex skills + 2 shared skills installed for Codex.' <<<"$output" || fail "wrong Codex count"

echo "3/5 dry-run makes no changes"
fixture="$TMP_ROOT/dry/repo"; claude="$TMP_ROOT/dry/claude"; codex="$TMP_ROOT/dry/codex"
make_fixture "$fixture"
mkdir -p "$codex"
output="$(run_installer "$fixture" "$claude" "$codex" --dry-run)"
assert_absent "$claude/skills"
assert_absent "$codex/skills"
grep -Fq '[dry-run]' <<<"$output" || fail "dry-run actions not reported"

echo "4/5 collision fails before mutation"
fixture="$TMP_ROOT/collision/repo"; claude="$TMP_ROOT/collision/claude"; codex="$TMP_ROOT/collision/codex"
make_fixture "$fixture"
mkdir -p "$fixture/skills/shared/client-claude"
cp "$fixture/skills/claude/client-claude/SKILL.md" "$fixture/skills/shared/client-claude/SKILL.md"
mkdir -p "$codex"
if run_installer "$fixture" "$claude" "$codex" >"$TMP_ROOT/collision.out" 2>&1; then
  fail "collision unexpectedly succeeded"
fi
assert_absent "$claude/skills"
assert_absent "$codex/skills"
grep -Fq "refusing to overwrite" "$TMP_ROOT/collision.out" || fail "collision error missing"
fixture="$TMP_ROOT/collision-codex/repo"; claude="$TMP_ROOT/collision-codex/claude"; codex="$TMP_ROOT/collision-codex/codex"
make_fixture "$fixture"
mkdir -p "$fixture/skills/shared/client-codex"
cp "$fixture/skills/codex/client-codex/SKILL.md" "$fixture/skills/shared/client-codex/SKILL.md"
mkdir -p "$codex"
if run_installer "$fixture" "$claude" "$codex" >"$TMP_ROOT/collision-codex.out" 2>&1; then
  fail "Codex collision unexpectedly succeeded"
fi
assert_absent "$claude/skills"
assert_absent "$codex/skills"
grep -Fq "skills/codex" "$TMP_ROOT/collision-codex.out" || fail "Codex collision error missing"

echo "5/5 obsolete skill warns, then quarantines only by opt-in"
fixture="$TMP_ROOT/migrate/repo"; claude="$TMP_ROOT/migrate/claude"; codex="$TMP_ROOT/migrate/codex"
make_fixture "$fixture"
mkdir -p "$claude/skills/synology-sharesync-stuck-triage" "$codex/skills/synology-sharesync-stuck-triage"
printf '%s\n' old > "$claude/skills/synology-sharesync-stuck-triage/SKILL.md"
printf '%s\n' old > "$codex/skills/synology-sharesync-stuck-triage/SKILL.md"
run_installer "$fixture" "$claude" "$codex" >"$TMP_ROOT/migrate-warn.out" 2>&1
assert_dir "$claude/skills/synology-sharesync-stuck-triage"
assert_dir "$codex/skills/synology-sharesync-stuck-triage"
grep -Fq 'Re-run with --migrate-obsolete' "$TMP_ROOT/migrate-warn.out" || fail "migration warning missing"
run_installer "$fixture" "$claude" "$codex" --dry-run --migrate-obsolete >"$TMP_ROOT/migrate-preview.out" 2>&1
assert_dir "$claude/skills/synology-sharesync-stuck-triage"
assert_dir "$codex/skills/synology-sharesync-stuck-triage"
grep -Fq '[dry-run] mv' "$TMP_ROOT/migrate-preview.out" || fail "migration preview missing"
run_installer "$fixture" "$claude" "$codex" --migrate-obsolete >"$TMP_ROOT/migrate-run.out" 2>&1
assert_absent "$claude/skills/synology-sharesync-stuck-triage"
assert_absent "$codex/skills/synology-sharesync-stuck-triage"
assert_file "$claude/skills-quarantine/synology-sharesync-stuck-triage/SKILL.md"
assert_file "$codex/skills-quarantine/synology-sharesync-stuck-triage/SKILL.md"
assert_file "$claude/skills/synology-sharesync-triage/SKILL.md"
assert_file "$codex/skills/synology-sharesync-triage/SKILL.md"

echo "PASS: ai-install-skills"
