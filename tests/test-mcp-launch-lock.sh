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

grep -Fq '_aidev_exports="\$(flock -w 90 "$CFG_DIR/op-refresh.lock" op run' "$source_file" ||
  fail "MCP launcher does not limit the lock to secret resolution"
grep -Fq 'unset _aidev_names _aidev_exports' "$source_file" ||
  fail "MCP launcher leaves temporary secret-resolution variables behind"
grep -Fq 'exec "\$@"' "$source_file" ||
  fail "MCP launcher does not start the server after releasing the lock"

echo "PASS: Codex skill header and Linux MCP lock lifetime"
