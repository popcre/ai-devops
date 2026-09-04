#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/bin"
LOG="$TMP/gh.log"

cat >"$TMP/bin/gh" <<'GH'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$GH_LOG"
case "$*" in
  'api repos/acme/tool/commits/main --jq .sha') printf '%s\n' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;
  'api repos/acme/tool/git/ref/tags/ai-verify-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa --jq .object.sha') printf '%s\n' aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;
  *'run list'*'--event workflow_dispatch'*) printf '%s' "${FAKE_ACTIVE:-}" ;;
  *'run view 42'*'--json event,workflowName'*) printf '%s\n' $'workflow_dispatch\tverify' ;;
  *'run view 42'*) printf '%s\n' $'42\tworkflow_dispatch\tin_progress\taaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\t2026-09-03T00:00:00Z\thttps://example/run/42' ;;
  *'run view 99'*'--json event,workflowName'*) printf '%s\n' $'pull_request\tverify' ;;
esac
GH
chmod +x "$TMP/bin/gh"
export PATH="$TMP/bin:$PATH" GH_LOG="$LOG"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }

if "$ROOT/bin/ai-verify-run" start --repo acme/tool --ref main --task t >/dev/null 2>&1; then
  fail 'start accepted missing purpose'
fi
if timeout 2 "$ROOT/bin/ai-verify-run" start --repo >/dev/null 2>&1; then
  fail 'start accepted a missing option value'
fi

: >"$LOG"
export FAKE_ACTIVE=$'42\tin_progress\thttps://example/run/42'
if "$ROOT/bin/ai-verify-run" start --repo acme/tool --ref main --task issue-246 --purpose safety >/dev/null 2>&1; then
  fail 'start accepted an active exact-SHA duplicate'
fi
grep -q 'workflow run' "$LOG" && fail 'safe refusal dispatched a workflow'

: >"$LOG"
unset FAKE_ACTIVE
"$ROOT/bin/ai-verify-run" start --repo acme/tool --ref main --task issue-246 --purpose safety >/dev/null || fail 'safe start failed'
grep -Fq 'workflow run verify.yml --repo acme/tool --ref ai-verify-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa -f requester_task=issue-246 -f purpose=safety' "$LOG" || fail 'start was not pinned to immutable SHA provenance'
grep -q 'run cancel' "$LOG" && fail 'start cancelled a run'

: >"$LOG"
if "$ROOT/bin/ai-verify-run" cancel --repo acme/tool --run-id 42 --reason obsolete >/dev/null 2>&1; then
  fail 'cancel accepted missing destructive confirmation'
fi
grep -q 'run cancel' "$LOG" && fail 'unconfirmed cancel reached GitHub'

if "$ROOT/bin/ai-verify-run" cancel --repo acme/tool --run-id 99 --reason typo --confirm-discard-running-proof >/dev/null 2>&1; then
  fail 'cancel accepted a non-manual run'
fi
grep -Fq 'run cancel 99' "$LOG" && fail 'non-manual run reached cancellation'

"$ROOT/bin/ai-verify-run" cancel --repo acme/tool --run-id 42 --reason obsolete --confirm-discard-running-proof >/dev/null 2>&1 || fail 'confirmed exact cancel failed'
grep -Fq 'run view 42 --repo acme/tool' "$LOG" || fail 'cancel did not inspect the exact target'
grep -Fq 'run cancel 42 --repo acme/tool' "$LOG" || fail 'confirmed cancel did not target the exact run'

printf 'PASS: safe start never cancels, active duplicates are refused, provenance is sent, and cancellation needs exact destructive confirmation\n'
