#!/usr/bin/env bash
# Part 2 of tests/test-ai-muse.sh, run as its own suite so a Windows section
# stays under its time limit. See tests/lib-test-part.sh.
AI_TEST_PART=2 AI_TEST_SUITE=test-ai-muse-part2 exec bash "$(dirname "${BASH_SOURCE[0]}")/test-ai-muse.sh" "$@"
