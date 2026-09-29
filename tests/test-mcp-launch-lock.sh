#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_file="$repo/bin/setup-secrets.sh"
skill_file="$repo/skills/codex/codex-transcript-miner/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }

first_line="$(sed -n '1p' "$skill_file")"
[[ "$first_line" == '---' ]] || fail "Codex transcript skill frontmatter is not first"

if grep -Fq 'exec flock -w 90 "$CFG_DIR/op-refresh.lock" op run' "$source_file"; then
  fail "MCP launcher still holds the refresh lock around the long-running server"
fi

# The serialized op call goes through one shared helper: the lock covers only
# the op command, closes before op's children, proves real contention with
# flock's conflict exit code before any sweep, and self-heals once through
# ai-lock-doctor before a single retry (#1002).
grep -Fq 'flock --close -E 87 -w 90 "$CFG_DIR/op-refresh.lock" "\$@"' "$source_file" ||
  fail "MCP launcher lock helper does not serialize exactly one op command with a conflict exit code"
grep -Fq '[ "\$_aidev_rc" -eq 87 ] || return "\$_aidev_rc"' "$source_file" ||
  fail "MCP launcher sweeps the lock without proving contention first"
grep -Fq 'ai-lock-doctor --recover --older-than 90 "$CFG_DIR/op-refresh.lock"' "$source_file" ||
  fail "MCP launcher lock helper has no bounded self-healing retry"
grep -Fq '_aidev_exports="\$(_aidev_flock op run' "$source_file" ||
  fail "MCP launcher does not limit the lock to secret resolution"
grep -Fq 'TOK="\$(_aidev_flock op read' "$source_file" ||
  fail "remote MCP launcher passes the refresh lock to 1Password"
grep -Fq 'unset _aidev_names _aidev_exports' "$source_file" ||
  fail "MCP launcher leaves temporary secret-resolution variables behind"
grep -Fq 'exec "\$@"' "$source_file" ||
  fail "MCP launcher does not start the server after releasing the lock"

echo "PASS: Codex skill header and Linux MCP lock lifetime"
