# windows-gate-env.sh — BASH_ENV for StepFun Windows OpenCode turns.
#
# OpenCode spawns the real Git bash.exe (pinned via OPENCODE_GIT_BASH_PATH,
# because the closed gate PATH carries no git and no spawnable shim) and
# passes each model command as a non-interactive `bash -c`, which sources
# this file. The DEBUG trap fires before the first simple command executes
# and execs the gate directly in its `gate -c INNER` form (Layer 0), so no
# model command ever runs outside the gate.
#
# The gate itself sets AI_STEPFUN_SHELL_GATE=1 and clears BASH_ENV before
# exec'ing an already hash-verified runner, which both stops this file from
# re-arming inside the gate (recursion) and keeps the allowlisted
# `bash <script>` runner from being re-gated.

if [ "${AI_STEPFUN_SHELL_GATE:-}" = "1" ]; then
  return 0 2>/dev/null || true
fi
trap 'unset BASH_ENV; exec "$AI_STEPFUN_GATE_BIN" -c "$BASH_COMMAND"' DEBUG
