# windows-gate-env.sh — BASH_ENV for StepFun Windows OpenCode turns.
#
# OpenCode spawns the real Git bash.exe (pinned via OPENCODE_GIT_BASH_PATH,
# because the closed gate PATH carries no git and no spawnable shim) and
# passes each model command as a non-interactive `bash -c`, which sources
# this file. The DEBUG trap fires before the first simple command executes
# and execs the gate directly in its `gate -c INNER` form (Layer 0), so no
# model command ever runs outside the gate.
#
# The audit write before the exec is load-bearing, not decoration: under
# OpenCode's pseudo-console an immediate exec from the trap deadlocks the
# shell (observed live: bash stuck thread-waiting on the console before any
# child exists), while a write first completes (#1343). It also records
# every gated command to $AI_STEPFUN_GATE_LOG (per-run, deleted with the
# turn's home).
#
# The gate itself sets AI_STEPFUN_SHELL_GATE=1 and clears BASH_ENV before
# exec'ing an already hash-verified runner, which both stops this file from
# re-arming inside the gate (recursion) and keeps the allowlisted
# `bash <script>` runner from being re-gated.

if [ "${AI_STEPFUN_SHELL_GATE:-}" = "1" ]; then
  return 0 2>/dev/null || true
fi
# Fail closed on misconfiguration: without a gate to exec into, the shell
# must die rather than let the command run ungated (an unset-variable
# expansion error alone does not stop a bash -c mid-BASH_ENV).
if [ -z "${AI_STEPFUN_GATE_BIN:-}" ]; then
  printf 'windows-gate-env: AI_STEPFUN_GATE_BIN unset; refusing to run ungated\n' >&2
  exit 77
fi
__stepfun_gate_run(){
  [ -z "${AI_STEPFUN_GATE_LOG:-}" ] || \
    printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$BASH_COMMAND" \
      >> "$AI_STEPFUN_GATE_LOG" 2>/dev/null || true
  unset BASH_ENV
  exec "$AI_STEPFUN_GATE_BIN" -c "$BASH_COMMAND"
}
trap '__stepfun_gate_run' DEBUG
