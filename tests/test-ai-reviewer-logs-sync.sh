#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0
check(){ if eval "$2"; then pass=$((pass + 1)); printf '  ok   %s\n' "$1"; else printf '  FAIL %s\n' "$1" >&2; exit 1; fi; }
# absent CMD...: true only when CMD ran fine and found nothing (exit 1); a
# checker error (exit 2+) or a match fails the check.
absent(){ local rc=0; "$@" >/dev/null 2>&1 || rc=$?; [ "$rc" -eq 1 ]; }
native(){ if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }

# Throwaway archive key pair for the test.
(umask 077; MSYS2_ARG_CONV_EXCL='*' openssl req -x509 -newkey rsa:2048 -nodes -keyout "$(native "$TMP/key.pem")" \
  -out "$(native "$TMP/cert.pem")" -days 2 -subj "/CN=test archive" >/dev/null 2>&1)

REMOTE="$TMP/logs.git"
git init -q --bare "$REMOTE"
git -C "$REMOTE" symbolic-ref HEAD refs/heads/main
# Like the real archive, the test archive starts with one empty commit on main.
git init -q "$TMP/seed" && git -C "$TMP/seed" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m start
git -C "$TMP/seed" push -q "$REMOTE" HEAD:main

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
  HOME="$TMP/home" AI_REVIEWER_LOGS_TEST_MODE=1 AI_REVIEWER_LOGS_REMOTE="${AI_REVIEWER_LOGS_REMOTE:-$REMOTE}" \
    AI_REVIEWER_LOGS_HUB="${AI_REVIEWER_LOGS_HUB:-$TMP/hub}" AI_REVIEWER_STATE_BASE="$STATE" AI_REVIEWER_ISSUE_DIR="$ISSUES" \
    AI_REVIEWER_LOGS_ROOTS="$REPOS:$REPOS2" AI_REVIEWER_LOGS_MAX_FILE_BYTES=2000 \
    AI_REVIEWER_LOGS_CHUNK_BYTES="${AI_REVIEWER_LOGS_CHUNK_BYTES:-80000000}" \
    AI_REVIEWER_LOGS_MACHINE="${AI_REVIEWER_LOGS_MACHINE:-test-box}" AI_REVIEWER_LOGS_CERT="$TMP/cert.pem" \
    AI_REVIEWER_LOGS_KEY_FILE="${AI_REVIEWER_LOGS_KEY_FILE-$TMP/key.pem}" \
    GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid \
    bash "$ROOT/bin/ai-reviewer-logs-sync" "$@"
}
view(){ rm -rf "$TMP/plain"; run view "$TMP/plain" >/dev/null 2>"$TMP/view.err" || { cat "$TMP/view.err" >&2; return 1; }; }

run sync 2> "$TMP/out1" || { cat "$TMP/out1" >&2; exit 1; }
VIEW="$TMP/view"; git clone -q "$REMOTE" "$VIEW"
M="$VIEW/test-box"; P="$TMP/plain/test-box"
check 'first run pushes the machine folder' "[ -f '$M/LAST-SYNC.txt' ] && ls '$M/bundles' | grep -q 'part001.tar.gz.cms'"
git -C "$VIEW" ls-files > "$TMP/published-1"
check 'only encrypted bundles and the status file are published' "absent grep -vE '^test-box/(bundles/[0-9TZ]+-[0-9a-f]+-part[0-9]{3}[.]tar[.]gz[.]cms|LAST-SYNC[.]txt)$' '$TMP/published-1'"
check 'no clear text from the logs reaches the repository' "absent git -C '$VIEW' grep -q -e 'after timeout' -e hunter3word -e APPROVE"
view
check 'view decrypts complete, unmasked evidence' "cmp -s '$ISSUES/pkg/provider.log' '$P/reviewer-issues/pkg/provider.log' && cmp -s '$ISSUES/pkg/blob.bin' '$P/reviewer-issues/pkg/blob.bin'"
check 'scoreboard, events and lifecycle collected' "[ -f '$P/state/review-scoreboard/reviews.jsonl' ] && [ -f '$P/state/reviewer-events/events.jsonl' ] && [ -f '$P/state/review-lifecycle/runs/r1/run.json' ]"
check 'review reports from same-named checkouts kept apart' "[ \$(ls '$P/reviews' | wc -l) -eq 2 ] && [ \$(grep -rl APPROVE '$P/reviews' | wc -l) -eq 1 ] && [ \$(grep -rl 'second checkout' '$P/reviews' | wc -l) -eq 1 ]"
git -C "$VIEW" ls-files > "$TMP/published-names"
check 'file names are never published in clear text' "absent grep -q -e '$fake_gh' -e provider -e codex-final '$TMP/published-names' && absent git -C '$VIEW' grep -q -e '$fake_gh' -e provider.log && [ -f '$P/reviewer-issues/pkg/$fake_gh.log' ]"
check 'odd file names are data, never commands' "[ ! -e PWNED ] && [ ! -e '$TMP/home/PWNED' ] && ls '$P/reviewer-issues/pkg' | grep -q 'touch PWNED'"
check 'oversized files skipped and listed inside the bundle' "[ ! -e '$P/reviewer-issues/pkg/large.txt' ] && cat '$P'/_collection/*-skipped.txt | grep -q 'large.txt'"
check 'provider session stores are not collected' "[ ! -e '$P/state/qwen' ]"

run sync 2> "$TMP/out2"
check 'unchanged rerun pushes nothing new' "grep -q 'nothing new' '$TMP/out2' && [ \$(git -C '$REMOTE' rev-list --count main) -eq 2 ]"

printf 'BBBB\n' > "$STATE/review-lifecycle/runs/r1/run.json"; touch -d '2002-02-02' "$STATE/review-lifecycle/runs/r1/run.json"
rm -f "$REPOS/app-one/.ai/reviews/codex-final-check.md"
run sync 2> "$TMP/out3" || { cat "$TMP/out3" >&2; exit 1; }
view
check 'changed content collected even with an old timestamp' "grep -q BBBB '$P/state/review-lifecycle/runs/r1/run.json'"
check 'files deleted locally stay in the archive' "[ \$(grep -rl APPROVE '$P/reviews' | wc -l) -eq 1 ]"

# Large runs are split into several compressed parts; view joins them back.
# Incompressible content: each part must still respect the raw-size bound.
mkdir -p "$ISSUES/many"; for n in 1 2 3 4 5 6; do head -c 1500 /dev/urandom > "$ISSUES/many/f$n.log"; done
AI_REVIEWER_LOGS_CHUNK_BYTES=3000 run sync 2> "$TMP/out17" || { cat "$TMP/out17" >&2; exit 1; }
git -C "$REMOTE" ls-tree -r --name-only main > "$TMP/tree17"
view
check 'large runs are split into parts and reassembled' "[ \$(grep -c 'part00[2-9]' '$TMP/tree17') -ge 1 ] && [ \$(ls '$P/reviewer-issues/many' | wc -l) -eq 6 ] && cmp -s '$ISSUES/many/f6.log' '$P/reviewer-issues/many/f6.log'"
biggest=0; for f in "$TMP/hub/test-box/bundles/"*part*.cms; do n="$(wc -c < "$f")"; [ "$n" -gt "$biggest" ] && biggest="$n"; done
check 'incompressible parts stay within the raw bound plus small overhead' "[ $biggest -le 6000 ]"
check 'a part size over 80 MB is refused' "! AI_REVIEWER_LOGS_CHUNK_BYTES=90000000 run sync 2>/dev/null"
head -c 4000 /dev/urandom > "$ISSUES/many/huge-for-chunk.log"
AI_REVIEWER_LOGS_CHUNK_BYTES=3000 run sync 2> "$TMP/out18" || { cat "$TMP/out18" >&2; exit 1; }
view
check 'a file larger than one part is listed as oversized, never forced into a part' "[ ! -e '$P/reviewer-issues/many/huge-for-chunk.log' ] && cat '$P'/_collection/*-skipped.txt | grep -q huge-for-chunk"
rm -f "$ISSUES/many/huge-for-chunk.log"

# Incident packages written inside other checkouts are collected too.
mkdir -p "$REPOS2/app-one/.ai/reviewer-issues/other-pkg"; printf 'from another checkout\n' > "$REPOS2/app-one/.ai/reviewer-issues/other-pkg/details.txt"
run sync 2> "$TMP/out21" || { cat "$TMP/out21" >&2; exit 1; }
view
check 'incident packages from every checkout are collected' "grep -rq 'from another checkout' '$P/reviewer-issues' && [ \$(grep -rl 'exit 1 after timeout' '$P/reviewer-issues' | wc -l) -eq 1 ]"

# A bundle lost from the published archive is put back from the local copy.
first="$(git -C "$REMOTE" ls-tree -r --name-only main | grep bundles | sort | head -1)"
git -C "$VIEW" pull -q; git -C "$VIEW" -c user.name=t -c user.email=t@example.invalid rm -q "$first"
git -C "$VIEW" -c user.name=t -c user.email=t@example.invalid commit -qm lose && git -C "$VIEW" push -q origin HEAD:main
rc=0; run view "$TMP/plain-incomplete" > /dev/null 2> "$TMP/out19" || rc=$?
check 'view fails loudly when a published bundle is missing' "[ $rc -eq 3 ] && grep -q INCOMPLETE '$TMP/out19' && grep -q 'part' '$TMP/plain-incomplete/INCOMPLETE-missing-bundles.txt'"
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
rc=0; run view "$TMP/plain" > /dev/null 2> "$TMP/out20" || rc=$?
check 'bundles lost everywhere are reported as known losses, not as an incomplete view' "[ $rc -eq 0 ] && grep -q 'known lost' '$TMP/out20'"

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
pybin="$(command -v python3 || command -v python)"
"$pybin" - "$(native "$TMP/evil2.tar")" <<'PY'
import io, sys, tarfile
with tarfile.open(sys.argv[1], "w") as t:
    data = b"x"
    info = tarfile.TarInfo(r"..\outside.txt"); info.size = len(data)
    t.addfile(info, io.BytesIO(data))
PY
MSYS2_ARG_CONV_EXCL='*' openssl cms -encrypt -binary -aes-256-cbc -outform DER -in "$(native "$TMP/evil2.tar")" \
  -out "$(native "$VIEW/test-box/bundles/99991231T000000000000001Z-evil.tar.cms")" "$(native "$TMP/cert.pem")"
git -C "$VIEW" add -A && git -C "$VIEW" -c user.name=t -c user.email=t@example.invalid commit -qm evil2 && git -C "$VIEW" push -q origin HEAD:main
check 'bundles with Windows-style escaping paths are not unpacked' "! run view '$TMP/plain' >/dev/null 2>'$TMP/out15' && grep -q 'unsafe path' '$TMP/out15' && [ ! -e '$TMP/outside.txt' ]"
git -C "$VIEW" -c user.name=t -c user.email=t@example.invalid rm -q test-box/bundles/99991231T000000000000001Z-evil.tar.cms
# The forged test bundles were removed on purpose: record them as known losses.
printf '%s\n' test-box/bundles/99991231T000000000000000Z-evil.tar.cms test-box/bundles/99991231T000000000000001Z-evil.tar.cms >> "$VIEW/test-box/LOST-BUNDLES.txt"
git -C "$VIEW" add test-box/LOST-BUNDLES.txt
git -C "$VIEW" -c user.name=t -c user.email=t@example.invalid commit -qm unevil && git -C "$VIEW" push -q origin HEAD:main

# Hashing failure: partial, exit 2, never recorded complete; a clean retry clears it.
mkdir -p "$TMP/badbin"; real_sha="$(command -v sha256sum)"
printf '#!/usr/bin/env bash\ncase " $* " in *" -z "*) echo "sha256sum: read error" >&2; exit 1 ;; esac\nexec "%s" "$@"\n' "$real_sha" > "$TMP/badbin/sha256sum"
chmod +x "$TMP/badbin/sha256sum"
rc=0; PATH="$TMP/badbin:$PATH" run sync 2> "$TMP/out4" || rc=$?
git -C "$VIEW" pull -q
check 'read failures fail the run and are published as incomplete' "[ $rc -eq 2 ] && grep -q PARTIAL '$TMP/out4' && grep -q '^complete: no' '$M/LAST-SYNC.txt'"
run sync 2> "$TMP/out5" || { cat "$TMP/out5" >&2; exit 1; }
git -C "$VIEW" pull -q
check 'a clean retry clears the read-failure mark but still reports oversized files' "absent grep -q 'could not be read' '$M/LAST-SYNC.txt' && grep -q '^complete: no - 1 files over the size limit' '$M/LAST-SYNC.txt'"
rm -f "$ISSUES/pkg/large.txt"; printf 'v\n' >> "$STATE/reviewer-events/events.jsonl"
run sync 2> "$TMP/out5b" || { cat "$TMP/out5b" >&2; exit 1; }
git -C "$VIEW" pull -q
check 'complete: yes only when nothing was left out' "grep -q '^complete: yes' '$M/LAST-SYNC.txt'"

# An unpushed local commit (here carrying clear text) never reaches GitHub; the
# next run starts from the published archive.
printf 'stranded clear text
' > "$TMP/hub/test-box/sneak.txt"
git -C "$TMP/hub" add -A && git -C "$TMP/hub" -c user.name=t -c user.email=t@example.invalid commit -qm stranded
printf 'w
' >> "$STATE/reviewer-events/events.jsonl"
run sync 2> "$TMP/out6" || { cat "$TMP/out6" >&2; exit 1; }
git -C "$REMOTE" log --format=%s main > "$TMP/remote-log"; git -C "$REMOTE" ls-tree -r --name-only main > "$TMP/remote-tree"
check 'unpushed local commits never reach GitHub' "absent grep -q stranded '$TMP/remote-log' && absent grep -q sneak '$TMP/remote-tree'"

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

cp "$TMP/key.pem" "$TMP/plain/key.pem"
check 'a key inside the view folder is refused and kept' "! AI_REVIEWER_LOGS_KEY_FILE='$TMP/plain/key.pem' run view '$TMP/plain' >/dev/null 2>&1 && [ -f '$TMP/plain/key.pem' ]"
ln -s "$TMP/plain/key.pem" "$TMP/keylink.pem" 2>/dev/null && [ -L "$TMP/keylink.pem" ] &&   check 'a key symlink into the view folder is refused' "! AI_REVIEWER_LOGS_KEY_FILE='$TMP/keylink.pem' run view '$TMP/plain' >/dev/null 2>&1 && [ -f '$TMP/plain/key.pem' ]"
mkdir -p "$TMP/home/.ai-devops/reviewer-logs-sync/sync.lock"; sleep 600 & live=$!
printf '%s %s' "$live" "$(awk '{print $22}' "/proc/$live/stat")" > "$TMP/home/.ai-devops/reviewer-logs-sync/sync.lock/owner"
touch -d '2001-01-01' "$TMP/home/.ai-devops/reviewer-logs-sync/sync.lock"
check 'a live lock is never broken, however old' "! run sync 2>/dev/null && [ -d '$TMP/home/.ai-devops/reviewer-logs-sync/sync.lock' ]"
kill "$live" 2>/dev/null; wait "$live" 2>/dev/null || true
check 'a dead owner lock is reclaimed' "run sync 2>/dev/null"
mkdir -p "$TMP/home/.ai-devops/reviewer-logs-sync/sync.lock"
printf '%s 1' "$$" > "$TMP/home/.ai-devops/reviewer-logs-sync/sync.lock/owner"
check 'a reused process id does not keep the lock' "run sync 2>/dev/null"
check 'openssl is required only by sync and view, never by help or unschedule' "[ \$(grep -c '^  need_openssl\$' '$ROOT/bin/ai-reviewer-logs-sync') -eq 2 ] && absent grep -q '^need_openssl\$' '$ROOT/bin/ai-reviewer-logs-sync'"
q="$TMP/it's"; mkdir -p "$q/bin" "$q/tools/lib"
cp "$ROOT/bin/ai-reviewer-logs-sync" "$q/bin/"; cp "$ROOT/tools/lib/local-watch.sh" "$q/tools/lib/"
HOME="$TMP/home" bash "$q/bin/ai-reviewer-logs-sync" schedule > "$TMP/out16" 2>&1 || true
check 'scheduling from a quoted path is refused' "grep -q 'contains a quote' '$TMP/out16'"
if [ -n "${SYSTEMROOT:-}" ]; then
  # Scheduling from a profile with a space quotes every path in the timer command.
  mkdir -p "$TMP/fakesched" "$TMP/home with space"
  printf '#!/usr/bin/env bash\nprintf "%%s\n" "$@" > "%s/schtasks.args"\n' "$TMP" > "$TMP/fakesched/schtasks.exe"
  chmod +x "$TMP/fakesched/schtasks.exe"
  PATH="$TMP/fakesched:$PATH" HOME="$TMP/home with space" bash "$ROOT/bin/ai-reviewer-logs-sync" schedule > /dev/null 2>&1 || true
  check 'scheduled command quotes a log path containing a space' "grep -qF \"/reviewer-logs-sync/cron.log' 2>&1\" '$TMP/schtasks.args' && grep -qF \"'$TMP/home with space\" '$TMP/schtasks.args'"
fi
# The production privacy probe runs with no ambient credentials (stub git records
# its environment and reports "readable", so the run stops before any network use).
mkdir -p "$TMP/probe-git"
printf '#!/usr/bin/env bash\ncase " $* " in *" ls-remote "*) env > "%s/probe-env"; exit 0 ;; esac\nexit 1\n' "$TMP" > "$TMP/probe-git/git"
chmod +x "$TMP/probe-git/git"
GIT_ASKPASS=/bin/echo SSH_ASKPASS=/bin/echo GH_TOKEN=x PATH="$TMP/probe-git:$PATH" HOME="$TMP/home" \
  AI_REVIEWER_LOGS_HUB="$TMP/probe-hub" bash "$ROOT/bin/ai-reviewer-logs-sync" sync > "$TMP/out22" 2>&1 || true
check 'the anonymous privacy probe carries no credentials and blocks a readable archive' "grep -q 'publicly readable' '$TMP/out22' && absent grep -qE '^(GIT_ASKPASS|SSH_ASKPASS|GH_TOKEN)=' '$TMP/probe-env' && grep -q '^GIT_CONFIG_GLOBAL=/dev/null' '$TMP/probe-env'"
git -C "$REMOTE" log --format='%an <%ae>|%cn <%ce>' main | grep -v '^t <t@example.invalid>|t <t@example.invalid>$' | sort -u > "$TMP/idents"
check 'archive commits always carry the owner identity' "[ \"\$(cat '$TMP/idents')\" = 'Albert Hazan <u2giants@users.noreply.github.com>|Albert Hazan <u2giants@users.noreply.github.com>' ]"
mkdir -p "$TMP/fake-uname"; printf '#!/bin/sh\necho Darwin\n' > "$TMP/fake-uname/uname"; chmod +x "$TMP/fake-uname/uname"
PATH="$TMP/fake-uname:$PATH" bash "$ROOT/bin/ai-reviewer-logs-sync" sync > "$TMP/out23" 2>&1 || true
check 'unsupported systems are refused clearly' "grep -q 'Linux and Windows' '$TMP/out23'"
# Cleaned machine names never collide with a literal name.
printf 'm\n' >> "$STATE/reviewer-events/events.jsonl"
AI_REVIEWER_LOGS_MACHINE=build_1 run sync > /dev/null 2>&1 || true
git -C "$REMOTE" ls-tree --name-only main > "$TMP/machines"
check 'cleaned machine names get a fingerprint' "grep -qE '^build-1-[0-9a-f]{8}\$' '$TMP/machines'"

# A rejected push leaves the bundle recorded locally; the next run publishes it.
printf '#!/bin/sh\nexit 1\n' > "$REMOTE/hooks/pre-receive"; chmod +x "$REMOTE/hooks/pre-receive"
printf 'evidence during an outage\n' > "$ISSUES/pkg/outage.log"
run sync > /dev/null 2>&1 || true
rm -f "$REMOTE/hooks/pre-receive"
run sync 2> "$TMP/out24" || { cat "$TMP/out24" >&2; exit 1; }
view
check 'bundles from a failed push are published by the next run' "grep -q 'restored' '$TMP/out24' && grep -q 'during an outage' '$P/reviewer-issues/pkg/outage.log'"
AI_REVIEWER_LOGS_REMOTE='https://user:SECRETTOKEN@github.com/u2giants/ai-devops-reviewer-logs.git' HOME="$TMP/home" bash "$ROOT/bin/ai-reviewer-logs-sync" sync > "$TMP/out25" 2>&1 || true
check 'addresses carrying credentials are refused without echoing them' "grep -q 'must not contain credentials' '$TMP/out25' && absent grep -q SECRETTOKEN '$TMP/out25'"
git -C "$TMP/hub" remote set-url origin "file://user:STOREDSECRET@localhost$REMOTE"
git -C "$TMP/hub" config remote.origin.pushurl "file://user:STOREDSECRET@localhost$REMOTE"
printf 's\n' >> "$STATE/reviewer-events/events.jsonl"
run sync > "$TMP/out26" 2>&1 || { cat "$TMP/out26" >&2; exit 1; }
check 'a stored address with credentials is replaced before any use' "absent grep -q STOREDSECRET '$TMP/hub/.git/config' && absent grep -q STOREDSECRET '$TMP/out26' && absent grep -rq STOREDSECRET '$TMP/home/.ai-devops/reviewer-logs-sync'"
for addr in 'SCPSECRET@github.com:u2giants/ai-devops-reviewer-logs.git' 'ssh://SCPSECRET@github.com/u2giants/ai-devops-reviewer-logs.git' 'https://SCPSECRET@github.com/u2giants/ai-devops-reviewer-logs.git'; do
  AI_REVIEWER_LOGS_REMOTE="$addr" HOME="$TMP/home" bash "$ROOT/bin/ai-reviewer-logs-sync" sync > "$TMP/out27" 2>&1 || true
  check "credential-bearing address refused: ${addr%%SCPSECRET*}...@" "grep -q 'must not contain credentials' '$TMP/out27' && absent grep -q SCPSECRET '$TMP/out27'"
done
for addr in 'github.com:u2giants/ai-devops-reviewer-logs.git' 'git@github.com/u2giants/ai-devops-reviewer-logs.git'; do
  AI_REVIEWER_LOGS_REMOTE="$addr" HOME="$TMP/home" bash "$ROOT/bin/ai-reviewer-logs-sync" sync > "$TMP/out28" 2>&1 || true
  check "malformed archive address refused: $addr" "grep -q 'not the private reviewer-logs repository' '$TMP/out28'"
done
git init -q --bare "$TMP/empty.git"
AI_REVIEWER_LOGS_REMOTE="$TMP/empty.git" AI_REVIEWER_LOGS_HUB="$TMP/empty-hub" run sync > "$TMP/out29" 2>&1 || true
check 'an archive without main is refused and nothing is pushed' "grep -q 'has no main branch' '$TMP/out29' && [ -z \"\$(git -C '$TMP/empty.git' for-each-ref)\" ]"
check 'view needs a key file and never calls 1Password itself' "! AI_REVIEWER_LOGS_KEY_FILE= HOME='$TMP/home' AI_REVIEWER_LOGS_TEST_MODE=1 AI_REVIEWER_LOGS_REMOTE='$REMOTE' AI_REVIEWER_LOGS_HUB='$TMP/hub' bash '$ROOT/bin/ai-reviewer-logs-sync' view '$TMP/nokey' 2>/dev/null && ! grep -q 'op read' <(grep -v '^#' '$ROOT/bin/ai-reviewer-logs-sync')"
if [ -n "${SYSTEMROOT:-}" ]; then
  acl="$(icacls "$(cygpath -w "$TMP/home/.ai-devops/reviewer-logs-sync")")"
  printf '%s\n' "$acl" > "$TMP/acl.txt"
  check 'state folder is owner-only on Windows' "[ -s '$TMP/acl.txt' ] && absent grep -qiE 'users:|everyone:|authenticated' '$TMP/acl.txt'"
fi
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
