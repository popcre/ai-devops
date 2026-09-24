#!/usr/bin/env bash
# Tests for bin/ai-gh (machine-wide GitHub throttle) and bin/ai-gh-wait.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; GH="$ROOT/bin/ai-gh"; WAIT="$ROOT/bin/ai-gh-wait"
PASS=0; FAIL=0; ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAKE="$TMP/fake-gh"
cat > "$FAKE" <<'EOF'
#!/usr/bin/env bash
echo "start $(date +%s%N) $*" >> "$FAKE_LOG"
case "${FAKE_MODE:-ok}" in
  ok) sleep "${FAKE_SLEEP:-0}"; echo "out:$*" ;;
  secondary) echo 'HTTP 403: You have exceeded a secondary rate limit. Please wait a few minutes before you try again.' >&2; echo 'Retry-After: 900' >&2; echo "end $(date +%s%N)" >> "$FAKE_LOG"; exit 1 ;;
  secondary-short) echo 'gh: HTTP 429: Too Many Requests (retry-after: 60)' >&2; exit 1 ;;
  notfound) echo 'HTTP 404: Not Found' >&2; exit 1 ;;
  spaced-failure) if [ "$1 $2" = 'api rate_limit' ] || [ "$1 $2" = 'api --include' ]; then
    printf 'core\t4000\t5000\t%s\ngraphql\t4000\t5000\t%s\n' $(( $(date +%s) + 3000 )) $(( $(date +%s) + 3000 ));
    else echo 'HTTP 404: Not Found' >&2; exit 1; fi ;;
  quota) if [ "$1 $2" = 'api rate_limit' ]; then
    filter='.'; previous=''
    for arg in "$@"; do [ "$previous" != --jq ] || filter="$arg"; previous="$arg"; done
    {
    [ -z "${FAKE_EXTRA_RESOURCE:-}" ] || printf '%s\t%s\t100\t%s\n' "$FAKE_EXTRA_RESOURCE" "${FAKE_EXTRA_REMAINING:-0}" $(( $(date +%s) + 3600 ));
    printf 'core\t%s\t5000\t%s\ngraphql\t%s\t5000\t%s\nsearch\t%s\t30\t%s\ncode_search\t%s\t10\t%s\n' "$FAKE_REMAINING" $(( $(date +%s) + 1800 )) "${FAKE_GRAPHQL_REMAINING:-$FAKE_REMAINING}" $(( $(date +%s) + 2400 )) "${FAKE_SEARCH_REMAINING:-30}" $(( $(date +%s) + 60 )) "${FAKE_CODE_SEARCH_REMAINING:-10}" $(( $(date +%s) + 60 ));
    } | jq -Rn '[inputs | split("\t") | {key:.[0],value:{remaining:(.[1]|tonumber? // .),limit:(.[2]|tonumber),reset:(.[3]|tonumber)}}] | {resources:from_entries}' | jq -r "$filter"
    else echo "out:$*"; fi ;;
  primary) if [ "$1 $2" = 'api --include' ]; then
    [ -z "${FAKE_EXTRA_RESOURCE:-}" ] || printf '%s\t0\t100\t%s\n' "$FAKE_EXTRA_RESOURCE" $(( $(date +%s) + 3600 ));
    printf 'HTTP/2.0 200 OK\nX-Ratelimit-Remaining: 0\nX-Ratelimit-Reset: %s\nX-Github-Request-Id: F95F:1E2E31\n\ncore\t0\t5000\t%s\ngraphql\t0\t5000\t%s\n' $(( $(date +%s) + 9000 )) $(( $(date +%s) + 3000 )) $(( $(date +%s) + 2000 ));
    elif [ "$1 $2" = 'api rate_limit' ]; then printf 'core\t4000\t5000\t%s\ngraphql\t4000\t5000\t%s\n' $(( $(date +%s) + 3000 )) $(( $(date +%s) + 2000 )); else echo 'gh: API rate limit exceeded for user ID 55610577. (HTTP 403) token ghp_abcdefSECRET123' >&2; exit 1; fi ;;
  missing-resource) if [ "$1 $2" = 'api rate_limit' ]; then printf 'core\t4999\t5000\t%s\n' $(( $(date +%s) + 9000 ));
    elif [ "$1 $2" = 'api --include' ]; then printf 'HTTP/2 200\nX-Ratelimit-Reset: %s\n\ncore\t4999\t5000\t%s\n' $(( $(date +%s) + 9000 )) $(( $(date +%s) + 9000 ));
    else echo 'gh: API rate limit already exceeded for user ID 55610577. (HTTP 403)' >&2; exit 1; fi ;;
  counter) n=$(( $(cat "$FAKE_COUNT" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$FAKE_COUNT"; [ "$n" -ge 2 ] && echo '{"status":"completed"}' || echo '{"status":"in_progress"}' ;;
esac
echo "end $(date +%s%N)" >> "$FAKE_LOG"
EOF
chmod +x "$FAKE"
export AI_GH_REAL_GH="$FAKE" FAKE_LOG="$TMP/log" AI_GH_STATE_DIR="$TMP/state" AI_GH_MIN_SPACING_SECONDS=0 FAKE_COUNT="$TMP/count" AI_GH_QUOTA_PROBE_SECONDS=off

check 'passes arguments and output through' "[ \"\$('$GH' pr view 5)\" = 'out:pr view 5' ]"
check 'gh run watch is refused without calling GitHub' "! '$GH' run watch 12 && ! grep -q 'run watch' '$FAKE_LOG'"
"$GH" run watch 12 >/dev/null 2>&1; check 'run watch exits 2' "[ $? -eq 2 ]"
"$GH" pr checks 3 --watch >/dev/null 2>&1; check '--watch flag exits 2' "[ $? -eq 2 ]"
FAKE_MODE=notfound "$GH" api x >/dev/null 2>&1; rc=$?
check 'ordinary failure keeps gh status and records no back-off' "[ $rc -eq 1 ] && [ ! -s '$TMP/state/backoff_until' ]"

# Spacing across calls.
: > "$FAKE_LOG"
AI_GH_MIN_SPACING_SECONDS=2 "$GH" a >/dev/null; AI_GH_MIN_SPACING_SECONDS=2 "$GH" b >/dev/null
s1=$(awk '/^start/{print $2}' "$FAKE_LOG" | sed -n 1p); s2=$(awk '/^start/{print $2}' "$FAKE_LOG" | sed -n 2p)
check 'calls are spaced by the minimum interval' "[ $(( (s2 - s1) / 1000000 )) -ge 1000 ]"

# Serialization across concurrent processes: call STARTS are spaced, and a slow
# call does not hold the lock while it runs.
: > "$FAKE_LOG"
for i in 1 2 3; do AI_GH_MIN_SPACING_SECONDS=1 FAKE_SLEEP=3 "$GH" p$i >/dev/null & done; wait
check 'concurrent processes space their GitHub call starts' "[ \$(grep -c '^start' '$FAKE_LOG') -eq 3 ] && awk '/^start/{print \$2}' '$FAKE_LOG' | sort -n | awk '{t[++n]=\$1} END{for(i=2;i<=n;i++) if((t[i]-t[i-1])/1000000 < 900) exit 1}'"
check 'lock is released after calls' "[ ! -d '$TMP/state/lock.d' ]"
: > "$FAKE_LOG"
# Prove ordering, not speed: the quick call must START before the slow call
# ENDS. A wall-clock ceiling failed on loaded machines even before P1 (#775).
FAKE_SLEEP=20 "$GH" slow >/dev/null & sp=$!
for _ in $(seq 1 300); do grep -q '^start .* slow$' "$FAKE_LOG" && break; sleep 0.2; done
timeout 60 "$GH" quick >/dev/null; qrc=$?; wait "$sp"
check 'a slow call does not block the next caller' "[ $qrc -eq 0 ] && awk '/^start .* slow$/{if(!s)s=NR} /^start .* quick$/{q=NR} /^end/{if(!e)e=NR} END{exit !(s && q && e && s<q && q<e)}' '$FAKE_LOG'"

# Secondary rate limit: back-off uses Retry-After, no retry, and blocks later calls.
: > "$FAKE_LOG"
before=$(date +%s)
FAKE_MODE=secondary "$GH" api repos/x >/dev/null 2>"$TMP/err"; rc=$?
check 'secondary limit exits 75' "[ $rc -eq 75 ]"
check 'refused call is not retried' "[ \$(grep -c '^start' '$FAKE_LOG') -eq 1 ]"
check 'back-off honours Retry-After 900' "[ \$(cat '$TMP/state/backoff_until') -ge $((before + 900)) ]"
check 'refusal is logged' "grep -q 'retry_after=900' '$TMP/state/refusals.log'"
AI_GH_NO_WAIT=1 "$GH" pr view 1 >/dev/null 2>&1; rc=$?
check 'during back-off NO_WAIT exits 75 without calling GitHub' "[ $rc -eq 75 ] && [ \$(grep -c '^start' '$FAKE_LOG') -eq 1 ]"
rm -f "$TMP/state/backoff_until"
before=$(date +%s)
FAKE_MODE=secondary-short "$GH" api y >/dev/null 2>&1; rc=$?
check 'short Retry-After is raised to the 600s floor' "[ $rc -eq 75 ] && [ \$(cat '$TMP/state/backoff_until') -ge $((before + 600)) ]"
rm -f "$TMP/state/backoff_until"

# Hourly (primary) budget.
# Follow-up probes must share the same start-spacing lock as real requests.
: > "$FAKE_LOG"
for i in 1 2; do FAKE_MODE=spaced-failure AI_GH_QUOTA_PROBE_SECONDS=300 AI_GH_MIN_SPACING_SECONDS=2 "$GH" api repos/o/r/issues >/dev/null 2>&1 & done
wait
check 'concurrent ordinary failures serialize and space every probe and request' "[ \$(grep -c 'api --include rate_limit' '$FAKE_LOG') -eq 2 ] && awk '/^start/{print \$2}' '$FAKE_LOG' | sort -n | awk '{t[++n]=\$1} END{for(i=2;i<=n;i++) if((t[i]-t[i-1])/1000000 < 1900) exit 1}'"
: > "$FAKE_LOG"
FAKE_MODE=primary AI_GH_QUOTA_PROBE_SECONDS=0 AI_GH_MIN_SPACING_SECONDS=2 "$GH" api repos/o/r/issues >/dev/null 2>&1; rc=$?
check 'primary refusal snapshot also respects minimum start spacing' "[ $rc -eq 75 ] && [ \$(grep -c 'api --include rate_limit' '$FAKE_LOG') -eq 1 ] && awk '/^start/{print \$2}' '$FAKE_LOG' | sort -n | awk '{t[++n]=\$1} END{for(i=2;i<=n;i++) if((t[i]-t[i-1])/1000000 < 1900) exit 1}'"
rm -f "$TMP/state/backoff_until"
rm -f "$TMP/state/quota"
FAKE_MODE=quota FAKE_REMAINING=3000 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" pr view 2 > "$TMP/qout" 2>/dev/null; rc=$?
check 'mixed CLI cost is unknown and its resource snapshots are invalidated' "[ $rc -eq 0 ] && grep -q 'out:pr view 2' '$TMP/qout' && grep -q '^0 3000 5000 ' '$TMP/state/quota' && grep -q '^0 3000 5000 ' '$TMP/state/quota.graphql'"
check 'telemetry observes named server buckets without changing admission' "jq -e '.buckets.core.remaining == 3000 and .buckets.graphql.remaining == 3000 and .buckets.search.remaining == 30 and .principal == \"unknown\"' '$TMP/state/quota-observation.json'"
check 'quota observations retain bounded history without another request' "jq -se 'length >= 1 and .[-1].buckets.graphql.remaining == 3000' '$TMP/state/quota-measurements/'*.jsonl"
rm -f "$TMP/state/quota"; : > "$FAKE_LOG"
FAKE_MODE=quota FAKE_REMAINING=900 AI_GH_QUOTA_PROBE_SECONDS=300 AI_GH_NO_WAIT=1 "$GH" pr view 3 >/dev/null 2>&1; rc=$?
check 'budget below 20% pauses machine-wide without making the call' "[ $rc -eq 75 ] && ! grep -q 'pr view 3' '$FAKE_LOG' && [ \$(cat '$TMP/state/backoff_until') -gt \$(date +%s) ] && grep -q 'budget-pause remaining=900/5000' '$TMP/state/refusals.log'"
rm -f "$TMP/state/backoff_until" "$TMP/state/quota"
before=$(date +%s)
FAKE_MODE=primary AI_GH_QUOTA_PROBE_SECONDS=0 "$GH" pr list >/dev/null 2>&1; rc=$?
check 'primary limit refusal backs off until the window resets' "[ $rc -eq 75 ] && [ \$(cat '$TMP/state/backoff_until') -ge $((before + 2900)) ] && grep -q 'kind=primary' '$TMP/state/refusals.log'"
check 'refusal log keeps the exact refusal text' "grep -q 'API rate limit exceeded for user ID 55610577' '$TMP/state/refusals.log'"
check 'failure log records status, headers and body' "grep -q 'status: HTTP 403' '$TMP/state/failures.log' && grep -qi 'x-ratelimit-remaining: 0' '$TMP/state/failures.log' && grep -q 'X-Github-Request-Id: F95F:1E2E31' '$TMP/state/failures.log'"
check 'failure and refusal logs redact credentials' "! grep -q 'ghp_abcdef' '$TMP/state/failures.log' '$TMP/state/refusals.log' && grep -q REDACTED '$TMP/state/failures.log'"
rm -f "$TMP/state/backoff_until"
FAKE_MODE=notfound AI_GH_QUOTA_PROBE_SECONDS=off "$GH" api nope >/dev/null 2>&1
check 'ordinary failures are logged too' "grep -q 'args=api nope' '$TMP/state/failures.log' && grep -q 'HTTP 404: Not Found' '$TMP/state/failures.log'"
rm -f "$TMP/state/backoff_until" "$TMP/state/quota"

# Resource classification and accounting: no real credential or API is used.
fresh_quota(){ rm -f "$TMP/state/quota" "$TMP/state"/quota.* "$TMP/state/quota-resources" "$TMP/state/backoff_until"; : > "$FAKE_LOG"; }
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_GRAPHQL_REMAINING=0 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql -f query=privatequery >/dev/null 2>"$TMP/resource-err"; rc=$?
check 'healthy REST cannot conceal exhausted GraphQL before a direct query' "[ $rc -eq 75 ] && ! grep -q 'api graphql' '$FAKE_LOG' && grep -q 'resource=graphql' '$TMP/state/refusals.log'"
for verb in pr issue; do
  fresh_quota
  FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_GRAPHQL_REMAINING=0 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" "$verb" list >/dev/null 2>&1; rc=$?
  check "indirect $verb command checks GraphQL as well as REST" "[ $rc -eq 75 ] && ! grep -q '$verb list' '$FAKE_LOG'"
done
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_GRAPHQL_REMAINING=0 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1; rc=$?
check 'single REST call uses core and reserves one request' "[ $rc -eq 0 ] && grep -q ' 3999 5000 ' '$TMP/state/quota'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=0 FAKE_GRAPHQL_REMAINING=4000 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api -X POST /graphql -F query=secretquery >/dev/null 2>&1; rc=$?
check 'direct GraphQL selects its own bucket even with leading options' "[ $rc -eq 0 ] && grep -q '^0 4000 5000 ' '$TMP/state/quota.graphql'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api --paginate repos/o/r/issues >/dev/null 2>&1; rc=$?
check 'pagination invalidates the snapshot instead of inventing a one-request cost' "[ $rc -eq 0 ] && grep -q '^0 4000 5000 ' '$TMP/state/quota'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api rate_limit >/dev/null 2>&1; rc=$?
check 'rate_limit does not decrement the core request budget' "[ $rc -eq 0 ] && grep -q ' 4000 5000 ' '$TMP/state/quota'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_SEARCH_REMAINING=0 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api search/issues >/dev/null 2>&1; rc=$?
check 'REST search uses its separate resource rather than healthy core' "[ $rc -eq 75 ] && ! grep -q 'api search/issues' '$FAKE_LOG'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_CODE_SEARCH_REMAINING=0 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api search/code >/dev/null 2>&1; rc=$?
check 'code search uses its separate resource' "[ $rc -eq 75 ] && ! grep -q 'api search/code' '$FAKE_LOG'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_GRAPHQL_REMAINING=0 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api --unknown-option graphql >/dev/null 2>&1; rc=$?
check 'unknown API options retain conservative resource selection' "[ $rc -eq 75 ] && ! grep -q -- '--unknown-option' '$FAKE_LOG'"
fresh_quota
before=$(date +%s)
FAKE_MODE=primary AI_GH_QUOTA_PROBE_SECONDS=0 "$GH" api graphql >/dev/null 2>&1; rc=$?
check 'GraphQL refusal uses GraphQL reset, never the unrelated core response header' "[ $rc -eq 75 ] && [ \$(cat '$TMP/state/backoff_until') -ge $((before + 1900)) ] && [ \$(cat '$TMP/state/backoff_until') -lt $((before + 2500)) ]"
fresh_quota
before=$(date +%s)
FAKE_MODE=missing-resource AI_GH_QUOTA_PROBE_SECONDS=0 "$GH" api graphql -f query=privatevalue >/dev/null 2>"$TMP/unknown-quota"; rc=$?
check 'missing GraphQL evidence is visible and never borrows core reset' "[ $rc -eq 75 ] && grep -q 'graphql quota unknown' '$TMP/unknown-quota' && [ \$(cat '$TMP/state/backoff_until') -lt $((before + 1000)) ]"
check 'new resource diagnostics do not expose query values' "! grep -q privatevalue '$TMP/state/failures.log' '$TMP/state/refusals.log'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api --hostname github.example repos/o/r >/dev/null 2>&1; rc=$?
check 'explicit host is probed and its snapshots cannot leak to default-host cache' "[ $rc -eq 0 ] && grep -q 'rate_limit --hostname github.example' '$FAKE_LOG' && grep -q '^0 ' '$TMP/state/quota' && grep -q '^0 ' '$TMP/state/quota.graphql'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=0 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api --hostname github.example repos/o/r >/dev/null 2>&1; rc=$?
check 'an explicit-host budget refusal also leaves every snapshot invalidated' "[ $rc -eq 75 ] && grep -q '^0 ' '$TMP/state/quota' && grep -q '^0 ' '$TMP/state/quota.graphql'"
fresh_quota
printf '%s 0 5000 %s\n' "$(date +%s)" "$(( $(date +%s) - 10 ))" > "$TMP/state/quota"
FAKE_MODE=quota FAKE_REMAINING=4000 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1; rc=$?
check 'a passed resource reset refreshes even a recently timestamped cache' "[ $rc -eq 0 ] && grep -q 'api rate_limit' '$FAKE_LOG'"
fresh_quota

# Every live sibling resource and a future bucket must be ingested. Unknown
# endpoints stay conservative without making a hardcoded resource inventory.
for spec in 'audit_log orgs/o/audit-log' 'scim scim/v2/organizations/o/Users' \
  'dependency_snapshots repos/o/r/dependency-graph/snapshots' \
  'dependency_sbom repos/o/r/dependency-graph/sbom' \
  'actions_runner_registration repos/o/r/actions/runners/registration-token' \
  'audit_log_streaming enterprises/e/audit-log/streams' \
  'copilot_usage_records enterprises/e/copilot/metrics' \
  'enterprise_token_inventory enterprises/e/personal-access-tokens' \
  'integration_manifest app' 'source_import repos/o/r/import' \
  'code_scanning_autofix repos/o/r/code-scanning/alerts/1/autofix' \
  'future_quota future/endpoint'; do
  read -r resource endpoint <<< "$spec"
  fresh_quota
  FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_EXTRA_RESOURCE="$resource" AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api "$endpoint" >/dev/null 2>&1; rc=$?
  check "$resource exhaustion blocks its REST request before dispatch" "[ $rc -eq 75 ] && ! grep -q 'api $endpoint' '$FAKE_LOG' && grep -q 'resource=$resource' '$TMP/state/refusals.log'"
done
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_EXTRA_RESOURCE=future_quota AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r/issues >/dev/null 2>&1; rc=$?
check 'known core endpoint is not stopped by an unrelated REST quota' "[ $rc -eq 0 ] && grep -q ' 3999 5000 ' '$TMP/state/quota'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_EXTRA_RESOURCE=future_quota FAKE_EXTRA_REMAINING=100 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api future/endpoint >/dev/null 2>&1; rc=$?
check 'unknown REST cost invalidates newly discovered resource snapshots' "[ $rc -eq 0 ] && grep -q '^0 100 100 ' '$TMP/state/quota.future_quota'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_EXTRA_RESOURCE=future_quota FAKE_EXTRA_REMAINING=malformed AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api future/endpoint >/dev/null 2>"$TMP/malformed"; rc=$?
check 'malformed new resource is unknown and visibly reported' "[ $rc -eq 0 ] && grep -q 'future_quota quota unknown' '$TMP/malformed'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_EXTRA_RESOURCE=future_quota AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" extension run custom >/dev/null 2>&1; rc=$?
check 'unknown CLI command considers the full discovered resource inventory' "[ $rc -eq 75 ] && ! grep -q 'extension run custom' '$FAKE_LOG'"
fresh_quota
before=$(date +%s)
FAKE_MODE=primary FAKE_EXTRA_RESOURCE=future_quota AI_GH_QUOTA_PROBE_SECONDS=0 "$GH" api future/endpoint >/dev/null 2>&1; rc=$?
check 'new resource discovered only after refusal supplies its own reset' "[ $rc -eq 75 ] && [ \$(cat '$TMP/state/backoff_until') -ge $((before + 3500)) ] && [ \$(cat '$TMP/state/backoff_until') -lt $((before + 4000)) ] && grep -q 'exhausted-resource=future_quota' '$TMP/state/refusals.log'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_EXTRA_RESOURCE=future_quota FAKE_EXTRA_REMAINING=100 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api --hostname github.example repos/o/r >/dev/null 2>&1; rc=$?
check 'explicit host invalidates new resource caches as well as known ones' "[ $rc -eq 0 ] && grep -q '^0 100 100 ' '$TMP/state/quota.future_quota'"
fresh_quota

# Stale lock is recovered by age; a young lock with a live-looking owner is not stolen.
mkdir -p "$TMP/state/lock.d"; echo "999999 $(( $(date +%s) - 400 )) tok" > "$TMP/state/lock.d/owner"
check 'abandoned lock older than the stale limit is recovered' "timeout 20 '$GH' z"
mkdir -p "$TMP/state/lock.d"; : > "$TMP/state/lock.d/owner"; touch -d '@'$(( $(date +%s) - 120 )) "$TMP/state/lock.d"
check 'lock with an empty owner record is recovered' "timeout 20 '$GH' z"
mkdir -p "$TMP/state/lock.d"; echo "999999 $(date +%s) other" > "$TMP/state/lock.d/owner"
AI_GH_NO_WAIT=1 AI_GH_NO_WAIT_LOCK_SECONDS=2 "$GH" z >/dev/null 2>&1; rc=$?
check 'a fresh lock is not stolen even if its pid looks dead; NO_WAIT gives up with 75' "[ $rc -eq 75 ] && grep -q other '$TMP/state/lock.d/owner'"
rm -rf "$TMP/state/lock.d"
# Behavioural: a holder's release must not remove a lock that now belongs to another owner.
# Real script: hold its post-acquisition back-off read at a FIFO, then replace
# the owner record. A spacing timer can expire before a loaded Windows runner
# observes the lock, making the old test overwrite an already-released lock.
rm -f "$TMP/state/backoff_until"
mkfifo "$TMP/state/backoff_until" || { bad 'release test created its acquisition barrier'; exit 1; }
AI_GH_MIN_SPACING_SECONDS=0 "$GH" relcheck >/dev/null 2>&1 & rp=$!
held=0
for i in $(seq 1 600); do
  if [ -s "$TMP/state/lock.d/owner" ] && [ "$(awk '{print $1}' "$TMP/state/lock.d/owner")" = "$rp" ]; then held=1; break; fi
  kill -0 "$rp" 2>/dev/null || break
  sleep 0.05
done
if [ "$held" -eq 1 ]; then
  echo "1 $(date +%s) newowner" > "$TMP/state/lock.d/owner"
  printf '0\n' > "$TMP/state/backoff_until"
  wait "$rp"
  check 'release (real script) leaves a lock that another owner now holds' "grep -q newowner '$TMP/state/lock.d/owner'"
else
  bad 'release (real script) acquired its own lock before owner replacement'
  kill -KILL "$rp" 2>/dev/null || true
  wait "$rp" 2>/dev/null || true
fi
rm -f "$TMP/state/backoff_until"
# A lock that keeps looking abandoned but cannot be reclaimed must not trap a NO_WAIT caller.
mkdir -p "$TMP/state/lock.d" "$TMP/state/lock.d.reclaim"; echo "1 $(( $(date +%s) - 400 )) stuck" > "$TMP/state/lock.d/owner"
AI_GH_NO_WAIT=1 AI_GH_NO_WAIT_LOCK_SECONDS=2 timeout 30 "$GH" z >/dev/null 2>&1; rc=$?
check 'NO_WAIT gives up with 75 even while reclaim attempts keep failing' "[ $rc -eq 75 ]"
rm -rf "$TMP/state/lock.d.reclaim"
rm -rf "$TMP/state/lock.d"
# Command-line redaction: secret values passed as flags never reach the log.
: > "$TMP/state/failures.log"
FAKE_MODE=notfound AI_GH_QUOTA_PROBE_SECONDS=off "$GH" api repos/x -f password=hunter2 --body 's3cr3tvalue' >/dev/null 2>&1
FAKE_MODE=notfound AI_GH_QUOTA_PROBE_SECONDS=off "$GH" secret set MY_KEY --body 'topsecret42' >/dev/null 2>&1
check 'flag values and secret-set arguments are never logged' "! grep -qE 'hunter2|s3cr3tvalue|topsecret42|MY_KEY' '$TMP/state/failures.log' && grep -q 'args=secret set' '$TMP/state/failures.log'"
check 'a plain token message stays diagnosable' "[ \"\$(echo 'token in keyring is invalid' | bash -c \"\$(sed -n '/^redact()/p' '$GH'); redact\")\" = 'token in keyring is invalid' ]"
# Slow mode below 40% remaining.
rm -f "$TMP/state/quota" "$TMP/state/backoff_until"; echo 0 > "$TMP/state/last_call"
FAKE_MODE=quota FAKE_REMAINING=1500 AI_GH_QUOTA_PROBE_SECONDS=300 AI_GH_QUOTA_SLOW_SPACING=30 AI_GH_NO_WAIT=1 "$GH" pr view 7 >/dev/null 2>&1; rc=$?
FAKE_MODE=quota FAKE_REMAINING=1500 AI_GH_QUOTA_PROBE_SECONDS=300 AI_GH_QUOTA_SLOW_SPACING=30 AI_GH_NO_WAIT=1 "$GH" pr view 8 >/dev/null 2>&1; rc2=$?
check "below 40% remaining the next call is spaced out (NO_WAIT gives up with 75)" "[ $rc -eq 0 ] && [ $rc2 -eq 75 ]"
rm -f "$TMP/state/quota" "$TMP/state/backoff_until"
"$WAIT" --interval >/dev/null 2>&1; check 'an option without a value is refused, not looped on' "[ $? -eq 3 ]"
# A reclaim gate left behind by a killed process must not wedge the machine.
mkdir -p "$TMP/state/lock.d" "$TMP/state/lock.d.reclaim"
echo "999999 $(( $(date +%s) - 400 )) tok" > "$TMP/state/lock.d/owner"
touch -d '@'$(( $(date +%s) - 120 )) "$TMP/state/lock.d.reclaim"
check 'an abandoned reclaim gate is cleared instead of hanging' "timeout 25 '$GH' zz"
rm -rf "$TMP/state/lock.d" "$TMP/state/lock.d.reclaim"
# A stuck gate must still let a NO_WAIT caller give up rather than loop.
mkdir -p "$TMP/state/lock.d" "$TMP/state/lock.d.reclaim"
echo "999999 $(( $(date +%s) - 400 )) tok" > "$TMP/state/lock.d/owner"
AI_GH_NO_WAIT=1 AI_GH_NO_WAIT_LOCK_SECONDS=2 timeout 25 "$GH" zz >/dev/null 2>&1; rc=$?
check 'a stuck reclaim gate still lets NO_WAIT callers exit 75' "[ $rc -eq 75 ]"
rm -rf "$TMP/state/lock.d" "$TMP/state/lock.d.reclaim"
# Error output reaches the caller live, and glued flag values are not logged.
: > "$TMP/state/failures.log"
FAKE_MODE=notfound AI_GH_QUOTA_PROBE_SECONDS=off "$GH" api z -fkey=gluedsecret 2> "$TMP/live-err" >/dev/null
check "gh's error output reaches the caller" "grep -q 'HTTP 404: Not Found' '$TMP/live-err'"
check 'glued flag values are not logged' "! grep -q gluedsecret '$TMP/state/failures.log'"
rm -f "$TMP/state/backoff_until"
check 'redaction covers Bearer and inline Authorization' "[ \"\$(printf 'args=api -H Authorization: Bearer eyJabc.def\n' | bash -c \"\$(grep '^redact()' '$GH'); redact\")\" = 'args=api -H Authorization: [REDACTED]' ] && [ \"\$(echo 'x Bearer eyJabc' | bash -c \"\$(grep '^redact()' '$GH'); redact\")\" = 'x Bearer [REDACTED]' ]"
: > "$FAKE_LOG"; rm -f "$TMP/state/backoff_until"
FAKE_MODE=secondary AI_GH_QUOTA_PROBE_SECONDS=0 "$GH" pr view 9 >/dev/null 2>&1
check 'no header snapshot request after a secondary refusal' "! grep -q 'api --include' '$FAKE_LOG'"
rm -f "$TMP/state/backoff_until" "$TMP/state/quota"

# ai-gh-wait
AI_DEVOPS_TEST_MODE=0 "$WAIT" --until-regex x --interval 60 -- run view 1 >/dev/null 2>&1; rc=$?
check 'wait refuses an interval below 300 seconds' "[ $rc -eq 3 ]"
AI_DEVOPS_TEST_MODE=1 AI_GH_WAIT_TEST_MIN_INTERVAL=1 FAKE_MODE=counter "$WAIT" --until-regex completed --interval 1 --timeout-minutes 1 -- run view 1 > "$TMP/wout" 2>/dev/null; rc=$?
check 'wait exits 0 when the state matches' "[ $rc -eq 0 ] && grep -q completed '$TMP/wout' && [ \$(cat '$FAKE_COUNT') -eq 2 ]"
check 'wait default interval is at least 300 seconds' "grep -q '^INTERVAL=300' '$WAIT' && grep -q '^MIN=300' '$WAIT'"
"$GH" pr checks 1 --watch=true >/dev/null 2>&1; rc=$?
check '--watch=VALUE is refused too' "[ $rc -eq 2 ]"
: > "$FAKE_LOG"; echo 0 > "$FAKE_COUNT"
# Leave enough lead for a loaded Windows runner to start ai-gh-wait before
# this artificial back-off expires; otherwise the test never exercises it.
echo $(( $(date +%s) + 15 )) > "$TMP/state/backoff_until"
AI_DEVOPS_TEST_MODE=1 AI_GH_WAIT_TEST_MIN_INTERVAL=1 FAKE_MODE=counter timeout 60 "$WAIT" --until-regex completed --interval 1 --timeout-minutes 1 -- run view 1 > "$TMP/wout" 2> "$TMP/werr"; rc=$?
check 'wait stretches its delay through a recorded back-off, then succeeds' "[ $rc -eq 0 ] && grep -q 'back-off active' '$TMP/werr'"
rm -f "$TMP/state/backoff_until"
AI_DEVOPS_TEST_MODE=1 AI_GH_WAIT_TEST_MIN_INTERVAL=1 timeout 90 "$WAIT" --until-regex never-matches --interval 30 --timeout-minutes 0 -- run view 1 >/dev/null 2>&1; rc=$?
check 'wait exits 2 at its deadline' "[ $rc -eq 2 ]"
AI_DEVOPS_TEST_MODE=1 AI_GH_WAIT_TEST_MIN_INTERVAL=1 timeout 20 "$WAIT" --until-regex x --interval 1 -- run watch 1 >/dev/null 2>&1; rc=$?
check 'wait does not retry a command the throttle refuses' "[ $rc -eq 3 ]"
cat > "$TMP/pending-gh" <<'EOF'
#!/usr/bin/env bash
n=$(( $(cat "$FAKE_COUNT" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$FAKE_COUNT"
if [ "$n" -ge 4 ]; then echo 'build pass'; exit 0; fi
echo 'build pending'; exit 8
EOF
chmod +x "$TMP/pending-gh"; echo 0 > "$FAKE_COUNT"
AI_GH_REAL_GH="$TMP/pending-gh" AI_DEVOPS_TEST_MODE=1 AI_GH_WAIT_TEST_MIN_INTERVAL=1 timeout 60 "$WAIT" --until-regex 'pass' --interval 1 --timeout-minutes 1 -- pr checks 1 >/dev/null 2>&1; rc=$?
check 'wait treats a pending exit (gh pr checks: 8) as not-done, not as failure' "[ $rc -eq 0 ] && [ \$(cat '$FAKE_COUNT') -eq 4 ]"
AI_GH_QUOTA_PAUSE_PCT=abc "$GH" pr view 1 >/dev/null 2>&1; rc=$?
check 'a non-numeric budget setting is refused, not silently skipped' "[ $rc -eq 2 ]"
check 'ai-pr-wait routes through the throttle' "grep -q 'ai-gh' '$ROOT/bin/ai-pr-wait'"

# P1: allowlisted metadata is scrubbed before any measurement is persisted.
cat > "$TMP/telemetry-gh" <<'EOF'
#!/usr/bin/env bash
printf 'body ghp_FIXTURE_CANARY query=private\n'
printf 'stderr password=FIXTURE_CANARY\n' >&2
exit "${FAKE_STATUS:-0}"
EOF
chmod +x "$TMP/telemetry-gh"
export AI_GH_REAL_GH="$TMP/telemetry-gh" AI_GH_STATE_DIR="$TMP/telemetry-state"
AI_GH_CALLER=$'FIXTURE_CANARY\ninjected' "$GH" api 'repos/private/FIXTURE_CANARY?secret=value' -f 'query=FIXTURE_CANARY' > "$TMP/tout" 2> "$TMP/terr"; rc=$?
check 'telemetry_redacts_before_write' "[ $rc -eq 0 ] && ! grep -RqE 'FIXTURE_CANARY|injected|secret=value|password=|private' '$TMP/telemetry-state/measurements' && jq -e '.operation == \"api.unknown\" and .caller == \"unknown\" and .repository == \"redacted\" and .http_requests == null and .graphql_points == null' '$TMP/telemetry-state/measurements/'*.jsonl"
printf 'body ghp_FIXTURE_CANARY query=private\n' > "$TMP/expected-out"
printf 'stderr password=FIXTURE_CANARY\n' > "$TMP/expected-err"
check 'telemetry_preserves_streams_and_status success' "cmp '$TMP/tout' '$TMP/expected-out' && cmp '$TMP/terr' '$TMP/expected-err'"
FAKE_STATUS=8 "$GH" pr checks 1 > "$TMP/tout" 2> "$TMP/terr"; rc=$?
check 'telemetry_preserves_streams_and_status failure' "[ $rc -eq 8 ] && cmp '$TMP/tout' '$TMP/expected-out' && cmp '$TMP/terr' '$TMP/expected-err' && jq -se '.[-1].exit_status == 8' '$TMP/telemetry-state/measurements/'*.jsonl"
mkdir "$TMP/telemetry-state/measurements/write.lock"
FAKE_STATUS=8 "$GH" pr checks 1 > "$TMP/tout" 2> "$TMP/terr"; rc=$?
check 'telemetry failure is visible and preserves failed command status' "[ $rc -eq 8 ] && grep -q 'request measurement unavailable' '$TMP/terr' && cmp '$TMP/tout' '$TMP/expected-out'"
touch -d '5 minutes ago' "$TMP/telemetry-state/measurements/write.lock"
FAKE_STATUS=8 "$GH" pr checks 1 > "$TMP/tout" 2> "$TMP/terr"; rc=$?
check 'a lock left by a crash is cleared and measurement resumes' "[ $rc -eq 8 ] && ! grep -q 'request measurement unavailable' '$TMP/terr' && [ ! -d '$TMP/telemetry-state/measurements/write.lock' ]"
touch "$TMP/telemetry-state/measurements/2000-01-01.jsonl"
"$GH" api graphql > /dev/null 2>/dev/null
check 'telemetry retention removes only old owned date files' "[ ! -e '$TMP/telemetry-state/measurements/2000-01-01.jsonl' ] && jq -se '.[-1].bucket == \"graphql\" and .[-1].cli_executions == 1 and .[-1].principal == \"unknown\"' '$TMP/telemetry-state/measurements/'*.jsonl"
python "$ROOT/tools/github-requests/report.py" "$TMP/telemetry-state/measurements" > "$TMP/report"; rc=$?
check 'request_report_coverage_and_denominator' "[ $rc -eq 0 ] && jq -e '.records == 4 and .opaque_cli_executions == 4 and .http_requests == null and .graphql_points == null and (.acceptance | startswith(\"incomplete\")) and (.coverage_gaps | length) > 0' '$TMP/report'"
printf '{"operation":"FIXTURE_CANARY"}\n' > "$TMP/telemetry-state/measurements/2001-01-01.jsonl"
python "$ROOT/tools/github-requests/report.py" "$TMP/telemetry-state/measurements" > "$TMP/report" 2> "$TMP/report-error"; rc=$?
check 'request report rejects untrusted labels without reflecting them' "[ $rc -eq 1 ] && [ ! -s '$TMP/report' ] && ! grep -q FIXTURE_CANARY '$TMP/report-error'"

# Reject malformed JSON shapes through the same fixed diagnostic, never a
# traceback or a reflected input value. Keep a valid row before the bad one
# to prove the report cannot publish a partial aggregate on later corruption.
mkdir "$TMP/report-shapes"
head -n 1 "$TMP/telemetry-state/measurements/$(date -u +%F).jsonl" > "$TMP/report-valid"
python -c 'print("request report: invalid or unavailable measurement input; no report produced")' > "$TMP/report-expected-error"
for shape in '[]' '["FIXTURE_CANARY"]' 'null' 'true' '1' '"FIXTURE_CANARY"' \
  '{"operation":[]}' '{"operation":{}}' '{"operation":true}' \
  '{"operation":"api.graphql","caller":[]}' '{"operation":"api.graphql","caller":{}}'; do
  cat "$TMP/report-valid" > "$TMP/report-shapes/2001-01-01.jsonl"
  printf '%s\n' "$shape" >> "$TMP/report-shapes/2001-01-01.jsonl"
  python "$ROOT/tools/github-requests/report.py" "$TMP/report-shapes" > "$TMP/report" 2> "$TMP/report-error"; rc=$?
  check 'request report rejects nonobject or wrong-type label without partial output' "[ $rc -eq 1 ] && [ ! -s '$TMP/report' ] && cmp '$TMP/report-error' '$TMP/report-expected-error'"
done
for mutation in '.schema=true' '.schema="1"' 'del(.http_requests)' 'del(.graphql_points)' '.utc=[]' '.latency_ms=true'; do
  jq -c "$mutation" "$TMP/report-valid" > "$TMP/report-shapes/2001-01-01.jsonl"
  python "$ROOT/tools/github-requests/report.py" "$TMP/report-shapes" > "$TMP/report" 2> "$TMP/report-error"; rc=$?
  check 'request report rejects invalid required field shapes' "[ $rc -eq 1 ] && [ ! -s '$TMP/report' ] && cmp '$TMP/report-error' '$TMP/report-expected-error'"
done
python -c 'print("[" * 2000 + "\"FIXTURE_CANARY\"" + "]" * 2000)' > "$TMP/report-shapes/2001-01-01.jsonl"
python "$ROOT/tools/github-requests/report.py" "$TMP/report-shapes" > "$TMP/report" 2> "$TMP/report-error"; rc=$?
check 'request report rejects excessive JSON nesting with controlled diagnostic' "[ $rc -eq 1 ] && [ ! -s '$TMP/report' ] && cmp '$TMP/report-error' '$TMP/report-expected-error'"

# Reject every non-regular path before opening it; a FIFO must never hold up
# the original operation or the offline reader. Directories exercise this on
# Windows too, where the filesystem may not implement mkfifo.
export AI_GH_STATE_DIR="$TMP/special-state"
mkdir -p "$AI_GH_STATE_DIR/measurements/$(date -u +%F).jsonl"
FAKE_STATUS=8 timeout 15 "$GH" pr checks 1 > "$TMP/special-out" 2> "$TMP/special-err"; rc=$?
check 'telemetry rejects non-regular daily paths without changing status' "[ $rc -eq 8 ] && grep -q 'request measurement unavailable' '$TMP/special-err' && [ ! -d '$AI_GH_STATE_DIR/measurements/write.lock' ]"
timeout 15 python "$ROOT/tools/github-requests/report.py" "$AI_GH_STATE_DIR/measurements" > "$TMP/report" 2> "$TMP/report-error"; rc=$?
check 'report rejects non-regular daily paths before opening' "[ $rc -eq 1 ] && [ ! -s '$TMP/report' ]"
rmdir "$AI_GH_STATE_DIR/measurements/$(date -u +%F).jsonl"
if mkfifo "$AI_GH_STATE_DIR/measurements/$(date -u +%F).jsonl" 2>/dev/null; then
  FAKE_STATUS=8 timeout 15 "$GH" pr checks 1 > "$TMP/special-out" 2> "$TMP/special-err"; rc=$?
  check 'FIFO telemetry path cannot block a failed command' "[ $rc -eq 8 ] && grep -q 'request measurement unavailable' '$TMP/special-err'"
  timeout 15 python "$ROOT/tools/github-requests/report.py" "$AI_GH_STATE_DIR/measurements" > "$TMP/report" 2> "$TMP/report-error"; rc=$?
  check 'FIFO report input is rejected without waiting for a writer' "[ $rc -eq 1 ] && [ ! -s '$TMP/report' ]"
else
  printf '  skip FIFO cases: filesystem does not support named pipes (directory cases passed above)\n'
fi
mkdir "$AI_GH_STATE_DIR/quota-observation.json"
source "$ROOT/tools/github-requests/telemetry.sh"
STATE="$AI_GH_STATE_DIR"
gh_measure_quota 1 2 3 4 5 6 7 8 9 >/dev/null 2>&1; rc=$?
check 'quota observation rejects non-regular destination too' "[ $rc -eq 1 ] && [ -d '$AI_GH_STATE_DIR/quota-observation.json' ] && [ \$(find '$AI_GH_STATE_DIR' -maxdepth 1 -name 'quota-observation.*' -type f | wc -l) -eq 0 ]"

STATE="$TMP/named-row-state"; mkdir -p "$STATE"
gh_measure_quota_rows $'future_resource\t9\t10\t30\nsearch\t7\t30\t40\ncore\t80\t100\t50\ngraphql\t61\t200\t60'
check 'named quota telemetry ignores row order and extra resource names' "jq -e '.buckets.core.remaining == 80 and .buckets.graphql.remaining == 61 and .buckets.search.remaining == 7 and (.buckets|keys|length) == 3' '$STATE/quota-observation.json'"
gh_measure_quota_rows $'core\tbad\t100\t50\nsearch\t7\t30\t40\textra'
check 'missing malformed and overlong quota rows remain unknown' "jq -e '.buckets.core == null and .buckets.graphql == null and .buckets.search == null' '$STATE/quota-observation.json'"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
