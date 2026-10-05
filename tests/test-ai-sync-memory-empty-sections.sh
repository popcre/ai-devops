#!/usr/bin/env bash
# Regression: MEMORY.md must not accumulate empty "## …" section shells.
#
# Two defects created them and then copied them forever:
#   1. `grep -Fqx` missed a CRLF title, so every merge with additions appended
#      another "## Local entries preserved during migration".
#   2. forget/tombstone/prune removed entry lines but left the empty headers.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

FIXTURE="$TMP/fixture"
LOCAL="$TMP/claude"
mkdir -p "$FIXTURE/bin" "$FIXTURE/memory/sample" \
  "$LOCAL/projects/C--repos-sample/memory"
cp "$ROOT/bin/ai-sync-memory" "$FIXTURE/bin/ai-sync-memory"
chmod +x "$FIXTURE/bin/ai-sync-memory"
# Private hub identity: not on the public allow-list, so push may proceed.
mkdir -p "$FIXTURE/config"
cp "$ROOT/bin/ai-repo-identity" "$FIXTURE/bin/ai-repo-identity"
chmod +x "$FIXTURE/bin/ai-repo-identity"
cp "$ROOT/config/repo-identities.tsv" "$FIXTURE/config/repo-identities.tsv"

# Hub index is LF and already carries the migration title once (with content).
cat > "$FIXTURE/memory/sample/MEMORY.md" <<'EOF'
# Memory index - sample

- [hub](hub.md) - hub fact.

## Local entries preserved during migration

- [hub](hub.md) - hub fact.
EOF
printf 'hub fact\n' > "$FIXTURE/memory/sample/hub.md"

# Local index is CRLF and already polluted with empty migration shells.
{
  printf '%s\r\n' '# Memory index - sample'
  printf '\r\n'
  printf '%s\r\n' '- [local](local.md) - local fact.'
  printf '\r\n'
  for _ in 1 2 3 4 5; do
    printf '%s\r\n' '## Local entries preserved during migration'
    printf '\r\n'
  done
  printf '%s\r\n' '## Recovered union entries'
  printf '\r\n'
} > "$LOCAL/projects/C--repos-sample/memory/MEMORY.md"
printf 'local fact\n' > "$LOCAL/projects/C--repos-sample/memory/local.md"

git -C "$FIXTURE" init -q
git -C "$FIXTURE" remote add origin https://github.com/example/private-memory-hub.git

# --- Pull: CRLF local + LF hub must not mint another empty title. ------------
CLAUDE_HOME="$LOCAL" bash "$FIXTURE/bin/ai-sync-memory" pull >/dev/null
INDEX="$LOCAL/projects/C--repos-sample/memory/MEMORY.md"
grep -Fq '[local](local.md)' "$INDEX" || fail "pull dropped the local entry"
grep -Fq '[hub](hub.md)' "$INDEX" || fail "pull did not accept the hub entry"

empty_headers="$(grep -c '^## Local entries preserved during migration' "$INDEX" || true)"
# Title may remain only if it still has a body; empty shells must be gone.
# After prune, at most one title can survive and only with a following entry.
title_lines="$(grep -c '^## Local entries preserved during migration' "$INDEX" || true)"
if [[ "$title_lines" -gt 1 ]]; then
  fail "pull left $title_lines migration titles in $INDEX"
fi
if [[ "$title_lines" -eq 1 ]]; then
  awk '
    /^## Local entries preserved during migration/ { grab = 1; next }
    grab && /^## / { exit 1 }
    grab && $0 ~ /[^ \t]/ { found = 1; exit }
    END { exit (found ? 0 : 1) }
  ' "$INDEX" || fail "surviving migration title has an empty body"
fi
if grep -q '^## Recovered union entries' "$INDEX"; then
  awk '
    /^## Recovered union entries/ { grab = 1; next }
    grab && /^## / { exit 1 }
    grab && $0 ~ /[^ \t]/ { found = 1; exit }
    END { exit (found ? 0 : 1) }
  ' "$INDEX" || fail "Recovered union entries title is an empty shell"
fi

# --- Push: hub must not gain empty shells either. ----------------------------
CLAUDE_HOME="$LOCAL" bash "$FIXTURE/bin/ai-sync-memory" push >/dev/null
HUB_INDEX="$FIXTURE/memory/sample/MEMORY.md"
hub_titles="$(grep -c '^## Local entries preserved during migration' "$HUB_INDEX" || true)"
[[ "$hub_titles" -le 1 ]] || fail "push left $hub_titles migration titles on the hub"
if grep -q '^## Recovered union entries' "$HUB_INDEX"; then
  awk '
    /^## Recovered union entries/ { grab = 1; next }
    grab && /^## / { exit 1 }
    grab && $0 ~ /[^ \t]/ { found = 1; exit }
    END { exit (found ? 0 : 1) }
  ' "$HUB_INDEX" || fail "hub Recovered union entries is an empty shell"
fi

# --- Forget: removing the last entry under a title must remove the title. ----
printf 'local fact\n' > "$FIXTURE/memory/sample/local.md"
# Ensure local.md is on the hub index so forget can tombstone it.
if ! grep -Fq '(local.md)' "$HUB_INDEX"; then
  printf '%s\n' '- [local](local.md) - local fact.' >> "$HUB_INDEX"
fi
CLAUDE_HOME="$LOCAL" bash "$FIXTURE/bin/ai-sync-memory" forget sample local.md "test: empty shell must not survive" >/dev/null
if grep -q '^## Local entries preserved during migration' "$HUB_INDEX"; then
  awk '
    /^## Local entries preserved during migration/ { grab = 1; next }
    grab && /^## / { empty = 1; exit }
    grab && $0 ~ /[^ \t]/ { empty = 0; exit }
    END { exit (empty ? 1 : 0) }
  ' "$HUB_INDEX" && fail "forget left an empty migration title on the hub"
fi

bash -n "$ROOT/bin/ai-sync-memory"
echo "PASS: MEMORY.md empty section shells are pruned and not recreated"
