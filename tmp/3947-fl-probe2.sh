#!/usr/bin/env bash
set -euo pipefail
GH="${GH:-C:/repos/ai-devops/bin/ai-gh}"
REPO="popcre/shared-db"

case "${1:-}" in
  issue3947-fence)
    "$GH" api "repos/$REPO/issues/3947/comments" --paginate \
      --jq '.[] | {id, created_at, user:.user.login, body:(.body|tostring)}' \
      | rg -i -n 'fence|approve|e35c1ecde|20261007190954|risk' | head -60
    ;;
  issue3947-last)
    "$GH" api "repos/$REPO/issues/3947/comments" --paginate \
      --jq '.[-12:] | .[] | {id, created_at, user:.user.login, body:(.body|tostring|.[0:400])}'
    ;;
  pr4047-comments)
    "$GH" api "repos/$REPO/issues/4047/comments" --paginate \
      --jq '.[] | {id, created_at, user:.user.login, body:(.body|tostring|.[0:400])}' | tail -80
    ;;
  exact-head)
    cd /c/repos/shared-db
    PR_NUMBER=4047 REQUESTED_SHA="e35c1ecde901b55e7ed3a343da685d5f2c4c7a37" \
      node scripts/check-exact-head-approval.mjs
    ;;
  verdict-refs)
    cd /c/repos/shared-db
    git fetch --quiet origin \
      'refs/db-review-verdicts/*3947*' \
      'refs/db-review-verdict-replacements/*3947-4047*' 2>/dev/null || true
    git ls-remote origin | rg 'db-review-verdict' | rg '3947'
    ;;
  fetch-verdict-content)
    # Dump the two verdict-replacement refs' commit messages / tree
    cd /c/repos/shared-db
    for ref in \
      refs/db-review-verdict-replacements/3947-4047-e35c1ecde901b55e7ed3a343da685d5f2c4c7a37-5687 \
      refs/db-review-verdict-replacements/3947-4047-e35c1ecde901b55e7ed3a343da685d5f2c4c7a37-slot2-5694
    do
      echo "===== $ref ====="
      git fetch --quiet origin "$ref" || { echo "fetch failed"; continue; }
      sha=$(git rev-parse FETCH_HEAD)
      echo "sha=$sha"
      git log -1 --format='%s%n%b' "$sha" | head -40
      echo "--- tree ---"
      git ls-tree -r "$sha" | head -20
    done
    ;;
  *)
    echo "usage: $0 <issue3947-fence|issue3947-last|pr4047-comments|exact-head|verdict-refs|fetch-verdict-content>"
    exit 2
    ;;
esac
