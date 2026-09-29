#!/usr/bin/env bash
# ai-merge-queue-drift suite (issue #1002 step 3). Offline: every ruleset is
# a fixture, no network, and bin/ai-gh is never invoked.
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

# The real repository itself must be clean offline (workflow + selection).
out="$("$DRIFT" --root "$ROOT" --offline 2>&1)"; rc=$?
[ $rc -eq 0 ] && result pass 'the real repository passes the offline checks' \
  || { result fail 'the real repository passes the offline checks'; printf '%s\n' "$out" | sed -n '1,12p' | sed 's/^/      /' >&2; }

printf 'ai-merge-queue-drift: %s pass, %s fail\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
