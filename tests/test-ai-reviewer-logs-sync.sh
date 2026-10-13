#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0
check(){ if eval "$2"; then pass=$((pass + 1)); printf '  ok   %s\n' "$1"; else printf '  FAIL %s\n' "$1" >&2; exit 1; fi; }

REMOTE="$TMP/logs.git"
git init -q --bare "$REMOTE"
git -C "$REMOTE" symbolic-ref HEAD refs/heads/main

STATE="$TMP/state"; ISSUES="$TMP/issues"; REPOS="$TMP/repos"
mkdir -p "$STATE/review-scoreboard" "$STATE/reviewer-events" "$STATE/review-lifecycle/runs/r1" \
  "$ISSUES/20261013-pkg" "$REPOS/app-one/.ai/reviews" "$STATE/qwen/sessions"
printf '{"verdict":"REJECT"}\n' > "$STATE/review-scoreboard/reviews.jsonl"
printf '{"event":"start"}\n' > "$STATE/reviewer-events/events.jsonl"
printf 'state\n' > "$STATE/review-lifecycle/runs/r1/run.json"
printf 'big\n' > "$STATE/qwen/sessions/huge.json"
fake_gh="gh""p_""abcdefghijklmnopqrstuvwxyz0123"
fake_sk="sk-""ABCDEFGHIJKLMNOPQRSTUVWXYZ123456"
cat > "$ISSUES/20261013-pkg/provider.log" <<EOF
reviewer said: exit 1 after timeout
token=$fake_gh
Authorization: Bearer abcdefghijklmnop.qrstuvwx
key $fake_sk end
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAA
-----END OPENSSH PRIVATE KEY-----
after key
EOF
printf 'A=1\n' > "$ISSUES/20261013-pkg/local.env"
printf '\000\001\002binary' > "$ISSUES/20261013-pkg/blob.bin"
head -c 3000 /dev/zero | tr '\0' 'x' > "$ISSUES/20261013-pkg/large.txt"
printf '# review\nVERDICT: APPROVE\n' > "$REPOS/app-one/.ai/reviews/codex-final-check.md"
REPOS2="$TMP/other/repos"; mkdir -p "$REPOS2/app-one/.ai/reviews"
printf 'second checkout\n' > "$REPOS2/app-one/.ai/reviews/codex-final-check.md"
printf 'x\n' > "$ISSUES/20261013-pkg/"'name-$(touch PWNED).log'
fake_npm="npm_""abcdefghijklmnopqrstuvwxyz0123456789"
printf 'db postgres://admin:hunter2pass@db.example:5432/app\nnpm %s\n' "$fake_npm" > "$ISSUES/20261013-pkg/urls.log"

run(){
  HOME="$TMP/home" AI_REVIEWER_LOGS_TEST_MODE=1 AI_REVIEWER_LOGS_REMOTE="$REMOTE" \
    AI_REVIEWER_LOGS_HUB="$TMP/hub" AI_REVIEWER_STATE_BASE="$STATE" AI_REVIEWER_ISSUE_DIR="$ISSUES" \
    AI_REVIEWER_LOGS_ROOTS="$REPOS:$REPOS2" AI_REVIEWER_LOGS_MAX_FILE_BYTES=2000 AI_REVIEWER_LOGS_MACHINE=test-box \
    GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid \
    bash "$ROOT/bin/ai-reviewer-logs-sync" "$@"
}

run sync 2> "$TMP/out1" || { cat "$TMP/out1" >&2; exit 1; }
VIEW="$TMP/view"; git clone -q "$REMOTE" "$VIEW"
M="$VIEW/test-box"
check 'first run pushes the machine folder' "[ -f '$M/LAST-SYNC.txt' ] && [ -f '$VIEW/README.md' ]"
check 'incident package copied' "grep -q 'exit 1 after timeout' '$M/reviewer-issues/20261013-pkg/provider.log'"
check 'scoreboard, events and lifecycle copied' "[ -f '$M/state/review-scoreboard/reviews.jsonl' ] && [ -f '$M/state/reviewer-events/events.jsonl' ] && [ -f '$M/state/review-lifecycle/runs/r1/run.json' ]"
check 'review reports copied per checkout' "[ \$(grep -rl APPROVE '$M/reviews' | wc -l) -eq 1 ] && [ \$(grep -rl 'second checkout' '$M/reviews' | wc -l) -eq 1 ]"
check 'same-named checkouts kept apart' "[ \$(ls '$M/reviews' | wc -l) -eq 2 ]"
check 'odd filenames are data, never commands' "[ ! -e PWNED ] && [ ! -e '$TMP/home/PWNED' ] && ls '$M/reviewer-issues/20261013-pkg' | grep -q 'touch PWNED'"
check 'URL passwords and npm tokens redacted' "! grep -q hunter2pass '$M/reviewer-issues/20261013-pkg/urls.log' && grep -q 'postgres://admin:' '$M/reviewer-issues/20261013-pkg/urls.log' && ! grep -q '$fake_npm' '$M/reviewer-issues/20261013-pkg/urls.log'"
check 'token values redacted' "! grep -q '$fake_gh' '$M/reviewer-issues/20261013-pkg/provider.log' && ! grep -q '$fake_sk' '$M/reviewer-issues/20261013-pkg/provider.log'"
check 'bearer and private key redacted, text around kept' "! grep -q 'abcdefghijklmnop' '$M/reviewer-issues/20261013-pkg/provider.log' && ! grep -q b3BlbnNz '$M/reviewer-issues/20261013-pkg/provider.log' && grep -q 'after key' '$M/reviewer-issues/20261013-pkg/provider.log'"
check 'secret file types, binaries and large files skipped and listed' "[ ! -e '$M/reviewer-issues/20261013-pkg/local.env' ] && [ ! -e '$M/reviewer-issues/20261013-pkg/blob.bin' ] && [ ! -e '$M/reviewer-issues/20261013-pkg/large.txt' ] && [ \$(grep -c . '$M/SKIPPED.txt') -eq 3 ]"
check 'provider session stores are not collected' "[ ! -e '$M/state/qwen' ]"
check 'source files are untouched' "grep -q '$fake_gh' '$ISSUES/20261013-pkg/provider.log'"

run sync 2> "$TMP/out2"
check 'unchanged rerun pushes nothing new' "grep -q 'nothing new' '$TMP/out2' && [ \$(git -C '$REMOTE' rev-list --count main) -eq 1 ]"

printf '{"verdict":"APPROVE"}\n' >> "$STATE/review-scoreboard/reviews.jsonl"
rm -f "$REPOS/app-one/.ai/reviews/codex-final-check.md"
run sync 2> "$TMP/out3"
git -C "$VIEW" pull -q
check 'new evidence is appended' "grep -q APPROVE '$M/state/review-scoreboard/reviews.jsonl'"
check 'files deleted locally stay in the archive' "[ \$(grep -rl APPROVE '$M/reviews' | wc -l) -eq 1 ]"

# Basic authentication values are masked.
printf 'Authorization: Basic dXNlcjpodW50ZXIycGFzcw==\n' > "$ISSUES/20261013-pkg/basic.log"
run sync 2> "$TMP/out4"
git -C "$VIEW" pull -q
check 'basic auth masked' "! grep -q dXNlcjpodW50ZXIy '$M/reviewer-issues/20261013-pkg/basic.log'"

# Short and spaced labeled passwords, secret-looking file names, and evidence
# restored with an older timestamp.
printf 'password=abc\n"secret": "two words here"\n' > "$ISSUES/20261013-pkg/labels.log"
printf 'x\n' > "$ISSUES/20261013-pkg/$fake_gh.log"
printf 'restored older content\n' > "$STATE/review-lifecycle/runs/r1/run.json"
touch -d '2001-01-01' "$STATE/review-lifecycle/runs/r1/run.json"
run sync 2> "$TMP/out6" || { cat "$TMP/out6" >&2; exit 1; }
git -C "$VIEW" pull -q
check 'short and spaced labeled values masked' "! grep -q 'abc' '$M/reviewer-issues/20261013-pkg/labels.log' && ! grep -q 'two words' '$M/reviewer-issues/20261013-pkg/labels.log'"
check 'secret-looking file names are withheld' "! ls '$M/reviewer-issues/20261013-pkg' | grep -q '$fake_gh' && grep -q 'secret in file name' '$M/SKIPPED.txt'"
check 'older-timestamp restores are collected' "grep -q 'restored older content' '$M/state/review-lifecycle/runs/r1/run.json'"

# A symbolic link committed to the repository stops the sync before any write.
git -C "$VIEW" config user.name t; git -C "$VIEW" config user.email t@example.invalid
printf '%s' "$TMP/outside" > "$TMP/target"
blob="$(git -C "$VIEW" hash-object -w "$TMP/target")"
git -C "$VIEW" update-index --add --cacheinfo 120000,"$blob",evil-link
git -C "$VIEW" commit -qm link && git -C "$VIEW" push -q origin HEAD:main
printf 'more\n' >> "$STATE/reviewer-events/events.jsonl"
check 'repository symlinks refused' "! run sync 2> '$TMP/out5' && grep -q 'symbolic links' '$TMP/out5' && [ ! -e '$TMP/outside' ]"
check 'program is executable in git' "[ \"\$(git -C '$ROOT' ls-files -s bin/ai-reviewer-logs-sync | cut -c1-6)\" = 100755 ]"

printf 'PASS test-ai-reviewer-logs-sync (%s checks)\n' "$pass"
