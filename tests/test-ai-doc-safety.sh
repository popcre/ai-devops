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

# File-list and --changed modes (u2giants/theoracle#345): a PR's changed
# files are checked on their own, a planted LAN address is still caught, and
# untouched files elsewhere in the tree are not read.
SCOPED="$TMP/scoped"; mkrepo "$SCOPED"
printf 'HostName 192.168.1.20\n' > "$SCOPED/old-topology.md"
printf '# Clean\n' > "$SCOPED/clean.md"
( cd "$SCOPED" && git add -A && git commit -qm base )
if bash "$TOOL" "$SCOPED" -- clean.md >/dev/null 2>&1; then note 'a clean file passes the file-list mode'; else failed 'a clean file passes the file-list mode'; fi
if bash "$TOOL" "$SCOPED" -- old-topology.md >/dev/null 2>&1; then failed 'a planted LAN address fails the file-list mode'; else note 'a planted LAN address fails the file-list mode'; fi
( cd "$SCOPED" && git checkout -qb pr && printf 'More prose\n' >> clean.md && git commit -qam prose )
if bash "$TOOL" --changed main "$SCOPED" >"$TMP/changed.out" 2>&1; then note '--changed checks only the PR files'; else failed '--changed checks only the PR files'; fi
grep -q 'checking public boundary on 1 selected file' "$TMP/changed.out" && note 'progress names the selected scope' || failed 'progress names the selected scope'
mkdir -p "$SCOPED/test"; printf 'host 10.1.2.3\n' > "$SCOPED/test/planted.py"
( cd "$SCOPED" && git add test/planted.py && git commit -qm planted )
if bash "$TOOL" --changed main "$SCOPED" >/dev/null 2>&1; then failed '--changed catches a LAN address in a changed test file'; else note '--changed catches a LAN address in a changed test file'; fi
rc=0; bash "$TOOL" --changed no-such-ref "$SCOPED" >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 2 ] && note 'an unknown --changed base exits 2' || failed 'an unknown --changed base exits 2'

# The hard limit fails closed with a clear message instead of hanging.
if command -v timeout >/dev/null 2>&1; then
  SLOW="$TMP/slowtool"; mkdir -p "$SLOW/bin" "$SLOW/tools"
  cp "$TOOL" "$SLOW/bin/ai-doc-safety"
  printf '#!/usr/bin/env bash\nsleep 30\n' > "$SLOW/bin/ai-public-boundary-check"
  cp "$ROOT/tools/check-markdown-links.py" "$SLOW/tools/"
  rc=0; AI_DOC_SAFETY_TIMEOUT=1 bash "$SLOW/bin/ai-doc-safety" "$CLEAN" >"$TMP/slow.out" 2>&1 || rc=$?
  { [ "$rc" -eq 1 ] && grep -q 'did not finish within 1s' "$TMP/slow.out"; } && note 'a stuck check stops at the hard limit and fails' || failed 'a stuck check stops at the hard limit and fails'
fi

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
