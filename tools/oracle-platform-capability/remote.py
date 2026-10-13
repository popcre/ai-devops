# Fixed remote public metadata program; C is the reviewed contract only.
import hashlib,json,re,subprocess,sys,time
HELPER='ghcr.io/coollabsio/coolify-helper'
IDENTITY='{"id":{{json .Id}},"name":{{json .Name}},"image":{{json .Config.Image}},"image_id":{{json .Image}},"state":{{json .State.Status}}}'
INVENTORY='{"id":{{json .ID}},"image":{{json .Image}},"name":{{json .Names}},"state":{{json .State}}}'
def run(args,seconds=5,limit=8192):
    if not (type(C['issued_at']) is int and type(C['expires_at']) is int and 0<=time.time()-C['issued_at'] and 0<C['expires_at']-C['issued_at']<=1800 and time.time()+seconds+5<C['expires_at']):raise ValueError('expired')
    p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=seconds,env={'PATH':'/usr/bin:/bin','LANG':'C'})
    if time.time()>=C['expires_at']:raise ValueError('expired')
    if p.returncode or len(p.stdout)>limit:raise ValueError('bounded capability refusal')
    return p.stdout
try:
    if C['mode']=='discover':
        coolify=json.loads(run(['docker','inspect','--format',IDENTITY,'coolify'],limit=2048))
        raw=run(['docker','ps','--no-trunc','--filter','ancestor='+HELPER,'--format',INVENTORY],limit=8192)
        rows=[json.loads(line) for line in raw.splitlines()]
        if len(rows)>16:raise ValueError('helper population bound')
        if time.time()>=C['expires_at']:raise ValueError('expired')
        print(json.dumps({'mode':'discover','coolify':coolify,'inventory':rows,'configured_helper':'UNKNOWN','capabilities':'UNKNOWN'},separators=(',',':')))
    else:
        row=json.loads(run(['docker','inspect','--format',IDENTITY,C['helper_id']],limit=2048))
        expected={'id':C['helper_id'],'name':'/'+C['helper_name'],'image':C['helper_image'],'image_id':C['helper_image_id'],'state':'running'}
        if row!=expected:raise ValueError('helper changed')
        prefix=['docker','exec',C['helper_id']]
        commands=[['/bin/sh','-c','test 1 -eq 1'],['/bin/date','+%s'],['timeout','--help'],['docker','compose','version','--short'],['docker','compose','wait','--help'],['/bin/sh','-c','test 0 -gt $(/bin/date +%s)']]
        receipts=[]
        for argv in commands[:-1]:
            raw=run(prefix+argv,limit=8192)
            if argv[0]=='/bin/date' and not re.fullmatch(rb'[0-9]{10}\n',raw):raise ValueError('date capability')
            if argv==['timeout','--help'] and (b'-s' not in raw or b'-k' not in raw):raise ValueError('timeout flags')
            if argv==['docker','compose','wait','--help'] and b'wait' not in raw:raise ValueError('compose wait unavailable')
            receipts.append({'argv':argv,'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw)})
        # Fixed public shell refusal. Deliberately no injected time or script.
        if not (type(C['issued_at']) is int and type(C['expires_at']) is int and 0<=time.time()-C['issued_at'] and 0<C['expires_at']-C['issued_at']<=1800 and time.time()+10<C['expires_at']):raise ValueError('expired')
        p=subprocess.run(prefix+commands[-1],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=5,env={'PATH':'/usr/bin:/bin','LANG':'C'})
        if p.returncode!=1 or p.stdout:raise ValueError('expired guard not refused')
        if json.loads(run(['docker','inspect','--format',IDENTITY,C['helper_id']],limit=2048))!=expected:raise ValueError('helper changed after qualification')
        if time.time()>=C['expires_at']:raise ValueError('expired')
        print(json.dumps({'mode':'qualify','identity':row,'capabilities':receipts,'expired_guard_refused':True,'configured_helper':'UNKNOWN','read_only':True},separators=(',',':')))
except Exception:sys.exit(3)
