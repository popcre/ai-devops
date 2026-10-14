"""Closed public platform capability reader; never an issuer or deployment.

Discovery and qualification need different exact reviewed contracts/one-use
claims. No live use is performed by preparation/tests.
"""
import http.client,socket,ipaddress
from urllib.parse import urlsplit
import argparse,base64,hashlib,importlib.util,json,os,re,resource,stat,subprocess,sys,tempfile,time,urllib.request
from pathlib import Path
LIMIT=65536
HELPER='ghcr.io/coollabsio/coolify-helper'
TARGET_SHA256='056362b2aa356350e0db6c7bdb90711dcd5d7283b9f55016d665381640ed7450'
SOURCE_PLATFORM='f55efc859dfcbbf79274c4907b3df89f9767c11d'
# Strip injected credentials before ANY project module executes.
resource.setrlimit(resource.RLIMIT_CORE,(0,0))
_PASSWORD=os.environ.pop('ORACLE_HETZ_READ_PASSWORD',None)
_TOKEN=os.environ.pop('ORACLE_COOLIFY_READ_TOKEN',None)
HELPER_SHA='35173ab9a0422b7f9cbccd13929d83ff568525f2d244ad5af9b14ca451f60754'
def require(ok,message):
    if not ok:raise ValueError(message)
def file_identity(info):
    # Read-induced atime changes are allowed; all immutable custody facts remain exact.
    return tuple(getattr(info,key) for key in ('st_dev','st_ino','st_uid','st_gid','st_mode','st_nlink','st_size','st_mtime_ns','st_ctime_ns'))

def bounded_file(path,maximum):
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    with os.fdopen(fd,'rb') as f:
        before=os.fstat(f.fileno());require(stat.S_ISREG(before.st_mode) and before.st_nlink==1 and before.st_size<=maximum,'bounded regular source required')
        raw=f.read(maximum+1);require(len(raw)<=maximum and file_identity(os.fstat(f.fileno()))==file_identity(before),'source moved')
        return raw
def load_helpers():
    path=Path(__file__).resolve().parents[1]/'oracle-hosting-diagnosis/inspect_metadata.py'
    raw=bounded_file(path,65536);require(hashlib.sha256(raw).hexdigest()==HELPER_SHA,'transport helper changed before execution')
    import types
    module=types.ModuleType('oracle_metadata_helpers');module.__file__=str(path)
    exec(compile(raw,str(path),'exec'),module.__dict__);return module
helpers=load_helpers()
transport_failure=helpers.transport_failure
class Custody:
    def __init__(self,path):
        self.path=str(path);require(self.path.startswith('/') and all(x not in ('','..','.') for x in self.path.split('/')[1:]),'normalized absolute custody required')
        fd=os.open('/',os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
        try:
            for part in self.path.split('/')[1:]:
                child=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd);os.close(fd);fd=child
            info=os.fstat(fd);require(info.st_uid==os.getuid() and stat.S_IMODE(info.st_mode)==0o700,'owned private custody required')
        except Exception as exc:
            os.close(fd);raise ValueError("custody ancestry refused") from exc
        self.fd=fd;self.identity=(info.st_dev,info.st_ino)
    def recheck(self):
        other=Custody(self.path)
        try:require(other.identity==self.identity,'custody moved')
        finally:other.close()
    def create(self,name,raw,mode=0o600):
        require(re.fullmatch('[a-zA-Z0-9_.-]{1,100}',name),'fixed custody leaf required');self.recheck()
        fd=os.open(name,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,mode,dir_fd=self.fd)
        with os.fdopen(fd,'wb') as out:
            info=os.fstat(out.fileno());require(stat.S_ISREG(info.st_mode) and info.st_nlink==1 and info.st_uid==os.getuid() and stat.S_IMODE(info.st_mode)==mode,'file custody differs')
            out.write(raw);out.flush();os.fsync(out.fileno())
        os.fsync(self.fd);self.recheck()
    def close(self):os.close(self.fd)
def lifetime(c,remaining=0):
    now=time.time();require(type(c['issued_at']) is int and type(c['expires_at']) is int and 0<=now-c['issued_at'] and 0<c['expires_at']-c['issued_at']<=1800 and now+remaining<c['expires_at'],'bounded actual action lifetime required')
IDENTITY='{"id":{{json .Id}},"name":{{json .Name}},"image":{{json .Config.Image}},"image_id":{{json .Image}},"state":{{json .State.Status}}}'
INVENTORY='{"id":{{json .ID}},"image":{{json .Image}},"name":{{json .Names}},"state":{{json .State}}}'
BASE={'schema','mode','application','api','platform_source','host','user','port','known_hosts_sha256','issued_at','expires_at','installed_gate','tailnet','claim_id','operator_sha256','remote_sha256','transport_helper_sha256'}
FIXED={'schema':'oracle-platform-capability/v5','application':'vhmcdkdk23dgvjvcvhyhcjzd','platform_source':SOURCE_PLATFORM,'user':'ai','port':22}

class ReviewedContract(dict):pass

def load_contract(path,seal):
    if isinstance(path,HeldInput):path.check();raw=path.raw
    else:raw=bounded_file(path,8192)
    require(re.fullmatch('[a-f0-9]{64}',seal) and hashlib.sha256(raw).hexdigest()==seal,'contract mismatch')
    c=ReviewedContract(json.loads(raw,object_pairs_hook=unique_metadata));extra={'helper_id','helper_name','helper_image','helper_image_id'} if c.get('mode')=='qualify' else set()
    require(set(c)==BASE|extra and all(c[k]==v for k,v in FIXED.items()),'closed contract mismatch')
    require(c['mode'] in {'discover','qualify'} and type(c['expires_at']) is int and type(c['claim_id']) is str and re.fullmatch('[a-z0-9-]{1,64}',c['claim_id']),'contract metadata invalid')
    require(re.fullmatch('[a-f0-9]{64}',c['known_hosts_sha256']),'known host pin invalid')
    if c['mode']=='qualify':
        require(re.fullmatch('[a-f0-9]{64}',c['helper_id']) and re.fullmatch('[a-z0-9][a-z0-9_-]{0,63}',c['helper_name']),'helper identity invalid')
        require(re.fullmatch(re.escape(HELPER)+r'(?::[a-zA-Z0-9_.-]{1,64}|@sha256:[a-f0-9]{64})',c['helper_image']) and re.fullmatch('sha256:[a-f0-9]{64}',c['helper_image_id']),'immutable helper image required')
    for key,source_path in [('operator_sha256',Path(__file__)),('remote_sha256',Path(__file__).with_name('remote.py')),('transport_helper_sha256',Path(helpers.__file__))]:
        source=bounded_file(source_path,65536)
        require(re.fullmatch('[a-f0-9]{64}',c[key]) and hashlib.sha256(source).hexdigest()==c[key],'reviewed source changed')
        if key=='remote_sha256':c.remote_source=source
    target_contract(c);lifetime(c);tailnet_contract(c)
    if isinstance(path,HeldInput):path.check()
    return c

def remote_command(c,source):
    # This is a fixed public source program; caller supplies no shell/argv/path.
    require(type(source) is bytes and len(source)<=65536 and hashlib.sha256(source).hexdigest()==c['remote_sha256'],'held remote source changed')
    encoded=base64.b64encode(source).decode();config=base64.b64encode(json.dumps(c,sort_keys=True).encode()).decode()
    return '/usr/bin/python3 -c "import base64;C=__import__(\'json\').loads(base64.b64decode(\''+config+'\'));exec(base64.b64decode(\''+encoded+'\'))"'

def read_remote(contract,known_hosts,password,source):
    target_contract(contract);tailnet_contract(contract);lifetime(contract,60)
    require(isinstance(known_hosts,HeldInput),'held known-host custody required');known_hosts.check();hosts=known_hosts.raw;require(hashlib.sha256(hosts).hexdigest()==contract['known_hosts_sha256'],'known hosts changed')
    require(type(password) is str and password and len(password.encode('utf-8'))<=LIMIT and not any(x in password for x in ('\x00','\n','\r')),'protected credential missing')
    parent=Custody(os.environ.get('TMPDIR',''))
    name='oracle-metadata-'+os.urandom(12).hex();directory=None
    try:
        parent.recheck();os.mkdir(name,0o700,dir_fd=parent.fd);parent.recheck()
        directory=Custody(parent.path+'/'+name)
        directory.create('known-hosts',hosts);directory.create('password',password.encode());del password
        # Every askpass read traverses the controller's open directory descriptor.
        # It validates regular single-link0600 exact inode/size before and after.
        secretinfo=os.stat('password',dir_fd=directory.fd,follow_symlinks=False)
        anchor='/proc/'+str(os.getpid())+'/fd/'+str(directory.fd)
        helper_source=('#!/usr/bin/python3\nimport os,stat,sys\n'
          'd=os.open('+repr(anchor)+',os.O_RDONLY|os.O_DIRECTORY)\n'
          'fd=os.open("password",os.O_RDONLY|os.O_NOFOLLOW,dir_fd=d)\n'
          'st=os.fstat(fd)\n'
          'if not stat.S_ISREG(st.st_mode) or st.st_nlink!=1 or st.st_uid!=os.getuid() or stat.S_IMODE(st.st_mode)!=0o600 or (st.st_dev,st.st_ino,st.st_size)!='+repr((secretinfo.st_dev,secretinfo.st_ino,secretinfo.st_size))+':sys.exit(3)\n'
          'raw=os.read(fd,65537)\n'
          'if len(raw)!=st.st_size or os.fstat(fd)!=st:sys.exit(3)\n'
          'sys.stdout.buffer.write(raw)\n')
        directory.create('askpass',helper_source.encode(),0o700)
        child={'PATH':'/usr/bin:/bin','LANG':'C','SSH_ASKPASS':anchor+'/askpass','SSH_ASKPASS_REQUIRE':'force','DISPLAY':'oracle-metadata:0'}
        command=['/usr/bin/ssh','-F','/dev/null','-T','-p','22','-o','StrictHostKeyChecking=yes','-o','UserKnownHostsFile='+anchor+'/known-hosts','-o','GlobalKnownHostsFile=/dev/null','-o','ConnectTimeout=10','-o','ConnectionAttempts=1','-o','NumberOfPasswordPrompts=1','-o','IdentitiesOnly=yes','-o','PubkeyAuthentication=no','-o','PreferredAuthentications=password','-o','ProxyCommand=none','-o','ProxyJump=none','-o','ClearAllForwardings=yes',contract['user']+'@'+contract['host'],remote_command(contract,source)]
        def bound_file():resource.setrlimit(resource.RLIMIT_FSIZE,(LIMIT,LIMIT))
        # Anonymous output descriptors never follow mutable named parents.
        with tempfile.TemporaryFile(dir=anchor) as output,tempfile.TemporaryFile(dir=anchor) as error:
            known_hosts.check();directory.recheck();parent.recheck();lifetime(contract,60)
            result=subprocess.run(command,stdin=subprocess.DEVNULL,stdout=output,stderr=error,timeout=55,env=child,start_new_session=True,preexec_fn=bound_file)
            known_hosts.check();directory.recheck();parent.recheck();lifetime(contract)
            if result.returncode:
                error.seek(0);raise ValueError(transport_failure(result.returncode,error.read(4097)))
            output.seek(0);return output.read(LIMIT+1)
    finally:
        if directory is not None:
            for leaf in ('known-hosts','password','askpass'):
                try:os.unlink(leaf,dir_fd=directory.fd)
                except FileNotFoundError:pass
            directory.close()
            try:os.rmdir(name,dir_fd=parent.fd)
            except OSError:pass # retain protected custody after hostile movement
        parent.close()

SOCKET='/run/tailscale/tailscaled.sock'
PEER_FIELDS=frozenset(('node_id', 'node_name', 'addresses', 'node_key_sha256', 'tags', 'route_device', 'route_table', 'route_source'))
PEER_SHA256='c7f6ec888e90f1743d7a466e3af0a021af0b71da509369c20a4118523a117d45'
OS_FILES={'tailscale':('/usr/bin/tailscale','/var/lib/dpkg/info/tailscale.md5sums'),'ip':('/usr/bin/ip','/var/lib/dpkg/info/iproute2.md5sums'),'git':('/usr/bin/git','/var/lib/dpkg/info/git.md5sums')}
def root_ancestry(path,socket_leaf=False):
    parts=Path(path).parts;fd=os.open('/',os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:
        for part in parts[1:-1]:
            child=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd);os.close(fd);fd=child
            info=os.fstat(fd);require(info.st_uid==0 and not stat.S_IMODE(info.st_mode)&0o022,'root-owned OS ancestry required')
        info=os.stat(parts[-1],dir_fd=fd,follow_symlinks=False)
        require(info.st_uid==0 and (stat.S_ISSOCK(info.st_mode) if socket_leaf else stat.S_ISREG(info.st_mode) and info.st_nlink==1 and not stat.S_IMODE(info.st_mode)&0o022),'root-owned OS resource required')
        return (info.st_dev,info.st_ino)
    finally:os.close(fd)
def os_identity(kind,pins):
    path,origin=OS_FILES[kind];root_ancestry(path);root_ancestry(origin)
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    with os.fdopen(fd,'rb') as code:
        before=os.fstat(code.fileno());require(before.st_size<=64*1024**2 and before.st_mode&0o111,'bounded executable required')
        raw=code.read(64*1024**2+1);require(len(raw)==before.st_size and file_identity(os.fstat(code.fileno()))==file_identity(before),'OS executable moved')
    require(hashlib.sha256(raw).hexdigest()==pins['binary_sha256'],'reviewed OS executable differs')
    metadata=bounded_file(origin,1024*1024);require(hashlib.sha256(metadata).hexdigest()==pins['package_manifest_sha256'],'root package origin moved')
    rows=[x.split() for x in metadata.decode('ascii').splitlines()]
    require([x[0] for x in rows if len(x)==2 and x[1]==path[1:]]==[hashlib.md5(raw).hexdigest()],'installed package binary association differs')
def canonical_commitment(kind,value):
    return hashlib.sha256(json.dumps({'schema':kind,'value':value},sort_keys=True,separators=(',',':'),ensure_ascii=True,allow_nan=False).encode('ascii')).hexdigest()

def target_contract(c):
    value={key:c[key] for key in ('api','host','user','port')}
    require(canonical_commitment('oracle-platform-target/v4',value)==TARGET_SHA256,'fixed protected target commitment differs')
    require(type(value['api']) is str and type(value['host']) is str and re.fullmatch('[a-z0-9.-]{1,253}',value['host']) and value['user']=='ai' and type(value['port']) is int and value['port']==22,'target metadata schema differs')
    parsed=urlsplit(value['api'])
    require(parsed.scheme=='http' and parsed.hostname and parsed.port==8000 and parsed.path=='/api/v1/version' and not parsed.username and not parsed.password and not parsed.query and not parsed.fragment,'fixed version resource required')
    require(type(parsed.hostname) is str and str(ipaddress.IPv4Address(parsed.hostname))==parsed.hostname and value['api']=='http://'+parsed.hostname+':8000/api/v1/version','canonical fixed IPv4 version resource required')
    return parsed

def tailnet_contract(c):
    target_contract(c)
    value=c['tailnet'];require(type(value) is dict and set(value)==PEER_FIELDS|{'os_cli'},'closed peer/route schema required')
    require(canonical_commitment('oracle-platform-peer-route/v4',{k:value[k] for k in PEER_FIELDS})==PEER_SHA256,'independently reviewed fixed peer/route binding required')
    require(type(value['os_cli']) is dict and set(value['os_cli'])==set(OS_FILES),'fixed OS CLI closure required')
    for pins in value['os_cli'].values():require(type(pins) is dict and set(pins)=={'binary_sha256','package_manifest_sha256'} and all(isinstance(h,str) and re.fullmatch('[a-f0-9]{64}',h) for h in pins.values()),'exact reviewed OS origin pins required')
    return value

def local_metadata(argv,maximum):
    # Fixed root-owned OS program, no inherited credentials/config/proxy.
    parent=Custody(os.environ.get('TMPDIR',''))
    try:
        anchor='/proc/'+str(os.getpid())+'/fd/'+str(parent.fd)
        with tempfile.TemporaryFile(dir=anchor) as output:
            def bounded():resource.setrlimit(resource.RLIMIT_FSIZE,(maximum,maximum))
            parent.recheck()
            result=subprocess.run(argv,stdin=subprocess.DEVNULL,stdout=output,stderr=subprocess.DEVNULL,timeout=5,env={'PATH':'/usr/bin:/bin','LANG':'C'},preexec_fn=bounded)
            parent.recheck();require(result.returncode==0,'local peer/route metadata refused');output.seek(0);raw=output.read(maximum+1);require(len(raw)<=maximum,'local metadata exceeds bound')
        return json.loads(raw,object_pairs_hook=unique_metadata)
    finally:parent.close()
def unique_metadata(pairs):
    out={}
    for k,v in pairs:require(k not in out,'duplicate local metadata field');out[k]=v
    return out

def verify_tailnet(c):
    expected=tailnet_contract(c);target=target_contract(c).hostname;lifetime(c,15)
    for kind in OS_FILES:os_identity(kind,expected['os_cli'][kind])
    identity=root_ancestry(SOCKET,True)
    who=local_metadata(['/usr/bin/tailscale','--socket='+SOCKET,'whois','--json',target],65536)
    require(type(who) is dict and type(who.get('Node')) is dict,'fixed peer missing');node=who['Node']
    key=node.get('Key');require(isinstance(key,str) and re.fullmatch(r'nodekey:[a-fA-F0-9]{64}',key,flags=re.ASCII),'fixed peer key missing')
    require(type(node.get('ID')) is int and node['ID']==expected['node_id'] and node.get('Name')==expected['node_name'],'fixed peer identity moved')
    require(type(node.get('Addresses')) is list and sorted(node['Addresses'])==sorted(expected['addresses']),'fixed peer addresses moved')
    tags=node.get('Tags');require(type(tags) is list and all(isinstance(t,str) for t in tags) and tags==sorted(set(tags)) and tags==expected['tags'],'fixed peer tags moved')
    require(hashlib.sha256(key.encode('ascii')).hexdigest()==expected['node_key_sha256'],'fixed peer key moved')
    # Missing/null expiry fields mean UNKNOWN, never false or never-expiring.
    if node.get('Expired') is not None:require(node['Expired'] is False,'expired peer refused')
    if node.get('KeyExpiry') is not None:
        from datetime import datetime,timezone
        expiry=datetime.fromisoformat(node['KeyExpiry'].replace('Z','+00:00'));require(expiry.tzinfo is not None and expiry>datetime.now(timezone.utc),'expired or malformed peer lifetime')
    route=local_metadata(['/usr/bin/ip','-j','route','get',target],8192)
    require(type(route) is list and len(route)==1 and type(route[0]) is dict,'fixed route missing')
    r=route[0];require(r.get('dst')==target and r.get('dev')==expected['route_device'] and str(r.get('table'))==expected['route_table'] and r.get('prefsrc')==expected['route_source'] and r.get('flags')==[] and not any(k in r for k in ('gateway','via','nhid','multipath')),'fixed encrypted route moved')
    require(root_ancestry(SOCKET,True)==identity,'local daemon socket moved')
    for kind in OS_FILES:os_identity(kind,expected['os_cli'][kind])
    lifetime(c,10)
    return {'fixed_peer_key_bound':True,'encrypted_route_bound':True,'peer_expiry':'UNKNOWN' if node.get('KeyExpiry') is None or node.get('Expired') is None else 'checked-current'}

class BoundConnection(http.client.HTTPConnection):
    def __init__(self,host,*,contract,**kwargs):
        self.contract=contract
        super().__init__(host,**kwargs)
    def connect(self):
        target=target_contract(self.contract).hostname;peer=tailnet_contract(self.contract)
        require(self.host==target and self.port==8000,'fixed HTTP target required')
        sock=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
        try:
            sock.settimeout(10);sock.setsockopt(socket.SOL_SOCKET,socket.SO_BINDTODEVICE,(peer['route_device']+'\x00').encode('ascii'));sock.bind((peer['route_source'],0));sock.connect((target,8000));self.sock=sock
        except Exception:sock.close();raise # No other interface/source fallback.
class BoundHTTP(urllib.request.HTTPHandler):
    def __init__(self,contract):
        self.contract=contract;super().__init__()
    def http_open(self,request):
        def connection(host,**kwargs):return BoundConnection(host,contract=self.contract,**kwargs)
        return self.do_open(connection,request)

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):raise ValueError('API redirect denied')

def version(token,c):
    target_contract(c);tailnet_contract(c)
    require(isinstance(token,str) and re.fullmatch(r'[!-~]{1,8192}',token,flags=re.ASCII),'protected ASCII API credential missing')
    verify_tailnet(c) # BEFORE constructing/sending any bearer request
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),BoundHTTP(c),NoRedirect())
    request=urllib.request.Request(c['api'],headers={'Authorization':'Bearer '+token,'Accept':'text/plain'},method='GET')
    with opener.open(request,timeout=10) as response:
        require(response.status==200 and response.geturl()==c['api'],'version endpoint refused')
        raw=response.read(65)
    peer=verify_tailnet(c) # Refuse changed peer/route before accepting metadata
    value=raw.decode('ascii').strip();require(len(raw)<=64 and re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+',value),'version metadata invalid')
    return value,peer

def validate(raw,c):
    require(len(raw)<=LIMIT,'metadata bound')
    result=json.loads(raw)
    require(result.get('mode')==c['mode'] and result.get('configured_helper')=='UNKNOWN','unproved configured helper')
    if c['mode']=='discover':
        require(set(result)=={'mode','coolify','inventory','configured_helper','capabilities'} and result['capabilities']=='UNKNOWN','discovery fields')
        row=result['coolify'];require(set(row)=={'id','name','image','image_id','state'} and row['name']=='/coolify','coolify identity')
        require(re.fullmatch('[a-f0-9]{64}',row['id']) and re.fullmatch('sha256:[a-f0-9]{64}',row['image_id']) and row['state']=='running','coolify identity')
        require(re.fullmatch(r'(?:(?:docker.io/)?coollabsio/coolify|ghcr.io/coollabsio/coolify)(?::[a-zA-Z0-9_.-]{1,64}|@sha256:[a-f0-9]{64})',row['image']),'foreign coolify image')
        require(isinstance(result['inventory'],list) and len(result['inventory'])<=16,'helper population')
        for row in result['inventory']:
            require(set(row)=={'id','image','name','state'} and re.fullmatch('[a-f0-9]{64}',row['id']) and re.fullmatch('[a-z0-9][a-z0-9_-]{0,63}',row['name']) and row['state']=='running','helper metadata')
            require(re.fullmatch(re.escape(HELPER)+r'(?::[a-zA-Z0-9_.-]{1,64}|@sha256:[a-f0-9]{64})',row['image']),'foreign helper image')
    else:
        require(set(result)=={'mode','identity','capabilities','expired_guard_refused','configured_helper','read_only'} and result['expired_guard_refused'] is True and result['read_only'] is True,'qualification fields')
        expected={'id':c['helper_id'],'name':'/'+c['helper_name'],'image':c['helper_image'],'image_id':c['helper_image_id'],'state':'running'}
        require(result['identity']==expected and len(result['capabilities'])==5,'qualification identity')
        fixed=[['/bin/sh','-c','test 1 -eq 1'],['/bin/date','+%s'],['timeout','--help'],['docker','compose','version','--short'],['docker','compose','wait','--help']]
        require([r.get('argv') for r in result['capabilities']]==fixed,'capability argv differs')
        for row in result['capabilities']:require(set(row)=={'argv','sha256','bytes'} and re.fullmatch('[a-f0-9]{64}',row['sha256']) and type(row['bytes']) is int and 0<=row['bytes']<=8192,'capability receipt')
    result.update(read_only=True,production_mutations=0,hosted_accepted=False,launch_admitted=False)
    return result

GATE='/usr/local/bin/ai-task-gates'
GATE_SOURCE='/home/ahazan/repos/ai-devops/bin/ai-task-gates'
MANIFEST='/etc/ai-devops/install-manifest.tsv'
def read_install_manifest():
    # Installer deliberately publishes this fixed receipt as the normal owner.
    # Only its ancestry is root-owned; never chmod/chown or reinterpret it.
    path=Path(MANIFEST);require(path.is_absolute(),'fixed absolute install receipt required')
    fd=os.open('/',os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:
        for part in path.parts[1:-1]:
            child=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd);os.close(fd);fd=child
            info=os.fstat(fd);require(stat.S_ISDIR(info.st_mode) and info.st_uid==0 and not stat.S_IMODE(info.st_mode)&0o022,'root-owned install receipt ancestry required')
        leaf=os.open(path.name,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK,dir_fd=fd)
        try:
            before=os.fstat(leaf)
            require(stat.S_ISREG(before.st_mode) and before.st_uid==os.getuid() and stat.S_IMODE(before.st_mode)==0o600 and before.st_nlink==1 and 0<before.st_size<=1024*1024,'caller-owned protected install receipt required')
            raw=b''
            while len(raw)<before.st_size:
                chunk=os.read(leaf,min(65536,before.st_size-len(raw)))
                require(bool(chunk),'install receipt truncated');raw+=chunk
            require(os.read(leaf,1)==b'' and file_identity(os.fstat(leaf))==file_identity(before),'install receipt moved')
            return raw
        finally:os.close(leaf)
    finally:os.close(fd)

def installed_gate(c):
    pins=c['installed_gate'];require(type(pins) is dict and set(pins)=={'source_head','launcher_sha256','manifest_sha256'},'exact installed gate pins required')
    require(re.fullmatch('[a-f0-9]{40}',pins['source_head']) and all(re.fullmatch('[a-f0-9]{64}',pins[k]) for k in ('launcher_sha256','manifest_sha256')),'installed gate identity invalid')
    link=os.lstat(GATE);require(stat.S_ISLNK(link.st_mode) and link.st_uid==0 and os.readlink(GATE)==GATE_SOURCE,'root-owned installed launcher required')
    manifest=read_install_manifest();require(hashlib.sha256(manifest).hexdigest()==pins['manifest_sha256'],'installed manifest moved')
    rows=[x.split('\t') for x in manifest.decode('ascii').splitlines()]
    require([x[2] for x in rows if x[:2]==['meta','source_sha']]==[pins['source_head']],'installed source identity moved')
    require([x for x in rows if x[:2]==['symlink',GATE]]==[['symlink',GATE,GATE_SOURCE,pins['launcher_sha256']]],'installed gate receipt differs')
    links=[x for x in rows if x and x[0]=='symlink']
    require(0<len(links)<=256 and all(len(x)==4 for x in links) and len({x[1] for x in links})==len(links),'managed link closure differs')
    for _,launcher,source,digest in links:
        require(Path(launcher).parent==Path(GATE).parent and Path(source).parent==Path(GATE_SOURCE).parent and Path(launcher).name==Path(source).name and re.fullmatch('[a-f0-9]{64}',digest),'foreign managed link row refused')
        info=os.lstat(launcher);require(stat.S_ISLNK(info.st_mode) and info.st_uid==0 and os.readlink(launcher)==source,'managed launcher moved')
        require(hashlib.sha256(bounded_file(source,1024*1024)).hexdigest()==digest,'managed source hash differs')
    require(hashlib.sha256(bounded_file(GATE_SOURCE,1024*1024)).hexdigest()==pins['launcher_sha256'],'installed gate source changed')
    os_identity('git',c['tailnet']['os_cli']['git'])
    head=subprocess.run(['/usr/bin/git','-c','core.fsmonitor=false','-c','core.hooksPath=/dev/null','-C','/home/ahazan/repos/ai-devops','rev-parse','HEAD'],capture_output=True,timeout=5,env={'PATH':'/usr/local/bin:/usr/bin:/bin','HOME':'/home/ahazan'})
    os_identity('git',c['tailnet']['os_cli']['git'])
    require(head.returncode==0 and head.stdout.decode('ascii').strip()==pins['source_head'],'installed checkout not current')
    status=subprocess.run(['/usr/bin/git','-c','core.fsmonitor=false','-c','core.hooksPath=/dev/null','-C','/home/ahazan/repos/ai-devops','status','--porcelain','--untracked-files=no'],capture_output=True,timeout=5,env={'PATH':'/usr/local/bin:/usr/bin:/bin','HOME':'/home/ahazan'})
    os_identity('git',c['tailnet']['os_cli']['git'])
    require(status.returncode==0 and not status.stdout,'installed tracked source moved')
    return pins

def report_ancestry(path):
    fd=os.open('/',os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW);walked=Path('/');identities=[]
    try:
        for part in Path(path).parts[1:]:
            child=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd);os.close(fd);fd=child;walked=walked/part
            info=os.fstat(fd)
            sticky_tmp=walked==Path('/tmp') and info.st_uid==0 and bool(info.st_mode&stat.S_ISVTX)
            require(info.st_uid in (0,os.getuid()) and (sticky_tmp or not stat.S_IMODE(info.st_mode)&0o022),'reviewer report ancestry is untrusted')
            identities.append((info.st_dev,info.st_ino,info.st_uid,info.st_gid,info.st_mode))
        return tuple(identities)
    finally:os.close(fd)

class HeldReport:
    """Hold the genuine gate's report custody through claim; never issue approval."""
    def __init__(self,path):
        raw=str(path)
        require(raw.startswith('/') and all(x not in ('','.','..') for x in raw.split('/')[1:]),'absolute canonical reviewer report required')
        self.path=Path(raw);self.ancestry=report_ancestry(self.path.parent);self.parent=Custody(self.path.parent);self.fd=None
        try:
            self.fd=os.open(self.path.name,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK,dir_fd=self.parent.fd)
            self.info=os.fstat(self.fd)
            require(stat.S_ISREG(self.info.st_mode) and self.info.st_uid==os.getuid() and self.info.st_nlink==1 and not stat.S_IMODE(self.info.st_mode)&0o022 and 0<self.info.st_size<=1024*1024,'reviewer report custody differs')
            self.parent_info=file_identity(os.fstat(self.parent.fd))
            self.check();raw=b''
            while len(raw)<self.info.st_size:
                part=os.read(self.fd,min(65536,self.info.st_size-len(raw)))
                require(bool(part),'reviewer report truncated');raw+=part
            require(os.read(self.fd,1)==b'','reviewer report grew');self.check()
            self.sha256=hashlib.sha256(raw).hexdigest()
            self.anchor='/proc/'+str(os.getpid())+'/fd/'+str(self.parent.fd)+'/'+self.path.name
        except Exception:
            self.close();raise
    def check(self):
        require(report_ancestry(self.path.parent)==self.ancestry,'reviewer report ancestry moved')
        self.parent.recheck()
        require(file_identity(os.fstat(self.parent.fd))==self.parent_info,'reviewer report parent moved')
        require(file_identity(os.fstat(self.fd))==file_identity(self.info),'reviewer report held leaf moved')
        named=os.stat(self.path.name,dir_fd=self.parent.fd,follow_symlinks=False)
        require(file_identity(named)==file_identity(self.info),'reviewer report named leaf moved')
    def close(self):
        if self.fd is not None:os.close(self.fd);self.fd=None
        self.parent.close()

def outside_git(path):
    raw=str(path)
    require(raw.startswith('/') and all(p not in ('','.','..','.git') for p in raw.split('/')[1:]),'canonical outside-Git contract required')
    fd=os.open('/',os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:
        for part in Path(raw).parts[1:-1]:
            child=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd);os.close(fd);fd=child
            try:os.stat('.git',dir_fd=fd,follow_symlinks=False)
            except FileNotFoundError:pass
            else:raise ValueError('Git ancestry refused')
            # A bare repository has no .git child. Metadata only; never read it.
            try:
                head=os.stat('HEAD',dir_fd=fd,follow_symlinks=False)
                objects=os.stat('objects',dir_fd=fd,follow_symlinks=False)
                refs=os.stat('refs',dir_fd=fd,follow_symlinks=False)
            except FileNotFoundError:pass
            else:
                require(not((stat.S_ISREG(head.st_mode) or stat.S_ISLNK(head.st_mode)) and stat.S_ISDIR(objects.st_mode) and stat.S_ISDIR(refs.st_mode)),'bare Git ancestry refused')
    finally:os.close(fd)

class HeldInput:
    """Hold outside-Git private input, anchored leaf and immutable parent until close."""
    def __init__(self,path,maximum,exact_size=None):
        self.path=Path(path);outside_git(path);self.ancestry=report_ancestry(self.path.parent)
        self.parent=Custody(self.path.parent);self.fd=None
        try:
            self.parent_info=file_identity(os.fstat(self.parent.fd))
            self.fd=os.open(self.path.name,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK,dir_fd=self.parent.fd)
            self.info=os.fstat(self.fd)
            require(stat.S_ISREG(self.info.st_mode) and self.info.st_uid==os.getuid() and stat.S_IMODE(self.info.st_mode)==0o600 and self.info.st_nlink==1 and 0<self.info.st_size<=maximum and (exact_size is None or self.info.st_size==exact_size),'protected input leaf required')
            self.check();self.raw=b''
            while len(self.raw)<self.info.st_size:
                part=os.read(self.fd,min(65536,self.info.st_size-len(self.raw)));require(bool(part),'protected input truncated');self.raw+=part
            require(os.read(self.fd,1)==b'','protected input grew');self.check()
            self.anchor='/proc/'+str(os.getpid())+'/fd/'+str(self.parent.fd)+'/'+self.path.name
        except Exception:
            self.close();raise
    def check(self):
        outside_git(self.path);require(report_ancestry(self.path.parent)==self.ancestry,'input ancestry moved');self.parent.recheck()
        require(file_identity(os.fstat(self.parent.fd))==self.parent_info and file_identity(os.fstat(self.fd))==file_identity(self.info) and file_identity(os.stat(self.path.name,dir_fd=self.parent.fd,follow_symlinks=False))==file_identity(self.info),'protected input moved')
    def close(self):
        if self.fd is not None:os.close(self.fd);self.fd=None
        self.parent.close()

def gate_and_claim(c,contract_sha,report,custody,input_checks=()):
    target_contract(c);tailnet_contract(c);lifetime(c,120);directory=custody if isinstance(custody,Custody) else Custody(custody)
    owned=not isinstance(custody,Custody)
    try:
        directory.recheck();held=HeldReport(report)
        try:
            held.check();[check() for check in input_checks];installed_gate(c);held.check();[check() for check in input_checks]
            gate=subprocess.run([GATE,'check','--before','production','--reviewer-approval',held.anchor],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=30,env={'PATH':'/usr/local/bin:/usr/bin:/bin','HOME':'/home/ahazan'})
            held.check();[check() for check in input_checks];require(gate.returncode==0,'production lifecycle refused')
            installed_gate(c);held.check();[check() for check in input_checks];directory.recheck();lifetime(c,90);verify_tailnet(c);held.check();[check() for check in input_checks]
            name=c['claim_id']+'.claim.json'
            directory.create(name,json.dumps({'contract_sha256':contract_sha,'review_report_sha256':held.sha256,'mode':c['mode'],'issued_at':c['issued_at'],'expires_at':c['expires_at'],'claimed_at':int(time.time()),'spent':True}).encode())
            held.check();[check() for check in input_checks]
            return Path(directory.path)/name
        finally:held.close()
    finally:
        if owned:directory.close()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--contract',required=True);parser.add_argument('--contract-sha256',required=True);parser.add_argument('--reviewer-approval',required=True);parser.add_argument('--known-hosts',required=True);parser.add_argument('--custody',required=True)
    args=parser.parse_args()
    # Remove BOTH credentials before ANY lifecycle child. Root injects them only
    # through its serialized protected op_run; values never enter argv/receipts.
    global _PASSWORD,_TOKEN
    password,token=_PASSWORD,_TOKEN;_PASSWORD=_TOKEN=None
    custody=None;contract_input=None;host_input=None
    try:
        protected_tmp=Custody(os.environ.get('TMPDIR',''));protected_tmp.close()
        contract_input=HeldInput(args.contract,8192)
        c=load_contract(contract_input,args.contract_sha256);contract_input.check()
        host_input=HeldInput(args.known_hosts,142,exact_size=142)
        require(hashlib.sha256(host_input.raw).hexdigest()==c['known_hosts_sha256'],'known host changed');host_input.check();contract_input.check()
        source=c.remote_source
        require(isinstance(token,str) and re.fullmatch(r'[!-~]{1,8192}',token,flags=re.ASCII) and isinstance(password,str) and password and len(password.encode())<=LIMIT and not any(x in password for x in ('\x00','\n','\r')),'credential presence/shape refused before claim')
        lifetime(c,120)
        custody=Custody(args.custody)
        gate_and_claim(c,args.contract_sha256,args.reviewer_approval,custody,(contract_input.check,host_input.check))
        contract_input.check();host_input.check()
        actual_version,peer_state=version(token,c);del token
        contract_input.check();host_input.check()
        require(c['mode']=='discover' or actual_version=='4.4.6','unqualified installed platform version')
        lifetime(c,60)
        raw=read_remote(c,host_input,password,source);del password
        contract_input.check();host_input.check()
        result=validate(raw,c);result.update(platform_version=actual_version,contract_sha256=args.contract_sha256,tailnet_runtime_checks=peer_state)
        lifetime(c);custody.create(c['claim_id']+'.receipt.json',json.dumps(result,sort_keys=True).encode())
        print('bounded platform metadata receipt retained; no launch admitted')
    except Exception:
        print('platform capability reader refused; one-use claim retained if spent',file=sys.stderr);return 3
    finally:
        password=token=None
        if custody is not None:custody.close()
        if host_input is not None:host_input.close()
        if contract_input is not None:contract_input.close()
    return 0
if __name__=='__main__':raise SystemExit(main())
