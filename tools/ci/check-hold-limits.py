#!/usr/bin/env python3
"""Refuse automated holds, waits and timeouts over 30 minutes in gate code.

Owner rule (Albert 2026-11-20): "nothing should be allowed to hold other work
back for 20 hours." Standing rule: thirty minutes without progress is broken.
A 24-hour "closed as not planned" hold, written into an AI plan and then into
code, stopped every later production migration for a day (shared-db #6909).

Flags any `timedelta(hours=N)` / `timedelta(days=N)` and any millisecond or
second constant of an hour or more in the scanned files. A line that is not a
hold (a lookback window, cache, retention, report period) may opt out with a
trailing `# not-a-hold: <reason>` comment.

    check-hold-limits.py [paths...]   exit 0 clean, 1 findings
"""
from __future__ import annotations
import re
import subprocess
import sys

LIMIT_MINUTES = 30
OPT_OUT = re.compile(r"(#|//)\s*not-a-hold:\s*\S")
PATTERNS = [
    (re.compile(r"timedelta\(\s*(hours|days)\s*=\s*(\d+(?:\.\d+)?)"), None),
    (re.compile(r"timedelta\(\s*minutes\s*=\s*(\d+(?:\.\d+)?)"), "minutes"),
    (re.compile(r"\b(\d+)\s*\*\s*60\s*\*\s*60\s*\*\s*1000\b"), "hours_ms"),
    (re.compile(r"\b(\d+)\s*\*\s*3600\b"), "hours"),
]
EXTENSIONS = (".py", ".mjs", ".js", ".ts", ".sh", ".yml", ".yaml")


def minutes(match: re.Match, kind: str | None) -> float:
    if kind is None:
        unit, value = match.group(1), float(match.group(2))
        return value * (60 if unit == "hours" else 1440)
    value = float(match.group(1))
    return value if kind == "minutes" else value * 60


def scan_line(line: str) -> float | None:
    if OPT_OUT.search(line):
        return None
    worst = None
    for pattern, kind in PATTERNS:
        for m in pattern.finditer(line):
            mins = minutes(m, kind)
            if mins > LIMIT_MINUTES and (worst is None or mins > worst):
                worst = mins
    return worst


def tracked(paths: list[str]) -> list[str]:
    out = subprocess.run(["git", "ls-files", "--", *paths], capture_output=True, text=True, check=True).stdout
    return [p for p in out.splitlines() if p.endswith(EXTENSIONS) and "/test" not in p and not p.split("/")[-1].startswith("test")]


def main(argv: list[str]) -> int:
    findings = []
    for path in tracked(argv or ["."]):
        try:
            with open(path, encoding="utf-8") as handle:
                for number, line in enumerate(handle, 1):
                    mins = scan_line(line)
                    if mins is not None:
                        findings.append(f"{path}:{number}: {mins:g} min > {LIMIT_MINUTES} min: {line.strip()[:120]}")
        except (UnicodeDecodeError, FileNotFoundError):
            continue
    for f in findings:
        print(f"::error::hold over 30 minutes: {f}")
    if findings:
        print("Each automated hold, wait or timeout must be 30 minutes or less. "
              "If a line is not a hold (lookback, cache, retention, report period), "
              "end it with '# not-a-hold: <reason>'.")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
