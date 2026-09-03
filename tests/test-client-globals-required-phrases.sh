#!/usr/bin/env bash
#
# The full client-autonomy-guardrail check (tests/test-context-audit.ps1) is
# PowerShell, so it only runs in the Windows CI lanes — a 75-90 minute round
# trip that is not a required check on main. A prose edit to either global
# (templates/system/CLAUDE-global.md, templates/system/AGENTS-global-codex.md)
# that drops or line-wraps one of these load-bearing phrases sat on main for
# about a day undetected because of that gap (#209, 2026-09-03: a rewrap
# broke the check twice in a row, costing two full qualification runs).
#
# This is a cheap, deliberately narrow duplicate of that one check, kept in
# the required linux-offline lane so the same regression fails in minutes
# instead of an hour and a half. It does not replace the full PowerShell
# suite, which still exercises the audit tool's actual behaviour.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_GLOBAL="$REPO_ROOT/templates/system/CLAUDE-global.md"
CODEX_GLOBAL="$REPO_ROOT/templates/system/AGENTS-global-codex.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

required_phrases=(
  "Start immediately"
  "No approval loops"
  "recover first and finish"
  "Preserve the capability"
  "reported problem is gone"
  "original capability still works"
  "present symptom suppression as a fix"
  "Do not load unrelated handoffs"
)

for client_file in "$CLAUDE_GLOBAL" "$CODEX_GLOBAL"; do
  [[ -f "$client_file" ]] || fail "missing global file: $client_file"
  for phrase in "${required_phrases[@]}"; do
    grep -qzF "$phrase" "$client_file" \
      || fail "$(basename "$client_file") lost or line-wrapped the autonomy rule: $phrase"
  done
done

echo "PASS: Claude and Codex globals carry the required autonomy phrases, unwrapped"
