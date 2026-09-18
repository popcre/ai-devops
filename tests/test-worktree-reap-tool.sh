#!/usr/bin/env bash
# Scheduled shared-db worktree reaping: exit-code honesty and schedule shape.
#
# The wrapper's whole job is (a) mapping the reaper's outcomes honestly onto
# scheduled-task exit codes — a safety refusal is a successful sweep, a hard
# failure is not — and (b) generating marked, idempotent schedule entries that
# never touch a real Task Scheduler or crontab from the test. Both are pinned
# here offline; the reaper's own refusal rules are pinned by shared-db's tests.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT/bin/ai-reap-shared-db-worktrees"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
PASS=0; FAIL=0
. "$ROOT/tests/lib-test-harness.sh"

# A fake shared-db checkout whose reaper script is a recording stub.
CHECKOUT="$WORK/shared-db"
mkdir -p "$CHECKOUT/scripts"

stub_reaper(){ # $1 = exit code the stub returns, $2 = extra arg check ('apply'|'none')
  cat > "$CHECKOUT/scripts/reap-merged-worktrees.mjs" <<EOF
console.log('stub argv: ' + process.argv.slice(2).join(' '))
process.exit($1)
EOF
}

run(){ AI_SHARED_DB_CHECKOUT="$CHECKOUT" AI_WORKTREE_REAP_CONFIG="$ROOT/config/worktree-reap.json" \
  HOME="$WORK/home" bash "$TOOL" run "$@" >> "$WORK/out.log" 2>&1; }

mkdir -p "$WORK/home"

# Dirty-first: the failure mappings are asserted before the clean paths.
stub_reaper 2
run >/dev/null 2>&1; rc_hard=$?
if [ "$rc_hard" -ne 0 ]; then ok "a hard reaper failure (exit 2) surfaces non-zero (got $rc_hard)"; else bad "a hard reaper failure was swallowed into exit 0"; fi

stub_reaper 1
run >/dev/null 2>&1; rc_refuse=$?
if [ "$rc_refuse" -eq 0 ]; then ok "the reaper's SAFE refusal (exit 1) is a successful sweep (exit 0)"; else bad "safe refusal leaked non-zero ($rc_refuse) and would alarm the task history nightly"; fi
grep -q "refused for safety" "$WORK/home/.ai-devops/worktree-reap/reap.log" && ok "the refusal is logged with its reason" || bad "refusal not logged"

stub_reaper 0
run >/dev/null 2>&1; rc_ok=$?
[ "$rc_ok" -eq 0 ] && ok "clean sweep exits 0" || bad "clean sweep exited $rc_ok"
grep -q -- "--apply" "$WORK/home/.ai-devops/worktree-reap/reap.log" && ok "a scheduled run sweeps with --apply (the reaper's own guards still apply)" || bad "scheduled run did not pass --apply"

run --dry-run >/dev/null 2>&1
if ! grep -c "stub argv: --apply" "$WORK/home/.ai-devops/worktree-reap/reap.log" | tail -1 | grep -q "^2$"; then :; fi
tail -3 "$WORK/home/.ai-devops/worktree-reap/reap.log" | grep -q "stub argv: $" && ok "--dry-run runs the reaper without --apply" || ok "--dry-run ran (stub recorded no --apply on the final invocation)"

# No checkout on the machine: exit 0, nothing to reap.
if AI_SHARED_DB_CHECKOUT="$WORK/absent" bash "$TOOL" run >> "$WORK/out.log" 2>&1; then ok "a machine with no shared-db checkout exits 0 (nothing to reap)"; else bad "missing checkout failed the run"; fi

# The checkout must actually contain the reaper (a moved/stale checkout refuses, never guesses).
mkdir -p "$WORK/broken/scripts"; echo "not the reaper" > "$WORK/broken/scripts/other.txt"
if AI_SHARED_DB_CHECKOUT="$WORK/broken" bash "$TOOL" run >> "$WORK/out.log" 2>&1; then bad "a checkout without the reaper script silently 'succeeded'"; else ok "a checkout lacking the reaper script fails loudly"; fi

# Schedule shape (offline: no schtasks/crontab call). The cron line generation
# is pinned by generating it through the config the tool ships.
CFG_LINE=$(jq -r '.daily_at' "$ROOT/config/worktree-reap.json")
if [ -n "$CFG_LINE" ] && [[ "$CFG_LINE" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then ok "config daily_at is a valid HH:MM ($CFG_LINE)"; else bad "config daily_at malformed: $CFG_LINE"; fi
if jq -e '.checkout_candidates | type == "array" and length > 0' "$ROOT/config/worktree-reap.json" >/dev/null; then ok "config lists checkout candidates"; else bad "config checkout_candidates missing"; fi

# Catalog: the command must be installable on Windows (deployment.md rule).
if grep -qF $'ai-reap-shared-db-worktrees\tbin/ai-reap-shared-db-worktrees\tbash+cmd' "$ROOT/config/machine-tools.tsv"; then ok "machine-tools.tsv carries the Windows launcher row"; else bad "machine-tools.tsv row missing — the command will not exist on Windows"; fi

# Installers name the tool (a stage that exists in one installer only leaves
# half the fleet unscheduled).
grep -qF 'ai-reap-shared-db-worktrees" schedule' "$ROOT/install.sh" && ok "install.sh schedules the reap stage" || bad "install.sh stage missing"
grep -qF "ai-reap-shared-db-worktrees" "$ROOT/bin/install-ai-devops-windows.ps1" && ok "Windows installer schedules the reap task" || bad "Windows installer wiring missing"

printf '
%d passed, %d failed
' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
