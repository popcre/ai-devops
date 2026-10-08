#!/usr/bin/env bash
# Offline suite for tools/ci/check-temp-hygiene.sh (plan_session-temp-cleanup.md step 6).
set -u
PASS=0; FAIL=0
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib-test-harness.sh"
lint="$here/../tools/ci/check-temp-hygiene.sh"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bad" "$work/good"
printf '#!/usr/bin/env bash\nout="/tmp/658-approval.md"\n' > "$work/bad/literal"
printf '#!/usr/bin/env bash\nd="$(mktemp -d)"\n' > "$work/bad/notrap.sh"
printf '#!/usr/bin/env bash\nd="$(mktemp -d)"; trap '"'"'rm -rf "$d"'"'"' EXIT\n# /tmp/ in a comment is fine\nx="$HOME/tmp/y"\n' > "$work/good/ok.sh"
bash "$lint" --baseline /dev/null "$work/bad/literal" >/dev/null; check "bad /tmp/ literal fails the lint" '[ $? -ne 0 ]'
bash "$lint" --baseline /dev/null "$work/bad/notrap.sh" >/dev/null; check "mktemp without trap fails the lint" '[ $? -ne 0 ]'
bash "$lint" --baseline /dev/null "$work/good" >/dev/null; check "clean fixture passes" '[ $? -eq 0 ]'
bash "$lint" >/dev/null; check "repository bin/ and tools/ pass" '[ $? -eq 0 ]'
printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"; [ "$FAIL" -eq 0 ]
