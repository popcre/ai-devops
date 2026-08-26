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
# The guard consults the shared allow-list. Without the helper AND the table
# in the fixture, ai-sync-memory exits 127 and the test passes on a missing
# file rather than on the guard actually identifying a public repository --
# it would still pass if the guard never worked at all.
mkdir -p "$FIXTURE/config"
cp "$ROOT/bin/ai-repo-identity" "$FIXTURE/bin/ai-repo-identity"
chmod +x "$FIXTURE/bin/ai-repo-identity"
cp "$ROOT/config/repo-identities.tsv" "$FIXTURE/config/repo-identities.tsv"

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

# The guard must recognise EVERY accepted ai-devops identity as public, not
# just the owner it was originally written against. This is the case that a
# hard-coded owner would have failed after the popcre transfer.
git -C "$FIXTURE" remote set-url origin https://github.com/popcre/ai-devops.git
set +e
popcre_output="$(CLAUDE_HOME="$LOCAL" bash "$FIXTURE/bin/ai-sync-memory" push 2>&1)"
popcre_status=$?
set -e
[[ "$popcre_output" == *"[BLOCKED]"* ]] || fail "popcre-owned public hub was not blocked"
[[ "$popcre_status" -ne 0 ]] || fail "popcre-owned public hub push returned success"
[[ ! -e "$FIXTURE/memory/ai-devops/local.md" ]] || fail "popcre-owned public hub push copied a private fact"

# A broken allow-list must BLOCK. The guard is inverted -- it reads "not on
# the list" as "not the public repo, proceed" -- so an empty or unreadable
# table returning an ordinary refusal is a fail-open that publishes private
# memory. Verified 2026-08-26 that it did exactly that before the fix.
for broken in empty comments spaces; do
  case "$broken" in
    empty)    : > "$FIXTURE/config/repo-identities.tsv" ;;
    comments) printf "# no rows at all\n" > "$FIXTURE/config/repo-identities.tsv" ;;
    spaces)   printf "ai-devops github.com/u2giants/ai-devops\n" > "$FIXTURE/config/repo-identities.tsv" ;;
  esac
  set +e
  broken_output="$(CLAUDE_HOME="$LOCAL" bash "$FIXTURE/bin/ai-sync-memory" push 2>&1)"
  broken_status=$?
  set -e
  [[ "$broken_output" == *"[BLOCKED]"* ]] || fail "broken allow-list ($broken) did not block the push"
  [[ "$broken_status" -ne 0 ]] || fail "broken allow-list ($broken) returned success"
  [[ ! -e "$FIXTURE/memory/ai-devops/local.md" ]] || fail "broken allow-list ($broken) copied a private fact"
done
cp "$ROOT/config/repo-identities.tsv" "$FIXTURE/config/repo-identities.tsv"
git -C "$FIXTURE" remote set-url origin https://github.com/u2giants/ai-devops.git

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
