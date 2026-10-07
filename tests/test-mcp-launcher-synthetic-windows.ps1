param([string]$InstalledRoot = '', [string]$RuntimeRoot = '')
$ErrorActionPreference = 'Stop'
$source = Split-Path -Parent $PSScriptRoot
if (-not $InstalledRoot) { $InstalledRoot = Join-Path $source 'bin' }
if (-not $RuntimeRoot) {
    $RuntimeRoot = Join-Path $env:USERPROFILE '.config\ai-devops\mcp-runtime'
    if (-not (Test-Path -LiteralPath (Join-Path $RuntimeRoot 'node_modules\mcp-remote\dist\proxy.js'))) {
        Write-Host 'SKIP: scoped pinned runtime is required for native synthetic HTTP proof.'
        return
    }
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ('mcp-synthetic-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    . (Join-Path $source 'bin\windows-private-file.ps1')
    . (Join-Path $source 'bin\mcp-launcher-install-windows.ps1')
    Protect-AiDevOpsPrivatePath $temp -Directory
    $launcherSource = [IO.File]::ReadAllText((Join-Path $InstalledRoot 'mcp-secret-launch.ps1'))
    $needle = '$cfgDir = Join-Path $HOME ''.config\ai-devops'''
    if (-not $launcherSource.Contains($needle)) { throw 'Synthetic fixture cannot isolate configuration.' }
    $isolated = $launcherSource.Replace($needle, ('$cfgDir = ''' + $temp.Replace("'", "''") + ''''))
    $script = Join-Path $temp 'launcher.ps1'
    [IO.File]::WriteAllText($script, $isolated)
    Copy-Item -LiteralPath (Join-Path $InstalledRoot 'mcp-session-guard.mjs') -Destination $temp
    $reference = 'op://fixture/remote/token'
    [IO.File]::WriteAllText((Join-Path $temp 'mcp.env'), "DEVOPS_MCP_TOKEN=$reference")
    $dummy = 'synthetic-' + [guid]::NewGuid().ToString('N')
    $encrypted = ConvertFrom-SecureString (ConvertTo-SecureString $dummy -AsPlainText -Force)
    @{ createdUtc = [DateTime]::UtcNow.ToString('o'); values = @{ DEVOPS_MCP_TOKEN = $encrypted } } |
        ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $temp 'mcp-secrets.dpapi.json')
    $bin = Join-Path $temp 'mcp-runtime\node_modules\.bin'
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    $runtimeProxy = Join-Path $RuntimeRoot 'node_modules\mcp-remote\dist\proxy.js'
    if (-not (Test-Path -LiteralPath $runtimeProxy)) { throw 'Pinned proxy is absent.' }
    if ((Get-Content -Raw -LiteralPath (Join-Path $RuntimeRoot 'node_modules\mcp-remote\package.json') | ConvertFrom-Json).version -cne '0.1.38') { throw 'Synthetic proof requires pinned 0.1.38 runtime.' }
    $capture = Join-Path $temp 'capture.mjs'
    [IO.File]::WriteAllText($capture, @'
import { spawn } from 'node:child_process';
const proxy = process.argv[2];
const args = process.argv.slice(3);
const env = process.env.MCP_REMOTE_AUTH_HEADER || '';
const safe = args.includes('Authorization:${MCP_REMOTE_AUTH_HEADER}') && !args.some(v => v.includes(env) || v.includes(env.slice(7)));
const authorized = env.startsWith('Bearer synthetic-') && !process.env.DEVOPS_MCP_TOKEN && !process.env.NAS_MCP_TOKEN && !process.env.OP_SERVICE_ACCOUNT_TOKEN;
if (!safe || !authorized) process.exit(91);
const child = spawn(process.execPath, [proxy, ...args], {stdio: 'inherit', env: process.env});
child.on('exit', code => process.exit(code ?? 1));
'@)
    $serverScript = Join-Path $temp 'server.mjs'
    [IO.File]::WriteAllText($serverScript, @'
import http from 'node:http';
import fs from 'node:fs';
const expected = process.env.SYNTHETIC_EXPECTED;
const proof = process.argv[2];
const server = http.createServer((req, res) => {
  if (req.headers.authorization !== `Bearer ${expected}`) {res.writeHead(401);res.end();return;}
  if (req.method === 'GET') { res.writeHead(405);res.end();return; }
  let body = '';
  req.on('data', chunk => body += chunk);
  req.on('end', () => {
    let message;
    try { message = JSON.parse(body); } catch { res.writeHead(400);res.end();return; }
    fs.writeFileSync(proof, 'argv_safe=true server_authorized=true response_received=true');
    if (message.id === undefined) {res.writeHead(202);res.end();return;}
    const result = message.method === 'initialize'
      ? {protocolVersion: '2025-03-26', capabilities: {tools: {}}, serverInfo: {name: 'synthetic', version: '1'}}
      : message.method === 'tools/list' ? {tools: []} : {};
    res.writeHead(200, {'content-type': 'application/json'});
    res.end(JSON.stringify({jsonrpc:'2.0', id:message.id, result}));
  });
});
server.listen(0, '127.0.0.1', () => console.log(server.address().port));
'@)
    $node = (Get-Command node -ErrorAction Stop).Source
    [IO.File]::WriteAllText((Join-Path $bin 'mcp-remote.cmd'), "@echo off`r`n`"$node`" `"$capture`" `"$runtimeProxy`" %*`r`n")
    $proof = Join-Path $temp 'proof'
    $serverInfo = [Diagnostics.ProcessStartInfo]::new($node)
    $serverInfo.UseShellExecute = $false
    $serverInfo.RedirectStandardOutput = $true
    $serverInfo.RedirectStandardError = $true
    $serverInfo.ArgumentList.Add($serverScript)
    $serverInfo.ArgumentList.Add($proof)
    $serverInfo.Environment['SYNTHETIC_EXPECTED'] = $dummy
    $server = [Diagnostics.Process]::Start($serverInfo)
    $port = $server.StandardOutput.ReadLine()
    if ($port -notmatch '^\d+$') { throw 'Synthetic HTTP server failed.' }
    $url = "http://127.0.0.1:$port/mcp"
    $durableLauncher = Join-Path $temp 'mcp-remote-launch.cmd'
    $durableScript = Join-Path $temp 'mcp-secret-launch.ps1'
    Move-Item -LiteralPath $script -Destination $durableScript
    $hash = (Get-FileHash -LiteralPath $durableScript).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText($durableLauncher, (Get-McpNarrowRemoteLauncher $hash), [Text.Encoding]::ASCII)
    # Keep stdin alive during child startup; session guard intentionally kills
    # its child on EOF. No host MCP configuration or credential is consulted.
    $info = [Diagnostics.ProcessStartInfo]::new($env:ComSpec)
    $info.UseShellExecute = $false
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.Arguments = '/d /s /c ""' + $durableLauncher + '" "' + $url + '" "' + $reference + '""'
    foreach ($name in @('OP_SERVICE_ACCOUNT_TOKEN','DEVOPS_MCP_TOKEN','NAS_MCP_TOKEN','MCP_REMOTE_AUTH_HEADER')) { $info.Environment.Remove($name) | Out-Null }
    $info.Environment['DEVOPS_MCP_TOKEN'] = 'synthetic-stale-parent'
    $info.Environment['MCP_REMOTE_CONFIG_DIR'] = Join-Path $temp 'remote-auth'
    $process = [Diagnostics.Process]::Start($info)
    $process.StandardInput.WriteLine('{"jsonrpc":"2.0","id":100,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"proof","version":"1"}}}')
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    while (-not (Test-Path -LiteralPath $proof) -and -not $process.HasExited -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
    if (-not (Test-Path -LiteralPath $proof)) { throw 'Synthetic HTTP authentication was not observed.' }
    $process.StandardInput.Close()
    if (-not $process.WaitForExit(5000)) { $process.Kill($true); $process.WaitForExit(5000) | Out-Null }
    $output = $process.StandardOutput.ReadToEnd()
    $errors = $process.StandardError.ReadToEnd()
    if ([IO.File]::ReadAllText($proof) -cne 'argv_safe=true server_authorized=true response_received=true') { throw 'Synthetic launcher did not preserve authorization and safe process arguments.' }
    if ($output.Contains($dummy) -or $errors.Contains($dummy)) { throw 'Synthetic launcher emitted its dummy credential.' }
    $process.Dispose()
    $process = $null
    # An unavailable vault refresh must refuse launch, despite a stale parent.
    (Get-Item -LiteralPath (Join-Path $temp 'mcp-secrets.dpapi.json')).LastWriteTimeUtc = [DateTime]::UtcNow.AddHours(-1)
    Remove-Item -LiteralPath $proof
    $process = [Diagnostics.Process]::Start($info)
    if (-not $process.WaitForExit(10000)) { throw 'Missing vault authority did not fail promptly.' }
    if ($process.ExitCode -eq 0 -or (Test-Path -LiteralPath $proof)) { throw 'Unavailable vault refresh reused stale credentials.' }
    $process.Dispose()
    $process = $null
    Write-Host 'PASS: installed launcher executes guarded remote with dummy authorization and safe argv.'
} finally {
    foreach ($name in @('process','server')) {
        $variable = Get-Variable -Name $name -ErrorAction SilentlyContinue
        if ($variable -and $variable.Value) {
            try { if (-not $variable.Value.HasExited) { $variable.Value.Kill($true) } } catch { }
            $variable.Value.Dispose()
        }
    }
    Remove-Item -LiteralPath $temp -Recurse -Force
}
