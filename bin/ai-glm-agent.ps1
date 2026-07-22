[CmdletBinding()]
param(
    [ValidateSet("review", "implement")][string]$Mode = "review",
    [string]$Model = $(if ($env:ZAI_GLM_MODEL) { $env:ZAI_GLM_MODEL } else { "glm-5.2" }),
    [string]$PromptFile,
    [string]$Output,
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Prompt
)

$ErrorActionPreference = "Stop"
$cfgDir = if ($env:AI_DEVOPS_CONFIG_DIR) { $env:AI_DEVOPS_CONFIG_DIR } else { Join-Path $HOME ".config\ai-devops" }
$tokenFile = Join-Path $cfgDir "op-service-account"
$mcpEnv = Join-Path $cfgDir "mcp.env"

if ([string]::IsNullOrWhiteSpace($env:ZAI_API_KEY)) {
    if (-not (Get-Command op -ErrorAction SilentlyContinue)) { throw "1Password CLI (op) is required." }
    if (-not (Test-Path -LiteralPath $tokenFile)) { throw "Missing 1Password service-account token file: $tokenFile" }
    if (-not (Test-Path -LiteralPath $mcpEnv)) { throw "Missing managed 1Password reference file: $mcpEnv" }
    $env:OP_SERVICE_ACCOUNT_TOKEN = (Get-Content -Raw -LiteralPath $tokenFile).Trim()
    $childArgs = @("run", "--env-file", $mcpEnv, "--", "pwsh", "-NoProfile", "-File", $PSCommandPath, "-Mode", $Mode, "-Model", $Model)
    if ($PromptFile) { $childArgs += @("-PromptFile", $PromptFile) }
    if ($Output) { $childArgs += @("-Output", $Output) }
    if ($Prompt) { $childArgs += $Prompt }
    & op @childArgs
    exit $LASTEXITCODE
}

if ($PromptFile) {
    if (-not (Test-Path -LiteralPath $PromptFile)) { throw "Prompt file not found: $PromptFile" }
    $promptText = Get-Content -Raw -LiteralPath $PromptFile
} elseif ($Prompt) {
    $promptText = $Prompt -join " "
} elseif ([Console]::IsInputRedirected) {
    $promptText = [Console]::In.ReadToEnd()
} else {
    throw "Provide prompt text, -PromptFile, or stdin."
}
if ([string]::IsNullOrWhiteSpace($promptText)) { throw "Prompt is empty." }
if (-not (Get-Command claude -ErrorAction SilentlyContinue)) { throw "Claude Code CLI is required to host the GLM agent." }

Remove-Item Env:CLAUDECODE -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
$env:ANTHROPIC_AUTH_TOKEN = $env:ZAI_API_KEY
$env:ANTHROPIC_BASE_URL = if ($env:ZAI_ANTHROPIC_BASE_URL) { $env:ZAI_ANTHROPIC_BASE_URL } else { "https://api.z.ai/api/anthropic" }
$env:ANTHROPIC_DEFAULT_OPUS_MODEL = $Model
$env:ANTHROPIC_DEFAULT_SONNET_MODEL = $Model
$env:ANTHROPIC_DEFAULT_HAIKU_MODEL = $Model
$env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1"
$env:CLAUDE_CONFIG_DIR = if ($env:ZAI_CLAUDE_CONFIG_DIR) { $env:ZAI_CLAUDE_CONFIG_DIR } else { Join-Path $cfgDir "glm-claude" }
New-Item -ItemType Directory -Force -Path $env:CLAUDE_CONFIG_DIR | Out-Null

$permissionMode = if ($Mode -eq "implement") { "auto" } else { "plan" }
$rawFile = [System.IO.Path]::GetTempFileName()
try {
    $promptText | & claude -p --model $Model --permission-mode $permissionMode `
        --setting-sources project,local --no-session-persistence --output-format json |
        Set-Content -LiteralPath $rawFile -Encoding utf8
    if ($LASTEXITCODE -ne 0) { throw "GLM agent process failed with exit code $LASTEXITCODE." }
    $response = Get-Content -Raw -LiteralPath $rawFile | ConvertFrom-Json
    if ($response.is_error) { throw "GLM agent returned an error: $($response.result)" }
    $actualModel = @($response.modelUsage.PSObject.Properties.Name)[0]
    if ($actualModel -ne $Model) { throw "Requested model '$Model' but Z.ai returned '$actualModel'. No fallback accepted." }
    if ($Output) {
        $parent = Split-Path -Parent $Output
        if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
        Set-Content -LiteralPath $Output -Value $response.result -Encoding utf8
        Write-Host "GLM $actualModel result written to: $Output"
    } else {
        Write-Output $response.result
    }
} finally {
    Remove-Item -LiteralPath $rawFile -Force -ErrorAction SilentlyContinue
}
