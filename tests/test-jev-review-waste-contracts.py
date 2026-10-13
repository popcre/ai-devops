#!/usr/bin/env python3
"""Offline contract checks for the review-waste Jev caller (no bash, no network).

Validates the same contracts as tests/test-ai-jev-review-waste.sh where the
Windows Git Bash fork limit makes that suite unreliable locally. CI still runs
the bash suite.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CFG = ROOT / "config" / "jev-decisions.json"
CLIENT = ROOT / "tools" / "lib" / "jev-client.sh"
CALLER = ROOT / "bin" / "ai-jev-review-waste"
PROBE = ROOT / "bin" / "ai-jev-probe"
SHADOW = ROOT / "bin" / "ai-jev-completion-shadow"
PINS = ROOT / "config" / "tool-versions.json"

passed = 0
failed = 0


def ok(msg: str = "") -> None:
    global passed
    passed += 1
    if msg:
        print(f"  ok   {msg}")


def bad(msg: str) -> None:
    global failed
    failed += 1
    print(f"  FAIL {msg}")


def main() -> int:
    # 1. Config schema and pin
    cfg = json.loads(CFG.read_text(encoding="utf-8"))
    pins = json.loads(PINS.read_text(encoding="utf-8"))
    if cfg.get("schema_version") == 1 and cfg.get("model_pin"):
        ok("jev-decisions.json schema + model pin")
    else:
        bad("jev-decisions.json missing schema/pin")
    if cfg.get("model_pin") == pins.get("models", {}).get("jev"):
        ok("model pin matches tool-versions")
    else:
        bad(f"pin mismatch {cfg.get('model_pin')} vs {pins.get('models', {}).get('jev')}")
    if cfg.get("model_alias_forbidden_for_calibration") == "jev-latest":
        ok("jev-latest forbidden for calibration")
    else:
        bad("jev-latest calibration guard missing")

    # 2. Locked five-level Score scale
    vl = cfg.get("decisions", {}).get("value_level", {})
    labels = vl.get("level_labels")
    if labels == ["negative", "none", "low", "medium", "highest"]:
        ok("five-level Score labels locked")
    else:
        bad(f"value_level labels wrong: {labels}")
    if vl.get("type") == "score" and cfg["decisions"]["chunk_filter"].get("type") == "choice":
        ok("question types are score + choice")
    else:
        bad("question types wrong")

    # 3. Shared client is the only transport
    client_txt = CLIENT.read_text(encoding="utf-8")
    caller_txt = CALLER.read_text(encoding="utf-8")
    for fn in ("jev_bootstrap", "jev_request", "jev_read_noul", "jev_read_choice",
               "jev_read_score", "jev_cleanup"):
        if f"{fn}()" in client_txt or f"function {fn}" in client_txt:
            ok(f"client exports {fn}")
        else:
            bad(f"client missing {fn}")
    if "api.typesafe.ai" not in caller_txt:
        ok("thin caller has no hardcoded endpoint")
    else:
        bad("thin caller hardcodes endpoint")
    if "TYPESAFE_API_KEY=" not in caller_txt:
        ok("thin caller does not resolve secrets")
    else:
        bad("thin caller resolves secrets")
    if "jev-latest" in caller_txt or "jev-latest" in client_txt:
        # allow only the forbidden-alias constant in config load comments; check literals
        if re.search(r'["\']jev-latest["\']', caller_txt + client_txt):
            bad("jev-latest literal in client/caller")
        else:
            ok("no jev-latest literal in client/caller")
    else:
        ok("no jev-latest in client/caller")

    # 4. Probe/shadow observable contracts still present
    for path in (PROBE, SHADOW):
        t = path.read_text(encoding="utf-8")
        if "jev-client.sh" in t:
            ok(f"{path.name} sources shared client")
        else:
            bad(f"{path.name} does not source shared client")
        if "fail()" in t or "FAIL:" in t:
            ok(f"{path.name} keeps FAIL contract")
        else:
            bad(f"{path.name} missing FAIL contract")

    # 5. Empty-key loudness (static)
    if "EMPTY" in client_txt and "jev_fail_loud" in client_txt:
        ok("empty key is loud")
    else:
        bad("empty key loudness missing")

    # 6. Review-waste caller refuses to guess (static abstain paths)
    for token in ('emit_abstain', 'below-threshold', 'request', 'parse'):
        if token in caller_txt:
            ok(f"abstain path present: {token}")
        else:
            bad(f"abstain path missing: {token}")

    # 7. No raw state printed by caller (static)
    if "echo \"$state\"" in caller_txt or "echo $state" in caller_txt:
        bad("caller echoes state")
    else:
        ok("caller does not echo state")

    print(f"\n{passed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
