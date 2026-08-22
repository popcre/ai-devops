#!/usr/bin/env python3
"""Render the current context table from audit JSON; never copy measurements by hand."""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("report", type=Path)
args = parser.parse_args()
report = json.loads(args.report.read_text(encoding="utf-8"))
totals = {}
for item in report["files"] + report["skills"]:
    row = totals.setdefault(item["classification"], {"files": 0, "bytes": 0, "tokens": 0})
    row["files"] += 1; row["bytes"] += item["bytes"]; row["tokens"] += item["estimatedTokens"]
print("| Context class | Files | Bytes | Estimated tokens |")
print("|---|---:|---:|---:|")
for name in ("always-loaded", "startup-routed", "task-triggered"):
    row = totals.get(name, {"files": 0, "bytes": 0, "tokens": 0})
    print(f"| {name} | {row['files']} | {row['bytes']} | {row['tokens']} |")
for client in ("claude", "codex"):
    row = report["skillManifest"][client]
    print(f"| {client} skill manifest | {row['skills']} | {row['bytes']} | {row['estimatedTokens']} |")
effective = report.get("effectiveInstalledGlobals", {})
if effective.get("complete"):
    value = effective["bytes"]
    print(f"| effective installed globals | 2 | {value} | {(value + 3) // 4} |")
