#!/usr/bin/env bash
# Exercise the standalone Git Bash entrypoint without relying on caller set -e.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/repo" "$TMP/profile" "$TMP/bin"
git -C "$TMP/repo" init -q
git -C "$TMP/repo" config user.name Test
git -C "$TMP/repo" config user.email test@example.invalid
printf 'Old template\n' > "$TMP/repo/global.md"
git -C "$TMP/repo" add global.md
git -C "$TMP/repo" commit -qm old
printf 'New template\n' > "$TMP/repo/global.md"
git -C "$TMP/repo" commit -qam new
printf 'Old template\n\n---\n\n# Machine facts\nKeep this fact.\n' > "$TMP/original"
cp "$TMP/original" "$TMP/profile/AGENTS.md"
printf '#!/bin/sh\nexit 1\n' > "$TMP/bin/mv"
chmod +x "$TMP/bin/mv"
rc=0
PATH="$TMP/bin:$PATH" bash "$ROOT/tools/lib/globals-common.sh" refresh \
  "$TMP/repo" "$TMP/repo/global.md" "$TMP/profile/AGENTS.md" Test > "$TMP/output" 2>&1 || rc=$?
[[ "$rc" == 2 ]] || { cat "$TMP/output"; echo "FAIL: failed move returned $rc"; exit 1; }
cmp "$TMP/original" "$TMP/profile/AGENTS.md"
cmp "$TMP/original" "$TMP/profile/globals-backup/AGENTS.md"
[[ ! -e "$TMP/profile/AGENTS.md.ai-devops-new" ]]
! grep -q 'machine section kept; previous copy' "$TMP/output"
bash "$ROOT/tools/lib/globals-common.sh" refresh \
  "$TMP/repo" "$TMP/repo/global.md" "$TMP/profile/AGENTS.md" Test
grep -q 'New template' "$TMP/profile/AGENTS.md"
diff <(sed -n '/^# Machine facts/,$p' "$TMP/original") \
  <(sed -n '/^# Machine facts/,$p' "$TMP/profile/AGENTS.md")
echo 'PASS: standalone refresh reports failed replacement, cleans up, and preserves machine facts'
