#!/usr/bin/env bash
# Small, provider-neutral primitives for wrapper adapters.
#
# This file intentionally has no lock, payment, terminal-record, retry, or
# refusal policy. Those choices remain provider-owned until their behaviour is
# independently proven equivalent.

provider_wrapper_valid_name() {
  case "$1" in ''|*[!A-Za-z0-9._-]*) return 1 ;; *) return 0 ;; esac
}

provider_wrapper_sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

# Batched byte-inventory primitives.
#
# The original wrapper inventories spawned one sha256sum per file, which turned
# a 30k-file snapshot on a loaded Windows host into hours per pass (#633). These
# helpers hash in batches while emitting a byte-identical record stream, so
# stored digests stay comparable across the upgrade.
#
# Failure is never silent: if any file cannot be hashed the stream returns
# non-zero and the caller must refuse the digest rather than treat a partial
# stream as a complete inventory.

provider_wrapper_prefix_lines() {
  if [ -z "$1" ]; then cat; else sed "s|^|$1|"; fi
}

# stdin: NUL-separated paths. stdout: sha256sum records in input order.
provider_wrapper_hash_paths() {
  xargs -0 -r sha256sum --
}

# provider_wrapper_inventory_stream <link-record-prefix> <file-record-prefix>
# stdin: NUL-separated paths, already ordered by the caller.
# Symlinks become "<link-prefix><path>\t<target>"; every other path is hashed in
# batches and prefixed with <file-record-prefix>, preserving input order.
provider_wrapper_inventory_stream() {
  local link_prefix="$1" file_prefix="$2" f
  local -a batch=()
  while IFS= read -r -d '' f; do
    if [ -L "$f" ]; then
      if [ "${#batch[@]}" -gt 0 ]; then
        provider_wrapper_flush_batch "$file_prefix" "${batch[@]}" || return 1
        batch=()
      fi
      printf '%s%s\t%s\n' "$link_prefix" "$f" "$(readlink "$f")"
    else
      batch+=("$f")
    fi
  done
  if [ "${#batch[@]}" -gt 0 ]; then
    provider_wrapper_flush_batch "$file_prefix" "${batch[@]}" || return 1
  fi
}

provider_wrapper_flush_batch() {
  local file_prefix="$1"; shift
  [ "$#" -gt 0 ] || return 0
  ( set -o pipefail
    printf '%s\0' "$@" | provider_wrapper_hash_paths | provider_wrapper_prefix_lines "$file_prefix" )
}

# Inventory record streams shared by reviewer wrappers.
# Grammar note: the two streams below are the byte record formats stored as
# review_tree_sha256 / source_tree_sha256. Never change a record without
# versioning the stored digest.
#
# Both public functions are fail-closed regardless of the caller's shell
# options: every stage runs under an explicit `pipefail` subshell and a failing
# stage returns non-zero, so a truncated stream can never be accepted as a
# complete digest just because the final sha256sum succeeded.
provider_wrapper_tree_inventory(){
  local d="$1"
  ( set -o pipefail
    cd "$d" || exit 1
    find . \( -type f -o -type l \) -print0 | LC_ALL=C sort -z \
      | provider_wrapper_inventory_stream $'L\t' '' | sha256sum | cut -d' ' -f1 )
}

# Emits the protected-source records. Assumes the caller has already entered
# "$1" and materialised the tracked index at "$2".
provider_wrapper_source_records(){
  local d="$1" index="$2" f meta mode object sub
  local -a tracked=()
  # Tracked bytes are always protected, even if a tracked file happens to live
  # in a wrapper-owned runtime directory. Only untracked runtime artifacts are
  # omitted from the second inventory stream.
  while IFS=$'\t' read -r -d '' meta f; do
    mode="${meta%% *}"; object="${meta#* }"; object="${object%% *}"
    if [ "$mode" = 160000 ]; then
      if [ -n "$(git -C "$f" rev-parse --show-superproject-working-tree 2>/dev/null || true)" ]; then sub="$(provider_wrapper_source_inventory "$d/$f")" || return 1; else sub=UNINITIALIZED; fi
      printf 'T\tGITLINK\t%s\t%s\t%s\n' "$f" "$object" "$sub"
    elif [ ! -e "$f" ] && [ ! -L "$f" ]; then printf 'T\tMISSING\t%s\n' "$f"
    elif [ -L "$f" ]; then printf 'T\tL\t%s\t%s\n' "$f" "$(readlink "$f")"
    else tracked+=("$f"); fi
  done < "$index"
  # The tracked and untracked streams are sorted together by the caller, so
  # batching the regular tracked files at the end cannot change the digest.
  provider_wrapper_flush_batch $'T\t' ${tracked[@]+"${tracked[@]}"} || return 1
  ( set -o pipefail
    find . \
      -path './.git' -prune -o \
      -path './.ai/reviews' -prune -o \
      -path './.ai/reviewer-issues' -prune -o \
      -path './.ai/test-runs' -prune -o \
      -path './.ai/qualification' -prune -o \
      -path './.ai/qwen-test.*' -prune -o \
      -path './.ai-review-*' -prune -o \
      \( -type f -o -type l \) -print0 | provider_wrapper_inventory_stream $'A\tL\t' $'A\t' ) || return 1
}

provider_wrapper_source_inventory(){
  # Everything runs in one subshell that owns the temporary tracked index and
  # removes it on any exit, including the SIGTERM a bounded caller sends on
  # timeout: the index holds repository filenames and object ids and must not
  # outlive the pass.
  ( set -o pipefail
    local d="$1" index
    index="$(mktemp)" || exit 1
    trap 'rm -f "$index"' EXIT HUP INT TERM
    # The index is materialised first so a git failure is a hard failure, and
    # so the batch array survives the reading loop instead of dying with a
    # pipeline subshell.
    git -C "$d" ls-files --stage -z > "$index" || exit 1
    cd "$d" || exit 1
    { provider_wrapper_source_records "$d" "$index" || exit 1; } \
      | LC_ALL=C sort | sha256sum | cut -d' ' -f1 )
}
