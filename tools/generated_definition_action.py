"""Closed public generated-fixture validation for ai-task-gates (no execution).

Owned by the native task gate. Shares native custody IO only; neither imports
application code nor changes the private #770 profile. Audit is not a token.
"""
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import stat
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
_spec = importlib.util.spec_from_file_location('generated_native_io', ROOT / 'bin/ai-review-code-only.py')
IO = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(IO)
FIXTURE = 'generated-definition-boundary-v1'
GATE = 'reviewed-generated-definition-fixture-only'
REPOSITORY = 'popcre/designflow-backend'
HEX = re.compile(r'[0-9a-f]{64}\Z')
COMMIT = re.compile(r'[0-9a-f]{40}\Z')
IDENTIFIER = re.compile(r'[0-9a-f]{32}\Z')
SOURCE = sorted(['package.json', 'scripts/cutover-synthetic/run.cjs',
 'scripts/cutover-synthetic/generated-definition-admission.cjs',
 'scripts/cutover-synthetic/generated-definition-fixtures.cjs',
 'scripts/cutover-synthetic/generated-definition-qualification.cjs',
 'scripts/cutover-synthetic/private-profile.cjs', 'scripts/cutover-synthetic/reconcile.cjs',
 'scripts/lib/strict-json.cjs'])
CONSUMER = '.ai-devops/task-gates.json'
CHANGES = sorted(['plan_4250_generated_definition_qualification.md',
 'docs/verification/cutover-synthetic/generated-definition-boundary-spec.md',
 'scripts/cutover-synthetic/README.md', 'scripts/cutover-synthetic/run.cjs',
 'scripts/cutover-synthetic/generated-definition-admission.cjs',
 'scripts/cutover-synthetic/generated-definition-fixtures.cjs',
 'scripts/cutover-synthetic/generated-definition-qualification.cjs',
 'scripts/cutover-synthetic/generated-definition-qualification.test.cjs', CONSUMER])
RESOURCES = dict(instances=1, cpu=2, memoryBytes=2147483648, swapBytes=2147483648,
                 pids=128, nodeHeapMiB=2048, tmpBytes=67108864)
LIMITS = dict(wallMs=120000, containerCommandMs=30000, connectMs=1000,
              statementMs=5000, lockMs=1000, stopSeconds=10)
ENVELOPE = {'schema_version','fixture_id','repository','source_head','source_closure_sha256',
 'fixture_sha256','admission_path','admission_sha256','runtime_receipt_path','runtime_receipt_sha256'}
UNSAFE = re.compile(r'^(GIT_(DIR|WORK_TREE|COMMON_DIR|INDEX_FILE|OBJECT_DIRECTORY|ALTERNATE_OBJECT_DIRECTORIES|CONFIG.*|PREFIX|CEILING_DIRECTORIES|NAMESPACE|DISCOVERY_ACROSS_FILESYSTEM|REPLACE_REF_BASE|GRAFT_FILE)|NODE_PATH|PG.*|DOCKER_(HOST|CONTEXT|TLS_VERIFY|CERT_PATH))$')


def require(value, reason='generated fixture consistency refused'):
    if not value:
        raise ValueError(reason)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True).encode()


def exact(value, wanted):
    if type(value) is not type(wanted):
        return False
    if type(wanted) is dict:
        return value.keys() == wanted.keys() and all(exact(value[k], v) for k,v in wanted.items())
    if type(wanted) is list:
        return len(value) == len(wanted) and all(exact(a,b) for a,b in zip(value,wanted))
    return value == wanted


def keys(value, expected):
    require(type(value) is dict and set(value) == set(expected))


def decode(raw, maximum=8192):
    require(len(raw) <= maximum)
    def unique(pairs):
        result = {}
        for k,v in pairs:
            require(k not in result and k not in ('__proto__','prototype','constructor'))
            result[k] = v
        return result
    value = json.loads(raw.decode('utf-8'), object_pairs_hook=unique,
                       parse_constant=lambda _: require(False))
    def check(v, depth=0):
        require(depth <= 16)
        if isinstance(v,str):
            require('\x00' not in v and not any(0xD800 <= ord(c) <= 0xDFFF for c in v))
        elif isinstance(v,float):
            require(math.isfinite(v))
        elif isinstance(v,dict):
            for k,x in v.items(): check(k,depth+1); check(x,depth+1)
        elif isinstance(v,list):
            for x in v: check(x,depth+1)
    check(value)
    return value


def select(raw):
    try:
        return decode(raw).get('fixture_id') == FIXTURE
    except (ValueError, TypeError, AttributeError, UnicodeError):
        return False


def pathname(value):
    require(type(value) is str and '\x00' not in value and '=' not in value)
    p = Path(value)
    require(p.is_absolute() and str(p) == value and '..' not in p.parts)
    return p


def read(path, maximum=8192, private=False):
    p = pathname(str(path))
    info = p.lstat()
    require(info.st_nlink == 1 and stat.S_ISREG(info.st_mode))
    if private:
        require(info.st_uid == os.getuid() and stat.S_IMODE(info.st_mode) == 0o600)
    raw = IO.private_read(p, limit=maximum, private=private)
    after = p.lstat()
    require((info.st_dev,info.st_ino,info.st_mode,info.st_nlink,info.st_uid,info.st_size,info.st_mtime_ns,info.st_ctime_ns) ==
            (after.st_dev,after.st_ino,after.st_mode,after.st_nlink,after.st_uid,after.st_size,after.st_mtime_ns,after.st_ctime_ns))
    return raw


def registry():
    value = decode(read(ROOT/'config/review-action-profiles.json', 1<<20),1<<20)
    profile = value['profiles'][FIXTURE]
    keys(profile, {'action','repository','required_gate','source_paths','changed_paths','pins','resources','limits','retirement'})
    require(profile['action']=='database' and profile['repository']==REPOSITORY and profile['required_gate']==GATE)
    require(profile['source_paths']==SOURCE and profile['changed_paths']==CHANGES)
    require(exact(profile['resources'],RESOURCES) and exact(profile['limits'],LIMITS))
    pins=profile['pins']
    keys(pins, {'fixture_sha256','image','node_version','node_sha256','npm_version','npm_inventory_sha256','dependency_inventory_sha256','package_sha256','pg_version','pg_entry_sha256','fixture_module_sha256'})
    for k,v in pins.items():
        require(type(v) is str and (k in ('image','node_version','npm_version','pg_version') or HEX.fullmatch(v)))
    return profile


def git(repo, *args):
    require(not any(UNSAFE.match(k) for k in os.environ), 'redirected generated action context')
    env={'PATH':'/usr/bin:/bin','HOME':os.path.expanduser('~'),'LANG':'C',
         'GIT_CONFIG_NOSYSTEM':'1','GIT_CONFIG_GLOBAL':'/dev/null','GIT_OPTIONAL_LOCKS':'0'}
    p=subprocess.run(['/usr/bin/git','--no-replace-objects','-c','core.fsmonitor=false','-c','core.hooksPath=/dev/null','-C',str(repo),*args],
                     stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env,timeout=20)
    require(p.returncode==0,'generated source Git proof refused')
    return p.stdout


def source_identity(repo, state, profile):
    repo=pathname(str(repo)); require(repo.resolve(strict=True)==repo and repo.is_dir())
    require(Path(git(repo,'rev-parse','--show-toplevel').decode().strip()).resolve()==repo)
    common=Path(git(repo,'rev-parse','--path-format=absolute','--git-common-dir').decode().strip())
    require(not (common/'shallow').exists() and not (common/'info/grafts').exists())
    require(not git(repo,'for-each-ref','--format=%(refname)','refs/replace'))
    require(git(repo,'rev-parse','--is-shallow-repository').strip()==b'false')
    origin=git(repo,'remote','get-url','origin').decode().strip()
    require(origin in ('https://github.com/'+REPOSITORY,'https://github.com/'+REPOSITORY+'.git',
                       'git@github.com:'+REPOSITORY,'git@github.com:'+REPOSITORY+'.git',
                       'ssh://git@github.com/'+REPOSITORY,'ssh://git@github.com/'+REPOSITORY+'.git'))
    require(not git(repo,'status','--porcelain','--untracked-files=all'))
    head=git(repo,'rev-parse','--verify','HEAD^{commit}').decode().strip()
    require(head==state['head'] and COMMIT.fullmatch(head))
    env=IO.git_env(); env.pop('NODE_PATH',None)
    probe=subprocess.run([str(ROOT/'bin/ai-task-gates'),'explain','--json'],cwd=repo,env=env,
                         stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30)
    require(probe.returncode==0)
    task=decode(probe.stdout,1<<20)
    require(task['repository']==REPOSITORY and task['effective_class']=='reviewer-safety' and task['declared_class']=='reviewer-safety')
    base=git(repo,'rev-parse','--verify',task['base']+'^{commit}').decode().strip()
    git(repo,'merge-base','--is-ancestor',base,head)
    changes=git(repo,'diff','--no-renames','--name-status','-z',base,head).split(b'\0')
    changed=[]
    for i in range(0,len(changes)-1,2):
        require(changes[i] in (b'A',b'M'), 'deleted or renamed action contributor')
        name=changes[i+1].decode('utf-8');require(name in CHANGES);changed.append(name)
    require(CONSUMER in changed)
    current=decode(read(repo/CONSUMER,1<<20),1<<20)
    require('database' not in current.get('gates',{}).get('reviewer-safety',{}).get('forbidden_actions',[]),'explicit consumer database prohibition')
    before=decode(git(repo,'show',base+':'+CONSUMER),1<<20)
    require('database' not in before.get('gates',{}).get('reviewer-safety',{}).get('forbidden_actions',[]),'explicit consumer database prohibition')
    wanted=json.loads(json.dumps(before)); required=wanted['gates']['reviewer-safety']['required']
    require(GATE not in required); required.append(GATE)
    require(exact(current,wanted),'consumer opt-in changed other policy')
    framed=hashlib.sha256()
    for name in SOURCE:
        tracked=git(repo,'ls-files','--error-unmatch',name).decode().strip();require(tracked==name)
        raw=read(repo/name,32<<20)
        require(raw==git(repo,'show',head+':'+name))
        if name=='scripts/cutover-synthetic/generated-definition-fixtures.cjs':
            require(sha(raw)==profile['pins']['fixture_module_sha256'],'fixed fixture module changed')
        encoded=name.encode();framed.update(str(len(encoded)).encode()+b'\n'+encoded+b'\n'+sha(raw).encode()+b'\n')
    return {'head':head,'base':base,'root':str(repo),'source_closure_sha256':framed.hexdigest(),'changed_paths':sorted(changed)}


def inventory(root, descriptor, pinned, limits):
    keys(descriptor, {'root','manifest','sha256','entries','externalSymlinks'})
    require(descriptor['root']==str(root) and descriptor['sha256']==pinned and type(descriptor['externalSymlinks']) is int and descriptor['externalSymlinks']==0)
    require(type(descriptor['entries']) is int and 0<descriptor['entries']<=limits[0])
    require(root.resolve(strict=True)==root and root.is_dir())
    raw=read(pathname(descriptor['manifest']),16<<20,private=True)
    require(sha(raw)==pinned)
    rows=decode(raw,16<<20);require(type(rows) is list and len(rows)==descriptor['entries'])
    actual=set();dirs=[]
    for parent, subdirs, files in os.walk(root,followlinks=False):
        dirs.append((Path(parent),Path(parent).stat()))
        for name in subdirs+files:
            p=Path(parent)/name; st=p.lstat()
            if not stat.S_ISDIR(st.st_mode): actual.add(p.relative_to(root).as_posix())
            require(stat.S_ISDIR(st.st_mode) or stat.S_ISLNK(st.st_mode) or stat.S_ISREG(st.st_mode))
        require(len(actual)<=limits[0])
    seen=set();total=0;snapshots=[]
    for row in rows:
        require(type(row) is dict and type(row.get('path')) is str)
        rel=row['path'];p=root/rel
        require(rel and not Path(rel).is_absolute() and '..' not in Path(rel).parts and rel not in seen and str(Path(rel))==rel)
        seen.add(rel);snapshots.append((p,p.lstat()))
        if 'symlink' in row:
            keys(row,{'path','symlink','resolvedTarget'})
            require(p.is_symlink() and os.readlink(p)==row['symlink'])
            target=p.resolve(strict=True);require(target.is_relative_to(root) and str(target)==row['resolvedTarget'])
        else:
            keys(row,{'path','sha256','bytes'})
            require(type(row['bytes']) is int and 0<=row['bytes']<=limits[2] and type(row['sha256']) is str and HEX.fullmatch(row['sha256']))
            data=read(p,limits[2]); require(len(data)==row['bytes'] and sha(data)==row['sha256'])
            total+=len(data);require(total<=limits[1])
    require(seen==actual,'runtime inventory omits or adds installed entries')
    for p,before in snapshots:
        after=p.lstat();require((before.st_dev,before.st_ino,before.st_mode,before.st_nlink,before.st_uid,before.st_size,before.st_mtime_ns,before.st_ctime_ns)==(after.st_dev,after.st_ino,after.st_mode,after.st_nlink,after.st_uid,after.st_size,after.st_mtime_ns,after.st_ctime_ns),'runtime file changed across inventory')
    for directory,before in dirs:
        after=directory.stat();require((before.st_dev,before.st_ino,before.st_mtime_ns,before.st_ctime_ns)==(after.st_dev,after.st_ino,after.st_mtime_ns,after.st_ctime_ns))
    return pinned


def runtime(receipt, repo, identity, profile):
    keys(receipt, {'scope','sourceCommit','clean','packageSha256','node','npm','dependencies','pg','sourceClosureSha256','fixtureSha256','image','resources','limits','NODE_PATH','install','admissionSelected','execution'})
    pin=profile['pins']
    require(receipt['scope']=='fixed generated fixture dependency qualification ONLY; no Docker/SQL/provider/admission/production action')
    require(receipt['sourceCommit']==identity['head'] and receipt['clean'] is True and receipt['NODE_PATH'] is False and receipt['admissionSelected'] is False and receipt['execution'] is False)
    require(receipt['packageSha256']==pin['package_sha256']==sha(read(repo/'package.json',1<<20)))
    require(receipt['sourceClosureSha256']==identity['source_closure_sha256'] and receipt['fixtureSha256']==pin['fixture_sha256'] and receipt['image']==pin['image'])
    require(exact(receipt['resources'],RESOURCES) and exact(receipt['limits'],LIMITS))
    node=receipt['node'];keys(node,{'binary','version','sha256'})
    binary=pathname(node['binary']);require(node['version']==pin['node_version'] and node['sha256']==pin['node_sha256']==sha(read(binary,256<<20)))
    npm=receipt['npm'];keys(npm,{'version','root','manifest','sha256','entries','externalSymlinks'})
    require(npm['version']==pin['npm_version'])
    npmroot=pathname(npm['root']); require(npmroot==binary.parent.parent/'lib/node_modules/npm')
    inventory(npmroot,{k:v for k,v in npm.items() if k!='version'},pin['npm_inventory_sha256'],(4096,32<<20,2<<20))
    require(decode(read(npmroot/'package.json',1<<20))['version']==pin['npm_version'])
    inventory(repo/'node_modules',receipt['dependencies'],pin['dependency_inventory_sha256'],(32768,512<<20,32<<20))
    pg=receipt['pg'];keys(pg,{'version','entry','entrySha256','importCheck'})
    require(pg['version']==pin['pg_version'] and pg['entry']==str(repo/'node_modules/pg/lib/index.js') and pg['entrySha256']==pin['pg_entry_sha256']==sha(read(pathname(pg['entry']),32<<20)) and pg['importCheck'] is True)
    require(decode(read(repo/'node_modules/pg/package.json',1<<20))['version']==pin['pg_version'])
    install=receipt['install'];keys(install,{'exit','log','logSha256','packagesAdded','scriptPolicyWarnings','wholeApplicationRuntimeQualified'})
    require(type(install['exit']) is int and install['exit']==0 and install['wholeApplicationRuntimeQualified'] is False and type(install['packagesAdded']) is int and install['packagesAdded']==756)
    require(install['scriptPolicyWarnings']==['bcrypt@6.0.0 install not covered by npm allowScripts','protobufjs@7.6.6 postinstall not covered by npm allowScripts'])
    require(type(install['logSha256']) is str and HEX.fullmatch(install['logSha256']) and sha(read(pathname(install['log']),16<<20,private=False))==install['logSha256'])


def output_identity(file):
    p=pathname(file);require(not p.exists() and not p.is_symlink())
    parent=p.parent; require(parent.resolve(strict=True)==parent)
    cursor=parent
    while True:
        st=cursor.lstat();require(stat.S_ISDIR(st.st_mode) and not stat.S_ISLNK(st.st_mode))
        if cursor==cursor.parent:break
        cursor=cursor.parent
    st=parent.stat();require(st.st_uid==os.getuid())
    return {'path':str(p),'parent_dev':st.st_dev,'parent_ino':st.st_ino,'parent_mode':st.st_mode,'parent_uid':st.st_uid}


def admission(record, envelope, identity, profile):
    keys(record, {'admissionSchemaVersion','kind','stage','admissionId','source','fixture','image','resources','limits','output','cleanup'})
    require(type(record['admissionSchemaVersion']) is int and record['admissionSchemaVersion']==1 and record['kind']=='generated-definition-qualification-admission' and record['stage']=='generated-only')
    require(type(record['admissionId']) is str and IDENTIFIER.fullmatch(record['admissionId']))
    require(exact(record['source'],{'repository':REPOSITORY,'commit':identity['head'],'closureSha256':identity['source_closure_sha256']}))
    require(exact(record['fixture'],{'id':FIXTURE,'sha256':profile['pins']['fixture_sha256']}))
    require(exact(record['image'],{'digest':profile['pins']['image']}) and exact(record['resources'],RESOURCES) and exact(record['limits'],LIMITS))
    keys(record['output'],{'resultPath','policy'});require(record['output']['policy']=='exclusive-0600-sanitized')
    output=output_identity(record['output']['resultPath'])
    require(output['path']!=envelope['admission_path'])
    require(exact(record['cleanup'],{'policy':'owned-nonce-only','required':True}))
    return output


def lifecycle(state, repo):
    require(state['status']=='completed' and state['verdict']=='APPROVE' and state['stale'] is False and state.get('failure_class') is None)
    require(state['repository_root']==str(repo) and state['provider'] and state['implementer_engine'] and state['provider'].lower()!=state['implementer_engine'].lower())
    require(state['review_mode'] in ('final-check','security-review'))
    require(not state.get('code_only') and not state.get('code_only_export') and not state.get('action_profile_binding') and state.get('evidence_scope')!='selected-code')
    require(state['tests']['exit']==0 and type(state['tests']['exit']) is int and HEX.fullmatch(state['tests']['output_sha256']))
    require(state['report_sha256']==sha(read(pathname(state['report_path']),16<<20,private=True)))
    require(state['source_digest']==IO.source_digest(repo),'whole-source seal moved')


def installed_enforcement():
    # Reuse native installed-source receipt verification, then bind this new
    # managed helper/config/classifier closure with raw Git object reads.
    spec = importlib.util.spec_from_file_location('generated_shared_profile', ROOT/'tools/review_action_profile.py')
    shared = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(shared)
    proof = shared.installed_enforcement()
    require(proof.get('kind') == 'VERIFIED_INSTALLED_SOURCE', 'generated route requires verified installed enforcement')
    head = proof['source_head']
    require(COMMIT.fullmatch(head) and git(ROOT,'rev-parse','HEAD').decode().strip()==head)
    common=Path(git(ROOT,'rev-parse','--path-format=absolute','--git-common-dir').decode().strip())
    require(not (common/'info/grafts').exists() and not (common/'shallow').exists())
    require(not git(ROOT,'for-each-ref','--format=%(refname)','refs/replace'))
    for name in ('tools/generated_definition_action.py','tools/review_action_profile.py',
                 'bin/ai-review-code-only.py','bin/ai-task-gates','config/task-gates.json',
                 'config/review-action-profiles.json'):
        require(read(ROOT/name,32<<20)==git(ROOT,'show',head+':'+name), 'installed generated enforcement moved')
    return proof


def validate(envelope, state):
    require(sys.platform=='linux' and os.name=='posix')
    require(not any(UNSAFE.match(k) for k in os.environ))
    if os.environ.get('AI_TASK_GATES_FILE'):
        require(pathname(os.environ['AI_TASK_GATES_FILE'])==ROOT/'config/task-gates.json','foreign central policy override')
    keys(envelope,ENVELOPE)
    require(type(envelope['schema_version']) is int and envelope['schema_version']==1 and envelope['fixture_id']==FIXTURE and envelope['repository']==REPOSITORY)
    for k in ('source_closure_sha256','fixture_sha256','admission_sha256','runtime_receipt_sha256'):
        require(type(envelope[k]) is str and HEX.fullmatch(envelope[k]))
    require(type(envelope['source_head']) is str and COMMIT.fullmatch(envelope['source_head']))
    installed_enforcement()
    profile=registry();repo=pathname(state['repository_root'])
    lifecycle(state,repo)
    identity=source_identity(repo,state,profile)
    require(envelope['source_head']==identity['head'] and envelope['source_closure_sha256']==identity['source_closure_sha256'] and envelope['fixture_sha256']==profile['pins']['fixture_sha256'])
    raw=read(pathname(envelope['admission_path']),8192,private=True);require(sha(raw)==envelope['admission_sha256'])
    result=admission(decode(raw),envelope,identity,profile)
    raw=read(pathname(envelope['runtime_receipt_path']),8192,private=True);require(sha(raw)==envelope['runtime_receipt_sha256'])
    runtime(decode(raw),repo,identity,profile)
    require(source_identity(repo,state,profile)==identity and IO.source_digest(repo)==state['source_digest'])
    require(result==output_identity(result['path']))
    lifecycle(state,repo)
    require(registry()==profile,'installed fixture profile moved')
    return {'fixture_id':FIXTURE,'source':identity,'descriptor_sha256':sha(canonical(envelope)),
            'admission_sha256':envelope['admission_sha256'],'runtime_receipt_sha256':envelope['runtime_receipt_sha256'],
            'output':result,'audit_only':True,'process_execution_authorized':False}


def main(argv):
    try:
        if argv==['generated-select']:
            return 0 if select(sys.stdin.buffer.read(8193)) else 1
        require(len(argv)==2 and argv[0]=='generated-preaction')
        state_bytes=read(pathname(argv[1]),16<<20,private=True)
        state=decode(state_bytes,16<<20)
        result=validate(decode(sys.stdin.buffer.read(8193)),state)
        require(read(pathname(argv[1]),16<<20,private=True)==state_bytes,'native lifecycle changed during validation')
        # Existing gate state_record_override persists immutable binding evidence;
        # no new token, lifecycle mutation or consumption ledger is created.
        print(json.dumps(result,sort_keys=True,separators=(',',':')))
        return 0
    except Exception:
        print('generated-definition-action: bounded consistency refused',file=sys.stderr)
        return 1
