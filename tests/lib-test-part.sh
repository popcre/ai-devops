#!/usr/bin/env bash
# Run one part of a long offline suite (issue: Windows sections over 20 minutes).
#
# A suite marks where each part begins with `ai_test_part N` and wraps that
# part's expensive work in `if ai_test_part_active; then ... fi`. The harness
# reporters (check/ok/bad/skip) stay silent outside the selected part, so every
# check is counted in exactly one part. Shared setup outside the wrapped blocks
# runs in every part.
#
#   AI_TEST_PART unset or 1  the suite file itself: part 1 only
#   AI_TEST_PART=N           part N (set by tests/<suite>-partN.sh)
#   AI_TEST_PART=all         every part in one process (local convenience)
#
# test-all.sh runs the suite file and each -partN file as separate suites, so
# Linux and Windows both execute every check exactly once.
AI_TEST_PART="${AI_TEST_PART:-1}"
case "$AI_TEST_PART" in
  all|[1-9]) ;;
  *) printf 'lib-test-part: AI_TEST_PART must be 1-9 or all, got %s\n' "$AI_TEST_PART" >&2; exit 2 ;;
esac
AI_TEST_CURRENT_PART=1
ai_test_part() { AI_TEST_CURRENT_PART="$1"; }
ai_test_part_active() { [ "$AI_TEST_PART" = all ] || [ "$AI_TEST_PART" = "$AI_TEST_CURRENT_PART" ]; }
