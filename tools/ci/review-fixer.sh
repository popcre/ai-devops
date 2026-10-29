#!/usr/bin/env bash
# Automatic fixer for one `review-finding` issue (plan_simple-reviewer-rebuild.md
# REVISION phase A). A headless Codex run decides whether each finding is real,
# fixes the real ones and runs the relevant tests. This script then commits,
# pushes `review-fix/<issue>` and opens a PR, or closes the issue as not
# planned, and labels it fixer-done or fixer-failed.
#
#   review-fixer.sh ISSUE_NUMBER
#
# Env: GITHUB_REPOSITORY, GH_TOKEN (workflow token for issue edits),
# AI_GH_SIGNATURE, REVIEW_FIXER_AGENT (default "codex"), WORK_ROOT.
set -uo pipefail
issue="${1:?issue number}"
[[ "$issue" =~ ^[0-9]+$ ]] || { echo "bad issue number" >&2; exit 2; }
repo="${GITHUB_REPOSITORY:?}"
sig="${AI_GH_SIGNATURE:-Posted by review-fixer}"
agent="${REVIEW_FIXER_AGENT:-codex}"
root="${WORK_ROOT:-${RUNNER_TEMP:-/tmp}}/review-fixer-$issue"
branch="review-fix/$issue"

label() { gh issue edit "$issue" --repo "$repo" --add-label "$1" >/dev/null || true; }
fail() {
  echo "::error::$1"
  gh issue comment "$issue" --repo "$repo" --body "$(printf 'Automatic fixer failed: %s\n\n%s\n' "$1" "$sig")" >/dev/null || true
  label fixer-failed; exit 1
}
for l in fixer-done fixer-failed; do
  gh label create "$l" --repo "$repo" --color 5319E7 --description "review-fixer outcome" 2>/dev/null || true
done

# Push and open PRs as the runner user's own gh login when it works, so the
# fix PR runs CI; fall back to the workflow token otherwise.
if env -u GH_TOKEN gh auth token >/dev/null 2>&1; then
  pgh() { env -u GH_TOKEN gh "$@"; }
else
  pgh() { gh "$@"; }
fi

body="$(gh issue view "$issue" --repo "$repo" --json body --jq .body)" || fail "could not read the issue"
pr="$(grep -oE "github\.com/$repo/pull/[0-9]+" <<<"$body" | head -1 | grep -oE '[0-9]+$' || true)"
base=main
if [ -n "$pr" ]; then
  read -r state head_ref head_repo < <(gh pr view "$pr" --repo "$repo" \
    --json state,headRefName,headRepositoryOwner,headRepository \
    --jq '"\(.state) \(.headRefName) \(.headRepositoryOwner.login)/\(.headRepository.name)"') || true
  if [ "${state:-}" = OPEN ] && [ "${head_repo:-}" = "$repo" ]; then base="$head_ref"; fi
fi

rm -rf "$root"; mkdir -p "$root"
work="$root/repo"
pgh repo clone "$repo" "$work" -- --quiet --branch "$base" || fail "could not clone $repo at $base"
git -C "$work" checkout -q -b "$branch" || fail "could not create $branch"

prompt="$root/prompt.md"
cat > "$prompt" <<EOF
You are the automatic fixer for GitHub issue #$issue in $repo. The repository
is checked out at branch $branch, made from $base. The issue holds findings
from an advisory AI code review:

----- issue body -----
$body
----- end issue body -----

Do this:
1. Read the code each finding points at and decide whether it is real.
2. Fix every real finding with the smallest correct change. Do not touch
   anything unrelated. Do not commit, push, or open PRs; the caller does that.
3. Run only the tests that exercise the files you changed (see the tests/
   folder) and make sure they pass. Use PYTHONDONTWRITEBYTECODE=1 for Python.
   You run in a sandbox with no network and no installed toolkit, so suites
   that need either cannot run here; do not run them, and never count their
   setup errors as a failure of your fix. Full CI runs on the PR afterwards.
   If no test covers the changed files, say so and treat the fix as tested.
   Ignore any personal or global instructions about reply format; end exactly
   as step 4 says.
4. End your final message with exactly one line:
   DECISION: FIXED   (you changed files and the tests pass)
   DECISION: INVALID (every finding is wrong; explain why above that line)
   DECISION: FAILED  (you could not fix it; explain why above that line)
Above the decision line, write a short plain summary of each finding and what
you did, suitable for a PR body.
EOF

last="$root/last.txt"
# The agent reads untrusted findings text, so it runs with no GitHub token and
# no reviewer provider keys in its environment (plan section 8.5). Codex's
# workspace-write sandbox also has no network access.
scrub=(env -u GH_TOKEN -u GITHUB_TOKEN -u MODEL_API_KEY -u AI_MUSE_KEY
  -u DEEPSEEK_API_KEY -u STEPFUN_API_KEY -u AI_STEPFUN_KEY -u ZHIPU_API_KEY
  -u ZAI_API_KEY -u AI_REVIEW_SIMPLE_SECRETS_DIR -u OP_SERVICE_ACCOUNT_TOKEN)
case "$agent" in
  codex)
    timeout 40m "${scrub[@]}" codex exec -C "$work" -s workspace-write --skip-git-repo-check \
      -o "$last" - < "$prompt" > "$root/agent.log" 2>&1 ;;
  claude)
    (cd "$work" && timeout 40m "${scrub[@]}" claude -p --permission-mode acceptEdits < "$prompt" > "$last" 2> "$root/agent.log") ;;
  *) fail "unknown REVIEW_FIXER_AGENT '$agent'" ;;
esac
rc=$?
tail -40 "$root/agent.log" || true
[ -s "$last" ] || fail "the $agent run produced no report (exit $rc)"
decision="$(grep -oE '^DECISION: (FIXED|INVALID|FAILED)' "$last" | tail -1 | awk '{print $2}')"
report="$(grep -vE '^DECISION:' "$last" | head -c 50000)"
echo "decision: ${decision:-none} (agent exit $rc)"

case "$decision" in
  FIXED)
    git -C "$work" add -A
    git -C "$work" diff --cached --quiet && fail "the agent reported FIXED but changed no files"
    # Enforced outside the agent: a fix may never touch workflows, installers
    # or the task gates (plan section 8.5).
    denied="$(git -C "$work" diff --cached --name-only | grep -E \
      '^(\.github/workflows/|install\.sh$|update\.sh$|bin/install-ai-devops-windows\.ps1$|config/task-gates\.json$|bin/ai-task-gates$)' || true)"
    [ -z "$denied" ] || fail "the fix touched protected files, refusing to push: $(tr '\n' ' ' <<<"$denied")"
    git -C "$work" commit -q -m "Fix review finding #$issue" \
      -m "Automatic fix by review-fixer ($agent)." || fail "commit failed"
    git -C "$work" -c credential.helper= -c credential.helper='!gh auth git-credential' \
      push -q -u origin "$branch" || fail "push of $branch failed"
    url="$(pgh pr create --repo "$repo" --base "$base" --head "$branch" \
      --title "Fix review finding #$issue" \
      --body "$(printf 'Closes #%s\n\n%s\n\n%s\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\n' "$issue" "$report" "$sig")")" \
      || fail "could not open the fix PR"
    gh issue comment "$issue" --repo "$repo" --body "$(printf 'Fix PR: %s\n\n%s\n' "$url" "$sig")" >/dev/null || true
    label fixer-done; echo "opened $url" ;;
  INVALID)
    gh issue comment "$issue" --repo "$repo" --body "$(printf '%s\n\n%s\n' "$report" "$sig")" >/dev/null || true
    label fixer-done
    gh issue close "$issue" --repo "$repo" --reason "not planned" >/dev/null || true ;;
  *)
    fail "the $agent run ended with ${decision:-no decision} (exit $rc). ${report:0:3000}" ;;
esac
