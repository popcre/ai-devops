#!/usr/bin/env python3
"""Closed Oracle metadata-only admission; captures are never read here.

The admission is descriptor-only (#2041, owner rulings 2026-10-29): it binds
the exact committed Oracle source, the private-tooling opt-in, the stat-only
custody descriptor and the installed enforcement. No reviewer verdict is
required or read; an AI review of the action is optional advisory evidence.
This is not a qualified source, SourceRef, provider or hosting permission issuer.
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
PROFILE='oracle-native-alternate-serialization-v1'
ACTION='offline-private-capture-transform'
ADMISSION_SCHEMA=1
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
    require(Path(path).name=='oracle-native-action.manifest.json','dedicated metadata control required')
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
    spec=importlib.util.spec_from_file_location('oracle_public_runtime',ROOT/'tools/oracle_native_alternate_runtime.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module

def public_bwrap_identity(expected=None):return public_runtime_module().public_tool_identity('bwrap',expected)

def validate_lock_fd(fd):
    info=os.fstat(fd)
    require(stat.S_ISREG(info.st_mode) and info.st_uid==os.getuid() and stat.S_IMODE(info.st_mode)==0o600 and info.st_nlink==1,'native receipt lock is unsafe')

def profile():
    raw=(ROOT/'config/review-action-profiles.json').read_bytes();value=decode(raw)['profiles'][PROFILE]
    require(value['repository']=='https://github.com/u2giants/theoracle' and value['action']==ACTION
            and value['purpose']==PURPOSE and value['limits']==LIMITS and value['input_format']=='historical-custom-native-pages-v1' and value['capture_count']==33 and value['control_count']==15,'installed closed profile differs')
    require(sha(canonical(value['paths']))==value['path_set_sha256'],'complete public closure differs')
    return value,sha(raw)


def validate_manifest(m,now):
    require(type(m) is dict and set(m)==FIELDS and m['schema_version']==1 and m['profile']==PROFILE
            and m['purpose']==PURPOSE and m['limits']==LIMITS and m['census']==CENSUS,'closed metadata contract differs')
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
    require(len(set(names))==33 and all(re.fullmatch(r'group-[0-7]-page-[1-9][0-9]*\.json',n) for n in names),'fixed custom page identities required')
    seen=set();total=0
    for item in m['controls']+m['captures']:
        require(type(item) is dict and set(item)=={'path','sha256','role','stat'},'capture descriptor schema differs')
        require(set(item['stat'])==STAT_FIELDS and all(type(v) is int for v in item['stat'].values()),'capture stat commitment differs')
        require(isinstance(item['sha256'],str) and re.fullmatch('[a-f0-9]{64}',item['sha256']),'claimed historical hash required')
        if item['role'] in CONTROL_HASHES:require(item['sha256']==CONTROL_HASHES[item['role']],'historical control commitment differs')
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
            'capture_count':len(m['captures']),'capture_bytes':total,'capture_byte_hashes_verified':False,
            'runtime_identity':{'closure_sha256':runtime['closure_sha256'],'bytes':runtime['bytes'],'sandbox_binary':sandbox_identity,'public_os_origin_set_sha256':recipe['public_os_origin_set_sha256'],'ldd_identity':recipe['ldd_identity']},'limits':LIMITS,'input_format':'historical-custom-native-pages-v1'}


def binding(state,m):
    p,_=profile();old=legacy();substitution_guard()
    # Optional advisory review evidence only: binds what the reviewer sees.
    require(state['normalized_upstream']==p['repository'],'exact Oracle repository required')
    exported=old._native.validate_snapshot(Path(state['code_only_export']),state['head'])
    require(exported==state['code_only'] and exported['paths']==p['paths'],'full public decoder/operator closure required')
    return _bind(Path(state['repository_root']),state['head'],state['source_digest'],m)


def substitution_guard():
    if os.environ.get('AI_DEVOPS_TEST_MODE')!='1':
        require(not any(os.environ.get(k) for k in ('AI_TASK_GATES_FILE','AI_TASK_GATES_CONSUMER_FILE',
            'AI_REVIEW_ACTION_PROFILES_FILE','AI_REVIEW_NATIVE_EXPORT_ROOT')),'native policy substitution refused')


def admission_binding(repo,m):
    """Descriptor-only binding of the exact clean committed Oracle source."""
    substitution_guard();p,_=profile();old=legacy();repo=Path(repo)
    require(repo.is_absolute() and repo.resolve()==repo,'canonical repository root required')
    proc=subprocess.run([str(ROOT/'bin/ai-review-lifecycle'),'identity',str(repo)],capture_output=True,timeout=30)
    require(proc.returncode==0,'source identity unavailable');ident=decode(proc.stdout)
    require(ident['repository_root']==str(repo) and ident['normalized_upstream']==p['repository'],'exact Oracle repository required')
    require(ident['working_tree_sha256']==sha(b''),'clean committed Oracle source required')
    for path in p['paths']:old.git(repo,'cat-file','-e',ident['head']+':'+path)
    return _bind(repo,ident['head'],ident['source_digest'],m)


def _bind(repo,head,src_digest,m):
    p,pdigest=profile();old=legacy()
    require(m['source_head']==head and m['source_digest']==src_digest,'source moved')
    explanation=control_metadata.gate_explanation(repo,decode)
    require(explanation['repository']=='u2giants/theoracle' and explanation['declared_class']=='private-tooling'
        and explanation['effective_class']=='private-tooling','truthful Oracle private-tooling task required')
    local=decode(old.git(repo,'show',head+':.ai-devops/task-gates.json'))
    require('oracle-native-alternate-descriptor-only-admission' in local['gates']['private-tooling']['required'],
            'committed Oracle opt-in required')
    facts=validate_manifest(m,int(time.time()));installed=old.installed_enforcement()
    public={path:sha((ROOT/path).read_bytes()) for path in ('tools/oracle_native_alternate_profile.py',
        'tools/oracle_native_alternate_guardian.py','tools/oracle_native_alternate_runtime.py','bin/ai-oracle-native-alternate','tools/oracle_native_alternate_output.py','tools/oracle_native_alternate_control.py')}
    if installed['kind']=='VERIFIED_INSTALLED_SOURCE':
        for path,digest in public.items():require(sha(old.git(ROOT,'show',installed['source_head']+':'+path))==digest,'installed Oracle guard differs')
    return {'profile':PROFILE,'profile_sha256':pdigest,'action':ACTION,'purpose':PURPOSE,
        'manifest_descriptor_sha256':sha(canonical(m)),'permission_registration_descriptor_sha256':sha(canonical(m['permission_custody'])),
        'source_head':head,'source_digest':src_digest,'path_set_sha256':p['path_set_sha256'],
        'root_action_authority':False,'entrypoint':p['entrypoint'],'installed_enforcement':installed,
        'oracle_enforcement_sha256':public,**facts}


def admission(repo,m,publish,advisory_report_sha256=None):
    """Issue the one-use descriptor-only admission; no reviewer verdict is read."""
    b=admission_binding(repo,m);now=int(time.time())
    if advisory_report_sha256 is not None:
        require(isinstance(advisory_report_sha256,str) and re.fullmatch('[a-f0-9]{64}',advisory_report_sha256),'advisory report digest malformed')
    record={'schema_version':ADMISSION_SCHEMA,'kind':'descriptor-only-admission','profile':PROFILE,'action':ACTION,'purpose':PURPOSE,
        'action_id':m['action_id'],'repository_root':str(repo),'binding':b,'issued_at':now,'expires_at':min(m['expires_at'],now+300),
        'reviewer_verdict_required':False,'advisory_review_report_sha256':advisory_report_sha256,
        'conditional_unqualified_serialization_only':True,'qualified_source_authority':False,'source_ref_authority':False,
        'provider_authority':False,'hosted_authority':False}
    if not publish:return record,None
    return record,control_metadata.publish_admission(record,PROFILE,canonical)


def evidence_projection(b):
    return {'schema_version':1,'evidence_kind':'oracle-stat-only-private-action-commitment',
        'action_authorized':False,'capture_byte_hashes_verified':False,'private_values_disclosed':False,
        **{k:b[k] for k in ('profile','action','purpose','manifest_descriptor_sha256','permission_registration_descriptor_sha256',
            'capture_count','capture_bytes','path_set_sha256','source_head','source_digest','oracle_enforcement_sha256','runtime_identity','limits','input_format')}}

def prompt(state):
    require(type(state) is dict and type(state.get('action_profile_binding')) is dict,'invalid lifecycle action binding')
    b=state['action_profile_binding']
    require(b.get('profile')==PROFILE,'foreign action profile prompt refused')
    return ('Review ONLY Oracle offline native-alternate serialization. Metadata/custody/stat and claimed historical hashes were checked; '
        'capture bytes were NOT read or hash-verified. This review is advisory only; admission never reads its verdict. '
        'Report any applicable owner/license/custodian requirement that is not established. '
        'No old permit renewal, model/network/database/SourceRef/adoption/hosting rights. Require exact closure, one-use consumption before reads, '
        'networkless fixed bounds and explicit schema refusal. Name the descriptor you reviewed:\n'
        'Purpose registration: '+PROFILE+' descriptor sha256:'+b['permission_registration_descriptor_sha256']+'\n'
        'Action scope: '+PROFILE+' descriptor sha256:'+b['manifest_descriptor_sha256'])


def main(argv=None):
    parser=argparse.ArgumentParser();parser.add_argument('phase',choices=('capture','evidence','finish','prompt','admit'))
    parser.add_argument('state',nargs='?');parser.add_argument('--manifest');parser.add_argument('--profile',default=PROFILE)
    parser.add_argument('--stage',default='initial-forward');parser.add_argument('--repo');parser.add_argument('--publish',action='store_true')
    parser.add_argument('--advisory-report-sha256');args=parser.parse_args(argv)
    try:
        require(args.profile==PROFILE and args.stage=='initial-forward','fixed Oracle stage required')
        if args.phase=='admit':
            require(args.state is None and args.repo,'admission takes --repo and descriptor stdin only')
            m=decode(sys.stdin.buffer.read(1024**2+1));require(type(m) is dict,'descriptor object required')
            record,path=admission(Path(args.repo),m,args.publish,args.advisory_report_sha256)
            print(json.dumps({'admission':None if path is None else str(path),'admission_sha256':sha(canonical(record)),
                'action_id':record['action_id'],'source_head':record['binding']['source_head'],
                'installed_enforcement':record['binding']['installed_enforcement']['kind'],'reviewer_verdict_required':False},sort_keys=True));return 0
        require(args.state is not None,'lifecycle state required')
        state=decode(control_metadata.read_lifecycle(args.state,legacy()._native.private_read))
        require(type(state) is dict and (args.phase=='capture' or type(state.get('action_profile_binding')) is dict),'invalid lifecycle action binding')
        if args.phase=='prompt':print(prompt(state));return 0
        require(state['status']=={'capture':'preflight','evidence':'running','finish':'running'}[args.phase],'wrong native phase')
        m=metadata(args.manifest) if args.manifest else decode(sys.stdin.buffer.read(1024**2+1));b=binding(state,m)
        if args.phase!='capture':require(b==state['action_profile_binding'],'action metadata or source moved')
        if args.phase=='evidence':b=evidence_projection(b)
        print(json.dumps(b,sort_keys=True));return 0
    except (OSError,ValueError,KeyError,TypeError,RecursionError,subprocess.SubprocessError):
        print('oracle-native-alternate: bounded native metadata admission refused',file=sys.stderr);return 1

if __name__=='__main__':sys.exit(main())
