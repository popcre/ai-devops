import json,os,re,sys,hashlib
src,out=sys.argv[1],sys.argv[2]
REV=re.compile(r'\b(ai-review|reviewers?|muse|glm|deepseek|stepfun|kimi|qwen|grok|gemini|codex review|second opinion|final-check|plan-review|diff-review)\b',re.I)
VAL=re.compile(r'(VERDICT|REJECT|REVISE|APPROVE|finding|caught|real bug|good catch|valid point|false positive|not a real|no new findings|nothing actionable|addressed|fixed (?:the|per|its)|reviewer (?:was|is) right|reviewer (?:was|is) wrong|nitpick)',re.I)
KEY=re.compile(r'(sk-[A-Za-z0-9_-]{16,}|gh[psou]_[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_.-]+|(?i:(api[_-]?key|token|password|secret)["\s:=]+)[^\s"]{12,})')
def strs(o,acc):
    if isinstance(o,str): acc.append(o)
    elif isinstance(o,dict):
        for k,v in o.items():
            if k in('signature','data','thinkingSignature','encrypted_content'): continue
            strs(v,acc)
    elif isinstance(o,list):
        for v in o: strs(v,acc)
seen=set(); os.makedirs(out,exist_ok=True); tot=0
for root,_,fs in os.walk(src):
  for f in fs:
    if not (f.endswith('.jsonl') or f.endswith('.txt')): continue
    p=os.path.join(root,f); keep=[]; first=None; cwd=''
    try:
      for line in open(p,errors='replace'):
        try:
          d=json.loads(line); 
          if not cwd and isinstance(d,dict): cwd=str(d.get('cwd') or (d.get('payload') or {}).get('cwd') or '')
          acc=[];strs(d,acc);t='\n'.join(acc)
          if first is None and isinstance(d,dict) and (d.get('type')=='user' or (d.get('payload') or {}).get('role')=='user') and len(t)>30 and '<' not in t[:3]: first=t[:600]
        except Exception: t=line
        for para in re.split(r'\n{2,}',t):
          if para.count('\n')>25: continue
          m=REV.search(para); e=VAL.search(para)
          if m and e and abs(m.start()-e.start())<300:
            a=max(0,min(m.start(),e.start())-200); s=para[a:a+700]
            h=hashlib.md5(s.encode()).hexdigest()
            if h in seen: continue
            seen.add(h); keep.append(KEY.sub('[REDACTED]',s))
    except Exception as ex: continue
    if len(keep)>=2:
      body='\n---\n'.join(keep)[:200000]; tot+=len(body)
      open(os.path.join(out,hashlib.md5(p.encode()).hexdigest()[:10]+'.txt'),'w').write(f"SOURCE: {p}\nCWD: {cwd}\nFIRST REQUEST: {KEY.sub('[REDACTED]',first or '')}\n=====\n{body}")
print(src,'chars',tot,flush=True)
