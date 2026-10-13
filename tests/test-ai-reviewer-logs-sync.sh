#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0
check(){ if eval "$2"; then pass=$((pass + 1)); printf '  ok   %s\n' "$1"; else printf '  FAIL %s\n' "$1" >&2; exit 1; fi; }
native(){ if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

# Throwaway archive key pair for the test.
(umask 077; MSYS2_ARG_CONV_EXCL='*' openssl req -x509 -newkey rsa:2048 -nodes -keyout "$(native "$TMP/key.pem")" \
  -out "$(native "$TMP/cert.pem")" -days 2 -subj "/CN=test archive" >/dev/null 2>&1)

REMOTE="$TMP/logs.git"
git init -q --bare "$REMOTE"
git -C "$REMOTE" symbolic-ref HEAD refs/heads/main

STATE="$TMP/state"; ISSUES="$TMP/issues"; REPOS="$TMP/repos"; REPOS2="$TMP/other/repos"
mkdir -p "$STATE/review-scoreboard" "$STATE/reviewer-events" "$STATE/review-lifecycle/runs/r1" \
  "$ISSUES/pkg" "$REPOS/app-one/.ai/reviews" "$REPOS2/app-one/.ai/reviews" "$STATE/qwen/sessions"
printf '{"verdict":"REJECT"}\n' > "$STATE/review-scoreboard/reviews.jsonl"
printf '{"event":"start"}\n' > "$STATE/reviewer-events/events.jsonl"
printf 'AAAA\n' > "$STATE/review-lifecycle/runs/r1/run.json"
printf 'big\n' > "$STATE/qwen/sessions/huge.json"
fake_gh="gh""p_""abcdefghijklmnopqrstuvwxyz0123"
printf 'reviewer said: exit 1 after timeout\ntoken=%s\nthe password is hunter3word\n' "$fake_gh" > "$ISSUES/pkg/provider.log"
printf '\000\001\002binary' > "$ISSUES/pkg/blob.bin"
head -c 3000 /dev/zero | tr '\0' 'x' > "$ISSUES/pkg/large.txt"
printf 'x\n' > "$ISSUES/pkg/"'name-$(touch PWNED).log'
printf 'x\n' > "$ISSUES/pkg/$fake_gh.log"
printf '# review\nVERDICT: APPROVE\n' > "$REPOS/app-one/.ai/reviews/codex-final-check.md"
printf 'second checkout\n' > "$REPOS2/app-one/.ai/reviews/codex-final-check.md"

run(){
  HOME="$TMP/home" AI_REVIEWER_LOGS_TEST_MODE=1 AI_REVIEWER_LOGS_REMOTE="$REMOTE" \
    AI_REVIEWER_LOGS_HUB="$TMP/hub" AI_REVIEWER_STATE_BASE="$STATE" AI_REVIEWER_ISSUE_DIR="$ISSUES" \
    AI_REVIEWER_LOGS_ROOTS="$REPOS:$REPOS2" AI_REVIEWER_LOGS_MAX_FILE_BYTES=2000 \
    AI_REVIEWER_LOGS_MACHINE="${AI_REVIEWER_LOGS_MACHINE:-test-box}" AI_REVIEWER_LOGS_CERT="$TMP/cert.pem" \
    AI_REVIEWER_LOGS_KEY_FILE="$TMP/key.pem" \
    GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid \
    bash "$ROOT/bin/ai-reviewer-logs-sync" "$@"
}
view(){ rm -rf "$TMP/plain"; run view "$TMP/plain" >/dev/null 2>&1; }

run sync 2> "$TMP/out1" || { cat "$TMP/out1" >&2; exit 1; }
VIEW="$TMP/view"; git clone -q "$REMOTE" "$VIEW"
M="$VIEW/test-box"; P="$TMP/plain/test-box"
check 'first run pushes the machine folder' "[ -f '$M/LAST-SYNC.txt' ] && ls '$M/bundles' | grep -q 'tar.cms'"
check 'only encrypted bundles and the status file are published' "[ -z \"\$(git -C '$VIEW' ls-files | grep -v -e '^test-box/bundles/[0-9TZ]*-[0-9a-f]*\.tar\.cms\$' -e '^test-box/LAST-SYNC.txt\$')\" ]"
check 'no clear text from the logs reaches the repository' "! git -C '$VIEW' grep -q -e 'after timeout' -e hunter3word -e APPROVE"
view
check 'view decrypts complete, unmasked evidence' "cmp -s '$ISSUES/pkg/provider.log' '$P/reviewer-issues/pkg/provider.log' && cmp -s '$ISSUES/pkg/blob.bin' '$P/reviewer-issues/pkg/blob.bin'"
check 'scoreboard, events and lifecycle collected' "[ -f '$P/state/review-scoreboard/reviews.jsonl' ] && [ -f '$P/state/reviewer-events/events.jsonl' ] && [ -f '$P/state/review-lifecycle/runs/r1/run.json' ]"
check 'review reports from same-named checkouts kept apart' "[ \$(ls '$P/reviews' | wc -l) -eq 2 ] && [ \$(grep -rl APPROVE '$P/reviews' | wc -l) -eq 1 ] && [ \$(grep -rl 'second checkout' '$P/reviews' | wc -l) -eq 1 ]"
check 'file names are never published in clear text' "! git -C '$VIEW' ls-files | grep -q -e '$fake_gh' -e provider -e codex-final && ! git -C '$VIEW' grep -q -e '$fake_gh' -e provider.log && [ -f '$P/reviewer-issues/pkg/$fake_gh.log' ]"
check 'odd file names are data, never commands' "[ ! -e PWNED ] && [ ! -e '$TMP/home/PWNED' ] && ls '$P/reviewer-issues/pkg' | grep -q 'touch PWNED'"
check 'oversized files skipped and listed inside the bundle' "[ ! -e '$P/reviewer-issues/pkg/large.txt' ] && cat '$P'/_collection/*-skipped.txt | grep -q 'large.txt'"
check 'provider session stores are not collected' "[ ! -e '$P/state/qwen' ]"

run sync 2> "$TMP/out2"
check 'unchanged rerun pushes nothing new' "grep -q 'nothing new' '$TMP/out2' && [ \$(git -C '$REMOTE' rev-list --count main) -eq 1 ]"

printf 'BBBB\n' > "$STATE/review-lifecycle/runs/r1/run.json"; touch -d '2002-02-02' "$STATE/review-lifecycle/runs/r1/run.json"
rm -f "$REPOS/app-one/.ai/reviews/codex-final-check.md"
run sync 2> "$TMP/out3" || { cat "$TMP/out3" >&2; exit 1; }
view
check 'changed content collected even with an old timestamp' "grep -q BBBB '$P/state/review-lifecycle/runs/r1/run.json'"
check 'files deleted locally stay in the archive' "[ \$(grep -rl APPROVE '$P/reviews' | wc -l) -eq 1 ]"

# A bundle lost from the published archive is put back from the local copy.
first="$(git -C "$REMOTE" ls-tree -r --name-only main | grep bundles | sort | head -1)"
git -C "$VIEW" pull -q; git -C "$VIEW" -c user.name=t -c user.email=t@example.invalid rm -q "$first"
git -C "$VIEW" -c user.name=t -c user.email=t@example.invalid commit -qm lose && git -C "$VIEW" push -q origin HEAD:main
run sync 2> "$TMP/out13" || { cat "$TMP/out13" >&2; exit 1; }
check 'lost bundles are restored byte for byte' "grep -q 'restored' '$TMP/out13' && git -C '$REMOTE' cat-file -e 'main:$first'"
view
check 'restored evidence includes files deleted locally' "[ \$(grep -rl APPROVE '$P/reviews' | wc -l) -eq 1 ]"

# Lost everywhere: everything is collected again, once.
second="$(git -C "$REMOTE" ls-tree -r --name-only main | grep bundles | sort | head -1)"
git -C "$VIEW" pull -q; git -C "$VIEW" -c user.name=t -c user.email=t@example.invalid rm -q "$second"
git -C "$VIEW" -c user.name=t -c user.email=t@example.invalid commit -qm lose2 && git -C "$VIEW" push -q origin HEAD:main
rm -f "$TMP/home/.ai-devops/reviewer-logs-sync/sent/$(basename "$second")"
run sync 2> "$TMP/out13b" || { cat "$TMP/out13b" >&2; exit 1; }
run sync 2> "$TMP/out13c" || { cat "$TMP/out13c" >&2; exit 1; }
view
check 'bundles lost everywhere are re-collected once' "grep -q 'collecting everything again' '$TMP/out13b' && grep -q 'nothing new' '$TMP/out13c' && cmp -s '$ISSUES/pkg/provider.log' '$P/reviewer-issues/pkg/provider.log'"

# view rebuilds from scratch, never wipes a foreign folder, and refuses unsafe bundles.
mkdir -p "$TMP/plain/test-box/ghost"; : > "$TMP/plain/test-box/ghost/stale.txt"
view
check 'view output is rebuilt from scratch' "[ ! -e '$TMP/plain/test-box/ghost' ]"
mkdir -p "$TMP/foreign"; : > "$TMP/foreign/keep.txt"
check 'view refuses to wipe a folder it did not make' "! run view '$TMP/foreign' >/dev/null 2>&1 && [ -f '$TMP/foreign/keep.txt' ]"
mkdir -p "$TMP/evil/x"; : > "$TMP/evil/x/f"
(cd "$TMP/evil/x" && tar -cPf "$TMP/evil.tar" ../x/f 2>/dev/null)
git -C "$VIEW" pull -q; mkdir -p "$VIEW/test-box/bundles"
MSYS2_ARG_CONV_EXCL='*' openssl cms -encrypt -binary -aes-256-cbc -outform DER -in "$(native "$TMP/evil.tar")" \
  -out "$(native "$VIEW/test-box/bundles/99991231T000000000000000Z-evil.tar.cms")" "$(native "$TMP/cert.pem")"
git -C "$VIEW" add -A && git -C "$VIEW" -c user.name=t -c user.email=t@example.invalid commit -qm evil && git -C "$VIEW" push -q origin HEAD:main
check 'bundles with escaping paths are not unpacked' "! run view '$TMP/plain' >/dev/null 2>'$TMP/out14' && grep -q 'unsafe path' '$TMP/out14'"
git -C "$VIEW" -c user.name=t -c user.email=t@example.invalid rm -q test-box/bundles/99991231T000000000000000Z-evil.tar.cms
git -C "$VIEW" -c user.name=t -c user.email=t@example.invalid commit -qm unevil && git -C "$VIEW" push -q origin HEAD:main

# Hashing failure: partial, exit 2, never recorded complete; a clean retry clears it.
mkdir -p "$TMP/badbin"; real_sha1="$(command -v sha1sum)"
printf '#!/usr/bin/env bash\ncase " $* " in *" -z "*) echo "sha1sum: read error" >&2; exit 1 ;; esac\nexec "%s" "$@"\n' "$real_sha1" > "$TMP/badbin/sha1sum"
chmod +x "$TMP/badbin/sha1sum"
rc=0; PATH="$TMP/badbin:$PATH" run sync 2> "$TMP/out4" || rc=$?
git -C "$VIEW" pull -q
check 'read failures fail the run and are published as incomplete' "[ $rc -eq 2 ] && grep -q PARTIAL '$TMP/out4' && grep -q '^complete: no' '$M/LAST-SYNC.txt'"
run sync 2> "$TMP/out5" || { cat "$TMP/out5" >&2; exit 1; }
git -C "$VIEW" pull -q
check 'a clean retry clears the incomplete mark' "grep -q '^complete: yes' '$M/LAST-SYNC.txt'"

# An unpushed local commit (here carrying clear text) never reaches GitHub; the
# next run starts from the published archive.
printf 'stranded clear text
' > "$TMP/hub/test-box/sneak.txt"
git -C "$TMP/hub" add -A && git -C "$TMP/hub" -c user.name=t -c user.email=t@example.invalid commit -qm stranded
printf 'w
' >> "$STATE/reviewer-events/events.jsonl"
run sync 2> "$TMP/out6" || { cat "$TMP/out6" >&2; exit 1; }
check 'unpushed local commits never reach GitHub' "! git -C '$REMOTE' log --format=%s main | grep -q stranded && ! git -C '$REMOTE' ls-tree -r --name-only main | grep -q sneak"

# Leak gate: if encryption silently produced clear text, nothing is pushed.
mkdir -p "$TMP/badssl"
cat > "$TMP/badssl/openssl" <<'FAKE'
#!/usr/bin/env bash
in=; out=
while [ $# -gt 0 ]; do case "$1" in -in) in="$2"; shift ;; -out) out="$2"; shift ;; esac; shift; done
cp "$in" "$out"
FAKE
chmod +x "$TMP/badssl/openssl"
printf '0 starts like DER
' > "$ISSUES/pkg/new.log"
before="$(git -C "$REMOTE" rev-parse main)"
check 'clear-text output is refused, even when it starts with 0' "! PATH='$TMP/badssl':\"\$PATH\" run sync 2> '$TMP/out7' && grep -q 'not encrypted' '$TMP/out7' && [ \"\$(git -C '$REMOTE' rev-parse main)\" = '$before' ]"
run sync 2> "$TMP/out7b" || { cat "$TMP/out7b" >&2; exit 1; }

check 'the shipped certificate is tracked' "git -C '$ROOT' ls-files --error-unmatch config/reviewer-logs-archive.crt >/dev/null 2>&1"

check 'option-like and path-like machine names refused' "! AI_REVIEWER_LOGS_MACHINE=--dry-run run sync 2>/dev/null && ! AI_REVIEWER_LOGS_MACHINE=.. run sync 2>/dev/null"

# A symbolic link committed to the repository stops the sync before any write.
git -C "$VIEW" pull -q
git -C "$VIEW" config user.name t; git -C "$VIEW" config user.email t@example.invalid
printf '%s' "$TMP/outside" > "$TMP/target"
blob="$(git -C "$VIEW" hash-object -w "$TMP/target")"
git -C "$VIEW" update-index --add --cacheinfo 120000,"$blob",evil-link
git -C "$VIEW" commit -qm link && git -C "$VIEW" push -q origin HEAD:main
printf 'more\n' >> "$STATE/reviewer-events/events.jsonl"
rc8=0; run sync 2> "$TMP/out8" || rc8=$?
check 'repository symlinks refused' "[ $rc8 -ne 0 ] && grep -q 'symbolic links' '$TMP/out8' && [ ! -e '$TMP/outside' ]"
check 'program is executable in git' "[ \"\$(git -C '$ROOT' ls-files -s bin/ai-reviewer-logs-sync | cut -c1-6)\" = 100755 ]"

printf 'PASS test-ai-reviewer-logs-sync (%s checks)\n' "$pass"
