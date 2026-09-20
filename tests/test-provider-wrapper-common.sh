#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tools/lib/provider-wrapper-common.sh"

provider_wrapper_valid_name 'adapter-1.0_ok'
! provider_wrapper_valid_name 'adapter name'
! provider_wrapper_valid_name ''
fixture="$(mktemp)"
trap 'rm -f "$fixture"' EXIT
printf 'fixture adapter\n' > "$fixture"
test "$(provider_wrapper_sha256_file "$fixture")" = "$(sha256sum "$fixture" | awk '{print $1}')"

# --------------------------------------------------------------------------
# Byte-inventory parity (#633, plan P1)
#
# The legacy reference below is the exact per-file construction that shipped
# before batching. Every case compares the batched digest against it: a record
# grammar change would break stored review_tree_sha256 / source_tree_sha256
# values, so parity is the hard requirement, not a nicety.
# --------------------------------------------------------------------------
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

legacy_tree_inventory(){ local d="$1"; (cd "$d" && find . \( -type f -o -type l \) -print0 | LC_ALL=C sort -z | while IFS= read -r -d '' f; do if [ -L "$f" ]; then printf 'L\t%s\t%s\n' "$f" "$(readlink "$f")"; else sha256sum -- "$f"; fi; done) | sha256sum | cut -d' ' -f1; }
legacy_source_inventory(){ local d="$1" f meta mode object sub; (cd "$d" && {
  git ls-files --stage -z | while IFS=$'\t' read -r -d '' meta f; do
    mode="${meta%% *}"; object="${meta#* }"; object="${object%% *}"
    if [ "$mode" = 160000 ]; then
      if [ -n "$(git -C "$f" rev-parse --show-superproject-working-tree 2>/dev/null || true)" ]; then sub="$(legacy_source_inventory "$d/$f")"; else sub=UNINITIALIZED; fi
      printf 'T\tGITLINK\t%s\t%s\t%s\n' "$f" "$object" "$sub"
    elif [ ! -e "$f" ] && [ ! -L "$f" ]; then printf 'T\tMISSING\t%s\n' "$f"
    elif [ -L "$f" ]; then printf 'T\tL\t%s\t%s\n' "$f" "$(readlink "$f")"
    else printf 'T\t'; sha256sum -- "$f"; fi
  done
  find . \
    -path './.git' -prune -o \
    -path './.ai/reviews' -prune -o \
    -path './.ai/reviewer-issues' -prune -o \
    -path './.ai/test-runs' -prune -o \
    -path './.ai/qualification' -prune -o \
    -path './.ai/qwen-test.*' -prune -o \
    -path './.ai-review-*' -prune -o \
    \( -type f -o -type l \) -print0 | while IFS= read -r -d '' f; do
      if [ -L "$f" ]; then printf 'A\tL\t%s\t%s\n' "$f" "$(readlink "$f")"
      else printf 'A\t'; sha256sum -- "$f"; fi
    done
  } | LC_ALL=C sort) | sha256sum | cut -d' ' -f1; }

TMPD="$(mktemp -d)"; trap 'chmod -R u+rwX "$TMPD" 2>/dev/null || true; rm -rf "$TMPD" "$fixture"' EXIT
REPO="$TMPD/repo"
mkdir -p "$REPO/dir with space" "$REPO/nested/deep"
git -C "$REPO" init -q
git -C "$REPO" config user.email parity@invalid
git -C "$REPO" config user.name parity

: > "$REPO/empty.txt"
printf 'plain\n' > "$REPO/plain.txt"
printf 'spaced\n' > "$REPO/dir with space/a file.txt"
printf 'tabbed\n' > "$REPO/$(printf 'weird\tname.txt')"
printf 'dashed\n' > "$REPO/-leading-dash.txt"
printf 'unicode\n' > "$REPO/ünïcødé.txt"
printf 'crlf\r\n' > "$REPO/crlf.txt"
printf '\000\001\002binary' > "$REPO/binary.dat"
printf 'executable\n' > "$REPO/run.sh"; chmod +x "$REPO/run.sh"
printf 'deep\n' > "$REPO/nested/deep/leaf.txt"

SYMLINKS=1
if ln -s 'dir with space/a file.txt' "$REPO/good-link" 2>/dev/null && ln -s ../../nowhere "$REPO/nested/broken-link" 2>/dev/null; then
  printf 'backslash\n' > "$REPO/$(printf 'back\slash.txt')" 2>/dev/null || true
else
  SYMLINKS=0
fi

git -C "$REPO" add -A >/dev/null 2>&1
git -C "$REPO" commit -qm parity >/dev/null 2>&1
printf 'untracked\n' > "$REPO/untracked.txt"
mkdir -p "$REPO/.ai/reviews"; printf 'excluded\n' > "$REPO/.ai/reviews/report.json"
mkdir -p "$REPO/.ai-review-tag"; printf 'excluded\n' > "$REPO/.ai-review-tag/MANIFEST.md"

check 'inventory_weird_names_byte_parity (review copy)' \
  "test \"\$(provider_wrapper_tree_inventory '$REPO')\" = \"\$(legacy_tree_inventory '$REPO')\""
check 'inventory_weird_names_byte_parity (protected source)' \
  "test \"\$(provider_wrapper_source_inventory '$REPO')\" = \"\$(legacy_source_inventory '$REPO')\""
if [ "$SYMLINKS" -eq 1 ]; then
  check 'inventory_link_mode_submodule_parity records symlink targets' \
    "provider_wrapper_inventory_stream \$'L\t' '' < <(printf '%s\000' good-link) | grep -q '^L	good-link	dir with space/a file.txt$'"
else
  skip 'inventory_link_mode_submodule_parity needs symlink support'
fi

# A tracked file deleted from the working tree stays a MISSING record, and a
# file removed between the walk and the hash must fail the pass outright.
rm -f "$REPO/plain.txt"
check 'inventory_missing_tracked_file_parity' \
  "test \"\$(provider_wrapper_source_inventory '$REPO')\" = \"\$(legacy_source_inventory '$REPO')\""
printf 'plain
' > "$REPO/plain.txt"

set +e
DISAPPEARED="$(provider_wrapper_inventory_stream $'L\t' '' < <(printf '%s\000' "$REPO/plain.txt" "$REPO/does-not-exist") 2>/dev/null)"; DISAPPEARED_RC=$?
set -e
check 'inventory_failure_never_emits_success_digest' "test '$DISAPPEARED_RC' -ne 0"

# The public functions must fail closed for a caller that has neither errexit
# nor pipefail set: a truncated stream must never be accepted just because the
# final sha256sum succeeded. A stub sha256sum that always fails stands in for
# an unreadable file, a disappeared file, and a tool failure.
mkdir -p "$TMPD/failbin"
cat > "$TMPD/failbin/sha256sum" <<'STUB'
#!/usr/bin/env bash
printf 'stub sha256sum: forced failure\n' >&2
exit 1
STUB
chmod +x "$TMPD/failbin/sha256sum"
cat > "$TMPD/fail-probe.sh" <<'PROBE'
#!/usr/bin/env bash
# Deliberately no errexit and no pipefail: this is the hostile caller.
. "$1"
PATH="$2:$PATH"
"$3" "$4" >/dev/null 2>&1
exit $?
PROBE
chmod +x "$TMPD/fail-probe.sh"
LIB_PATH="$ROOT/tools/lib/provider-wrapper-common.sh"
set +e
"$TMPD/fail-probe.sh" "$LIB_PATH" "$TMPD/failbin" provider_wrapper_tree_inventory "$REPO"; TREE_FAIL_RC=$?
"$TMPD/fail-probe.sh" "$LIB_PATH" "$TMPD/failbin" provider_wrapper_source_inventory "$REPO"; SOURCE_FAIL_RC=$?
set -e
check 'tree_inventory_fails_closed_for_a_plain_caller' "test '$TREE_FAIL_RC' -ne 0"
check 'source_inventory_fails_closed_for_a_plain_caller' "test '$SOURCE_FAIL_RC' -ne 0"

# A removed tracked file is a MISSING record, but a file that vanishes after
# the walk and before the hash must fail the whole pass.
VANISH="$TMPD/vanish"; mkdir -p "$VANISH"
printf 'here\n' > "$VANISH/present.txt"; printf 'gone\n' > "$VANISH/gone.txt"
mkdir -p "$TMPD/vanishbin"
cat > "$TMPD/vanishbin/sha256sum" <<'STUB'
#!/usr/bin/env bash
rm -f ./gone.txt 2>/dev/null || true
exec "$REAL_SHA256SUM_BIN" "$@"
STUB
chmod +x "$TMPD/vanishbin/sha256sum"
set +e
VANISH_RC=0
REAL_SHA256SUM_BIN="$(command -v sha256sum)" "$TMPD/fail-probe.sh" "$LIB_PATH" "$TMPD/vanishbin" provider_wrapper_tree_inventory "$VANISH" || VANISH_RC=$?
set -e
check 'inventory_disappearing_file_fails_the_pass' "test '$VANISH_RC' -ne 0"

BEFORE="$(provider_wrapper_tree_inventory "$REPO")"
printf 'mutated\n' >> "$REPO/plain.txt"
check 'inventory_mutation_detected' "test \"\$(provider_wrapper_tree_inventory '$REPO')\" != '$BEFORE'"
# Restore the exact bytes; a git checkout would re-apply line-ending policy.
printf 'plain\n' > "$REPO/plain.txt"
check 'inventory_mutation_restores_identical_digest' "test \"\$(provider_wrapper_tree_inventory '$REPO')\" = '$BEFORE'"

# Empty input must return an empty stream, not block on standard input.
check 'inventory_empty_selection_terminates' \
  "test -z \"\$(: | provider_wrapper_inventory_stream \$'L\t' '')\""

# Large-tree bound: the batched pass must stay far below the per-file cost that
# made a 30k-file snapshot take hours (#633). 4,000 files keeps the suite quick
# while still proving the spawn count no longer scales with the file count; the
# dated 30,384-file benchmark lives under tests/verification/repo-throughput/.
BIG="$TMPD/big"; mkdir -p "$BIG"
i=0; while [ "$i" -lt 4000 ]; do printf 'f%s\n' "$i" > "$BIG/file-$i.txt"; i=$((i + 1)); done
BIG_START="$(date +%s)"
BIG_DIGEST="$(provider_wrapper_tree_inventory "$BIG")"
BIG_ELAPSED=$(( $(date +%s) - BIG_START ))
check 'inventory_large_tree_bounded' "test -n '$BIG_DIGEST' && test '$BIG_ELAPSED' -le 60"
printf '  note 4000-file batched inventory took %ss\n' "$BIG_ELAPSED"

# Batch-boundary parity: long names push the argument list past the xargs
# limit, so the stream is produced by several sha256sum invocations. Order and
# bytes must still match the per-file reference exactly.
SPLIT="$TMPD/split"; mkdir -p "$SPLIT"
LONG="$(printf 'n%.0s' $(seq 1 180))"
i=0; while [ "$i" -lt 300 ]; do printf 's%s\n' "$i" > "$SPLIT/$LONG-$i.txt"; i=$((i + 1)); done
check 'inventory_batch_boundary_parity' \
  "test \"\$(provider_wrapper_tree_inventory '$SPLIT')\" = \"\$(legacy_tree_inventory '$SPLIT')\""
# Prove the batch really is split: the argument bytes exceed what one exec on
# this host can carry, so xargs must run sha256sum more than once.
SPLIT_BYTES="$(printf '%s\n' "$SPLIT"/*.txt | wc -c)"
XARGS_LIMIT="$(xargs --show-limits </dev/null 2>&1 | sed -n 's/.*actually use: //p' | head -1)"
check 'inventory_batch_boundary_splits' \
  "test -n '$XARGS_LIMIT' && test '$SPLIT_BYTES' -gt '$XARGS_LIMIT'"

printf '\n%d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "${SKIP:-0}"
[ "$FAIL" -eq 0 ]
