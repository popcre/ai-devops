#!/usr/bin/env bash
# One unresolvable 1Password reference (a rotated or renamed item) must not
# stop every MCP: the launcher skips that variable, names it, and starts.
set -euo pipefail
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T_DIR="$(mktemp -d)"; trap 'rm -rf "$T_DIR"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

CFG_DIR="$T_DIR/cfg"; MCP_ENV="$CFG_DIR/mcp.env"; TOKEN_FILE="$CFG_DIR/none"
NODE_BIN="$T_DIR/bin/fake-node"; GUARD_JS="$T_DIR/guard"
mkdir -p "$CFG_DIR" "$T_DIR/bin"
printf 'GOOD_A=op://v/a/credential\nBAD_B=op://v/gone/credential\nPLAIN=x\n' > "$MCP_ENV"

# Stub op: references containing "gone" do not exist.
cat > "$T_DIR/bin/op" <<'OP'
#!/usr/bin/env bash
if [ "$1" = read ]; then case "$3" in *gone*) exit 1;; *) printf 'val';; esac; exit 0; fi
shift; envf=""; while [ "$1" != -- ]; do case "$1" in --env-file=*) envf="${1#*=}";; esac; shift; done; shift
grep -q gone "$envf" && { echo "could not find item" >&2; exit 1; }
while IFS='=' read -r k v; do export "$k=resolved-$k"; done < "$envf"
exec "$@"
OP
printf '#!/bin/sh\nenv | grep -E "^(GOOD_A|BAD_B)=" | sort\n' > "$NODE_BIN"
chmod +x "$T_DIR/bin/op" "$NODE_BIN"

# Render the launcher heredoc exactly as setup-secrets.sh writes it.
body="$(sed -n '/cat > "\$LAUNCH_SH" <<EOF/,/^EOF$/p' "$repo/bin/setup-secrets.sh" | sed '1d;$d')"
eval "cat <<EOF
$body
EOF" > "$T_DIR/launch.sh"

out="$(env -u SUPABASE_ACCESS_TOKEN PATH="$T_DIR/bin:$PATH" sh "$T_DIR/launch.sh" 2>"$T_DIR/err")" ||
  fail "launcher stopped on one bad reference: $(cat "$T_DIR/err")"
[ "$out" = "GOOD_A=resolved-GOOD_A" ] || fail "unexpected environment: $out"
grep -q 'skipping BAD_B' "$T_DIR/err" || fail "bad reference was not named"

printf 'BAD_B=op://v/gone/credential\n' > "$MCP_ENV"
if env -u SUPABASE_ACCESS_TOKEN PATH="$T_DIR/bin:$PATH" sh "$T_DIR/launch.sh" 2>/dev/null; then
  fail "launcher started with no resolvable reference"
fi
echo "PASS: one bad 1Password reference is skipped and named; all-bad still fails"
