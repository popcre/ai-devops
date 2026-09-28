#!/usr/bin/env python3
"""Reject new unmanaged GitHub API/CLI traffic in installed bin commands.

P3/#931 owns this guard. User-facing command examples have narrow literal
exceptions; the P4/S2 ai-pr-wait direct fallback has been removed.
"""

import pathlib
import re
import sys


ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) == 2 else pathlib.Path(__file__).resolve().parents[2])
DIRECT = re.compile(r"(?<![\w-])gh(?:\.exe)?\s+(?:api|run|repo|pr|issue|workflow|release|search)\b", re.IGNORECASE)
SDK = re.compile(r"(?:execFileSync|spawnSync|execFile|spawn)\s*\(\s*['\"]gh(?:\.exe)?['\"]", re.IGNORECASE)
ARG_ARRAY = re.compile(r"[\[(,]\s*['\"]gh(?:\.exe)?['\"]\s*,\s*['\"](?:api|run|repo|pr|issue|workflow|release|search)\b", re.IGNORECASE)
HTTP = re.compile(r"(?:api\.github\.com|github\.getOctokit|@octokit)")
CLI_ALIAS = re.compile(r"\b[A-Za-z_]\w*\s*=\s*['\"]?gh(?:\.exe)?['\"]?(?=\s|;|$)", re.IGNORECASE)


def inspect(path: pathlib.Path) -> list[str]:
    relative = path.relative_to(ROOT).as_posix()
    if path.name == "ai-gh":
        return []  # The shared admission command must invoke the real CLI.
    raw = path.read_bytes()
    problems = []
    # Preserve the first physical line for diagnostics while joining shell
    # continuations, which otherwise split `gh` from its API subcommand.
    logical_lines = []
    pending = ""
    start = 1
    for number, physical in enumerate(raw.decode("utf-8", errors="replace").splitlines(), 1):
        if not pending:
            start = number
        if physical.rstrip().endswith("\\"):
            pending += physical.rstrip()[:-1] + " "
            continue
        logical_lines.append((start, pending + physical))
        pending = ""
    if pending:
        logical_lines.append((start, pending))
    for number, line in logical_lines:
        stripped = line.lstrip()
        if stripped.startswith(("#", "//", "*")):
            continue
        if path.name == "ai-private-config" and stripped == 'mkdir -p "$(dirname "$ROOT")"; gh repo clone "$REPOSITORY" "$ROOT" >/dev/null':
            continue  # Bootstrap Git clone; separate Git transport, not an API read.
        if path.name == "ai-blocker-watch" and stripped.startswith('prompt="ai-blocker-watch:') and stripped.endswith('"') and '$(gh' not in line:
            continue  # User-facing recovery text, not an executed command.
        if path.name == "ai-pr-wait" and stripped in {
            "printf 'ai-pr-wait: a documentation-only pull request merges immediately with `gh pr merge --squash --admin`; no wait was started.\\n' >&2",
            'say "    gh run list --repo $REPO --event merge_group --limit 5"',
        }:
            continue  # Exact user-facing guidance; S2 removed its direct fallback.
        if DIRECT.search(line) or SDK.search(line) or ARG_ARRAY.search(line) or HTTP.search(line) or CLI_ALIAS.search(line):
            problems.append(f"{relative}:{number}: unmanaged GitHub transport")
    if path.name == "ai-pr-wait" and b"calling gh directly" in raw:
        problems.append(f"{relative}: unpaced fallback after shared transport failure")
    return problems


def main() -> int:
    bindir = ROOT / "bin"
    if not bindir.is_dir():
        print("managed GitHub transport guard: bin directory missing", file=sys.stderr)
        return 2
    problems = []
    for path in sorted(bindir.iterdir()):
        if path.is_file() and path.suffix in ("", ".sh", ".ps1", ".py", ".js", ".mjs", ".cjs", ".cmd", ".bat"):
            problems.extend(inspect(path))
    if problems:
        print("\n".join(problems), file=sys.stderr)
        return 1
    print("managed GitHub transport guard: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
