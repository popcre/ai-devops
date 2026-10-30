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
tg_reviewer_ci_path() { tg_legacy_classify pull_request <<<"$1" | grep -x 'reviewer=true' >/dev/null; }

# A matching header must not make the consumer close before the classifier
# finishes. Large trailing output makes that pipefail regression deterministic.
if ! (
  tg_legacy_classify() {
    printf 'reviewer=true\n'
    printf '%200000s\n' ''
  }
  tg_reviewer_ci_path templates/delegation/debate-turn.md
); then
  fail 'matching reviewer header must preserve complete classifier output'
fi
if (
  tg_legacy_classify() { printf 'reviewer=true\n'; return 23; }
  tg_reviewer_ci_path templates/delegation/debate-turn.md
); then
  fail 'classifier failure must refuse even with a matching reviewer header'
fi

# 1. Completeness: walk every tracked repository file the reviewer suites load,
#    transitively, and require the path list to cover each one. A file counts
#    as loaded when it is named by repository path ("tools/x.sh"), by a path
#    built from a script-directory variable ("$SCRIPT_DIR/ai-review-lifecycle",
#    "$(dirname "$0")/../tools/x.sh"), or is a sibling test library.
#    ai-review-preflight names every provider wrapper in its dispatch table but
#    runs only the one requested; the suites never request these, so they are
#    mentions, not dependencies. A new edge anywhere else fails this test.
# tests/lib-selection.sh is named in a task-gates.sh header comment, and this
# suite's own policy file is read (not loaded-from) by the classifier at runtime;
# following either as an edge would pull the whole CI selection layer into the
# reviewer lane. The policy file itself stays required below.
# bin/ai-gh and its managed helper closure are real sandbox source-release
# proof dependencies; keep them in the transitive walk and required lane.
# The scoped helper is called only for scoped-skills-install, a Linux-only
# installation action none of these Windows reviewer suites invokes. Its
# committed-integrity filename list is not a Windows runtime import closure.
MENTION_ONLY=' tools/scoped_skills_install.py bin/ai-claude-review bin/ai-deepseek-agent bin/ai-gemini bin/ai-glm bin/ai-kimi bin/ai-qwen bin/ai-stepfun bin/ai-grok-review bin/ai-grok-implement skills/shared/grok-cli tests/grok-auth-link-cases.sh tools/lib/grok-paid-keys.sh tools/lib/grok-runtime.sh tools/lib/gemini-review-contract.sh tests/test-ai-grok-review.sh tests/lib-selection.sh config/reviewer-ci-paths.txt '
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
# Classification glob strings declare task ownership, rather than loading the
# files they name. Keep the policy itself required below, without following
# those metadata names into unrelated installer/global dependency trees.
runtime_references() {
  [ "$1" != config/task-gates.json ] || return 0
  local ref
  while IFS= read -r ref; do
    case "$MENTION_ONLY" in *" $ref "*) continue ;; esac
    printf '%s\n' "$ref"
  done < <(references "$1")
}
if [ -n "$(runtime_references config/task-gates.json)" ]; then
  fail 'classification glob metadata must not become executable dependency edges'
fi
# An ordinary executable edge must still be discovered and require coverage.
# This intentionally uncovered helper is only a synthetic extraction fixture.
fixture="$(mktemp "${TMPDIR:-/tmp}/reviewer-ci-edge.XXXXXX")" || exit 1
trap 'rm -f -- "$fixture"' EXIT
printf 'source tools/not-covered-runtime-helper.sh\n' > "$fixture"
if ! runtime_references "$fixture" | grep -x tools/not-covered-runtime-helper.sh >/dev/null; then
  fail 'ordinary runtime helper edge disappeared from dependency traversal'
fi
if tg_reviewer_ci_path tools/not-covered-runtime-helper.sh; then
  fail 'uncovered ordinary runtime helper must still require explicit lane coverage'
fi

declare -A seen=()
queue=(tests/test-delegation-templates.sh tests/test-ai-review-packet.sh)
while [ "${#queue[@]}" -gt 0 ]; do
  file="${queue[0]}"; queue=("${queue[@]:1}")
  [ -z "${seen[$file]:-}" ] || continue
  seen["$file"]=1
  while IFS= read -r ref; do
    [ -n "$ref" ] && tracked "$ref" || continue
    case "$MENTION_ONLY" in *" $ref "*) continue ;; esac
    [ -n "${seen[$ref]:-}" ] || queue+=("$ref")
  done < <(runtime_references "$file" | sort -u)
done
[ "${#seen[@]}" -ge 20 ] || fail "dependency walk found only ${#seen[@]} files"
for file in "${!seen[@]}"; do
  tg_reviewer_ci_path "$file" || fail "reviewer suite dependency is not a reviewer CI path: $file"
done
for file in tools/generated_definition_action.py tests/test_generated_definition_action.py config/review-action-profiles.json \
  bin/ai-gh tools/application_source_release.py tools/github-requests/telemetry.sh \
  tools/github-requests/pr-status-context tools/github-requests/pr_status_singleflight.py \
  templates/delegation/debate-turn.md \
  bin/ai-review-preflight bin/ai-review-lifecycle bin/ai-task-gates bin/ai-task-gates.cmd \
  config/task-gates.json config/reviewer-ci-paths.txt tests/test-reviewer-ci-paths.sh; do
  tg_reviewer_ci_path "$file" || fail "required reviewer CI path missing: $file"
done
for file in README.md docs/ci-speed-audit-2026-09-17.md bin/ai-pr-wait bin/ai-glm \
  .github/workflows/docs-reachability.yml tests/test-ai-task-gates.sh; do
  ! tg_reviewer_ci_path "$file" || fail "unrelated path selects the reviewer lane: $file"
done

if [ "$failures" -ne 0 ]; then
  printf 'test-reviewer-ci-paths: %s failure(s)\n' "$failures" >&2
  exit 1
fi
printf 'test-reviewer-ci-paths: PASS (%s reviewer dependencies covered)\n' "${#seen[@]}"
