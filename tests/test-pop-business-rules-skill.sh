#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/skills/shared/pop-business-rules/SKILL.md"

fail() { echo "FAIL: $*" >&2; exit 1; }
require() { grep -Fq -- "$1" "$SKILL" || fail "missing required contract: $1"; }

[[ -f "$SKILL" ]] || fail "shared Skill is missing"
[[ ! -e "$ROOT/skills/claude/pop-business-rules" ]] || fail "Claude-specific duplicate exists"
[[ ! -e "$ROOT/skills/codex/pop-business-rules" ]] || fail "Codex-specific duplicate exists"

require "name: pop-business-rules"
require "description:"
require "docs/business-rules/application-map.md"
require "Settled"
require "Proposed"
require "Historical"
require "Unknown"
require "Never infer a Settled business rule from code"
require "Read or explain"
require "Add or change a rule"
require "Audit an application or document"
require "replace them with a pointer"
require 'Update `application-map.md`'
require "Never copy rule content into this Skill"
require "codex-shared-db-change"

if grep -Eq 'C:\\repos|mgCategory.*Wall|royalty.*[0-9]+%' "$SKILL"; then
  fail "Skill embeds a machine path or copied business-rule value"
fi

echo "PASS: pop-business-rules shared routing and authority contract"
