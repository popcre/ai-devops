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
spec=importlib.util.spec_from_file_location('oracle_profile',Path(__file__).with_name('oracle_native_alternate_profile.py'))
profile=importlib.util.module_from_spec(spec);spec.loader.exec_module(profile)


def consume(state_path,state,m,b):
    profile.completed(state_path,state,b)
    receipt=state.get('oracle_alternate_action_admission')
    profile.require(type(receipt) is dict and receipt.get('binding')==b and receipt.get('action_id')==m['action_id']
        and type(receipt.get('expires_at')) is int and int(time.time())+180<=receipt['expires_at']<=m['expires_at']
        and receipt.get('registration')==profile.completed(state_path,state,b),
        'actual current-purpose and action gate receipt required')
    profile.require(os.environ.get('AI_DEVOPS_TEST_MODE')!='1','test fixture cannot consume actual authority')
    spent=Path(state_path).parent/('oracle-alternate-'+m['action_id']+'.spent')
    fd=os.open(spent,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,'wb') as out:
        out.write(profile.canonical({'action_id':m['action_id'],'binding_sha256':profile.sha(profile.canonical(b)),
            'consumed_at':int(time.time()),'outcome':'consumed-no-retry'}));out.flush();os.fsync(out.fileno())
    directory=os.open(spent.parent,os.O_DIRECTORY|os.O_RDONLY)
    try:os.fsync(directory)
    finally:os.close(directory)
    return spent


def public_runtime(root,expected,maximum):
    rows=[];total=0
    for folder,dirs,files in os.walk(root,followlinks=False):
        dirs.sort()
        for name in sorted(dirs+files):
            path=Path(folder)/name;info=path.lstat()
            profile.require(not path.is_symlink() and info.st_uid==os.getuid() and not info.st_mode&0o022,'immutable runtime custody required')
            if path.is_file():
                total+=info.st_size;profile.require(total<=maximum,'runtime byte bound exceeded')
                with path.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
                rows.append({'path':str(path.relative_to(root)),'bytes':info.st_size,'sha256':digest})
    profile.require(profile.sha(profile.canonical(rows))==expected,'complete runtime closure changed')
    return total


def sandbox_command(runtime,operator,decoder,captures,output):
    cmd=[runtime['bwrap'],'--die-with-parent','--new-session','--unshare-all','--clearenv',
         '--ro-bind',runtime['root'],'/','--proc','/proc','--dev','/dev',
         '--ro-bind',operator,'/code/operator.py','--ro-bind',decoder,'/code/native_alternate.py',
         '--bind',output,'/output','--chdir','/','--setenv','OMP_NUM_THREADS','2','--setenv','OPENBLAS_NUM_THREADS','2']
    for i,fd in enumerate(captures):cmd+=['--ro-bind','/proc/self/fd/'+str(fd),'/input/c'+str(i)]
    return cmd+['/usr/bin/python3','-I','-S','/code/operator.py']


def limits():
    resource.setrlimit(resource.RLIMIT_AS,(profile.LIMITS['address_space_bytes'],)*2)
    resource.setrlimit(resource.RLIMIT_CPU,(profile.LIMITS['cpu_seconds'],)*2)
    resource.setrlimit(resource.RLIMIT_FSIZE,(profile.LIMITS['output_bytes'],)*2)
    resource.setrlimit(resource.RLIMIT_CORE,(0,0))


def run(state_path,m):
    old=profile.legacy();state=profile.decode(old._native.private_read(Path(state_path)))
    b=profile.binding(state,m);profile.require(b==state.get('action_profile_binding'),'fixed prospective action binding required')
    # There is deliberately no ordinary/advisory/boolean authority path.
    spec=importlib.util.spec_from_file_location('oracle_public_runtime',Path(__file__).with_name('oracle_native_alternate_runtime.py'))
    runtime_recipe=importlib.util.module_from_spec(spec);spec.loader.exec_module(runtime_recipe)
    recipe=runtime_recipe.verify_recipe(m['runtime']['root'])
    profile.require(recipe['closure_sha256']==m['runtime']['closure_sha256'] and recipe['bytes']==m['runtime']['bytes'],
                    'reviewed public-only runtime recipe differs')
    consume(state_path,state,m,b)
    profile.validate_manifest(m,int(time.time()))
    runtime=m['runtime'];total=public_runtime(runtime['root'],runtime['closure_sha256'],runtime['bytes'])
    profile.require(total==runtime['bytes'],'runtime size differs')
    with open(runtime['bwrap'],'rb') as stream:
        profile.require(hashlib.file_digest(stream,'sha256').hexdigest()==runtime['bwrap_sha256'],'sandbox binary changed')
    repo=Path(state['repository_root']);p,_=profile.profile()
    operator=repo/p['entrypoint'];decoder=repo/'services/oracle-brain/oracle_brain/operating_model/native_alternate.py'
    source_bytes=[]
    for path in (operator,decoder):
        data=path.read_bytes()
        profile.require(data==old.git(repo,'show',state['head']+':'+str(path.relative_to(repo))), 'fixed source changed')
        source_bytes.append(data)
    output=Path(m['output_parent']['path'])/m['output_leaf'];output.mkdir(mode=0o700)
    inputs=m['captures']+[m['original_register']];fds=[];source_fds=[]
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
            info=os.fstat(fd)
            profile.require((info.st_dev,info.st_ino,info.st_size,info.st_mtime_ns,info.st_ctime_ns)==
                tuple(item['stat'][k] for k in ('dev','ino','size','mtime_ns','ctime_ns')),'input changed after claim')
        control={'profile':profile.PROFILE,'purpose':profile.PURPOSE,'limits':profile.LIMITS,'census':profile.CENSUS,
            'inputs':[{k:v for k,v in item.items() if k!='path'} for item in inputs],
            'capture_count':len(m['captures']),'expires_at':min(m['expires_at'],state['oracle_alternate_action_admission']['expires_at']),'runtime_bytes':total}
        started=time.monotonic();wall=time.time()
        # A sealed anonymous metadata fd avoids a blocking stdin write. Bound
        # stdout while reading it, rather than after unbounded communicate().
        control_fd=os.memfd_create('oracle-native-control',os.MFD_ALLOW_SEALING)
        os.write(control_fd,profile.canonical(control));os.lseek(control_fd,0,os.SEEK_SET)
        import fcntl
        fcntl.fcntl(control_fd,fcntl.F_ADD_SEALS,fcntl.F_SEAL_WRITE|fcntl.F_SEAL_GROW|fcntl.F_SEAL_SHRINK|fcntl.F_SEAL_SEAL)
        proc=None
        try:
            proc=subprocess.Popen(sandbox_command(runtime,'/proc/self/fd/'+str(source_fds[0]),'/proc/self/fd/'+str(source_fds[1]),fds,str(output)),
                stdin=control_fd,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,
                pass_fds=tuple(fds+source_fds),preexec_fn=limits,env={'PATH':'/usr/bin:/bin'})
            result=bytearray();selector=selectors.DefaultSelector();selector.register(proc.stdout,selectors.EVENT_READ)
            try:
                while selector.get_map():
                    profile.require(time.monotonic()-started<180 and time.time()<state['oracle_alternate_action_admission']['expires_at'],'action deadline expired')
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
        profile.require(set(receipt)=={'status','artifact_count','output_bytes','outputs_sha256','source_qualified','ledger_adopted'}
            and receipt['status']=='unqualified-native-alternate-v1' and receipt['source_qualified'] is False
            and receipt['ledger_adopted'] is False,'operator cannot qualify sources or adopt knowledge')
        return receipt
    finally:
        for fd in fds+source_fds:os.close(fd)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--state',required=True);args=parser.parse_args()
    try:
        m=profile.decode(sys.stdin.buffer.read(1024**2+1));print(json.dumps(run(args.state,m),sort_keys=True));return 0
    except (OSError,ValueError,KeyError,TypeError,subprocess.SubprocessError):
        print('oracle-native-alternate: isolated action stopped; no retry or qualification',file=sys.stderr);return 1


if __name__=='__main__':sys.exit(main())
