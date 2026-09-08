#!/usr/bin/env bash
# Suite selection for tests/test-all.sh (issue #163). Fast and offline.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/tests/lib-selection.sh"

fails=0; n=0
check() { # check <label> <expected> <actual>
  n=$((n + 1))
  if [ "$2" = "$3" ]; then
    printf '%s/9 ok  %s\n' "$n" "$1"
  else
    printf '%s/9 FAIL %s\n      expected: %s\n      actual:   %s\n' "$n" "$1" "$2" "$3"
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

printf '\nSELECTION SUMMARY tests=%s failures=%s\n' "$n" "$fails"
[ "$fails" -eq 0 ]
