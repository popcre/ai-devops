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
# Launchers whose .cmd is reviewer-safety and cannot change under the
# no-review plan (plan §8). Their empty-ProgramFiles walk stays on #1701.
PROTECTED_LAUNCHERS="ai-gemini ai-gemini-usage ai-review-credit-watch ai-review-engine ai-review-lifecycle ai-review-packet ai-review-pool ai-review-preflight ai-review-sandbox ai-review-scoreboard ai-reviewer-logs-sync ai-stepfun ai-stepfun-windows-shell"
is_protected() {
  case " $PROTECTED_LAUNCHERS " in
  *" $1 "*) return 0 ;;
  *) return 1 ;;
  esac
}
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
  is_protected "$name" && continue
  # Empty/missing ProgramFiles must still find Git Bash (issue #1701). The
  # walk keeps the .cmd wrapper pattern and ends at the hard-coded machine
  # path so a bare \Git\bin\bash.exe candidate cannot win.
  grep -Fq 'if not exist "%AI_BASH%" set "AI_BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"' "$launcher" || {
    echo "FAIL: bin/$name.cmd lacks the ProgramFiles(x86) Git Bash fallback" >&2; fail=1; }
  grep -Fq 'if not exist "%AI_BASH%" set "AI_BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"' "$launcher" || {
    echo "FAIL: bin/$name.cmd lacks the LOCALAPPDATA Git Bash fallback" >&2; fail=1; }
  grep -Fq 'if not exist "%AI_BASH%" set "AI_BASH=C:\Program Files\Git\bin\bash.exe"' "$launcher" || {
    echo "FAIL: bin/$name.cmd lacks the hard-coded Git Bash fallback" >&2; fail=1; }
  grep -Fq 'if not exist "%AI_BASH%" set "AI_BASH=C:\Program Files (x86)\Git\bin\bash.exe"' "$launcher" || {
    echo "FAIL: bin/$name.cmd lacks the hard-coded x86 Git Bash fallback" >&2; fail=1; }
done

# Named fixture (plan step 5): every code-class launcher can resolve Git Bash
# even when ProgramFiles is empty, because the hard-coded machine path is in
# the chain. Protected launchers are the known #1701 remainder.
hardcoded_missing=0
for launcher in "$REPO_ROOT"/bin/*.cmd; do
  name="$(basename "$launcher" .cmd)"
  is_protected "$name" && continue
  if ! grep -Fq 'if not exist "%AI_BASH%" set "AI_BASH=C:\Program Files\Git\bin\bash.exe"' "$launcher"; then
    echo "FAIL: launcher_resolves_git_bash_with_empty_programfiles: $name" >&2
    hardcoded_missing=1
    fail=1
  fi
done
[ "$hardcoded_missing" -eq 0 ] && echo "ok: launcher_resolves_git_bash_with_empty_programfiles"

# Live Windows walk with ProgramFiles cleared: a real launcher must still
# start through the hard-coded fallback. Skipped on the Linux lane (those
# paths never exist there).
if command -v cmd.exe >/dev/null 2>&1 && [ -f "$REPO_ROOT/bin/ai-doc-reachability.cmd" ]; then
  win="$(cygpath -w "$REPO_ROOT/bin/ai-doc-reachability.cmd")"
  if out="$(MSYS_NO_PATHCONV=1 cmd.exe /d /c "set \"ProgramFiles=\" && set \"ProgramFiles(x86)=\" && $win --help" 2>&1)"; then
    echo "ok: empty_programfiles_launcher_still_runs"
  else
    echo "FAIL: empty_programfiles_launcher_still_runs" >&2
    printf '%s\n' "$out" | tail -n 15 | sed 's/^/  | /' >&2
    fail=1
  fi
fi
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
    if ! out="$(MSYS_NO_PATHCONV=1 cmd.exe /d /c "$win" --help 2>&1)"; then
      echo "FAIL: bin/$tool.cmd --help did not run cleanly" >&2
      printf '%s
' "$out" | tail -n 15 | sed 's/^/  | /' >&2
      fail=1
    fi
  done
fi
[ "$fail" -eq 0 ] && echo "PASS: bin launchers"
exit "$fail"
