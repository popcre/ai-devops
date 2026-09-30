#!/usr/bin/env bash
# ai-merge-queue-drift suite (issue #1002 step 3). Offline: every ruleset is
# a fixture, no network, and bin/ai-gh appears only as a per-case stub.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRIFT="$ROOT/bin/ai-merge-queue-drift"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PASS=0; FAIL=0
result(){
  if [ "$1" = pass ]; then PASS=$((PASS + 1)); printf '  ok   %s\n' "$2"
  else FAIL=$((FAIL + 1)); printf '  FAIL %s\n' "$2" >&2; fi
}

[ -x "$DRIFT" ] && result pass 'ai-merge-queue-drift is committed executable' || result fail 'ai-merge-queue-drift is committed executable'
[ -f "$ROOT/bin/ai-merge-queue-drift.cmd" ] && result pass 'ai-merge-queue-drift carries a Windows .cmd launcher' || result fail 'ai-merge-queue-drift carries a Windows .cmd launcher'
bash -n "$DRIFT" && result pass 'ai-merge-queue-drift passes bash -n' || result fail 'ai-merge-queue-drift passes bash -n'
if "$DRIFT" --bogus >/dev/null 2>&1; then result fail 'unknown argument is refused'; else result pass 'unknown argument is refused'; fi

PYTHON=""
for candidate in python3 python; do
  if "$candidate" -c 'import sys' >/dev/null 2>&1; then PYTHON="$candidate"; break; fi
done
[ -n "$PYTHON" ] || { printf '  FAIL no python interpreter for the selector fixture\n' >&2; exit 1; }

# The fixture ruleset: the live ruleset 21564317 as fetched 2026-09-28.
cat > "$TMP/ruleset-live.json" <<'EOF'
{
  "id": 21564317,
  "name": "main: pull request + merge queue",
  "source": "popcre/ai-devops",
  "enforcement": "active",
  "conditions": { "ref_name": { "exclude": [], "include": ["~DEFAULT_BRANCH"] } },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    { "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "required_reviewers": [],
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["squash"]
      } },
    { "type": "merge_queue",
      "parameters": {
        "merge_method": "SQUASH",
        "max_entries_to_build": 5,
        "min_entries_to_merge": 1,
        "max_entries_to_merge": 5,
        "min_entries_to_merge_wait_minutes": 0,
        "grouping_strategy": "ALLGREEN",
        "check_response_timeout_minutes": 120
      } },
    { "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": false,
        "required_status_checks": [ { "context": "verification-closure" } ]
      } }
  ]
}
EOF
# A drifted ruleset: one merge-queue parameter moved on GitHub without a PR.
sed 's/"check_response_timeout_minutes": 120/"check_response_timeout_minutes": 30/' "$TMP/ruleset-live.json" > "$TMP/ruleset-drifted.json"

# make_fixture NAME -> a minimal checkout tree with the real snapshot,
# selector, and workflow (or modified variants per case).
make_fixture(){
  local name="$1"; local f="$TMP/$name"
  mkdir -p "$f/config" "$f/bin" "$f/.github/workflows" "$f/tests"
  cp "$ROOT/config/merge-queue-expected.json" "$f/config/"
  cp "$ROOT/tests/lib-selection.sh" "$f/tests/"
  cp "$ROOT/.github/workflows/verify.yml" "$f/.github/workflows/"
  printf '#!/usr/bin/env bash\n' > "$f/bin/ai-gh"; chmod +x "$f/bin/ai-gh"
  local s
  for s in test-a-suite.sh test-workflow-policy.sh test-windows-scripts.sh test-z-suite.sh; do
    printf '#!/usr/bin/env bash\ntrue\n' > "$f/tests/$s"
  done
  printf '%s\n' "$f"
}

# Case 4 (run first as the baseline): the current tree passes cleanly.
f_clean="$(make_fixture clean)"
out="$("$DRIFT" --root "$f_clean" --ruleset "$TMP/ruleset-live.json" 2>&1)"; rc=$?
[ $rc -eq 0 ] && grep -q 'no drift' <<<"$out" \
  && result pass 'a clean fixture tree reports no drift' \
  || result fail 'a clean fixture tree reports no drift'

# Case A1: a ruleset parameter changed live without a PR.
out="$("$DRIFT" --root "$f_clean" --ruleset "$TMP/ruleset-drifted.json" 2>&1)"; rc=$?
[ $rc -eq 1 ] && grep -q 'check_response_timeout_minutes' <<<"$out" \
  && result pass 'a changed live merge-queue parameter is reported as drift' \
  || result fail 'a changed live merge-queue parameter is reported as drift'

# Case 1: the required job was renamed in the workflow.
f_renamed="$(make_fixture renamed)"
sed -i 's/^  verification-closure:/  verification-closure-renamed:/' "$f_renamed/.github/workflows/verify.yml"
out="$("$DRIFT" --root "$f_renamed" --ruleset "$TMP/ruleset-live.json" 2>&1)"; rc=$?
[ $rc -eq 1 ] && grep -q "job 'verification-closure' is missing" <<<"$out" \
  && result pass 'a renamed required job is reported as drift' \
  || result fail 'a renamed required job is reported as drift'

# Case 1b: the required job's if: mentions merge_group only to exclude it.
f_excl="$(make_fixture excludes)"
awk '{ print } /^  verification-closure:$/ { print "    if: github.event_name != '"'"'merge_group'"'"'" }' \
  "$ROOT/.github/workflows/verify.yml" > "$f_excl/.github/workflows/verify.yml.new"
python3 - "$f_excl/.github/workflows/verify.yml.new" "$f_excl/.github/workflows/verify.yml" <<'PY2'
import sys, re
t = open(sys.argv[1]).read().split('\n')
out, in_job, seen = [], False, False
for line in t:
    if line == '  verification-closure:':
        in_job = True; out.append(line); continue
    if in_job and re.match(r'^  [A-Za-z0-9_-]+:$', line):
        in_job = False
    if in_job and line.startswith('    if:'):
        if seen: continue
        seen = True
    out.append(line)
open(sys.argv[2], 'w').write('\n'.join(out))
PY2
out="$("$DRIFT" --root "$f_excl" --ruleset "$TMP/ruleset-live.json" 2>&1)"; rc=$?
[ $rc -eq 1 ] && grep -q 'excludes merge_group' <<<"$out" \
  && result pass 'an if: that excludes merge_group is reported as drift' \
  || result fail 'an if: that excludes merge_group is reported as drift'

# Case 1d: merge_group appears only as an unrelated string; nothing selects it.
f_str="$(make_fixture onlystring)"
python3 - "$ROOT/.github/workflows/verify.yml" "$f_str/.github/workflows/verify.yml" <<'PY2'
import sys
t = open(sys.argv[1]).read()
old = """    if: >-
      always() && !cancelled() &&
      (github.event_name == 'pull_request' || github.event_name == 'merge_group')"""
assert old in t, 'verify.yml verification-closure if: changed; update this fixture'
t = t.replace(old, """    if: github.event_name == 'pull_request' || format('{0}', 'merge_group') == 'x'""", 1)
open(sys.argv[2], 'w').write(t)
PY2
out="$("$DRIFT" --root "$f_str" --ruleset "$TMP/ruleset-live.json" 2>&1)"; rc=$?
[ $rc -eq 1 ] && grep -q 'does not explicitly select it' <<<"$out" \
  && result pass 'an if: that only mentions merge_group as a string is reported as drift' \
  || result fail 'an if: that only mentions merge_group as a string is reported as drift'

# Case 1e: merge_group is selected but an extra && term makes it unproducible.
f_false="$(make_fixture andfalse)"
python3 - "$ROOT/.github/workflows/verify.yml" "$f_false/.github/workflows/verify.yml" <<'PY2'
import sys
t = open(sys.argv[1]).read()
old = """    if: >-
      always() && !cancelled() &&
      (github.event_name == 'pull_request' || github.event_name == 'merge_group')"""
assert old in t, 'verify.yml verification-closure if: changed; update this fixture'
open(sys.argv[2], 'w').write(t.replace(old, "    if: github.event_name == 'merge_group' && false", 1))
PY2
out="$("$DRIFT" --root "$f_false" --ruleset "$TMP/ruleset-live.json" 2>&1)"; rc=$?
[ $rc -eq 1 ] && grep -q 'does not explicitly select it' <<<"$out" \
  && result pass 'an if: with an extra && term is reported as drift' \
  || result fail 'an if: with an extra && term is reported as drift'

# Case 1c: the required job reports under a different display name.
f_disp="$(make_fixture display)"
awk '{ print } /^  verification-closure:$/ { print "    name: Verification closure" }' \
  "$ROOT/.github/workflows/verify.yml" > "$f_disp/.github/workflows/verify.yml"
out="$("$DRIFT" --root "$f_disp" --ruleset "$TMP/ruleset-live.json" 2>&1)"; rc=$?
[ $rc -eq 1 ] && grep -q "reports as 'Verification closure'" <<<"$out" \
  && result pass 'a required job with a different display name is reported as drift' \
  || result fail 'a required job with a different display name is reported as drift'

# Case 2: the producing workflow grows a paths filter (the trigger can skip).
f_paths="$(make_fixture paths)"
awk '{ print } /^  pull_request:/ { print "    paths:"; print "      - bin/**" }' \
  "$ROOT/.github/workflows/verify.yml" > "$f_paths/.github/workflows/verify.yml"
out="$("$DRIFT" --root "$f_paths" --ruleset "$TMP/ruleset-live.json" 2>&1)"; rc=$?
[ $rc -eq 1 ] && grep -q 'carries a paths filter' <<<"$out" \
  && result pass 'a required job behind a paths filter is reported as drift' \
  || result fail 'a required job behind a paths filter is reported as drift'

# Case 3: .ps1 selection diverges from the merge queue (the #913 shape): the
# PR selector drops the ASCII guard while the queue still runs it.
f_ps1="$(make_fixture ps1div)"
"$PYTHON" - "$ROOT/tests/lib-selection.sh" "$f_ps1/tests/lib-selection.sh" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
text = open(src, encoding='utf-8').read()
old = """      *.ps1)
        # Windows PowerShell has its own runner, but this Bash suite checks
        # every tracked .ps1 for the ASCII-only source contract. A narrowed
        # PR must catch that failure before its full merge-group run.
        add_suite "test-windows-scripts.sh"
        continue
        ;;"""
new = """      *.ps1)
        # seeded divergence: PowerShell selects nothing in PR mode
        continue
        ;;"""
assert old in text, 'selector shape changed; update this fixture'
open(dst, 'w', encoding='utf-8', newline='').write(text.replace(old, new))
PY
out="$("$DRIFT" --root "$f_ps1" --ruleset "$TMP/ruleset-live.json" 2>&1)"; rc=$?
[ $rc -eq 1 ] && grep -qF "file class .ps1 ('scripts/example.ps1'): PR selection dropped" <<<"$out" \
  && result pass 'a .ps1 selection divergence is reported as drift' \
  || result fail 'a .ps1 selection divergence is reported as drift'

# --- The live lane itself (#1026 item 4) --------------------------------------
# The live-ruleset job's run: script is extracted from the workflow so the
# lane's own branching is executed, not just the bin tool's.

lane_yml="$ROOT/.github/workflows/merge-queue-drift.yml"
lane_txt="$(tr -d '\r' < "$lane_yml")"
grep -q 'GH_TOKEN: ${{ secrets.RUNNER_POOL_READ_TOKEN || github.token }}' <<<"$lane_txt" &&
  ! grep -q 'MERGE_QUEUE_DRIFT_TOKEN' <<<"$lane_txt" &&
  result pass 'the live lane reads through the existing scoped RUNNER_POOL_READ_TOKEN (no new credential)' ||
  result fail 'the live lane reads through the existing scoped RUNNER_POOL_READ_TOKEN (no new credential)'
grep -q "^    if: github.event_name != 'pull_request' && vars.MERGE_QUEUE_DRIFT_LIVE == 'enabled'$" <<<"$lane_txt" &&
  result pass 'pull requests stay offline and the lane is gated on MERGE_QUEUE_DRIFT_LIVE' ||
  result fail 'pull requests stay offline and the lane is gated on MERGE_QUEUE_DRIFT_LIVE'

# Extract the live-ruleset job's run: block (content indented 10 or more
# spaces under `        run: |`, between the `live-ruleset:` job key and the
# next 2-space job key).
live_run_script(){
  awk '
    { sub(/\r$/, "") }
    $0 ~ /^  live-ruleset:$/ { in_job=1; next }
    in_job && /^  [A-Za-z0-9_-]+:$/ { exit }
    in_job && /^        run: \|$/ { in_run=1; next }
    in_run && /^ {10}/ { print substr($0, 11); next }
    in_run && /^$/ { print ""; next }
    in_run { exit }
  ' "$lane_yml"
}

# A stub ai-gh whose answers are steered by environment knobs, so the lane's
# HTTP-404 logic runs offline: STUB_RULESET_OK/STUB_RULESET_FILE (the single
# ruleset read), STUB_RUNNERS_OK (the administration probe),
# STUB_LIST_OK/STUB_LIST_IDS (the ruleset list, already post-jq).
make_live_fixture(){
  local name="$1"; local f
  f="$(make_fixture "$name")"
  cp "$ROOT/bin/ai-merge-queue-drift" "$f/bin/"
  chmod +x "$f/bin/ai-merge-queue-drift"
  live_run_script > "$f/live-run.sh"
  cat > "$f/bin/ai-gh" <<'STUB'
#!/usr/bin/env bash
endpoint=""
for a in "$@"; do
  case "$a" in repos/*) endpoint="$a" ;; esac
done
case "$endpoint" in
  */actions/runners*)
    if [ "${STUB_RUNNERS_OK:-0}" = 1 ]; then
      printf '{"total_count":0,"runners":[]}\n'
      exit 0
    fi
    printf 'gh: Not Found (HTTP 404)\n' >&2
    exit 1
    ;;
  */rulesets[?]per_page=*)
    if [ "${STUB_LIST_OK:-0}" = 1 ]; then
      printf '%s\n' ${STUB_LIST_IDS:-}
      exit 0
    fi
    printf 'gh: Not Found (HTTP 404)\n' >&2
    exit 1
    ;;
  */rulesets/*)
    if [ "${STUB_RULESET_OK:-0}" = 1 ]; then
      cat "${STUB_RULESET_FILE:?}"
      exit 0
    fi
    printf 'gh: Not Found (HTTP 404)\n' >&2
    exit 1
    ;;
esac
printf 'ai-gh stub: unexpected endpoint: %s\n' "$endpoint" >&2
exit 1
STUB
  chmod +x "$f/bin/ai-gh"
  printf '%s\n' "$f"
}
run_live_lane(){ # run_live_fixture NAME -> runs its extracted lane script in place
  ( cd "$1" && GITHUB_OUTPUT="$1/outcome-$2.txt" bash live-run.sh 2>&1 ); return $?
}

f_live="$(make_live_fixture live)"

# Case L1 (the #1026 hardening): a mis-scoped token answers 404 on the
# ruleset read AND fails the administration probe; that must be booked
# refused (say-once degraded), never "the ruleset no longer exists" drift.
out="$(run_live_lane "$f_live" l1)"; rc=$?
[ $rc -eq 0 ] && grep -q 'outcome=refused' "$f_live/outcome-l1.txt" &&
  ! grep -q '^outcome=drift' "$f_live/outcome-l1.txt" &&
  ! grep -q 'no longer exists' <<<"$out" &&
  result pass 'a mis-scoped 404 token is booked refused, not deletion drift' ||
  result fail 'a mis-scoped 404 token is booked refused, not deletion drift'

# Case L1b (the exact #1026 hole): a token WITHOUT administration gets a
# readable ruleset list that still lacks the id. The pre-hardening lane
# booked that as deletion drift and re-commented daily; the administration
# probe must refuse it instead.
out="$(STUB_RUNNERS_OK=0 STUB_LIST_OK=1 STUB_LIST_IDS="111 222" run_live_lane "$f_live" l1b)"; rc=$?
[ $rc -eq 0 ] && grep -q 'outcome=refused' "$f_live/outcome-l1b.txt" &&
  ! grep -q 'no longer exists' <<<"$out" &&
  result pass 'a readable list without administration read is refused, not drift' ||
  result fail 'a readable list without administration read is refused, not drift'

# Case L2: an administration-authorized token with a readable ruleset list
# that lacks the id: that is genuine deletion drift.
out="$(STUB_RUNNERS_OK=1 STUB_LIST_OK=1 STUB_LIST_IDS="111 222" run_live_lane "$f_live" l2)"; rc=$?
[ $rc -eq 1 ] && grep -q '^outcome=drift' "$f_live/outcome-l2.txt" &&
  grep -q 'no longer exists' <<<"$out" &&
  result pass 'an authorized 404 with the id missing from the list is deletion drift' ||
  result fail 'an authorized 404 with the id missing from the list is deletion drift'

# Case L2b: a readable EMPTY list also proves deletion (pre-#1026 behavior).
out="$(STUB_RUNNERS_OK=1 STUB_LIST_OK=1 STUB_LIST_IDS="" run_live_lane "$f_live" l2b)"; rc=$?
[ $rc -eq 1 ] && grep -q '^outcome=drift' "$f_live/outcome-l2b.txt" &&
  grep -q 'no longer exists' <<<"$out" &&
  result pass 'a readable empty ruleset list still proves deletion' ||
  result fail 'a readable empty ruleset list still proves deletion'

# Case L3: the read succeeds and the ruleset matches: outcome=ok.
out="$(STUB_RULESET_OK=1 STUB_RULESET_FILE="$TMP/ruleset-live.json" run_live_lane "$f_live" l3)"; rc=$?
[ $rc -eq 0 ] && grep -q 'outcome=ok' "$f_live/outcome-l3.txt" &&
  result pass 'a clean live ruleset read reports ok' ||
  result fail 'a clean live ruleset read reports ok'

# Case L4: the read succeeds but the live ruleset drifted: outcome=drift.
out="$(STUB_RULESET_OK=1 STUB_RULESET_FILE="$TMP/ruleset-drifted.json" run_live_lane "$f_live" l4)"; rc=$?
[ $rc -eq 1 ] && grep -q '^outcome=drift' "$f_live/outcome-l4.txt" &&
  grep -q 'check_response_timeout_minutes' <<<"$out" &&
  result pass 'a readable drifted ruleset is reported as drift by the lane' ||
  result fail 'a readable drifted ruleset is reported as drift by the lane'

# The real repository itself must be clean offline (workflow + selection).
out="$("$DRIFT" --root "$ROOT" --offline 2>&1)"; rc=$?
[ $rc -eq 0 ] && result pass 'the real repository passes the offline checks' \
  || { result fail 'the real repository passes the offline checks'; printf '%s\n' "$out" | sed -n '1,12p' | sed 's/^/      /' >&2; }

printf 'ai-merge-queue-drift: %s pass, %s fail\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
