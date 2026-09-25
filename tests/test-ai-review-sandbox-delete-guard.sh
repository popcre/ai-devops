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

# 5. A symlink standing in for a managed snapshot cannot redirect deletion
#    outside the sandbox root. is_managed canonicalizes both sides (pwd -P),
#    so a link that resolves outside the sandbox root must be refused.
LINK_TARGET="$TMP/link-target"
mkdir -p "$LINK_TARGET"
echo precious > "$LINK_TARGET/keep-me.txt"
REAL="$("$SCRIPT" ensure-copy "$MAIN" guardlink)"
check "link_guard_snapshot_exists"            "[ -d '$REAL' ]"
# Swap the managed directory for a symlink to an outside tree. On Windows,
# ln -s may fall back to a copy; only run the escape checks on a real link.
set +e
rm -rf "$REAL" 2>/dev/null
ln -s "$LINK_TARGET" "$REAL" 2>/dev/null
set -e
if [ -L "$REAL" ]; then
  set +e
  "$SCRIPT" remove-recorded guardlink "$REAL" >/dev/null 2>&1
  RC4=$?
  set -e
  check "remove_recorded_refuses_symlink_escape" "[ '$RC4' -ne 0 ]"
  check "symlink_target_survives"               "[ -f '$LINK_TARGET/keep-me.txt' ]"
  set +e
  "$SCRIPT" remove-copy "$MAIN" guardlink >/dev/null 2>&1
  RC5=$?
  set -e
  check "remove_copy_refuses_symlink_escape"    "[ '$RC5' -ne 0 ] && [ -L '$REAL' ]"
  check "symlink_target_survives_remove_copy"   "[ -f '$LINK_TARGET/keep-me.txt' ]"
else
  skip "remove_recorded_refuses_symlink_escape (ln -s unavailable)"
  skip "symlink_target_survives (ln -s unavailable)"
  skip "remove_copy_refuses_symlink_escape (ln -s unavailable)"
  skip "symlink_target_survives_remove_copy (ln -s unavailable)"
fi
set +e
rm -rf "$REAL" 2>/dev/null
"$SCRIPT" remove-copy "$MAIN" guardlink >/dev/null 2>&1
set -e

# --- managed root reached through a link is still deletable via sweep -------
# Production root is a Windows junction. sweep-orphans enumerates that linked
# spelling and hands it to remove_sandbox. Evidence tools reject link
# components, so the delete must canonicalize first or every real orphan is
# retained forever. Age a marker and sweep through the linked root.
LINK_ROOT="$TMP/linked-sandboxes"
REAL_ROOT="$TMP/real-sandboxes"
mkdir -p "$REAL_ROOT"
linked=0
if command -v cmd >/dev/null 2>&1 && command -v cygpath >/dev/null 2>&1; then
  win_link="$(cygpath -w "$LINK_ROOT")"
  win_real="$(cygpath -w "$REAL_ROOT")"
  # Windows directory junction: the production sandbox root is one of these.
  cmd //c "mklink /J $win_link $win_real" >/dev/null 2>&1 || true
fi
if [ -e "$LINK_ROOT" ] && [ "$(cd "$LINK_ROOT" 2>/dev/null && pwd -P)" = "$(cd "$REAL_ROOT" 2>/dev/null && pwd -P)" ]; then
  linked=1
fi
if [ "$linked" = 1 ]; then
  OLD_SANDBOX_DIR="$AI_REVIEW_SANDBOX_DIR"
  export AI_REVIEW_SANDBOX_DIR="$LINK_ROOT"
  LINKED_SNAP="$("$SCRIPT" ensure-copy "$MAIN" guardlinkroot)"
  check "linked_root_snapshot_is_created"      "[ -d '$LINKED_SNAP' ] && [ -f '$LINKED_SNAP/.ai-review-sandbox' ]"
  # Age the marker past the sweep threshold, then sweep using the LINKED root
  # spelling — exactly what production passes from AI_REVIEW_SANDBOX_DIR.
  touch -d '2 hours ago' "$LINKED_SNAP/.ai-review-sandbox" 2>/dev/null || true
  "$SCRIPT" sweep-orphans --max-age-seconds 60 --max-removals 5 >/dev/null 2>&1 || true
  check "linked_root_sweep_removes_orphan"     "[ ! -e '$LINKED_SNAP' ]"
  export AI_REVIEW_SANDBOX_DIR="$OLD_SANDBOX_DIR"
else
  skip "linked_root_snapshot_is_created (no usable symlink/junction)"
  skip "linked_root_sweep_removes_orphan (no usable symlink/junction)"
fi

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
