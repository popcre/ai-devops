#!/usr/bin/env bash
# Offline native GLM dispatch and unchanged pool safety gates.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export AI_DEVOPS_TEST_MODE=1 AI_TASK_GATES_MODE=none AI_POOL_TEST_HOOKS=1 AI_POOL_CALLER=codex
export AI_REVIEW_EVENT_DIR="$TMP/events" AI_REVIEW_SANDBOX_HOME="$TMP/sandboxes"
export GLM_FIXTURE="$TMP" REAL_PACKET="$ROOT/bin/ai-review-packet"
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
 begin)
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
[ "$1" = new ] && [[ "$2" == pool-glm-* ]] && [ "$3" = --prompt-file ]
[ "$5" = --base ] && [ "$6" = "$GLM_TEST_BASE" ] && [ "$7" = --assert-head ] && [ "$8" = "$GLM_TEST_HEAD" ]
head="$GLM_TEST_HEAD"
case "${GLM_REPORT_MODE:-good}" in
 wronghead) head=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;
 tiny) printf 'Head %s\n## Verdict\nAPPROVE\n' "$head"; exit ;;
 malformed) printf 'No terminal verdict\n'; exit ;;
 drift) printf 'model write\n' > file ;;
 chrome) printf 'Head %s and %0600d\n' "$head" 0 >&2; printf '## Verdict\nAPPROVE\n'; exit ;;
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
for mode in wronghead tiny malformed drift chrome; do
  export GLM_REPORT_MODE="$mode"
  if run; then printf 'FAIL: %s accepted\n' "$mode" >&2; exit 1; fi
  [ "$(cat "$TMP/repo/file")" = changed ]
done
unset GLM_REPORT_MODE
rm "$TMP/runner-args"
if (cd "$TMP/repo" && bash "$ROOT/bin/ai-review-pool" glm final-check --base "$BASE" --assert-head aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa) > "$TMP/out" 2>&1; then
  printf 'FAIL: wrong dispatch head accepted\n' >&2; exit 1
fi
[ ! -e "$TMP/runner-args" ]
if (cd "$TMP/repo" && AI_POOL_TEST_HOOKS=0 bash "$ROOT/bin/ai-review-pool" glm final-check) > "$TMP/out" 2>&1; then
  printf 'FAIL: unguarded runner substitution accepted\n' >&2; exit 1
fi
grep -q 'test hook' "$TMP/out"
printf 'GLM pool: 9 dispatch/refusal checks passed\n'
