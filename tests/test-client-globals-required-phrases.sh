#!/usr/bin/env bash
# Disposable #2022 CI failure/repair probe; never merge this branch.
#
# The full client-autonomy-guardrail check (tests/test-context-audit.ps1) is
# PowerShell, so it only runs in the Windows CI lanes — a 75-90 minute round
# trip that is not a required check on main. A prose edit to any global
# (templates/system/CLAUDE-global.md, templates/system/AGENTS-global-codex.md,
# templates/system/AGENTS-global-zcode.md, templates/system/AGENTS-global-mimo.md)
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
ZCODE_GLOBAL="$REPO_ROOT/templates/system/AGENTS-global-zcode.md"
MIMO_GLOBAL="$REPO_ROOT/templates/system/AGENTS-global-mimo.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

required_phrases=(
  "Complete the authorized scope"
  "Completing one child or phase is never a reason to stop"
  "Start immediately"
  "Never ask a human to approve"
  "recover first and finish"
  "Preserve the capability"
  "reported problem is gone"
  "original capability still works"
  "present symptom suppression as a fix"
  "Do not load unrelated handoffs"
  "resume that agent immediately"
  "quote Albert's exact words"
  "no human approval is ever requested"
  "AI review is advice"
  "never blocks"
  "Live proof is required before an outcome is closed"
  "One issue per application need"
  "Quote every time in EST"
)

for client_file in "$CLAUDE_GLOBAL" "$CODEX_GLOBAL" "$ZCODE_GLOBAL" "$MIMO_GLOBAL"; do
  [[ -f "$client_file" ]] || fail "missing global file: $client_file"
  for phrase in "${required_phrases[@]}"; do
    grep -qzF "$phrase" "$client_file" \
      || fail "$(basename "$client_file") lost or line-wrapped the autonomy rule: $phrase"
  done
  ! grep -qiEz 'first[[:space:]]+unticked[[:space:]]+child.{0,80}do[[:space:]]+only[[:space:]]+that[[:space:]]+one|one[[:space:]]+unproven[[:space:]]+live-behavior[[:space:]]+outcome[[:space:]]+per[[:space:]]+session' "$client_file" \
    || fail "$(basename "$client_file") restored a revoked automatic child-stop rule"
  # The canonical home since the 2026-09-18 transfer (#634): no client global
  # may keep teaching the pre-transfer slug as where structure work is authored.
  grep -qF 'popcre/shared-db' "$client_file" \
    || fail "$(basename "$client_file") no longer names popcre/shared-db as the canonical home"
  ! grep -qF 'u2giants/shared-db' "$client_file" \
    || fail "$(basename "$client_file") still routes live prose to u2giants/shared-db"
done

# The bounded public Entire trial policy must match across all four client
# globals. Compare extracted blocks to Claude's block without duplicating the
# prose here; semantic guards protect the repository, deadlines, privacy, checks
# and fallback contract. Normalize CRLF only in the extracted comparison copy.
trial_tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/ai-devops-entire-trial.XXXXXX")"
trap 'rm -rf -- "$trial_tmpdir"' EXIT
trial_reference="$trial_tmpdir/reference"
trial_actual="$trial_tmpdir/actual"
trial_have_reference=false
extract_trial_block() {
  local client_file="$1" output_file="$2"
  tr -d '\r' < "$client_file" | awk '
    $0 == "## Public Entire trial instructions (#2022)" {
      starts++
      if (starts != 1 || active) invalid = 1
      active = 1
    }
    active { print }
    active && $0 == "deadline at runtime." {
      ends++
      active = 0
    }
    END {
      if (starts != 1 || ends != 1 || active || invalid) exit 1
    }
  ' > "$output_file" \
    || fail "$(basename "$client_file") must contain exactly one complete Entire trial policy block"
}

for client_file in "$CLAUDE_GLOBAL" "$CODEX_GLOBAL" "$ZCODE_GLOBAL" "$MIMO_GLOBAL"; do
  extract_trial_block "$client_file" "$trial_actual"
  if ! $trial_have_reference; then
    cp "$trial_actual" "$trial_reference"
    trial_have_reference=true
  elif ! cmp -s "$trial_reference" "$trial_actual"; then
    fail "$(basename "$client_file") Entire trial policy differs from the Claude policy block"
  fi
  for phrase in \
    'public `popcre/ai-devops` tasks' \
    'Before each trial activity, check the current' \
    'docs/entire-trial.md' \
    'GitHub is' \
    'authoritative for source, checks and delivery' \
    'exact GitHub head' \
    'corresponding existing Entire Trail' \
    'sanitized continuity on the task' \
    'If Entire is unavailable, missing or stale' \
    'disclose it as unverified' \
    'continue through GitHub' \
    'Keep private capture off' \
    'Never enable session hooks' \
    'import private context' \
    'paid Agents' \
    'change billing,' \
    'integrations or required checks' \
    'November 12, 2026, 5:58 AM EST (America/New_York)' \
    'The discovery deadline remains November 2,' \
    '2026, 5:00 PM EST.' \
    'After the stop time, use GitHub only' \
    'disposition on #2022' \
    'do not enforce the' \
    'deadline at runtime.'; do
    grep -qF "$phrase" "$trial_actual" \
      || fail "$(basename "$client_file") Entire trial policy lost required phrase: $phrase"
  done
done

# Each global lists the valid task-gate classes; the list must match
# config/task-gates.json change_classes exactly so it cannot go stale (#1881).
expected_classes="$(jq -r '.change_classes|keys[]' "$REPO_ROOT/config/task-gates.json" | tr -d '\r' | sort | tr '\n' ' ')"
for client_file in "$CLAUDE_GLOBAL" "$CODEX_GLOBAL" "$ZCODE_GLOBAL" "$MIMO_GLOBAL"; do
  listed_classes="$(tr -d '\r' < "$client_file" | tr '\n' ' '  | grep -oP 'Classes: \K[^.]*' | head -n1 \
    | sed 's/([^)]*)//g' | tr ',' '\n' | tr -d ' ' | grep -v '^$' | sort | tr '\n' ' ')"
  [[ "$listed_classes" == "$expected_classes" ]] \
    || fail "$(basename "$client_file") task-gate class list '$listed_classes' does not match config/task-gates.json '$expected_classes'"
done

# Owner ruling 2026-09-28 ("never ask a human to approve"): the repository
# guide, the secrets skill, and the details doc must not return to asking Albert
# to approve. Owner ruling 2026-10-29 (#2041/#2072): review is advice only, so
# no reviewer-approval gate may come back either.
AGENTS_MD="$REPO_ROOT/AGENTS.md"
SECRETS_SKILL="$REPO_ROOT/skills/shared/secrets-to-1password/SKILL.md"
DETAILS="$REPO_ROOT/docs/standing-rules-details.md"
grep -qF "AI review is advice only" "$AGENTS_MD" \
  || fail "AGENTS.md lost the advisory-review rule"
! grep -qF "without Albert naming" "$AGENTS_MD" \
  || fail "AGENTS.md returned to requiring Albert to name production actions"
grep -qF "record a rotation plan on the tracking issue" "$SECRETS_SKILL" \
  || fail "secrets-to-1password lost the recorded rotation plan"
! grep -qF "without Albert's approval" "$SECRETS_SKILL" \
  || fail "secrets-to-1password returned to requiring Albert's approval"
grep -qF "hetzner_vps" "$SECRETS_SKILL" || fail "secrets-to-1password lost the standing no-rotation exception"
grep -qF "supersedes every reviewer-approval rule" "$DETAILS" \
  || fail "standing-rules-details lost the 2026-10-29 advisory-review ruling"

for never_ask in \
  "$REPO_ROOT/skills/claude/new-app-setup/NEW-PROJECT-STANDARD.md" \
  "$REPO_ROOT/skills/claude/new-app-setup/SKILL.md" \
  "$REPO_ROOT/skills/shared/designflow-human-qa/SKILL.md" \
  "$REPO_ROOT/docs/deployment.md" \
  "$REPO_ROOT/skills/shared/designflow-human-qa/references/safety-and-evidence.md" \
  "$REPO_ROOT/skills/codex/codex-shared-db-change/SKILL.md" \
  "$REPO_ROOT/skills/shared/secrets-to-1password/SKILL.md" \
  "$REPO_ROOT"/plan_muse-opencode-harness.md "$REPO_ROOT"/plan_kimi-windows-execution-reliability.md \
  "$REPO_ROOT"/plan_kimi-review-failure-recovery.md "$REPO_ROOT"/templates/repo-docs/AGENTS.addon.md \
  "$REPO_ROOT"/plan_ai-devops-work-claims.md "$REPO_ROOT"/plan_grok_integration-review-access.md \
  "$REPO_ROOT"/docs/transcript-leak-audit-2026-07-19.md "$REPO_ROOT"/skills/claude/sync-dotfiles/SKILL.md \
  "$REPO_ROOT"/templates/repo-docs/docs-ai-branching.md "$REPO_ROOT"/plan_cross_repo_routing_and_gate_enforcement.md \
  "$REPO_ROOT"/docs/shared-db-structural-safety/references/operating-manual.md \
  "$REPO_ROOT"/skills/shared/handoff-writer/SKILL.md "$REPO_ROOT"/templates/system/handoff-standard.md \
  "$REPO_ROOT"/skills/codex/codex-sync-dotfiles/SKILL.md "$REPO_ROOT"/docs/shared-db-structural-safety/README.md \
  "$REPO_ROOT"/plan_ast-grep-multi-machine-management.md "$REPO_ROOT"/plan_shared-db-finish-first-delivery.md \
  "$REPO_ROOT"/plan_shared-db-complete-throughput-repair.md "$REPO_ROOT"/plan_ai-muse-native-engine-parity.md \
  "$CLAUDE_GLOBAL" "$CODEX_GLOBAL" "$ZCODE_GLOBAL" "$MIMO_GLOBAL" "$AGENTS_MD"; do
  ! tr -d '\r' < "$never_ask" | tr '\n' ' ' | tr -s ' ' | grep -qiP "(?<!never )(?<!not )(asks? Albert to approve|asking Albert to approve)|needs a human ruling|WHOLE list to (him|the owner)|material scope/authority decisions|(?<!never )(?<!not )(ask (me|Albert) to approve|asking Albert to approve|ask (me|Albert)( once)? for|ask Albert(\.| to run)|asking Albert to run)|stop and ask Albert|ask for one\.|Please provide as many|Albert's current-chat (authorization|response)|decided by Albert|current-chat (ruling|resource|authority)|to Albert once|Owner authorization is consumed|If Albert's authority is required|needs an owner decision|specifically authorized request|stops for Albert|explicit owner approval|separate explicit authorization gate|Present Albert|Albert names the exact|current-chat authorization|owner authorization required|Albert's explicit repository|let him choose|is his call|specific approved action|required owner authorization|stops for an owner decision|must tell Albert immediately|needs Albert's action|is Albert's decision|Albert's explicit decision|Albert (must )?explicitly authoriz|Albert decides it|ask Albert (once|whether)|asks Albert once|Albert explicitly clears|Albert must explicitly|tell Albert the token|let Albert decide|offer to register|explicit human approval|do not need Albert unless|Albert (explicitly )?approves|Albert's (explicit )?approval for|needs Albert's approval|once he says yes|Albert authorization|without Albert naming|wait for a quick approval|when he must run" \
    || fail "$(basename "$never_ask") returned to asking Albert for access or approval"
done

for addon in "$REPO_ROOT/templates/repo-docs/AGENTS.addon.md" "$REPO_ROOT/templates/repo-docs/docs-ai-branching.md"; do
  grep -qF "AI review is advice only" "$addon" || fail "$(basename "$addon") lost the advisory-review rule"
done

for client_file in "$CLAUDE_GLOBAL" "$CODEX_GLOBAL" "$ZCODE_GLOBAL" "$MIMO_GLOBAL"; do
  ! grep -qiEz "assigned[[:space:]]+AI[[:space:]]+reviewer|exact-head[[:space:]]+APPROVE|reviewer-rotation-rules" "$client_file" \
    || fail "$(basename "$client_file") brought back a reviewer gate (owner ruling 2026-10-29)"
done

for sync_skill in "$REPO_ROOT/skills/claude/sync-dotfiles/SKILL.md" "$REPO_ROOT/skills/codex/codex-sync-dotfiles/SKILL.md"; do
  grep -qF "chmod 600" "$sync_skill" && grep -qF "Set-AiDevOpsPrivateFileAtomic" "$sync_skill" \
    || fail "$(basename "$(dirname "$sync_skill")") lost the private-file rule for the token file"
done

echo "PASS: Claude, Codex, ZCode, and MiMo globals carry the required autonomy phrases, unwrapped"
