#!/usr/bin/env bash
# Evaluate the stable required context for pull-request and merge-queue runs.
set -uo pipefail

[ "$#" -eq 7 ] || {
  echo 'verify-closure: event classifier run-long evidence linux windows reviewer are required.' >&2
  exit 2
}

EVENT="$1"
CLASSIFIER_RESULT="$2"
RUN_LONG="$3"
EVIDENCE_RESULT="$4"
LINUX_RESULT="$5"
WINDOWS_RESULT="$6"
REVIEWER_RESULT="$7"

printf 'event=%s classifier=%s run_long=%s evidence=%s linux=%s windows=%s reviewer=%s\n' \
  "$EVENT" "$CLASSIFIER_RESULT" "$RUN_LONG" "$EVIDENCE_RESULT" \
  "$LINUX_RESULT" "$WINDOWS_RESULT" "$REVIEWER_RESULT"

[ "$CLASSIFIER_RESULT" = success ] || {
  echo 'verify-closure: change classification did not succeed.' >&2
  exit 1
}
[ "$EVIDENCE_RESULT" = success ] || {
  echo 'verify-closure: merge-group evidence did not succeed.' >&2
  exit 1
}

if [ "$EVENT" = merge_group ]; then
  [ "$LINUX_RESULT" = success ] || {
    echo 'verify-closure: merge-group Linux verification did not succeed.' >&2
    exit 1
  }
  echo 'verify-closure: merge-group evidence and Linux verification succeeded.'
  exit 0
fi

[ "$EVENT" = pull_request ] || {
  echo "verify-closure: unsupported required-check event $EVENT." >&2
  exit 2
}
case "$RUN_LONG" in
  true)
    [ "$LINUX_RESULT" = success ] || {
      echo 'verify-closure: exact-head Linux verification did not succeed.' >&2
      exit 1
    } ;;
  false)
    [ "$LINUX_RESULT" = skipped ] || {
      echo 'verify-closure: prose-only Linux result was not the declared skip.' >&2
      exit 1
    } ;;
  *)
    echo 'verify-closure: classifier run-long output was missing or malformed.' >&2
    exit 1 ;;
esac
[ "$WINDOWS_RESULT" = success ] || {
  echo 'verify-closure: exact-head Windows verification did not succeed.' >&2
  exit 1
}
[ "$REVIEWER_RESULT" = success ] || {
  echo 'verify-closure: exact-head reviewer safety did not succeed.' >&2
  exit 1
}
echo 'verify-closure: every exact-head pull-request proof succeeded.'
