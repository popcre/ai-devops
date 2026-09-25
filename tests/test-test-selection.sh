#!/usr/bin/env bash
# Suite selection for tests/test-all.sh (issues #163, #805). Fast and offline.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib-selection.sh"

fails=0; n=0; total=19
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
check 'workflow runner changes fail closed to every suite' \
  'test-ai-adopt-globals.sh test-ai-facts.sh test-ai-gh.sh test-ai-install-skills.sh test-ai-repo-policy.sh test-bin-cmd-launchers.sh test-markdown-links.sh test-repository-policy.sh test-workflow-policy.sh' \
  "$(aff '.github/workflows/verify.yml')"
check 'a deleted or unknown test file fails closed to every suite' \
  'test-ai-adopt-globals.sh test-ai-facts.sh test-ai-gh.sh test-ai-install-skills.sh test-ai-repo-policy.sh test-bin-cmd-launchers.sh test-markdown-links.sh test-repository-policy.sh test-workflow-policy.sh' \
  "$(aff 'tests/test-does-not-exist.sh')"

printf '\nSELECTION SUMMARY tests=%s failures=%s\n' "$n" "$fails"
[ "$fails" -eq 0 ]
