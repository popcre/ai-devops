#!/usr/bin/env bash
# Fast filesystem-admission cases. Simulate access denial because Windows and
# root-run CI cannot reliably express it with chmod; all store contents are real.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source <(sed -n '/^linked_below_home(){/,/^}/p' "$ROOT/bin/ai-muse")
source <(sed -n '/^muse_code_delete_session(){/,/^}/p' "$ROOT/bin/ai-muse")
TMP="$(mktemp -d "${TMPDIR:-/tmp}/muse-delete-unit.XXXXXX")"
trap 'rm -rf -- "$TMP"' EXIT
PROFILE_HOME="$TMP/home"
XDG_DATA_HOME="$PROFILE_HOME/.local/share/ai-devops/muse-code"
root="$XDG_DATA_HOME/muse/sessions"
sid=12345678-1234-4234-8234-123456789abc
mkdir -p "$root/.msp-view-v1/$sid" "$root/2026/09/19/$sid"
printf keep > "$root/.msp-view-v1/$sid/HEAD.json"
printf keep > "$root/2026/09/19/$sid/session.jsonl"
denied=""
# Emulate the OS behavior: a denied parent fails access checks and existence
# probes through it return false. Other predicates retain their real behavior.
[(){
  if [[ -n "$denied" ]]; then
    if [[ ( "${1:-}" == -r || "${1:-}" == -x ) && "${2:-}" == "$denied" ]]; then return 1; fi
    if [[ "${1:-}" == -e && "${2:-}" == "$denied/"* ]]; then return 1; fi
  fi
  builtin [ "$@"
}
for denied in "$XDG_DATA_HOME" "$XDG_DATA_HOME/muse" . ./2026 ./2026/09 ./2026/09/19 ./.msp-view-v1; do
  if muse_code_delete_session "$sid" > "$TMP/refusal" 2>&1; then
    printf 'FAIL: access denial was accepted: %s\n' "$denied"; exit 1
  fi
  grep -q 'store deletion unconfirmed' "$TMP/refusal"
  builtin [ -f "$root/.msp-view-v1/$sid/HEAD.json" ]
  builtin [ -f "$root/2026/09/19/$sid/session.jsonl" ]
done
denied=""
if muse_code_delete_session ../escape > "$TMP/refusal" 2>&1; then
  printf 'FAIL: non-UUID deletion was accepted\n'; exit 1
fi
[[ -f "$root/.msp-view-v1/$sid/HEAD.json" && -f "$root/2026/09/19/$sid/session.jsonl" ]]
# A UUID parked as a regular file must be refused at preflight for EITHER store
# while its sibling store survives untouched.
rm -f -- "$root/.msp-view-v1/$sid/HEAD.json"; rmdir -- "$root/.msp-view-v1/$sid"
printf file > "$root/.msp-view-v1/$sid"
if muse_code_delete_session "$sid" > "$TMP/refusal" 2>&1; then
  printf 'FAIL: projection file UUID deletion was accepted\n'; exit 1
fi
grep -q 'projection store deletion unconfirmed' "$TMP/refusal"
builtin [ -f "$root/2026/09/19/$sid/session.jsonl" ]
rm -f -- "$root/.msp-view-v1/$sid"; mkdir -p -- "$root/.msp-view-v1/$sid"
printf keep > "$root/.msp-view-v1/$sid/HEAD.json"
rm -f -- "$root/2026/09/19/$sid/session.jsonl"; rmdir -- "$root/2026/09/19/$sid"
printf file > "$root/2026/09/19/$sid"
if muse_code_delete_session "$sid" > "$TMP/refusal" 2>&1; then
  printf 'FAIL: durable file UUID deletion was accepted\n'; exit 1
fi
grep -q 'durable store deletion unconfirmed' "$TMP/refusal"
builtin [ -f "$root/.msp-view-v1/$sid/HEAD.json" ]
rm -f -- "$root/2026/09/19/$sid"; mkdir -p -- "$root/2026/09/19/$sid"
printf keep > "$root/2026/09/19/$sid/session.jsonl"
muse_code_delete_session "$sid"
[[ ! -e "$root/.msp-view-v1/$sid" && ! -e "$root/2026/09/19/$sid" ]]
printf 'Muse deletion admission: 11 passed, 0 failed, 0 skipped\n'
