#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

make_repo() {
  local path="$1" remote="$2"
  git init -q "$path"
  git -C "$path" remote add origin "$remote"
}

make_repo "$TMP/private" https://github.com/u2giants/ai-devops-transcripts.git
make_repo "$TMP/public" https://github.com/u2giants/ai-devops.git
make_repo "$TMP/lookalike" https://github.com/attacker/ai-devops-transcripts.git

AI_TRANSCRIPT_TEST_MODE=1 AI_TRANSCRIPT_TEST_PRIVATE=1 \
  bash "$ROOT/bin/ai-transcript-destination-check" "$TMP/private" >/dev/null ||
  fail "canonical private fixture was rejected"

for hostile in public lookalike; do
  if AI_TRANSCRIPT_TEST_MODE=1 AI_TRANSCRIPT_TEST_PRIVATE=1 \
      bash "$ROOT/bin/ai-transcript-destination-check" "$TMP/$hostile" >/dev/null 2>&1; then
    fail "$hostile destination was accepted"
  fi
done

if AI_TRANSCRIPT_TEST_MODE=1 AI_TRANSCRIPT_TEST_PRIVATE=1 \
    bash "$ROOT/bin/ai-transcript-destination-check" "$TMP/missing" >/dev/null 2>&1; then
  fail "non-repository destination was accepted"
fi

[[ "$(head -1 "$ROOT/skills/claude/claude-transcript-backup/SKILL.md")" == '---' ]] ||
  fail "Claude transcript skill frontmatter is not on line 1"

echo "PASS: transcript guard accepts only the canonical private destination"
