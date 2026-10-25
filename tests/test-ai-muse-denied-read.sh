#!/usr/bin/env bash
# Exact native-stream boundary only. Synthetic streams; no provider/state/credentials.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
source <(sed -n '/^failed_turn_stream_check(){/,/^}/p' "$ROOT/bin/ai-muse")
python3 - "$TMP" <<'PY'
import json,pathlib,sys,copy
root=pathlib.Path(sys.argv[1]);sid='ses_fixture'
def event(kind,**part):return dict(type=kind,sessionID=sid,part=part)
start=event('step_start',type='step-start');finish=event('step_finish',type='step-finish',reason='tool-calls')
text=event('text',type='text',text='Inspecting the change.')
read=event('tool_use',type='tool',tool='read',state=dict(status='completed'))
denied=event('tool_use',type='tool',tool='read',state=dict(status='error',error='The user rejected permission to use this specific tool call.'))
base=[start,text,read,finish,start,denied,finish]
cases={}
def case(name,events,allowed=False):cases[name]=(copy.deepcopy(events),allowed)
case('one-exact-denial',base,True)
case('two-consecutive-denials',base[:-1]+[denied,finish],True)
case('three-consecutive-denials',base[:-1]+[denied,denied,finish],True)
neutral=copy.deepcopy(base);neutral[1]['part']['text']='Reading approval evidence before inspecting source.'
case('neutral-preliminary-approval-evidence',neutral,True)
for name,word in [('explicit-verdict','VERDICT: APPROVE'),('approve-action','I approve this change.'),('approved-action','Approved.'),('approval-granted','Approval granted.'),('final-approval','Final approval.'),('decision','DECISION: proceed'),('rejected','REJECTED'),('stopped','STOPPED'),('approving','I am approving this change.'),('lgtm','LGTM, no blockers')]:
 e=copy.deepcopy(base);e[1]['part']['text']=word;case(name,e)
command=copy.deepcopy(base);command[2]['part']['tool']='bash';case('completed-disposable-command-before-denial',command,True)
e=copy.deepcopy(base);e[0]['part']['type']='other';case('wrong-start-part',e)
e=copy.deepcopy(base);e[-1]['part']['type']='other';case('wrong-finish-part',e)
empty=event('text',type='text',text='   ');case('empty-text-after-denial',base[:-1]+[empty,finish])
case('four-errors',base[:-1]+[denied,denied,denied,finish])
case('text-after-first-denial',base[:-1]+[text,finish])
case('successful-tool-after-first-denial',base[:-1]+[read,finish])
case('interleaved-text',base[:-1]+[text,denied,finish])
case('denials-in-different-steps',base+[start,denied,finish])
case('nested-step',base[:1]+[start]+base[1:])
case('orphan-finish',[finish]+base)
case('unclosed-step',base+[start])
case('tool-outside-step',[read]+base)
case('text-outside-step',[text]+base)
for name,key,value in [('wrong-denied-tool','tool','bash'),('generic-error','error','unrelated error')]:
 e=copy.deepcopy(base)
 if key=='tool':e[-2]['part'][key]=value
 else:e[-2]['part']['state'][key]=value
 case(name,e)
e=copy.deepcopy(base);e[-1]['part']['reason']='stop';case('successful-terminal-stop',e)
e=copy.deepcopy(base);e[-1]['sessionID']='ses_other';case('wrong-session',e)
e=copy.deepcopy(base);e[-2]['type']='error';case('unknown-event-type',e)
e=copy.deepcopy(base);e[-2]['part']['state']['status']='running';case('incomplete-tool',e)
e=copy.deepcopy(base);e[2]['part']['type']='other';case('wrong-native-tool-part',e)
for name,(events,allowed) in cases.items():
 (root/(name+'.jsonl')).write_text(''.join(json.dumps(e)+'\n' for e in events))
 (root/(name+'.expected')).write_text('0' if allowed else '1')
PY
pass=0;fail=0
for stream in "$TMP"/*.jsonl; do
  actual=1; failed_turn_stream_check "$stream" ses_fixture && actual=0
  expected="$(cat "${stream%.jsonl}.expected")"
  if [ "$actual" = "$expected" ]; then pass=$((pass+1)); else fail=$((fail+1)); printf 'FAIL %s: expected %s, got %s\n' "$(basename "$stream")" "$expected" "$actual" >&2; fi
done
printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
