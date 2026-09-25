#!/usr/bin/env bash
# Count BlockerWatch GitHub calls from the ai-gh measurement log.
set -u
dir="${1:-$HOME/.ai-devops/gh-throttle/measurements}"
day="${2:-$(date -u +%Y-%m-%d)}"
f="$dir/$day.jsonl"
[ -f "$f" ] || { echo "no $f"; exit 1; }
echo "file=$f"
echo "hour utc  total  rest  graphql  writes"
for h in $(seq -w 0 23); do
  total=$(rg "ai-blocker-watch" "$f" | rg -c "\"utc\":\"${day}T${h}:" || true)
  [ "${total:-0}" -gt 0 ] || continue
  rest=$(rg "ai-blocker-watch" "$f" | rg "\"utc\":\"${day}T${h}:" | rg -c 'api\.unknown' || true)
  gql=$(rg "ai-blocker-watch" "$f" | rg "\"utc\":\"${day}T${h}:" | rg -c 'api\.graphql' || true)
  wr=$(rg "ai-blocker-watch" "$f" | rg "\"utc\":\"${day}T${h}:" | rg -c 'issue\.(comment|create|edit)' || true)
  echo "$h     $total  ${rest:-0}  ${gql:-0}  ${wr:-0}"
done
echo "day_total=$(rg -c 'ai-blocker-watch' "$f" || true)"
