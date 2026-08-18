#!/usr/bin/env bash
# Offline regression test for tools/skill-trigger-eval/codex-trigger-eval.py.
# Calls no model: it asserts the two hard invocation rules and the trigger
# detection that a real 2026-08-12 run proved was broken.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$ROOT/tools/skill-trigger-eval/codex-trigger-eval.py"

fail() { echo "FAIL: $*" >&2; exit 1; }

command -v python >/dev/null 2>&1 || { echo "SKIP: python not on PATH"; exit 0; }

python - "$RUNNER" <<'PY' || exit 1
import importlib.util, json, sys
from pathlib import Path

spec = importlib.util.spec_from_file_location("cte", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

def fail(msg):
    print(f"FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)

# Rule 1: reasoning effort is always explicit, and only low or medium.
for effort in ("low", "medium"):
    argv = m.build_command("q", effort)
    if f"model_reasoning_effort={effort}" not in argv:
        fail(f"{effort} effort is not passed on the command line")
for bad in ("high", "none", "minimal", ""):
    try:
        m.build_command("q", bad)
    except ValueError:
        pass
    else:
        fail(f"effort {bad!r} was accepted; the standing rule caps GPT-5.6 at low/medium")

# Rule 2: the sandbox is read-only, passed as a flag, not a -c key.
argv = m.build_command("q", "low")
if argv[argv.index("--sandbox") + 1] != "read-only":
    fail("the run is not pinned to a read-only sandbox")

# Detection: Codex reports the command it ran inside a JSON string, so a real
# Windows path arrives with doubled backslashes. Matching the raw line scored
# 0/1 on a query where Codex had visibly opened the skill.
installed = Path(r"C:\Users\ahazan2\.codex\skills\qwen-code\SKILL.md")
line = json.dumps({"type": "item.completed", "item": {
    "type": "command_execution",
    "command": r'pwsh -Command "Get-Content -Raw '
               r"'C:\\Users\\ahazan2\\.codex\\skills\\qwen-code\\SKILL.md'\"",
}})
if not m._mentions_skill(line, "qwen-code", installed):
    fail("a JSON-escaped Windows path to the installed SKILL.md is not detected")

if m._mentions_skill(json.dumps({"item": {"type": "command_execution",
                                          "command": "git status"}}),
                     "qwen-code", installed):
    fail("an unrelated command counted as a trigger")

# Contamination: several files in THIS repo contain the installed skill path,
# including this test. A run that merely printed one of them must not score.
noise = json.dumps({"type": "item.completed", "item": {
    "type": "command_execution",
    "command": "pwsh -Command \"Get-Content -Raw 'tests/test-codex-trigger-eval.sh'\"",
    "aggregated_output": r"installed = Path(r'C:\Users\ahazan2\.codex\skills"
                         r"\qwen-code\SKILL.md')",
}})
if m._mentions_skill(noise, "qwen-code", installed):
    fail("the skill path appearing in command OUTPUT counted as a trigger")

# A protected/missing executable is an excluded run, never a crash or a clean miss.
original_run = m.subprocess.run
def denied(*args, **kwargs):
    raise PermissionError("blocked")
m.subprocess.run = denied
try:
    if m.run_query("q", "qwen-code", installed, Path.cwd(), "low", 1) is not None:
        fail("an access-denied Codex launch counted as a completed run")
finally:
    m.subprocess.run = original_run

print("PASS: codex-trigger-eval effort, sandbox, and trigger detection")
PY
