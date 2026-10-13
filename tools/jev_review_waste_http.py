#!/usr/bin/env python3
"""Minimal Jev HTTP client for calibration/analysis on this host.

Uses config/jev-decisions.json pin and the same secret bootstrap (op run).
Does not print secrets. Not a second production transport — the shipped
transport remains tools/lib/jev-client.sh; this script is a local analysis
helper for the Windows fork-limited environment.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CFG = json.loads((ROOT / "config" / "jev-decisions.json").read_text(encoding="utf-8"))
MODEL = CFG["model_pin"]
ENDPOINT = CFG["endpoint"]
TIMEOUT = CFG.get("call_timeout_seconds", 20)


def _managed_reference() -> str:
    """The one managed TYPESAFE_API_KEY op:// line, same lookup as jev-client.sh."""
    cfg_dir = Path(os.environ.get("AI_DEVOPS_CONFIG_DIR") or Path.home() / ".config/ai-devops")
    for f in (cfg_dir / "mcp.env", ROOT / "config" / "mcp.env.example"):
        if not f.is_file():
            continue
        lines = [ln for ln in f.read_text(encoding="utf-8").splitlines()
                 if ln.startswith("TYPESAFE_API_KEY=op://")]
        if len(lines) > 1:
            raise SystemExit("more than one TYPESAFE_API_KEY reference")
        if lines:
            return lines[0]
    raise SystemExit("no TYPESAFE_API_KEY op:// reference found")


def resolve_key() -> str:
    """Return the key from the environment, or re-run this process under
    `op run` with the managed reference (the only secret path; no field reads).
    The unkeyed parent never returns: it exits with the child's status."""
    key = os.environ.get("TYPESAFE_API_KEY")
    if key:
        return key
    if os.environ.get("AI_JEV_REEXEC"):
        raise SystemExit("TYPESAFE_API_KEY resolved EMPTY after op run")
    ref = _managed_reference()
    if shutil.which("op") is None:
        raise SystemExit("1Password CLI (op) is required to resolve TYPESAFE_API_KEY")
    env = os.environ.copy()
    env["AI_JEV_REEXEC"] = "1"
    token_file = Path(os.environ.get("AI_DEVOPS_CONFIG_DIR") or Path.home() / ".config/ai-devops") / "op-service-account"
    if "OP_SERVICE_ACCOUNT_TOKEN" not in env and token_file.is_file():
        env["OP_SERVICE_ACCOUNT_TOKEN"] = token_file.read_text(encoding="utf-8").strip()
    fd, ref_file = tempfile.mkstemp(suffix=".env")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(ref + "\n")
        rc = subprocess.run(["op", "run", "--env-file", ref_file, "--",
                             sys.executable, *sys.argv], env=env).returncode
    finally:
        try:
            os.unlink(ref_file)
        except OSError:
            pass
    if rc != 0:
        print(f"jev: keyed run under op run failed (exit {rc})", file=sys.stderr)
    raise SystemExit(rc)


def ask(state: str, questions: dict, key: str) -> dict:
    body = json.dumps({"model": MODEL, "state": state, "questions": questions}).encode("utf-8")
    req = urllib.request.Request(
        ENDPOINT, data=body,
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read().decode("utf-8"))


def chunk_question(instructions: str, criteria: dict) -> dict:
    return {"chunk_filter": {"type": "choice", "instructions": instructions, "criteria": criteria}}


def value_question(instructions: str, criteria: list) -> dict:
    return {"value_level": {"type": "score", "instructions": instructions, "criteria": criteria}}


if __name__ == "__main__":
    k = resolve_key()
    print("key_ok", bool(k), "model", MODEL)
    r = ask(
        "The sky is blue on a clear day.",
        {"probe": {"type": "noul", "instructions": "Does the state describe the colour of the sky?"}},
        k,
    )
    print("model_echo", r.get("model"), "answers", r.get("answers"), "usage", r.get("usage"))
