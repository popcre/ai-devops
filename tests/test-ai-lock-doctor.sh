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

# On failure, show WHY: the doctor's verdict plus the /proc facts the case
# was built on (bounded). Offline lane only; nothing here is a secret — the
# fixtures are all this suite's own processes.
dump_case(){
  local label="$1" out="$2"; shift 2
  printf '  ---- %s diagnostics ----\n' "$label" >&2
  [ -f "$out" ] && sed -n '1,25p' "$out" >&2
  local p
  for p in "$@"; do
    [ -n "$p" ] || continue
    kill -0 "$p" 2>/dev/null || { printf '  pid %s: gone\n' "$p" >&2; continue; }
    printf '  pid %s: cmdline=<%s> ppid/state/start=<%s> fds=<%s>\n' "$p" \
      "$(tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | cut -c1-80)" \
      "$(awk '{print $4, $3, $22}' "/proc/$p/stat" 2>/dev/null)" \
      "$(ls "/proc/$p/fd" 2>/dev/null | tr '\n' ' ')" >&2
  done
  printf '  /proc/locks (first 20):\n' >&2
  sed -n '1,20p' /proc/locks >&2
  printf '  lock inode: %s  btime=%s hertz=%s now=%s\n' \
    "$(stat -Lc '%d:%i' "$lock" 2>/dev/null)" \
    "$(sed -n 's/^btime //p' /proc/stat 2>/dev/null)" \
    "$(getconf CLK_TCK 2>/dev/null)" "$(date +%s)" >&2
  printf '  ---- end diagnostics ----\n' >&2
}

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

# The wired wrappers must prove contention (flock's conflict exit code) before
# any sweep, and must call the doctor only through the bounded --recover route
# (#1002 reviews, findings 4 and 5 of rounds 3 and 4).
for wrapper in ai-qwen ai-muse ai-deepseek-agent; do
  body="$ROOT/bin/$wrapper"
  if grep -q -- '-E 87' "$body" && grep -q 'ai-lock-doctor' "$body" \
     && grep -q -- '--recover --older-than' "$body" && bash -n "$body"; then
    result pass "$wrapper proves contention and sweeps only through ai-lock-doctor"
  else
    result fail "$wrapper proves contention and sweeps only through ai-lock-doctor"
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
# with no /proc/locks entry naming it (the #940 shape). The daemon records
# its own pid before exec: a ps-based ppid==1 lookup assumed orphans land on
# init, but runners with a subreaper reparent elsewhere, so the pid (and the
# case) was never found there.
daemon_pid=''
daemon_pidfile="$TMP/daemon.pid"; rm -f "$daemon_pidfile"
setsid bash -c 'printf "%s\n" "$$" >"$1"; exec -a ailockdoctor-fdholder sleep 120' _ "$daemon_pidfile" 9<"$lock" >/dev/null 2>&1 &
daemon_spawn=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -s "$daemon_pidfile" ] && break
  sleep 0.2
done
daemon_pid="$(cat "$daemon_pidfile" 2>/dev/null || true)"
if [ -n "$daemon_pid" ] && ! "$DOCTOR" "$lock" >"$TMP/out4" 2>&1 && grep -q "holder pid=$daemon_pid class=foreign" "$TMP/out4"; then
  result pass 'a detached fd holder is found by inode and classified foreign'
else
  result fail 'a detached fd holder is found by inode and classified foreign'
  dump_case 'case4 detached fd holder' "$TMP/out4" "$daemon_pid"
fi
kill "$daemon_pid" 2>/dev/null || true; wait "$daemon_spawn" 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 "$daemon_pid" 2>/dev/null || break; sleep 0.2; done

# Case 2: a foreign holder of a REAL flock is reported and NOT killed. The
# renamed argv[0] keeps the doctor's our-tool rule (an flock on this exact
# lock) from matching, so the holder is foreign by proof, not by accident.
# --close keeps the sleep child from inheriting the lock fd, so killing the
# recorded wrapper pid at cleanup really frees the lock for the next case.
foreign_pid=''
foreign_pidfile="$TMP/foreign.pid"; rm -f "$foreign_pidfile"
setsid bash -c 'printf "%s\n" "$$" >"$1"; exec -a ailockdoctor-foreign flock --close "$2" sleep 120' _ "$foreign_pidfile" "$lock" >/dev/null 2>&1 &
foreign_spawn=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [ -s "$foreign_pidfile" ] && break
  sleep 0.2
done
foreign_pid="$(cat "$foreign_pidfile" 2>/dev/null || true)"
for _ in 1 2 3 4 5 6 7 8 9 10; do
  flock -n "$lock" true 2>/dev/null || break   # held: the foreign flock is really up
  sleep 0.2
done
if [ -n "$foreign_pid" ] && ! "$DOCTOR" --recover --older-than 1 "$lock" >"$TMP/out5" 2>&1 && grep -q 'foreign holders remain' "$TMP/out5" \
   && kill -0 "$foreign_pid" 2>/dev/null; then
  result pass 'a foreign holder survives --recover and fails loudly'
else
  result fail 'a foreign holder survives --recover and fails loudly'
  dump_case 'case2 foreign holder' "$TMP/out5" "$foreign_pid"
fi
kill "$foreign_pid" 2>/dev/null || true; wait "$foreign_spawn" 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$lock" true 2>/dev/null && break; sleep 0.2; done

# Case 5: a lock held for less than the timeout is left alone. --close keeps
# the sleep child from inheriting the lock fd: the case's cleanup kills only
# the wrapper, and an orphaned fd child would hold the lock for its full
# 120s, silently poisoning every later case (live evidence, seventh pass).
flock --close "$lock" sleep 120 &
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
# WITHOUT --close, on purpose: the wrapper's sleep child inherits the lock fd
# and the doctor must clear both.
flock "$lock" sleep 120 &
stuck_holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$lock" true 2>/dev/null || break; sleep 0.2; done
sleep 3 # holder AND its inherited-fd child cross --older-than 2 with margin
start="$(date +%s)"
if "$DOCTOR" --recover --older-than 2 "$lock" >"$TMP/out7" 2>&1 && grep -q 'recovered' "$TMP/out7" \
   && flock -n "$lock" true 2>/dev/null \
   && ! kill -0 "$stuck_holder" 2>/dev/null; then
  result pass 'a live our-tool holder of age is TERM/KILLed and the lock is freed'
else
  result fail 'a live our-tool holder of age is TERM/KILLed and the lock is freed'
  dump_case 'case1 our-tool holder of age' "$TMP/out7" "$stuck_holder"
fi
# The inherited-fd child must not outlive this case whatever the verdict:
# kill the wrapper and any child it still parents.
stuck_child="$(ps -o pid= --ppid "$stuck_holder" 2>/dev/null | tr -d ' ' | head -1)"
kill "$stuck_holder" 2>/dev/null || true
[ -n "$stuck_child" ] && kill "$stuck_child" 2>/dev/null || true
wait "$stuck_holder" 2>/dev/null || true
for _ in 1 2 3 4 5; do flock -n "$lock" true 2>/dev/null && break; sleep 0.2; done
elapsed=$(( $(date +%s) - start ))
[ "$elapsed" -lt 120 ] && result pass "recovery completed in ${elapsed}s (under the 2-minute gate)" \
                      || result fail "recovery took ${elapsed}s (the 2-minute gate is exceeded)"

# Case 6: a kernel-proven BLOCKED WAITER is never signalled, even of age and
# provably our-tool: an flock -w waiter opens the lock file, so only the
# /proc/locks "->" line separates it from the stuck holder. Recovery of the
# real holder lets the waiter take the lock and finish cleanly (exit 0, not
# a signal death) — sixth exact-head review, finding 2. The doctor's own
# exit code is not asserted: the waiter legitimately holds the lock for a
# moment while taking over, and seeing that is correct, not a failure.
flock --close "$lock" sleep 120 &
stuck_waiter_case_holder=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do flock -n "$lock" true 2>/dev/null || break; sleep 0.2; done
flock -w 60 "$lock" true &
blocked_waiter=$!
sleep 3 # holder and waiter both cross --older-than 2 with margin
"$DOCTOR" --recover --older-than 2 "$lock" >"$TMP/out8" 2>&1 || true
if grep -q "holder pid=$blocked_waiter class=waiter" "$TMP/out8" \
   && ! grep -q "recovering our-tool holder pid=$blocked_waiter" "$TMP/out8"; then
  wait "$blocked_waiter"; waiter_rc=$?
  if [ "$waiter_rc" -eq 0 ] && ! kill -0 "$stuck_waiter_case_holder" 2>/dev/null \
     && flock -n "$lock" true 2>/dev/null; then
    result pass 'a kernel-proven blocked waiter is never signalled and finishes cleanly'
  else
    result fail 'a kernel-proven blocked waiter is never signalled and finishes cleanly'
  fi
else
  kill "$blocked_waiter" 2>/dev/null || true; wait "$blocked_waiter" 2>/dev/null || true
  result fail 'a kernel-proven blocked waiter is never signalled and finishes cleanly'
  dump_case 'case6 blocked waiter' "$TMP/out8" "$stuck_waiter_case_holder" "$blocked_waiter"
fi
kill "$stuck_waiter_case_holder" 2>/dev/null || true; wait "$stuck_waiter_case_holder" 2>/dev/null || true
for _ in 1 2 3 4 5; do flock -n "$lock" true 2>/dev/null && break; sleep 0.2; done

cleanup "$stuck_holder" "$young_holder" "$daemon_pid" 2>/dev/null || true

printf 'ai-lock-doctor: %s pass, %s fail\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
