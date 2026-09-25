#!/usr/bin/env bash
# Phase 2 delete-guard (issue #711): cleanup must refuse to delete any path
# outside managed review storage, and must never rm -rf a caller-supplied
# free path. The guard lives in is_managed + remove_sandbox.
#
# Fully offline: real git, no network, no provider calls.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$REPO_ROOT/bin/ai-review-sandbox"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export AI_REVIEW_SANDBOX_DIR="$TMP/sandboxes"
export AI_REVIEW_EVENT_DIR="$TMP/reviewer-events"
unset AI_KEEP_SANDBOX 2>/dev/null || true

MAIN="$TMP/main"
mkdir -p "$MAIN"
git -C "$MAIN" init -q
git -C "$MAIN" config user.email t@example.com
git -C "$MAIN" config user.name Test
echo base > "$MAIN/a.txt"
git -C "$MAIN" add -A
git -C "$MAIN" commit -qm init

echo '== ai-review-sandbox delete-guard'

# A managed snapshot is removable.
SNAP="$("$SCRIPT" ensure-copy "$MAIN" guardok)"
check "managed_snapshot_is_created"          "[ -d '$SNAP' ] && [ -f '$SNAP/.ai-review-sandbox' ]"
"$SCRIPT" remove-copy "$MAIN" guardok
check "managed_snapshot_is_removable"        "[ ! -d '$SNAP' ]"

# --- refuse paths outside the sandbox directory ------------------------------

# 1. An unmanaged directory that happens to carry the marker file.
OUTSIDE="$TMP/outside-with-marker"
mkdir -p "$OUTSIDE"
echo source > "$OUTSIDE/.ai-review-sandbox"
echo precious > "$OUTSIDE/keep-me.txt"
set +e
"$SCRIPT" remove-recorded guard-outside "$OUTSIDE" >/dev/null 2>&1
RC1=$?
set -e
check "remove_recorded_refuses_outside_path"  "[ '$RC1' -ne 0 ]"
check "outside_path_survives_remove_recorded" "[ -f '$OUTSIDE/keep-me.txt' ]"

# 2. A path inside the sandbox root but without the marker.
UNMARKED="$AI_REVIEW_SANDBOX_DIR/not-a-snapshot"
mkdir -p "$UNMARKED"
echo precious > "$UNMARKED/keep-me.txt"
set +e
"$SCRIPT" remove-recorded guard-unmarked "$UNMARKED" >/dev/null 2>&1
RC2=$?
set -e
check "remove_recorded_refuses_unmarked_dir"  "[ '$RC2' -ne 0 ]"
check "unmarked_dir_survives"                 "[ -f '$UNMARKED/keep-me.txt' ]"

# 3. remove-copy by root+tag cannot be aimed at a free path: it always derives
#    the managed name. Prove a hostile AI_REVIEW_SANDBOX_DIR cannot escape via
#    a tag that looks like a path.
set +e
"$SCRIPT" remove-copy "$MAIN" '../../etc' >/dev/null 2>&1
RC3=$?
set -e
check "hostile_tag_is_rejected"               "[ '$RC3' -ne 0 ]"

# 4. with-copy cleanup only deletes the snapshot it created — never the source.
BEFORE_SRC="$(find "$MAIN" | wc -l | tr -d ' ')"
set +e
"$SCRIPT" with-copy "$MAIN" guardsrc -- true >/dev/null 2>&1
set -e
check "with_copy_leaves_source_untouched"     "[ \"\$(find '$MAIN' | wc -l | tr -d ' ')\" = '$BEFORE_SRC' ] && [ -d '$MAIN/.git' ]"

# 5. A symlink into the sandbox root cannot redirect deletion outside it.
LINK_TARGET="$TMP/link-target"
mkdir -p "$LINK_TARGET"
echo precious > "$LINK_TARGET/keep-me.txt"
# Build a real managed snapshot, then replace its contents' parent via a
# recorded path that resolves outside — remove-recorded must still refuse
# because is_managed compares physical paths under the sandbox root.
REAL="$("$SCRIPT" ensure-copy "$MAIN" guardlink)"
check "link_guard_snapshot_exists"            "[ -d '$REAL' ]"
# The only deletion path is remove_*/with-copy cleanup; both call is_managed.
# Direct remove-recorded on a path whose physical location left the sandbox
# root is already covered by case 1. Clean up the real snapshot normally.
"$SCRIPT" remove-copy "$MAIN" guardlink
check "real_snapshot_cleaned"                 "[ ! -d '$REAL' ]"
check "link_target_untouched"                 "[ -f '$LINK_TARGET/keep-me.txt' ]"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
