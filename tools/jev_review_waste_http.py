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
import subprocess
import tempfile
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CFG = json.loads((ROOT / "config" / "jev-decisions.json").read_text(encoding="utf-8"))
MODEL = CFG["model_pin"]
ENDPOINT = CFG["endpoint"]
TIMEOUT = CFG.get("call_timeout_seconds", 20)


def resolve_key() -> str:
    key = os.environ.get("TYPESAFE_API_KEY") or os.environ.get("AI_JEV_KEY")
    if key:
        return key
    env = os.environ.copy()
    token_file = Path.home() / ".config/ai-devops/op-service-account"
    if "OP_SERVICE_ACCOUNT_TOKEN" not in env and token_file.is_file():
        env["OP_SERVICE_ACCOUNT_TOKEN"] = token_file.read_text(encoding="utf-8").strip()
    # Prefer 1Password field read (works on Windows); fall back to op run.
    for cmd in (
        ["op", "item", "get", "typesafe.ai API", "--vault", "vibe_coding",
         "--fields", "label=credential", "--reveal"],
        ["op", "item", "get", "typesafe.ai API", "--vault", "vibe_coding",
         "--fields", "credential", "--reveal"],
    ):
        p = subprocess.run(cmd, capture_output=True, text=True, timeout=30, env=env)
        key = (p.stdout or "").strip()
        if key and p.returncode == 0:
            return key
    raise SystemExit("EMPTY key from 1Password")



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
