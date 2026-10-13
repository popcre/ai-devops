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
  # Empty ProgramFiles yields a bare \Git\... candidate; the launcher must still
  # find Git Bash through the remaining fallbacks (issue #1701 follow-up).
  grep -Fq 'if not exist "%AI_BASH%" set "AI_BASH=C:\Program Files\Git\bin\bash.exe"' "$launcher" || {
    echo "FAIL: bin/$name.cmd lacks the hard-coded Git Bash fallback" >&2; fail=1; }
  grep -Fq 'if not exist "%AI_BASH%" set "AI_BASH=%ProgramFiles(x86)%\Git\bin\bash.exe"' "$launcher" || {
    echo "FAIL: bin/$name.cmd lacks the ProgramFiles(x86) Git Bash fallback" >&2; fail=1; }
  grep -Fq 'if not exist "%AI_BASH%" set "AI_BASH=%LOCALAPPDATA%\Programs\Git\bin\bash.exe"' "$launcher" || {
    echo "FAIL: bin/$name.cmd lacks the LOCALAPPDATA Git Bash fallback" >&2; fail=1; }
done
for launcher in "$REPO_ROOT"/bin/*.cmd; do
  script="${launcher%.cmd}"
  [ -f "$script" ] || { echo "FAIL: $(basename "$launcher") has no matching script" >&2; fail=1; }
  mode="$(git -C "$REPO_ROOT" ls-files -s "bin/$(basename "$launcher")" | cut -d' ' -f1)"
  [ -z "$mode" ] || [ "$mode" = 100644 ] || { echo "FAIL: $(basename "$launcher") must not be executable (mode $mode)" >&2; fail=1; }
done

# Same bug in the PowerShell helpers: Join-Path on an empty ProgramFiles root
# throws, and a bare "\Git\bin\bash.exe" string never exists. Every detection
# site must guard the root and walk through the hard-coded fallback
# (issue #1701 follow-up).
for ps1 in bin/install-machine-tools.ps1 bin/setup-machine.ps1; do
  if ! grep -Fq "'C:\Program Files\Git\bin\bash.exe'" "$REPO_ROOT/$ps1"; then
    echo "FAIL: $ps1 lacks the hard-coded Git Bash candidate" >&2; fail=1
  fi
  if grep -E 'Join-Path \$env:ProgramFiles "Git' "$REPO_ROOT/$ps1" | grep -vq 'if (\$env:ProgramFiles)'; then
    echo "FAIL: $ps1 calls Join-Path on an unguarded ProgramFiles root" >&2; fail=1
  fi
  if ! grep -Fq "\$_ -notmatch '^[\\\\/]'" "$REPO_ROOT/$ps1"; then
    echo "FAIL: $ps1 does not drop root-relative bash candidates" >&2; fail=1
  fi
done

if command -v pwsh >/dev/null 2>&1; then
  if ! out="$(pwsh -NoProfile -Command '
    $env:ProgramFiles = ""; $env:ProgramFilesx86 = ""
    Remove-Item Env:ProgramFiles* -ErrorAction SilentlyContinue
    $candidates = @(
      $(if ($env:ProgramFiles) { Join-Path $env:ProgramFiles "Git\bin\bash.exe" }),
      $(if (${env:ProgramFiles(x86)}) { Join-Path ${env:ProgramFiles(x86)} "Git\bin\bash.exe" }),
      $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "Programs\Git\bin\bash.exe" }),
      "C:\Program Files\Git\bin\bash.exe",
      "C:\Program Files (x86)\Git\bin\bash.exe"
    ) | Where-Object { $_ -and $_ -notmatch "^[\\/]" -and (Test-Path -LiteralPath $_) } | Select-Object -First 1
    if (-not $candidates) { Write-Error "candidate walk found no Git Bash"; exit 1 }
    if ($candidates -ne "C:\Program Files\Git\bin\bash.exe" -and -not (Test-Path -LiteralPath $candidates)) {
      Write-Error "candidate walk returned a missing path: $candidates"; exit 1
    }
    Write-Output "resolved=$candidates"
  ' 2>&1)"; then
    echo "FAIL: empty-ProgramFiles candidate walk failed:" >&2
    printf '%s\n' "$out" | tail -n 10 | sed 's/^/  | /' >&2
    fail=1
  fi
fi

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
