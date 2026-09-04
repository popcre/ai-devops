#!/usr/bin/env bash
# Proves bin/ai-gemini emits a stdout body that u2giants/shared-db's
# scripts/run-governed-review.mjs can actually record, and that a response with no
# usable decision still fails instead of being defaulted into a verdict.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
FAIL=0
ok(){ printf 'ok   %s\n' "$1"; }
bad(){ printf 'FAIL %s\n' "$1"; FAIL=1; }

HEAD_SHA=ed2c61807a20528c2d278010d3a5c11dedc0b607
printf '{"head":"%s"}\n' "$HEAD_SHA" > "$WORK/meta.json"

# A response in Gemini's real shape: the decision heading FIRST, repeated later,
# plus a blockquoted and a bolded copy that the shared consumer predicate also reads.
resp='## Verdict
APPROVE

### Findings
- bin/foo looks fine.
> APPROVE
**REJECT** something
Approved usage of the cache is fine.

## Verdict
APPROVE'
jq -n --arg r "$resp" '{response:$r}' > "$WORK/out.json"
jq -n --arg r '## Verdict
BLOCKED

Cannot review: the packet is unreadable.' '{response:$r}' > "$WORK/blocked.json"

emit(){ # emit RESPONSE_JSON -> stdout, returns wrapper exit status
  ( set +u; source "$ROOT/bin/ai-gemini" --version >/dev/null 2>&1
    emit_governed_stdout "$1" "$WORK/meta.json" )
}

emit "$WORK/out.json" > "$WORK/body.txt" 2>"$WORK/body.err"; rc=$?
[ "$rc" -eq 0 ] && ok 'approve response emits successfully' || bad "approve response exited $rc: $(cat "$WORK/body.err")"

# A byte-faithful copy of run-governed-review.mjs verdictFromOutput and of
# lib/review-verdict.mjs lineOpensWithVerdictWord, so this repository can prove the
# contract without depending on a checkout of u2giants/shared-db. The "control"
# assertion below feeds this checker the UNFIXED response and requires it to say
# "not recordable", so a checker that always passes cannot go unnoticed.
cat > "$WORK/check.mjs" <<NODE
import fs from "node:fs"
const headSha = "$HEAD_SHA"
function verdictFromOutput(body){
  const lines=String(body??"").split(/\r?\n/).map((l)=>l.trim()).filter(Boolean)
  const v=lines.filter((l)=>/^VERDICT\s*:\s*(?:APPROVE|REVISE|REJECT)\b/i.test(l))
  if(v.length!==1||v[0]!==lines.at(-1))return null
  const m=/^VERDICT\s*:\s*(APPROVE|REVISE|REJECT)(?:\s+([0-9a-f]{40}))?\s*\$/i.exec(v[0])
  if(!m||!m[2]||m[2].toLowerCase()!==headSha.toLowerCase())return null
  return m[1].toUpperCase()
}
const stripVerdictLabel=(line)=>String(line).replace(/^[\s>*_#-]+/,"").replace(/^VERDICT\s*:\s*/i,"").replace(/^[\s*_]+/,"")
const VERDICT_WORD=/^(?:APPROVE(?:D)?|REJECT(?:ED)?|REVISE|REQUEST[_\s]CHANGES)(?![A-Za-z0-9])/i
const lineOpensWithVerdictWord=(line)=>VERDICT_WORD.test(stripVerdictLabel(line))
const body=fs.readFileSync(process.argv[2],"utf8").trim()
const lines=body.split(/\r?\n/).map((l)=>l.trim()).filter(Boolean)
const terminal=lines.at(-1)
const extra=lines.filter((l)=>l!==terminal&&lineOpensWithVerdictWord(l))
console.log(JSON.stringify({verdict:verdictFromOutput(body),extraDecisionLines:extra}))
NODE

result="$(node "$WORK/check.mjs" "$WORK/body.txt")"
[ "$(printf '%s' "$result" | jq -r .verdict)" = APPROVE ] \
  && ok 'runner parser records APPROVE from wrapper stdout' \
  || bad "runner parser returned $(printf '%s' "$result" | jq -r .verdict)"
[ "$(printf '%s' "$result" | jq -r '.extraDecisionLines|length')" = 0 ] \
  && ok 'no non-terminal line reads as a decision' \
  || bad "extra decision lines: $(printf '%s' "$result" | jq -c .extraDecisionLines)"
grep -q 'bin/foo looks fine' "$WORK/body.txt" && ok 'findings are preserved on stdout' || bad 'findings were dropped'

# Positive control: the checker must be able to FAIL. Feed it the raw response.
printf '%s\n' "$resp" > "$WORK/raw.txt"
raw="$(node "$WORK/check.mjs" "$WORK/raw.txt")"
[ "$(printf '%s' "$raw" | jq -r .verdict)" = null ] \
  && ok 'control: unfixed response is not recordable' \
  || bad 'control failed: unfixed response parsed as a verdict'

# Verdictless / blocked: must fail, must emit no VERDICT line, must not be defaulted.
emit "$WORK/blocked.json" > "$WORK/blocked.txt" 2>/dev/null; brc=$?
[ "$brc" -ne 0 ] && ok 'blocked response exits non-zero' || bad 'blocked response exited 0'
grep -qi '^VERDICT:' "$WORK/blocked.txt" && bad 'blocked response emitted a VERDICT line' || ok 'blocked response emits no VERDICT line'
blocked="$(node "$WORK/check.mjs" "$WORK/blocked.txt")"
[ "$(printf '%s' "$blocked" | jq -r .verdict)" = null ] \
  && ok 'runner parser records nothing for a blocked review' \
  || bad 'blocked review was recordable'

# A head sha that is not a full commit id must be refused, never guessed.
printf '{"head":"abc123"}\n' > "$WORK/meta.json"
emit "$WORK/out.json" >/dev/null 2>&1 && bad 'short head sha was accepted' || ok 'short head sha is refused'

[ "$FAIL" -eq 0 ] && printf 'PASS test-ai-gemini-governed-stdout\n' || { printf 'FAIL test-ai-gemini-governed-stdout\n'; exit 1; }
