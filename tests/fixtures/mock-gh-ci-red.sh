#!/usr/bin/env bash
# Mock gh for test-report-ci-red.sh. Logs every call; returns fixtures.
log="${GH_LOG:?}"
echo "gh $*" >> "$log"
if [ -n "${GH_BODY_FILE:-}" ] && [[ "$1 $2" == 'issue create' || "$1 $2" == 'issue edit' ]]; then
  python3 -c 'import json,sys; args=sys.argv[2:]; json.dump({"body":args[args.index("--body")+1]}, open(sys.argv[1], "w"))' "$GH_BODY_FILE" "$@"
fi
case "$1 $2" in
  "issue list")
    if [[ "$*" == *"--label ci-red"* ]]; then
      if [ -n "${GH_FIXTURE_ISSUE:-}" ]; then
        python3 -c 'import json,os; print(json.dumps([{"number":int(os.environ["GH_FIXTURE_ISSUE"]),"title":os.environ.get("GH_FIXTURE_TITLE", "ci-red: linux-offline (PR #7)")}]))'
      else
        echo '[]'
      fi
    fi
    ;;
  "issue view")
    # Simulate --jq for green-count queries.
    if [[ "$*" == *"--json comments"* ]]; then
      python3 -c 'import json,os; print(json.dumps({"comments":json.loads(os.environ["GH_FIXTURE_COMMENTS"]) if "GH_FIXTURE_COMMENTS" in os.environ else [{"body":"<!-- ci-red-green --> Green run: run/"+str(i)} for i in range(int(os.environ.get("GH_FIXTURE_GREEN_COUNT","0")))]}))'
    fi
    ;;
  "issue create")
    echo "#99"
    ;;
  "api repos/o/r/actions/runs/10/jobs")
    printf '%s\n' 'Linux offline "quoted"\suite=failure' 'Other suite=failure'
    ;;
esac
exit 0
