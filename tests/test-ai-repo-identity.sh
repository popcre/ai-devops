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
printf '# no rows at all
' > "$TMP/comments.tsv"
printf 'ai-devops github.com/u2giants/ai-devops
' > "$TMP/spaces.tsv"
chmod 0000 "$TMP/empty.tsv" 2>/dev/null; chmod 0644 "$TMP/empty.tsv" 2>/dev/null

# A broken allow-list must be an ERROR (exit 2), never an ordinary refusal
# (exit 1). bin/ai-sync-memory's guard is INVERTED -- it reads exit 1 as "not
# the public repo, proceed" -- so returning 1 here publishes private memory
# into a public clone. Verified 2026-08-26 that it did exactly that.
for broken in empty comments spaces absent; do
  status=0
  AI_REPO_IDENTITY_FILE="$TMP/$broken.tsv" "$SCRIPT" accepts ai-devops     'https://github.com/u2giants/ai-devops.git' >/dev/null 2>&1 || status=$?
  [ "$status" -eq 2 ] && ok "broken allow-list ($broken) is an error, not a refusal"                       || bad "broken allow-list ($broken) must exit 2, got $status"
done

# An intact table plus an unknown identity is an ordinary refusal, exit 1.
status=0
"$SCRIPT" accepts ai-devops 'https://github.com/attacker/ai-devops.git' >/dev/null 2>&1 || status=$?
[ "$status" -eq 1 ] && ok 'an intact table refusing an identity exits 1, not 2'                     || bad "an intact table refusing an identity must exit 1, got $status"

# URL forms that must still resolve to an accepted identity.
for url in   'https://github.com/popcre/ai-devops.git/'   '  https://github.com/popcre/ai-devops.git  '   'ssh://git@github.com/popcre/ai-devops' ; do
  check "URL form accepted: $url" "'$SCRIPT' accepts ai-devops '$url'"
done

check 'comment rows are not identities' \
  "! '$SCRIPT' accepts ai-devops '#'"

# --- no script may quietly re-introduce a seventh literal ------------------
# Every hard-coded ai-devops identity left in bin/ must be one the table lists.
missing=0
# Every repository identity literal in bin/ must be one the table lists, in
# either the full github.com/<owner>/<repo> form or the bare <owner>/<repo>
# form. bin/ai-facts and bin/ai-private-config once compared the bare form,
# which a github.com-only pattern never saw -- changing either literal to
# another owner would not have turned this check red.
: > "$TMP/listed"
for key in ai-devops ai-devops-memory ai-devops-transcripts ai-devops-private-config; do "$SCRIPT" list "$key" >> "$TMP/listed"; done
sed -E "s#^github[.]com/##" "$TMP/listed" > "$TMP/listed.bare"
cat "$TMP/listed.bare" >> "$TMP/listed"
# `-e` is load-bearing: a candidate that begins with a hyphen would otherwise be
# parsed by grep as an option, and the resulting usage error was reported as an
# identity violation. The owner class excludes a leading hyphen for the same
# reason -- no GitHub owner starts with one -- while still allowing a leading
# dot so `.config/ai-devops` keeps matching the path filter below.
while IFS= read -r found; do
  grep -Fqx -e "${found%.git}" "$TMP/listed" ||
    { printf '       unlisted identity in bin/: %s\n' "$found"; missing=1; }
# Filtered out: filesystem paths that merely end in an ai-devops* directory
# name, and `gh api repos/<owner>/<repo>` calls, which are API requests rather
# than identity comparisons.
done < <(grep -rhoE '(github\.com/)?[A-Za-z0-9._][A-Za-z0-9._-]*/ai-devops(-[A-Za-z0-9._-]+)?(\.git)?' "$ROOT/bin" --exclude-dir=.git | grep -vE '^([.]|repos/|api/|share/|state/|worksp/|local/|bin/|opt/|var/|etc/|cache/|lib/|log/|tmp/|run/)' | LC_ALL=C sort -u)
[ "$missing" -eq 0 ] && ok 'every ai-devops identity literal in bin/ is listed in the table' \
                     || bad 'every ai-devops identity literal in bin/ is listed in the table'

# --- the guards actually consult the table ---------------------------------
check 'the Windows bootstrap uses the shared allow-list' \
  "grep -Fq 'Assert-AiDevOpsRepoIdentity' '$ROOT/bin/bootstrap-windows-dev.ps1'"
check 'the Windows installer uses the shared allow-list' \
  "grep -Fq 'Assert-AiDevOpsRepoIdentity' '$ROOT/bin/install-ai-devops-windows.ps1'"
check 'the public-hub memory guard uses the shared allow-list' \
  "grep -Fq 'ai-repo-identity' '$ROOT/bin/ai-sync-memory'"
# A same-line grep cannot see `try { Assert-... } catch { Write-Warning }`, so
# inspect a window around every call site instead, and require the helper itself
# to still throw. Proven by injecting each softening and watching this go red.
soften_re="-WarningAction|Write-Warning|-ErrorAction[[:space:]]+(SilentlyContinue|Continue)"
for f in "$ROOT/bin/bootstrap-windows-dev.ps1" "$ROOT/bin/install-ai-devops-windows.ps1"; do
  check "no identity guard was softened in $(basename "$f")" \
    "! grep -nE -A4 -B4 'Assert-AiDevOpsRepoIdentity' '$f' | grep -qE -- \"$soften_re\""
done
check 'the assertion helper still throws on an unlisted identity' \
  "grep -Fq 'throw' '$ROOT/bin/repo-identity.ps1'"
check 'the assertion helper never downgrades to a warning' \
  "! grep -qE \"Write-Warning|-WarningAction\" '$ROOT/bin/repo-identity.ps1'"
check 'the public-hub memory guard still refuses rather than warns' \
  "grep -qE 'BLOCKED' '$ROOT/bin/ai-sync-memory'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
