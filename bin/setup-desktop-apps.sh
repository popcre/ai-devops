#!/usr/bin/env bash
PY3="$(command -v python3 || command -v python)"
# setup-desktop-apps.sh — wire the ai-devops MCP servers into the Linux GUI
# apps: Claude Desktop (~/.config/Claude/claude_desktop_config.json) and the
# ChatGPT desktop app, whose Codex agent reads ~/.codex/config.toml.
# Linux counterpart of the Claude Desktop and Codex steps in setup-machine.ps1.
# Idempotent; safe to re-run.
#
# Server definitions come from the catalog setup-secrets.sh writes
# (~/.config/ai-devops/state/mcp-catalog.json), so run that first. Secrets are
# resolved by the launchers inside each definition: GUI apps started from the
# desktop menu never read ~/.bashrc.
#
# Membership ($ClaudeDesktopMcpNames, $McpProjectScope, $RetiredMcpServerNames)
# is read from bin/setup-machine.ps1 via bin/mcp_policy.py. Claude Desktop has no
# per-repository scope, so scoped servers never reach it.
# A running Claude Desktop writes its in-memory config back over the file, so
# while it runs nothing is written; a background waiter applies the change when
# the app quits. Codex gets the catalog minus scoped servers; entries the ChatGPT app wrote
# itself (node_repl, plugins, marketplaces) are left untouched.
#
# Usage:
#   setup-desktop-apps.sh             # apply now (Claude Desktop deferred if running)
#   setup-desktop-apps.sh --dry-run   # show what would change, write nothing
set -uo pipefail

CFG_DIR="${AI_DEVOPS_CONFIG:-$HOME/.config/ai-devops}"
CATALOG="$CFG_DIR/state/mcp-catalog.json"
CLAUDE_DESKTOP_CONFIG="${CLAUDE_DESKTOP_CONFIG:-$HOME/.config/Claude/claude_desktop_config.json}"
CODEX_CONFIG="${CODEX_CONFIG:-${CODEX_HOME:-$HOME/.codex}/config.toml}"
BIN="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
WAIT_LOG="$CFG_DIR/state/claude-desktop-mcp-sync.log"

DRY_RUN=0 WAIT=0 ONLY=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --wait-for-desktop-exit) WAIT=1 ;;
    --claude-only) ONLY=claude ;;
    --codex-only) ONLY=codex ;;
    -h|--help) grep '^#' "$0" | sed -n '2,20p' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

ok()   { printf '  ok %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; }

if [ ! -s "$CATALOG" ]; then
  warn "No MCP catalog at $CATALOG — run bin/setup-secrets.sh first. Nothing changed."
  exit 0
fi

claude_desktop_running() {
  case "${CLAUDE_DESKTOP_STATE:-}" in running) return 0 ;; stopped) return 1 ;; esac
  pgrep -x claude-desktop >/dev/null 2>&1
}

apply_claude_desktop() {
  "$PY3" - "$CLAUDE_DESKTOP_CONFIG" "$CATALOG" "$DRY_RUN" "$BIN" <<'PY'
import json, os, sys, time
path, catalog_path, dry = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
sys.path.insert(0, sys.argv[4]); import mcp_policy
pol = mcp_policy.policy()
names = [n for n in pol["desktop"] if n not in pol["scoped"]]
catalog = json.load(open(catalog_path))
managed = set(catalog) | set(pol["retired"]) | set(pol["scoped"]) | {"vercel"}
cfg = {}
if os.path.exists(path):
    try:
        cfg = json.load(open(path))
    except Exception as exc:
        sys.exit("refusing to overwrite unreadable %s (%s)" % (path, exc))
servers = cfg.setdefault("mcpServers", {})
wanted = {n: catalog[n] for n in names if n in catalog}
removed = [n for n in list(servers) if n in managed and n not in wanted]
unmanaged = [n for n in servers if n not in managed]
for n in removed:
    del servers[n]
servers.update(wanted)
print("  ok Claude Desktop MCP set: " + ", ".join(sorted(wanted)))
if removed: print("  ok removed undeclared: " + ", ".join(sorted(removed)))
for n in unmanaged: print("  [WARN] left unmanaged server in place: " + n)
if dry:
    print("  [dry-run] would write " + path)
    sys.exit(0)
if os.path.exists(path):
    backup = "%s.aidevops-%s.bak" % (path, time.strftime("%Y%m%d%H%M%S"))
    with open(path) as src, open(backup, "w") as dst: dst.write(src.read())
    print("  ok backup: " + backup)
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path + ".tmp", "w") as fh:
    json.dump(cfg, fh, indent=2); fh.write("\n")
os.replace(path + ".tmp", path)
PY
}

claude_desktop_step() {
  echo "Claude Desktop -> $CLAUDE_DESKTOP_CONFIG"
  if [ ! -d "$(dirname "$CLAUDE_DESKTOP_CONFIG")" ]; then
    warn "Claude Desktop not installed or never started here; skipped."
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then apply_claude_desktop; return; fi
  if claude_desktop_running; then
    if [ "$WAIT" -eq 0 ]; then
      mkdir -p "$(dirname "$WAIT_LOG")"
      nohup "$0" --claude-only --wait-for-desktop-exit >"$WAIT_LOG" 2>&1 &
      warn "Claude Desktop is open, so its MCP list was NOT changed yet."
      warn "  Fully quit it (tray icon > Quit); the change applies then."
      warn "  Result: $WAIT_LOG"
      return 0
    fi
    echo "Waiting for Claude Desktop to quit ..."
    deadline=$(( $(date +%s) + 3 * 24 * 3600 ))
    while claude_desktop_running; do
      [ "$(date +%s)" -lt "$deadline" ] || { warn "still running after 3 days; nothing written."; return 1; }
      sleep 15
    done
  fi
  apply_claude_desktop
}

apply_codex() {
  "$PY3" - "$CODEX_CONFIG" "$CATALOG" "$DRY_RUN" "$BIN" <<'PY'
import json, os, re, sys, time
path, catalog_path, dry = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
sys.path.insert(0, sys.argv[4]); import mcp_policy
pol = mcp_policy.policy()
remove = set(pol["scoped"]) | set(pol["retired"])
servers = {n: d for n, d in json.load(open(catalog_path)).items() if n not in remove}
if "codex-cli" in servers:
    # Parked on every machine since 2026-09-17; one `enabled` flip restores it.
    servers["codex-cli"].pop("env", None)
    servers["codex-cli"].update({"tool_timeout_sec": 3600, "enabled": False})

def s(v): return json.dumps(str(v))
def block(name, srv):
    out = ['[mcp_servers.%s]' % s(name)]
    for k in ("command", "url", "cwd"):
        if k in srv: out.append("%s = %s" % (k, s(srv[k])))
    if "args" in srv: out.append("args = [%s]" % ", ".join(s(a) for a in srv["args"]))
    if srv.get("env"):
        out.append("env = { %s }" % ", ".join("%s = %s" % (k, s(v)) for k, v in srv["env"].items()))
    for k in ("startup_timeout_sec", "tool_timeout_sec"):
        if k in srv: out.append("%s = %d" % (k, int(srv[k])))
    if "enabled" in srv: out.append("enabled = %s" % ("true" if srv["enabled"] else "false"))
    return out + [""]

head_re = re.compile(r'^\[mcp_servers\.(?:"([^"]+)"|([A-Za-z0-9_-]+))(\..+)?\]$')
old = open(path).read() if os.path.exists(path) else ""
segments, cur = [], (None, [])
for line in old.splitlines():
    if line.lstrip().startswith("["):
        segments.append(cur); cur = (line.strip(), [])
    else:
        cur[1].append(line)
segments.append(cur)

out, written = [], set()
for header, body in segments:
    m = head_re.match(header) if header else None
    name = (m.group(1) or m.group(2)) if m else None
    if name in remove:
        continue
    if name in servers:
        if name not in written:
            out += block(name, servers[name]); written.add(name)
        if m.group(3) is None or m.group(3) == ".env":
            continue  # replaced main table / stale env subtable
    if header: out.append(header)
    out += body
for name in servers:
    if name not in written:
        out += [""] + block(name, servers[name])
new = re.sub(r"\n{3,}", "\n\n", "\n".join(out)).strip("\n") + "\n"
print("  ok Codex MCP set: " + ", ".join(sorted(servers)))
if new == old:
    print("  ok already up to date"); sys.exit(0)
if dry:
    print("  [dry-run] would write " + path); sys.exit(0)
if old:
    backup = "%s.aidevops-%s.bak" % (path, time.strftime("%Y%m%d%H%M%S"))
    open(backup, "w").write(old)
    print("  ok backup: " + backup)
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path + ".tmp", "w") as fh: fh.write(new)
os.replace(path + ".tmp", path)
PY
}

codex_step() {
  echo "ChatGPT desktop / Codex -> $CODEX_CONFIG"
  if [ ! -d "$(dirname "$CODEX_CONFIG")" ]; then
    warn "No Codex home; ChatGPT desktop/Codex not set up here. Skipped."
    return 0
  fi
  apply_codex
}

rc=0
[ "$ONLY" = codex ]  || claude_desktop_step || rc=1
[ "$ONLY" = claude ] || codex_step || rc=1
[ "$WAIT" -eq 1 ] || echo "Restart Claude Desktop and ChatGPT fully for MCP changes to load."
exit "$rc"
