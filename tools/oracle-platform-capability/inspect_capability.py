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
spec=importlib.util.spec_from_file_location('oracle_metadata_helpers',Path(__file__).resolve().parents[1]/'oracle-hosting-diagnosis/inspect_metadata.py')
helpers=importlib.util.module_from_spec(spec);spec.loader.exec_module(helpers)
require,bounded_file,transport_failure=helpers.require,helpers.bounded_file,helpers.transport_failure
IDENTITY='{"id":{{json .Id}},"name":{{json .Name}},"image":{{json .Config.Image}},"image_id":{{json .Image}},"state":{{json .State.Status}}}'
INVENTORY='{"id":{{json .ID}},"image":{{json .Image}},"name":{{json .Names}},"state":{{json .State}}}'
BASE={'schema','mode','application','api','platform_source','host','user','port','known_hosts_sha256','expires_at','claim_id','operator_sha256','remote_sha256','transport_helper_sha256'}
FIXED={'schema':'oracle-platform-capability/v1','application':'vhmcdkdk23dgvjvcvhyhcjzd','api':API,'platform_source':SOURCE_PLATFORM,'host':'hetz','user':'ai','port':22}

def load_contract(path,seal):
    raw=bounded_file(path,8192);require(re.fullmatch('[a-f0-9]{64}',seal) and hashlib.sha256(raw).hexdigest()==seal,'contract mismatch')
    c=json.loads(raw);extra={'helper_id','helper_name','helper_image','helper_image_id'} if c.get('mode')=='qualify' else set()
    require(set(c)==BASE|extra and all(c[k]==v for k,v in FIXED.items()),'closed contract mismatch')
    require(c['mode'] in {'discover','qualify'} and type(c['expires_at']) is int and type(c['claim_id']) is str and re.fullmatch('[a-z0-9-]{1,64}',c['claim_id']),'contract metadata invalid')
    require(re.fullmatch('[a-f0-9]{64}',c['known_hosts_sha256']),'known host pin invalid')
    if c['mode']=='qualify':
        require(re.fullmatch('[a-f0-9]{64}',c['helper_id']) and re.fullmatch('[a-z0-9][a-z0-9_-]{0,63}',c['helper_name']),'helper identity invalid')
        require(re.fullmatch(re.escape(HELPER)+r'(?::[a-zA-Z0-9_.-]{1,64}|@sha256:[a-f0-9]{64})',c['helper_image']) and re.fullmatch('sha256:[a-f0-9]{64}',c['helper_image_id']),'immutable helper image required')
    for key,path in [('operator_sha256',Path(__file__)),('remote_sha256',Path(__file__).with_name('remote.py')),('transport_helper_sha256',Path(helpers.__file__))]:
        require(re.fullmatch('[a-f0-9]{64}',c[key]) and hashlib.sha256(bounded_file(path,65536)).hexdigest()==c[key],'reviewed source changed')
    return c

def remote_command(c):
    # This is a fixed public source program; caller supplies no shell/argv/path.
    source=Path(__file__).with_name('remote.py').read_bytes()
    encoded=base64.b64encode(source).decode();config=base64.b64encode(json.dumps(c,sort_keys=True).encode()).decode()
    return 'python3 -c "import base64;C=__import__(\'json\').loads(base64.b64decode(\''+config+'\'));exec(base64.b64decode(\''+encoded+'\'))"'

def read_remote(contract, known_hosts, password):
    hosts=bounded_file(known_hosts,8192)
    require(len(hosts)<=8192 and hashlib.sha256(hosts).hexdigest()==contract['known_hosts_sha256'],'known-hosts changed')
    require(type(password) is str and password and len(password.encode('utf-8')) <= LIMIT and '\x00' not in password and '\n' not in password and '\r' not in password,'protected credential missing')
    parent=os.environ.get('TMPDIR')
    if parent is not None:
        parent_stat=os.stat(parent,follow_symlinks=False)
        require(stat.S_ISDIR(parent_stat.st_mode) and parent_stat.st_uid==os.getuid() and stat.S_IMODE(parent_stat.st_mode)==0o700,'protected temp parent required')
    with tempfile.TemporaryDirectory(prefix='oracle-metadata-',dir=parent) as directory:
        os.chmod(directory,0o700)
        pinned_hosts=Path(directory)/'known-hosts'
        fd=os.open(pinned_hosts,os.O_CREAT|os.O_EXCL|os.O_WRONLY|os.O_NOFOLLOW,0o600)
        with os.fdopen(fd,'wb') as stream:stream.write(hosts)
        secret=Path(directory)/'password'
        fd=os.open(secret,os.O_CREAT|os.O_EXCL|os.O_WRONLY|os.O_NOFOLLOW,0o600)
        with os.fdopen(fd,'w') as stream:stream.write(password)
        del password
        helper=Path(directory)/'askpass'
        helper_source=('#!'+sys.executable+'\nimport os,stat,sys\n'
          'fd=os.open('+repr(str(secret))+',os.O_RDONLY|os.O_NOFOLLOW)\n'
          'st=os.fstat(fd)\n'
          'if not stat.S_ISREG(st.st_mode) or st.st_uid!=os.getuid() or st.st_mode&0o777!=0o600 or st.st_size>65536:sys.exit(3)\n'
          'with os.fdopen(fd,\"rb\") as stream:sys.stdout.buffer.write(stream.read(65537))\n')
        fd=os.open(helper,os.O_CREAT|os.O_EXCL|os.O_WRONLY|os.O_NOFOLLOW,0o700)
        with os.fdopen(fd,'w') as stream:stream.write(helper_source)
        child={'PATH':'/usr/bin:/bin','LANG':'C','SSH_ASKPASS':str(helper),'SSH_ASKPASS_REQUIRE':'force','DISPLAY':'oracle-metadata:0'}
        command=['/usr/bin/ssh','-F','/dev/null','-T','-p','22','-o','StrictHostKeyChecking=yes','-o','UserKnownHostsFile='+str(pinned_hosts),'-o','GlobalKnownHostsFile=/dev/null','-o','ConnectTimeout=10','-o','ConnectionAttempts=1','-o','NumberOfPasswordPrompts=1','-o','IdentitiesOnly=yes','-o','PubkeyAuthentication=no','-o','PreferredAuthentications=password','-o','ProxyCommand=none','-o','ProxyJump=none','-o','ClearAllForwardings=yes','ai@hetz',remote_command(contract)]
        def bound_file():resource.setrlimit(resource.RLIMIT_FSIZE,(LIMIT,LIMIT))
        with tempfile.TemporaryFile(dir=directory) as output, tempfile.TemporaryFile(dir=directory) as error:
            result=subprocess.run(command,stdin=subprocess.DEVNULL,stdout=output,stderr=error,timeout=55,env=child,start_new_session=True,preexec_fn=bound_file)
            if result.returncode:
                error.seek(0)
                raise ValueError(transport_failure(result.returncode,error.read(4097)))
            output.seek(0)
            return output.read(LIMIT+1)

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,*args,**kwargs):raise ValueError('API redirect denied')

def version(token):
    require(isinstance(token,str) and token and len(token)<=8192 and '\n' not in token and '\r' not in token,'protected API credential missing')
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

def gate_and_claim(c,contract_sha,report,custody):
    require(time.time()+120<c['expires_at'],'metadata action expiry')
    custody=Path(custody).absolute()
    for ancestor in (custody,*custody.parents):require(not ancestor.is_symlink(),'claim custody symlink denied')
    info=os.stat(custody,follow_symlinks=False);require(stat.S_ISDIR(info.st_mode) and info.st_uid==os.getuid() and stat.S_IMODE(info.st_mode)==0o700,'private claim custody required')
    # Installed authentic exact-head reviewer lifecycle owns this decision;
    # dictionaries/booleans cannot substitute for a genuine accepted report.
    gate=subprocess.run(['ai-task-gates','check','--before','production','--reviewer-approval',str(report)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=30,env={'PATH':'/home/ahazan/.local/bin:/usr/local/bin:/usr/bin:/bin','HOME':str(Path.home())})
    require(gate.returncode==0,'production lifecycle refused')
    require(time.time()+90<c['expires_at'],'metadata action expiry')
    claim=Path(custody)/(c['claim_id']+'.claim.json')
    directory=os.open(custody,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:fd=os.open(claim.name,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=directory)
    finally:os.close(directory)
    with os.fdopen(fd,'w') as stream:json.dump({'contract_sha256':contract_sha,'mode':c['mode'],'expires_at':c['expires_at'],'claimed_at':int(time.time()),'spent':True},stream);stream.flush();os.fsync(stream.fileno())
    return claim

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--contract',required=True);parser.add_argument('--contract-sha256',required=True);parser.add_argument('--reviewer-approval',required=True);parser.add_argument('--known-hosts',required=True);parser.add_argument('--custody',required=True)
    args=parser.parse_args()
    # Remove BOTH credentials before ANY lifecycle child. Root injects them only
    # through its serialized protected op_run; values never enter argv/receipts.
    password=os.environ.pop('ORACLE_HETZ_READ_PASSWORD',None);token=os.environ.pop('ORACLE_COOLIFY_READ_TOKEN',None)
    try:
        c=load_contract(args.contract,args.contract_sha256)
        require(hashlib.sha256(bounded_file(args.known_hosts,8192)).hexdigest()==c['known_hosts_sha256'],'known host changed')
        gate_and_claim(c,args.contract_sha256,args.reviewer_approval,args.custody)
        actual_version=version(token);del token
        require(c['mode']=='discover' or actual_version=='4.4.6','unqualified installed platform version')
        raw=read_remote(c,args.known_hosts,password);del password
        result=validate(raw,c);result.update(platform_version=actual_version,contract_sha256=args.contract_sha256)
        fd=os.open(Path(args.custody)/(c['claim_id']+'.receipt.json'),os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
        with os.fdopen(fd,'w') as stream:json.dump(result,stream,sort_keys=True);stream.flush();os.fsync(stream.fileno())
        print('bounded platform metadata receipt retained; no launch admitted')
    except Exception:
        print('platform capability reader refused; one-use claim retained if spent',file=sys.stderr);return 3
    return 0
if __name__=='__main__':raise SystemExit(main())
