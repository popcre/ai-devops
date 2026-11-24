#!/usr/bin/env bash
# Offline tests for bin/ai-memory-health.
# The point of the tool is that it REPORTS and never edits, so the safety test
# (nothing on disk changes) matters as much as the detection tests.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-memory-health"
# Point the hub check at an empty directory so the real checkout's sync state
# cannot leak into these assertions.
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

mk_project() { # mk_project <name>
  mkdir -p "$TMP/home/projects/$1/memory"
  printf '%s' "$TMP/home/projects/$1/memory"
}

mk_memory() { # mk_memory <dir> <slug> <description> [body]
  cat > "$2/$3.md" <<EOF
---
name: $3
description: "$4"
metadata:
  node_type: memory
  type: project
---

${5:-body text}
EOF
}

# --- clean project -----------------------------------------------------------
CLEAN="$(mk_project clean)"
mk_memory x "$CLEAN" alpha "the alpha fact about widgets"
mk_memory x "$CLEAN" beta "an unrelated note concerning payroll timing"
cat > "$CLEAN/MEMORY.md" <<'EOF'
# Memory index

- [Alpha](alpha.md) — hook
- [Beta](beta.md) — hook
EOF

out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"; rc=$?
check "clean project exits 0" "[ $rc -eq 0 ]"
check "clean project reports clean" "printf '%s' \"\$out\" | grep -q 'clean'"

# --- unindexed memory --------------------------------------------------------
mk_memory x "$CLEAN" gamma "a third fact nobody indexed"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"; rc=$?
check "unindexed memory exits 1" "[ $rc -eq 1 ]"
check "unindexed memory is named" "printf '%s' \"\$out\" | grep -q 'NOT IN INDEX: gamma.md'"

# --- broken index line -------------------------------------------------------
echo '- [Ghost](ghost.md) — hook' >> "$CLEAN/MEMORY.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "broken index line detected" "printf '%s' \"\$out\" | grep -q 'BROKEN INDEX LINE: MEMORY.md points at missing ghost.md'"

# --- dangling cross-link -----------------------------------------------------
printf '\nSee [[nowhere-at-all]].\n' >> "$CLEAN/alpha.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "dangling link detected" "printf '%s' \"\$out\" | grep -q 'DANGLING LINK: \[\[nowhere-at-all\]\]'"

# --- missing frontmatter -----------------------------------------------------
BARE="$(mk_project bare)"
printf 'just prose, no frontmatter\n' > "$BARE/loose.md"
printf '# Memory index\n\n- [Loose](loose.md) — hook\n' > "$BARE/MEMORY.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "missing frontmatter detected" "printf '%s' \"\$out\" | grep -q 'NO FRONTMATTER: loose.md'"

# --- missing index -----------------------------------------------------------
NOIDX="$(mk_project noindex)"
mk_memory x "$NOIDX" orphan "a fact with no index at all"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "missing index detected" "printf '%s' \"\$out\" | grep -q 'NO INDEX'"

# --- possible duplicate ------------------------------------------------------
DUP="$(mk_project dupes)"
mk_memory x "$DUP" first  "the supabase service account token rotated and every project reference broke"
mk_memory x "$DUP" second "the supabase service account token rotated breaking every stored reference"
printf '# Memory index\n\n- [First](first.md) — hook\n- [Second](second.md) — hook\n' > "$DUP/MEMORY.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "possible duplicate detected" "printf '%s' \"\$out\" | grep -q 'POSSIBLE DUPLICATE'"

# --- two identical notes in a two-note project -------------------------------
# Every word is in both notes, so the rarity weight must never collapse to 0.
PAIR="$(mk_project pair)"
mk_memory x "$PAIR" one "the supabase service account token rotated and every project reference broke"
mk_memory x "$PAIR" two "the supabase service account token rotated and every project reference broke"
printf '# Memory index\n\n- [One](one.md) — hook\n- [Two](two.md) — hook\n' > "$PAIR/MEMORY.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "two identical notes in a two-note project are a duplicate" "printf '%s' \"\$out\" | grep -q 'POSSIBLE DUPLICATE: one.md and two.md'"

# --- template wording is not a duplicate (#2808) ------------------------------
# 78 chapter notes whose descriptions share "Shared-db chapter (<topic>): N
# consolidated facts." flagged 2,150 pairs on hetz. Each holds different facts.
TPL="$(mk_project chapters)"
for n in 1 2 3 4 5 6 7 8 9 10 11 12; do
  mk_memory x "$TPL" "chapter-lease-$n" "Shared-db chapter (claim-lease-queue): 2 consolidated facts. mutex-waits-are-not-blockers-$n; ledger-reads-need-a-refresh-$n"
done
{ printf '# Memory index\n\n'; for n in 1 2 3 4 5 6 7 8 9 10 11 12; do printf -- '- [c%s](chapter-lease-%s.md) — hook\n' "$n" "$n"; done; } > "$TPL/MEMORY.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "template wording alone is not a duplicate" "! printf '%s' \"\$out\" | grep -q 'POSSIBLE DUPLICATE: chapter-lease-'"

# A real copy inside such a project must still be reported, and only that pair.
mk_memory x "$TPL" chapter-lease-13 "Shared-db chapter (claim-lease-queue): 2 consolidated facts. mutex-waits-are-not-blockers-1; ledger-reads-need-a-refresh-1"
echo '- [c13](chapter-lease-13.md) — hook' >> "$TPL/MEMORY.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "an identical note inside a templated project is still a duplicate" \
  "printf '%s' \"\$out\" | grep -qE 'POSSIBLE DUPLICATE: chapter-lease-(1\\.md and chapter-lease-13|13\\.md and chapter-lease-1)\\.md'"
check "the templated project reports only that pair" \
  "[ \"\$(printf '%s' \"\$out\" | grep -c 'POSSIBLE DUPLICATE: chapter-lease-')\" -eq 1 ]"

# --- oversized index ---------------------------------------------------------
BIG="$(mk_project big)"
mk_memory x "$BIG" solo "one fact"
{ printf '# Memory index\n\n- [Solo](solo.md) — hook\n'; for i in $(seq 1 250); do printf -- '- filler line %s\n' "$i"; done; } > "$BIG/MEMORY.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "oversized index detected" "printf '%s' \"\$out\" | grep -q 'INDEX TOO LONG'"

# --- the index size gate must fire in --coverage-only ------------------------
# That is the ONLY mode bin/ai-memory-sync gates on. Before 2026-08-26 the size
# limit was skipped in that mode, so an index could grow past it for weeks
# without ever blocking a sync - the budget existed and never bit.
FAT="$(mk_project fat)"
mk_memory x "$FAT" solo "one fact"
{ printf '# Memory index\n\n- [Solo](solo.md) - hook\n'
  for i in $(seq 1 120); do
    printf -- '- [Entry %s](entry%s.md) - %s\n' "$i" "$i" "$(printf 'x%.0s' $(seq 1 140))"
  done
} > "$FAT/MEMORY.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" --coverage-only 2>&1)"; rc=$?
check "index size is checked in --coverage-only (the sync gate)" \
  "printf '%s' \"\$out\" | grep -q 'INDEX TOO BIG'"
check "an oversized index fails the run, so sync is gated" "[ $rc -ne 0 ]"

# The limit must be low enough to matter: a real 9.3KB index sat at 36% of the
# old 25KB limit and would never have warned.
{ printf '# Memory index\n\n- [Solo](solo.md) - hook\n'
  for i in $(seq 1 90); do
    printf -- '- [Entry %s](entry%s.md) - %s\n' "$i" "$i" "$(printf 'y%.0s' $(seq 1 140))"
  done
} > "$FAT/MEMORY.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" --coverage-only 2>&1)"
check "a 14KB index is over the limit too" "printf '%s' \"\$out\" | grep -q 'INDEX TOO BIG'"

# --- stale threshold is configurable ----------------------------------------
touch -d '2020-01-01' "$CLEAN/beta.md" 2>/dev/null || touch -t 202001010000 "$CLEAN/beta.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" --stale-days 30 2>&1)"
check "stale memory detected at 30 days" "printf '%s' \"\$out\" | grep -q 'UNTOUCHED >30d: beta.md'"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" --stale-days 99999 2>&1)"
check "stale memory not flagged at 99999 days" "! printf '%s' \"\$out\" | grep -q 'UNTOUCHED'"

# --- SAFETY: the audit must never modify anything ---------------------------
before="$(find "$TMP/home" -type f -printf '%p %s %T@\n' | sort | md5sum)"
"$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" >/dev/null 2>&1
after="$(find "$TMP/home" -type f -printf '%p %s %T@\n' | sort | md5sum)"
check "audit changed nothing on disk" "[ \"$before\" = \"$after\" ]"

# --- --out writes a copy -----------------------------------------------------
"$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" --out "$TMP/report.md" >/dev/null 2>&1
check "--out writes the report" "[ -s \"$TMP/report.md\" ]"
check "--out report names the machine" "grep -q 'Machine:' \"$TMP/report.md\""

# --- bad usage ---------------------------------------------------------------
"$SCRIPT" --nonsense >/dev/null 2>&1; rc=$?
check "unknown option exits 2" "[ $rc -eq 2 ]"
"$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/does-not-exist" >/dev/null 2>&1; rc=$?
check "missing projects dir exits 2" "[ $rc -eq 2 ]"

# --- trend reporting ---------------------------------------------------------
# The weekly report listed symptoms for weeks without showing the trajectory, so
# nobody read a growing hub as a problem. The summary must state the direction.
TREND="$TMP/trend.state"
rm -f "$TREND"
out="$(AI_MEMORY_HEALTH_STATE="$TREND" "$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "first run declares itself the baseline" "printf '%s' \"\$out\" | grep -q 'this run is the baseline'"
check "summary reports index weight" "printf '%s' \"\$out\" | grep -q 'KB of index loaded per session'"
check "first run records state" "[ -s \"$TREND\" ]"

out="$(AI_MEMORY_HEALTH_STATE="$TREND" "$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "an unchanged week reports no change" "printf '%s' \"\$out\" | grep -q 'files no change'"
check "a flat index carries no stray unit" "! printf '%s' \"\$out\" | grep -q 'no changeKB'"

printf '%s|0|2020-01-01|1|1|1024|0\n' "$(hostname)" > "$TREND"
out="$(AI_MEMORY_HEALTH_STATE="$TREND" "$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "growth since the last report is stated" "printf '%s' \"\$out\" | grep -qE 'since 2020-01-01: projects \+'"

before_trend="$(find "$TMP/home" -type f -printf '%p %s %T@\n' | sort | md5sum)"
AI_MEMORY_HEALTH_STATE="$TREND" "$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" >/dev/null 2>&1
after_trend="$(find "$TMP/home" -type f -printf '%p %s %T@\n' | sort | md5sum)"
check "trend tracking still changes no memory" "[ \"$before_trend\" = \"$after_trend\" ]"

# The installed command may be a chain of relative and absolute symlinks.
# Invoke that chain outside the checkout and use a separate synthetic hub to
# prove root resolution and the explicit --repo-root override together.
LINK_REPO="$TMP/linked-command-hub"
OVERRIDE_REPO="$TMP/explicit-override-hub"
LINK_HOME="$TMP/linked-command-home"
mkdir -p "$TMP/link-one/bin" "$TMP/link-two" "$TMP/unrelated" "$LINK_HOME" \
         "$LINK_REPO/bin" "$LINK_REPO/memory/synthetic" "$OVERRIDE_REPO/memory/override"
cp "$SCRIPT" "$LINK_REPO/bin/ai-memory-health"
printf 'synthetic fact\n' > "$LINK_REPO/memory/synthetic/fact.md"
printf '# Memory index\n\n- [Missing](default-missing.md) — fixture\n' \
  > "$LINK_REPO/memory/synthetic/MEMORY.md"
printf 'override fact\n' > "$OVERRIDE_REPO/memory/override/fact.md"
printf '# Memory index\n\n- [Missing](override-missing.md) — fixture\n' \
  > "$OVERRIDE_REPO/memory/override/MEMORY.md"
if ln -s "$LINK_REPO/bin/ai-memory-health" "$TMP/link-two/ai-memory-health" &&
   ln -s ../../link-two/ai-memory-health "$TMP/link-one/bin/ai-memory-health" &&
   [[ -L "$TMP/link-one/bin/ai-memory-health" && -L "$TMP/link-two/ai-memory-health" ]]; then
  out="$(cd "$TMP/unrelated" && env HOME="$LINK_HOME" \
    AI_MEMORY_HEALTH_STATE="$TMP/linked-health-state" \
    "$TMP/link-one/bin/ai-memory-health" --hub-only --coverage-only \
    --ignore-sync-state 2>&1)"; rc=$?
  check "linked health derives root from its synthetic repository" \
    "[ $rc -eq 1 ] && printf '%s' \"\$out\" | grep -q 'BROKEN INDEX LINE: MEMORY.md points at missing default-missing.md'"
  out="$(cd "$TMP/unrelated" && env HOME="$LINK_HOME" \
    AI_MEMORY_HEALTH_STATE="$TMP/linked-health-override-state" \
    "$TMP/link-one/bin/ai-memory-health" --hub-only --coverage-only \
    --ignore-sync-state --repo-root "$OVERRIDE_REPO" 2>&1)"; rc=$?
  check "linked health honors explicit --repo-root override" \
    "[ $rc -eq 1 ] && printf '%s' \"\$out\" | grep -q 'BROKEN INDEX LINE: MEMORY.md points at missing override-missing.md'"
  check "explicit override result is not the default synthetic hub" \
    "! printf '%s' \"\$out\" | grep -q 'default-missing.md'"
else
  echo "SKIP: linked health fixtures require actual symlink support"
fi

# --- weekly timer (#2799) -----------------------------------------------------
# `schedule` / `unschedule` manage only the report's own timer. Linux/macOS get
# one marked user-crontab line; a stub crontab keeps the real one untouched.
if command -v schtasks.exe >/dev/null 2>&1; then
  echo "SKIP: crontab timer checks need a host without schtasks.exe"
else
  CRON="$TMP/cron-bin"; mkdir -p "$CRON" "$TMP/timer-home"
  cat > "$CRON/crontab" <<'CRON_STUB'
#!/bin/sh
# -l prints the installed crontab; any other form installs $1.
[ "$1" = -l ] && { [ -f "$CRONTAB_FILE" ] && cat "$CRONTAB_FILE"; exit 0; }
[ -n "${CRONTAB_REFUSE:-}" ] && { echo "crontab: not allowed" >&2; exit 1; }
cat "$1" > "$CRONTAB_FILE"; exit 0
CRON_STUB
  chmod +x "$CRON/crontab"
  export CRONTAB_FILE="$TMP/installed-crontab"
  timer() { PATH="$CRON:$PATH" HOME="$TMP/timer-home" env LC_ALL=C "$@"; }
  FOREIGN='17 3 * * * /home/ai/bin/keep-me.sh'
  MARKER='# ai-devops memory-health (managed by ai-memory-health schedule; unschedule removes)'
  JOB="00 09 * * 1 cd \"$ROOT\" && '$SCRIPT' --repo-root \"$ROOT\" --out \"$TMP/timer-home/.config/ai-devops/memory-health-latest.md\" >/dev/null 2>&1"
  markers() { grep -cF "$MARKER" "$CRONTAB_FILE"; }
  printf '%s\n' "$FOREIGN" > "$CRONTAB_FILE"

  out="$(timer "$SCRIPT" schedule 2>&1)"; rc=$?
  check "schedule exits 0" "[ $rc -eq 0 ]"
  check "schedule states day, time and crontab" "printf '%s' \"\$out\" | grep -q 'scheduled weekly on Monday at 09:00 in the user crontab'"
  check "schedule writes the report file path" "[ -d \"$TMP/timer-home/.config/ai-devops\" ] && printf '%s' \"\$out\" | grep -qF \"report file: $TMP/timer-home/.config/ai-devops/memory-health-latest.md\""
  check "schedule adds exactly one marked line" "[ \"\$(markers)\" -eq 1 ]"
  check "schedule keeps a foreign entry" "grep -qF \"$FOREIGN\" \"$CRONTAB_FILE\""
  check "the job runs the read-only audit with absolute paths" "[ \"\$(tail -n 1 \"$CRONTAB_FILE\")\" = \"\$JOB\" ]"

  timer "$SCRIPT" schedule >/dev/null 2>&1; rc=$?
  check "schedule is idempotent" "[ $rc -eq 0 ] && [ \"\$(markers)\" -eq 1 ]"

  out="$(timer AI_MEMORY_HEALTH_WEEKDAY=Sunday AI_MEMORY_HEALTH_WEEKLY_AT=18:05 "$SCRIPT" schedule 2>&1)"; rc=$?
  check "day and time come from the environment" \
    "[ $rc -eq 0 ] && tail -n 1 \"$CRONTAB_FILE\" | grep -q '^05 18 \\* \\* 0 ' && printf '%s' \"\$out\" | grep -q 'Sunday at 18:05'"

  before_timer="$(sha256sum < "$CRONTAB_FILE")"
  for bad_env in AI_MEMORY_HEALTH_WEEKDAY=Funday AI_MEMORY_HEALTH_WEEKDAY=1 \
                 AI_MEMORY_HEALTH_WEEKLY_AT=24:00 AI_MEMORY_HEALTH_WEEKLY_AT=09:60 \
                 AI_MEMORY_HEALTH_WEEKLY_AT=9am 'AI_MEMORY_HEALTH_WEEKLY_AT=09:00; rm -rf /'; do
    out="$(timer "$bad_env" "$SCRIPT" schedule 2>&1)"; rc=$?
    check "an invalid $bad_env is refused before the crontab" \
      "[ $rc -eq 2 ] && printf '%s' \"\$out\" | grep -q 'AI_MEMORY_HEALTH_'"
  done
  check "invalid settings leave the crontab unchanged" "[ \"\$before_timer\" = \"\$(sha256sum < \"$CRONTAB_FILE\")\" ]"

  out="$(CRONTAB_REFUSE=1 timer "$SCRIPT" schedule 2>&1)"; rc=$?
  check "a crontab refusal fails schedule truthfully" \
    "[ $rc -eq 2 ] && printf '%s' \"\$out\" | grep -q 'crontab refused the schedule of the weekly entry'"

  out="$(timer "$SCRIPT" unschedule 2>&1)"; rc=$?
  check "unschedule exits 0 and says so" "[ $rc -eq 0 ] && printf '%s' \"\$out\" | grep -q 'removed the weekly memory-health crontab entry'"
  check "unschedule removes only its own lines" "[ \"\$(markers)\" -eq 0 ] && grep -qF \"$FOREIGN\" \"$CRONTAB_FILE\""

  # Timer subcommands never audit: no report, no trend line, no memory change.
  before_timer="$(find "$TMP/home" "$TMP/timer-home" -type f -printf '%p %s %T@\n' | sort | md5sum)"
  out="$(timer AI_MEMORY_HEALTH_STATE="$TMP/timer-trend" "$SCRIPT" schedule 2>&1; timer AI_MEMORY_HEALTH_STATE="$TMP/timer-trend" "$SCRIPT" unschedule 2>&1)"
  check "timer subcommands print no audit" "! printf '%s' \"\$out\" | grep -q 'Memory health report'"
  check "timer subcommands change no memory and write no trend" \
    "[ \"\$before_timer\" = \"\$(find \"$TMP/home\" \"$TMP/timer-home\" -type f -printf '%p %s %T@\\n' | sort | md5sum)\" ] && [ ! -e \"$TMP/timer-trend\" ]"
fi

# --- Windows route: schedule delegates to the existing task script -------------
# A stub schtasks.exe selects the Windows route and a stub pwsh records the call,
# so a real Scheduled Task is never touched on any host.
WINBIN="$TMP/win-bin"; mkdir -p "$WINBIN"
printf '#!/bin/sh\nexit 0\n' > "$WINBIN/schtasks.exe"
cat > "$WINBIN/pwsh" <<'PWSH_STUB'
#!/bin/sh
printf '%s\n' "$@" > "$PWSH_ARGS_FILE"
PWSH_STUB
chmod +x "$WINBIN/schtasks.exe" "$WINBIN/pwsh"
export PWSH_ARGS_FILE="$TMP/pwsh-args"
win() { PATH="$WINBIN:$PATH" HOME="$TMP/timer-home" "$SCRIPT" "$@"; }
# Argument lines: 1-4 the pwsh flags, 5 the task script (platform-shaped:
# cygpath on Git Bash), then the day and time.
win_args_shape() { printf '%s' "$(head -n 4 "$PWSH_ARGS_FILE" | tr '\n' ' ')"; }

win schedule >/dev/null 2>&1; rc=$?
check "Windows schedule delegates to the task script" \
  "[ $rc -eq 0 ] && [ \"\$(win_args_shape)\" = '-NoProfile -ExecutionPolicy Bypass -File ' ] && sed -n '5p' \"$PWSH_ARGS_FILE\" | grep -q 'install-memory-health-task\.ps1\$'"
check "Windows schedule passes the default day and time" "[ \"\$(tail -n +6 \"$PWSH_ARGS_FILE\" | tr '\n' ' ')\" = '-DayOfWeek Monday -At 09:00 ' ]"
check "Windows schedule stays out of the crontab" "[ ! -e \"\${CRONTAB_FILE:-}\" ] || ! grep -qF 'ai-memory-health' \"\$CRONTAB_FILE\""

AI_MEMORY_HEALTH_WEEKDAY=Friday AI_MEMORY_HEALTH_WEEKLY_AT=07:41 win schedule >/dev/null 2>&1; rc=$?
check "Windows schedule passes environment day and time" \
  "[ $rc -eq 0 ] && [ \"\$(tail -n +6 \"$PWSH_ARGS_FILE\" | tr '\n' ' ')\" = '-DayOfWeek Friday -At 07:41 ' ]"

win unschedule >/dev/null 2>&1; rc=$?
check "Windows unschedule asks the task script to remove the task" \
  "[ $rc -eq 0 ] && [ \"\$(tail -n +6 \"$PWSH_ARGS_FILE\" | tr '\n' ' ')\" = '-Remove ' ]"

# "No pwsh" must be built, never assumed: CI images and Windows hosts ship a real
# pwsh, and reaching it would run the real task script on that machine. This PATH
# holds only the stub schtasks.exe and the three core utilities the script needs
# before it looks for pwsh.
NOPWSH="$TMP/win-bin-nopwsh"; mkdir -p "$NOPWSH"
printf '#!/bin/sh\nexit 0\n' > "$NOPWSH/schtasks.exe"; chmod +x "$NOPWSH/schtasks.exe"
for util in dirname basename readlink; do
  printf '#!/bin/sh\nexec "%s" "$@"\n' "$(command -v "$util")" > "$NOPWSH/$util"; chmod +x "$NOPWSH/$util"
done
# bash is addressed by path on purpose: with PATH replaced, "bash" is not found.
check "the no-pwsh test PATH really has no pwsh" "! PATH=\"$NOPWSH\" \"\$BASH\" -c 'command -v pwsh'"
out="$(PATH="$NOPWSH" "$BASH" "$SCRIPT" schedule 2>&1)"; rc=$?
check "Windows schedule without pwsh 7 fails with the reason" \
  "[ $rc -eq 2 ] && printf '%s' \"\$out\" | grep -q 'PowerShell 7'"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
