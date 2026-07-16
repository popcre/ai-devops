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
#        - resolves each op:// reference in mcp.env into this shell's environment
#          (via `op read`, never overwriting a value that is already set).
#      and makes ~/.bashrc and ~/.profile source it (one include line).
#      There is NO `claude` launcher/wrapper: every CLI in the session (claude,
#      supabase, scripts, ...) is authorized by the exported environment, so
#      nothing shadows or re-invokes `claude`. (This header previously described
#      an `op run --env-file ... -- claude` launcher; that was never what the code
#      does, and the stale text caused a real misdiagnosis on 2026-07-16 — the
#      launcher was reasoned about as a rollout risk that does not exist.)
#      Cost to know: the snippet runs one `op read` per reference in mcp.env on
#      every interactive shell start (a network round-trip each), and the resolved
#      secrets live in that shell's environment.
#   5. Comments out any legacy RAW `export OP_SERVICE_ACCOUNT_TOKEN=ops_...`
#      lines and old per-app op-read blocks left in ~/.bashrc (with a backup),
#      so the only copy of the token on disk is the locked-down file.
#   6. Verifies every reference resolves (prints PASS/FAIL, never a value).
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
EXAMPLE="$REPO_ROOT/config/mcp.env.example"
VAULT="vibe_coding"

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

_aidevops_export_if_unset() {
  # \$1 = var name, \$2 = op:// reference. Never overwrites an existing value.
  eval "_aidev_cur=\\\${\$1:-}"
  [ -n "\$_aidev_cur" ] && return 0
  eval "export \$1=\"\\\$(op read \"\$2\" 2>/dev/null)\""
}

if command -v op >/dev/null 2>&1 && [ -n "\${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -f "$MCP_ENV" ]; then
  while IFS='=' read -r _aidev_name _aidev_ref; do
    case "\$_aidev_name" in ''|\\#*) continue ;; esac
    case "\$_aidev_ref"  in op://*) ;; *) continue ;; esac
    _aidevops_export_if_unset "\$_aidev_name" "\$_aidev_ref"
  done < "$MCP_ENV"
  unset _aidev_name _aidev_ref _aidev_cur
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

info "codex-cli MCP for Claude Code (~/.claude/settings.json)"
# Wire Codex's OWN `codex mcp-server` (official, stdio) so Claude can call Codex as
# a tool instead of shelling out. Deliberately NOT the third-party npx wrapper:
# native is version-locked to the CLI, needs no npx download, carries no extra
# supply chain, and — because we pin the absolute binary — cannot resolve to the
# wrong codex. It needs NO secret (Codex carries its own `codex login` session),
# so it is not wrapped in the op launcher and never touches mcp.env.
CODEX_BIN="$(command -v codex 2>/dev/null || true)"
CC_SETTINGS="$HOME/.claude/settings.json"
if [ -z "$CODEX_BIN" ]; then
  warn "codex not found on PATH — codex-cli MCP NOT configured."
  warn "  Install Codex, run: codex login, then re-run this script."
# Probe that python3 actually RUNS, not merely that something named python3 is on
# PATH: a stub/shim (e.g. Windows' Store alias) satisfies `command -v` and then
# fails on use. Presence != capability — that mistake is what this whole fix is about.
elif ! python3 -c 'import json' >/dev/null 2>&1; then
  warn "python3 present but not usable — cannot safely edit $CC_SETTINGS; skipped."
else
  mkdir -p "$(dirname "$CC_SETTINGS")"
  [ -f "$CC_SETTINGS" ] && cp "$CC_SETTINGS" "$CC_SETTINGS.aidevops.bak"
  if CODEX_BIN="$CODEX_BIN" CC_SETTINGS="$CC_SETTINGS" python3 - <<'PY'
import json, os, sys
path = os.environ["CC_SETTINGS"]
try:
    with open(path) as fh:
        cfg = json.load(fh)
except FileNotFoundError:
    cfg = {}
except json.JSONDecodeError:
    sys.stderr.write("existing settings.json is not valid JSON; refusing to overwrite\n")
    sys.exit(1)
if not isinstance(cfg, dict):
    sys.stderr.write("settings.json root is not an object; refusing\n")
    sys.exit(1)
# Preserve every other server and every other settings key.
cfg.setdefault("mcpServers", {})["codex-cli"] = {
    "command": os.environ["CODEX_BIN"],
    "args": ["mcp-server"],
    # Codex jobs run long; don't let the MCP call time out at the default.
    "env": {"MCP_TOOL_TIMEOUT": "3600000"},
}
with open(path, "w") as fh:
    json.dump(cfg, fh, indent=2)
    fh.write("\n")
PY
  then
    ok "codex-cli MCP -> native mcp-server ($CODEX_BIN)"
    warn "Restart Claude Code, then confirm codex-cli shows connected."
    warn "  Prove its sandbox can actually write:  ai-devops doctor"
  else
    warn "Could not update $CC_SETTINGS — left unchanged (backup: $CC_SETTINGS.aidevops.bak)"
  fi
fi

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
  if op read "$ref" >/dev/null 2>&1; then
    ok "PASS  $name"
  else
    warn "FAIL  $name  ($ref)"
    fail=1
  fi
done < "$MCP_ENV"

echo
if [ "$fail" -eq 0 ]; then
  info "Secrets wiring complete. Open a new terminal (or: source ~/.bashrc),"
  info "then run 'claude' in any app folder — placeholders fill automatically."
else
  warn "One or more references failed to resolve. Check the item ids in $MCP_ENV."
  exit 1
fi
