[CmdletBinding()]
param(
  [ValidateSet('Stdio','Remote','Capture')][string]$Mode = 'Stdio',
  [string]$Url = '',
  [string]$SecretRef = '',
  # Position=0 is load-bearing: it makes CommandArgs the ONLY positional param,
  # which forces -Url/-SecretRef to bind by NAME only. Without it, a Stdio child
  # like `cmd /c npx ...` has its leading `cmd` and `/c` silently swallowed into
  # -Url/-SecretRef (positional), and the launcher then runs `npx` bare instead of
  # through cmd. It also lets the .cmd callers drop the `--` separator, which
  # PowerShell's `-File` mode mis-parses as an empty/ambiguous parameter name.
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$CommandArgs
)

$ErrorActionPreference = 'Stop'
$cfgDir = Join-Path $HOME '.config\ai-devops'
$tokenFile = Join-Path $cfgDir 'op-service-account'
$envFile = Join-Path $cfgDir 'mcp.env'
$cacheFile = Join-Path $cfgDir 'mcp-secrets.dpapi.json'
$cacheMinutes = 15

function Get-References {
  $refs = [ordered]@{}
  foreach ($line in Get-Content -LiteralPath $envFile) {
    if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(op://.+)$') { $refs[$Matches[1]] = $Matches[2] }
  }
  $refs
}

function Write-EncryptedCache {
  $values = [ordered]@{}
  foreach ($name in (Get-References).Keys) {
    $plain = [Environment]::GetEnvironmentVariable($name, 'Process')
    if ([string]::IsNullOrEmpty($plain)) { throw "1Password resolved $name EMPTY; refusing to cache or start MCPs." }
    $secure = ConvertTo-SecureString $plain -AsPlainText -Force
    $values[$name] = ConvertFrom-SecureString $secure
  }
  @{ createdUtc = [DateTime]::UtcNow.ToString('o'); values = $values } |
    ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $cacheFile -Encoding utf8
  & icacls $cacheFile /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null
}

function Ensure-Cache {
  $mutex = [Threading.Mutex]::new($false, 'Local\ai-devops-1password-refresh')
  try {
    if (-not $mutex.WaitOne([TimeSpan]::FromSeconds(90))) { throw 'Timed out waiting for the serialized 1Password refresh.' }
    $fresh = (Test-Path -LiteralPath $cacheFile) -and
      (([DateTime]::UtcNow - (Get-Item -LiteralPath $cacheFile).LastWriteTimeUtc).TotalMinutes -lt $cacheMinutes)
    if (-not $fresh) {
      if (-not (Test-Path -LiteralPath $tokenFile)) { throw "Missing 1Password token file: $tokenFile" }
      $env:OP_SERVICE_ACCOUNT_TOKEN = (Get-Content -Raw -LiteralPath $tokenFile).Trim()
      & op run --no-masking --env-file=$envFile -- pwsh -NoProfile -File $PSCommandPath -Mode Capture
      if ($LASTEXITCODE -ne 0) { throw "The single 1Password environment refresh failed (exit $LASTEXITCODE)." }
    }
  } finally {
    try { $mutex.ReleaseMutex() } catch { }
    $mutex.Dispose()
  }
}

function Import-Cache {
  $cache = Get-Content -Raw -LiteralPath $cacheFile | ConvertFrom-Json
  foreach ($property in $cache.values.PSObject.Properties) {
    $secure = ConvertTo-SecureString $property.Value
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { [Environment]::SetEnvironmentVariable($property.Name, [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr), 'Process') }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
  }
}

if ($Mode -eq 'Capture') { Write-EncryptedCache; exit 0 }
Ensure-Cache
Import-Cache

# The 1Password MCP authenticates with OP_SERVICE_ACCOUNT_TOKEN itself, but that
# variable is NOT in mcp.env and therefore never lands in the DPAPI cache. Ensure-Cache
# only sets it on the *refresh* path (stale cache), so whether the 1Password MCP got a
# token was a race with the 15-minute cache window: start it while the cache was fresh
# -- e.g. any reconnect shortly after another MCP refreshed it -- and it came up with no
# token, failing every call with "Service account token is required" until Claude Code
# was restarted. Observed mid-session 2026-07-26.
#
# Inject it explicitly, and ONLY for that MCP: handing the vault's service-account token
# to every MCP child (supabase, trigger, recall-ai, nas, ...) would widen its blast radius
# for no reason.
if (($CommandArgs -join ' ') -match '1password-mcp') {
  if (-not (Test-Path -LiteralPath $tokenFile)) { throw "Missing 1Password token file: $tokenFile" }
  $opToken = (Get-Content -Raw -LiteralPath $tokenFile).Trim()
  if ([string]::IsNullOrEmpty($opToken)) { throw "1Password token file is empty: $tokenFile" }
  [Environment]::SetEnvironmentVariable('OP_SERVICE_ACCOUNT_TOKEN', $opToken, 'Process')
  # Belt and braces: hand over the token FILE PATH too (not a secret). 1password-mcp
  # >= 2.6.0 can re-resolve from it, so the server self-heals instead of staying dead
  # for its whole lifetime if the env injection above ever fails.
  [Environment]::SetEnvironmentVariable('OP_SERVICE_ACCOUNT_TOKEN_FILE', $tokenFile, 'Process')
}

if ($Mode -eq 'Remote') {
  $name = (Get-References).GetEnumerator() | Where-Object Value -eq $SecretRef | Select-Object -ExpandProperty Key -First 1
  if (-not $name) { throw "Secret reference is not managed by ${envFile}: $SecretRef" }
  $token = [Environment]::GetEnvironmentVariable($name, 'Process')
  $remoteCommand = Join-Path $cfgDir 'mcp-runtime\node_modules\.bin\mcp-remote.cmd'
  if (-not (Test-Path -LiteralPath $remoteCommand)) { throw "Pinned MCP remote command is missing: $remoteCommand" }
  & $remoteCommand $Url --header "Authorization: Bearer $token" @CommandArgs
} else {
  if (-not $CommandArgs -or $CommandArgs.Count -eq 0) { throw 'No MCP command was supplied.' }
  $command = $CommandArgs[0]
  $args = if ($CommandArgs.Count -gt 1) { $CommandArgs[1..($CommandArgs.Count - 1)] } else { @() }
  & $command @args
}
exit $LASTEXITCODE
