"""Closed public platform capability reader; never an issuer or deployment.

Discovery and qualification need different exact reviewed contracts/one-use
claims. No live use is performed by preparation/tests.
"""
import argparse,base64,hashlib,importlib.util,json,os,re,resource,stat,subprocess,sys,tempfile,time,urllib.request
from pathlib import Path
LIMIT=65536
HELPER='ghcr.io/coollabsio/coolify-helper'
API='http://100.66.37.58:8000/api/v1/version'
SOURCE_PLATFORM='f55efc859dfcbbf79274c4907b3df89f9767c11d'
# Strip injected credentials before ANY project module executes.
resource.setrlimit(resource.RLIMIT_CORE,(0,0))
_PASSWORD=os.environ.pop('ORACLE_HETZ_READ_PASSWORD',None)
_TOKEN=os.environ.pop('ORACLE_COOLIFY_READ_TOKEN',None)
HELPER_SHA='35173ab9a0422b7f9cbccd13929d83ff568525f2d244ad5af9b14ca451f60754'
def require(ok,message):
    if not ok:raise ValueError(message)
def bounded_file(path,maximum):
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW)
    with os.fdopen(fd,'rb') as f:
        before=os.fstat(f.fileno());require(stat.S_ISREG(before.st_mode) and before.st_nlink==1 and before.st_size<=maximum,'bounded regular source required')
        raw=f.read(maximum+1);require(len(raw)<=maximum and os.fstat(f.fileno())==before,'source moved')
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
BASE={'schema','mode','application','api','platform_source','host','user','port','known_hosts_sha256','issued_at','expires_at','installed_gate','claim_id','operator_sha256','remote_sha256','transport_helper_sha256'}
FIXED={'schema':'oracle-platform-capability/v2','application':'vhmcdkdk23dgvjvcvhyhcjzd','api':API,'platform_source':SOURCE_PLATFORM,'host':'hetz','user':'ai','port':22}

class ReviewedContract(dict):pass

def load_contract(path,seal):
    raw=bounded_file(path,8192);require(re.fullmatch('[a-f0-9]{64}',seal) and hashlib.sha256(raw).hexdigest()==seal,'contract mismatch')
    c=ReviewedContract(json.loads(raw));extra={'helper_id','helper_name','helper_image','helper_image_id'} if c.get('mode')=='qualify' else set()
    require(set(c)==BASE|extra and all(c[k]==v for k,v in FIXED.items()),'closed contract mismatch')
    require(c['mode'] in {'discover','qualify'} and type(c['expires_at']) is int and type(c['claim_id']) is str and re.fullmatch('[a-z0-9-]{1,64}',c['claim_id']),'contract metadata invalid')
    require(re.fullmatch('[a-f0-9]{64}',c['known_hosts_sha256']),'known host pin invalid')
    if c['mode']=='qualify':
        require(re.fullmatch('[a-f0-9]{64}',c['helper_id']) and re.fullmatch('[a-z0-9][a-z0-9_-]{0,63}',c['helper_name']),'helper identity invalid')
        require(re.fullmatch(re.escape(HELPER)+r'(?::[a-zA-Z0-9_.-]{1,64}|@sha256:[a-f0-9]{64})',c['helper_image']) and re.fullmatch('sha256:[a-f0-9]{64}',c['helper_image_id']),'immutable helper image required')
    for key,path in [('operator_sha256',Path(__file__)),('remote_sha256',Path(__file__).with_name('remote.py')),('transport_helper_sha256',Path(helpers.__file__))]:
        source=bounded_file(path,65536)
        require(re.fullmatch('[a-f0-9]{64}',c[key]) and hashlib.sha256(source).hexdigest()==c[key],'reviewed source changed')
        if key=='remote_sha256':c.remote_source=source
    lifetime(c)
    return c

def remote_command(c,source):
    # This is a fixed public source program; caller supplies no shell/argv/path.
    require(type(source) is bytes and len(source)<=65536 and hashlib.sha256(source).hexdigest()==c['remote_sha256'],'held remote source changed')
    encoded=base64.b64encode(source).decode();config=base64.b64encode(json.dumps(c,sort_keys=True).encode()).decode()
    return '/usr/bin/python3 -c "import base64;C=__import__(\'json\').loads(base64.b64decode(\''+config+'\'));exec(base64.b64decode(\''+encoded+'\'))"'

def read_remote(contract,known_hosts,password,source):
    lifetime(contract,60)
    hosts=bounded_file(known_hosts,8192);require(hashlib.sha256(hosts).hexdigest()==contract['known_hosts_sha256'],'known hosts changed')
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
        command=['/usr/bin/ssh','-F','/dev/null','-T','-p','22','-o','StrictHostKeyChecking=yes','-o','UserKnownHostsFile='+anchor+'/known-hosts','-o','GlobalKnownHostsFile=/dev/null','-o','ConnectTimeout=10','-o','ConnectionAttempts=1','-o','NumberOfPasswordPrompts=1','-o','IdentitiesOnly=yes','-o','PubkeyAuthentication=no','-o','PreferredAuthentications=password','-o','ProxyCommand=none','-o','ProxyJump=none','-o','ClearAllForwardings=yes','ai@hetz',remote_command(contract,source)]
        def bound_file():resource.setrlimit(resource.RLIMIT_FSIZE,(LIMIT,LIMIT))
        # Anonymous output descriptors never follow mutable named parents.
        with tempfile.TemporaryFile(dir=anchor) as output,tempfile.TemporaryFile(dir=anchor) as error:
            directory.recheck();parent.recheck();lifetime(contract,60)
            result=subprocess.run(command,stdin=subprocess.DEVNULL,stdout=output,stderr=error,timeout=55,env=child,start_new_session=True,preexec_fn=bound_file)
            directory.recheck();parent.recheck();lifetime(contract)
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

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):raise ValueError('API redirect denied')

def version(token):
    require(isinstance(token,str) and re.fullmatch(r'[!-~]{1,8192}',token,flags=re.ASCII),'protected ASCII API credential missing')
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect())
    request=urllib.request.Request(API,headers={'Authorization':'Bearer '+token,'Accept':'text/plain'},method='GET')
    with opener.open(request,timeout=10) as response:
        require(response.status==200 and response.geturl()==API,'version endpoint refused')
        raw=response.read(65)
    value=raw.decode('ascii').strip();require(len(raw)<=64 and re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+',value),'version metadata invalid')
    return value

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
def installed_gate(c):
    pins=c['installed_gate'];require(type(pins) is dict and set(pins)=={'source_head','launcher_sha256','manifest_sha256'},'exact installed gate pins required')
    require(re.fullmatch('[a-f0-9]{40}',pins['source_head']) and all(re.fullmatch('[a-f0-9]{64}',pins[k]) for k in ('launcher_sha256','manifest_sha256')),'installed gate identity invalid')
    link=os.lstat(GATE);require(stat.S_ISLNK(link.st_mode) and link.st_uid==0 and os.readlink(GATE)==GATE_SOURCE,'root-owned installed launcher required')
    info=os.lstat(MANIFEST);require(stat.S_ISREG(info.st_mode) and info.st_uid==0 and info.st_nlink==1 and not info.st_mode&0o022,'root-owned install receipt required')
    manifest=bounded_file(MANIFEST,1024*1024);require(hashlib.sha256(manifest).hexdigest()==pins['manifest_sha256'],'installed manifest moved')
    rows=[x.split('\t') for x in manifest.decode('ascii').splitlines()]
    require([x[2] for x in rows if x[:2]==['meta','source_sha']]==[pins['source_head']],'installed source identity moved')
    require([x for x in rows if x[:2]==['symlink',GATE]]==[['symlink',GATE,GATE_SOURCE,pins['launcher_sha256']]],'installed gate receipt differs')
    require(hashlib.sha256(bounded_file(GATE_SOURCE,1024*1024)).hexdigest()==pins['launcher_sha256'],'installed gate source changed')
    head=subprocess.run(['/usr/bin/git','-C','/home/ahazan/repos/ai-devops','rev-parse','HEAD'],capture_output=True,timeout=5,env={'PATH':'/usr/local/bin:/usr/bin:/bin','HOME':'/home/ahazan'})
    require(head.returncode==0 and head.stdout.decode('ascii').strip()==pins['source_head'],'installed checkout not current')
    status=subprocess.run(['/usr/bin/git','-c','core.fsmonitor=false','-c','core.hooksPath=/dev/null','-C','/home/ahazan/repos/ai-devops','status','--porcelain','--untracked-files=no'],capture_output=True,timeout=5,env={'PATH':'/usr/local/bin:/usr/bin:/bin','HOME':'/home/ahazan'})
    require(status.returncode==0 and not status.stdout,'installed tracked source moved')
    return pins

def gate_and_claim(c,contract_sha,report,custody):
    lifetime(c,120);directory=custody if isinstance(custody,Custody) else Custody(custody)
    owned=not isinstance(custody,Custody)
    try:
        directory.recheck();installed_gate(c)
        gate=subprocess.run([GATE,'check','--before','production','--reviewer-approval',str(report)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=30,env={'PATH':'/usr/local/bin:/usr/bin:/bin','HOME':'/home/ahazan'})
        require(gate.returncode==0,'production lifecycle refused')
        installed_gate(c);directory.recheck();lifetime(c,90)
        name=c['claim_id']+'.claim.json'
        directory.create(name,json.dumps({'contract_sha256':contract_sha,'mode':c['mode'],'issued_at':c['issued_at'],'expires_at':c['expires_at'],'claimed_at':int(time.time()),'spent':True}).encode())
        return Path(directory.path)/name
    finally:
        if owned:directory.close()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--contract',required=True);parser.add_argument('--contract-sha256',required=True);parser.add_argument('--reviewer-approval',required=True);parser.add_argument('--known-hosts',required=True);parser.add_argument('--custody',required=True)
    args=parser.parse_args()
    # Remove BOTH credentials before ANY lifecycle child. Root injects them only
    # through its serialized protected op_run; values never enter argv/receipts.
    global _PASSWORD,_TOKEN
    password,token=_PASSWORD,_TOKEN;_PASSWORD=_TOKEN=None
    custody=None
    try:
        c=load_contract(args.contract,args.contract_sha256)
        require(hashlib.sha256(bounded_file(args.known_hosts,8192)).hexdigest()==c['known_hosts_sha256'],'known host changed')
        source=c.remote_source
        custody=Custody(args.custody)
        gate_and_claim(c,args.contract_sha256,args.reviewer_approval,custody)
        actual_version=version(token);del token
        require(c['mode']=='discover' or actual_version=='4.4.6','unqualified installed platform version')
        lifetime(c,60)
        raw=read_remote(c,args.known_hosts,password,source);del password
        result=validate(raw,c);result.update(platform_version=actual_version,contract_sha256=args.contract_sha256)
        lifetime(c);custody.create(c['claim_id']+'.receipt.json',json.dumps(result,sort_keys=True).encode())
        print('bounded platform metadata receipt retained; no launch admitted')
    except Exception:
        print('platform capability reader refused; one-use claim retained if spent',file=sys.stderr);return 3
    finally:
        password=token=None
        if custody is not None:custody.close()
    return 0
if __name__=='__main__':raise SystemExit(main())
