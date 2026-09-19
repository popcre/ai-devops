#!/usr/bin/env python3
"""Render the bash scripts that setup-opencode-glm.ps1 generates on Windows.

The launcher and the scheduled-task service wrapper are both written from
PowerShell here-strings, so a quoting mistake there produces a broken shell
script that only fails on a Windows machine, in front of Albert. Rendering
them here lets `bash -n` catch that from Ubuntu. The service wrapper was
left unrendered once and its rewrite shipped with hand-verified-only
escaping (reviewed 2026-09-18); both are checked now, and the wrapper must
not regress to port 4096 while its sibling interpolates the installed port.
"""
import re, sys

src = open("bin/setup-opencode-glm.ps1", encoding="utf-8").read()
here_strings = re.findall(r'@"\n(#!/usr/bin/env bash\n.*?)\n"@', src, re.S)
if not here_strings:
    sys.exit("could not find any bash here-string in setup-opencode-glm.ps1")
launchers = [h for h in here_strings if "AI_GLM_LAUNCH_REEXEC" in h and "max_attempts" not in h]
wrappers = [h for h in here_strings if "max_attempts" in h]
if len(launchers) != 1:
    sys.exit(f"expected exactly one launcher here-string, found {len(launchers)}")
if len(wrappers) != 1:
    sys.exit(f"expected exactly one service-wrapper here-string, found {len(wrappers)}")

SUBST = {
    "$binaryBash": "/C/Users/u/.local/lib/ai-devops/opencode/1.18.12/node_modules/opencode-ai/bin/opencode.exe",
    "$homeBash":   "/C/Users/u",
    "$cfgBash":    "/C/Users/u/.config/ai-devops",
    "$gitBashFwd": "C:/Program Files/Git/bin/bash.exe",
    "$logFwd":     "/C/Users/u/.config/ai-devops/opencode/server.log",
    "$launchBash": "/C/Users/u/.local/bin/opencode-glm-launch",
    "$Port":       "4096",
}
BASH_VARS = {"AI_DEVOPS_CONFIG_DIR","HOME","CFG_DIR","TOKEN_FILE","MCP_ENV","OC_HOME",
             "XDG_CONFIG_HOME","XDG_DATA_HOME","XDG_STATE_HOME","XDG_CACHE_HOME",
             "ZAI_API_KEY","ZHIPU_API_KEY","AI_GLM_LAUNCH_REEXEC","OP_SERVICE_ACCOUNT_TOKEN",
             "OPENCODE_SERVER_USERNAME","OPENCODE_SERVER_PASSWORD","AI_GLM_PORT",
             "AI_GLM_ATTEMPT_TIMEOUT","port","attempt","max_attempts","attempt_timeout",
             "child","status","SECONDS","before","now","log","referenced","p","c","w","holder"}

# The only variable names permitted to appear bash-escaped (\$name) in rendered
# output. Each entry must have a positive assertion elsewhere in this file or in
# test-windows-scripts.sh proving the escaped form is the intended one.
ESCAPED_OK = {"_"}

def render(body):
    for name, value in SUBST.items():
        body = body.replace(name, value)
    # Only the backtick escape is normalized. A bare backslash-dollar is banned
    # by a separate grep guard in test-windows-scripts.sh, and stripping it here
    # would eat legitimate bash-escaped variables like the kill helper pipeline var.
    body = body.replace("`$", "$")
    if "`" in body:
        sys.exit("unresolved PowerShell backtick escape in the rendered script:\n  " +
                 "\n  ".join(l for l in body.splitlines() if "`" in l))
    # Two leak classes, both checked:
    #  - a BARE $var the renderer did not substitute (a PowerShell variable that
    #    would be expanded by bash) -- unless it is a declared bash variable;
    #  - a \$var escape -- legitimate ONLY for the intentionally escaped names
    #    below. An escape of any other name is just as much a leak: it means the
    #    here-string substitution was written for a variable that no longer
    #    exists (or was misspelled), and the silence is the danger.
    bare = [v for v in re.findall(r'(?<![\\])\$([A-Za-z_][A-Za-z0-9_]*)', body) if v not in BASH_VARS]
    escaped = [v for v in re.findall(r'\\\$([A-Za-z_][A-Za-z0-9_]*)', body) if v not in ESCAPED_OK]
    stray = bare + escaped
    if stray:
        sys.exit(f"PowerShell variable leaked into the rendered script unsubstituted: {sorted(set(stray))}")
    return body

out = render(launchers[0])
wrapper = render(wrappers[0])
# PS expands a bare $_ inside the double-quoted here-string to empty, silently
# gutting the generated kill helper (review finding, 2026-09-18). The stray-var
# check below now rejects it; assert the positive form too so the helper's
# presence is proven by more than its name.
if r"\$_" not in wrapper:
    sys.exit("kill_secret_children lost its PowerShell pipeline variable (bare $_ was expanded by the here-string)")
# Before substitution: the wrapper's port fallback must interpolate the installed
# $Port like its sibling the launcher does. A literal 4096 there makes the health
# probe ignore a non-default installed port and kill-loop a working server.
if '"${AI_GLM_PORT:-$Port}"' not in wrappers[0].replace("`$", "$"):
    sys.exit("service wrapper hardcodes its port fallback instead of interpolating $Port")
sys.stdout.write(out + "\n# --- rendered service wrapper (opencode-glm-service) ---\n" + wrapper)
