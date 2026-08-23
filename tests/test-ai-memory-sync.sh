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
