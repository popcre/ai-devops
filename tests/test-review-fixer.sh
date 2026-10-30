#!/usr/bin/env bash
# Offline test for tools/ci/review-fixer.sh decision handling (#2075).
# Stubs gh and the agent; asserts PROTECTED leaves the issue open with a
# designed-refusal comment, and FIXED touching a workflow is refused.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
git init -q -b main "$tmp/source"
git -C "$tmp/source" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
export STUB_HEAD="$(git -C "$tmp/source" rev-parse HEAD)" STUB_SOURCE="$tmp/source"
cat > "$tmp/bin/gh" <<'GH'
#!/usr/bin/env bash
echo "gh $*" >> "$STUB_LOG"
case "$1 $2" in
  "api repos/o/r/issues/7")
    [ "$STUB_DECISION" != PRECHECK-ERROR ] || exit 1
    printf '{"number":7,"state":"open","labels":[{"name":"review-finding"}],"body":"PR: https://github.com/o/r/pull/2\\nHead SHA: `%s`"}\n' "$STUB_HEAD" ;;
  "api repos/o/r/pulls/2")
    sha="$STUB_HEAD"; { [ -f "$STUB_LOG.moved" ] || [ "$STUB_DECISION" = STALE ]; } && sha=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
    printf '{"number":2,"state":"open","user":{"login":"owner"},"head":{"ref":"main","sha":"%s","repo":{"full_name":"o/r"}},"base":{"ref":"main"}}\n' "$sha" ;;
  "api repos/o/r/git/ref/heads/main") printf '{"object":{"sha":"%s"}}\n' "$STUB_HEAD" ;;
  "api --paginate") echo '[[]]' ;;
  "issue view") printf 'PR: https://github.com/o/r/pull/2\nHead SHA: `%s`\n' "$STUB_HEAD" ;;
  "repo clone") git clone -q "$STUB_SOURCE" "$4" ;;
  "auth token") exit 1 ;;
  "pr create") echo https://github.com/o/r/pull/9 ;;
esac
exit 0
GH
cat > "$tmp/bin/codex" <<'CX'
#!/usr/bin/env bash
out=""; dir=""
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift ;; -C) dir="$2"; shift ;; esac; shift; done
echo "agent called" >> "$STUB_LOG"
case "$STUB_DECISION" in
  FIXED-WORKFLOW) mkdir -p "$dir/.github/workflows"; echo x > "$dir/.github/workflows/a.yml"; d=FIXED ;;
  FIXED|MOVED|MOVED-AFTER-PUSH)
    echo x > "$dir/safe.py"; d=FIXED
    [ "$STUB_DECISION" = MOVED ] && touch "$STUB_LOG.moved"
    if [ "$STUB_DECISION" = MOVED-AFTER-PUSH ]; then
      printf '#!/bin/sh\ntouch "%s.moved"\n' "$STUB_LOG" > "$STUB_SOURCE/.git/hooks/post-receive"
      chmod +x "$STUB_SOURCE/.git/hooks/post-receive"
    fi ;;
  BAD-EXIT) printf 'summary\nDECISION: INVALID\n' > "$out"; exit 9 ;;
  *) d="$STUB_DECISION" ;;
esac
printf 'summary\nDECISION: %s\n' "$d" > "$out"
CX
chmod +x "$tmp/bin/"*
fail=0
run() {
  : > "$tmp/log"
  rm -f "$tmp/log.moved"
  STUB_LOG="$tmp/log" STUB_DECISION="$1" PATH="$tmp/bin:$PATH" GITHUB_REPOSITORY=o/r GH_TOKEN=x \
    AI_GH_STATE_DIR="$tmp/throttle" AI_GH_MIN_SPACING_SECONDS=0 AI_GH_QUOTA_PROBE_SECONDS=off \
    WORK_ROOT="$tmp/w" GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t \
    bash "$root/tools/ci/review-fixer.sh" 7 > "$tmp/out" 2>&1
}
check() { if eval "$2"; then echo "  ok   $1"; else echo "  FAIL $1"; cat "$tmp/out" "$tmp/log"; fail=1; fi; }

run STALE; rc=$?
check "stale source stops before outcome setup credential probe clone or model" '[ $rc = 0 ] && grep -q "add-label fixer-deferred" "$tmp/log" && ! grep -Eq "label create fixer-(done|failed)|auth token|repo clone|agent called|pr create|issue close" "$tmp/log"'

run PRECHECK-ERROR; rc=$?
check "failed preflight still creates its failure label and reports failure without a model" '[ $rc = 1 ] && grep -q "label create fixer-failed" "$tmp/log" && grep -q "source preflight failed" "$tmp/log" && grep -q "add-label fixer-failed" "$tmp/log" && ! grep -Eq "auth token|repo clone|agent called|pr create|issue close" "$tmp/log"'

run PROTECTED; rc=$?
check "PROTECTED exits 0" '[ $rc = 0 ]'
check "PROTECTED comments a designed refusal" 'grep -q "refused by design" "$tmp/log"'
check "PROTECTED labels fixer-done" 'grep -q "add-label fixer-done" "$tmp/log"'
check "PROTECTED never closes the issue" '! grep -q "issue close" "$tmp/log"'

run FIXED-WORKFLOW; rc=$?
check "a fix touching a workflow is refused" '[ $rc = 1 ] && grep -q "touched protected files" "$tmp/out"'
check "a refused fix is labelled fixer-failed" 'grep -q "add-label fixer-failed" "$tmp/log"'

run INVALID; rc=$?
check "INVALID closes as not planned with explicit evidence" 'grep -q "issue close 7 --repo o/r --reason not planned" "$tmp/log" && grep -q "review-fixer-invalid:v1" "$tmp/log" && grep -q "add-label fixer-invalid" "$tmp/log"'

run FIXED; rc=$?
check "genuine current fix still commits pushes and opens a usable PR" '[ $rc = 0 ] && grep -q "pr create.*--base main --head review-fix/7" "$tmp/log" && grep -q "review-fixer:v1" "$tmp/log" && git -C "$tmp/source" show review-fix/7:safe.py >/dev/null'

run MOVED; rc=$?
check "source movement during model call stops publication and leaves finding open" '[ $rc = 0 ] && grep -q "add-label fixer-deferred" "$tmp/log" && ! grep -q "pr create" "$tmp/log" && ! grep -q "issue close" "$tmp/log"'

git -C "$tmp/source" branch -m review-fix/7 baseline-published-fix
run MOVED-AFTER-PUSH; rc=$?
retained="$(git -C "$tmp/source" rev-parse refs/heads/review-fix/7)"
check "late source movement retains exact recovery tip and unresolved owner without PR" '[ $rc = 0 ] && grep -q "add-label fixer-deferred" "$tmp/log" && ! grep -q "pr create" "$tmp/log" && ! grep -q "issue close" "$tmp/log" && grep -q "Recovery branch .*review-fix/7" "$tmp/log"'
check "retention comment names exact pushed tip owner and deliberate deferral" 'grep -Fq "$retained" "$tmp/log" && grep -q "unresolved with @owner" "$tmp/log" && grep -q "unchanged automatic reruns stay deferred" "$tmp/log"'

run BAD-EXIT; rc=$?
check "failed model cannot publish an invalid disposition" '[ $rc = 1 ] && ! grep -q "issue close" "$tmp/log" && ! grep -q "add-label fixer-invalid" "$tmp/log"'
PYTHONDONTWRITEBYTECODE=1 python3 "$root/tests/test_review_fixer_state.py" || fail=1
[ "$fail" = 0 ] && echo "PASS: review-fixer decisions" || exit 1
