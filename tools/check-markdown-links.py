#!/usr/bin/env python3
"""Validate tracked local Markdown links without network access.

Skipped content: root `plan_*.md` / `fix_*.md` historical records and
`docs/verification/**` evidence captures embed paths as of capture time and
are not doc navigation, so no link checks run on them; matches inside fenced
code blocks or inline code spans are ignored for the same reason (embedded
JSON snapshots live there). Every checked link keeps both failure modes:
missing local target and link escapes repository.
"""
from __future__ import annotations
import fnmatch, pathlib, re, subprocess, sys, urllib.parse

root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
if not root.is_dir():
    raise SystemExit("check-markdown-links: expected a repository directory")
# Optional "-- path..." limits the check to those tracked Markdown files
# (a PR's changed files, u2giants/theoracle#345); otherwise all are checked.
if len(sys.argv) > 2 and sys.argv[2] == "--":
    scope = [":(literal)" + p for p in sys.argv[3:] if p.lower().endswith(".md")]
    if not scope:
        print("PASS: no changed Markdown files to check")
        raise SystemExit(0)
else:
    scope = ["*.md"]
try:
    tracked = subprocess.run(
        ["git", "-C", str(root), "ls-files", "--", *scope], check=True,
        text=True, capture_output=True,
    ).stdout.splitlines()
except (OSError, subprocess.CalledProcessError, UnicodeError):
    raise SystemExit("check-markdown-links: cannot list tracked Markdown in that directory")
pattern = re.compile(r"(?<!!)\[[^\]]+\]\(([^)]+)\)")
fence_pattern = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")


def is_historical(relative: str) -> bool:
    parts = relative.replace("\\", "/").split("/")
    if len(parts) >= 3 and parts[0] == "docs" and parts[1] == "verification":
        return True
    if len(parts) == 1:
        name = parts[0]
        return fnmatch.fnmatchcase(name, "plan_*.md") or fnmatch.fnmatchcase(name, "fix_*.md")
    return False


def code_spans(line: str) -> list[tuple[int, int]]:
    """Ranges of inline-code spans (matching backtick runs) in one line."""
    spans: list[tuple[int, int]] = []
    i, n = 0, len(line)
    while i < n:
        if line[i] != "`":
            i += 1
            continue
        j = i
        while j < n and line[j] == "`":
            j += 1
        run = j - i
        k, closed = j, False
        while k < n:
            if line[k] != "`":
                k += 1
                continue
            m = k
            while m < n and line[m] == "`":
                m += 1
            if m - k == run:
                spans.append((i, m))
                i, closed = m, True
                break
            k = m
        if not closed:
            i = j
    return spans


failures: list[str] = []
checked = 0
skipped = 0
for relative in tracked:
    if is_historical(relative):
        skipped += 1
        continue
    checked += 1
    source = root / relative
    try:
        text = source.read_text(encoding="utf-8", errors="strict")
    except (OSError, UnicodeError):
        failures.append(f"{relative}: cannot read tracked Markdown as UTF-8")
        continue
    in_fence = None
    for line_number, line in enumerate(text.splitlines(), 1):
        fence = fence_pattern.match(line)
        if in_fence is not None:
            if (fence and fence.group(1)[0] == in_fence[0]
                    and len(fence.group(1)) >= in_fence[1]
                    and not fence.group(2).strip()):
                in_fence = None
            continue
        if fence:
            in_fence = (fence.group(1)[0], len(fence.group(1)))
            continue
        spans = code_spans(line)
        for match in pattern.finditer(line):
            if any(start <= match.start() < end for start, end in spans):
                continue
            target = match.group(1).strip()
            if not target:
                continue
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
print(
    f"PASS: {checked} tracked Markdown files have valid local link targets"
    f" ({skipped} historical/evidence files skipped)"
)
