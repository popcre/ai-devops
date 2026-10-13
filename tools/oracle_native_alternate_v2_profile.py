#!/usr/bin/env python3
"""Closed Oracle metadata-only admission; captures are never read here.

Only a genuine independent prospective native completion containing BOTH scoped
lines registers this new conditional local purpose. Advisory reviews, hashes,
booleans and expired source/worker permits cannot register it. This is not a
qualified source, SourceRef, provider or hosting permission issuer.
"""
import argparse
from datetime import datetime
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile
import time
import fcntl

ROOT=Path(__file__).resolve().parents[1]
PROFILE='oracle-native-alternate-serialization-v2'
ACTION='offline-private-capture-transform'
PURPOSE='native-alternate-serialization'
CENSUS={'original_uploads':26,'native_groups':8,'native_pages':33,
    'completion_sha256':'8ae0e0182324b563b10d5acb2c43a87adf677c3933d35ee8ffa8a3513befc74c',
    'operator_sha256':'8fc05bea47c07034d90f294665b73f0293cf1b51fb1644c9f8cd93afbdcf9175',
    'configuration_sha256':'4c6bf1a32ffe26894e99c76440f20eda19faa58318851d0f5444058dbb82d681',
    'custody_sha256':'79bd96fa3a837a702ad283dc2f1f613dce4de6f2f1a8801f0e11e05ede53b0ca'}
CONTROL_HASHES={'completion':CENSUS['completion_sha256'],'configuration':CENSUS['configuration_sha256'],
    'producer':CENSUS['operator_sha256'],'custody':CENSUS['custody_sha256'],
    'original_manifest':'59b92c2b28d629732f5e5fb5895325d636173c7fc2ff7e84158f6f98f8fc6a7e',
    'group_inventory':'b236778237d7c0c64c8cb73995b8d7430493e492a3c28a357e0efc24bdd26bfe',
    'page_skeleton':'f650543d3d6d6fcf0b24da3ff5d9bc839d657aac9350c719ad847056eb0509d7'}
CONTROL_ROLES=list(CONTROL_HASHES)+['group-'+str(i)+'-manifest.json' for i in range(8)]
LIMITS={'input_bytes':256*1024**2,'output_bytes':256*1024**2,'per_file_bytes':8*1024**2,'workers':1,'threads':2,
        'address_space_bytes':8*1024**3,'cpu_seconds':120,'wall_seconds':180,'network':'none'}
FIELDS={'schema_version','profile','purpose','action_id','source_head','source_digest','observed_at','expires_at',
        'permission_custody','captures','controls','output_parent','output_leaf','runtime','limits','census'}
STAT_FIELDS={'dev','ino','uid','mode','size','mtime_ns','ctime_ns'}

spec=importlib.util.spec_from_file_location('oracle_control',ROOT/'tools/oracle_native_alternate_control.py')
control_metadata=importlib.util.module_from_spec(spec);spec.loader.exec_module(control_metadata)

def require(condition,reason):
    if not condition:raise ValueError(reason)


def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=True,allow_nan=False).encode()
def sha(raw):return hashlib.sha256(raw).hexdigest()
def unique(pairs):
    result={}
    for k,v in pairs:
        require(k not in result,'duplicate control field');result[k]=v
    return result
def decode(raw):
    require(len(raw)<=1024**2,'metadata exceeds bound')
    return json.loads(raw,object_pairs_hook=unique,parse_constant=lambda _:(_ for _ in ()).throw(ValueError('nonfinite metadata')))
def legacy():
    spec=importlib.util.spec_from_file_location('oracle_profile_legacy',ROOT/'tools/review_action_profile.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module
def metadata(path):
    require(Path(path).name=='oracle-native-action-v2.manifest.json','dedicated metadata control required')
    return control_metadata.read_descriptor(path,PROFILE,legacy()._native.private_read,decode)


def descriptor_stat(path,directory=False):
    """O_PATH/fstat only: no file content open/hash before independent admission."""
    path=Path(path)
    require(path.is_absolute() and '..' not in path.parts,'unsafe custody identity')
    fd=os.open(path.anchor,os.O_PATH|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:
        for part in path.parts[1:]:
            new=os.open(part,os.O_PATH|os.O_NOFOLLOW,dir_fd=fd);os.close(fd);fd=new
            require(not stat.S_ISLNK(os.fstat(fd).st_mode),'linked custody identity')
        info=os.fstat(fd)
        require((stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode)),'nonregular custody identity')
        require(info.st_uid==os.getuid() and stat.S_IMODE(info.st_mode)==(0o700 if directory else 0o600),'owned private custody required')
        if not directory:require(info.st_nlink==1,'aliased capture inode refused')
        return dict(dev=info.st_dev,ino=info.st_ino,uid=info.st_uid,mode=stat.S_IMODE(info.st_mode),
                    size=info.st_size,mtime_ns=info.st_mtime_ns,ctime_ns=info.st_ctime_ns)
    finally:os.close(fd)


def public_runtime_module():
    spec=importlib.util.spec_from_file_location('oracle_public_runtime',ROOT/'tools/oracle_native_alternate_v2_runtime.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module

def public_bwrap_identity(expected=None):return public_runtime_module().public_tool_identity('bwrap',expected)

def validate_lock_fd(fd):
    info=os.fstat(fd)
    require(stat.S_ISREG(info.st_mode) and info.st_uid==os.getuid() and stat.S_IMODE(info.st_mode)==0o600 and info.st_nlink==1,'native receipt lock is unsafe')

def approval_summary(state):
    return 'APPROVE by '+state['provider']+' (implementer '+state['implementer_engine']+', run '+state['run_id']+', '+state['review_mode']+') for '+ACTION+' at '+state['head']+' report sha256:'+state['report_sha256']

def has_exact_task_override(task,state):
    return any(isinstance(r,dict) and r.get('kind')=='reviewer-approval' and r.get('action')==ACTION and r.get('observed_class')=='private-tooling' and r.get('reason')==approval_summary(state) for r in task.get('overrides',[]))

def profile():
    raw=(ROOT/'config/review-action-profiles.json').read_bytes();value=decode(raw)['profiles'][PROFILE]
    require(value['repository']=='https://github.com/u2giants/theoracle' and value['action']==ACTION
            and value['required_gate']=='oracle-native-alternate-v2-descriptor-only-admission' and value['manifest_schema_version']==2 and value['purpose']==PURPOSE and value['limits']==LIMITS and value['input_format']=='historical-custom-native-pages-chain-v2' and value['capture_count']==33 and value['control_count']==15,'installed closed profile differs')
    require(sha(canonical(value['paths']))==value['path_set_sha256'],'complete public closure differs')
    return value,sha(raw)


def validate_manifest(m,now):
    require(type(m) is dict and set(m)==FIELDS and type(m['schema_version']) is int and m['schema_version']==2 and m['profile']==PROFILE
            and m['purpose']==PURPOSE and m['limits']==LIMITS and m['census']==CENSUS,'closed metadata contract differs')
    require(type(m['source_head']) is str and re.fullmatch('[a-f0-9]{40}',m['source_head']) and type(m['source_digest']) is str and re.fullmatch('[a-f0-9]{64}',m['source_digest']),'exact public source identity required')
    require(re.fullmatch('[a-f0-9]{32}',m['action_id'] or '') is not None,'fixed action identity required')
    require(type(m['observed_at']) is int and type(m['expires_at']) is int
            and 0<=now-m['observed_at']<=600 and now+180<=m['expires_at']<=m['observed_at']+900,'current bounded purpose required')
    custody=m['permission_custody']
    require(type(custody) is dict and set(custody)=={'current_contract_metadata_sha256','historical_capture_sha256',
        'current_owner','requires_external_registrar','external_registration_sha256','observed_at','expires_at'},'applicable custody contract required')
    require(type(custody['observed_at']) is int and type(custody['expires_at']) is int
            and 0<=now-custody['observed_at']<=600 and custody['expires_at']>=m['expires_at'],'custody contract stale')
    require(isinstance(custody['current_owner'],str) and bool(custody['current_owner']),'actual custodian identity required')
    for key in ('current_contract_metadata_sha256','historical_capture_sha256'):
        require(isinstance(custody[key],str) and re.fullmatch('[a-f0-9]{64}',custody[key]),'contract commitment required')
    # No fabricated external registrar/signature. A separately required actual
    # license/custodian registration must be resolved through its own contract.
    require(custody['requires_external_registrar'] is False and custody['external_registration_sha256'] is None,
            'applicable external custodian registration needs its supported verifier')
    require(type(m['controls']) is list and len(m['controls'])==15 and [c['role'] for c in m['controls']]==CONTROL_ROLES,'fixed historical control closure required')
    require(type(m['captures']) is list and len(m['captures'])==33,'fixed captured page census required')
    names=[c['role'] for c in m['captures']]
    require(len(set(names))==33 and all(type(n) is str and re.fullmatch(r'group-[0-7]-page-[1-9][0-9]*\.json',n) for n in names),'fixed custom page identities required')
    require(names==sorted(names,key=lambda n:tuple(map(int,re.findall(r'[0-9]+',n)))),'canonical group/page input order required')
    seen=set();total=0
    for item in m['controls']+m['captures']:
        require(type(item) is dict and set(item)=={'path','commitment','role','stat'},'capture descriptor schema differs')
        require(set(item['stat'])==STAT_FIELDS and all(type(v) is int for v in item['stat'].values()),'capture stat commitment differs')
        commitment=item['commitment'];role=item['role']
        require(type(commitment) is dict,'typed input commitment required')
        require(type(item['path']) is str,'fixed path identity required')
        if role not in CONTROL_HASHES:require(Path(item['path']).name==role,'fixed child role/path basename required')
        if role in CONTROL_HASHES:
            require(commitment=={'kind':'fixed-sha256','sha256':CONTROL_HASHES[role]},'exact public root commitment required')
        else:
            parent='completion' if role in CONTROL_ROLES else 'group-'+role.split('-')[1]+'-manifest.json'
            require(commitment=={'kind':'verified-parent','parent_role':parent,'child_role':role},'fixed verified-parent commitment required')
        actual=descriptor_stat(item['path']);require(actual==item['stat'],'capture custody moved')
        inode=(actual['dev'],actual['ino']);require(inode not in seen,'duplicate input inode');seen.add(inode)
        require(descriptor_stat(str(Path(item['path']).parent),True)['mode']==0o700,'private input parent required')
        require(0<actual['size']<=8*1024**2,'per-file input exceeds bound')
        total+=actual['size'];require(total<=LIMITS['input_bytes'],'aggregate input exceeds bound')
    parent=m['output_parent'];require(set(parent)=={'path','stat'} and descriptor_stat(parent['path'],True)==parent['stat'],'output parent moved')
    require(isinstance(m['output_leaf'],str) and re.fullmatch('[a-z0-9-]{1,80}',m['output_leaf']),'fresh output leaf required')
    output=Path(parent['path'])/m['output_leaf'];require(not output.exists() and not output.is_symlink(),'output already exists')
    runtime=m['runtime'];require(set(runtime)=={'root','closure_sha256','bytes','bwrap','bwrap_sha256'},'fixed runtime descriptor required')
    require(type(runtime['bytes']) is int and runtime['bytes']>0 and total+runtime['bytes']<=LIMITS['input_bytes'],'runtime plus inputs exceed bound')
    require(runtime['bwrap']=='/usr/bin/bwrap','only fixed public OS sandbox executable is supported')
    sandbox_identity=public_bwrap_identity(runtime['bwrap_sha256'])
    recipe=public_runtime_module().verify_recipe(runtime['root'])
    require(recipe['closure_sha256']==runtime['closure_sha256'] and recipe['bytes']==runtime['bytes'],'actual public runtime differs from descriptor')
    require(re.fullmatch('[a-f0-9]{64}',runtime['closure_sha256']) and re.fullmatch('[a-f0-9]{64}',runtime['bwrap_sha256']),'runtime identity required')
    return {'claimed_input_set_sha256':sha(canonical([{k:v for k,v in c.items() if k!='path'} for c in m['controls']+m['captures']])),
            'capture_stat_sha256':sha(canonical([c['stat'] for c in m['controls']+m['captures']])),
            'manifest_schema_version':2,'root_sha256':CONTROL_HASHES,'verified_parent_commitment_count':41,'capture_count':len(m['captures']),'capture_bytes':total,'capture_byte_hashes_verified':False,
            'runtime_identity':{'closure_sha256':runtime['closure_sha256'],'bytes':runtime['bytes'],'sandbox_binary':sandbox_identity,'public_os_origin_set_sha256':recipe['public_os_origin_set_sha256'],'ldd_identity':recipe['ldd_identity']},'limits':LIMITS,'input_format':'historical-custom-native-pages-chain-v2'}


def binding(state,m):
    p,pdigest=profile();old=legacy()
    if os.environ.get('AI_DEVOPS_TEST_MODE')!='1':
        require(not any(os.environ.get(k) for k in ('AI_TASK_GATES_FILE','AI_TASK_GATES_CONSUMER_FILE',
            'AI_REVIEW_ACTION_PROFILES_FILE','AI_REVIEW_NATIVE_EXPORT_ROOT')),'native policy substitution refused')
    require(state['normalized_upstream']==p['repository'] and state['provider']=='deepseek'
        and state['implementer_engine'].lower()!='deepseek' and state['review_mode'] in ('final-check','security-review'),'independent exact Oracle review required')
    exported=old._native.validate_snapshot(Path(state['code_only_export']),state['head'])
    require(exported==state['code_only'] and exported['paths']==p['paths'],'full public decoder/operator closure required')
    require(m['source_head']==state['head'] and m['source_digest']==state['source_digest'],'source moved')
    repo=Path(state['repository_root'])
    require(set(p['code_sha256'])=={'scripts/oracle2/native_alternate_chain_operator.py','services/oracle-brain/oracle_brain/operating_model/native_page_chain.py','services/oracle-brain/oracle_brain/operating_model/native_page_alternate.py'},'fixed three-code closure required')
    require(p['public_contract_sha256']=='f4e0c71e1caf00b7c06a238af246c9d9947d3635b5f036bd5354e6f1a006a60e' and sha(old.git(repo,'show',state['head']+':scripts/oracle2/contracts/native_alternate_chain_v2.json'))==p['public_contract_sha256'],'fixed public contract differs')
    for path,digest in p['code_sha256'].items():require(sha(old.git(repo,'show',state['head']+':'+path))==digest,'frozen public code pin differs')
    explanation=decode(subprocess.check_output([str(ROOT/'bin/ai-task-gates'),'explain','--json'],cwd=repo))
    require(explanation['repository']=='u2giants/theoracle' and explanation['declared_class']=='private-tooling'
        and explanation['effective_class']=='private-tooling','truthful Oracle private-tooling task required')
    local=decode(old.git(repo,'show',state['head']+':.ai-devops/task-gates.json'))
    require('oracle-native-alternate-v2-descriptor-only-admission' in local['gates']['private-tooling']['required'],
            'committed Oracle opt-in required')
    facts=validate_manifest(m,int(time.time()));installed=old.installed_enforcement()
    public={path:sha((ROOT/path).read_bytes()) for path in ('tools/oracle_native_alternate_v2_profile.py',
        'tools/oracle_native_alternate_v2_guardian.py','tools/oracle_native_alternate_v2_runtime.py','bin/ai-oracle-native-alternate-v2','tools/oracle_native_alternate_output.py','tools/oracle_native_alternate_control.py')}
    if installed['kind']=='VERIFIED_INSTALLED_SOURCE':
        for path,digest in public.items():require(sha(old.git(ROOT,'show',installed['source_head']+':'+path))==digest,'installed Oracle guard differs')
    return {'profile':PROFILE,'profile_sha256':pdigest,'action':ACTION,'purpose':PURPOSE,
        'manifest_descriptor_sha256':sha(canonical(m)),'permission_registration_descriptor_sha256':sha(canonical({'schema_version':2,'profile':PROFILE,'permission_custody':m['permission_custody'],'manifest_descriptor_sha256':sha(canonical(m))})),
        'source_head':state['head'],'source_digest':state['source_digest'],'path_set_sha256':p['path_set_sha256'],
        'root_action_authority':False,'entrypoint':p['entrypoint'],'installed_enforcement':installed,
        'oracle_enforcement_sha256':public,**facts}


def exact_purpose_line(content,b):
    expected='Purpose registration: '+PROFILE+' descriptor sha256:'+b['permission_registration_descriptor_sha256']
    lines=[line for line in content.splitlines() if line.lstrip().startswith('Purpose registration:')]
    return len(lines)==1 and lines[0] in (expected,expected+'.')


def completed(state_path,state,b):
    require(state.get('status')=='completed' and state.get('verdict')=='APPROVE' and state.get('stale') is False
        and state.get('failure_class') is None,'current completed approval required')
    require(b['installed_enforcement']['kind']=='VERIFIED_INSTALLED_SOURCE','test fixture cannot issue authority')
    finished=datetime.fromisoformat(state['finished_at'].replace('Z','+00:00'))
    require(finished.tzinfo is not None and 0<=time.time()-finished.timestamp()<=300,'native approval start window expired')
    control_metadata.lifecycle(state_path)
    old=legacy();proc=subprocess.run([sys.executable,str(ROOT/'bin/ai-review-code-only.py'),'lifecycle-proof',
        str(state_path),state['session_id'],state['report_path'],'--completed'],capture_output=True)
    require(proc.returncode==0 and decode(proc.stdout)==state['code_only_completion'],'genuine independent native completion required')
    report=old._native.private_read(Path(state['report_path'])).decode()
    require(sha(report.encode())==state['report_sha256'] and old._native.has_exact_action_scope(report,b)
        and exact_purpose_line(report,b),'dual exact independent scopes required')
    return {'kind':'native-independent-current-purpose-registration','profile':PROFILE,'purpose':PURPOSE,
        'descriptor_sha256':b['permission_registration_descriptor_sha256'],'action_descriptor_sha256':b['manifest_descriptor_sha256'],
        'source_head':state['head'],'source_digest':state['source_digest'],'provider':state['provider'],
        'implementer_engine':state['implementer_engine'],'native_completion_sha256':sha(canonical(state['code_only_completion'])),
        'report_sha256':state['report_sha256'],'conditional_unqualified_serialization_only':True,
        'qualified_source_authority':False,'source_ref_authority':False,'provider_authority':False,'hosted_authority':False}


def atomic_receipt(state_path,state,b,m,publish):
    reg=completed(state_path,state,b)
    if not publish:return reg
    require(os.environ.get('AI_DEVOPS_TEST_MODE')!='1','test mode cannot issue actual authority')
    lock=os.open(str(state_path)+'.oracle.lock',os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
    try:
        validate_lock_fd(lock)
        fcntl.flock(lock,fcntl.LOCK_EX);old=legacy();current=decode(control_metadata.read_lifecycle(state_path,old._native.private_read))
        require(current==state,'lifecycle moved during registration')
        finished=int(datetime.fromisoformat(state['finished_at'].replace('Z','+00:00')).timestamp())
        expected={'schema_version':2,'registration':reg,'binding':b,'action_id':m['action_id'],
                  'issued_at':finished,'expires_at':min(m['expires_at'],finished+300)}
        key='oracle_alternate_v2_action_admission'
        if key in current:require(current[key]==expected,'admission collision');return reg
        # Task gate has already independently recorded the exact approval.
        identity=sha(('u2giants/theoracle'+'\0'+state['repository_root']).encode())
        task_dir=Path(os.environ.get('AI_TASK_GATES_DIR',str(Path.home()/'.local/state/ai-devops/task-gates')))
        task=decode(old._native.private_read(task_dir/(identity+'.json')))
        require(has_exact_task_override(task,state),'native gate approval was not persisted exactly')
        current[key]=expected
        fd,temp=tempfile.mkstemp(dir=Path(state_path).parent,prefix='.oracle-admission-')
        with os.fdopen(fd,'wb') as out:out.write(canonical(current)+b'\n');out.flush();os.fsync(out.fileno())
        os.replace(temp,state_path)
        parent=os.open(Path(state_path).parent,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
        try:os.fsync(parent)
        finally:os.close(parent)
        return reg
    finally:os.close(lock)


def evidence_projection(b):
    return {'schema_version':2,'evidence_kind':'oracle-v2-stat-only-parent-chain-action-commitment',
        'action_authorized':False,'capture_byte_hashes_verified':False,'private_values_disclosed':False,
        **{k:b[k] for k in ('profile','action','purpose','manifest_descriptor_sha256','permission_registration_descriptor_sha256',
            'manifest_schema_version','root_sha256','verified_parent_commitment_count','capture_count','capture_bytes','path_set_sha256','source_head','source_digest','oracle_enforcement_sha256','runtime_identity','limits','input_format')}}

def prompt(state):
    require(type(state) is dict and type(state.get('action_profile_binding')) is dict,'invalid lifecycle action binding')
    b=state['action_profile_binding']
    require(b['profile']==PROFILE,'foreign profile prompt refused')
    return ('Review ONLY Oracle offline native-alternate serialization. Metadata/custody/stat and claimed historical hashes were checked; '
        'seven root SHA pins and 41 typed parent-chain commitments were bound; capture bytes were NOT read or hash-verified. Only genuine independent native completion may register this current bounded purpose. '
        'Applicable owner/license/custodian requirements remain mandatory; withhold approval if they are not established. '
        'No old permit renewal, model/network/database/SourceRef/adoption/hosting rights. Require exact closure, one-use consumption before reads, '
        'networkless fixed bounds and explicit schema refusal. If approving include both unique standalone lines:\n'
        'Purpose registration: '+PROFILE+' descriptor sha256:'+b['permission_registration_descriptor_sha256']+'\n'
        'Action scope: '+PROFILE+' descriptor sha256:'+b['manifest_descriptor_sha256'])


def main(argv=None):
    parser=argparse.ArgumentParser();parser.add_argument('phase',choices=('capture','evidence','finish','preaction','prompt'))
    parser.add_argument('state');parser.add_argument('--manifest');parser.add_argument('--profile',default=PROFILE)
    parser.add_argument('--stage',default='initial-forward');parser.add_argument('--admit',action='store_true');args=parser.parse_args(argv)
    try:
        require(args.profile==PROFILE and args.stage=='initial-forward','fixed Oracle stage required')
        state=decode(control_metadata.read_lifecycle(args.state,legacy()._native.private_read))
        require(type(state) is dict and (args.phase=='capture' or type(state.get('action_profile_binding')) is dict),'invalid lifecycle action binding')
        if args.phase=='prompt':print(prompt(state));return 0
        require(state['status']=={'capture':'preflight','evidence':'running','finish':'running','preaction':'completed'}[args.phase],'wrong native phase')
        m=metadata(args.manifest) if args.manifest else decode(sys.stdin.buffer.read(1024**2+1));b=binding(state,m)
        if args.phase!='capture':require(b==state['action_profile_binding'],'action metadata or source moved')
        if args.phase=='preaction':atomic_receipt(args.state,state,b,m,args.admit)
        if args.phase=='evidence':b=evidence_projection(b)
        print(json.dumps(b,sort_keys=True));return 0
    except (OSError,ValueError,KeyError,TypeError,RecursionError,subprocess.SubprocessError):
        print('oracle-native-alternate: bounded native metadata admission refused',file=sys.stderr);return 1


if __name__=='__main__':sys.exit(main())
