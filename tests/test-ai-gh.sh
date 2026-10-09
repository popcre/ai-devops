#!/usr/bin/env bash
# Tests for bin/ai-gh (machine-wide GitHub throttle) and bin/ai-gh-wait.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; GH="$ROOT/bin/ai-gh"; WAIT="$ROOT/bin/ai-gh-wait"
PYTHON_RUNNER=''
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -c 'import sys; sys.exit(sys.version_info < (3, 10))' >/dev/null 2>&1; then PYTHON_RUNNER="$(command -v "$candidate")"; break; fi
done
[ -n "$PYTHON_RUNNER" ] || { printf 'Python 3.10 or newer is required\n' >&2; exit 2; }
PASS=0; FAIL=0; ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }; bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
FAKE="$TMP/fake-gh"
cat > "$FAKE" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-} ${2:-}" = 'auth token' ]; then printf '%s\n' "${FAKE_TOKEN:-fixture-token}"; exit 0; fi
if [ "${1:-} ${2:-}" = 'api user' ]; then [ -z "${FAKE_IDENTITY_LOG:-}" ] || printf 'lookup\n' >> "$FAKE_IDENTITY_LOG"; printf '%s\n' "${FAKE_PRINCIPAL:-55610577}"; exit "${FAKE_IDENTITY_STATUS:-0}"; fi
echo "start $(date +%s%N) $*" >> "$FAKE_LOG"
case "${FAKE_MODE:-ok}" in
  ok) sleep "${FAKE_SLEEP:-0}"; if [ -n "${FAKE_HOLD:-}" ] && [ -e "$FAKE_HOLD" ]; then echo "held $*" >> "$FAKE_LOG"; while [ -e "$FAKE_HOLD" ]; do sleep 0.1; done; fi; echo "out:$*" ;;
  secondary) echo 'HTTP 403: You have exceeded a secondary rate limit. Please wait a few minutes before you try again.' >&2; echo 'Retry-After: 900' >&2; echo "end $(date +%s%N)" >> "$FAKE_LOG"; exit 1 ;;
  secondary-short) echo 'gh: HTTP 429: Too Many Requests (retry-after: 60)' >&2; exit 1 ;;
  secondary-mixed) echo 'HTTP 429: secondary rate limit; API rate limit exceeded for user ID 55610577; Retry-After: 60' >&2; exit 1 ;;
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
    elif [[ " $* " == *" graphql "* || " $* " == *" /graphql "* ]]; then printf '{"data":{}}\n'
    else echo "out:$*"; fi ;;
  primary) if [ "$1 $2" = 'api --include' ]; then
    [ -z "${FAKE_EXTRA_RESOURCE:-}" ] || printf '%s\t0\t100\t%s\n' "$FAKE_EXTRA_RESOURCE" $(( $(date +%s) + 3600 ));
    printf 'HTTP/2.0 200 OK\nX-Ratelimit-Remaining: 0\nX-Ratelimit-Reset: %s\nX-Github-Request-Id: F95F:1E2E31\n\ncore\t0\t5000\t%s\ngraphql\t0\t5000\t%s\n' $(( $(date +%s) + 9000 )) $(( $(date +%s) + 3000 )) $(( $(date +%s) + 2000 ));
    elif [ "$1 $2" = 'api rate_limit' ]; then printf 'core\t4000\t5000\t%s\ngraphql\t4000\t5000\t%s\n' $(( $(date +%s) + 3000 )) $(( $(date +%s) + 2000 )); else echo 'gh: API rate limit exceeded for user ID 55610577. (HTTP 403) token ghp_abcdefSECRET123' >&2; exit 1; fi ;;
  missing-resource) if [ "$1 $2" = 'api rate_limit' ]; then printf 'core\t4999\t5000\t%s\n' $(( $(date +%s) + 9000 ));
    elif [ "$1 $2" = 'api --include' ]; then printf 'HTTP/2 200\nX-Ratelimit-Reset: %s\n\ncore\t4999\t5000\t%s\n' $(( $(date +%s) + 9000 )) $(( $(date +%s) + 9000 ));
    else echo 'gh: API rate limit already exceeded for user ID 55610577. (HTTP 403)' >&2; exit 1; fi ;;
  probe-timeout) if [ "$1 $2" = 'api rate_limit' ]; then sleep 2; else echo "out:$*"; fi ;;
  graphql-200-primary|graphql-200-secondary|graphql-200-partial|graphql-cli-error|graphql-crash|graphql-large|graphql-unknown|graphql-malformed-errors|graphql-jq-scalar|graphql-jq-empty|graphql-jq-error|graphql-pages|graphql-pages-error)
    if [ "$1 $2" = 'api rate_limit' ]; then
      printf 'core\t4000\t5000\t%s\ngraphql\t4000\t5000\t%s\n' $(( $(date +%s) + 1800 )) $(( $(date +%s) + 2400 ))
    elif [ "$1 $2" = 'api --include' ]; then
      printf 'HTTP/2 200\n\ncore\t4000\t5000\t%s\ngraphql\t0\t5000\t%s\n' $(( $(date +%s) + 1800 )) $(( $(date +%s) + 2400 ))
    elif [ "$FAKE_MODE" = graphql-200-primary ]; then
      printf '{"data":{"viewer":{"login":"partial"}},"errors":[{"message":"API rate limit exceeded"}]}\n'
    elif [ "$FAKE_MODE" = graphql-200-secondary ]; then
      printf '{"data":{"viewer":{"login":"partial"}},"errors":[{"message":"secondary rate limit"}]}\n'
    elif [ "$FAKE_MODE" = graphql-cli-error ]; then
      printf 'temporary upstream reset\n' >&2; exit 1
    elif [ "$FAKE_MODE" = graphql-crash ]; then
      printf '{"data":{"viewer":{"login":"FIXTURE_PRIVATE_BODY"}}}\n'; sleep 3
    elif [ "$FAKE_MODE" = graphql-large ]; then
      printf '{"data":{"text":"'; head -c 100000 /dev/zero | tr '\0' a; printf '"}}\n'
    elif [ "$FAKE_MODE" = graphql-unknown ]; then
      printf 'not-json\n'
    elif [ "$FAKE_MODE" = graphql-malformed-errors ]; then
      printf '{"data":{"viewer":{"login":"partial"}},"errors":{"message":"bad-shape"}}\n'
    elif [ "$FAKE_MODE" = graphql-jq-scalar ]; then
      printf 'scalar\n'
    elif [ "$FAKE_MODE" = graphql-jq-empty ]; then
      :
    elif [ "$FAKE_MODE" = graphql-jq-error ]; then
      printf '{"data":{"viewer":{"login":"partial"}},"errors":[{"message":"field unavailable"}]}\n'
      printf 'gh: field unavailable\n' >&2
      exit 1
    elif [ "$FAKE_MODE" = graphql-pages ]; then
      printf '{"data":{"page":1}}\n{"data":{"page":2}}\n'
    elif [ "$FAKE_MODE" = graphql-pages-error ]; then
      printf '{"data":{"page":1}}\n{"data":{"page":2},"errors":[{"message":"API rate limit exceeded"}]}\n'
    else
      printf '{"data":{"viewer":{"login":"partial"}},"errors":[{"message":"field unavailable"}]}\n'
    fi ;;
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
# Reservation order is serialized; process scheduling after lock release can
# change the order of actual child starts. Check the observed burst envelope.
check 'concurrent processes space their GitHub call starts' "[ \$(grep -c '^start' '$FAKE_LOG') -eq 3 ] && awk '/^start/{print \$2}' '$FAKE_LOG' | sort -n | awk '{t[++n]=\$1} END{if(n!=3 || (t[3]-t[1])/1000000 < 1500) exit 1; for(i=2;i<=n;i++) if((t[i]-t[i-1])/1000000 < 400) exit 1}'"
check 'lock is released after calls' "[ ! -d '$TMP/state/lock.d' ]"
: > "$FAKE_LOG"
# Prove ordering, not speed: the slow call is held open until the quick call
# has finished, so no timing window exists however loaded the machine is (#775).
touch "$TMP/hold"; FAKE_HOLD="$TMP/hold" "$GH" slow >/dev/null & sp=$!
for _ in $(seq 1 600); do grep -q '^held slow$' "$FAKE_LOG" && break; sleep 0.2; done
timeout 120 "$GH" quick >/dev/null; qrc=$?; rm -f "$TMP/hold"; wait "$sp"
check 'a slow call does not block the next caller' "[ $qrc -eq 0 ] && awk '/^held slow$/{if(!s)s=NR} /^start .* quick$/{q=NR} /^end/{if(!e)e=NR} END{exit !(s && q && e && s<q && q<e)}' '$FAKE_LOG'"

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
FAKE_MODE=secondary-mixed AI_GH_QUOTA_PROBE_SECONDS=0 "$GH" api z >/dev/null 2>&1; rc=$?
check 'secondary wording wins over simultaneous primary wording' "[ $rc -eq 75 ] && [ \$(cat '$TMP/state/backoff_until') -gt \$(date +%s) ] && grep -q 'kind=secondary' '$TMP/state/refusals.log'"
rm -f "$TMP/state/backoff_until"

# Hourly (primary) budget.
# Follow-up probes must share the same start-spacing lock as real requests.
: > "$FAKE_LOG"
for i in 1 2; do FAKE_MODE=spaced-failure AI_GH_QUOTA_PROBE_SECONDS=300 AI_GH_MIN_SPACING_SECONDS=2 "$GH" api repos/o/r/issues >/dev/null 2>&1 & done
wait
# Ordinary failures need no diagnostic quota request. Both commands still
# reserve separate starts even when their processes launch in either order.
check 'concurrent ordinary failures retain spacing without diagnostic probes' "! grep -q 'api --include rate_limit' '$FAKE_LOG' && awk '/^start/{print \$2}' '$FAKE_LOG' | sort -n | awk '{t[++n]=\$1} END{if(n!=2 || (t[2]-t[1])/1000000 < 1000) exit 1}'"
: > "$FAKE_LOG"
FAKE_MODE=primary AI_GH_QUOTA_PROBE_SECONDS=0 AI_GH_MIN_SPACING_SECONDS=2 "$GH" api repos/o/r/issues >/dev/null 2>&1; rc=$?
check 'primary refusal snapshot also respects minimum start spacing' "[ $rc -eq 75 ] && [ \$(grep -c 'api --include rate_limit' '$FAKE_LOG') -eq 1 ] && awk '/^start/{print \$2}' '$FAKE_LOG' | sort -n | awk '{t[++n]=\$1} END{for(i=2;i<=n;i++) if((t[i]-t[i-1])/1000000 < 1900) exit 1}'"
rm -f "$TMP/state/backoff_until" "$TMP/state"/quota-pause.*
rm -f "$TMP/state/quota"
FAKE_MODE=quota FAKE_REMAINING=3000 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" pr view 2 > "$TMP/qout" 2>/dev/null; rc=$?
check 'mixed CLI cost is unknown and its resource snapshots are invalidated' "[ $rc -eq 0 ] && grep -q 'out:pr view 2' '$TMP/qout' && grep -q '^0 3000 5000 ' '$TMP/state/quota' && grep -q '^0 3000 5000 ' '$TMP/state/quota.graphql'"
check 'telemetry observes named server buckets with a private principal label' "jq -e '.buckets.core.remaining == 3000 and .buckets.graphql.remaining == 3000 and .buckets.search.remaining == 30 and (.principal | startswith(\"local-sha256:\"))' '$TMP/state/quota-observation.json'"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    # The runner's short-TEMP ACL varies by host. The protected positive
    # fixture below proves attribution; this one may safely be unattributed.
    check 'Windows quota context is validated or unattributed' "jq -e '.access_context | if . == null then true else test(\"^v1:[0-9a-f]{64}$\") end' '$TMP/state/quota-observation.json'"
    ;;
  *) check 'verified quota snapshot binds to an opaque local access context' "jq -e '.access_context | strings | test(\"^v1:[0-9a-f]{64}$\")' '$TMP/state/quota-observation.json'" ;;
esac
# Git Bash on NTFS reports its inherited Windows ACL through synthetic modes;
# POSIX hosts can additionally prove the file itself is mode 600.
salt_check="[ \$(stat -c %a '$TMP/state/principal-salt') = 600 ]"
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) salt_check="[ -s '$TMP/state/principal-salt' ]";; esac
check 'principal label uses a private local salt' "$salt_check && ! grep -R -q 55610577 '$TMP/state/measurements' '$TMP/state/quota-measurements'"
check 'quota observations retain bounded history without another request' "jq -se 'length >= 1 and .[-1].buckets.graphql.remaining == 3000' '$TMP/state/quota-measurements/'*.jsonl"

# One verified principal can hold distinct PATs. Quota snapshots must keep
# their access contexts apart while the local context lookup makes no API call.
context_log="$TMP/context-join-calls"; identity_log="$TMP/context-join-identity.log"
context_state="$TMP/context-join-state"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    # Match the S2 Windows context tests: the state must be below the user's
    # profile and have a private ACL before its first credential is read.
    # Prepare a private parent first. A user profile may itself grant Modify
    # to other SIDs, so EnsureCache must not be called directly below it.
    context_root="$(mktemp -d "$HOME/ai-gh-context.XXXXXXXX")"
    trap 'rm -rf "$TMP" "$context_root"' EXIT
    context_state="$context_root/state"
    CONTEXT_ACL_ROOT="$(cygpath -w "$context_root")" powershell.exe \
      -NoProfile -NonInteractive -Command '$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value; & icacls.exe "$env:CONTEXT_ACL_ROOT" /inheritance:r /grant:r ("*" + $sid + ":(OI)(CI)(F)") | Out-Null; exit $LASTEXITCODE' \
      >/dev/null 2>&1; context_acl_rc=$?
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass \
      -File "$(cygpath -w "$ROOT/tools/github-requests/secure-windows-path.ps1")" \
      -Mode EnsureCache -Path "$(cygpath -w "$context_state")" >/dev/null 2>&1; context_setup_rc=$?
    check 'Windows quota context fixture has a protected state directory' "[ $context_acl_rc -eq 0 ] && [ $context_setup_rc -eq 0 ] && [ -d '$context_state' ]"
    ;;
esac
for token in ghp_fixtureA ghp_fixtureB; do
  AI_GH_STATE_DIR="$context_state" FAKE_MODE=quota FAKE_REMAINING=4000 \
    FAKE_TOKEN="$token" FAKE_LOG="$context_log" FAKE_IDENTITY_LOG="$identity_log" \
    AI_GH_QUOTA_PROBE_SECONDS=0 "$GH" api repos/o/r >/dev/null 2>&1
done
check 'same-principal credentials retain two distinct quota access contexts' "jq -se 'length == 2 and (map(.access_context) | all(. != null)) and (map(.access_context) | unique | length == 2) and (map(.principal) | unique | length == 1)' '$context_state/quota-measurements/'*.jsonl"
check 'local context lookup adds no GitHub API request' "[ \$(grep -c '^start' '$context_log') -eq 4 ] && [ \$(wc -l < '$identity_log') -eq 2 ]"
check 'quota history contains no token or numeric principal' "! grep -Eq 'ghp_fixtureA|ghp_fixtureB|55610577' '$context_state/quota-measurements/'*.jsonl"
printf 'interrupted-write\n' > "$context_state/quota.graphql.tmp.ABC123"
AI_GH_STATE_DIR="$context_state" FAKE_MODE=quota FAKE_REMAINING=4000 \
  FAKE_TOKEN=ghp_fixtureC AI_GH_QUOTA_PROBE_SECONDS=0 "$GH" api repos/o/r >/dev/null 2>&1; context_rc=$?
check 'interrupted quota temp file does not block credential rotation and stays preserved' "[ $context_rc -eq 0 ] && [ \$(cat '$context_state/quota.graphql.tmp.ABC123') = interrupted-write ] && [ \$(cat '$context_state/quota.graphql' | awk '{print \$2}') = 4000 ]"
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_TOKEN=ghp_fixtureA AI_GH_STATE_DIR="$context_state" \
  AI_GH_QUOTA_PROBE_SECONDS=0 "$GH" api repos/o/r >/dev/null 2>&1; context_rc=$?
check 'credential restore also ignores preserved interrupted quota temp files' "[ $context_rc -eq 0 ] && [ \$(cat '$context_state/quota.graphql.tmp.ABC123') = interrupted-write ]"

AI_GH_STATE_DIR="$TMP/context-missing-state" FAKE_MODE=quota FAKE_REMAINING=4000 \
  FAKE_TOKEN=ghp_fixtureC FAKE_IDENTITY_STATUS=1 FAKE_LOG="$TMP/context-missing-calls" \
  AI_GH_QUOTA_PROBE_SECONDS=0 "$GH" api repos/o/r >/dev/null 2>&1; context_rc=$?
check 'unverified identity leaves quota access context unattributed' "[ $context_rc -eq 0 ] && jq -e '.access_context == null and .principal == \"unknown\"' '$TMP/context-missing-state/quota-observation.json'"
check 'unverified quota history contains no credential or principal' "! grep -Eq 'ghp_fixtureC|55610577' '$TMP/context-missing-state/quota-measurements/'*.jsonl"
rm -f "$TMP/state/quota"; : > "$FAKE_LOG"
FAKE_MODE=quota FAKE_REMAINING=900 AI_GH_QUOTA_PROBE_SECONDS=300 AI_GH_NO_WAIT=1 "$GH" pr view 3 >/dev/null 2>&1; rc=$?
check 'budget below 20% pauses its resource without making the call' "[ $rc -eq 75 ] && ! grep -q 'pr view 3' '$FAKE_LOG' && [ \$(cat '$TMP/state/quota-pause.core') -gt \$(date +%s) ] && grep -q 'budget-pause remaining=900/5000' '$TMP/state/refusals.log'"
rm -f "$TMP/state/backoff_until" "$TMP/state/quota" "$TMP/state"/quota-pause.*
before=$(date +%s)
FAKE_MODE=primary AI_GH_QUOTA_PROBE_SECONDS=0 "$GH" pr list >/dev/null 2>&1; rc=$?
check 'primary limit refusal pauses the exhausted core resource until reset' "[ $rc -eq 75 ] && [ \$(cat '$TMP/state/quota-pause.core') -ge $((before + 2900)) ] && grep -q 'kind=primary' '$TMP/state/refusals.log'"
check 'refusal log keeps the exact refusal text' "grep -q 'API rate limit exceeded for user ID 55610577' '$TMP/state/refusals.log'"
check 'failure log records status, headers and body' "grep -q 'status: HTTP 403' '$TMP/state/failures.log' && grep -qi 'x-ratelimit-remaining: 0' '$TMP/state/failures.log' && grep -q 'X-Github-Request-Id: F95F:1E2E31' '$TMP/state/failures.log'"
check 'failure and refusal logs redact credentials' "! grep -q 'ghp_abcdef' '$TMP/state/failures.log' '$TMP/state/refusals.log' && grep -q REDACTED '$TMP/state/failures.log'"
rm -f "$TMP/state/backoff_until"
FAKE_MODE=notfound AI_GH_QUOTA_PROBE_SECONDS=off "$GH" api nope >/dev/null 2>&1
check 'ordinary failures are logged too' "grep -q 'args=api nope' '$TMP/state/failures.log' && grep -q 'HTTP 404: Not Found' '$TMP/state/failures.log'"
rm -f "$TMP/state/backoff_until" "$TMP/state/quota"

# Resource classification and accounting: no real credential or API is used.
fresh_quota(){ rm -f "$TMP/state/quota" "$TMP/state"/quota.* "$TMP/state"/quota-pause.* "$TMP/state/quota-resources" "$TMP/state/backoff_until"; rm -rf "$TMP/state/quota-contexts"; : > "$FAKE_LOG"; }
mkdir -p "$TMP/linked-outside" "$TMP/link-identity-state" "$TMP/link-context-state" "$TMP/fifo-salt-state"
if ln -s "$TMP/linked-outside" "$TMP/linked-state" 2>/dev/null && [ -L "$TMP/linked-state" ]; then
  AI_GH_STATE_DIR="$TMP/linked-state" FAKE_MODE=quota AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r > "$TMP/linked-state-out" 2> "$TMP/linked-state-err"; rc=$?
  check 'linked state root is rejected before an API call' "[ $rc -eq 3 ] && [ ! -s '$TMP/linked-state-out' ] && grep -q 'invalid GitHub state directory' '$TMP/linked-state-err'"
else ok 'linked state root fixture is unavailable on this host'; fi
if ln -s "$TMP/linked-outside" "$TMP/link-identity-state/identities" 2>/dev/null && [ -L "$TMP/link-identity-state/identities" ]; then
  AI_GH_STATE_DIR="$TMP/link-identity-state" FAKE_MODE=quota AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r > "$TMP/link-identity-out" 2> "$TMP/link-identity-err"; rc=$?
  check 'linked identity directory is rejected before an API call' "[ $rc -eq 3 ] && [ ! -s '$TMP/link-identity-out' ] && grep -q 'cannot protect GitHub identity cache' '$TMP/link-identity-err' && [ ! -e '$TMP/linked-outside/owner' ]"
else ok 'linked identity directory fixture is unavailable on this host'; fi
if ln -s "$TMP/linked-outside" "$TMP/link-context-state/quota-contexts" 2>/dev/null && [ -L "$TMP/link-context-state/quota-contexts" ]; then
  AI_GH_STATE_DIR="$TMP/link-context-state" FAKE_MODE=quota AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r > "$TMP/link-context-out" 2> "$TMP/link-context-err"; rc=$?
  check 'linked quota directory is rejected before an API call' "[ $rc -eq 3 ] && [ ! -s '$TMP/link-context-out' ] && grep -q 'cannot protect GitHub quota contexts' '$TMP/link-context-err'"
else ok 'linked quota directory fixture is unavailable on this host'; fi
mkfifo "$TMP/fifo-salt-state/principal-salt"
AI_GH_STATE_DIR="$TMP/fifo-salt-state" FAKE_MODE=quota AI_GH_QUOTA_PROBE_SECONDS=300 timeout 15 "$GH" api repos/o/r > "$TMP/fifo-salt-out" 2> "$TMP/fifo-salt-err"; rc=$?
check 'non-regular principal salt is ignored without blocking the command' "[ $rc -eq 0 ] && jq -e '.principal == \"unknown\"' '$TMP/fifo-salt-state/quota-observation.json' && [ -p '$TMP/fifo-salt-state/principal-salt' ]"
printf 'protected\n' > "$TMP/linked-outside/canary"
mkdir -p "$TMP/link-put-state" "$TMP/link-log-state" "$TMP/link-refusal-state" "$TMP/link-restore-state"
if ln -s "$TMP/linked-outside/canary" "$TMP/link-put-state/last_call" 2>/dev/null && [ -L "$TMP/link-put-state/last_call" ]; then
  AI_GH_STATE_DIR="$TMP/link-put-state" AI_GH_QUOTA_PROBE_SECONDS=off "$GH" pr view 1 > "$TMP/link-put-out" 2> "$TMP/link-put-err"; rc=$?
  check 'atomic state writer refuses a linked destination' "[ $rc -eq 3 ] && [ \$(cat '$TMP/linked-outside/canary') = protected ] && grep -q 'invalid GitHub state file' '$TMP/link-put-err'"
else ok 'linked state file fixture is unavailable on this host'; fi
if ln -s "$TMP/linked-outside/canary" "$TMP/link-log-state/failures.log" 2>/dev/null && [ -L "$TMP/link-log-state/failures.log" ]; then
  AI_GH_STATE_DIR="$TMP/link-log-state" FAKE_MODE=notfound AI_GH_QUOTA_PROBE_SECONDS=off "$GH" pr view 1 > "$TMP/link-log-out" 2> "$TMP/link-log-err"; rc=$?
  check 'failure evidence never appends through a link' "[ $rc -eq 1 ] && [ \$(cat '$TMP/linked-outside/canary') = protected ] && grep -q 'invalid GitHub state log' '$TMP/link-log-err'"
else ok 'linked failure log fixture is unavailable on this host'; fi
if ln -s "$TMP/linked-outside/canary" "$TMP/link-refusal-state/refusals.log" 2>/dev/null && [ -L "$TMP/link-refusal-state/refusals.log" ]; then
  AI_GH_STATE_DIR="$TMP/link-refusal-state" FAKE_MODE=secondary AI_GH_QUOTA_PROBE_SECONDS=off "$GH" pr view 1 > "$TMP/link-refusal-out" 2> "$TMP/link-refusal-err"; rc=$?
  check 'rate refusal never appends through a link' "[ $rc -eq 75 ] && [ \$(cat '$TMP/linked-outside/canary') = protected ] && grep -q 'invalid GitHub state log' '$TMP/link-refusal-err'"
else ok 'linked refusal log fixture is unavailable on this host'; fi
FAKE_TOKEN=token-restore-A AI_GH_STATE_DIR="$TMP/link-restore-state" FAKE_MODE=quota AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1
restore_key="$(cat "$TMP/link-restore-state/quota-context-key")"
FAKE_TOKEN=token-restore-B AI_GH_STATE_DIR="$TMP/link-restore-state" FAKE_MODE=quota AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1
if [ -f "$TMP/link-restore-state/quota-contexts/$restore_key/quota" ] && ln -s "$TMP/linked-outside/canary" "$TMP/link-restore-state/quota-contexts/$restore_key/quota.link" 2>/dev/null && [ -L "$TMP/link-restore-state/quota-contexts/$restore_key/quota.link" ]; then
  mv "$TMP/link-restore-state/quota-contexts/$restore_key/quota" "$TMP/link-restore-state/quota-contexts/$restore_key/quota.original"
  mv "$TMP/link-restore-state/quota-contexts/$restore_key/quota.link" "$TMP/link-restore-state/quota-contexts/$restore_key/quota"
  FAKE_TOKEN=token-restore-A AI_GH_STATE_DIR="$TMP/link-restore-state" FAKE_MODE=quota AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r > "$TMP/link-restore-out" 2> "$TMP/link-restore-err"; rc=$?
  check 'context restoration rejects a linked quota file' "[ $rc -eq 3 ] && [ \$(cat '$TMP/linked-outside/canary') = protected ] && grep -q 'invalid GitHub quota state' '$TMP/link-restore-err'"
else ok 'linked restore fixture is unavailable on this host'; fi
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_GRAPHQL_REMAINING=0 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql -f query=privatequery >/dev/null 2>"$TMP/resource-err"; rc=$?
check 'healthy REST cannot conceal exhausted GraphQL before a direct query' "[ $rc -eq 75 ] && ! grep -q 'api graphql' '$FAKE_LOG' && grep -q 'resource=graphql' '$TMP/state/refusals.log'"
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_GRAPHQL_REMAINING=0 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1; rc=$?
check 'exhausted GraphQL does not stop an independent healthy REST read' "[ $rc -eq 0 ] && grep -q 'api repos/o/r' '$FAKE_LOG'"
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
check 'leading GraphQL options retain the GraphQL measurement label' "jq -se '.[-1].operation == \"api.graphql\" and .[-1].bucket == \"graphql\"' '$TMP/state/measurements/'*.jsonl"
fresh_quota
command(){ if [ "${1:-}" = -v ] && [ "${2:-}" = jq ]; then return 1; fi; builtin command "$@"; }
export -f command
FAKE_MODE=quota AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql -f query=fixture > "$TMP/no-jq-out" 2> "$TMP/no-jq-err"; rc=$?
export -n -f command; unset -f command
check 'missing jq refuses GraphQL before an API call' "[ $rc -eq 3 ] && [ ! -s '$TMP/no-jq-out' ] && grep -q 'jq is required' '$TMP/no-jq-err' && ! grep -q 'api graphql' '$FAKE_LOG'"
FAKE_MODE=quota FAKE_REMAINING=0 FAKE_GRAPHQL_REMAINING=4000 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1; rc=$?
check 'exhausted REST does not stop an independent healthy GraphQL read' "[ $rc -eq 75 ] && [ \$(cat '$TMP/state/quota-pause.core') -gt \$(date +%s) ]"
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
check 'GraphQL refusal uses GraphQL reset, never the unrelated core response header' "[ $rc -eq 75 ] && [ \$(cat '$TMP/state/quota-pause.graphql') -ge $((before + 1900)) ] && [ \$(cat '$TMP/state/quota-pause.graphql') -lt $((before + 2500)) ]"
fresh_quota
before=$(date +%s)
FAKE_MODE=missing-resource AI_GH_QUOTA_PROBE_SECONDS=0 "$GH" api graphql -f query=privatevalue >/dev/null 2>"$TMP/unknown-quota"; rc=$?
check 'missing GraphQL evidence is visible and never borrows core reset' "[ $rc -eq 75 ] && grep -q 'graphql quota unknown' '$TMP/unknown-quota' && [ \$(cat '$TMP/state/backoff_until') -lt $((before + 1000)) ]"
check 'new resource diagnostics do not expose query values' "! grep -q privatevalue '$TMP/state/failures.log' '$TMP/state/refusals.log'"
fresh_quota
FAKE_MODE=probe-timeout FAKE_TOKEN=probe-timeout-token AI_GH_PROBE_TIMEOUT_SECONDS=1 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r > "$TMP/probe-timeout-out" 2> "$TMP/probe-timeout-err"; rc=$?
check 'quota probe timeout is unknown while the original CLI read still works' "[ $rc -eq 0 ] && grep -q 'out:api repos/o/r' '$TMP/probe-timeout-out' && grep -q 'core quota unknown' '$TMP/probe-timeout-err' && grep -q 'api rate_limit' '$FAKE_LOG'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api --hostname github.example repos/o/r >/dev/null 2>&1; rc=$?
check 'explicit host is probed and partitioned' "[ $rc -eq 0 ] && grep -q 'rate_limit --hostname github.example' '$FAKE_LOG' && grep -q ' github.example ' '$TMP/state/quota-context'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=0 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api --hostname github.example repos/o/r >/dev/null 2>&1; rc=$?
check 'an explicit-host budget refusal records its own bucket pause' "[ $rc -eq 75 ] && [ \$(cat '$TMP/state/quota-pause.core') -gt \$(date +%s) ]"
fresh_quota
printf '%s 0 5000 %s\n' "$(date +%s)" "$(( $(date +%s) - 10 ))" > "$TMP/state/quota"
FAKE_MODE=quota FAKE_REMAINING=4000 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1; rc=$?
check 'a passed resource reset refreshes even a recently timestamped cache' "[ $rc -eq 0 ] && grep -q 'api rate_limit' '$FAKE_LOG'"
fresh_quota
# A legacy core-only file, a different token, and a different host must each
# require fresh server evidence. None may reuse another context's headroom.
rm -f "$TMP/state/quota-context"
printf '%s 4999 5000 %s\n' "$(date +%s)" "$(( $(date +%s) + 1800 ))" > "$TMP/state/quota"
FAKE_MODE=quota FAKE_REMAINING=0 FAKE_TOKEN=token-a AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1; rc=$?
check 'old core-only state is discarded before admission' "[ $rc -eq 75 ] && grep -q 'api rate_limit' '$FAKE_LOG' && [ \$(cat '$TMP/state/quota-pause.core') -gt \$(date +%s) ]"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_TOKEN=token-a AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1
: > "$FAKE_LOG"
FAKE_MODE=quota FAKE_REMAINING=0 FAKE_TOKEN=token-b AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1; rc=$?
check 'credential switch probes instead of reusing healthy quota' "[ $rc -eq 75 ] && grep -q 'api rate_limit' '$FAKE_LOG' && ! grep -q 'api repos/o/r' '$FAKE_LOG'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_TOKEN=token-a AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1
: > "$FAKE_LOG"
FAKE_MODE=quota FAKE_REMAINING=0 FAKE_TOKEN=token-a GH_HOST=github.example AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1; rc=$?
check 'host switch probes instead of reusing healthy quota' "[ $rc -eq 75 ] && grep -q 'api rate_limit' '$FAKE_LOG' && ! grep -q 'api repos/o/r' '$FAKE_LOG'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=0 FAKE_GRAPHQL_REMAINING=4000 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" pr view 7 -R github.example/o/r >/dev/null 2>&1; rc=$?
check 'enterprise repository selector probes its own API host' "[ $rc -eq 75 ] && grep -q 'api rate_limit --hostname github.example' '$FAKE_LOG' && ! grep -q 'pr view 7' '$FAKE_LOG'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=0 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" pr view 7 -R https://github.example/o/r >/dev/null 2>&1; rc=$?
check 'unparsed repository selector remains unknown and preserves the command' "[ $rc -eq 0 ] && grep -q 'pr view 7' '$FAKE_LOG' && ! grep -q 'api rate_limit' '$FAKE_LOG'"
FAKE_MODE=quota FAKE_REMAINING=0 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" pr view 7 -R https://github.example/o/r >/dev/null 2>"$TMP/unknown-host"; rc=$?
check 'unknown host admission is visible to the caller' "[ $rc -eq 0 ] && grep -q 'quota admission unknown' '$TMP/unknown-host'"
fresh_quota
rm -f "$TMP/state/quota-context"; : > "$TMP/identity-log"
FAKE_IDENTITY_LOG="$TMP/identity-log" FAKE_TOKEN=token-unknown FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_PRINCIPAL=unknown AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1
: > "$FAKE_LOG"
FAKE_IDENTITY_LOG="$TMP/identity-log" FAKE_TOKEN=token-unknown FAKE_MODE=quota FAKE_REMAINING=0 FAKE_PRINCIPAL=unknown AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1; rc=$?
check 'unverified credential reuses only its short local direct-request snapshot' "[ $rc -eq 0 ] && ! grep -q 'api rate_limit' '$FAKE_LOG' && grep -q 'api repos/o/r' '$FAKE_LOG' && [ \$(wc -l < '$TMP/identity-log') -eq 1 ]"
: > "$FAKE_LOG"
FAKE_TOKEN=token-unknown-2 FAKE_MODE=quota FAKE_REMAINING=0 FAKE_PRINCIPAL=unknown AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1; rc=$?
check 'different unverified credential refreshes before admission' "[ $rc -eq 75 ] && grep -q 'api rate_limit' '$FAKE_LOG' && ! grep -q 'api repos/o/r' '$FAKE_LOG'"
check 'identity probe overhead is counted separately without claiming exact HTTP volume' "'$PYTHON_RUNNER' '$ROOT/tools/github-requests/report.py' '$TMP/state/measurements' | jq -e '.identity_probe_invocations >= 1 and .http_requests == null' && ! grep -R -q 55610577 '$TMP/state/measurements'"
fresh_quota
FAKE_TOKEN=ghp_PAT_A FAKE_MODE=quota FAKE_REMAINING=4000 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1
: > "$FAKE_LOG"; : > "$TMP/pat-identity-log"
FAKE_IDENTITY_LOG="$TMP/pat-identity-log" FAKE_TOKEN=ghp_PAT_B FAKE_MODE=quota FAKE_REMAINING=0 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1; rc=$?
check 'verified PATs for one principal share guarded local quota without another rate-limit probe' "[ $rc -eq 0 ] && ! grep -q 'api rate_limit' '$FAKE_LOG' && grep -q 'api repos/o/r' '$FAKE_LOG' && [ \$(wc -l < '$TMP/pat-identity-log') -eq 1 ]"
fresh_quota
FAKE_TOKEN=ghp_PAT_FAILED FAKE_IDENTITY_STATUS=1 FAKE_PRINCIPAL=55610577 FAKE_MODE=quota FAKE_REMAINING=0 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r >/dev/null 2>&1; rc=$?
check 'failed identity lookup with numeric output never verifies or shares principal quota' "[ $rc -eq 75 ] && grep -q 'api rate_limit' '$FAKE_LOG' && ! grep -q 'api repos/o/r' '$FAKE_LOG' && jq -se '[.[] | select(.operation == \"api.identity\")][-1].exit_status == 1' '$TMP/state/measurements/'*.jsonl"
fresh_quota
FAKE_MODE=graphql-200-primary AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql -f query=fixture > "$TMP/partial-primary" 2>/dev/null; rc=$?
check 'GraphQL HTTP-200 primary error preserves partial output and records its own pause' "[ $rc -eq 75 ] && jq -e '.data.viewer.login == \"partial\"' '$TMP/partial-primary' && [ \$(cat '$TMP/state/quota-pause.graphql') -gt \$(date +%s) ]"
fresh_quota
FAKE_MODE=graphql-200-secondary AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql -f query=fixture > "$TMP/partial-secondary" 2>/dev/null; rc=$?
check 'GraphQL HTTP-200 secondary error preserves partial output and uses shared backoff' "[ $rc -eq 75 ] && jq -e '.data.viewer.login == \"partial\"' '$TMP/partial-secondary' && [ \$(cat '$TMP/state/backoff_until') -gt \$(date +%s) ]"
fresh_quota
FAKE_MODE=graphql-200-partial AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql -f query=fixture > "$TMP/partial-other" 2> "$TMP/partial-other-err"; rc=$?
check 'GraphQL partial non-limit result returns failure, output, and a safe diagnostic' "[ $rc -eq 1 ] && jq -e '.errors[0].message == \"field unavailable\" and .data.viewer.login == \"partial\"' '$TMP/partial-other' && grep -q 'GraphQL response contains application errors' '$TMP/partial-other-err' && ! grep -q 'field unavailable' '$TMP/partial-other-err'"
check 'GraphQL application error adds no diagnostic quota request' "! grep -q 'api --include rate_limit' '$FAKE_LOG'"
fresh_quota
FAKE_MODE=graphql-cli-error AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql -f query=fixture > "$TMP/graphql-cli-error-out" 2> "$TMP/graphql-cli-error-err"; rc=$?
check 'failed GraphQL command keeps its original error without a shape warning' "[ $rc -eq 1 ] && [ ! -s '$TMP/graphql-cli-error-out' ] && grep -q 'temporary upstream reset' '$TMP/graphql-cli-error-err' && ! grep -q 'result unclassified' '$TMP/graphql-cli-error-err'"
fresh_quota
FAKE_MODE=graphql-unknown AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql -f query=fixture > "$TMP/unknown-graphql" 2> "$TMP/unknown-graphql-err"; rc=$?
check 'unclassifiable GraphQL result is visible and nonzero' "[ $rc -eq 1 ] && grep -q not-json '$TMP/unknown-graphql' && grep -q 'result unclassified' '$TMP/unknown-graphql-err'"
fresh_quota
FAKE_MODE=graphql-malformed-errors AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql -f query=fixture > "$TMP/malformed-graphql" 2> "$TMP/malformed-graphql-err"; rc=$?
check 'malformed GraphQL errors field fails closed without losing output' "[ $rc -eq 1 ] && jq -e '.errors.message == \"bad-shape\"' '$TMP/malformed-graphql' && grep -q 'result unclassified' '$TMP/malformed-graphql-err'"
fresh_quota
FAKE_MODE=graphql-jq-scalar AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql --jq .data.viewer.login > "$TMP/graphql-scalar" 2> "$TMP/graphql-scalar-err"; rc=$?
check 'transformed GraphQL preserves successful CLI output and warns about independent classification' "[ $rc -eq 0 ] && [ \$(cat '$TMP/graphql-scalar') = scalar ] && grep -q 'transformed GraphQL body cannot be independently classified' '$TMP/graphql-scalar-err'"
FAKE_MODE=graphql-jq-error AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql --jq .data.viewer.login > "$TMP/graphql-jq-error-out" 2> "$TMP/graphql-jq-error-err"; rc=$?
check 'transformed GraphQL preserves native CLI application-error failure' "[ $rc -eq 1 ] && jq -e '.errors[0].message == \"field unavailable\"' '$TMP/graphql-jq-error-out' && grep -q 'gh: field unavailable' '$TMP/graphql-jq-error-err'"
check 'transformed GraphQL scalar is explicitly unobservable in request report' "jq -se '[.[] | select(.operation == \"api.graphql\")][-1].request_class == \"graphql_transformed_unobservable\"' '$TMP/state/measurements/'*.jsonl && '$PYTHON_RUNNER' '$ROOT/tools/github-requests/report.py' '$TMP/state/measurements' | jq -e '.graphql_transformed_unobservable >= 1'"
check 'managed safety GraphQL callers never request transformed output' "awk '{ line=\$0; while (sub(/\\\\\$/, \"\", line) && (getline more) > 0) line=line more; if (line ~ /graphql/ && line ~ /--(jq|template|silent|include)(=|[[:space:]]|\$)/) exit 1 }' '$ROOT/bin/ai-merge-group-evidence' '$ROOT/bin/ai-pr-wait' '$ROOT/bin/ai-blocker-watch'"
fresh_quota
FAKE_MODE=graphql-jq-scalar AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api --hostname github.example graphql --jq .data.viewer.login > "$TMP/graphql-scalar-host" 2>/dev/null; rc=$?
check 'GraphQL transform after leading host flag is measured without rejecting report' "[ $rc -eq 0 ] && [ \$(cat '$TMP/graphql-scalar-host') = scalar ] && '$PYTHON_RUNNER' '$ROOT/tools/github-requests/report.py' '$TMP/state/measurements' | jq -e '.graphql_transformed_unobservable >= 2'"
fresh_quota
FAKE_MODE=graphql-jq-empty AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql --jq .data.missing > "$TMP/graphql-empty" 2>/dev/null; rc=$?
check 'valid GraphQL jq empty result keeps original success status' "[ $rc -eq 0 ] && [ ! -s '$TMP/graphql-empty' ]"
fresh_quota
FAKE_MODE=graphql-pages AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql --paginate > "$TMP/graphql-pages" 2>/dev/null; rc=$?
check 'valid paginated GraphQL objects retain success status and all output' "[ $rc -eq 0 ] && [ \$(wc -l < '$TMP/graphql-pages') -eq 2 ]"
fresh_quota
FAKE_MODE=graphql-pages-error AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql --paginate > "$TMP/graphql-pages-error" 2>/dev/null; rc=$?
check 'later GraphQL page error is classified without losing earlier output' "[ $rc -eq 75 ] && [ \$(wc -l < '$TMP/graphql-pages-error') -eq 2 ] && [ \$(cat '$TMP/state/quota-pause.graphql') -gt \$(date +%s) ]"
fresh_quota
FAKE_MODE=graphql-crash AI_GH_PROBE_TIMEOUT_SECONDS=1 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql -f query=fixture > "$TMP/graphql-slow" 2>/dev/null; rc=$?
check 'a valid slow GraphQL response outlives the quota-probe timeout' "[ $rc -eq 0 ] && jq -e '.data.viewer.login == \"FIXTURE_PRIVATE_BODY\"' '$TMP/graphql-slow'"
fresh_quota
FAKE_MODE=graphql-large AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql -f query=fixture > "$TMP/graphql-large" 2> "$TMP/graphql-large-err"; rc=$?
check 'a large GraphQL response retains its complete output' "[ $rc -eq 0 ] && jq -e '(.data.text | length) == 100000' '$TMP/graphql-large'"
if [ "$rc" -ne 0 ] || ! jq -e '(.data.text | length) == 100000' "$TMP/graphql-large" >/dev/null 2>&1; then
  printf 'large GraphQL fixture: rc=%s bytes=%s text_length=%s\n' "$rc" "$(wc -c < "$TMP/graphql-large")" "$(jq -r '.data.text | length' "$TMP/graphql-large" 2>/dev/null || printf invalid-json)" >&2
  cat "$TMP/graphql-large-err" >&2
fi
# The alternate utility must own both GraphQL streams and ordinary stderr.
TEST_REAL_TEE="$(command -v gnutee || command -v tee)"; export TEST_REAL_TEE
TEST_TEE_LOG="$TMP/tee-routing.log"; export TEST_TEE_LOG
mkdir "$TMP/tee-routing"
cat > "$TMP/tee-routing/gnutee" <<'EOF'
#!/usr/bin/env bash
printf 'gnu %s\n' "$1" >> "$TEST_TEE_LOG"
exec "$TEST_REAL_TEE" "$@"
EOF
cat > "$TMP/tee-routing/tee" <<'EOF'
#!/usr/bin/env bash
printf 'fallback %s\n' "$1" >> "$TEST_TEE_LOG"
exec "$TEST_REAL_TEE" "$@"
EOF
chmod +x "$TMP/tee-routing/gnutee" "$TMP/tee-routing/tee"
fresh_quota
FAKE_MODE=graphql-large PATH="$TMP/tee-routing:$PATH" AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql -f query=fixture > "$TMP/routed-large" 2> "$TMP/routed-err"; routed_rc=$?
FAKE_MODE=graphql-cli-error PATH="$TMP/tee-routing:$PATH" AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api repos/o/r > "$TMP/routed-ordinary" 2>/dev/null
check 'packaged GNU tee routes classifier and both stderr paths with complete output' "[ $routed_rc -eq 0 ] && jq -e '(.data.text | length) == 100000' '$TMP/routed-large' && [ \$(grep -c '^gnu ' '$TEST_TEE_LOG') -eq 3 ] && ! grep -q '^fallback ' '$TEST_TEE_LOG' && grep -q '/stream$' '$TEST_TEE_LOG'"
: > "$TEST_TEE_LOG"
command(){ if [ "${1:-}" = -v ] && [ "${2:-}" = gnutee ]; then return 1; fi; builtin command "$@"; }
export -f command
FAKE_MODE=graphql-large PATH="$TMP/tee-routing:$PATH" AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql -f query=fixture > "$TMP/fallback-large" 2> "$TMP/fallback-err"; fallback_rc=$?
export -n -f command; unset -f command
check 'hosts without packaged GNU alternate retain ordinary tee and complete classification' "[ $fallback_rc -eq 0 ] && jq -e '(.data.text | length) == 100000' '$TMP/fallback-large' && [ \$(grep -c '^fallback ' '$TEST_TEE_LOG') -eq 2 ] && ! grep -q '^gnu ' '$TEST_TEE_LOG'"
fresh_quota
FAKE_MODE=graphql-crash AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql -f query=fixture > "$TMP/crash-output" 2>/dev/null & crash_pid=$!
for _ in $(seq 1 30); do grep -q FIXTURE_PRIVATE_BODY "$TMP/crash-output" 2>/dev/null && break; sleep 0.1; done
kill -KILL "$crash_pid" 2>/dev/null; wait "$crash_pid" 2>/dev/null || true
check 'hard-killed GraphQL call leaves no response body in quota state' "! find '$TMP/state' -type f -exec grep -l FIXTURE_PRIVATE_BODY {} + | grep -q ."
fresh_quota
mkdir "$TMP/mkfifo-fail"
cat > "$TMP/mkfifo-fail/mkfifo" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TMP/mkfifo-fail/mkfifo"
FAKE_MODE=graphql-crash PATH="$TMP/mkfifo-fail:$PATH" AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api graphql -f query=fixture > "$TMP/fail-output" 2> "$TMP/fail-err"; rc=$?
check 'failed FIFO setup stops before GraphQL and never writes a raw response file' "[ $rc -eq 3 ] && [ ! -s '$TMP/fail-output' ] && grep -q 'cannot prepare private GraphQL classifier' '$TMP/fail-err' && ! grep -q 'api graphql' '$FAKE_LOG' && ! find '$TMP/state' -type f -exec grep -l FIXTURE_PRIVATE_BODY {} + | grep -q ."
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
check 'new resource discovered only after refusal supplies its own reset' "[ $rc -eq 75 ] && [ \$(cat '$TMP/state/quota-pause.future_quota') -ge $((before + 3500)) ] && [ \$(cat '$TMP/state/quota-pause.future_quota') -lt $((before + 4000)) ] && grep -q 'exhausted-resource=future_quota' '$TMP/state/refusals.log'"
fresh_quota
FAKE_MODE=quota FAKE_REMAINING=4000 FAKE_EXTRA_RESOURCE=future_quota FAKE_EXTRA_REMAINING=100 AI_GH_QUOTA_PROBE_SECONDS=300 "$GH" api --hostname github.example repos/o/r >/dev/null 2>&1; rc=$?
check 'explicit host retains a scoped new-resource snapshot' "[ $rc -eq 0 ] && grep -q ' 100 100 ' '$TMP/state/quota.future_quota' && grep -q ' github.example ' '$TMP/state/quota-context'"
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
rm -f "$TMP/state/quota" "$TMP/state/backoff_until" "$TMP/state"/quota-pause.*; echo 0 > "$TMP/state/last_call"
FAKE_MODE=quota FAKE_REMAINING=1500 AI_GH_QUOTA_PROBE_SECONDS=300 AI_GH_QUOTA_SLOW_SPACING=30 AI_GH_NO_WAIT=1 "$GH" pr view 7 >/dev/null 2>&1; rc=$?
if [ "$rc" -eq 75 ]; then
  # A newly verified identity is itself a paced GitHub read.
  echo 0 > "$TMP/state/last_call"
  FAKE_MODE=quota FAKE_REMAINING=1500 AI_GH_QUOTA_PROBE_SECONDS=300 AI_GH_QUOTA_SLOW_SPACING=30 AI_GH_NO_WAIT=1 "$GH" pr view 7 >/dev/null 2>&1; rc=$?
fi
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
AI_DEVOPS_TEST_MODE=0 "$WAIT" --until-regex x --timeout-minutes 1 --interval 60 -- run view 1 >/dev/null 2>&1; rc=$?
check 'wait refuses an interval below 300 seconds' "[ $rc -eq 3 ]"
AI_DEVOPS_TEST_MODE=0 "$WAIT" --until-regex x --interval 300 -- run view 1 >/dev/null 2>&1; rc=$?
check 'wait requires an explicit --timeout-minutes deadline' "[ $rc -eq 3 ]"
AI_DEVOPS_TEST_MODE=0 "$WAIT" --until-regex x --timeout-minutes 0 --interval 300 -- run view 1 >/dev/null 2>&1; rc=$?
check 'wait refuses a zero deadline' "[ $rc -eq 3 ]"
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
# Deadline path: pin the deadline to epoch 1 so the waiter exits 2 after one
# poll without a real 60s sleep.
AI_GH_WAIT_TEST_DEADLINE_EPOCH=1 \
  AI_DEVOPS_TEST_MODE=1 AI_GH_WAIT_TEST_MIN_INTERVAL=1 timeout 20 \
  "$WAIT" --until-regex never-matches --interval 1 --timeout-minutes 1 -- run view 1 >/dev/null 2>&1; rc=$?
check 'wait exits 2 at its deadline' "[ $rc -eq 2 ]"
AI_DEVOPS_TEST_MODE=1 AI_GH_WAIT_TEST_MIN_INTERVAL=1 timeout 20 "$WAIT" --until-regex x --timeout-minutes 1 --interval 1 -- run watch 1 >/dev/null 2>&1; rc=$?
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
AI_GH_CALLER=ai-blocker-watch AI_GH_OPERATION=bw.snapshot "$GH" api repos/o/r >/dev/null 2>&1
check 'BlockerWatch fixed operation is recorded' "jq -se '.[-1].operation == \"bw.snapshot\" and .[-1].caller == \"ai-blocker-watch\"' '$TMP/telemetry-state/measurements/'*.jsonl"
AI_GH_CALLER=ai-blocker-watch AI_GH_OPERATION='bw.snapshot\"injected' "$GH" api repos/o/r >/dev/null 2>&1
check 'untrusted BlockerWatch operation cannot enter telemetry' "jq -se '.[-1].operation == \"api.unknown\"' '$TMP/telemetry-state/measurements/'*.jsonl"
for caller in ai-merge-group-evidence ai-transcript-destination-check ai-workspace-status ai-reviewer-membership-drift; do
  AI_GH_CALLER="$caller" "$GH" api repos/o/r >/dev/null 2>&1
  check "$caller source is retained in telemetry and report" "jq -se '.[-1].caller == \"$caller\"' '$TMP/telemetry-state/measurements/'*.jsonl && '$PYTHON_RUNNER' '$ROOT/tools/github-requests/report.py' '$TMP/telemetry-state/measurements' | jq -e 'any(.sources[]; .caller == \"$caller\")'"
done
mkdir "$TMP/telemetry-state/measurements/write.lock"
FAKE_STATUS=8 "$GH" pr checks 1 > "$TMP/tout" 2> "$TMP/terr"; rc=$?
check 'telemetry failure is visible and preserves failed command status' "[ $rc -eq 8 ] && grep -q 'request measurement unavailable' '$TMP/terr' && cmp '$TMP/tout' '$TMP/expected-out'"
touch -d '5 minutes ago' "$TMP/telemetry-state/measurements/write.lock"
FAKE_STATUS=8 "$GH" pr checks 1 > "$TMP/tout" 2> "$TMP/terr"; rc=$?
check 'a lock left by a crash is cleared and measurement resumes' "[ $rc -eq 8 ] && ! grep -q 'request measurement unavailable' '$TMP/terr' && [ ! -d '$TMP/telemetry-state/measurements/write.lock' ]"
touch "$TMP/telemetry-state/measurements/2000-01-01.jsonl"
"$GH" api graphql > /dev/null 2>/dev/null
check 'telemetry retention removes only old owned date files' "[ ! -e '$TMP/telemetry-state/measurements/2000-01-01.jsonl' ] && jq -se '.[-1].bucket == \"graphql\" and .[-1].cli_executions == 1 and .[-1].principal == \"unknown\"' '$TMP/telemetry-state/measurements/'*.jsonl"
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/telemetry-state/measurements" > "$TMP/report"; rc=$?
check 'request_report_coverage_and_denominator' "[ $rc -eq 0 ] && jq -e '.records == 10 and .opaque_cli_executions == 10 and .http_requests == null and .graphql_points == null and (.acceptance | startswith(\"incomplete\")) and (.coverage_gaps | length) > 0' '$TMP/report'"
source "$ROOT/tools/github-requests/telemetry.sh"
workflow_id="$(gh_measure_workflow_id)"
access_context="v1:$(printf '%064d' 0)"
printf '%s' '{"data":{"rateLimit":{"cost":3,"remaining":4990,"resetAt":"2026-09-28T05:00:00Z"},"repository":{"private":"FIXTURE_CANARY"}}}' |
  gh_measure_graphql_cost ai-pr-wait graphql.pr_status pr_wait "$workflow_id" upstream_refresh "$access_context"
printf '%s' '{"data":{"rateLimit":{"cost":2,"remaining":4988,"resetAt":"2026-09-28T05:00:00Z"}}}' |
  gh_measure_graphql_cost ai-pr-wait graphql.pr_status pr_wait "$workflow_id" upstream_refresh "$access_context"
printf '%s' '{"data":{"rateLimit":{"cost":9}}}' |
  gh_measure_graphql_cost ai-pr-wait graphql.pr_status pr_wait "$workflow_id" cache_hit
cache_rc=$?
gh_measure_workflow_outcome ai-pr-wait pr_wait "$workflow_id" checks_failed 1234
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/telemetry-state/measurements" > "$TMP/report"; rc=$?
check 'GraphQL page costs link once to workflow and local reset headroom' \
  "[ $rc -eq 0 ] && [ $cache_rc -eq 2 ] && jq -e '.records == 10 and .identity_probe_invocations >= 0 and .observed_graphql_cost_records == 2 and .linked_graphql_points == 5 and .completed_workflow_receipts == 1 and .observed_graphql_windows_local_only == [{\"context_ordinal\":1,\"reset_at\":\"2026-09-28T05:00:00Z\",\"records\":2,\"min_remaining\":4988,\"max_remaining\":4990,\"observed_points\":5}]' '$TMP/report' && ! grep -q '$access_context' '$TMP/report' && ! grep -Rq FIXTURE_CANARY '$TMP/telemetry-state/measurements'"
mkdir -p "$TMP/evidence-state/measurements"; chmod 700 "$TMP/evidence-state/measurements"
evidence_id="$(gh_measure_workflow_id)"
AI_GH_STATE_DIR="$TMP/evidence-state" PR_WAIT_EVENT_KIND=unknown PR_WAIT_DELIVERY_BOUNDARY=unknown \
  gh_measure_workflow_evidence ai-pr-wait pr_wait "$evidence_id"
AI_GH_STATE_DIR="$TMP/evidence-state" gh_measure_workflow_outcome ai-pr-wait pr_wait "$evidence_id" checks_failed 1
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/evidence-state/measurements" > "$TMP/evidence-report"; rc=$?
check 'schema4 absent metadata remains unknown and reportable' \
  "[ $rc -eq 0 ] && jq -e '.workflow_evidence_records == 1 and .qualified_latency_ms.count == 0 and .workflow_evidence[0].unknown_reason == \"metadata_absent\"' '$TMP/evidence-report'"
# Schema4 metadata trust boundary: only the fixed, null-adapter contract is accepted.
mkdir -p "$TMP/cohort-state/measurements"; chmod 700 "$TMP/cohort-state/measurements"
printf '%s\n' '{"schema":1,"cohort_id":"0123456789abcdef0123456789abcdef","phase":"baseline","clock_status":null,"source_generation":null,"target_map":null}' > "$TMP/cohort-state/measurements/cohort.json"; chmod 600 "$TMP/cohort-state/measurements/cohort.json"
AI_GH_STATE_DIR="$TMP/cohort-state" PR_WAIT_EVENT_KIND=unknown PR_WAIT_DELIVERY_BOUNDARY=unknown gh_measure_workflow_evidence ai-pr-wait pr_wait "$(gh_measure_workflow_id)"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) cohort_predicate='.cohort_id == null and .unknown_reason == "metadata_untrusted"' ;;
  *) cohort_predicate='.cohort_id == "0123456789abcdef0123456789abcdef" and .unknown_reason == "source_unknown"' ;;
esac
check 'cohort metadata respects platform qualification and fixed null adapters' "jq -e '$cohort_predicate and .target_ordinal == null and .source_verified == \"unknown\" and .clock_quality == \"unknown\" and .latency_ms == null' '$TMP/cohort-state/measurements/'*.jsonl"
for field in clock_status source_generation target_map; do
  d="$TMP/cohort-nonnull-$field"; mkdir -p "$d/measurements"; chmod 700 "$d/measurements"
  jq --arg field "$field" '.[$field]={claimed:"verified"}' "$TMP/cohort-state/measurements/cohort.json" > "$d/measurements/cohort.json"; chmod 600 "$d/measurements/cohort.json"
  AI_GH_STATE_DIR="$d" PR_WAIT_EVENT_KIND=unknown PR_WAIT_DELIVERY_BOUNDARY=unknown gh_measure_workflow_evidence ai-pr-wait pr_wait "$(gh_measure_workflow_id)"
  check 'nonnull clock source or target adapters cannot qualify metadata' "jq -e '.cohort_id == null and .unknown_reason == \"metadata_untrusted\" and .latency_ms == null' '$d/measurements/'*.jsonl"
done
mkdir -p "$TMP/cohort-fifo/measurements"; chmod 700 "$TMP/cohort-fifo/measurements"
if mkfifo "$TMP/cohort-fifo/measurements/cohort.json" 2>/dev/null; then
  AI_GH_STATE_DIR="$TMP/cohort-fifo" timeout 5 bash -c 'source "$1"; gh_measure_read_cohort; [ "$GH_MEASURE_COHORT_REASON" = metadata_untrusted ]' bash "$ROOT/tools/github-requests/telemetry.sh"; cohort_rc=$?
  check 'FIFO cohort cannot block the original workflow' "[ '$cohort_rc' -eq 0 ]"
fi
"$PYTHON_RUNNER" - "$ROOT" "$TMP/cohort-link-representation" <<'PY'
import os, pathlib, sys, types
sys.path.insert(0, str(pathlib.Path(sys.argv[1]) / "tools/github-requests"))
import report
directory = pathlib.Path(sys.argv[2])
directory.mkdir()
# Exercise unsupported-platform semantics without changing pathlib's platform.
report.os = types.SimpleNamespace(name="nt", lstat=os.lstat)
assert report.read_cohort(directory) == {"cohort_id": None, "unknown_reason": "metadata_absent"}
(directory / "cohort.json.lnk").write_bytes(b"opaque MSYS pipe representation")
assert report.read_cohort(directory) == {"cohort_id": None, "unknown_reason": "metadata_untrusted"}
PY
cohort_link_rc=$?
check 'unsupported platform never mistakes an MSYS pipe representation for absent metadata' "[ '$cohort_link_rc' -eq 0 ]"
for bad in malformed extra mode oversize; do
  d="$TMP/cohort-$bad"; mkdir -p "$d/measurements"; chmod 700 "$d/measurements"
  case "$bad" in
    malformed) printf '%s\n' '{"schema":1,"cohort_id":"bad"}' > "$d/measurements/cohort.json" ;;
    extra) printf '%s\n' '{"schema":1,"cohort_id":"0123456789abcdef0123456789abcdef","phase":"baseline","clock_status":null,"source_generation":null,"target_map":null,"raw":"token"}' > "$d/measurements/cohort.json" ;;
    mode) printf '%s\n' '{"schema":1,"cohort_id":"0123456789abcdef0123456789abcdef","phase":"baseline","clock_status":null,"source_generation":null,"target_map":null}' > "$d/measurements/cohort.json"; chmod 644 "$d/measurements/cohort.json" ;;
    oversize) head -c 17000 /dev/zero > "$d/measurements/cohort.json" ;;
  esac
  [ "$bad" = mode ] || chmod 600 "$d/measurements/cohort.json"
  AI_GH_STATE_DIR="$d" PR_WAIT_EVENT_KIND=unknown PR_WAIT_DELIVERY_BOUNDARY=unknown gh_measure_workflow_evidence ai-pr-wait pr_wait "$(gh_measure_workflow_id)"
  check "cohort $bad is untrusted and remains unknown" "jq -e '.cohort_id == null and .unknown_reason == \"metadata_untrusted\"' '$d/measurements/'*.jsonl"
done
mkdir -p "$TMP/cohort-symlink/measurements"; chmod 700 "$TMP/cohort-symlink/measurements"
ln -s "$TMP/cohort-state/measurements/cohort.json" "$TMP/cohort-symlink/measurements/cohort.json"
AI_GH_STATE_DIR="$TMP/cohort-symlink" PR_WAIT_EVENT_KIND=unknown PR_WAIT_DELIVERY_BOUNDARY=unknown gh_measure_workflow_evidence ai-pr-wait pr_wait "$(gh_measure_workflow_id)"
check 'cohort symlink is rejected' "jq -se '.[-1].unknown_reason == \"metadata_untrusted\"' '$TMP/cohort-symlink/measurements/'*.jsonl"
# Parser adversarial matrix: malformed types, enums, opaque-label injection, duplicate and dangling joins fail closed.
mkdir -p "$TMP/evidence-invalid"
base='{"schema":4,"utc":"2026-09-28T05:00:00Z","measurement":"workflow_evidence","caller":"ai-pr-wait","workflow":"pr_wait","workflow_id":"0123456789abcdef0123456789abcdef","cohort_id":null,"target_ordinal":null,"source_verified":"unknown","source_fingerprint_start":null,"source_fingerprint_end":null,"install_generation_binding":null,"event_kind":"unknown","eligible_utc_ms":null,"observed_utc_ms":null,"delivered_utc_ms":null,"delivery_boundary":"unknown","clock_quality":"unknown","clock_error_bound_ms":null,"latency_ms":null,"unknown_reason":"metadata_absent"}'
for bad in type enum injection duplicate dangling mismatch future schema clock source event delivery latency forged duplicate_key; do
  d="$TMP/evidence-invalid/$bad"; mkdir -p "$d"; f="$d/2026-09-28.jsonl"; printf '%s\n' "$base" > "$f"
  case "$bad" in
    type) jq -c '.target_ordinal=true' "$f" > "$f.tmp" ;;
    enum) jq -c '.event_kind="bad"' "$f" > "$f.tmp" ;;
    injection) jq -c '.workflow_id="https://token"' "$f" > "$f.tmp" ;;
    duplicate) cp "$f" "$f.tmp"; cat "$f.tmp" >> "$f"; rm -f "$f.tmp"; "$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$d" >/dev/null 2>&1; rc=$?; check "schema4 $bad fixture fails closed" "[ $rc -eq 1 ]"; continue ;;
    dangling) jq -c '.workflow_id="fedcba9876543210fedcba9876543210"' "$f" > "$f.tmp" ;;
    mismatch) jq -c '.event_kind="pr_merged"|.eligible_utc_ms=1|.observed_utc_ms=2' "$f" > "$f.tmp" ;;
    future) jq -c '.source_verified="verified"|.source_fingerprint_start=("a"*64)|.source_fingerprint_end=("b"*64)|.install_generation_binding=("c"*64)' "$f" > "$f.tmp" ;;
    schema) jq -c '.schema="4"' "$f" > "$f.tmp" ;;
    clock) jq -c '.clock_quality="unknown"|.clock_error_bound_ms=1|.latency_ms=0' "$f" > "$f.tmp" ;;
    source) jq -c '.source_verified="unknown"|.source_fingerprint_start=("a"*64)' "$f" > "$f.tmp" ;;
    event) jq -c '.event_kind="pr_merged"|.eligible_utc_ms=null' "$f" > "$f.tmp" ;;
    delivery) jq -c '.delivery_boundary="terminal_report"|.delivered_utc_ms=null' "$f" > "$f.tmp" ;;
    latency) jq -c '.latency_ms=1' "$f" > "$f.tmp" ;;
    forged) jq -c '.cohort_id="0123456789abcdef0123456789abcdef"|.source_verified="verified"|.source_fingerprint_start=("a"*64)|.source_fingerprint_end=("a"*64)|.install_generation_binding=("c"*64)|.clock_quality="verified_bound"|.clock_error_bound_ms=1|.event_kind="check_completed"|.eligible_utc_ms=1000|.observed_utc_ms=2000|.delivered_utc_ms=3000|.delivery_boundary="terminal_report"|.latency_ms=2000|.unknown_reason="none"' "$f" > "$f.tmp" ;;
    duplicate_key) sed 's/"schema":4/"schema":4,"schema":4/' "$f" > "$f.tmp" ;;
  esac
  mv "$f.tmp" "$f"
  [ "$bad" = dangling ] || printf '%s\n' '{"schema":3,"utc":"2026-09-28T05:00:00Z","measurement":"workflow_outcome","caller":"ai-pr-wait","workflow":"pr_wait","workflow_id":"0123456789abcdef0123456789abcdef","outcome":"checks_failed","elapsed_ms":1}' >> "$f"
  "$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$d" > "$d/out" 2> "$d/err"; rc=$?
  check "schema4 $bad fixture fails closed" "[ $rc -eq 1 ] && [ ! -s '$d/out' ] && ! grep -q 'https://token' '$d/err'"
done
mkdir -p "$TMP/cohort-duplicate/measurements"; chmod 700 "$TMP/cohort-duplicate/measurements"
sed 's/"schema":1/"schema":1,"schema":1/' "$TMP/cohort-state/measurements/cohort.json" > "$TMP/cohort-duplicate/measurements/cohort.json"; chmod 600 "$TMP/cohort-duplicate/measurements/cohort.json"
AI_GH_STATE_DIR="$TMP/cohort-duplicate" gh_measure_read_cohort
check 'duplicate cohort keys never establish a cohort' "[ '$GH_MEASURE_COHORT_REASON' = metadata_untrusted ] && [ -z '$GH_MEASURE_COHORT_ID' ]"
if [ "$(uname -s)" = Linux ]; then
  timeout 5 "$PYTHON_RUNNER" - "$ROOT" "$TMP/cohort-race" <<'PY'
import os, pathlib, sys
sys.path.insert(0, str(pathlib.Path(sys.argv[1]) / 'tools/github-requests'))
import report
directory = pathlib.Path(sys.argv[2]); directory.mkdir(mode=0o700)
path = directory / 'cohort.json'
path.write_text('{"schema":1,"cohort_id":"0123456789abcdef0123456789abcdef","phase":"baseline","clock_status":null,"source_generation":null,"target_map":null}'); path.chmod(0o600)
original = os.open
def swap_to_fifo(name, flags, *args, **kwargs):
    if name == 'cohort.json':
        path.unlink(); os.mkfifo(path, 0o600)
    return original(name, flags, *args, **kwargs)
os.open = swap_to_fifo
assert report.read_cohort(directory) == {'cohort_id': None, 'unknown_reason': 'metadata_untrusted'}
PY
  race_rc=$?
  check 'cohort replacement with FIFO during open fails safely without blocking' "[ '$race_rc' -eq 0 ]"
fi
printf '%s' '{"data":{"rateLimit":{"cost":4,"remaining":"bad","resetAt":"FIXTURE_CANARY"}}}' |
  gh_measure_graphql_cost ai-pr-wait graphql.pr_status pr_wait '' upstream_refresh
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/telemetry-state/measurements" > "$TMP/report"; rc=$?
check 'legacy or malformed optional quota fields retain cost without false window' \
  "[ $rc -eq 0 ] && jq -e '.observed_graphql_cost_records == 3 and .observed_graphql_points == 9 and .observed_graphql_window_records == 2' '$TMP/report' && ! grep -Rq FIXTURE_CANARY '$TMP/telemetry-state/measurements'"
mkdir "$TMP/legacy-cost"
printf '%s\n' '{"schema":2,"utc":"2026-09-28T05:00:00Z","measurement":"observed_graphql_cost","caller":"ai-pr-wait","operation":"graphql.pr_status","workflow":"pr_wait","workflow_id":null,"graphql_points":7,"http_requests":null}' > "$TMP/legacy-cost/2026-09-28.jsonl"
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/legacy-cost" > "$TMP/report"; rc=$?
check 'older cost rows without quota window fields remain readable' \
  "[ $rc -eq 0 ] && jq -e '.observed_graphql_points == 7 and .observed_graphql_window_records == 0' '$TMP/report'"

# Regression: COST_SHAPES holds frozensets. A plain set never matched, so every
# newly measured schema-2 cost row was rejected and the report refused to run.
mkdir "$TMP/frozen-cost"
printf '%s\n' '{"schema":2,"utc":"2026-09-28T05:00:00Z","measurement":"observed_graphql_cost","caller":"ai-pr-wait","operation":"graphql.pr_status","workflow":"pr_wait","workflow_id":null,"access_context":null,"graphql_points":7,"graphql_remaining":4900,"graphql_reset_at":"2026-09-28T06:00:00Z","http_requests":null}' > "$TMP/frozen-cost/2026-09-28.jsonl"
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/frozen-cost" > "$TMP/report"; rc=$?
check 'new GraphQL cost rows remain reportable under exact key-set membership' \
  "[ $rc -eq 0 ] && jq -e '.observed_graphql_cost_records == 1 and .observed_graphql_points == 7 and .observed_graphql_window_records == 0 and .unattributed_graphql_window_records == 1' '$TMP/report'"
printf '%s' '{"data":{"rateLimit":{"cost":1,"remaining":4900,"resetAt":"2026-09-28T05:00:00Z"}}}' |
  AI_GH_STATE_DIR="$TMP/unattributed-state" gh_measure_graphql_cost ai-pr-wait graphql.pr_status pr_wait '' upstream_refresh 'ghp_FIXTURE_CANARY'
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/unattributed-state/measurements" > "$TMP/report"; rc=$?
check 'unverified access stays unattributed and no token enters telemetry or report' \
  "[ $rc -eq 0 ] && jq -e '.observed_graphql_window_records == 0 and .unattributed_graphql_window_records == 1 and .observed_graphql_windows_local_only == []' '$TMP/report' && ! grep -Rq FIXTURE_CANARY '$TMP/unattributed-state/measurements' && ! grep -q FIXTURE_CANARY '$TMP/report'"
bw_id="$(gh_measure_workflow_id)"
printf '%s' '{"data":{"rateLimit":{"cost":4,"remaining":4800,"resetAt":"2026-09-28T05:00:00Z"}}}' |
  AI_GH_STATE_DIR="$TMP/bw-cost-state" gh_measure_graphql_cost ai-blocker-watch graphql.open_issue_snapshot blocker_watch_tick "$bw_id" direct "$access_context"
AI_GH_STATE_DIR="$TMP/bw-cost-state" gh_measure_workflow_outcome ai-blocker-watch blocker_watch_tick "$bw_id" completed 1000
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/bw-cost-state/measurements" > "$TMP/report"; rc=$?
check 'BlockerWatch tick receipt links a direct snapshot cost' \
  "[ $rc -eq 0 ] && jq -e '.linked_graphql_points == 4 and .completed_workflow_receipts == 1 and .workflow_outcomes[0].workflow == \"blocker_watch_tick\"' '$TMP/report'"
printf '%s' '{"data":{"rateLimit":{"cost":2,"remaining":4798,"resetAt":"2026-09-28T05:00:00Z"}},"errors":[{"message":"fixture failure"}]}' |
  AI_GH_STATE_DIR="$TMP/bw-cost-state" gh_measure_graphql_cost ai-blocker-watch graphql.open_issue_snapshot blocker_watch_alarm '' direct "$access_context"
printf '%s' '{"data":{"rateLimit":{"cost":1,"remaining":4797,"resetAt":"2026-09-28T05:00:00Z"}}}' |
  AI_GH_STATE_DIR="$TMP/bw-cost-state" gh_measure_graphql_cost ai-blocker-watch graphql.open_issue_snapshot blocker_watch_links '' direct "$access_context"
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/bw-cost-state/measurements" > "$TMP/report"; rc=$?
check 'standalone BlockerWatch reads remain separate from tick outcomes, including charged error responses' \
  "[ $rc -eq 0 ] && jq -e '.observed_graphql_points == 7 and .linked_graphql_points == 4 and (.observed_graphql_cost_sources | any(.workflow == \"blocker_watch_alarm\" and .points == 2)) and (.observed_graphql_cost_sources | any(.workflow == \"blocker_watch_links\" and .points == 1))' '$TMP/report'"
mkdir "$TMP/cost-only" "$TMP/outcome-only"
printf '%s\n' '{"schema":2,"utc":"2020-01-01T00:00:00Z","measurement":"observed_graphql_cost","caller":"ai-pr-wait","operation":"graphql.pr_status","workflow":"pr_wait","workflow_id":null,"graphql_points":7,"http_requests":null}' > "$TMP/cost-only/2020-01-01.jsonl"
printf '%s\n' '{"schema":3,"utc":"2021-01-01T00:00:00Z","measurement":"workflow_outcome","caller":"ai-pr-wait","workflow":"pr_wait","workflow_id":"0123456789abcdef0123456789abcdef","outcome":"checks_failed","elapsed_ms":1}' > "$TMP/outcome-only/2021-01-01.jsonl"
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/cost-only" > "$TMP/cost-report"; cost_rc=$?
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/outcome-only" > "$TMP/outcome-report"; outcome_rc=$?
check 'cost-only and outcome-only reports retain their measurement time bounds' \
  "[ $cost_rc -eq 0 ] && [ $outcome_rc -eq 0 ] && jq -e '.first_utc == \"2020-01-01T00:00:00Z\" and .last_utc == .first_utc' '$TMP/cost-report' && jq -e '.first_utc == \"2021-01-01T00:00:00Z\" and .last_utc == .first_utc' '$TMP/outcome-report'"
jq -c '.access_context="FIXTURE_CANARY"' "$TMP/legacy-cost/2026-09-28.jsonl" > "$TMP/legacy-cost/2026-09-27.jsonl"
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/legacy-cost" > "$TMP/report" 2> "$TMP/report-error"; rc=$?
check 'report rejects a non-opaque context without exposing it' \
  "[ $rc -eq 1 ] && [ ! -s '$TMP/report' ] && ! grep -q FIXTURE_CANARY '$TMP/report-error'"
mkdir "$TMP/report-compat"
head -n 1 "$TMP/telemetry-state/measurements/$(date -u +%F).jsonl" > "$TMP/report-compat/$(date -u +%F).jsonl"
for sample in "$TMP/state/measurements/"*.jsonl; do jq -c 'select(.operation == "api.identity")' "$sample" >> "$TMP/report-compat/$(date -u +%F).jsonl"; done
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/report-compat" > "$TMP/report"; rc=$?
check 'report accepts legacy samples alongside identity invocation estimates' "[ $rc -eq 0 ] && jq -e '.records >= 2 and .identity_probe_invocations >= 1 and .http_requests == null' '$TMP/report'"
printf '{"operation":"FIXTURE_CANARY"}\n' > "$TMP/telemetry-state/measurements/2001-01-01.jsonl"
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/telemetry-state/measurements" > "$TMP/report" 2> "$TMP/report-error"; rc=$?
check 'request report rejects untrusted labels without reflecting them' "[ $rc -eq 1 ] && [ ! -s '$TMP/report' ] && ! grep -q FIXTURE_CANARY '$TMP/report-error'"

# Reject malformed JSON shapes through the same fixed diagnostic, never a
# traceback or a reflected input value. Keep a valid row before the bad one
# to prove the report cannot publish a partial aggregate on later corruption.
mkdir "$TMP/report-shapes"
head -n 1 "$TMP/telemetry-state/measurements/$(date -u +%F).jsonl" > "$TMP/report-valid"
mkdir "$TMP/report-callers"
for caller in ai-merge-group-evidence ai-transcript-destination-check ai-workspace-status ai-reviewer-membership-drift ai-devops-doctor ai-devops-installer; do
  jq -c --arg caller "$caller" '.caller=$caller' "$TMP/report-valid" > "$TMP/report-callers/2001-01-01.jsonl"
  "$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/report-callers" > "$TMP/report-caller-out" 2> "$TMP/report-caller-err"; rc=$?
  check "the $caller report label remains accepted and scrubbed" "[ $rc -eq 0 ] && jq -e --arg caller '$caller' '.sources[0].caller == \$caller' '$TMP/report-caller-out' && [ ! -s '$TMP/report-caller-err' ]"
done
"$PYTHON_RUNNER" -c 'print("request report: invalid or unavailable measurement input; no report produced")' > "$TMP/report-expected-error"
for shape in '[]' '["FIXTURE_CANARY"]' 'null' 'true' '1' '"FIXTURE_CANARY"' \
  '{"operation":[]}' '{"operation":{}}' '{"operation":true}' \
  '{"operation":"api.graphql","caller":[]}' '{"operation":"api.graphql","caller":{}}'; do
  cat "$TMP/report-valid" > "$TMP/report-shapes/2001-01-01.jsonl"
  printf '%s\n' "$shape" >> "$TMP/report-shapes/2001-01-01.jsonl"
  "$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/report-shapes" > "$TMP/report" 2> "$TMP/report-error"; rc=$?
  check 'request report rejects nonobject or wrong-type label without partial output' "[ $rc -eq 1 ] && [ ! -s '$TMP/report' ] && cmp '$TMP/report-error' '$TMP/report-expected-error'"
done
for mutation in '.schema=true' '.schema="1"' 'del(.http_requests)' 'del(.graphql_points)' '.utc=[]' '.latency_ms=true' '.operation="api.identity"' '.request_class="identity_probe"' '.measurement="direct_api_invocation_estimate"'; do
  jq -c "$mutation" "$TMP/report-valid" > "$TMP/report-shapes/2001-01-01.jsonl"
  "$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/report-shapes" > "$TMP/report" 2> "$TMP/report-error"; rc=$?
  check 'request report rejects invalid required field shapes' "[ $rc -eq 1 ] && [ ! -s '$TMP/report' ] && cmp '$TMP/report-error' '$TMP/report-expected-error'"
done
jq -sc '[.[] | select(.operation == "api.identity")][0]' "$TMP/state/measurements/"*.jsonl > "$TMP/report-identity-valid"
for mutation in '.cli_executions=0' '.latency_ms=0'; do
  jq -c "$mutation" "$TMP/report-identity-valid" > "$TMP/report-shapes/2001-01-01.jsonl"
  "$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/report-shapes" > "$TMP/report" 2> "$TMP/report-error"; rc=$?
  check 'request report rejects impossible identity probe counts' "[ $rc -eq 1 ] && [ ! -s '$TMP/report' ] && cmp '$TMP/report-error' '$TMP/report-expected-error'"
done
"$PYTHON_RUNNER" -c 'print("[" * 2000 + "\"FIXTURE_CANARY\"" + "]" * 2000)' > "$TMP/report-shapes/2001-01-01.jsonl"
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/report-shapes" > "$TMP/report" 2> "$TMP/report-error"; rc=$?
check 'request report rejects excessive JSON nesting with controlled diagnostic' "[ $rc -eq 1 ] && [ ! -s '$TMP/report' ] && cmp '$TMP/report-error' '$TMP/report-expected-error'"

# Reject every non-regular path before opening it; a FIFO must never hold up
# the original operation or the offline reader. Directories exercise this on
# Windows too, where the filesystem may not implement mkfifo.
export AI_GH_STATE_DIR="$TMP/special-state"
mkdir -p "$AI_GH_STATE_DIR/measurements/$(date -u +%F).jsonl"
FAKE_STATUS=8 timeout 15 "$GH" pr checks 1 > "$TMP/special-out" 2> "$TMP/special-err"; rc=$?
check 'telemetry rejects non-regular daily paths without changing status' "[ $rc -eq 8 ] && grep -q 'request measurement unavailable' '$TMP/special-err' && [ ! -d '$AI_GH_STATE_DIR/measurements/write.lock' ]"
timeout 15 "$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$AI_GH_STATE_DIR/measurements" > "$TMP/report" 2> "$TMP/report-error"; rc=$?
check 'report rejects non-regular daily paths before opening' "[ $rc -eq 1 ] && [ ! -s '$TMP/report' ]"
rmdir "$AI_GH_STATE_DIR/measurements/$(date -u +%F).jsonl"
if mkfifo "$AI_GH_STATE_DIR/measurements/$(date -u +%F).jsonl" 2>/dev/null; then
  FAKE_STATUS=8 timeout 15 "$GH" pr checks 1 > "$TMP/special-out" 2> "$TMP/special-err"; rc=$?
  check 'FIFO telemetry path cannot block a failed command' "[ $rc -eq 8 ] && grep -q 'request measurement unavailable' '$TMP/special-err'"
  timeout 15 "$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$AI_GH_STATE_DIR/measurements" > "$TMP/report" 2> "$TMP/report-error"; rc=$?
  check 'FIFO report input is rejected without waiting for a writer' "[ $rc -eq 1 ] && [ ! -s '$TMP/report' ]"
else
  printf '  skip FIFO cases: filesystem does not support named pipes (directory cases passed above)\n'
fi
mkdir "$AI_GH_STATE_DIR/quota-observation.json"
source "$ROOT/tools/github-requests/telemetry.sh"
for caller in ai-merge-group-evidence ai-transcript-destination-check ai-workspace-status ai-reviewer-membership-drift ai-devops-doctor ai-devops-installer; do
  AI_GH_CALLER="$caller" gh_measure_init api graphql
  check "the $caller transport keeps its fixed telemetry label" "[ '$GH_MEASURE_CALLER' = '$caller' ]"
done
AI_GH_CALLER=ai-devops-doctor gh_measure_init auth status
check 'networked authentication probe has a fixed operation label' "[ '$GH_MEASURE_OPERATION' = auth.status ]"
AI_GH_CALLER=$'ai-workspace-status\nprivate' gh_measure_init api graphql
check 'an injected caller label remains unknown and cannot enter telemetry' "[ '$GH_MEASURE_CALLER' = unknown ]"
STATE="$AI_GH_STATE_DIR"
gh_measure_quota 1 2 3 4 5 6 7 8 9 >/dev/null 2>&1; rc=$?
check 'quota observation rejects non-regular destination too' "[ $rc -eq 1 ] && [ -d '$AI_GH_STATE_DIR/quota-observation.json' ] && [ \$(find '$AI_GH_STATE_DIR' -maxdepth 1 -name 'quota-observation.*' -type f | wc -l) -eq 0 ]"

STATE="$TMP/named-row-state"; mkdir -p "$STATE"
gh_measure_quota_rows $'future_resource\t9\t10\t30\nsearch\t7\t30\t40\ncore\t80\t100\t50\ngraphql\t61\t200\t60'
check 'named quota telemetry ignores row order and extra resource names' "jq -e '.buckets.core.remaining == 80 and .buckets.graphql.remaining == 61 and .buckets.search.remaining == 7 and (.buckets|keys|length) == 3' '$STATE/quota-observation.json'"
gh_measure_quota_rows $'graphql\t61\t200\t60' 'ghp_FIXTURE_CANARY'
check 'malformed access context cannot enter a quota snapshot' "jq -e '.access_context == null' '$STATE/quota-observation.json' && ! grep -R -q 'FIXTURE_CANARY' '$STATE/quota-measurements'"
gh_measure_quota_rows $'core\tbad\t100\t50\nsearch\t7\t30\t40\textra'
check 'missing malformed and overlong quota rows remain unknown' "jq -e '.buckets.core == null and .buckets.graphql == null and .buckets.search == null' '$STATE/quota-observation.json'"

for operation in bw.snapshot bw.alarm_issue bw.link_issue; do
  AI_GH_STATE_DIR="$TMP/operation-label-state" AI_GH_CALLER=ai-blocker-watch AI_GH_OPERATION="$operation" \
    AI_GH_REAL_GH="$FAKE" FAKE_MODE=graphql-pages "$GH" api graphql > "$TMP/operation-output" 2> "$TMP/operation-error"; operation_rc=$?
  check "GraphQL retains the $operation caller operation and output" "[ $operation_rc -eq 0 ] && [ \$(wc -l < '$TMP/operation-output') -eq 2 ] && jq -se '.[-1].operation == \"$operation\" and .[-1].caller == \"ai-blocker-watch\" and .[-1].bucket == \"graphql\"' '$TMP/operation-label-state/measurements/'*.jsonl && '$PYTHON_RUNNER' '$ROOT/tools/github-requests/report.py' '$TMP/operation-label-state/measurements' >/dev/null"
done
AI_GH_STATE_DIR="$TMP/operation-label-state" AI_GH_CALLER=ai-blocker-watch AI_GH_OPERATION=bw.snapshot \
  AI_GH_REAL_GH="$FAKE" FAKE_MODE=graphql-jq-scalar "$GH" api graphql --jq '.data.viewer.login' >/dev/null 2>&1; operation_rc=$?
check 'transformed GraphQL retains the snapshot operation and classification' "[ $operation_rc -eq 0 ] && jq -se '.[-1].operation == \"bw.snapshot\" and .[-1].request_class == \"graphql_transformed_unobservable\" and .[-1].bucket == \"graphql\"' '$TMP/operation-label-state/measurements/'*.jsonl && '$PYTHON_RUNNER' '$ROOT/tools/github-requests/report.py' '$TMP/operation-label-state/measurements' | jq -e '.graphql_transformed_unobservable == 1'"
mkdir "$TMP/operation-invalid-report"
for mutation in '.caller = "interactive"' '.bucket = "unknown"'; do
  jq -s ".[ -1 ] | $mutation" "$TMP/operation-label-state/measurements/"*.jsonl > "$TMP/operation-invalid-report/$(date -u +%F).jsonl"
  "$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$TMP/operation-invalid-report" >/dev/null 2>&1; operation_rc=$?
  check "transformed caller label rejects invalid metadata: $mutation" "[ $operation_rc -eq 1 ]"
done
source "$ROOT/tools/github-requests/telemetry.sh"
for fixture in '123.45' '0.00' '9999999999.99'; do
  gh_measure_local_clock_parse "$fixture"
  check "local_clock_valid_$fixture" "[ '$GH_MEASURE_LOCAL_CLOCK_BASIS' = linux_boottime_centiseconds ] && [ '$GH_MEASURE_LOCAL_CLOCK_MS' -ge 0 ]"
done
for fixture in '' '1' '1.2' '1.234' '-1.00' '10000000000.00' '1.00x'; do
  gh_measure_local_clock_parse "$fixture"
  check "local_clock_invalid_unknown_${fixture:-empty}" "[ '$GH_MEASURE_LOCAL_CLOCK_BASIS' = unknown ] && [ -z '$GH_MEASURE_LOCAL_CLOCK_MS' ]"
done
local_state="$TMP/local-duration-state"; mkdir -p "$local_state/measurements"; chmod 700 "$local_state/measurements"
local_id=0123456789abcdef0123456789abcdef
AI_GH_STATE_DIR="$local_state" gh_measure_workflow_outcome ai-pr-wait pr_wait "$local_id" checks_failed 100
AI_GH_STATE_DIR="$local_state" gh_measure_local_observation "$local_id" checks_failed 1000 2100 linux_boottime_centiseconds 0
"$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$local_state/measurements" > "$TMP/local-report"; rc=$?
check 'local observation joins one schema-3 receipt and stays unqualified' \
  "[ '$rc' -eq 0 ] && jq -e '.local_workflow_observations.count == 1 and .local_workflow_observations.reason_counts[0].unknown_reason == \"source_unknown\" and .qualified_latency_ms.count == 0' '$TMP/local-report'"
for bad in duplicate dangling mismatch forged extra bool missing repeated-key interval partial basis; do
  d="$TMP/local-invalid-$bad"; mkdir -p "$d"; f="$d/2026-10-08.jsonl"
  receipt='{"schema":3,"utc":"2026-10-08T00:00:00Z","measurement":"workflow_outcome","caller":"ai-pr-wait","workflow":"pr_wait","workflow_id":"0123456789abcdef0123456789abcdef","outcome":"checks_failed","elapsed_ms":100}'
  observation='{"schema":5,"utc":"2026-10-08T00:00:00Z","measurement":"local_workflow_observation","caller":"ai-pr-wait","workflow":"pr_wait","workflow_id":"0123456789abcdef0123456789abcdef","outcome":"checks_failed","boundary":"receipt_init_to_terminal_output","clock_basis":"linux_boottime_centiseconds","start_monotonic_ms":1000,"end_monotonic_ms":1100,"duration_lower_ms":80,"duration_upper_ms":120,"clock_error_bound_ms":20,"source_verified":"unknown","acceptance":"unknown","unknown_reason":"source_unknown"}'
  printf '%s\n' "$receipt" > "$f"
  case "$bad" in
    duplicate) printf '%s\n%s\n' "$observation" "$observation" >> "$f" ;;
    dangling) jq -c '.workflow_id="fedcba9876543210fedcba9876543210"' <<<"$observation" >> "$f" ;;
    mismatch) jq -c '.outcome="merged"' <<<"$observation" >> "$f" ;;
    forged) jq -c '.source_verified="verified"' <<<"$observation" >> "$f" ;;
    extra) jq -c '.extra="x"' <<<"$observation" >> "$f" ;;
    bool) jq -c '.start_monotonic_ms=true' <<<"$observation" >> "$f" ;;
    missing) jq -c 'del(.boundary)' <<<"$observation" >> "$f" ;;
    repeated-key) printf '%s\n' "${observation/\"schema\":5/\"schema\":5,\"schema\":5}" >> "$f" ;;
    interval) jq -c '.duration_upper_ms=121' <<<"$observation" >> "$f" ;;
    partial) jq -c '.end_monotonic_ms=null' <<<"$observation" >> "$f" ;;
    basis) jq -c '.clock_basis="unknown"' <<<"$observation" >> "$f" ;;
  esac
  "$PYTHON_RUNNER" "$ROOT/tools/github-requests/report.py" "$d" >/dev/null 2>&1; rc=$?
  check "local_observation_${bad}_rejected" "[ '$rc' -eq 1 ]"
done
for fixture in '2100 1000 linux_boottime_centiseconds 0 clock_negative' '0 604800001 linux_boottime_centiseconds 0 clock_negative' '1000 2100 unknown 0 clock_unknown' '1000 2100 linux_boottime_centiseconds 1 delivery_unknown' '0000 0008 linux_boottime_centiseconds 0 clock_unknown'; do
  read -r start end basis failed reason <<<"$fixture"
  state="$TMP/local-unknown-$reason-$start-$end"; mkdir -p "$state/measurements"; chmod 700 "$state/measurements"
  AI_GH_STATE_DIR="$state" gh_measure_local_observation "$local_id" checks_failed "$start" "$end" "$basis" "$failed"
  check "local_duration_unknown_$reason" "jq -se '.[0].unknown_reason == \"$reason\" and .[0].start_monotonic_ms == null and .[0].duration_upper_ms == null' '$state/measurements/'*.jsonl"
done
(
  GH_MEASURE_LOCAL_PLATFORM_INITIALIZED=0
  uname(){ printf '%s\n' unsupported; }
  gh_measure_local_clock
  [ "$GH_MEASURE_LOCAL_CLOCK_BASIS" = unknown ] && [ -z "$GH_MEASURE_LOCAL_CLOCK_MS" ]
)
unsupported_rc=$?
check 'local_clock_unsupported_unknown' "[ '$unsupported_rc' -eq 0 ]"
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
