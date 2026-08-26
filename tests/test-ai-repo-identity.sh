#!/usr/bin/env bash
# The repository identity allow-list is a security guard, not a convenience.
# These tests prove it stays FAIL-CLOSED while it accepts the extra owner the
# popcre move needs (issue #84 / fix_to_gh_org.md).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; SCRIPT="$ROOT/bin/ai-repo-identity"
TABLE="$ROOT/config/repo-identities.tsv"
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

check 'the identity table exists' "[ -f '$TABLE' ]"
check 'the helper is executable' "[ -x '$SCRIPT' ]"

# --- the widening this change exists for -----------------------------------
for url in \
  'https://github.com/u2giants/ai-devops.git' \
  'https://github.com/u2giants/ai-devops' \
  'git@github.com:u2giants/ai-devops.git' ; do
  check "old owner accepted: $url" "'$SCRIPT' accepts ai-devops '$url'"
done
for url in \
  'https://github.com/popcre/ai-devops.git' \
  'https://github.com/popcre/ai-devops' \
  'git@github.com:popcre/ai-devops.git' \
  'ssh://git@github.com/popcre/ai-devops.git' ; do
  check "new owner accepted: $url" "'$SCRIPT' accepts ai-devops '$url'"
done

# --- the guard must still refuse everything else ---------------------------
for url in \
  'https://github.com/attacker/ai-devops.git' \
  'git@github.com:attacker/ai-devops.git' \
  'https://github.com/u2giants/ai-devops-evil.git' \
  'https://gitlab.com/u2giants/ai-devops.git' \
  'https://github.com/popcre/ai-devops-memory.git' \
  '' ; do
  check "refused: ${url:-<empty origin>}" "! '$SCRIPT' accepts ai-devops '$url'"
done

# --- the two PRIVATE siblings are deliberately NOT moving ------------------
check 'memory hub accepts u2giants' "'$SCRIPT' accepts ai-devops-memory 'https://github.com/u2giants/ai-devops-memory.git'"
check 'memory hub refuses popcre' "! '$SCRIPT' accepts ai-devops-memory 'https://github.com/popcre/ai-devops-memory.git'"
check 'transcripts accept u2giants' "'$SCRIPT' accepts ai-devops-transcripts 'https://github.com/u2giants/ai-devops-transcripts.git'"
check 'transcripts refuse popcre' "! '$SCRIPT' accepts ai-devops-transcripts 'https://github.com/popcre/ai-devops-transcripts.git'"
check 'an unknown key accepts nothing' "! '$SCRIPT' accepts not-a-repo 'https://github.com/u2giants/ai-devops.git'"

# --- a broken table must reject, never wave things through -----------------
: > "$TMP/empty.tsv"
check 'an emptied table accepts nothing' \
  "! AI_REPO_IDENTITY_FILE='$TMP/empty.tsv' '$SCRIPT' accepts ai-devops 'https://github.com/u2giants/ai-devops.git'"
check 'a missing table is a hard error, not a pass' \
  "! AI_REPO_IDENTITY_FILE='$TMP/absent.tsv' '$SCRIPT' accepts ai-devops 'https://github.com/u2giants/ai-devops.git'"
AI_REPO_IDENTITY_FILE="$TMP/absent.tsv" "$SCRIPT" accepts ai-devops 'https://github.com/u2giants/ai-devops.git' >/dev/null 2>&1
[ "$?" -eq 2 ] && ok 'a missing table exits 2 so callers can tell error from refusal' \
               || bad 'a missing table exits 2 so callers can tell error from refusal'
check 'comment rows are not identities' \
  "! '$SCRIPT' accepts ai-devops '#'"

# --- no script may quietly re-introduce a seventh literal ------------------
# Every hard-coded ai-devops identity left in bin/ must be one the table lists.
missing=0
{ "$SCRIPT" list ai-devops; "$SCRIPT" list ai-devops-memory; "$SCRIPT" list ai-devops-transcripts; } > "$TMP/listed"
while IFS= read -r found; do
  grep -Fqx "${found%.git}" "$TMP/listed" ||
    { printf '       unlisted identity in bin/: %s\n' "$found"; missing=1; }
done < <(grep -rhoE 'github\.com/[A-Za-z0-9._-]+/ai-devops(-[A-Za-z0-9._-]+)?(\.git)?' "$ROOT/bin" | LC_ALL=C sort -u)
[ "$missing" -eq 0 ] && ok 'every ai-devops identity literal in bin/ is listed in the table' \
                     || bad 'every ai-devops identity literal in bin/ is listed in the table'

# --- the guards actually consult the table ---------------------------------
check 'the Windows bootstrap uses the shared allow-list' \
  "grep -Fq 'Assert-AiDevOpsRepoIdentity' '$ROOT/bin/bootstrap-windows-dev.ps1'"
check 'the Windows installer uses the shared allow-list' \
  "grep -Fq 'Assert-AiDevOpsRepoIdentity' '$ROOT/bin/install-ai-devops-windows.ps1'"
check 'the public-hub memory guard uses the shared allow-list' \
  "grep -Fq 'ai-repo-identity' '$ROOT/bin/ai-sync-memory'"
check 'no identity guard was softened into a warning' \
  "! grep -nE 'Assert-AiDevOpsRepoIdentity.*(-WarningAction|Write-Warning)' '$ROOT/bin/bootstrap-windows-dev.ps1' '$ROOT/bin/install-ai-devops-windows.ps1'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
