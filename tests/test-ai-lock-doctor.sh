#!/usr/bin/env bash
# ai-lock-doctor suite (issue #1002 step 2). Offline. The /proc cases need a
# Linux host with flock; everywhere else they skip and only the portable
# Windows lock_acquire contract runs, exactly like tests/test-ai-qwen.sh.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCTOR="$ROOT/bin/ai-lock-doctor"
QWEN="$ROOT/bin/ai-qwen"
TMP="$(mktemp -d)"
PASS=0; FAIL=0
result(){
  if [ "$1" = pass ]; then PASS=$((PASS + 1)); printf '  ok   %s\n' "$2"
  else FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$2" >&2; fi
}
cleanup(){ kill "$@" 2>/dev/null || true; }
trap 'rm -rf "$TMP"' EXIT

# --- always: usage, executability, and platform refusal ---------------------

# The tool must be committed executable: install.sh links only executable
# bin/* entries, and the wired call sites test [ -x ] before falling back to
# PATH (first exact-head review of #1002, finding 1).
[ -x "$DOCTOR" ] && result pass 'ai-lock-doctor is committed executable' || result fail 'ai-lock-doctor is committed executable'
[ -f "$ROOT/bin/ai-lock-doctor.cmd" ] && result pass 'ai-lock-doctor carries a Windows .cmd launcher' || result fail 'ai-lock-doctor carries a Windows .cmd launcher'
bash -n "$DOCTOR" && result pass 'ai-lock-doctor passes bash -n' || result fail 'ai-lock-doctor passes bash -n'
if "$DOCTOR" >/dev/null 2>&1; then result fail 'no lock file argument refuses with usage'; else result pass 'no lock file argument refuses with usage'; fi
if "$DOCTOR" --no-such-flag "$TMP/x" >/dev/null 2>&1; then result fail 'unknown option is refused'; else result pass 'unknown option is refused'; fi
if "$DOCTOR" --older-than ten "$TMP/x" >/dev/null 2>&1; then result fail 'non-numeric --older-than is refused'; else result pass 'non-numeric --older-than is refused'; fi

# The wired wrappers must prove contention before any sweep, and must call
# the doctor only through the bounded --recover route (#1002 review, finding 4).
for wrapper in ai-qwen ai-muse ai-deepseek-agent; do
  body="$ROOT/bin/$wrapper"
  if grep -q 'flock -n .*true 2>/dev/null' "$body" && grep -q 'ai-lock-doctor' "$body" \
     && grep -q -- '--recover --older-than' "$body" && bash -n "$body"; then
    result pass "$wrapper probes contention and sweeps only through ai-lock-doctor"
  else
    result fail "$wrapper probes contention and sweeps only through ai-lock-doctor"
  fi
done

# --- portable: Qwen lock_acquire pid+age rule for Muse's legacy lock --------

FUNCS="$(sed -n '/^lock_publish() {/,/^}/p; /^lock_acquire() {/,/^}/p' "$QWEN")"
legacy_young="$TMP/muse-legacy-young.lock.d"; mkdir "$legacy_young"
printf '424242\n' > "$legacy_young/pid"
legacy_old="$TMP/muse-legacy-old.lock.d"; mkdir "$legacy_old"
printf '424242\n' > "$legacy_old/pid"
touch -d '20 minutes ago' "$legacy_old"
if ( source /dev/stdin
     lock_owner_record(){ cat "$1/owner" 2>/dev/null || true; }
     lock_owner_alive(){ return 1; } # MSYS pid invisible across Git Bash runtimes
     warn(){ :; }
     declare -A LOCK_TOKENS=()
     [ -n "${SYSTEMROOT:-}" ] || SYSTEMROOT=Windows   # force the Windows branch on Linux too
     export SYSTEMROOT
     ! lock_acquire "$legacy_young" test && [ -f "$legacy_young/pid" ] && [ ! -f "$legacy_young/owner" ]
   ) <<< "$FUNCS" >/dev/null 2>&1; then
  result pass 'a young legacy Muse lock is still never reclaimed on Windows'
else
  result fail 'a young legacy Muse lock is still never reclaimed on Windows'
fi
if ( source /dev/stdin
     lock_owner_record(){ cat "$1/owner" 2>/dev/null || true; }
     lock_owner_alive(){ return 1; }
     warn(){ :; }
     declare -A LOCK_TOKENS=()
     export SYSTEMROOT=Windows
     lock_acquire "$legacy_old" test && [ -f "$legacy_old/owner" ] && [ -f "$legacy_old/pid" ] \
       && [ "$(cat "$legacy_old/pid" 2>/dev/null || echo x)" != 424242 ]
   ) <<< "$FUNCS" >/dev/null 2>&1; then
  result pass 'an aged legacy Muse lock (pid invisible, older than 15 min) is reclaimed on Windows'
else
  result fail 'an aged legacy Muse lock (pid invisible, older than 15 min) is reclaimed on Windows'
fi
if ( source /dev/stdin
     lock_owner_record(){ cat "$1/owner" 2>/dev/null || true; }
     lock_owner_alive(){ return 0; } # a live, observable owner
     warn(){ :; }
     declare -A LOCK_TOKENS=()
     export SYSTEMROOT=Windows
     ! lock_acquire "$legacy_old" test && [ -f "$legacy_old/pid" ]
   ) <<< "$FUNCS" >/dev/null 2>&1; then
  result pass 'a live visible legacy owner never loses the lock, whatever the age'
else
  result fail 'a live visible legacy owner never loses the lock, whatever the age'
fi

# --- Linux /proc cases --------------------------------------------------------

if [ ! -r /proc/locks ] || [ ! -d /proc/self/fd ] || ! command -v flock >/dev/null 2>&1; then
  printf '  skip /proc-based cases: this host has no readable /proc/locks or no flock\n'
  printf 'ai-lock-doctor: %s pass, %s fail\n' "$PASS" "$FAIL"
  [ "$FAIL" -eq 0 ]
  exit 0
fi

lock="$TMP/op-refresh.lock"; : > "$lock"

# Case 3: no holder means nothing to do.
if "$DOCTOR" "$lock" >"$TMP/out3" 2>&1 && grep -q 'the lock is free' "$TMP/out3"; then
  result pass 'a lock with no holder reports free and exits 0'
else
  result fail 'a lock with no holder reports free and exits 0'
fi
if "$DOCTOR" --recover --older-than 1 "$lock" >"$TMP/out3b" 2>&1; then
  result pass 'recover with no holder exits 0'
else
  result fail 'recover with no holder exits 0'
fi

# Case 4: an inherited descriptor in a reparented child is found by inode,
# with no /proc/locks entry naming it (the #940 shape).
daemon_pid=''
setsid bash -c 'exec -a ailockdoctor-fdholder sleep 120' 9<"$lock" >/dev/null 2>&1 &
daemon_spawn=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  daemon_pid="$(ps -eo pid=,ppid=,args= | awk '$2 == 1 && /ailockdoctor-fdholder/ { print $1; exit }')"
  [ -n "$daemon_pid" ] && break
  sleep 0.2
done
if [ -n "$daemon_pid" ] && ! "$DOCTOR" "$lock" >"$TMP/out4" 2>&1 && grep -q "holder pid=$daemon_pid class=foreign" "$TMP/out4"; then
  result pass 'a detached fd holder is found by inode and classified foreign'
else
  result fail 'a detached fd holder is found by inode and classified foreign'
fi

# Case 2: a foreign holder is reported and NOT killed.
if ! "$DOCTOR" --recover --older-than 1 "$lock" >"$TMP/out5" 2>&1 && grep -q 'foreign holders remain' "$TMP/out5" \
   && kill -0 "$daemon_pid" 2>/dev/null; then
  result pass 'a foreign holder survives --recover and fails loudly'
else
  result fail 'a foreign holder survives --recover and fails loudly'
fi
kill "$daemon_pid" 2>/dev/null || true; wait "$daemon_spawn" 2>/dev/null || true

# Case 5: a lock held for less than the timeout is left alone.
flock "$lock" sleep 120 &
young_holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$lock" true 2>/dev/null || break; sleep 0.2; done
if ! "$DOCTOR" --recover --older-than 3600 "$lock" >"$TMP/out6" 2>&1 && grep -q 'younger than' "$TMP/out6" \
   && kill -0 "$young_holder" 2>/dev/null; then
  result pass 'an our-tool holder under the timeout is left alone'
else
  result fail 'an our-tool holder under the timeout is left alone'
fi
kill "$young_holder" 2>/dev/null || true; wait "$young_holder" 2>/dev/null || true
for _ in 1 2 3 4 5; do flock -n "$lock" true 2>/dev/null && break; sleep 0.2; done

# Case 1: a live our-tool holder at least as old as the wait is recovered,
# and the lock is really free afterwards (the #940 reproduction, time-scaled).
flock "$lock" sleep 120 &
stuck_holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$lock" true 2>/dev/null || break; sleep 0.2; done
sleep 2 # holder age crosses --older-than 2
start="$(date +%s)"
if "$DOCTOR" --recover --older-than 2 "$lock" >"$TMP/out7" 2>&1 && grep -q 'recovered' "$TMP/out7" \
   && flock -n "$lock" true 2>/dev/null \
   && ! kill -0 "$stuck_holder" 2>/dev/null; then
  result pass 'a live our-tool holder of age is TERM/KILLed and the lock is freed'
else
  result fail 'a live our-tool holder of age is TERM/KILLed and the lock is freed'
fi
elapsed=$(( $(date +%s) - start ))
[ "$elapsed" -lt 120 ] && result pass "recovery completed in ${elapsed}s (under the 2-minute gate)" \
                      || result fail "recovery took ${elapsed}s (the 2-minute gate is exceeded)"
cleanup "$stuck_holder" "$young_holder" "$daemon_pid" 2>/dev/null || true

printf 'ai-lock-doctor: %s pass, %s fail\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
