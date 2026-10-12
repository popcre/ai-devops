#!/usr/bin/env bash
# The live reviewer-events ledger must resolve to the real profile, never the
# current directory, when USERPROFILE is blank and pwd is unavailable (Windows).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="$(command -v python3 || command -v python)"
"$PYTHON" - "$ROOT/tools" <<'PY'
import builtins, os, sys, tempfile
sys.path.insert(0, sys.argv[1])
real_import = builtins.__import__
def no_platform(name, *a, **k):
    if name in ("pwd", "ctypes"):
        raise ImportError(name)
    return real_import(name, *a, **k)
builtins.__import__ = no_platform
import reviewer_events as r
from reviewer_maintenance import Blocked
cwd = tempfile.mkdtemp(); os.chdir(cwd)
os.environ.update(USERPROFILE="", HOMEDRIVE="", HOMEPATH="")
try:
    r.live_location(); raise SystemExit("FAIL blank profile resolved a location")
except Blocked:
    print("ok   blank profile refuses instead of resolving the current directory")
drive = os.path.abspath(os.sep)
os.environ.update(HOMEDRIVE=drive.rstrip(os.sep) or "", HOMEPATH=os.path.join(drive, "profile-x"))
os.environ["HOMEPATH"] = os.path.join(os.sep, "profile-x")
loc = str(r.live_location())
assert "profile-x" in loc and not loc.startswith(cwd), loc
print("ok   HOMEDRIVE/HOMEPATH names the profile when USERPROFILE is blank")
os.environ.pop("HOME", None); os.environ.pop("AI_REVIEW_EVENT_DIR", None); os.environ.pop("AI_REVIEWER_STATE_BASE", None)
os.environ.update(HOMEDRIVE="", HOMEPATH="")
try:
    r.location(); raise SystemExit("FAIL location() resolved without any home")
except Blocked:
    print("ok   location() refuses without HOME or a profile (no KeyError, no cwd)")
os.environ["HOME"] = "."
for fn in (r.location, r.lifecycle_location):
    try:
        fn(); raise SystemExit(f"FAIL {fn.__name__} accepted a relative HOME")
    except Blocked:
        pass
print("ok   a relative HOME is refused by location() and lifecycle_location()")
PY
printf 'reviewer-events profile home: passed\n'
