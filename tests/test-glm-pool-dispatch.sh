#!/usr/bin/env bash
# Offline native GLM dispatch and unchanged pool safety gates.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export AI_DEVOPS_TEST_MODE=1 AI_TASK_GATES_MODE=none AI_POOL_TEST_HOOKS=1 AI_POOL_CALLER=codex
unset AI_REVIEW_BRIEF_FILE
export AI_REVIEW_EVENT_DIR="$TMP/events" AI_REVIEW_SANDBOX_HOME="$TMP/sandboxes"
export GLM_FIXTURE="$TMP" REAL_PACKET="$ROOT/bin/ai-review-packet"
# Shared offline isolation (#1435, #1505): marker, cleared outer review session.
. "$ROOT/tests/lib-reviewer-events-isolation.sh"
mkdir -p "$TMP/repo" "$TMP/events"
git -C "$TMP/repo" init -q -b main
git -C "$TMP/repo" config user.name Test
git -C "$TMP/repo" config user.email t@example.com
printf '.ai/\n' > "$TMP/repo/.gitignore"
printf 'original\n' > "$TMP/repo/file"
git -C "$TMP/repo" add .gitignore file
git -C "$TMP/repo" commit -qm base
BASE="$(git -C "$TMP/repo" rev-parse HEAD)"
printf 'changed\n' > "$TMP/repo/file"
git -C "$TMP/repo" add file
git -C "$TMP/repo" commit -qm changed
HEAD="$(git -C "$TMP/repo" rev-parse HEAD)"
export GLM_TEST_BASE="$BASE" GLM_TEST_HEAD="$HEAD"
cat > "$TMP/lifecycle" <<'EOF'
#!/usr/bin/env bash
set -eu
case "$1" in
 identity) "$REAL_PACKET" resolve "$2" --base "$GLM_TEST_BASE" --assert-head "$GLM_TEST_HEAD" | jq '. + {repository_key:"glm-fixture-repository"}' ;;
 begin)
   printf 'begin\n' >> "$GLM_FIXTURE/lifecycle-starts"
   "$REAL_PACKET" resolve "$PWD" --base "$GLM_TEST_BASE" --assert-head "$GLM_TEST_HEAD" > "$GLM_FIXTURE/identity"
   jq '{head,source_digest,stale:false,verdict:null}' "$GLM_FIXTURE/identity" > "$GLM_FIXTURE/state"
   printf '%s\n' "$GLM_FIXTURE/state" ;;
 finish) printf '{"stale":false,"verdict":"APPROVE"}\n' ;;
 fail) printf '%s\n' "$*" >> "$GLM_FIXTURE/failures" ;;
 *) exit 0 ;;
esac
EOF
cat > "$TMP/runner" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$PWD" > "$GLM_FIXTURE/runner-pwd"
printf '%s\n' "$@" > "$GLM_FIXTURE/runner-args"
printf %s "${AI_REVIEW_SOURCE_ROOT:-}" > "$GLM_FIXTURE/runner-source-root"
cmd="${1:-}"; name="${2:-}"
case "$cmd" in new|ask) ;; *) echo "unexpected runner cmd: $cmd" >&2; exit 1 ;; esac
[[ "$name" == pool-glm-* ]] || { echo "unexpected session name: $name" >&2; exit 1; }
brief=""; base=""; ahead=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --prompt-file) brief="$2"; shift 2 ;;
    --base) base="$2"; shift 2 ;;
    --assert-head) ahead="$2"; shift 2 ;;
    --repo|--caller) shift 2 ;;
    *) shift ;;
  esac
done
[ -n "$brief" ] && [ -f "$brief" ]
cp "$brief" "$GLM_FIXTURE/runner-brief"
[ "$base" = "$GLM_TEST_BASE" ] && [ "$ahead" = "$GLM_TEST_HEAD" ]
head="$GLM_TEST_HEAD"
case "${GLM_REPORT_MODE:-good}" in
 wronghead) head=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;
 tiny) printf 'Head %s\n## Verdict\nAPPROVE\n' "$head"; exit ;;
 malformed) printf 'No terminal verdict\n'; exit ;;
 drift) printf 'model write\n' > file ;;
 chrome) printf 'Head %s and %0600d\n' "$head" 0 >&2; printf '## Verdict\nAPPROVE\n'; exit ;;
 revise) printf 'Head %s\n## Verdict\nREVISE\n' "$head"; exit ;;
esac
printf 'Reviewed head %s.\n' "$head"
printf 'The immutable source packet, changed files, protected snapshot boundary, exact source identity, lifecycle terminal handling, refusal conditions and tests were inspected. The change retains fail-closed validation and all existing guarantees. No findings were identified after checking relevant siblings, invalid inputs, source changes and failure paths. The exact reviewed commit remains bound throughout this report, and the model report is distinct from runtime progress chrome.\n\n## Verdict\nAPPROVE\n'
printf 'GLM progress chrome\n' >&2
EOF
chmod +x "$TMP/lifecycle" "$TMP/runner"
export AI_REVIEW_LIFECYCLE_BIN="$TMP/lifecycle" AI_POOL_RUNNER_GLM="$TMP/runner"
run(){ (cd "$TMP/repo" && bash "$ROOT/bin/ai-review-pool" glm final-check --base "$BASE" --assert-head "$HEAD") > "$TMP/out" 2>&1; }
run
REPORT="$(tail -1 "$TMP/out")"
[ -f "$REPORT" ]
! grep -q 'GLM progress chrome' "$REPORT"
[ "$(cat "$TMP/runner-pwd")" != "$TMP/repo" ]
[ "$(cat "$TMP/repo/file")" = changed ]
# Without a governed receipt request GLM resolves its own identity (unchanged).
[ ! -s "$TMP/runner-source-root" ]
# With one, GLM is told the ORIGINAL checkout (it snapshots that, not the pool's),
# so its receipt binds the source the caller trusts (shared-db#4308).
mkdir -p "$TMP/repo/.ai/reviews"
(cd "$TMP/repo" && AI_REVIEW_SOURCE_RECEIPT_FILE="$TMP/repo/.ai/reviews/governed-source-test.json" bash "$ROOT/bin/ai-review-pool" glm final-check --base "$BASE" --assert-head "$HEAD") > "$TMP/out" 2>&1
[ "$(cd "$(cat "$TMP/runner-source-root")" && pwd -P)" = "$(cd "$TMP/repo" && pwd -P)" ]
for mode in wronghead tiny malformed drift chrome; do
  export GLM_REPORT_MODE="$mode"
  if run; then printf 'FAIL: %s accepted\n' "$mode" >&2; exit 1; fi
  [ "$(cat "$TMP/repo/file")" = changed ]
done
unset GLM_REPORT_MODE
# An explicit question reaches native GLM, literally, from a private snapshot.
QUESTION='CARRIED_QUESTION_1794: assess the release question literally; $(must_not_execute)'
printf '%s\n' "$QUESTION" > "$TMP/question with spaces.md"
export AI_REVIEW_BRIEF_FILE="$TMP/question with spaces.md"
run
grep -Fq "$QUESTION" "$TMP/runner-brief"
grep -q 'carried request sha256' "$(tail -1 "$TMP/out")"
# Invalid inputs fail before lifecycle/provider start and never print their text.
mkdir "$TMP/request-directory"
ln -s "$AI_REVIEW_BRIEF_FILE" "$TMP/request-link"
mkfifo "$TMP/request-fifo"
: > "$TMP/request-empty"
printf '   \n' > "$TMP/request-whitespace"
python3 - "$TMP" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
(p/'request-oversized').write_bytes(b'x'*262145)
(p/'request-invalid-utf8').write_bytes(b'\xff')
(p/'request-nul').write_bytes(b'private-content-marker\0bad')
PY
for invalid in missing request-directory request-link request-fifo request-empty request-whitespace request-oversized request-invalid-utf8 request-nul; do
  export AI_REVIEW_BRIEF_FILE="$TMP/$invalid"
  rm -f "$TMP/runner-args"
  before="$(wc -l < "$TMP/lifecycle-starts")"
  if run; then printf 'FAIL: invalid request accepted: %s\n' "$invalid" >&2; exit 1; fi
  [ ! -e "$TMP/runner-args" ]
  [ "$(wc -l < "$TMP/lifecycle-starts")" = "$before" ]
  ! grep -q 'private-content-marker' "$TMP/out"
done
unset AI_REVIEW_BRIEF_FILE
# A generic passing report remains reusable, but cannot answer a specific question.
mkdir "$TMP/mock-python"
python3 - "$TMP" "$(command -v python3)" <<'PY'
from pathlib import Path
import json, shlex, sys
p=Path(sys.argv[1])
script='''#!/usr/bin/env bash
if [[ "${1:-}" == */tools/reviewer_events.py ]] && [ "${2:-}" = find-passing-report ]; then
  touch CACHE_MARKER
  printf '%s\\n' CACHE_RESULT
  exit 0
fi
exec REAL_PYTHON "$@"
'''
script=script.replace('CACHE_MARKER',shlex.quote(str(p/'cache-lookup'))).replace('CACHE_RESULT',shlex.quote(json.dumps({'report':str(p/'generic-report.md')}))).replace('REAL_PYTHON',shlex.quote(sys.argv[2]))
(p/'mock-python/python3').write_text(script)
PY
chmod +x "$TMP/mock-python/python3"
printf 'generic report\n' > "$TMP/generic-report.md"
export PATH="$TMP/mock-python:$PATH"
rm -f "$TMP/runner-args" "$TMP/cache-lookup"
run
[ -e "$TMP/cache-lookup" ] && [ ! -e "$TMP/runner-args" ]
[ "$(tail -1 "$TMP/out")" = "$TMP/generic-report.md" ]
export AI_REVIEW_BRIEF_FILE="$TMP/question with spaces.md"
rm -f "$TMP/cache-lookup"
run
[ ! -e "$TMP/cache-lookup" ] && [ -e "$TMP/runner-args" ]
grep -Fq "$QUESTION" "$TMP/runner-brief"
unset AI_REVIEW_BRIEF_FILE
rm "$TMP/runner-args"
if (cd "$TMP/repo" && bash "$ROOT/bin/ai-review-pool" glm final-check --base "$BASE" --assert-head aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa) > "$TMP/out" 2>&1; then
  printf 'FAIL: wrong dispatch head accepted\n' >&2; exit 1
fi
[ ! -e "$TMP/runner-args" ]
if (cd "$TMP/repo" && AI_POOL_TEST_HOOKS=0 bash "$ROOT/bin/ai-review-pool" glm final-check) > "$TMP/out" 2>&1; then
  printf 'FAIL: unguarded runner substitution accepted\n' >&2; exit 1
fi
grep -q 'test hook' "$TMP/out"
printf 'GLM pool: dispatch, carried-question, cache and refusal checks passed\n'
