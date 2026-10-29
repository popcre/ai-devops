#!/usr/bin/env bash
# reviewer-instructions.sh — minimal instruction profile for OpenCode reviewers
# (popcre/ai-devops#1881). OpenCode loads the owner's ~/.claude/CLAUDE.md and
# the ~/.claude and ~/.agents skill lists through HOME, even when its config
# home is private. Reviewers export REVIEWER_OPENCODE_ENV to turn those sources
# off and stage templates/system/REVIEWER-global.md as the per-run config
# home's global AGENTS.md, the same rules bin/ai-codex-review uses. The user's
# and the managed configuration are never edited.
# No dirname fork: Muse doctor budgets its process launches (#773).
REVIEWER_INSTRUCTIONS_ROOT="$(cd "${BASH_SOURCE[0]%/*}/../.." && pwd)"
REVIEWER_OPENCODE_ENV=(OPENCODE_DISABLE_CLAUDE_CODE=1 OPENCODE_DISABLE_EXTERNAL_SKILLS=1)

# reviewer_opencode_rules DIR: copy the reviewer rules to DIR/AGENTS.md, where
# DIR is the per-run "$XDG_CONFIG_HOME/opencode". Refuses without the rules.
reviewer_opencode_rules() {
  local rules="$REVIEWER_INSTRUCTIONS_ROOT/templates/system/REVIEWER-global.md"
  [ -f "$rules" ] || { printf 'reviewer instructions are missing: %s\n' "$rules" >&2; return 1; }
  mkdir -p "$1" && cp "$rules" "$1/AGENTS.md"
}

# reviewer_opencode_verdict_stop DIR: copy the shared verdict-stop plugin
# (config/opencode-plugins/verdict-stop.js) to DIR/plugin/, where DIR is the
# per-run "$XDG_CONFIG_HOME/opencode". Pinned OpenCode keeps compaction.auto
# on in every reviewer profile; the plugin declines the post-compaction
# auto-continue once the session has written its verdict. Refuses without it.
reviewer_opencode_verdict_stop() {
  local plugin="$REVIEWER_INSTRUCTIONS_ROOT/config/opencode-plugins/verdict-stop.js"
  [ -f "$plugin" ] || { printf 'verdict-stop plugin is missing: %s\n' "$plugin" >&2; return 1; }
  mkdir -p "$1/plugin" && cp "$plugin" "$1/plugin/verdict-stop.js"
}
