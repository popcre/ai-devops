#!/usr/bin/env bash
# Proves config/reviewer-ci-paths.txt selects the Windows reviewer CI lane for
# every repository file the reviewer suites load, so a change to any of them
# cannot skip the lane that tests it.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
# shellcheck source=../tools/lib/task-gates.sh
. "$ROOT/tools/lib/task-gates.sh"

failures=0
fail() { printf 'FAIL: %s\n' "$*" >&2; failures=$((failures + 1)); }
tg_reviewer_ci_path() { tg_legacy_classify pull_request <<<"$1" | grep -qx 'reviewer=true'; }

# 1. Completeness: walk every tracked repository file the reviewer suites load,
#    transitively, and require the path list to cover each one. A file counts
#    as loaded when it is named by repository path ("tools/x.sh"), by a path
#    built from a script-directory variable ("$SCRIPT_DIR/ai-review-lifecycle",
#    "$(dirname "$0")/../tools/x.sh"), or is a sibling test library.
#    ai-review-preflight names every provider wrapper in its dispatch table but
#    runs only the one requested; the suites never request these, so they are
#    mentions, not dependencies. A new edge anywhere else fails this test.
MENTION_ONLY=' bin/ai-claude-review bin/ai-deepseek-agent bin/ai-gemini bin/ai-glm bin/ai-kimi bin/ai-qwen '
tracked() { [ -f "$1" ] && git ls-files --error-unmatch -- "$1" >/dev/null 2>&1; }
references() {
  local file="$1" dir r
  dir="$(dirname "$file")"
  grep -oE '(^|[^A-Za-z0-9_./-])(bin|tools|config|templates|skills|tests)/[A-Za-z0-9_./-]*[A-Za-z0-9_-]' "$file" |
    sed -E 's#^[^a-z]##'
  grep -oE '\$\{?[A-Z_]*(DIR|ROOT|HERE|BIN|SELF)\}?"?/[A-Za-z0-9_./-]*[A-Za-z0-9_-]|dirname [^)]*\)"?/[A-Za-z0-9_./-]*[A-Za-z0-9_-]' "$file" |
    sed -E 's#^(\$\{?[A-Z_]*\}?|dirname [^)]*\))"?/##' | while IFS= read -r r; do
      while :; do case "$r" in ../*) r="${r#../}" ;; ./*) r="${r#./}" ;; *) break ;; esac; done
      case "$r" in
        bin/*|tools/*|config/*|templates/*|skills/*|tests/*) printf '%s\n' "$r" ;;
        *) printf '%s/%s\n' "$dir" "$r" ;;
      esac
    done
  grep -oE '\b(lib-test-[a-z-]+|grok-auth-link-cases)\.sh\b' "$file" | sed 's#^#tests/#'
}
declare -A seen=()
queue=(tests/test-ai-codex-review.sh tests/test-ai-grok-review.sh)
while [ "${#queue[@]}" -gt 0 ]; do
  file="${queue[0]}"; queue=("${queue[@]:1}")
  [ -z "${seen[$file]:-}" ] || continue
  seen["$file"]=1
  while IFS= read -r ref; do
    [ -n "$ref" ] && tracked "$ref" || continue
    case "$MENTION_ONLY" in *" $ref "*) continue ;; esac
    [ -n "${seen[$ref]:-}" ] || queue+=("$ref")
  done < <(references "$file" | sort -u)
done
[ "${#seen[@]}" -ge 20 ] || fail "dependency walk found only ${#seen[@]} files"
for file in "${!seen[@]}"; do
  tg_reviewer_ci_path "$file" || fail "reviewer suite dependency is not a reviewer CI path: $file"
done
for file in bin/ai-codex-review bin/ai-grok-review bin/ai-grok-review.cmd bin/ai-muse \
  bin/ai-review-preflight bin/ai-review-lifecycle bin/ai-task-gates bin/ai-task-gates.cmd \
  config/task-gates.json config/reviewer-ci-paths.txt tests/test-reviewer-ci-paths.sh; do
  tg_reviewer_ci_path "$file" || fail "required reviewer CI path missing: $file"
done
for file in README.md docs/ci-speed-audit-2026-09-17.md bin/ai-gh bin/ai-pr-wait bin/ai-glm \
  .github/workflows/docs-reachability.yml tests/test-ai-task-gates.sh; do
  ! tg_reviewer_ci_path "$file" || fail "unrelated path selects the reviewer lane: $file"
done

if [ "$failures" -ne 0 ]; then
  printf 'test-reviewer-ci-paths: %s failure(s)\n' "$failures" >&2
  exit 1
fi
printf 'test-reviewer-ci-paths: PASS (%s reviewer dependencies covered)\n' "${#seen[@]}"
