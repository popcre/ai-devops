<#
Skinny ai-devops setup: ONLY the skills and networking portions of the full
Windows setup (bin/setup-machine.ps1). Nothing else.

  1. Claude skills + global ~/.claude/CLAUDE.md (bin/ai-install-skills, with its
     reviewer/AI command launcher step skipped).
  2. Outbound SSH: 916-alien key, managed host aliases (LAN/Tailscale addresses
     from the private config repo), verified known_hosts; 916-alien is the
     fallback identity for every other host.
  3. Inbound SSH: OpenSSH Server (automatic start), 916-alien.pub authorized,
     key-only authentication.
  4. Tailscale up.

The 1Password service-account token is used only inside this process (from
OP_SERVICE_ACCOUNT_TOKEN if set, otherwise pasted at a prompt) and never stored.

Run from an elevated PowerShell 7:
  pwsh -NoProfile -ExecutionPolicy Bypass -File D:\repos\ai-devops\bin\skinny_setup.ps1
Idempotent; safe to rerun.
#>
[CmdletBinding()]
param([string]$RepoPath = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    OK  $m" -ForegroundColor Green }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw 'Run this from an elevated (Administrator) PowerShell.' }

$gitBash = 'C:\Program Files\Git\bin\bash.exe'
if (-not (Test-Path $gitBash)) { throw "Git for Windows is required at $gitBash." }
. (Join-Path $RepoPath 'bin\windows-private-file.ps1')
function Invoke-Bash([string]$Script) {
  $out = & $gitBash -lc $Script
  if ($LASTEXITCODE -ne 0) { throw "Git Bash command failed: $Script" }
  $out
}
$repoBash = (Invoke-Bash "cygpath -u '$RepoPath'" | Select-Object -Last 1).Trim()
function Get-PrivatePath([string]$Key) {
  $p = (Invoke-Bash "'$repoBash/bin/ai-private-config' path $Key" | Select-Object -Last 1).Trim()
  (Invoke-Bash "cygpath -w '$p'" | Select-Object -Last 1).Trim()
}

# --- prerequisites ----------------------------------------------------------
Step 'Prerequisites (jq, gh auth, op)'
if (-not (Get-Command jq -ErrorAction SilentlyContinue)) {
  winget install --id jqlang.jq -e --scope machine --accept-package-agreements --accept-source-agreements | Out-Host
  $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
}
gh auth status *> $null
if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI is not signed in; run: gh auth login' }
if (-not (Get-Command op -ErrorAction SilentlyContinue)) { throw '1Password CLI (op) is required.' }
Ok 'jq, gh and op available'

# --- 1Password: process-scoped token only -----------------------------------
Step '1Password service account (this process only)'
$hadToken = [bool]$env:OP_SERVICE_ACCOUNT_TOKEN
if (-not $hadToken) {
  $secure = Read-Host 'Paste the vibe_coding service-account token (not stored)' -AsSecureString
  $env:OP_SERVICE_ACCOUNT_TOKEN = [Net.NetworkCredential]::new('', $secure).Password
}
try {
  & op vault list *> $null
  if ($LASTEXITCODE -ne 0) { throw '1Password rejected the service-account token.' }
  Ok 'service account authenticated'

  # --- 1. Claude skills + globals ---------------------------------------------
  Step 'Claude skills and global CLAUDE.md'
  # Its final step installs reviewer/AI command launchers; skinny setup skips it.
  Invoke-Bash "AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE=1 '$repoBash/bin/ai-install-skills'" | Out-Host
  # --- 2. Outbound SSH ----------------------------------------------------------
  Step 'Outbound SSH (916-alien key, host aliases, known hosts)'
  Invoke-Bash "'$repoBash/bin/ai-private-config' sync" | Out-Null
  $sshDir = Join-Path $HOME '.ssh'
  New-Item -ItemType Directory -Force -Path $sshDir | Out-Null
  $keyPath = Join-Path $sshDir '916-alien'
  $priv = & op read 'op://vibe_coding/916-alien SSH key/private key'
  if ($LASTEXITCODE -ne 0 -or -not $priv) { throw 'Could not read the 916-alien private key from 1Password.' }
  $privText = (($priv -join "`n") -replace "`r`n", "`n"); if (-not $privText.EndsWith("`n")) { $privText += "`n" }
  Set-AiDevOpsPrivateFileAtomic -Path $keyPath -Bytes ([Text.Encoding]::UTF8.GetBytes($privText)) | Out-Null
  Remove-Variable priv, privText
  $pub = & op read 'op://vibe_coding/916-alien SSH key/public key'
  if ($LASTEXITCODE -ne 0 -or -not $pub) { throw 'Could not read the 916-alien public key from 1Password.' }
  $pubLine = (($pub -join ' ').Trim())
  [IO.File]::WriteAllText("$keyPath.pub", "$pubLine`n")
  Ok "restored $keyPath (+ .pub)"

  Copy-Item (Get-PrivatePath 'ssh_config') (Join-Path $sshDir 'ai-devops.conf') -Force
  foreach ($probe in 'ai-lan-probe', 'ai-lan-probe.cmd') {
    Copy-Item (Join-Path $RepoPath "config\ssh\$probe") (Join-Path $sshDir $probe) -Force
  }
  # Managed aliases first (OpenSSH takes the first value), 916-alien as the
  # fallback identity last, anything the user wrote in between untouched.
  $mainConf = Join-Path $sshDir 'config'
  $body = if (Test-Path $mainConf) { [IO.File]::ReadAllText($mainConf) } else { '' }
  $body = [regex]::Replace($body, '(?im)^\s*Include\s+ai-devops\.conf\s*\r?\n?', '')
  $body = [regex]::Replace($body, '(?ms)^# BEGIN AI-DEVOPS RUNNER DEFAULT KEY.*?^# END AI-DEVOPS RUNNER DEFAULT KEY\s*', '')
  $body = $body.Trim()
  $fallback = "# BEGIN AI-DEVOPS RUNNER DEFAULT KEY`r`nHost *`r`n  IdentityFile ~/.ssh/916-alien`r`n# END AI-DEVOPS RUNNER DEFAULT KEY`r`n"
  $text = "Include ai-devops.conf`r`n`r`n" + $(if ($body) { "$body`r`n`r`n" } else { '' }) + $fallback
  [IO.File]::WriteAllText($mainConf, $text, [Text.Encoding]::ASCII)
  foreach ($f in $mainConf, (Join-Path $sshDir 'ai-devops.conf')) {
    icacls $f /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null
  }
  & (Join-Path $RepoPath 'bin\sync-ssh-known-hosts.ps1') -TemplatePath (Get-PrivatePath 'ssh_known_hosts') `
    -KnownHostsPath (Join-Path $sshDir 'known_hosts')
  Ok 'host aliases, fallback identity and known hosts installed'
}
finally {
  if (-not $hadToken) { Remove-Item Env:\OP_SERVICE_ACCOUNT_TOKEN -ErrorAction SilentlyContinue }
}

# --- 3. Inbound SSH ---------------------------------------------------------
Step 'Inbound SSH (OpenSSH Server, 916-alien authorized, key-only)'
# Get/Add-WindowsCapability fail under pwsh 7 ("Class not registered"); dism.exe works everywhere.
if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
  dism.exe /Online /Add-Capability /CapabilityName:OpenSSH.Server~~~~0.0.1.0 /NoRestart | Out-Host
  if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) { throw 'OpenSSH Server install failed.' }
}
Set-Service sshd -StartupType Automatic
Start-Service sshd
# Administrators authenticate only from this file (Windows sshd default).
$authKeys = Join-Path $env:ProgramData 'ssh\administrators_authorized_keys'
if (-not (Test-Path $authKeys)) { New-Item -ItemType File -Path $authKeys -Force | Out-Null }
if (@(Get-Content $authKeys -ErrorAction SilentlyContinue) -notcontains $pubLine) { Add-Content -Path $authKeys -Value $pubLine -Encoding ascii }
icacls $authKeys /inheritance:r /grant '*S-1-5-18:F' /grant '*S-1-5-32-544:F' | Out-Null
$sshdConfig = Join-Path $env:ProgramData 'ssh\sshd_config'
$original = Get-Content -Raw $sshdConfig
$start = '# BEGIN AI-DEVOPS KEY-ONLY AUTH'; $end = '# END AI-DEVOPS KEY-ONLY AUTH'
$content = [regex]::Replace($original, '(?ms)^' + [regex]::Escape($start) + '.*?^' + [regex]::Escape($end) + '\s*', '')
$block = "$start`r`nPasswordAuthentication no`r`nPubkeyAuthentication yes`r`n$end`r`n`r`n"
$m = [regex]::Match($content, '(?im)^\s*Match\s+')
$content = if ($m.Success) { $content.Insert($m.Index, $block) } else { $content.TrimEnd() + "`r`n`r`n$block" }
if ($content -ne $original) {
  Set-Content -Path $sshdConfig -Value $content -Encoding ascii
  & "$env:WINDIR\System32\OpenSSH\sshd.exe" -t -f $sshdConfig
  if ($LASTEXITCODE -ne 0) { Set-Content -Path $sshdConfig -Value $original -Encoding ascii; throw 'sshd_config failed validation; original restored.' }
  Restart-Service sshd
}
Ok 'sshd running, 916-alien authorized, password login disabled'

# --- 4. Tailscale -------------------------------------------------------------
Step 'Tailscale'
$ts = (Get-Command tailscale -ErrorAction SilentlyContinue).Source
if (-not $ts) { $ts = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe' }
if (-not (Test-Path $ts)) {
  winget install --id Tailscale.Tailscale -e --accept-package-agreements --accept-source-agreements | Out-Host
}
$ip = (& $ts ip -4 2>$null | Select-Object -First 1)
if (-not $ip) { & $ts up; $ip = (& $ts ip -4 2>$null | Select-Object -First 1) }
if ($ip) { Ok "Tailscale up at $ip" } else { Write-Warning 'Tailscale needs sign-in: run "tailscale up" and finish in the browser.' }

Write-Host "`nDone." -ForegroundColor Green
