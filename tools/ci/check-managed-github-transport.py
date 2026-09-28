#!/usr/bin/env python3
"""Reject recognizable unmanaged GitHub API/CLI traffic in installed bin commands.

P3/#931 owns this guard. User-facing command examples have narrow literal
exceptions; the P4/S2 ai-pr-wait direct fallback has been removed.
This is a static syntax guard for recognizable CLI forms regardless of verb,
not a proof about computed executable names; those require source review.
"""

import pathlib
import re
import sys


ROOT = pathlib.Path(sys.argv[1] if len(sys.argv) == 2 else pathlib.Path(__file__).resolve().parents[2])
DIRECT = re.compile(r"(?<![\w$.-])(?:['\"])?gh(?:\.exe)?(?:['\"])?\s+[a-z][\w-]*\b", re.IGNORECASE)
SDK = re.compile(r"(?:execFileSync|spawnSync|execFile|spawn)\s*\(\s*['\"](?:[^'\"]*[/\\])?gh(?:\.exe)?['\"]", re.IGNORECASE)
ARG_ARRAY = re.compile(r"[\[(,]\s*['\"](?:[^'\"]*[/\\])?gh(?:\.exe)?['\"]\s*,\s*['\"][a-z][\w-]*\b", re.IGNORECASE)
POWERSHELL_START = re.compile(r"\bStart-Process\s+(?:-FilePath\s+)?['\"]?(?:[^'\"]+[/\\])?gh(?:\.exe)?['\"]?(?=\s|$)", re.IGNORECASE)
HTTP = re.compile(r"(?:api\.github\.com|github\.getOctokit|@octokit)")
CLI_ALIAS = re.compile(r"\b[A-Za-z_]\w*\s*=\s*['\"]?gh(?:\.exe)?['\"]?(?=\s|;|$)", re.IGNORECASE)
LOCAL_OR_TEXT = {
    "ai-devops": {
        'c_ok "gh installed ($(command -v gh))"',
        'c_ok "gh authenticated"',
        'c_warn "gh authentication check deferred by shared GitHub admission"',
        'c_warn "gh not authenticated — run: gh auth login"',
        'c_fail "gh not found (required)"',
    },
    "ai-gh-wait": {
        '[ $# -gt 0 ] || { say "gh arguments are required after --"; exit 3; }',
        'fails=$((fails+1)); say "gh failed (rc=$rc, attempt $fails)"',
    },
    "ai-pr-wait": {'command -v gh >/dev/null 2>&1 || { printf \'ai-pr-wait: gh is not installed\\n\' >&2; exit 3; }'},
    "ai-private-config": {
        "[ -r /dev/tty ] || die 'GitHub CLI is not authenticated; run: gh auth login'",
        "gh auth login --web --git-protocol https </dev/tty || die 'GitHub authorization did not complete.'",
    },
    "install-ai-devops-windows.ps1": {
        'Write-Note "GitHub CLI is installed but not logged in. Run: gh auth login"',
        'Write-Note "GitHub CLI not found. Install when needed: winget install GitHub.cli"',
    },
    "promote-windows-runner-to-service.ps1": {"foreach ($tool in @('git', 'gh', 'jq', 'pwsh', 'node', 'python')) {"},
    "verify-windows-dev.ps1": {"@('winget','git','pwsh','node','python','gh','op','gcloud','az','cloudflared','wsl','claude','grok','kimi','vercel','trigger.dev','railway','supabase') | ForEach-Object { Check-Command $_ }"},
}


def inspect(path: pathlib.Path) -> list[str]:
    relative = path.relative_to(ROOT).as_posix()
    if path.name == "ai-gh":
        return []  # The shared admission command must invoke the real CLI.
    raw = path.read_bytes()
    source = raw.decode("utf-8", errors="replace")
    problems = []
    # Preserve the first physical line for diagnostics while joining shell,
    # PowerShell, and CMD continuations, which split CLI from subcommand.
    logical_lines = []
    pending = ""
    start = 1
    for number, physical in enumerate(source.splitlines(), 1):
        if not pending:
            start = number
        if physical.rstrip().endswith(("\\", "`", "^")):
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
        if stripped in LOCAL_OR_TEXT.get(path.name, ()):
            continue  # Exact non-network text, local checks, or interactive bootstrap.
        if path.name == "ai-private-config" and stripped == 'mkdir -p "$(dirname "$ROOT")"; gh repo clone "$REPOSITORY" "$ROOT" >/dev/null':
            continue  # Bootstrap Git clone; separate Git transport, not an API read.
        if path.name == "ai-private-config" and stripped == 'if ! gh auth status >/dev/null 2>&1; then':
            continue  # First-clone authentication probe before protected config exists.
        if path.name == "ai-blocker-watch" and stripped.startswith('prompt="ai-blocker-watch:') and stripped.endswith('"') and '$(gh' not in line:
            continue  # User-facing recovery text, not an executed command.
        if path.name == "ai-pr-wait" and stripped in {
            "printf 'ai-pr-wait: a documentation-only pull request merges immediately with `gh pr merge --squash --admin`; no wait was started.\\n' >&2",
            'say "    gh run list --repo $REPO --event merge_group --limit 5"',
        }:
            continue  # Exact user-facing guidance; S2 removed its direct fallback.
        if DIRECT.search(line) or SDK.search(line) or ARG_ARRAY.search(line) or POWERSHELL_START.search(line) or HTTP.search(line) or CLI_ALIAS.search(line):
            problems.append(f"{relative}:{number}: unmanaged GitHub transport")
    # Python and Node argument arrays may span several physical lines. The
    # same bounded literal patterns apply after comment-only lines are masked.
    scan_text = "\n".join(
        "" if line.lstrip().startswith(("#", "//", "*")) else line
        for line in source.splitlines()
    )
    for pattern in (SDK, ARG_ARRAY):
        for match in pattern.finditer(scan_text):
            if "\n" in match.group():
                number = scan_text.count("\n", 0, match.start()) + 1
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
