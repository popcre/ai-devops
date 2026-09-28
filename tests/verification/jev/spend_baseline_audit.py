"""Count transcript structure and billed usage without emitting message content."""
import collections, glob, itertools, json, sys
ROOT=sys.argv[1] if len(sys.argv)==2 else None
if not ROOT:
    raise SystemExit('usage: python3 spend_baseline_audit.py PRIVATE_ARCHIVE_ROOT')
pat=ROOT+'/*/{client}/**/*.jsonl'
seen={'claude':set(),'codex':set()}
stats=collections.defaultdict(collections.Counter)
usage=collections.defaultdict(collections.Counter)

def read(f):
    try:
        with open(f,errors='replace') as h:
            for line in h:
                try: yield json.loads(line)
                except (ValueError,UnicodeError): stats[client]['invalid_lines']+=1
    except OSError: stats[client]['unreadable_files']+=1
for client in ('claude','codex'):
    for f in glob.iglob(pat.format(client=client),recursive=True):
        if '/subagents/' in f or '/agents/' in f:
            stats[client]['excluded_subagent_files']+=1;continue
        rows=read(f)
        try: first=next(rows)
        except StopIteration:continue
        sid=first.get('sessionId') or first.get('id') or ((first.get('payload') or {}).get('id') if isinstance(first.get('payload'),dict) else None)
        if not sid:
            # Some exports prepend title; find first session-bearing row, retaining the stream.
            prefix=[first]
            for row in rows:
                prefix.append(row)
                sid=row.get('sessionId') or row.get('id') or ((row.get('payload') or {}).get('id') if isinstance(row.get('payload'),dict) and row.get('type')=='session_meta' else None)
                if sid or len(prefix)>=20:break
            rows=itertools.chain(prefix,rows)
        if not sid:stats[client]['unidentified_files']+=1;continue
        if not isinstance(rows,itertools.chain):rows=itertools.chain([first],rows)
        if sid in seen[client]:stats[client]['excluded_duplicate_files']+=1;continue
        seen[client].add(sid);stats[client]['sessions']+=1
        message_ids=set();last_total={}
        for o in rows:
            if client=='claude':
                typ=o.get('type'); m=o.get('message') or {}
                if typ=='user' and isinstance(m,dict):
                    content=m.get('content')
                    if isinstance(content,str) and content.strip():stats[client]['human_user_turns']+=1
                    elif isinstance(content,list) and any(isinstance(x,dict) and x.get('type')=='text' for x in content):stats[client]['mixed_user_turns']+=1
                if typ!='assistant' or not isinstance(m,dict):continue
                mid=m.get('id')
                if mid not in message_ids and mid:
                    message_ids.add(mid)
                    u=m.get('usage') or {}
                    for k in ('input_tokens','cache_creation_input_tokens','cache_read_input_tokens','output_tokens'):
                        if isinstance(u.get(k),int):usage[client][k]+=u[k]
                    if u:stats[client]['billed_messages']+=1
                for x in m.get('content') or []:
                    if not isinstance(x,dict) or x.get('type')!='tool_use':continue
                    name=x.get('name','');inp=x.get('input') or {}
                    if name=='Skill':stats[client]['skill_tool_calls']+=1
                    if name in ('Read','Bash') and isinstance(inp,dict):
                        arg=str(inp.get('file_path','')) if name=='Read' else str(inp.get('command',''))
                        if 'SKILL.md' in arg:stats[client]['explicit_skill_file_reads']+=1
                        if 'ai-reviewer-issue' in arg and 'maintenance' in arg:stats[client]['reviewer_maintenance_commands']+=1
            else:
                typ=o.get('type');p=o.get('payload') or {}
                if typ=='event_msg' and isinstance(p,dict):
                    if p.get('type')=='user_message':stats[client]['human_user_turns']+=1
                    if p.get('type')=='token_count':
                        info=p.get('info') or {}; u=info.get('total_token_usage') or {}
                        if isinstance(u,dict) and u:last_total=u
                if typ=='response_item' and isinstance(p,dict) and p.get('type') in ('function_call','custom_tool_call'):
                    name=p.get('name','');arg=p.get('arguments') or p.get('input') or ''
                    if isinstance(arg,dict):arg=json.dumps(arg)
                    if 'SKILL.md' in str(arg):stats[client]['explicit_skill_file_reads']+=1
                    if 'ai-reviewer-issue' in str(arg) and 'maintenance' in str(arg):stats[client]['reviewer_maintenance_commands']+=1
        if client=='codex' and last_total:
            stats[client]['billed_sessions']+=1
            for k in ('input_tokens','cached_input_tokens','cache_write_input_tokens','output_tokens'):
                if isinstance(last_total.get(k),int):usage[client][k]+=last_total[k]
for c in ('claude','codex'):
    print(c,'stats',json.dumps(dict(sorted(stats[c].items())),sort_keys=True))
    print(c,'usage',json.dumps(dict(sorted(usage[c].items())),sort_keys=True))
