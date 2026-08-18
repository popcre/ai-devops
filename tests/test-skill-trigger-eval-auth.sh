#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNNER="$ROOT/tools/skill-trigger-eval/skill-trigger-eval.py"

python - "$RUNNER" <<'PY'
import importlib.util, json, subprocess, sys

spec = importlib.util.spec_from_file_location("ste", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class Result:
    def __init__(self, payload, returncode=0):
        self.stdout = json.dumps(payload)
        self.stderr = ""
        self.returncode = returncode

original = m.subprocess.run
try:
    m.subprocess.run = lambda *a, **k: Result({"loggedIn": False})
    ok, reason = m.claude_is_authenticated()
    assert not ok and "logged out" in reason

    m.subprocess.run = lambda *a, **k: Result({"loggedIn": True})
    ok, reason = m.claude_is_authenticated()
    assert ok and reason == ""

    def denied(*args, **kwargs):
        raise PermissionError("blocked")
    m.subprocess.run = denied
    ok, reason = m.claude_is_authenticated()
    assert not ok and "could not run" in reason
finally:
    m.subprocess.run = original

print("PASS: Claude trigger evaluation refuses logged-out and inaccessible clients")
PY
