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
  mkdir -p "$fixture/config"
  cp "$REPO_ROOT/config/retired-skills.txt" "$fixture/config/retired-skills.txt"
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

echo "1/9 shared directory absent"
fixture="$TMP_ROOT/absent/repo"; claude="$TMP_ROOT/absent/claude"; codex="$TMP_ROOT/absent/codex"
make_fixture "$fixture"
rm -rf "$fixture/skills/shared"
output="$(run_installer "$fixture" "$claude" "$codex")"
assert_file "$claude/skills/client-claude/SKILL.md"
assert_file "$codex/skills/client-codex/SKILL.md"
grep -Fq '1 Claude skills + 0 shared skills installed for Claude.' <<<"$output" || fail "wrong absent-shared count"

echo "2/9 dual-client install and counts"
fixture="$TMP_ROOT/dual/repo"; claude="$TMP_ROOT/dual/claude"; codex="$TMP_ROOT/dual/codex"
make_fixture "$fixture"
output="$(run_installer "$fixture" "$claude" "$codex")"
assert_file "$claude/skills/shared-one/SKILL.md"
assert_file "$codex/skills/shared-one/SKILL.md"
grep -Fq '1 Claude skills + 2 shared skills installed for Claude.' <<<"$output" || fail "wrong Claude count"
grep -Fq '1 Codex skills + 2 shared skills installed for Codex.' <<<"$output" || fail "wrong Codex count"

echo "3/9 dry-run makes no changes"
fixture="$TMP_ROOT/dry/repo"; claude="$TMP_ROOT/dry/claude"; codex="$TMP_ROOT/dry/codex"
make_fixture "$fixture"
mkdir -p "$codex"
output="$(run_installer "$fixture" "$claude" "$codex" --dry-run)"
assert_absent "$claude/skills"
assert_absent "$codex/skills"
grep -Fq '[dry-run]' <<<"$output" || fail "dry-run actions not reported"

echo "4/9 collision fails before mutation"
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

echo "5/9 orphans quarantine by default, marker-scoped"
fixture="$TMP_ROOT/migrate/repo"; claude="$TMP_ROOT/migrate/claude"; codex="$TMP_ROOT/migrate/codex"
make_fixture "$fixture"
# Three kinds of installed skill the repo no longer ships:
#   pre-marker  - unmarked, but named in config/retired-skills.txt (migration list)
#   marked      - stamped by an earlier ai-devops run, so ours to retire
#   vendor      - unmarked and unknown (e.g. Codex's own playwright): never touched
for home in "$claude" "$codex"; do
  for skill in synology-sharesync-stuck-triage marked-orphan vendor-skill; do
    mkdir -p "$home/skills/$skill"
    echo old > "$home/skills/$skill/SKILL.md"
  done
  : > "$home/skills/marked-orphan/.ai-devops-managed"
done

# --keep-orphans opts out: everything stays active and the warning is loud.
run_installer "$fixture" "$claude" "$codex" --keep-orphans >"$TMP_ROOT/keep.out" 2>&1
grep -Fq 'retired Claude skill left active' "$TMP_ROOT/keep.out" || fail "keep-orphans Claude warning missing"
grep -Fq 'retired Codex skill left active' "$TMP_ROOT/keep.out" || fail "keep-orphans Codex warning missing"
for home in "$claude" "$codex"; do
  assert_dir "$home/skills/synology-sharesync-stuck-triage"
  assert_dir "$home/skills/marked-orphan"
  assert_absent "$home/skills-quarantine"
done

# --dry-run previews the moves and changes nothing. --migrate-obsolete is a
# retired flag kept as an accepted no-op, so older docs/scripts still work.
run_installer "$fixture" "$claude" "$codex" --dry-run --migrate-obsolete >"$TMP_ROOT/preview.out" 2>&1
grep -Fq '[dry-run] mv' "$TMP_ROOT/preview.out" || fail "quarantine preview missing"
for home in "$claude" "$codex"; do
  assert_dir "$home/skills/synology-sharesync-stuck-triage"
  assert_dir "$home/skills/marked-orphan"
  assert_absent "$home/skills-quarantine"
done

# Default run (no flag): both of ours are quarantined, the vendor skill is not.
run_installer "$fixture" "$claude" "$codex" >"$TMP_ROOT/prune.out" 2>&1
for home in "$claude" "$codex"; do
  assert_absent "$home/skills/synology-sharesync-stuck-triage"
  assert_absent "$home/skills/marked-orphan"
  assert_file "$home/skills-quarantine/synology-sharesync-stuck-triage/SKILL.md"
  assert_file "$home/skills-quarantine/marked-orphan/SKILL.md"
  assert_file "$home/skills/vendor-skill/SKILL.md"
  assert_file "$home/skills/synology-sharesync-triage/SKILL.md"
  assert_file "$home/skills/shared-one/SKILL.md"
done

# Re-running must be safe even though the quarantine destinations now exist.
run_installer "$fixture" "$claude" "$codex" >"$TMP_ROOT/prune2.out" 2>&1
for home in "$claude" "$codex"; do
  assert_file "$home/skills-quarantine/synology-sharesync-stuck-triage/SKILL.md"
  assert_file "$home/skills/vendor-skill/SKILL.md"
done

echo "6/9 reconciliation fixture matrix: absent, identical, extended, conflicting"
fixture="$TMP_ROOT/matrix/repo"; claude="$TMP_ROOT/matrix/claude"; codex="$TMP_ROOT/matrix/codex"
make_fixture "$fixture"
# absent: nothing installed yet -> full install, and the marker records hashes.
run_installer "$fixture" "$claude" "$codex" >"$TMP_ROOT/m1.out" 2>&1
grep -Fq '+ client-claude (Claude) install' "$TMP_ROOT/m1.out" || fail "absent not classified as install"
grep -q '^[0-9a-f]\{64\}  SKILL.md$' "$claude/skills/client-claude/.ai-devops-managed" ||
  fail "marker does not record the installed file hash"

# identical: a second run must classify everything as up to date and write nothing.
before="$(find "$claude/skills" "$codex/skills" -type f -exec sha256sum {} + | sort)"
run_installer "$fixture" "$claude" "$codex" >"$TMP_ROOT/m2.out" 2>&1
grep -Fq '= client-claude (Claude) up to date' "$TMP_ROOT/m2.out" || fail "identical not classified"
grep -Fq '~ ' "$TMP_ROOT/m2.out" && fail "second apply reported an update"
after="$(find "$claude/skills" "$codex/skills" -type f -exec sha256sum {} + | sort)"
[[ "$before" == "$after" ]] || fail "second apply changed files (not idempotent)"

# locally extended: a file the repo does not ship must survive an update.
echo 'local note' > "$claude/skills/client-claude/LOCAL-NOTES.md"
printf '%s\n' '---' 'name: client-claude' 'description: test v2' '---' \
  > "$fixture/skills/claude/client-claude/SKILL.md"
run_installer "$fixture" "$claude" "$codex" >"$TMP_ROOT/m3.out" 2>&1
grep -Fq '~ client-claude (Claude) update' "$TMP_ROOT/m3.out" || fail "source change not classified as update"
assert_file "$claude/skills/client-claude/LOCAL-NOTES.md"
grep -Fq 'description: test v2' "$claude/skills/client-claude/SKILL.md" || fail "update did not land"
assert_absent "$claude/skills-backup/client-claude"

# locally conflicting: an edited installed file is backed up before replacement.
echo 'hand edited' >> "$claude/skills/client-claude/SKILL.md"
printf '%s\n' '---' 'name: client-claude' 'description: test v3' '---' \
  > "$fixture/skills/claude/client-claude/SKILL.md"
run_installer "$fixture" "$claude" "$codex" >"$TMP_ROOT/m4.out" 2>&1
grep -Fq 'LOCAL EDITS' "$TMP_ROOT/m4.out" || fail "local edit not detected"
grep -Fq 'hand edited' "$claude/skills-backup/client-claude/SKILL.md" || fail "local edit not backed up"
grep -Fq 'description: test v3' "$claude/skills/client-claude/SKILL.md" || fail "conflicting update did not land"
assert_file "$claude/skills-backup/client-claude/LOCAL-NOTES.md"

echo "7/9 unmanaged directory is backed up before adoption, dropped files removed"
fixture="$TMP_ROOT/unmanaged/repo"; claude="$TMP_ROOT/unmanaged/claude"; codex="$TMP_ROOT/unmanaged/codex"
make_fixture "$fixture"
mkdir -p "$claude/skills/client-claude"
echo 'someone elses copy' > "$claude/skills/client-claude/SKILL.md"
run_installer "$fixture" "$claude" "$codex" >"$TMP_ROOT/u1.out" 2>&1
grep -Fq 'ai-devops never installed it' "$TMP_ROOT/u1.out" || fail "unmanaged directory not reported"
grep -Fq 'someone elses copy' "$claude/skills-backup/client-claude/SKILL.md" || fail "unmanaged copy not backed up"
# A file we installed and the repo later dropped is removed; unowned files are not.
echo 'x' > "$fixture/skills/claude/client-claude/EXTRA.md"
run_installer "$fixture" "$claude" "$codex" >/dev/null 2>&1
assert_file "$claude/skills/client-claude/EXTRA.md"
rm "$fixture/skills/claude/client-claude/EXTRA.md"
echo 'mine' > "$claude/skills/client-claude/UNOWNED.md"
run_installer "$fixture" "$claude" "$codex" >/dev/null 2>&1
assert_absent "$claude/skills/client-claude/EXTRA.md"
assert_file "$claude/skills/client-claude/UNOWNED.md"

echo "8/9 dry-run previews the classification and writes nothing"
fixture="$TMP_ROOT/preview2/repo"; claude="$TMP_ROOT/preview2/claude"; codex="$TMP_ROOT/preview2/codex"
make_fixture "$fixture"
run_installer "$fixture" "$claude" "$codex" >/dev/null 2>&1
echo 'hand edited' >> "$claude/skills/client-claude/SKILL.md"
printf '%s\n' '---' 'name: client-claude' 'description: preview' '---' \
  > "$fixture/skills/claude/client-claude/SKILL.md"
before="$(find "$claude" -type f -exec sha256sum {} + | sort)"
run_installer "$fixture" "$claude" "$codex" --dry-run >"$TMP_ROOT/p1.out" 2>&1
grep -Fq 'LOCAL EDITS' "$TMP_ROOT/p1.out" || fail "dry-run did not classify the local edit"
grep -Fq 'backup:' "$TMP_ROOT/p1.out" || fail "dry-run did not name the backup path"
after="$(find "$claude" -type f -exec sha256sum {} + | sort)"
[[ "$before" == "$after" ]] || fail "dry-run wrote to disk"
assert_absent "$claude/skills-backup"

echo "9/9 globals: never clobbered without --adopt-globals, backed up with it"
fixture="$TMP_ROOT/globals/repo"; claude="$TMP_ROOT/globals/claude"; codex="$TMP_ROOT/globals/codex"
make_fixture "$fixture"
run_installer "$fixture" "$claude" "$codex" >/dev/null 2>&1
grep -Fq '# test Claude global' "$claude/CLAUDE.md" || fail "global not seeded when absent"
printf '%s\n' '# test Claude global' '## machine-specific section' > "$claude/CLAUDE.md"
run_installer "$fixture" "$claude" "$codex" >"$TMP_ROOT/g1.out" 2>&1
grep -Fq 'NOT overwriting' "$TMP_ROOT/g1.out" || fail "differing global was not protected"
grep -Fq 'machine-specific section' "$claude/CLAUDE.md" || fail "global was clobbered by default"
run_installer "$fixture" "$claude" "$codex" --adopt-globals --dry-run >"$TMP_ROOT/g2.out" 2>&1
grep -Fq 'machine-specific section' "$claude/CLAUDE.md" || fail "dry-run adopted the global"
assert_absent "$claude/globals-backup"
run_installer "$fixture" "$claude" "$codex" --adopt-globals >"$TMP_ROOT/g3.out" 2>&1
grep -Fq 'machine-specific section' "$claude/globals-backup/CLAUDE.md" || fail "old global not backed up"
grep -Fq 'machine-specific section' "$claude/CLAUDE.md" && fail "--adopt-globals did not replace the global"
grep -Fq 'restore with' "$TMP_ROOT/g3.out" || fail "restore hint missing"

echo "PASS: ai-install-skills"
