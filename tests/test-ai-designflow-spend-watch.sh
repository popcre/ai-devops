#!/usr/bin/env bash
# Offline tests for bin/ai-designflow-spend-watch with a stub gh.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT/bin/ai-designflow-spend-watch"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ pass=$((pass+1)); printf 'PASS: %s\n' "$1"; }
bad(){ fail=$((fail+1)); printf 'FAIL: %s\n' "$1" >&2; }

# Stub gh: answers from files in $STUB, records every call in $STUB/calls.
cat > "$TMP/gh" <<'E'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB/calls"
case "$1 $2" in
  "api repos/"*)
    r="${2#repos/popcre/designflow-}"; r="${r%%/*}"
    [ -f "$STUB/fail-queue" ] && exit 1
    if [ -f "$STUB/queue-$r.json" ]; then cat "$STUB/queue-$r.json"; else echo '{"workflow_runs":[]}'; fi ;;
  "api organizations/"*) [ -f "$STUB/fail-billing" ] && exit 1; cat "$STUB/billing.json" ;;
  "workflow run") [ -f "$STUB/fail-dispatch" ] && exit 1; exit 0 ;;
  "issue list") cat "$STUB/open-issue" 2>/dev/null ;;
  "issue create"|"issue edit"|"issue close") exit 0 ;;
  *) echo "stub: unexpected $*" >&2; exit 9 ;;
esac
E
chmod +x "$TMP/gh"

NOW=$(date -u -d '2026-11-26T12:00:00Z' +%s)
run(){ # run <case-name> [args...]; sets OUT RC
  export STUB="$TMP/$1"; mkdir -p "$STUB"; : > "$STUB/calls"
  [ -f "$STUB/billing.json" ] || echo '{"usageItems":[]}' > "$STUB/billing.json"
  shift
  OUT="$(AI_DESIGNFLOW_WATCH_GH="$TMP/gh" AI_DESIGNFLOW_WATCH_NOW="$NOW" AI_DESIGNFLOW_WATCH_HOME="$STUB/home" "$TOOL" "$@" 2>&1)"; RC=$?
}
queue(){ # queue <case> <repo> <minutes-old> [id]
  mkdir -p "$TMP/$1"
  printf '{"workflow_runs":[{"id":%s,"head_branch":"develop","created_at":"%s"}]}\n' "${4:-101}" "$(date -u -d "@$((NOW - $3*60))" +%Y-%m-%dT%H:%M:%SZ)" > "$TMP/$1/queue-$2.json"
}
billing(){ mkdir -p "$TMP/$1"; printf '{"usageItems":[{"product":"actions","repositoryName":"designflow-frontend","netAmount":%s},{"product":"actions","repositoryName":"shared-db","netAmount":50}]}\n' "$2" > "$TMP/$1/billing.json"; }

# 1. clean: nothing queued, low spend, no issue written
billing clean 0.40; run clean
[ "$RC" -eq 0 ] && ! grep -q "issue create\|workflow run" "$TMP/clean/calls" && ok "clean check exits 0 and writes nothing" || bad "clean check (rc=$RC): $OUT"

# 2. young queued run is left alone
queue young frontend 10; run young
[ "$RC" -eq 0 ] && ! grep -q "workflow run" "$TMP/young/calls" && ok "a run queued under the limit is left alone" || bad "young queue (rc=$RC): $OUT"

# 3. stuck run: hosted fallback started once, issue opened, second tick does not re-dispatch
queue stuck tracking 45; run stuck
grep -q "workflow run designflow-checks.yml -R popcre/designflow-tracking --ref develop -f hosted=true" "$TMP/stuck/calls" && [ "$RC" -eq 1 ] && grep -q "issue create" "$TMP/stuck/calls" \
  && ok "a stuck run starts the hosted fallback and raises the alarm" || bad "stuck dispatch (rc=$RC): $OUT"
run stuck
[ "$(grep -c "workflow run" "$TMP/stuck/calls")" -eq 0 ] && [ "$RC" -eq 1 ] && ok "the same stuck run is never dispatched twice" || bad "re-dispatch guard (rc=$RC): $OUT"

# 4. paid minutes over the limit raise the alarm; other repositories do not count
billing spend 3.20; run spend
[ "$RC" -eq 1 ] && grep -q '\$3.2' <<<"$OUT" && ok "DesignFlow spend over the limit raises the alarm" || bad "spend alarm (rc=$RC): $OUT"
billing other 0.50; run other
[ "$RC" -eq 0 ] && ok "spend in public repositories is ignored" || bad "non-DesignFlow spend (rc=$RC): $OUT"

# 5. clean run closes an open alarm issue
billing closer 0; mkdir -p "$TMP/closer"; echo 77 > "$TMP/closer/open-issue"; run closer
grep -q "issue close 77" "$TMP/closer/calls" && [ "$RC" -eq 0 ] && ok "a clean check closes the open alarm" || bad "close (rc=$RC): $OUT"

# 6. read failures are reported, never treated as clean
mkdir -p "$TMP/readfail"; touch "$TMP/readfail/fail-billing"; run readfail
[ "$RC" -eq 2 ] && grep -q "could not read the billing" <<<"$OUT" && ok "an unreadable bill is an error, not a pass" || bad "read failure (rc=$RC): $OUT"

# 7. dry run changes nothing
queue dry bff 60; run dry --dry-run
! grep -q "workflow run\|issue " "$TMP/dry/calls" && [ "$RC" -eq 1 ] && ok "dry run reports without dispatching or writing" || bad "dry run (rc=$RC): $OUT"

# 8. failed dispatch is reported and retried next time
queue dfail item-master 40; touch "$TMP/dfail/fail-dispatch"; run dfail
grep -q "FAILED" <<<"$OUT" && [ ! -s "$TMP/dfail/home/dispatched-runs" ] && ok "a failed fallback start is reported and left for retry" || bad "dispatch failure (rc=$RC): $OUT"

printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
