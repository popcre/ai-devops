#!/usr/bin/env bash
# observation-week.sh — the reviewer observation week window and its merge
# evidence (plan_reviewer-observation-week step 4).
#
# The window file is written per host at freeze start (step 6):
#   Linux   /etc/ai-devops/observation-week.json
#   Windows C:\ProgramData\ai-devops\observation-week.json
#   {"start":"<ISO-8601 UTC>","end":"<ISO-8601 UTC>","allowed_classes":["code","prose"]}
# AI_OBSERVATION_WEEK_FILE overrides the path (tests). A malformed, expired,
# future, over-long (> 8 days) window, or one that names any class other than
# code/prose, is NOT live: full gating applies and a warning says why.
# Deleting the file restores full gating with no reinstall.

ow_window_file() {
  if [ -n "${AI_OBSERVATION_WEEK_FILE:-}" ]; then printf '%s\n' "$AI_OBSERVATION_WEEK_FILE"; return 0; fi
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*) printf '%s\n' "/c/ProgramData/ai-devops/observation-week.json" ;;
    *) printf '%s\n' /etc/ai-devops/observation-week.json ;;
  esac
}

OW_START=""; OW_END=""; OW_CLASSES=""; OW_WHY=""

ow_window_live() { # -> 0 when a valid window covers now; OW_WHY says why not
  local file start end s e now
  OW_START=""; OW_END=""; OW_CLASSES=""; OW_WHY=""
  file="$(ow_window_file)"
  [ -f "$file" ] || { OW_WHY="no window file"; return 1; }
  jq -e 'type=="object" and (.start|type)=="string" and (.end|type)=="string" and (.allowed_classes|type)=="array"' "$file" >/dev/null 2>&1 \
    || { OW_WHY="window file is malformed: $file"; return 1; }
  if jq -e '.allowed_classes | map(select(. != "code" and . != "prose")) | length > 0' "$file" >/dev/null 2>&1; then
    OW_WHY="window file admits a protected class; only code and prose may merge unreviewed: $file"; return 1
  fi
  start="$(jq -r .start "$file" | tr -d '\r')"; end="$(jq -r .end "$file" | tr -d '\r')"
  s="$(date -u -d "$start" +%s 2>/dev/null)" && e="$(date -u -d "$end" +%s 2>/dev/null)" \
    || { OW_WHY="window dates are not ISO-8601: $file"; return 1; }
  now="$(date -u +%s)"
  [ "$e" -gt "$s" ] || { OW_WHY="window end is not after its start: $file"; return 1; }
  [ $((e - s)) -le $((8 * 86400)) ] || { OW_WHY="window is longer than eight days: $file"; return 1; }
  [ "$now" -ge "$s" ] || { OW_WHY="window has not started: $file"; return 1; }
  [ "$now" -lt "$e" ] || { OW_WHY="window has ended: $file"; return 1; }
  OW_START="$start"; OW_END="$end"
  OW_CLASSES="$(jq -r '.allowed_classes | join(" ")' "$file" | tr -d '\r')"
  return 0
}

ow_class_allowed() { # CLASS -> 0 when the live window admits it
  case " $OW_CLASSES " in *" $1 "*) return 0 ;; esac
  return 1
}

# Evidence that this exact head was sent for review: prints one of
#   approved <provider>        a scoreboard APPROVE for the head (not stale)
#   detached <run id>          an ai-review --detach run for the head
#   all-skipped <record id>    ai-review exit 75 (every reviewer skipped) for the head
# and returns 1 with nothing printed when there is none.
ow_head_evidence() { # HEAD
  local head="$1" board dir f id status
  [[ "$head" =~ ^[0-9a-f]{40}$ ]] || return 1
  board="${AI_REVIEW_SCOREBOARD_FILE:-${AI_REVIEW_SCOREBOARD_DIR:-$HOME/.local/state/ai-devops/review-scoreboard}/reviews.jsonl}"
  if [ -f "$board" ]; then
    local by
    by="$(jq -r --arg h "$head" 'select(.head==$h and .verdict=="APPROVE" and .stale!=true and .failure_class==null) | .provider' "$board" 2>/dev/null | tr -d '\r' | tail -1)"
    [ -z "$by" ] || { printf 'approved %s\n' "$by"; return 0; }
  fi
  dir="${AI_REVIEW_DETACH_DIR:-$HOME/.local/state/ai-devops/review-detached}"
  [ -d "$dir" ] || return 1
  for f in "$dir"/*.json; do
    [ -f "$f" ] || continue
    [ "$(jq -r '.head // empty' "$f" 2>/dev/null | tr -d '\r')" = "$head" ] || continue
    id="$(jq -r '.id // empty' "$f" 2>/dev/null | tr -d '\r')"
    status="$(jq -r '.status // empty' "$f" 2>/dev/null | tr -d '\r')"
    case "$status" in
      all-skipped) printf 'all-skipped %s\n' "$id"; return 0 ;;
      pending|finished)
        [ -n "$id" ] || continue
        # Finished with no lifecycle carrying this id: refused before dispatch.
        if [ -f "$dir/$id.result.json" ] && ! grep -rqlE --include='*.json' "\"detach_id\": ?\"$id\"" \
            "${AI_REVIEW_LIFECYCLE_DIR:-$HOME/.local/state/ai-devops/review-lifecycle}/runs" 2>/dev/null; then
          continue
        fi
        printf 'detached %s\n' "$id"; return 0 ;;
    esac
  done
  return 1
}
