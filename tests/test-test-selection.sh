#!/usr/bin/env bash
# Suite selection for tests/test-all.sh (issues #163, #805). Fast and offline.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib-selection.sh"

fails=0; n=0; total=29
check() { # check <label> <expected> <actual>
  n=$((n + 1))
  if [ "$2" = "$3" ]; then
    printf '%s/%s ok  %s\n' "$n" "$total" "$1"
  else
    printf '%s/%s FAIL %s\n      expected: %s\n      actual:   %s\n' "$n" "$total" "$1" "$2" "$3"
    fails=$((fails + 1))
  fi
}
cats() { printf '%s\n' "$1" | selection_categories_for_paths "$ROOT"; }

SUITES='test-ai-grok-review.sh test-ai-install-skills.sh test-ai-adopt-globals.sh test-workflow-policy.sh test-markdown-links.sh test-ai-facts.sh'
# shellcheck disable=SC2086
sel() { selection_by_categories "$1" $SUITES | tr '\n' ' ' | sed 's/ $//'; }

check 'prose paths classify as prose' \
  'prose' "$(cats 'docs/deployment.md
README.md')"
check 'skills-only change classifies as skills' \
  'skills' "$(cats 'skills/shared/wrap-up/SKILL.md')"
check 'workflow-only change classifies as workflow' \
  'workflow' "$(cats '.github/workflows/verify.yml')"
check 'PowerShell-only change classifies as powershell' \
  'powershell' "$(cats 'tests/test-all.ps1')"
check 'bin change classifies as code' \
  'code' "$(cats 'bin/ai-facts')"
check 'mixed change keeps every relevant category' \
  'skills workflow code' "$(cats 'skills/shared/wrap-up/SKILL.md
.github/workflows/verify.yml
bin/ai-facts')"

check 'prose selects no Bash suite' '' "$(sel prose)"
check 'powershell selects no Bash suite' '' "$(sel powershell)"
check 'skills selects only skills-facing suites' \
  'test-ai-adopt-globals.sh test-ai-install-skills.sh test-markdown-links.sh' "$(sel skills)"

# --- Affected-suite mapping (issue #805) ---
aff() { printf '%s\n' "$1" | selection_affected_suites "$ROOT" test-ai-facts.sh test-ai-gh.sh test-bin-cmd-launchers.sh test-ai-install-skills.sh test-ai-adopt-globals.sh test-markdown-links.sh test-repository-policy.sh test-ai-repo-policy.sh test-workflow-policy.sh | tr '\n' ' ' | sed 's/ $//'; }

check 'a one-file wrapper maps to its dedicated suite' \
  'test-ai-facts.sh' "$(aff 'bin/ai-facts')"
check 'a .cmd launcher also proves the launcher suite' \
  'test-ai-facts.sh test-bin-cmd-launchers.sh' "$(aff 'bin/ai-facts.cmd')"
check 'an unmapped bin tool fails closed to every suite' \
  'test-ai-adopt-globals.sh test-ai-facts.sh test-ai-gh.sh test-ai-install-skills.sh test-ai-repo-policy.sh test-bin-cmd-launchers.sh test-markdown-links.sh test-repository-policy.sh test-workflow-policy.sh' \
  "$(aff 'bin/ai-unknown-tool')"
check 'documentation alone selects no Bash suite' \
  '' "$(aff 'docs/development.md')"
check 'a shared harness change fails closed to every suite' \
  'test-ai-adopt-globals.sh test-ai-facts.sh test-ai-gh.sh test-ai-install-skills.sh test-ai-repo-policy.sh test-bin-cmd-launchers.sh test-markdown-links.sh test-repository-policy.sh test-workflow-policy.sh' \
  "$(aff 'tests/lib-test-harness.sh')"
check 'skills markdown stays on the skills-facing suites' \
  'test-ai-adopt-globals.sh test-ai-install-skills.sh test-markdown-links.sh' \
  "$(aff 'skills/shared/wrap-up/SKILL.md')"
check 'an explicit non-conventional name uses its declared map' \
  'test-repository-policy.sh' "$(aff 'bin/ai-repo-policy')"
check 'a suite editing itself stays on that suite' \
  'test-ai-facts.sh' "$(aff 'tests/test-ai-facts.sh')"
check 'a PowerShell script selects the repository-wide ASCII guard' \
  'test-windows-scripts.sh' \
  "$(printf '%s\n' 'scripts/ai-housekeeping/cleanup-ai-debris.ps1' | selection_affected_suites "$ROOT" test-ai-facts.sh test-windows-scripts.sh)"
check 'a PowerShell module does not claim the script-only ASCII guard' \
  '' \
  "$(printf '%s\n' 'scripts/sample.psm1' | selection_affected_suites "$ROOT" test-ai-facts.sh test-windows-scripts.sh)"
check 'workflow runner changes fail closed to every suite' \
  'test-ai-adopt-globals.sh test-ai-facts.sh test-ai-gh.sh test-ai-install-skills.sh test-ai-repo-policy.sh test-bin-cmd-launchers.sh test-markdown-links.sh test-repository-policy.sh test-workflow-policy.sh' \
  "$(aff '.github/workflows/verify.yml')"
check 'a deleted or unknown test file fails closed to every suite' \
  'test-ai-adopt-globals.sh test-ai-facts.sh test-ai-gh.sh test-ai-install-skills.sh test-ai-repo-policy.sh test-bin-cmd-launchers.sh test-markdown-links.sh test-repository-policy.sh test-workflow-policy.sh' \
  "$(aff 'tests/test-does-not-exist.sh')"

# --- Reviewer-owned paths stay narrow (issue #1563) ---
# shellcheck disable=SC2207
ALL_SUITES=($(cd "$ROOT/tests" && ls test-*.sh))
ALL_LIST="$(printf '%s\n' "${ALL_SUITES[@]}" | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')"
raff() { printf '%s\n' "$1" | selection_affected_suites "$ROOT" "${ALL_SUITES[@]}" | tr '\n' ' ' | sed 's/ $//'; }
mapped() { jq -r --arg p "$1" '.affected_suite_rules.path_suites[$p][]' "$ROOT/config/ci-suite-manifest.json" | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//'; }
deepseek_door="$(raff 'tools/lib/review-doors/deepseek.sh')"
check 'a reviewer door selects its declared suites, not every suite' \
  "$(mapped 'tools/lib/review-doors/deepseek.sh')" "$deepseek_door"
case " $deepseek_door " in
  *' test-ai-deepseek-agent.sh '*' test-ai-review-engine.sh '*) door_ok=yes ;;
  *) door_ok=no ;;
esac
check 'a reviewer door keeps its engine and shared review-engine suites' 'yes' "$door_ok"
check 'a reviewer door with no declared suites fails closed to every suite' \
  "$ALL_LIST" "$(raff 'tools/lib/review-doors/nosuch.sh')"
check 'shared task-gates library still fails closed to every suite' \
  "$ALL_LIST" "$(raff 'tools/lib/task-gates.sh')"
check 'a mapped reviewer tool selects exactly its declared suites' \
  "$(mapped 'tools/reviewer_credit_watch.py')" "$(raff 'tools/reviewer_credit_watch.py')"
check 'the GLM maintenance helper selects its lock regression suite' \
  'test-ai-glm.sh' "$(raff 'tools/lib/opencode-maintenance-lock.sh')"
check 'an unmapped new tools/lib file fails closed to every suite' \
  "$ALL_LIST" "$(raff 'tools/lib/brand-new-helper.sh')"
gone_manifest="$(mktemp)"
jq '.affected_suite_rules.path_suites["tools/lib/review-doors/removed.sh"] = ["test-ai-review-engine.sh"]' \
  "$ROOT/config/ci-suite-manifest.json" > "$gone_manifest"
check 'a deleted reviewer door fails closed to every suite' \
  "$ALL_LIST" "$(AI_CI_SUITE_MANIFEST="$gone_manifest" raff 'tools/lib/review-doors/removed.sh')"
rm -f "$gone_manifest"

printf '\nSELECTION SUMMARY tests=%s failures=%s\n' "$n" "$fails"
[ "$fails" -eq 0 ]
