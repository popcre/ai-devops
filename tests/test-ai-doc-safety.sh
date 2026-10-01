#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOL="$ROOT/bin/ai-doc-safety"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
failures=0

note() { printf '  ok   %s\n' "$1"; }
failed() { printf '  FAIL %s\n' "$1" >&2; failures=$((failures + 1)); }

mkrepo() {
  mkdir -p "$1"
  ( cd "$1" && git init -q -b main && git config user.name test && git config user.email t@example.invalid )
}

# A fixture tree that is clean by construction: one linked pair, no topology,
# no credentials.
CLEAN="$TMP/clean"; mkrepo "$CLEAN"; mkdir -p "$CLEAN/docs"
printf '# Target\n' > "$CLEAN/docs/target.md"
printf '[ok](docs/target.md)\n' > "$CLEAN/README.md"
( cd "$CLEAN" && git add -A && git commit -qm init )

if bash "$TOOL" "$CLEAN" >/dev/null 2>&1; then note 'a clean tree passes'; else failed 'a clean tree passes'; fi

# The #1171/#1180 jam: a private-network address in a landed doc.
printf 'HostName 10.20.30.40\n' > "$CLEAN/topology.md"
( cd "$CLEAN" && git add topology.md && git commit -qm topology )
if bash "$TOOL" "$CLEAN" >"$TMP/topology.out" 2>&1; then failed 'a private-network address fails the gate'; else
  note 'a private-network address fails the gate'
  grep -q 'public-boundary invariant failed' "$TMP/topology.out" && note 'the failure names the boundary invariant' || failed 'the failure names the boundary invariant'
fi
( cd "$CLEAN" && git rm -q topology.md && git commit -qm clean )

# The #1174/#1162 jam: a relative Markdown link with the wrong depth.
LINKS="$TMP/links"; mkrepo "$LINKS"; mkdir -p "$LINKS/tests/verification"
printf '# T\n' > "$LINKS/tests/verification/target.md"
printf '[plan](../../../../plan_example.md)\n' > "$LINKS/tests/verification/record.md"
( cd "$LINKS" && git add -A && git commit -qm init )
if bash "$TOOL" "$LINKS" >"$TMP/links.out" 2>&1; then failed 'an escaping Markdown link fails the gate'; else
  note 'an escaping Markdown link fails the gate'
  grep -q 'Markdown-link invariant failed' "$TMP/links.out" && note 'the failure names the link invariant' || failed 'the failure names the link invariant'
fi

# Default tree: with no argument the gate checks the caller worktree. The
# fixture above violates the link invariant, so a failure here proves the
# default target is the invoking repository, not the tool home.
if ( cd "$LINKS" && bash "$TOOL" ) >/dev/null 2>&1; then failed 'the default tree is the invoking repository'; else note 'the default tree is the invoking repository'; fi

# Usage and environment errors stay exit 2.
rc=0; bash "$TOOL" --nonsense >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && note 'an unknown option exits 2' || failed 'an unknown option exits 2'
rc=0; bash "$TOOL" "$TMP/not-a-repo" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && note 'a non-repository argument exits 2' || failed 'a non-repository argument exits 2'

# The gate's own repository must hold both invariants, or this suite ships a
# gate that cannot pass its own tree.
if bash "$TOOL" "$ROOT" >/dev/null 2>&1; then note 'the current repository passes its own doc-safety gate'; else failed 'the current repository passes its own doc-safety gate'; fi

[ "$failures" -eq 0 ] || exit 1
printf 'ai-doc-safety tests passed\n'
