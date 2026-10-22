#!/usr/bin/env bash
# Shared by every runner door's extract_report (deepseek, gemini, grok, muse,
# qwen, stepfun). Reviewer profiles and older briefs may end with
# "VERDICT: <word> <head>" instead of the "## Verdict" heading the pool and
# lifecycle require. Convert that terminal line into the recorded ## Verdict
# block so the decision is kept instead of a false BLOCKED (edge-dev incidents
# 20261018T200816Z / 20261019T151933Z, #1947). Never invents a decision.

# rtv_has_terminal_verdict < TEXT — exit 0 when the last non-blank line is a
# bare decision (optionally prefixed "VERDICT:", optionally followed by a
# hex head SHA). Qualified decisions are not terminal verdicts.
rtv_has_terminal_verdict() {
  awk '
    { lines[NR]=$0 }
    NF { last=NR }
    END {
      if (last < 1) exit 1
      t = lines[last]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
      if (t !~ /^(VERDICT:[[:space:]]*)?(APPROVE|REJECT|REVISE|BLOCKED)([^A-Z0-9_]|$)/) exit 1
      # Accept only "<word>" or "<word> <hex sha>": a qualified line such as
      # "APPROVE only after X" must fail closed as BLOCKED (#1973).
      sub(/^VERDICT:[[:space:]]*/, "", t)
      gsub(/\*+/, "", t)
      sub(/^(APPROVE|REJECT|REVISE|BLOCKED)/, "", t)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
      if (t == "" || t ~ /^[0-9a-f]+$/) exit 0
      exit 1
    }'
}

# rtv_emit_terminal_verdict < TEXT — findings, then a ## Verdict block holding
# only the bare decision word (rlc_parse_verdict accepts a bare word only).
rtv_emit_terminal_verdict() {
  local text
  text="$(cat)"
  printf '### Findings and reasoning\n\n'
  printf '%s\n' "$text" | sed '/^$/d' | sed '$d'
  printf '\n---\n\n## Verdict\n'
  printf '%s\n' "$text" | awk '
    { lines[NR]=$0 }
    NF { last=NR }
    END {
      t = lines[last]
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
      sub(/^[Vv][Ee][Rr][Dd][Ii][Cc][Tt][[:space:]]*:[[:space:]]*/, "", t)
      gsub(/\*+/, "", t)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", t)
      split(t, w, /[[:space:]]+/)
      print w[1]
    }'
}
