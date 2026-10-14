#!/usr/bin/env bash
# Regression tests for the unprotected-advance detector: a plain merge or pull
# that moves a checkout is recorded by the post-merge hook, the protected
# updater is not, and ai-task-gates warns on the next run.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATES="$REPO_ROOT/bin/ai-task-gates"
HOOK="$REPO_ROOT/hooks/post-merge"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/unprotected-advance.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
check(){ local name="$1"; shift; if eval "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); printf '  ok   %s\n' "$name"; else FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$name"; fi; }

export GIT_AUTHOR_NAME=T GIT_AUTHOR_EMAIL=t@e GIT_COMMITTER_NAME=T GIT_COMMITTER_EMAIL=t@e
R="$TMP/repo"; git init -q -b main "$R"
mkdir -p "$R/.git/hooks"; cp "$HOOK" "$R/.git/hooks/post-merge"; chmod +x "$R/.git/hooks/post-merge"
echo a > "$R/f"; git -C "$R" add f; git -C "$R" commit -qm one
OLD="$(git -C "$R" rev-parse HEAD)"
echo b > "$R/f"; git -C "$R" commit -qam two
NEW="$(git -C "$R" rev-parse HEAD)"
git -C "$R" reset -q --hard "$OLD"
LOG="$TMP/state/unprotected-advances.log"; export AI_TASK_GATES_DIR="$TMP/state"

printf '\n== plain fast-forward records an advance ==\n'
git -C "$R" merge -q --ff-only "$NEW"
check "plain ff merge writes one record" "[ \"\$(wc -l < '$LOG')\" -eq 1 ]"
check "record names the advanced-to head" "grep -q '$NEW' '$LOG'"

printf '\n== protected updater does not record ==\n'
rm -f "$LOG"; git -C "$R" reset -q --hard "$OLD"
AI_DEVOPS_PROTECTED_UPDATE=1 git -C "$R" merge -q --ff-only "$NEW"
check "protected advance writes no record" "[ ! -s '$LOG' ]"

printf '\n== ai-task-gates warns until a protected install lands ==\n'
MAN="$TMP/manifest.tsv"; printf 'meta\tsource_sha\t%s\t-\n' "$OLD" > "$MAN"
export AI_TASK_GATES_MANIFEST="$MAN"; git -C "$R" reset -q --hard "$OLD"; git -C "$R" merge -q --ff-only "$NEW"
check "warning names the unprotected advance" "( cd '$R' && '$GATES' explain 2>&1 >/dev/null | grep -q 'outside the protected install path' )"
printf 'meta\tsource_sha\t%s\t-\n' "$NEW" > "$MAN"
check "no warning once the receipt matches the advanced head" "! ( cd '$R' && '$GATES' explain 2>&1 >/dev/null | grep -q 'outside the protected install path' )"

printf '\n== recording never writes to stderr, even when the state dir is unwritable ==\n'
RO="$TMP/readonly"; mkdir -p "$RO"; chmod 500 "$RO"
git -C "$R" reset -q --hard "$OLD" 2>/dev/null
ERR="$( (AI_TASK_GATES_DIR="$RO/state" git -C "$R" merge -q --ff-only "$NEW") 2>&1 >/dev/null )"
check "unwritable state dir leaves stderr silent" "[ -z '$ERR' ]"
chmod 700 "$RO"

printf '\n== a protected acknowledgement settles earlier unprotected records ==\n'
rm -f "$LOG"; git -C "$R" reset -q --hard "$OLD"; git -C "$R" merge -q --ff-only "$NEW"
printf '%s\t%s\t%s\t%s\n' "2026-10-14T00:00:00Z" "$R" protected "$NEW" >> "$LOG"
check "acknowledged advance no longer warns" "! ( cd '$R' && '$GATES' explain 2>&1 >/dev/null | grep -q 'outside the protected install path' )"
printf '%s\t%s\t%s\t%s\n' "2026-10-14T01:00:00Z" "$R" "$NEW" "$OLD" >> "$LOG"
check "a later unprotected advance warns and names the checkout" "( cd '$R' && '$GATES' explain 2>&1 >/dev/null | grep -q \"$R\" )"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
