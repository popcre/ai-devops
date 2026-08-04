#!/usr/bin/env python3
"""Render the bash launcher that setup-opencode-glm.ps1 generates on Windows.

The launcher is written from a PowerShell here-string, so a quoting mistake there
produces a broken shell script that only fails on a Windows machine, in front of
Albert. Rendering it here lets `bash -n` catch that from Ubuntu.
"""
import re, sys

src = open("bin/setup-opencode-glm.ps1", encoding="utf-8").read()
m = re.search(r'@"\n(#!/usr/bin/env bash\n.*?)\n"@', src, re.S)
if not m:
    sys.exit("could not find the launcher here-string in setup-opencode-glm.ps1")

out = m.group(1)
for name, value in {
    "$binaryBash": "/C/Users/u/.local/lib/ai-devops/opencode/1.18.12/node_modules/opencode-ai/bin/opencode.exe",
    "$homeBash":   "/C/Users/u",
    "$cfgBash":    "/C/Users/u/.config/ai-devops",
    "$gitBashFwd": "C:/Program Files/Git/bin/bash.exe",
    "$Port":       "4096",
}.items():
    out = out.replace(name, value)
out = out.replace("`$", "$").replace("\\$", "$")

if "`" in out:
    sys.exit("unresolved PowerShell backtick escape in the rendered launcher:\n  " +
             "\n  ".join(l for l in out.splitlines() if "`" in l))
stray = [v for v in re.findall(r'\$([A-Za-z_][A-Za-z0-9_]*)', out)
         if v not in {"AI_DEVOPS_CONFIG_DIR","HOME","CFG_DIR","TOKEN_FILE","MCP_ENV","OC_HOME",
                      "XDG_CONFIG_HOME","XDG_DATA_HOME","XDG_STATE_HOME","XDG_CACHE_HOME",
                      "ZAI_API_KEY","ZHIPU_API_KEY","AI_GLM_LAUNCH_REEXEC","OP_SERVICE_ACCOUNT_TOKEN",
                      "OPENCODE_SERVER_USERNAME","OPENCODE_SERVER_PASSWORD","AI_GLM_PORT","0","@"}]
if stray:
    sys.exit(f"PowerShell variable leaked into the launcher unsubstituted: {sorted(set(stray))}")
sys.stdout.write(out)
