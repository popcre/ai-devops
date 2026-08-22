#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

FIXTURE="$TMP/fixture"
LOCAL="$TMP/claude"
mkdir -p "$FIXTURE/bin" "$FIXTURE/memory/ai-devops" \
  "$LOCAL/projects/C--repos-ai-devops/memory"
cp "$ROOT/bin/ai-sync-memory" "$FIXTURE/bin/ai-sync-memory"
chmod +x "$FIXTURE/bin/ai-sync-memory"

cat > "$FIXTURE/memory/ai-devops/MEMORY.md" <<'EOF'
# Memory index

- [Hub entry](hub.md) -- from the former hub.
EOF
printf 'hub fact\n' > "$FIXTURE/memory/ai-devops/hub.md"

cat > "$LOCAL/projects/C--repos-ai-devops/memory/MEMORY.md" <<'EOF'
# Memory index

- [Local entry](local.md) -- must survive a pull.
EOF
printf 'local fact\n' > "$LOCAL/projects/C--repos-ai-devops/memory/local.md"

git -C "$FIXTURE" init -q
git -C "$FIXTURE" remote add origin https://github.com/u2giants/ai-devops.git

set +e
push_output="$(CLAUDE_HOME="$LOCAL" bash "$FIXTURE/bin/ai-sync-memory" push 2>&1)"
push_status=$?
set -e
[[ "$push_output" == *"[BLOCKED]"* ]] || fail "public-hub push was not visibly blocked"
[[ "$push_status" -ne 0 ]] || fail "public-hub push returned success"
[[ ! -e "$FIXTURE/memory/ai-devops/local.md" ]] || fail "public-hub push copied a private fact"
grep -Fq '[Hub entry](hub.md)' "$FIXTURE/memory/ai-devops/MEMORY.md" ||
  fail "public-hub push modified the hub index"

CLAUDE_HOME="$LOCAL" bash "$FIXTURE/bin/ai-sync-memory" pull >/dev/null
INDEX="$LOCAL/projects/C--repos-ai-devops/memory/MEMORY.md"
grep -Fq '[Hub entry](hub.md)' "$INDEX" || fail "pull did not accept the hub entry"
grep -Fq '[Local entry](local.md)' "$INDEX" || fail "pull dropped the local-only entry"
[[ -f "$LOCAL/projects/C--repos-ai-devops/memory/local.md" ]] ||
  fail "pull removed a local-only fact"
[[ -f "$LOCAL/projects/C--repos-ai-devops/memory/hub.md" ]] ||
  fail "pull did not copy the hub fact"

bash -n "$FIXTURE/bin/ai-sync-memory"
echo "PASS: public memory uploads are blocked and pull preserves both indexes"
