#!/usr/bin/env bash
# Keep shared-path detector coverage independent of the retired release check.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/lib/review-capabilities.sh"
for path in bin/ai-review bin/ai-review-engine bin/ai-task-gates \
  bin/ai-muse bin/ai-glm.cmd tools/lib/review-capabilities.sh \
  tools/lib/review-lifecycle-core.sh config/review-runner-doors.json; do
  review_shared_code_changed "$path" || { echo "FAIL: missed $path"; exit 1; }
  [[ -n "$(review_shared_code_rule "$path")" ]]
done
for path in README.md docs/deployment.md bin/ai-review-unrelated \
  tools/lib/review-capabilities.sh.bak unrelated/bin/ai-review; do
  if review_shared_code_changed "$path"; then
    echo "FAIL: matched $path"; exit 1
  fi
  [[ -z "$(review_shared_code_rule "$path")" ]]
done
review_shared_code_changed $'README.md\nbin/ai-muse\ndocs/deployment.md'
echo 'PASS: shared review detector matches exact paths and mixed changes'
