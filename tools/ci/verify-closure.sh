#!/usr/bin/env bash
# Evaluate the stable required context for pull-request and merge-queue runs.
#
# Selection, fast validation and every required lane are evaluated as one truth
# table over success / failure / cancelled / skipped / missing. A known terminal
# fast-validation failure is the signal that must stop every expensive suite
# before it starts; closure fails it here. A missing or invalid selection never
# becomes a green skip: closure refuses to close. A cancelled or missing lane is
# no progress, never a pass.
set -uo pipefail

[ "$#" -eq 8 ] || {
  echo 'verify-closure: event selection run_long validation evidence linux windows reviewer are required.' >&2
  exit 2
}

EVENT="$1"
SELECTION_RESULT="$2"
RUN_LONG="$3"
VALIDATION_RESULT="$4"
EVIDENCE_RESULT="$5"
LINUX_RESULT="$6"
WINDOWS_RESULT="$7"
REVIEWER_RESULT="$8"

printf 'event=%s selection=%s run_long=%s validation=%s evidence=%s linux=%s windows=%s reviewer=%s\n' \
  "$EVENT" "$SELECTION_RESULT" "$RUN_LONG" "$VALIDATION_RESULT" \
  "$EVIDENCE_RESULT" "$LINUX_RESULT" "$WINDOWS_RESULT" "$REVIEWER_RESULT"

# Map a job result onto the truth-table vocabulary. Anything outside the known
# GitHub conclusions is "missing": it is never treated as progress or as proof.
classify_result() {
  case "$1" in
    success|failure|cancelled|skipped) printf '%s' "$1" ;;
    *) printf 'missing' ;;
  esac
}

# 1. Fast validation. A known terminal failure here is exactly the case that
#    must stop every expensive suite before it starts. Cancellation and a
#    missing validation proof fail closure too: there is no proof to trust.
VALIDATION_STATE="$(classify_result "$VALIDATION_RESULT")"
case "$VALIDATION_STATE" in
  success) ;;
  failure)
    echo 'verify-closure: fast validation failed; expensive suites were not started.' >&2
    exit 1 ;;
  cancelled)
    echo 'verify-closure: fast validation was cancelled; there is no validation proof.' >&2
    exit 1 ;;
  skipped)
    echo 'verify-closure: fast validation was skipped; there is no validation proof.' >&2
    exit 1 ;;
  *)
    echo 'verify-closure: fast validation result was missing.' >&2
    exit 1 ;;
esac

# 2. Selection. An unknown selection is never a green skip. The expensive lanes
#    were run conservatively, and closure still refuses to close without a real
#    classification result.
SELECTION_STATE="$(classify_result "$SELECTION_RESULT")"
if [ "$SELECTION_STATE" != success ]; then
  echo "verify-closure: change classification did not succeed (state=$SELECTION_STATE)." >&2
  exit 1
fi

# 3. Merge-queue evidence gate.
EVIDENCE_STATE="$(classify_result "$EVIDENCE_RESULT")"
if [ "$EVIDENCE_STATE" != success ]; then
  echo "verify-closure: merge-group evidence did not succeed (state=$EVIDENCE_STATE)." >&2
  exit 1
fi

if [ "$EVENT" = merge_group ]; then
  LINUX_STATE="$(classify_result "$LINUX_RESULT")"
  if [ "$LINUX_STATE" != success ]; then
    echo "verify-closure: merge-group Linux verification did not succeed (state=$LINUX_STATE)." >&2
    exit 1
  fi
  echo 'verify-closure: merge-group evidence and Linux verification succeeded.'
  exit 0
fi

if [ "$EVENT" != pull_request ]; then
  echo "verify-closure: unsupported required-check event $EVENT." >&2
  exit 2
fi

# 4. Required exact-head lanes. Each lane must report a real outcome: a missing
#    or cancelled lane is no progress and fails closure, and a declared
#    prose-only skip is accepted only where the lane is allowed to skip.
LINUX_STATE="$(classify_result "$LINUX_RESULT")"
WINDOWS_STATE="$(classify_result "$WINDOWS_RESULT")"
REVIEWER_STATE="$(classify_result "$REVIEWER_RESULT")"

case "$RUN_LONG" in
  true)
    if [ "$LINUX_STATE" != success ]; then
      echo "verify-closure: exact-head Linux verification did not succeed (state=$LINUX_STATE)." >&2
      exit 1
    fi ;;
  false)
    if [ "$LINUX_STATE" != skipped ]; then
      echo "verify-closure: prose-only Linux result was not the declared skip (state=$LINUX_STATE)." >&2
      exit 1
    fi ;;
  *)
    echo 'verify-closure: classifier run-long output was missing or malformed.' >&2
    exit 1 ;;
esac

if [ "$WINDOWS_STATE" != success ]; then
  echo "verify-closure: exact-head Windows verification did not succeed (state=$WINDOWS_STATE)." >&2
  exit 1
fi
if [ "$REVIEWER_STATE" != success ]; then
  echo "verify-closure: exact-head reviewer safety did not succeed (state=$REVIEWER_STATE)." >&2
  exit 1
fi
echo 'verify-closure: every exact-head pull-request proof succeeded.'
