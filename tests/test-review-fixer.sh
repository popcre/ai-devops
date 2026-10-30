#!/usr/bin/env bash
# Offline test for tools/ci/review-fixer.sh decision handling (#2075).
# Stubs gh and the agent; asserts PROTECTED leaves the issue open with a
# designed-refusal comment, and FIXED touching a workflow is refused.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat > "$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
echo "gh $*" >> "$STUB_LOG"
case "$1 $2" in
  "issue view") echo "PR: none" ;;
  "repo clone") mkdir -p "$4" && git -C "$4" init -q -b main && git -C "$4" commit -q --allow-empty -m init ;;
  "auth token") exit 1 ;;
esac
exit 0
GH
cat > "$tmp/bin/codex" <<'CX'
#!/usr/bin/env bash
out=""; dir=""
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift ;; -C) dir="$2"; shift ;; esac; shift; done
case "$STUB_DECISION" in
  FIXED-WORKFLOW) mkdir -p "$dir/.github/workflows"; echo x > "$dir/.github/workflows/a.yml"; d=FIXED ;;
  *) d="$STUB_DECISION" ;;
esac
printf 'summary\nDECISION: %s\n' "$d" > "$out"
CX
chmod +x "$tmp/bin/"*
fail=0
run() {
  : > "$tmp/log"
  STUB_LOG="$tmp/log" STUB_DECISION="$1" PATH="$tmp/bin:$PATH" GITHUB_REPOSITORY=o/r GH_TOKEN=x \
    WORK_ROOT="$tmp/w" GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
    bash "$root/tools/ci/review-fixer.sh" 7 > "$tmp/out" 2>&1
}
check() { if eval "$2"; then echo "  ok   $1"; else echo "  FAIL $1"; cat "$tmp/out" "$tmp/log"; fail=1; fi; }

run PROTECTED; rc=$?
check "PROTECTED exits 0" '[ $rc = 0 ]'
check "PROTECTED comments a designed refusal" 'grep -q "refused by design" "$tmp/log"'
check "PROTECTED labels fixer-done" 'grep -q "add-label fixer-done" "$tmp/log"'
check "PROTECTED never closes the issue" '! grep -q "issue close" "$tmp/log"'

run FIXED-WORKFLOW; rc=$?
check "a fix touching a workflow is refused" '[ $rc = 1 ] && grep -q "touched protected files" "$tmp/out"'
check "a refused fix is labelled fixer-failed" 'grep -q "add-label fixer-failed" "$tmp/log"'

run INVALID; rc=$?
check "INVALID closes as not planned" 'grep -q "issue close 7 --repo o/r --reason not planned" "$tmp/log"'
[ "$fail" = 0 ] && echo "PASS: review-fixer decisions" || exit 1
