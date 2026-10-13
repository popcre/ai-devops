#!/usr/bin/env bash
# Regression: MEMORY.md index entries merge by TARGET FILE, not by line text.
#
# A machine whose local index still has OLD wordings of entries must not re-add
# every one of them after the hub was consolidated. vps2 re-grew a 4KB popdam
# index to 11KB on its first sync after consolidation; al8960ofc and edge-dev
# pushed 19-25KB ai-devops indexes until the 12KB health gate blocked sync.
# forget --prune-index only dedupes the hub copy; the next machine sync used to
# re-add the lines. Hub wording wins for any target the hub already lists;
# genuinely new local memories are still added; tombstoned targets are not
# revived; a second sync converges with no change.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

TARGET_CLAUDE="$TMP/claude-index-target"
TARGET_HUB="$TMP/hub-index-target"
mkdir -p "$TARGET_CLAUDE/projects/C--repos-target/memory" \
  "$TARGET_HUB/memory/target"
cat > "$TARGET_HUB/memory/target/MEMORY.md" <<'EOF'
# Memory index - target

- [alpha](alpha.md) - consolidated alpha wording.
- [beta](beta.md) - consolidated beta wording.
EOF
printf 'alpha\n' > "$TARGET_HUB/memory/target/alpha.md"
printf 'beta\n' > "$TARGET_HUB/memory/target/beta.md"
cat > "$TARGET_CLAUDE/projects/C--repos-target/memory/MEMORY.md" <<'EOF'
# Memory index - target

- [alpha-old](alpha.md) - stale machine wording for alpha.
- [beta-old](beta.md) - stale machine wording for beta.
- [gamma](gamma.md) - genuinely new local memory.
EOF
printf 'gamma\n' > "$TARGET_CLAUDE/projects/C--repos-target/memory/gamma.md"

target_pull() {
  CLAUDE_HOME="$TARGET_CLAUDE" AI_MEMORY_HUB_ROOT="$TARGET_HUB" \
    bash "$ROOT/bin/ai-sync-memory" pull >/dev/null
}
target_push() {
  CLAUDE_HOME="$TARGET_CLAUDE" AI_MEMORY_HUB_ROOT="$TARGET_HUB" \
    bash "$ROOT/bin/ai-sync-memory" push >/dev/null
}

# (1) Stale reworded local lines are dropped; the hub wording wins.
target_pull
TINDEX="$TARGET_CLAUDE/projects/C--repos-target/memory/MEMORY.md"
grep -Fq 'consolidated alpha wording' "$TINDEX" ||
  fail "target merge dropped the hub's alpha wording"
if grep -Fq 'stale machine wording for alpha' "$TINDEX"; then
  fail "target merge re-added a stale reworded alpha line"
fi
if grep -Fq 'stale machine wording for beta' "$TINDEX"; then
  fail "target merge re-added a stale reworded beta line"
fi
[[ "$(grep -Fc '(alpha.md)' "$TINDEX")" -eq 1 ]] ||
  fail "target merge left more than one alpha.md index line"
[[ "$(grep -Fc '(beta.md)' "$TINDEX")" -eq 1 ]] ||
  fail "target merge left more than one beta.md index line"

# (2) A new local memory's line is kept.
grep -Fq '(gamma.md)' "$TINDEX" ||
  fail "target merge dropped a genuinely new local memory line"
grep -Fq 'genuinely new local memory' "$TINDEX" ||
  fail "target merge rewrote a new local memory's index wording"

# Push publishes gamma without reviving stale wordings or rewriting the hub.
target_push
HINDEX="$TARGET_HUB/memory/target/MEMORY.md"
grep -Fq '(gamma.md)' "$HINDEX" ||
  fail "target merge did not publish a new local memory to the hub"
grep -Fq 'consolidated alpha wording' "$HINDEX" ||
  fail "push overwrote the hub's consolidated alpha wording"
if grep -Fq 'stale machine wording' "$HINDEX"; then
  fail "push published a stale reworded line to the hub"
fi

# (3) A tombstoned target is not revived.
printf 'delta\n' > "$TARGET_HUB/memory/target/delta.md"
printf '%s\n' '- [delta](delta.md) - delta to be forgotten.' >> "$HINDEX"
printf '%s\n' '- [delta-old](delta.md) - stale delta wording.' >> "$TINDEX"
printf 'delta stale\n' > "$TARGET_CLAUDE/projects/C--repos-target/memory/delta.md"
printf 'delta.md\t2026-10-12\ttest tombstone\n' \
  > "$TARGET_HUB/memory/target/.forgotten"
rm -f "$TARGET_HUB/memory/target/delta.md"
awk 'index($0, "(delta.md)") == 0' "$HINDEX" > "$HINDEX.tomb" &&
  mv -f "$HINDEX.tomb" "$HINDEX"
target_pull
if grep -Fq '(delta.md)' "$TINDEX"; then
  fail "pull revived a tombstoned target line"
fi
target_push
if grep -Fq '(delta.md)' "$HINDEX"; then
  fail "push revived a tombstoned target line"
fi
[[ ! -e "$TARGET_HUB/memory/target/delta.md" ]] ||
  fail "push resurrected a tombstoned memory file"

# (4) A second sync converges with no change.
cp -a "$TINDEX" "$TMP/target-machine.before"
cp -a "$HINDEX" "$TMP/target-hub.before"
target_pull
target_push
cmp -s "$TMP/target-machine.before" "$TINDEX" ||
  fail "second sync changed the machine index after convergence"
cmp -s "$TMP/target-hub.before" "$HINDEX" ||
  fail "second sync changed the hub index after convergence"

bash -n "$ROOT/bin/ai-sync-memory"
echo "PASS: MEMORY.md index entries merge by target file and converge"
