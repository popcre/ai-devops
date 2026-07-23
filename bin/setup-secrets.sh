#!/usr/bin/env bash
# setup-secrets.sh — wire up automatic, vault-locked secret resolution for
# Claude Code on this Ubuntu machine. Idempotent; safe to re-run.
#
# What it does (nothing here is a secret except the one token you paste once):
#   1. Verifies the `op` (1Password) CLI is installed.
#   2. Stores the vault-locked 1Password SERVICE-ACCOUNT token ONCE, locked
#      down at ~/.config/ai-devops/op-service-account (chmod 600). This token
#      can only ever read the `vibe_coding` vault — nothing else.
#   3. Installs the central reference file  ~/.config/ai-devops/mcp.env  from
#      this repo's config/mcp.env.example (op:// references, never values).
#   4. Installs a managed shell snippet ~/.config/ai-devops/shellrc that:
#        - exports OP_SERVICE_ACCOUNT_TOKEN from the locked-down file, and
#        - resolves all op:// references in one `op run` invocation (never
#          overwriting a value that is already set).
#      and makes ~/.bashrc and ~/.profile source it (one include line).
#      There is NO `claude` launcher/wrapper: every CLI in the session (claude,
#      supabase, scripts, ...) is authorized by the exported environment, so
#      nothing shadows or re-invokes `claude`. (This header previously described
#      an `op run --env-file ... -- claude` launcher; that was never what the code
#      does, and the stale text caused a real misdiagnosis on 2026-07-16 — the
#      launcher was reasoned about as a rollout risk that does not exist.)
#      Cost to know: one shared refresh runs per interactive shell start, and the
#      resolved secrets live in that shell's environment.
#   5. Installs two MCP launchers (~/.config/ai-devops/mcp-launch.sh and
#      mcp-remote-launch.sh) so each MCP server resolves its own secrets at
#      launch, independent of whether the session sourced .bashrc.
#   6. Merges the FULL MCP server set into ~/.claude/settings.json — the same set
#      bin/setup-machine.ps1 installs on Windows, so every machine and both
#      surfaces agree. Only our own mcpServers keys are touched; permissions,
#      hooks, plugins and any other server are preserved untouched.
#   7. Comments out any legacy RAW `export OP_SERVICE_ACCOUNT_TOKEN=ops_...`
#      lines and old per-app op-read blocks left in ~/.bashrc (with a backup),
#      so the only copy of the token on disk is the locked-down file.
#   8. Verifies every reference resolves (prints PASS/FAIL, never a value).
#
# Usage:
#   setup-secrets.sh                 # set up / refresh
#   setup-secrets.sh --dry-run       # show what would change, do nothing
#   setup-secrets.sh --no-legacy     # skip the ~/.bashrc legacy cleanup
#   OP_SERVICE_ACCOUNT_TOKEN=ops_... setup-secrets.sh   # non-interactive token
#
# The token can only be scoped to one vault; there is no way for it to read any
# other 1Password vault or login. That is the whole point.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CFG_DIR="${AI_DEVOPS_CONFIG:-$HOME/.config/ai-devops}"
TOKEN_FILE="$CFG_DIR/op-service-account"
MCP_ENV="$CFG_DIR/mcp.env"
SHELLRC="$CFG_DIR/shellrc"
LAUNCH_SH="$CFG_DIR/mcp-launch.sh"
REMOTE_SH="$CFG_DIR/mcp-remote-launch.sh"
EXAMPLE="$REPO_ROOT/config/mcp.env.example"
VAULT="vibe_coding"
CLAUDE_SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
# The one shared POP production project. Overridable, never hard-coded downstream.
SUPABASE_PROJECT_REF="${SUPABASE_PROJECT_REF:-<removed-protected-project-ref>}"

DRY_RUN=0
DO_LEGACY=1
for arg in "$@"; do
  case "$arg" in
    --dry-run)   DRY_RUN=1 ;;
    --no-legacy) DO_LEGACY=0 ;;
    -h|--help)   grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown flag: $arg" >&2; exit 2 ;;
  esac
done

info() { printf '\033[1m==>\033[0m %s\n' "$1"; }
ok()   { printf '\033[32m  ok\033[0m %s\n' "$1"; }
warn() { printf '\033[33m[WARN]\033[0m %s\n' "$1"; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then echo "[dry-run] $*"; else eval "$*"; fi }

# --------------------------------------------------------------------------
# 1. op CLI present?
# --------------------------------------------------------------------------
info "Checking the 1Password CLI (op)"
if ! command -v op >/dev/null 2>&1; then
  warn "op is not installed."
  if command -v apt-get >/dev/null 2>&1; then
    warn "On managed Ubuntu hosts this is installed by ansible (1password-cli)."
    warn "To install by hand, follow: https://developer.1password.com/docs/cli/get-started/"
  fi
  warn "Install op, then re-run this script."
  exit 1
fi
ok "op $(op --version 2>/dev/null)"

# --------------------------------------------------------------------------
# 2. The one bootstrap secret: the service-account token
# --------------------------------------------------------------------------
info "Service-account token (vault-locked to '$VAULT')"
mkdir -p "$CFG_DIR"; chmod 700 "$CFG_DIR" 2>/dev/null || true

existing_token=""
[ -s "$TOKEN_FILE" ] && existing_token="$(cat "$TOKEN_FILE")"

token="${OP_SERVICE_ACCOUNT_TOKEN:-}"
if [ -n "$existing_token" ] && [ -z "$token" ]; then
  token="$existing_token"
  ok "Reusing token already stored at $TOKEN_FILE"
fi

if [ -z "$token" ]; then
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] would prompt you to paste the service-account token"
  elif [ -t 0 ]; then
    echo "Paste the 1Password service-account token for vault '$VAULT'."
    echo "(It starts with 'ops_'. Input is hidden. You do this once per machine.)"
    printf 'Token: '
    read -rs token; echo
  else
    warn "No token found and not an interactive terminal."
    warn "Re-run interactively, or pass OP_SERVICE_ACCOUNT_TOKEN=ops_... to this script."
    exit 1
  fi
fi

if [ -z "$token" ]; then
  warn "No token provided; aborting."
  exit 1
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] would write the token to $TOKEN_FILE (chmod 600)"
else
  umask 077
  printf '%s\n' "$token" > "$TOKEN_FILE"
  chmod 600 "$TOKEN_FILE"
  ok "Token stored at $TOKEN_FILE (chmod 600)"
fi

# Make the token available to op for the verification + resolution below.
export OP_SERVICE_ACCOUNT_TOKEN="$token"

# Sanity: the token must actually be a service account (scoped), not personal.
who="$(op whoami 2>/dev/null | tr -d '\r')"
if printf '%s' "$who" | grep -qi 'SERVICE_ACCOUNT'; then
  ok "Token authenticates as a scoped SERVICE ACCOUNT"
else
  warn "op whoami did not confirm a service account. Check the token."
fi

# --------------------------------------------------------------------------
# 3. Central reference file
# --------------------------------------------------------------------------
info "Central references -> $MCP_ENV"
if [ ! -f "$EXAMPLE" ]; then
  warn "Missing $EXAMPLE; cannot install mcp.env"; exit 1
fi
if [ -f "$MCP_ENV" ] && cmp -s "$EXAMPLE" "$MCP_ENV"; then
  ok "mcp.env already current"
else
  run "cp '$EXAMPLE' '$MCP_ENV'"
  ok "Installed/updated mcp.env from repo (references only, no secrets)"
fi

# --------------------------------------------------------------------------
# 4. Managed shell snippet + include lines
# --------------------------------------------------------------------------
info "Shell snippet -> $SHELLRC"
read -r -d '' SHELLRC_BODY <<EOF
# >>> ai-devops secrets (managed by setup-secrets.sh — do not edit by hand) >>>
# POSIX sh + bash safe. Sourced from ~/.bashrc and ~/.profile.
#
# Load the vault-locked 1Password service-account token (vibe_coding vault
# ONLY — it cannot read anything else) and resolve every central reference in
# mcp.env into this shell's environment. This authorizes not just 'claude' but
# every CLI (supabase, scripts, ...) in the session, with no special launcher.
if [ -s "$TOKEN_FILE" ]; then
  export OP_SERVICE_ACCOUNT_TOKEN="\$(cat "$TOKEN_FILE")"
fi

if command -v op >/dev/null 2>&1 && [ -n "\${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -f "$MCP_ENV" ]; then
  _aidev_names="\$(sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=op:\/\/.*/\1/p' "$MCP_ENV" | tr '\n' ' ')"
  _aidev_exports="\$(op run --no-masking --env-file="$MCP_ENV" -- python3 -c '
import os, shlex, sys
for name in sys.argv[1:]:
    value = os.environ.get(name, "")
    if not value:
        raise SystemExit("empty 1Password value: " + name)
    print("export %s=%s" % (name, shlex.quote(value)))
' \$_aidev_names 2>/dev/null)" && eval "\$_aidev_exports" ||
    echo "ai-devops: one-shot 1Password environment refresh failed" >&2
  unset _aidev_names _aidev_exports
fi
# <<< ai-devops secrets <<<
EOF

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] would write managed snippet to $SHELLRC"
else
  printf '%s\n' "$SHELLRC_BODY" > "$SHELLRC"
  ok "Wrote $SHELLRC"
fi

# Ensure ~/.bashrc and ~/.profile source it exactly once.
INCLUDE_LINE="[ -f \"$SHELLRC\" ] && . \"$SHELLRC\"  # ai-devops secrets"
ensure_include() {
  local rc="$1"
  [ -e "$rc" ] || { run "touch '$rc'"; }
  if grep -qF "$SHELLRC" "$rc" 2>/dev/null; then
    ok "$rc already sources the snippet"
  else
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[dry-run] would append include line to $rc"
    else
      printf '\n%s\n' "$INCLUDE_LINE" >> "$rc"
      ok "Added include line to $rc"
    fi
  fi
}
ensure_include "$HOME/.bashrc"
ensure_include "$HOME/.profile"

# --------------------------------------------------------------------------
# 4b. MCP launchers (mirror of the Windows setup-machine.ps1 launchers)
# --------------------------------------------------------------------------
# The shell snippet above authorizes interactive shells, but Claude Code can be
# started from places that never source .bashrc. These launchers make each MCP
# server resolve its own secrets at launch, so a server never depends on how the
# session happened to start, and no token is written into any config file.
info "MCP launchers -> $LAUNCH_SH, $REMOTE_SH"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] would write $LAUNCH_SH and $REMOTE_SH"
else
  cat > "$LAUNCH_SH" <<EOF
#!/usr/bin/env sh
# [ai-devops] managed by setup-secrets.sh — do not edit by hand.
# Reuses the one-shot shell environment. The fallback is locked so simultaneous
# non-login MCP startups cannot create a parallel 1Password request storm.
if [ -s "$TOKEN_FILE" ]; then
  OP_SERVICE_ACCOUNT_TOKEN="\$(cat "$TOKEN_FILE")"
  export OP_SERVICE_ACCOUNT_TOKEN
fi
if [ -n "\${SUPABASE_ACCESS_TOKEN:-}" ] && [ -n "\${TRIGGER_ACCESS_TOKEN:-}" ]; then
  exec "\$@"
fi
exec flock -w 90 "$CFG_DIR/op-refresh.lock" op run --no-masking --env-file="$MCP_ENV" -- "\$@"
EOF
  chmod 755 "$LAUNCH_SH"
  ok "Wrote $LAUNCH_SH"

  cat > "$REMOTE_SH" <<EOF
#!/usr/bin/env sh
# [ai-devops] managed by setup-secrets.sh — do not edit by hand.
# \$1 = server URL, \$2 = op:// ref to the bearer token, \$3+ = extra mcp-remote flags.
# mcp-remote does NOT expand \\\${VAR} in --header, so the token must be a real value
# before it runs: resolve it in memory here and pass it straight through.
if [ -s "$TOKEN_FILE" ]; then
  OP_SERVICE_ACCOUNT_TOKEN="\$(cat "$TOKEN_FILE")"
  export OP_SERVICE_ACCOUNT_TOKEN
fi
URL="\$1"; REF="\$2"; shift 2
case "\$REF" in
  op://vibe_coding/designflow-mcp/devops_token) TOK="\${DEVOPS_MCP_TOKEN:-}" ;;
  op://vibe_coding/designflow-mcp/nas_token) TOK="\${NAS_MCP_TOKEN:-}" ;;
  op://vibe_coding/6dqxnqdx2nwcuyeppvsb6nvkoq/password) TOK="\${RECALL_AI_MCP_TOKEN:-}" ;;
  *) TOK= ;;
esac
[ -n "\$TOK" ] || TOK="\$(flock -w 90 "$CFG_DIR/op-refresh.lock" op read "\$REF")" || {
  echo "ai-devops: serialized fallback FAILED for \$REF — not starting \$URL" >&2
  exit 1
}
[ -n "\$TOK" ] || {
  echo "ai-devops: \$REF resolved EMPTY — not starting \$URL" >&2
  exit 1
}
exec npx -y mcp-remote "\$URL" --header "Authorization: Bearer \$TOK" "\$@"
EOF
  chmod 755 "$REMOTE_SH"
  ok "Wrote $REMOTE_SH"
fi

# --------------------------------------------------------------------------
# 4c. The MCP server set for Claude Code (same set as Windows)
# --------------------------------------------------------------------------
# Ubuntu previously wired NO servers at all: this script only handled secrets and
# left server definitions to each app's own .mcp.json, so a machine ended up with
# whatever happened to be there (hetz: 'github' for root, 'codex-cli' for ai) and
# nothing else. This installs the same set bin/setup-machine.ps1 installs on
# Windows, so every machine and both surfaces agree.
#
# Only the mcpServers keys we define are touched. permissions, hooks,
# enabledPlugins, extraKnownMarketplaces and any server we do not define are
# preserved exactly as found.
info "MCP servers -> $CLAUDE_SETTINGS"
CODEX_BIN="$(command -v codex 2>/dev/null || true)"
[ -n "$CODEX_BIN" ] || warn "codex not found on PATH — codex-cli MCP will be skipped."

# Probe that python3 actually RUNS, not merely that something named python3 is on
# PATH: a stub/shim (e.g. Windows' Store alias) satisfies `command -v` and then
# fails on use. Presence != capability.
if ! python3 -c 'import json' >/dev/null 2>&1; then
  warn "python3 present but not usable — cannot safely edit $CLAUDE_SETTINGS; skipped."
  warn "  No MCP servers were wired. Install a working python3 and re-run."
elif [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] would merge the MCP server set into $CLAUDE_SETTINGS"
else
  mkdir -p "$(dirname "$CLAUDE_SETTINGS")"
  [ -f "$CLAUDE_SETTINGS" ] && cp "$CLAUDE_SETTINGS" "$CLAUDE_SETTINGS.aidevops.bak"
  python3 - "$CLAUDE_SETTINGS" "$LAUNCH_SH" "$REMOTE_SH" "$SUPABASE_PROJECT_REF" "$CODEX_BIN" <<'PY'
import json, os, sys

path, launch, remote, supa_ref, codex = sys.argv[1:6]

cfg = {}
if os.path.exists(path):
    try:
        with open(path) as fh:
            cfg = json.load(fh)
    except Exception as exc:
        # Never silently rebuild a config we failed to read — that would delete
        # the user's permissions/hooks. Fail loudly and change nothing.
        sys.stderr.write("ai-devops: %s is not valid JSON (%s).\n" % (path, exc))
        sys.stderr.write("ai-devops: refusing to overwrite it. Fix or move it, then re-run.\n")
        sys.exit(1)

servers = {
    # stdio + secrets: launched under `op run`, which injects the mcp.env refs.
    # --read-only is mandatory: all shared-DB schema work goes through the
    # u2giants/shared-db repo (branch + PR), never through this MCP.
    "supabase": {"command": launch, "args": [
        "npx", "-y", "@supabase/mcp-server-supabase@latest",
        "--read-only", "--project-ref", supa_ref]},
    "trigger": {"command": launch, "args": [
        "npx", "-y", "trigger.dev@latest", "mcp"]},
    "1password": {"command": launch, "args": [
        "npx", "-y", "@u2giants/1password-mcp"]},

    # remote/HTTP: the launcher resolves the bearer token from 1Password in
    # memory, so only the URL + op:// reference appear here.
    "devops-mcp": {"command": remote, "args": [
        "https://mcp.designflow.app/mcp",
        "op://vibe_coding/designflow-mcp/devops_token"]},
    "synology-monitor": {"command": remote, "args": [
        "https://nas-mcp.designflow.app/mcp",
        "op://vibe_coding/designflow-mcp/nas_token"]},
    "recall-ai": {"command": remote, "args": [
        "https://us-east-1.recall.ai/mcp",
        "op://vibe_coding/6dqxnqdx2nwcuyeppvsb6nvkoq/password",
        "--transport", "http-first"]},

    # no secret at all. vercel authenticates via mcp-remote's browser OAuth flow,
    # so it must NOT go through the remote launcher (that would force a header).
    "playwright": {"command": "npx", "args": ["-y", "@playwright/mcp@latest"]},
    "ag-grid":    {"command": "npx", "args": ["-y", "ag-mcp"]},
    "vercel":     {"command": "npx", "args": ["-y", "mcp-remote@latest",
                                              "https://mcp.vercel.com"]},
}

# codex-cli: Codex carries its own `codex login` session, so no launcher and no
# token. Absolute path, not "codex", so it cannot resolve to a different binary.
if codex:
    servers["codex-cli"] = {
        "command": codex,
        "args": ["mcp-server"],
        "env": {"MCP_TOOL_TIMEOUT": "3600000"},
    }

cfg.setdefault("mcpServers", {}).update(servers)
with open(path, "w") as fh:
    json.dump(cfg, fh, indent=2)
    fh.write("\n")
print("  ok wired: " + ", ".join(servers))
PY
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "Merged the MCP server set into $CLAUDE_SETTINGS"
    [ -f "$CLAUDE_SETTINGS.aidevops.bak" ] && ok "Backup: $CLAUDE_SETTINGS.aidevops.bak"
  else
    warn "Did NOT wire MCP servers (see the error above). Nothing was changed."
  fi
fi

# --------------------------------------------------------------------------
# 5. Legacy cleanup: neutralize raw tokens / old per-app blocks in ~/.bashrc
# --------------------------------------------------------------------------
if [ "$DO_LEGACY" -eq 1 ]; then
  info "Legacy cleanup in ~/.bashrc (raw tokens / old op-read blocks)"
  BRC="$HOME/.bashrc"
  if [ -f "$BRC" ] && grep -qE '^[[:space:]]*export OP_SERVICE_ACCOUNT_TOKEN=ops_|POPDAM MCP token injection' "$BRC"; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[dry-run] would back up ~/.bashrc and comment out legacy raw-token / op-read lines"
    else
      cp "$BRC" "$BRC.aidevops.bak.$(date +%Y%m%d-%H%M%S)"
      # Neutralize old lines by replacing them with `true` (a valid no-op), NOT a
      # bare comment: these lines can live INSIDE `if ... then ... fi` blocks, and
      # a then-block left with only comments is a shell syntax error. `true` keeps
      # every block valid while disabling the old behavior.
      #
      # Raw service-account token exports — removed entirely (never echo the value).
      sed -i -E "s|^([[:space:]]*)export OP_SERVICE_ACCOUNT_TOKEN=ops_.*\$|\1true  # [ai-devops] raw service-account token removed; now in $TOKEN_FILE|" "$BRC"
      # Old per-app op-read exports for the MCP tokens — now resolved via mcp.env.
      sed -i -E 's|^([[:space:]]*)export (SUPABASE_ACCESS_TOKEN\|DEVOPS_MCP_TOKEN\|NAS_MCP_TOKEN)="\$\(op read .*$|\1true  # [ai-devops] \2 now resolved from mcp.env|' "$BRC"
      ok "Backed up ~/.bashrc and neutralized legacy raw-token / op-read lines"
      warn "Old .bashrc kept as $BRC.aidevops.bak.* — delete once you've confirmed things work."
    fi
  else
    ok "No legacy raw tokens / op-read blocks found"
  fi
else
  info "Skipping legacy cleanup (--no-legacy)"
fi

# --------------------------------------------------------------------------
# 6. Verify every reference resolves (PASS/FAIL only, never a value)
# --------------------------------------------------------------------------
info "Token-free check: raw OP token inside ~/.claude/settings.json"
# The stated goal is that the ONLY copy of the service-account token on disk is the
# locked-down file ($TOKEN_FILE, chmod 600). Claude Code's settings.json can also
# carry it under "env", and step 5 above only cleaned ~/.bashrc — so a raw token was
# surviving there unnoticed (found on hetz 2026-07-16).
#
# Why it matters even though settings.json is chmod 600 like the token file: a
# config file is FAR more likely to be dumped, pasted into a chat, copied, or backed
# up than a dotfile named op-service-account. That is not hypothetical — an AI
# session leaked this exact token into its own transcript on 2026-07-16 by printing
# settings.json.
#
# Safe to remove because the managed shellrc already exports OP_SERVICE_ACCOUNT_TOKEN
# from $TOKEN_FILE in ~/.bashrc AND ~/.profile, so any shell-launched `claude` still
# gets it. TRADE-OFF, know this: a claude launched WITHOUT shell init (non-interactive
# `ssh host claude ...`, systemd, cron) would no longer see the token and will fail to
# authenticate — loudly, not silently. If you need that, keep the entry and accept the
# second copy.
CC_SETTINGS_TOKEN="$HOME/.claude/settings.json"
if [ ! -f "$CC_SETTINGS_TOKEN" ]; then
  ok "no settings.json yet — nothing to clean"
elif ! python3 -c 'import json' >/dev/null 2>&1; then
  warn "python3 unusable — cannot check $CC_SETTINGS_TOKEN for a raw token"
else
  CC_SETTINGS_TOKEN="$CC_SETTINGS_TOKEN" python3 - <<'PY'
import json, os, shutil, sys
path = os.environ["CC_SETTINGS_TOKEN"]
try:
    with open(path) as fh:
        cfg = json.load(fh)
except Exception as exc:                      # noqa: BLE001 - report, never clobber
    print(f"  [WARN] could not parse {path} ({exc}); left untouched")
    sys.exit(0)
env = cfg.get("env")
if not isinstance(env, dict) or "OP_SERVICE_ACCOUNT_TOKEN" not in env:
    print("  ok no raw OP_SERVICE_ACCOUNT_TOKEN in settings.json")
    sys.exit(0)
shutil.copy2(path, path + ".aidevops.tokenclean.bak")
del env["OP_SERVICE_ACCOUNT_TOKEN"]
if not env:
    cfg.pop("env", None)                      # don't leave an empty env block
with open(path, "w") as fh:
    json.dump(cfg, fh, indent=2)
    fh.write("\n")
print("  ok removed raw OP_SERVICE_ACCOUNT_TOKEN from settings.json")
print(f"  ok backup: {path}.aidevops.tokenclean.bak  (DELETE IT — it still holds the token)")
PY
fi

# NOTE: codex-cli used to be wired by its own separate step here. It is now part of
# the one server set in step 4c, so this step was removed: two steps writing the
# same key to the same file is exactly the drift this script is fixing. The old one
# also hard-coded ~/.claude/settings.json and so ignored $CLAUDE_SETTINGS.

echo
info "Verifying references resolve from 1Password (no values printed)"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] would verify each op:// reference resolves"
  info "Dry run complete — nothing was changed."
  exit 0
fi
fail=0
while IFS= read -r line; do
  case "$line" in
    ''|\#*) continue ;;
  esac
  ref="${line#*=}"
  case "$ref" in
    op://*) ;;
    *) continue ;;
  esac
  name="${line%%=*}"
  # Reject an EMPTY resolved value, not just a nonzero exit. `op read` of a blank
  # 1Password field returns "" with exit 0 (a silent empty) — that is exactly what
  # sent the GLM launcher into an unbounded re-exec loop. Treat empty as FAIL so
  # a mis-pointed reference is caught here, at setup, not at runtime.
  val="$(op read "$ref" 2>/dev/null)"
  if [ -n "$val" ]; then
    ok "PASS  $name"
  else
    warn "FAIL  $name  ($ref)  — resolved EMPTY or unreadable"
    fail=1
  fi
done < "$MCP_ENV"

echo
if [ "$fail" -eq 0 ]; then
  if command -v claude >/dev/null 2>&1 && [ -x "$REPO_ROOT/bin/ai-glm-agent" ]; then
    info "Verifying GLM coding agent end-to-end"
    glm_probe="$(mktemp)"
    if "$REPO_ROOT/bin/ai-glm-agent" --mode review --output "$glm_probe" \
        "Reply with exactly GLM_AGENT_OK and nothing else." >/dev/null &&
        [ "$(tr -d '\r\n' <"$glm_probe")" = "GLM_AGENT_OK" ]; then
      ok "GLM-5.2 coding agent verified through Claude Code and Z.ai"
    else
      rm -f "$glm_probe"
      warn "GLM coding-agent capability check failed"
      exit 1
    fi
    rm -f "$glm_probe"
  else
    warn "Claude Code is missing; GLM agent cannot be capability-tested yet."
  fi
  info "Secrets wiring complete. Open a new terminal (or: source ~/.bashrc),"
  info "then run 'claude' in any app folder — placeholders fill automatically."
else
  warn "One or more references failed to resolve. Check the item ids in $MCP_ENV."
  exit 1
fi
