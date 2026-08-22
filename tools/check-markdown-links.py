#!/usr/bin/env python3
"""Validate tracked local Markdown links without network access."""
from __future__ import annotations
import pathlib, re, subprocess, sys, urllib.parse

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
tracked = subprocess.run(
    ["git", "-C", str(root), "ls-files", "*.md"], check=True,
    text=True, capture_output=True,
).stdout.splitlines()
pattern = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
failures: list[str] = []
for relative in tracked:
    source = root / relative
    text = source.read_text(encoding="utf-8", errors="strict")
    for line_number, line in enumerate(text.splitlines(), 1):
        for raw in pattern.findall(line):
            target = raw.strip()
            if target.startswith("<") and ">" in target:
                target = target[1:target.index(">")]
            else:
                target = target.split(maxsplit=1)[0]
            if not target or target.startswith(("#", "http://", "https://", "mailto:", "data:")):
                continue
            if target == "HANDOFF.d/":  # Template link resolves in the consuming repository.
                continue
            target = urllib.parse.unquote(target.split("#", 1)[0])
            if not target:
                continue
            candidate = (source.parent / target).resolve()
            try:
                candidate.relative_to(root)
            except ValueError:
                failures.append(f"{relative}:{line_number}: link escapes repository: {target}")
                continue
            if not candidate.exists():
                failures.append(f"{relative}:{line_number}: missing local target: {target}")
if failures:
    print("\n".join(failures), file=sys.stderr)
    raise SystemExit(1)
print(f"PASS: {len(tracked)} tracked Markdown files have valid local link targets")
