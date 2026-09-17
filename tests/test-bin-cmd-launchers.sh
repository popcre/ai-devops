#!/usr/bin/env bash
#
# Every extensionless executable in bin/ needs a sibling .cmd launcher.
#
# Why: Windows shells (PowerShell, Codex) that run `bin/ai-gh` by path hand an
# extensionless file to the shell association, which pops "Select an app to
# open" instead of running it. A sibling .cmd is preferred and runs the script
# through Git Bash. The .cmd files stay non-executable so Unix installers,
# which link only executable bin/* entries, ignore them.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fail=0
for src in "$REPO_ROOT"/bin/*; do
  name="$(basename "$src")"
  case "$name" in *.*) continue ;; esac
  git -C "$REPO_ROOT" ls-files --error-unmatch "bin/$name" >/dev/null 2>&1 || continue
  launcher="$src.cmd"
  if [ ! -f "$launcher" ]; then
    echo "FAIL: bin/$name has no bin/$name.cmd launcher" >&2; fail=1; continue
  fi
  grep -q '"%~dpn0" %\*' "$launcher" || { echo "FAIL: bin/$name.cmd does not run its own script" >&2; fail=1; }
done
for launcher in "$REPO_ROOT"/bin/*.cmd; do
  script="${launcher%.cmd}"
  [ -f "$script" ] || { echo "FAIL: $(basename "$launcher") has no matching script" >&2; fail=1; }
  mode="$(git -C "$REPO_ROOT" ls-files -s "bin/$(basename "$launcher")" | cut -d' ' -f1)"
  [ -z "$mode" ] || [ "$mode" = 100644 ] || { echo "FAIL: $(basename "$launcher") must not be executable (mode $mode)" >&2; fail=1; }
done

if command -v cmd.exe >/dev/null 2>&1 && command -v pwsh >/dev/null 2>&1 && [ -f "$REPO_ROOT/bin/ai-task-gates.cmd" ]; then
  resolved="$(cd "$REPO_ROOT" && pwsh -NoProfile -Command '(Get-Command bin/ai-task-gates).Source' | tr -d '\r')"
  case "$resolved" in *.cmd) ;; *) echo "FAIL: PowerShell resolves bin/ai-task-gates to $resolved" >&2; fail=1 ;; esac
fi
# Launchers must honor each script's shebang (Bash and Python tools alike).
if command -v cmd.exe >/dev/null 2>&1; then
  for tool in ai-task-gates ai-doc-reachability; do
    [ -f "$REPO_ROOT/bin/$tool.cmd" ] || continue
    win="$(cygpath -w "$REPO_ROOT/bin/$tool.cmd")"
    MSYS_NO_PATHCONV=1 cmd.exe /d /c "$win" --help >/dev/null 2>&1       || { echo "FAIL: bin/$tool.cmd --help did not run cleanly" >&2; fail=1; }
  done
fi
[ "$fail" -eq 0 ] && echo "PASS: bin launchers"
exit "$fail"
