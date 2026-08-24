#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

REMOTE="$TMP/private.git"
SEED="$TMP/seed"
HOME_A="$TMP/home-a"
CLAUDE_A="$TMP/claude-a"
HUB_A="$TMP/hub-a"
LOG_A="$TMP/a.log"

git init -q --bare "$REMOTE"
git init -q "$SEED"
git -C "$SEED" config user.name test
git -C "$SEED" config user.email test@example.invalid
mkdir -p "$SEED/memory/sample"
cat > "$SEED/memory/sample/MEMORY.md" <<'EOF'
# Memory index - sample

- [hub](hub.md) - hub fact.
EOF
printf 'hub fact\n' > "$SEED/memory/sample/hub.md"
git -C "$SEED" add memory
git -C "$SEED" commit -qm seed
git -C "$SEED" branch -M main
git -C "$SEED" remote add origin "$REMOTE"
git -C "$SEED" push -q -u origin main
git --git-dir="$REMOTE" symbolic-ref HEAD refs/heads/main

mkdir -p "$CLAUDE_A/projects/C--repos-sample/memory" "$HOME_A"
cat > "$CLAUDE_A/projects/C--repos-sample/memory/MEMORY.md" <<'EOF'
# Memory index - sample

- [local](local.md) - local fact.
EOF
printf 'local fact\n' > "$CLAUDE_A/projects/C--repos-sample/memory/local.md"

sync_a() {
  HOME="$HOME_A" CLAUDE_HOME="$CLAUDE_A" \
  AI_MEMORY_TEST_MODE=1 AI_MEMORY_TEST_PRIVATE=1 \
  AI_MEMORY_TOOL_ROOT="$ROOT" AI_MEMORY_REMOTE="$REMOTE" \
  AI_MEMORY_HUB="$HUB_A" AI_MEMORY_LOG="$LOG_A" \
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.autocrlf GIT_CONFIG_VALUE_0=true \
    bash "$ROOT/bin/ai-memory-sync" "$@"
}

# A restore-from-zero home has managed skills but no Claude project memory yet.
# Pulling must validate the hub and succeed without inventing project paths or
# attempting an empty upload. An unrecognized empty home still fails closed so
# the historical wrong-HOME regression remains visible.
FRESH_HOME="$TMP/home-fresh"
FRESH_CLAUDE="$TMP/claude-fresh"
FRESH_HUB="$TMP/hub-fresh"
FRESH_LOG="$TMP/fresh.log"
FRESH_REMOTE="$TMP/fresh-private.git"
cp -a "$REMOTE" "$FRESH_REMOTE"
mkdir -p "$FRESH_HOME" "$FRESH_CLAUDE/skills"
fresh_remote_before="$(git --git-dir="$FRESH_REMOTE" rev-parse main)"
HOME="$FRESH_HOME" CLAUDE_HOME="$FRESH_CLAUDE" \
AI_MEMORY_TEST_MODE=1 AI_MEMORY_TEST_PRIVATE=1 \
AI_MEMORY_TOOL_ROOT="$ROOT" AI_MEMORY_REMOTE="$FRESH_REMOTE" \
AI_MEMORY_HUB="$FRESH_HUB" AI_MEMORY_LOG="$FRESH_LOG" \
  bash "$ROOT/bin/ai-memory-sync" sync > "$TMP/fresh.out"
[[ -d "$FRESH_HUB/.git" ]] || fail "fresh-machine seed did not clone the private hub"
grep -Fq 'fresh-machine seed complete' "$FRESH_LOG" ||
  fail "fresh-machine seed did not report its no-project state"
[[ "$(git --git-dir="$FRESH_REMOTE" rev-parse main)" == "$fresh_remote_before" ]] ||
  fail "fresh-machine seed uploaded a change despite having no project memory"
[[ "$(git --git-dir="$FRESH_REMOTE" rev-parse main)" == "$(git -C "$FRESH_HUB" rev-parse HEAD)" ]] ||
  fail "fresh-machine seed changed or diverged from the private hub"

# Forget is a hub operation and must still commit/push from a fresh machine.
# The fresh-seed early exit must never turn a tombstone into false success.
HOME="$FRESH_HOME" CLAUDE_HOME="$FRESH_CLAUDE" \
AI_MEMORY_TEST_MODE=1 AI_MEMORY_TEST_PRIVATE=1 \
AI_MEMORY_TOOL_ROOT="$ROOT" AI_MEMORY_REMOTE="$FRESH_REMOTE" \
AI_MEMORY_HUB="$FRESH_HUB" AI_MEMORY_LOG="$FRESH_LOG" \
  bash "$ROOT/bin/ai-memory-sync" forget sample hub.md 'fresh-machine deletion test' \
  > "$TMP/fresh-forget.out"
git --git-dir="$FRESH_REMOTE" show main:memory/sample/hub.md >/dev/null 2>&1 &&
  fail "fresh-machine forget reported success without removing the fact"
git --git-dir="$FRESH_REMOTE" show main:memory/sample/.forgotten |
  grep -Fq $'hub.md\t' || fail "fresh-machine forget did not publish its tombstone"

EMPTY_CLAUDE="$TMP/claude-unrecognized-empty"
mkdir -p "$EMPTY_CLAUDE"
set +e
CLAUDE_HOME="$EMPTY_CLAUDE" AI_MEMORY_HUB_ROOT="$SEED" \
  bash "$ROOT/bin/ai-sync-memory" pull > "$TMP/unrecognized-empty.out" 2>&1
empty_status=$?
set -e
[[ "$empty_status" -ne 0 ]] || fail "unrecognized empty Claude home did not fail closed"
grep -Fq 'almost certainly not the home Claude Code uses' "$TMP/unrecognized-empty.out" ||
  fail "unrecognized empty Claude home lost the wrong-home diagnosis"

MISMATCHED_CLAUDE="$TMP/claude-mismatched-with-skills"
mkdir -p "$MISMATCHED_CLAUDE/skills" \
  "$MISMATCHED_CLAUDE/projects/C--repos-not-in-hub/memory"
set +e
CLAUDE_HOME="$MISMATCHED_CLAUDE" AI_MEMORY_HUB_ROOT="$SEED" \
  bash "$ROOT/bin/ai-sync-memory" pull > "$TMP/mismatched-with-skills.out" 2>&1
mismatched_status=$?
set -e
[[ "$mismatched_status" -ne 0 ]] ||
  fail "managed home with only nonmatching project memory did not fail closed"
grep -Fq 'Every project was skipped' "$TMP/mismatched-with-skills.out" ||
  fail "managed mismatched home lost the wrong-home diagnosis"

# Exercise the wrapper's own managed-home guard independently of the child.
WRAPPER_TOOL="$TMP/wrapper-tool"
WRAPPER_HOME="$TMP/wrapper-home"
WRAPPER_HUB="$TMP/wrapper-hub"
mkdir -p "$WRAPPER_TOOL/bin" "$WRAPPER_HOME"
printf '#!/usr/bin/env bash\nexit 0\n' > "$WRAPPER_TOOL/bin/ai-sync-memory"
printf '#!/usr/bin/env bash\nexit 0\n' > "$WRAPPER_TOOL/bin/ai-memory-health"
chmod +x "$WRAPPER_TOOL/bin/ai-sync-memory" "$WRAPPER_TOOL/bin/ai-memory-health"
set +e
HOME="$WRAPPER_HOME" CLAUDE_HOME="$WRAPPER_HOME/.claude" \
AI_MEMORY_TEST_MODE=1 AI_MEMORY_TEST_PRIVATE=1 \
AI_MEMORY_TOOL_ROOT="$WRAPPER_TOOL" AI_MEMORY_REMOTE="$REMOTE" \
AI_MEMORY_HUB="$WRAPPER_HUB" AI_MEMORY_LOG="$TMP/wrapper.log" \
  bash "$ROOT/bin/ai-memory-sync" sync > "$TMP/wrapper-guard.out" 2>&1
wrapper_guard_status=$?
set -e
[[ "$wrapper_guard_status" -ne 0 ]] || fail "wrapper accepted an unmanaged empty Claude home"
grep -Fq 'is not a toolkit-managed Claude home' "$TMP/wrapper-guard.out" ||
  fail "wrapper managed-home guard lost its diagnosis"

# Reproduce a Windows working-tree index while the private Git hub stores LF.
# A hidden trailing CR must not make the same entry look new on every run.
awk '{ printf "%s\r\n", $0 }' \
  "$CLAUDE_A/projects/C--repos-sample/memory/MEMORY.md" \
  > "$CLAUDE_A/projects/C--repos-sample/memory/MEMORY.md.crlf"
mv "$CLAUDE_A/projects/C--repos-sample/memory/MEMORY.md.crlf" \
  "$CLAUDE_A/projects/C--repos-sample/memory/MEMORY.md"

sync_a sync >/dev/null
INDEX="$CLAUDE_A/projects/C--repos-sample/memory/MEMORY.md"
grep -Fq '(hub.md)' "$INDEX" || fail "machine did not receive hub index entry"
grep -Fq '(local.md)' "$INDEX" || fail "machine lost local index entry"
git --git-dir="$REMOTE" show main:memory/sample/MEMORY.md | grep -Fq '(hub.md)' || fail "hub entry vanished"
git --git-dir="$REMOTE" show main:memory/sample/MEMORY.md | grep -Fq '(local.md)' || fail "local entry did not reach hub"

converged_head="$(git --git-dir="$REMOTE" rev-parse main)"
sync_a sync >/dev/null
[[ "$(git --git-dir="$REMOTE" rev-parse main)" == "$converged_head" ]] ||
  fail "second CRLF sync created another commit"
[[ "$(git --git-dir="$REMOTE" show main:memory/sample/MEMORY.md | grep -Fc '(local.md)')" -eq 1 ]] ||
  fail "CRLF sync duplicated the local index entry"

# A duplicate-storm index must merge in one pass. The previous implementation
# launched one full-file grep per local entry, turning this fixture (and the
# 19.9 MB shared-db incident index) into quadratic work.
LARGE_CLAUDE="$TMP/claude-large"
LARGE_HUB="$TMP/hub-large"
mkdir -p "$LARGE_CLAUDE/projects/C--repos-large/memory" "$LARGE_HUB/memory/large"
for i in $(seq 1 20000); do
  printf -- '- [fact-%05d](fact-%05d.md) - fact.\n' "$i" "$i"
done > "$LARGE_HUB/memory/large/MEMORY.md"
awk '{ printf "%s\r\n", $0 }' "$LARGE_HUB/memory/large/MEMORY.md" \
  > "$LARGE_CLAUDE/projects/C--repos-large/memory/MEMORY.md"
printf '%s\r\n' '- [local-only](local-only.md) - local fact.' \
  >> "$LARGE_CLAUDE/projects/C--repos-large/memory/MEMORY.md"
if ! CLAUDE_HOME="$LARGE_CLAUDE" AI_MEMORY_HUB_ROOT="$LARGE_HUB" \
  timeout 15 bash "$ROOT/bin/ai-sync-memory" pull >/dev/null; then
  fail "large CRLF index merge did not complete within 15 seconds"
fi
LARGE_INDEX="$LARGE_CLAUDE/projects/C--repos-large/memory/MEMORY.md"
[[ "$(grep -Fc '(fact-00001.md)' "$LARGE_INDEX")" -eq 1 ]] ||
  fail "large CRLF merge duplicated an existing hub entry"
[[ "$(grep -Fc '(local-only.md)' "$LARGE_INDEX")" -eq 1 ]] ||
  fail "large CRLF merge lost or duplicated the local-only entry"

# Project matching must also be linear. Historical reviewer runs can leave
# hundreds of local memory directories and matching hub projects. The former
# nested loop canonicalized every possible pair and took hours on T16.
MANY_CLAUDE="$TMP/claude-many-projects"
MANY_HUB="$TMP/hub-many-projects"
mkdir -p "$MANY_CLAUDE/projects" "$MANY_HUB/memory"
for i in $(seq 1 500); do
  mkdir -p "$MANY_CLAUDE/projects/C--repos-local-$i/memory" \
    "$MANY_HUB/memory/hub-$i"
done
mkdir -p "$MANY_CLAUDE/projects/C--repos-shared/memory" \
  "$MANY_CLAUDE/projects/D--repos-shared/memory" \
  "$MANY_HUB/memory/shared"
printf '# Local shared\n' \
  > "$MANY_CLAUDE/projects/C--repos-shared/memory/MEMORY.md"
printf '# Second local shared\n' \
  > "$MANY_CLAUDE/projects/D--repos-shared/memory/MEMORY.md"
printf '# Hub shared\n' > "$MANY_HUB/memory/shared/MEMORY.md"
if ! CLAUDE_HOME="$MANY_CLAUDE" AI_MEMORY_HUB_ROOT="$MANY_HUB" \
  timeout 30 bash "$ROOT/bin/ai-sync-memory" pull > "$TMP/many-projects.out"; then
  fail "500-by-500 memory lookup did not complete within 30 seconds"
fi
grep -Fq '# Hub shared' \
  "$MANY_CLAUDE/projects/C--repos-shared/memory/MEMORY.md" ||
  fail "linear project lookup missed the final matching project"
grep -Fq '# Hub shared' \
  "$MANY_CLAUDE/projects/D--repos-shared/memory/MEMORY.md" ||
  fail "linear project lookup dropped a second checkout for one project"

# Explicit aliases retain the old first-declaration-wins behavior and include a
# final mapping line even when a hand-edited file has no trailing newline.
MAP_TOOL="$TMP/map-tool"
MAP_CLAUDE="$TMP/claude-map"
MAP_HUB="$TMP/hub-map"
mkdir -p "$MAP_TOOL/bin" "$MAP_TOOL/memory" \
  "$MAP_CLAUDE/projects/C--mapped/memory" \
  "$MAP_CLAUDE/projects/C--last/memory" \
  "$MAP_HUB/memory/first-project" "$MAP_HUB/memory/final-project"
cp "$ROOT/bin/ai-sync-memory" "$MAP_TOOL/bin/ai-sync-memory"
printf 'C--mapped\tfirst-project\r\nC--mapped\tsecond-project\r\nC--last\tfinal-project\r' \
  > "$MAP_TOOL/memory/project-map.tsv"
printf '# Local mapped\n' > "$MAP_CLAUDE/projects/C--mapped/memory/MEMORY.md"
printf '# Local final\n' > "$MAP_CLAUDE/projects/C--last/memory/MEMORY.md"
printf '# First wins\n' > "$MAP_HUB/memory/first-project/MEMORY.md"
printf '# Final line works\n' > "$MAP_HUB/memory/final-project/MEMORY.md"
CLAUDE_HOME="$MAP_CLAUDE" AI_MEMORY_HUB_ROOT="$MAP_HUB" \
  bash "$MAP_TOOL/bin/ai-sync-memory" pull >/dev/null
grep -Fq '# First wins' "$MAP_CLAUDE/projects/C--mapped/memory/MEMORY.md" ||
  fail "duplicate explicit map entries no longer keep the first declaration"
grep -Fq '# Final line works' "$MAP_CLAUDE/projects/C--last/memory/MEMORY.md" ||
  fail "explicit map ignored a final line without a newline"

# Empty files are valid intermediate states. Awk's NR==FNR idiom misclassifies
# the entire second file when the first file has zero records, so exercise both
# data-flow directions explicitly.
ZERO_PULL_CLAUDE="$TMP/claude-zero-pull"
ZERO_PULL_HUB="$TMP/hub-zero-pull"
mkdir -p "$ZERO_PULL_CLAUDE/projects/C--repos-zero-pull/memory" \
  "$ZERO_PULL_HUB/memory/zero-pull"
printf '%s\n' '- [local-survives](local-survives.md) - local fact.' \
  > "$ZERO_PULL_CLAUDE/projects/C--repos-zero-pull/memory/MEMORY.md"
: > "$ZERO_PULL_HUB/memory/zero-pull/MEMORY.md"
CLAUDE_HOME="$ZERO_PULL_CLAUDE" AI_MEMORY_HUB_ROOT="$ZERO_PULL_HUB" \
  bash "$ROOT/bin/ai-sync-memory" pull >/dev/null
grep -Fq '(local-survives.md)' \
  "$ZERO_PULL_CLAUDE/projects/C--repos-zero-pull/memory/MEMORY.md" ||
  fail "empty hub index erased the local index"

ZERO_PUSH_CLAUDE="$TMP/claude-zero-push"
ZERO_PUSH_HUB="$TMP/hub-zero-push"
mkdir -p "$ZERO_PUSH_CLAUDE/projects/C--repos-zero-push/memory" \
  "$ZERO_PUSH_HUB/memory/zero-push"
: > "$ZERO_PUSH_CLAUDE/projects/C--repos-zero-push/memory/MEMORY.md"
printf '%s\n' '- [hub-survives](hub-survives.md) - hub fact.' \
  > "$ZERO_PUSH_HUB/memory/zero-push/MEMORY.md"
printf 'interrupted merge scratch\n' \
  > "$ZERO_PUSH_CLAUDE/projects/C--repos-zero-push/memory/MEMORY.md.merge.123"
printf 'interrupted additions scratch\n' \
  > "$ZERO_PUSH_CLAUDE/projects/C--repos-zero-push/memory/MEMORY.md.additions.123"
printf 'interrupted tombstone scratch\n' \
  > "$ZERO_PUSH_CLAUDE/projects/C--repos-zero-push/memory/MEMORY.md.tombstone.123"
printf 'interrupted forgotten scratch\n' \
  > "$ZERO_PUSH_CLAUDE/projects/C--repos-zero-push/memory/.forgotten.tmp"
CLAUDE_HOME="$ZERO_PUSH_CLAUDE" AI_MEMORY_HUB_ROOT="$ZERO_PUSH_HUB" \
  bash "$ROOT/bin/ai-sync-memory" push >/dev/null
grep -Fq '(hub-survives.md)' "$ZERO_PUSH_HUB/memory/zero-push/MEMORY.md" ||
  fail "empty machine index erased the hub index"
[[ ! -e "$ZERO_PUSH_HUB/memory/zero-push/MEMORY.md.merge.123" &&
   ! -e "$ZERO_PUSH_HUB/memory/zero-push/MEMORY.md.additions.123" &&
   ! -e "$ZERO_PUSH_HUB/memory/zero-push/MEMORY.md.tombstone.123" &&
   ! -e "$ZERO_PUSH_HUB/memory/zero-push/.forgotten.tmp" ]] ||
  fail "interrupted merge scratch was copied as a memory fact"

# Offline fetch is a visible failure and leaves the only local fact untouched.
printf 'offline fact\n' > "$CLAUDE_A/projects/C--repos-sample/memory/offline.md"
printf '%s\n' '- [offline](offline.md) - must survive fetch failure.' >> "$INDEX"
mv "$REMOTE" "$REMOTE.offline"
set +e
sync_a sync >/dev/null 2>&1
offline_status=$?
set -e
mv "$REMOTE.offline" "$REMOTE"
[[ "$offline_status" -ne 0 ]] || fail "offline fetch returned success"
[[ -f "$CLAUDE_A/projects/C--repos-sample/memory/offline.md" ]] || fail "offline failure lost the only copy"

# A server rejection preserves the committed tree and does not perform a later
# reset/pull. The following run retries that exact commit successfully.
mkdir -p "$REMOTE/hooks"
cat > "$REMOTE/hooks/pre-receive" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$REMOTE/hooks/pre-receive"
set +e
sync_a sync >/dev/null 2>&1
reject_status=$?
set -e
[[ "$reject_status" -ne 0 ]] || fail "rejected push returned success"
[[ "$(git -C "$HUB_A" rev-list --count origin/main..HEAD)" -eq 1 ]] || fail "rejected commit was not preserved"
git --git-dir="$REMOTE" show main:memory/sample/offline.md >/dev/null 2>&1 && fail "rejected fact reached remote"
rm -f "$REMOTE/hooks/pre-receive"
sync_a sync >/dev/null
git --git-dir="$REMOTE" show main:memory/sample/offline.md >/dev/null || fail "preserved commit was not retried"

# Same-name conflicts retain both byte-distinct facts; an orphan is indexed
# automatically; a tombstone is the only operation that deletes across copies.
printf 'machine version\n' > "$CLAUDE_A/projects/C--repos-sample/memory/hub.md"
printf 'orphan fact\n' > "$CLAUDE_A/projects/C--repos-sample/memory/orphan.md"
sync_a sync >/dev/null
remote_files="$(git --git-dir="$REMOTE" ls-tree --name-only main:memory/sample)"
[[ "$remote_files" == *"hub.md"* && "$remote_files" == *"hub--"* ]] || fail "same-name conflict was overwritten"
git --git-dir="$REMOTE" show main:memory/sample/MEMORY.md | grep -Fq '(orphan.md)' || fail "orphan was not indexed"

printf 'local.md\t2026-08-21\ttest deletion\n' > "$CLAUDE_A/projects/C--repos-sample/memory/.forgotten"
rm -f "$CLAUDE_A/projects/C--repos-sample/memory/local.md"
sync_a sync >/dev/null
git --git-dir="$REMOTE" show main:memory/sample/local.md >/dev/null 2>&1 && fail "tombstoned fact survived in hub"
[[ ! -e "$CLAUDE_A/projects/C--repos-sample/memory/local.md" ]] || fail "tombstoned fact survived locally"

# Lock contention fails closed without touching either side.
mkdir "$HUB_A.lock"
set +e
sync_a sync >/dev/null 2>&1
lock_status=$?
set -e
rmdir "$HUB_A.lock"
[[ "$lock_status" -ne 0 ]] || fail "duplicate lock returned success"

bash -n "$ROOT/bin/ai-memory-sync"
bash -n "$ROOT/bin/ai-sync-memory"
echo "PASS: private memory sync converges losslessly and preserves every failure state"
