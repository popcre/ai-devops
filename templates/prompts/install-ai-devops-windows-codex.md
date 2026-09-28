# Install AI DevOps on this Windows computer

You are Codex on one of Albert's Windows computers. Install or update Albert's
AI DevOps toolkit without requiring him to know whether the repo already exists.

Do this:

For a new computer or an existing checkout whose installer predates the reviewed
source gate, follow the pinned target-worktree installation in
`docs/deployment.md`. A protected, missing-receipt, partial-launcher, or legacy
update must not execute pre-update installer bytes.

1. Open PowerShell commands from Codex as needed.
2. If the managed launcher receipt is present and current, run this one-liner
   for an ordinary update. Otherwise follow the reviewed route above:

```powershell
if(!(Get-Command git -EA SilentlyContinue)){winget install --id Git.Git -e --source winget; $env:Path=[Environment]::GetEnvironmentVariable("Path","Machine")+";"+[Environment]::GetEnvironmentVariable("Path","User")}; $p="$HOME\repos\ai-devops"; if(!(Test-Path "$p\.git")){git clone https://github.com/popcre/ai-devops.git $p}; powershell -ExecutionPolicy Bypass -File "$p\bin\install-ai-devops-windows.ps1"
```

3. If GitHub authentication is needed to clone the private repo, guide Albert
   through the exact `gh auth login` or browser/device-code step, then rerun the
   installer.
4. Verify these exist after the script finishes:
   - `$HOME\.codex\skills\codex-github-ship\SKILL.md`
   - `$HOME\.codex\skills\wrap-up\SKILL.md`
   - `$HOME\.codex\skills\codex-context-optimizer\SKILL.md`
   - `$HOME\.codex\skills\codex-transcript-miner\SKILL.md`
   - `$HOME\.codex\AGENTS.md`
5. Report in plain English:
   - where the repo lives,
   - whether it cloned or pulled,
   - how many Claude and Codex skills were installed,
   - anything Albert still needs to log into (`gh`, `codex`, or `claude`).

Do not paste or store secret values. If any existing global instruction file
differs, do not overwrite it; tell Albert the installer preserved local edits.
