#!/usr/bin/env python3
"""One native-approved action, consumed before ANY capture-content open.

No admission retry/renewal, arbitrary operator, network or broad host mount.
Actual runtime confinement requires supported Linux namespaces; refusal stops.
"""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import resource
import stat
import subprocess
import selectors
import sys
import time

sys.dont_write_bytecode=True
spec=importlib.util.spec_from_file_location('oracle_profile',Path(__file__).with_name('oracle_native_alternate_v2_profile.py'))
profile=importlib.util.module_from_spec(spec);spec.loader.exec_module(profile)
spec=importlib.util.spec_from_file_location('oracle_output',Path(__file__).with_name('oracle_native_alternate_output.py'))
output_checks=importlib.util.module_from_spec(spec);spec.loader.exec_module(output_checks)


def consume(state_path,state,m,b):
    profile.completed(state_path,state,b)
    receipt=state.get('oracle_alternate_v2_action_admission')
    profile.require(type(receipt) is dict and receipt.get('binding')==b and receipt.get('action_id')==m['action_id']
        and type(receipt.get('expires_at')) is int and int(time.time())+180<=receipt['expires_at']<=m['expires_at']
        and receipt.get('registration')==profile.completed(state_path,state,b),
        'actual current-purpose and action gate receipt required')
    profile.require(os.environ.get('AI_DEVOPS_TEST_MODE')!='1','test fixture cannot consume actual authority')
    spent=Path(state_path).parent/('oracle-alternate-v2-'+m['action_id']+'.spent')
    fd=os.open(spent,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,'wb') as out:
        out.write(profile.canonical({'action_id':m['action_id'],'binding_sha256':profile.sha(profile.canonical(b)),
            'consumed_at':int(time.time()),'outcome':'consumed-no-retry'}));out.flush();os.fsync(out.fileno())
    directory=os.open(spent.parent,os.O_DIRECTORY|os.O_RDONLY)
    try:os.fsync(directory)
    finally:os.close(directory)
    return spent


def public_runtime(root,expected,maximum):
    recipe=profile.public_runtime_module().verify_recipe(root)
    profile.require(recipe['closure_sha256']==expected and recipe['bytes']<=maximum,'complete runtime closure changed')
    return recipe['bytes']

def validate_sandbox_fds(code,captures):
    import fcntl
    profile.require(type(captures) is list and len(captures)==48,'fixed 48 input descriptors required')
    fds=list(code)+captures
    profile.require(all(type(fd) is int and fd>=3 for fd in fds) and len(set(fds))==len(fds),'distinct integer descriptors required')
    sealed=fcntl.F_SEAL_WRITE|fcntl.F_SEAL_GROW|fcntl.F_SEAL_SHRINK|fcntl.F_SEAL_SEAL
    for fd in code:
        info=os.fstat(fd)
        profile.require(stat.S_ISREG(info.st_mode) and info.st_uid==os.getuid() and fcntl.fcntl(fd,fcntl.F_GET_SEALS)==sealed,'sealed owned public code descriptor required')
    for fd in captures:
        info=os.fstat(fd)
        profile.require(stat.S_ISREG(info.st_mode) and info.st_uid==os.getuid() and info.st_nlink==1 and stat.S_IMODE(info.st_mode)==0o600 and fcntl.fcntl(fd,fcntl.F_GETFL)&os.O_ACCMODE==os.O_RDONLY,'held read-only private input descriptor required')


def sandbox_command(runtime,operator,decoder,chain,captures,output):
    code=(operator,decoder,chain);validate_sandbox_fds(code,captures)
    cmd=['/usr/bin/bwrap','--die-with-parent','--new-session','--unshare-all','--clearenv',
         '--ro-bind',runtime['root'],'/','--proc','/proc','--dev','/dev',
         '--ro-bind-data',str(operator),'/code/operator.py','--ro-bind-data',str(decoder),'/code/native_alternate.py',
         '--ro-bind-data',str(chain),'/code/native_chain.py',
         '--bind',output,'/output','--chdir','/','--setenv','OMP_NUM_THREADS','2','--setenv','OPENBLAS_NUM_THREADS','2']
    for i,fd in enumerate(captures):cmd+=['--ro-bind-fd',str(fd),'/input/c'+str(i)]
    return cmd+['/usr/bin/python3','-I','-S','/code/operator.py']


def validate_input_fd(fd,item):
    info=os.fstat(fd)
    actual=dict(dev=info.st_dev,ino=info.st_ino,uid=info.st_uid,mode=stat.S_IMODE(info.st_mode),size=info.st_size,mtime_ns=info.st_mtime_ns,ctime_ns=info.st_ctime_ns)
    profile.require(stat.S_ISREG(info.st_mode) and info.st_nlink==1 and actual==item['stat'],'full input custody changed after claim')

def revalidate_input_paths(inputs,fds):
    profile.require(type(inputs) is list and len(inputs)==48 and len(fds)==48,'fixed input closure changed')
    for item,fd in zip(inputs,fds):
        profile.require(profile.descriptor_stat(item['path'])==item['stat'],'input path custody changed before launch')
        profile.descriptor_stat(str(Path(item['path']).parent),True)
        validate_input_fd(fd,item)


def limits():
    resource.setrlimit(resource.RLIMIT_AS,(profile.LIMITS['address_space_bytes'],)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(profile.LIMITS['cpu_seconds'],)*2)
    resource.setrlimit(resource.RLIMIT_FSIZE,(profile.LIMITS['per_file_bytes'],)*2)
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    resource.setrlimit(resource.RLIMIT_NOFILE,(128,128))


def run(state_path,m):
    old=profile.legacy();state=profile.decode(old._native.private_read(Path(state_path)))
    b=profile.binding(state,m);profile.require(b==state.get('action_profile_binding'),'fixed prospective action binding required')
    # There is deliberately no ordinary/advisory/boolean authority path.
    spec=importlib.util.spec_from_file_location('oracle_public_runtime',Path(__file__).with_name('oracle_native_alternate_v2_runtime.py'))
    runtime_recipe=importlib.util.module_from_spec(spec);spec.loader.exec_module(runtime_recipe)
    recipe=runtime_recipe.verify_recipe(m['runtime']['root'])
    profile.require(recipe['closure_sha256']==m['runtime']['closure_sha256'] and recipe['bytes']==m['runtime']['bytes'],
                    'reviewed public-only runtime recipe differs')
    consume(state_path,state,m,b)
    profile.validate_manifest(m,int(time.time()))
    runtime=m['runtime'];total=public_runtime(runtime['root'],runtime['closure_sha256'],runtime['bytes'])
    profile.require(total==runtime['bytes'],'runtime size differs')
    profile.require(runtime['bwrap']=='/usr/bin/bwrap','only fixed public OS sandbox executable is supported')
    profile.public_bwrap_identity(runtime['bwrap_sha256'])
    repo=Path(state['repository_root']);p,_=profile.profile()
    operator=repo/p['entrypoint'];decoder=repo/'services/oracle-brain/oracle_brain/operating_model/native_page_alternate.py'
    chain=repo/'services/oracle-brain/oracle_brain/operating_model/native_page_chain.py'
    source_bytes=[]
    for path in (operator,decoder,chain):
        data=path.read_bytes()
        profile.require(data==old.git(repo,'show',state['head']+':'+str(path.relative_to(repo))), 'fixed source changed')
        source_bytes.append(data)
    output=Path(m['output_parent']['path'])/m['output_leaf'];output.mkdir(mode=0o700)
    output.chmod(0o700);output_fd=output_checks.open_directory(output);output_initial=os.fstat(output_fd)
    inputs=m['controls']+m['captures'];fds=[];source_fds=[]
    try:
        import fcntl
        for data in source_bytes:
            fd=os.memfd_create('oracle-reviewed-source',os.MFD_ALLOW_SEALING);source_fds.append(fd)
            with os.fdopen(os.dup(fd),'wb') as stream:stream.write(data)
            os.lseek(fd,0,os.SEEK_SET)
            fcntl.fcntl(fd,fcntl.F_ADD_SEALS,fcntl.F_SEAL_WRITE|fcntl.F_SEAL_GROW|fcntl.F_SEAL_SHRINK|fcntl.F_SEAL_SEAL)
        # First content-capable capture open happens AFTER the durable claim.
        for item in inputs:
            fd=os.open(item['path'],os.O_RDONLY|os.O_NOFOLLOW);fds.append(fd)
            validate_input_fd(fd,item)
        revalidate_input_paths(inputs,fds)
        control={'schema_version':2,'profile':profile.PROFILE,'purpose':profile.PURPOSE,'limits':profile.LIMITS,'census':profile.CENSUS,
            'inputs':[{k:v for k,v in item.items() if k!='path'} for item in inputs],
            'capture_count':len(m['captures']),'expires_at':min(m['expires_at'],state['oracle_alternate_v2_action_admission']['expires_at']),'runtime_bytes':total}
        started=time.monotonic();wall=time.time()
        # A sealed anonymous metadata fd avoids a blocking stdin write. Bound
        # stdout while reading it, rather than after unbounded communicate().
        control_fd=os.memfd_create('oracle-native-control',os.MFD_ALLOW_SEALING)
        os.write(control_fd,profile.canonical(control));os.lseek(control_fd,0,os.SEEK_SET)
        import fcntl
        fcntl.fcntl(control_fd,fcntl.F_ADD_SEALS,fcntl.F_SEAL_WRITE|fcntl.F_SEAL_GROW|fcntl.F_SEAL_SHRINK|fcntl.F_SEAL_SEAL)
        proc=None
        try:
            proc=subprocess.Popen(sandbox_command(runtime,*source_fds,fds,str(output)),
                stdin=control_fd,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,
                pass_fds=tuple(fds+source_fds),preexec_fn=limits,env={'PATH':'/usr/bin:/bin'})
            result=bytearray();selector=selectors.DefaultSelector();selector.register(proc.stdout,selectors.EVENT_READ)
            try:
                while selector.get_map():
                    profile.require(time.monotonic()-started<180 and time.time()<state['oracle_alternate_v2_action_admission']['expires_at'],'action deadline expired')
                    profile.require(profile.decode(old._native.private_read(Path(state_path)))==state,'purpose registration revoked during execution')
                    for key,_ in selector.select(.1):
                        chunk=os.read(key.fileobj.fileno(),2049-len(result))
                        if not chunk:selector.unregister(key.fileobj)
                        else:result.extend(chunk);profile.require(len(result)<=2048,'operator stdout exceeds bound')
            finally:selector.close()
            profile.require(proc.wait(timeout=2)==0,'isolated operator denied; spent attempt retained')
        finally:
            os.close(control_fd)
            if proc is not None and proc.poll() is None:proc.kill();proc.wait(timeout=2)
        profile.require(time.time()<m['expires_at'] and abs((time.time()-wall)-(time.monotonic()-started))<=2,'action clock moved')
        for item in inputs:profile.require(profile.descriptor_stat(item['path'])==item['stat'],'input moved during serialization')
        receipt=profile.decode(bytes(result))
        profile.require(set(receipt)=={'status','artifact_count','output_bytes','outputs_sha256','source_qualified','ledger_adopted','source_ref_issued','provider_authority','semantic_qualified'}
            and receipt['status']=='unqualified-native-alternate-v2' and receipt['source_qualified'] is False
            and receipt['ledger_adopted'] is False and receipt['source_ref_issued'] is False and receipt['provider_authority'] is False and receipt['semantic_qualified'] is False,'operator cannot qualify sources or adopt knowledge')
        output_checks.verify(output_fd,output_initial,receipt,profile.LIMITS)
        returned_fd=output_checks.open_directory(output)
        try:profile.require((os.fstat(returned_fd).st_dev,os.fstat(returned_fd).st_ino)==(output_initial.st_dev,output_initial.st_ino),'output path replaced before release')
        finally:os.close(returned_fd)
        profile.require(profile.decode(old._native.private_read(Path(state_path)))==state and time.time()<m['expires_at'],'registration changed before release')
        return receipt
    finally:
        for fd in fds+source_fds+[output_fd]:os.close(fd)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--state',required=True);args=parser.parse_args()
    try:
        m=profile.decode(sys.stdin.buffer.read(1024**2+1));print(json.dumps(run(args.state,m),sort_keys=True));return 0
    except (OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError):
        print('oracle-native-alternate: isolated action stopped; no retry or qualification',file=sys.stderr);return 1


if __name__=='__main__':sys.exit(main())
