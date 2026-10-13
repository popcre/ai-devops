"""Closed metadata-control paths, validated without opening file content.

These namespaces contain platform lifecycle metadata or fresh descriptors only.
They issue no permission and never admit a capture path as a control argument.
"""
import hashlib
import importlib.util
import json
import subprocess
import time
from urllib.parse import urlsplit
import os
from pathlib import Path
import pwd
import re
import stat

PROFILES=('oracle-native-alternate-serialization-v1','oracle-native-alternate-serialization-v2')
KEY=hashlib.sha256(b'https://github.com/u2giants/theoracle').hexdigest()
TAG=re.compile(r'code-only-[1-9][0-9]*-[1-9][0-9]*-[0-9]+\.json')


def require(value,reason):
    if not value:raise ValueError(reason)


def canonical_path(value):
    require(isinstance(value,(str,Path)),'control path type refused')
    raw=str(value);path=Path(raw)
    require(path.is_absolute() and str(path)==raw and '..' not in path.parts,'noncanonical metadata control path')
    return path


def roots():
    home=canonical_path(pwd.getpwuid(os.getuid()).pw_dir)
    lifecycle=home/'.local/state/ai-devops/review-lifecycle'
    descriptors=home/'.local/state/ai-devops/oracle-native-alternate-descriptors'
    test=os.environ.get('AI_DEVOPS_TEST_MODE')=='1'
    test_lifecycle=os.environ.get('AI_ORACLE_NATIVE_TEST_LIFECYCLE_ROOT')
    test_descriptors=os.environ.get('AI_ORACLE_NATIVE_TEST_DESCRIPTOR_ROOT')
    if test:
        if test_lifecycle:lifecycle=canonical_path(test_lifecycle)
        if test_descriptors:descriptors=canonical_path(test_descriptors)
    else:
        require(not test_lifecycle and not test_descriptors,'test metadata roots cannot select actual control storage')
        override=os.environ.get('AI_REVIEW_LIFECYCLE_DIR')
        require(not override or override==str(lifecycle),'actual lifecycle storage override refused')
    return lifecycle,descriptors


def stat_control(path,root,private_parent,directory=False):
    """O_PATH only; no regular file is opened for content here."""
    fd=os.open('/',os.O_PATH|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:
        walked=Path('/')
        for index,part in enumerate(path.parts[1:]):
            child=os.open(part,os.O_PATH|os.O_NOFOLLOW,dir_fd=fd)
            os.close(fd);fd=child;walked=walked/part;info=os.fstat(fd)
            require(not stat.S_ISLNK(info.st_mode),'linked metadata control path refused')
            leaf=index==len(path.parts)-2
            if leaf:
                require((stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode)) and info.st_uid==os.getuid()
                    and stat.S_IMODE(info.st_mode)==(0o700 if directory else 0o600) and (directory or info.st_nlink==1),'owned private single-link control required')
            else:
                require(stat.S_ISDIR(info.st_mode),'nondirectory metadata traversal refused')
                if walked==root or walked.is_relative_to(root):
                    require(info.st_uid==os.getuid() and not info.st_mode&0o022,'foreign or writable metadata parent refused')
                    if walked==root or private_parent(walked):
                        require(stat.S_IMODE(info.st_mode)==0o700,'private metadata parent required')
                elif walked==Path(pwd.getpwuid(os.getuid()).pw_dir) or walked.is_relative_to(Path(pwd.getpwuid(os.getuid()).pw_dir)):
                    require(info.st_uid==os.getuid() and not info.st_mode&0o022,'unsafe native platform ancestor')
        return tuple(getattr(info,k) for k in ('st_dev','st_ino','st_uid','st_mode','st_nlink','st_size','st_mtime_ns','st_ctime_ns'))
    finally:os.close(fd)


def lifecycle(path):
    path=canonical_path(path);root,_=roots()
    require(path.is_relative_to(root),'state is outside known native metadata storage')
    parts=path.relative_to(root).parts
    require(len(parts)==5 and parts[0]=='runs' and parts[1]==KEY and parts[2]=='deepseek'
        and re.fullmatch(r'[A-Za-z0-9._-]{1,128}',parts[3]) and parts[3] not in ('.','..')
        and parts[3].lower()!='deepseek' and TAG.fullmatch(parts[4]),'fixed native code-only lifecycle identity required')
    return stat_control(path,root,lambda directory:directory==path.parent)


def descriptor(path,profile):
    require(profile in PROFILES,'unknown closed descriptor profile')
    path=canonical_path(path);_,root=roots()
    require(path.is_relative_to(root),'descriptor is outside known metadata custody storage')
    parts=path.relative_to(root).parts
    basename='oracle-native-action'+('-v2' if profile.endswith('-v2') else '')+'.manifest.json'
    require(len(parts)==3 and parts[0]==profile and re.fullmatch('[a-f0-9]{32}',parts[1])
        and parts[2]==basename,'fixed fresh descriptor metadata identity required')
    return stat_control(path,root,lambda _:True),parts[1]


def read_lifecycle(path,reader):
    before=lifecycle(path);raw=reader(Path(path))
    require(lifecycle(path)==before,'lifecycle metadata moved during reading')
    return raw


def read_descriptor(path,profile,reader,decode):
    before,action_id=descriptor(path,profile);raw=reader(Path(path));value=decode(raw)
    require(type(value) is dict and value.get('profile')==profile and value.get('action_id')==action_id,
        'descriptor profile/action directory differs')
    require(descriptor(path,profile)==(before,action_id),'descriptor metadata moved during reading')
    return value


def oracle_state_context(path):
    # Lexical native repository-key recognition requires no candidate file read.
    if isinstance(path,(str,Path)) and KEY in Path(path).parts:return True
    env={k:v for k,v in os.environ.items() if not k.startswith('GIT_')}
    env.update(GIT_CONFIG_NOSYSTEM='1',GIT_CONFIG_GLOBAL='/dev/null',GIT_CONFIG_SYSTEM='/dev/null')
    info=os.stat('/usr/bin/git',follow_symlinks=False)
    require(stat.S_ISREG(info.st_mode) and info.st_uid==0 and not info.st_mode&0o022,'fixed public git executable required')
    proc=subprocess.run(['/usr/bin/git','-C',os.getcwd(),'config','--local','--no-includes','--get','remote.origin.url'],
        env=env,capture_output=True,timeout=5)
    if proc.returncode!=0:return False
    require(len(proc.stdout)<=4096,'public repository identity exceeds bound')
    remote=proc.stdout.decode().strip().removesuffix('.git').rstrip('/')
    # Never expose captured URL values, credentials or private config contents.
    if remote.startswith('git@') and ':' in remote:
        host,path=remote[4:].split(':',1);normalized='https://'+host.lower()+'/'+path
    else:
        parsed=urlsplit(remote)
        normalized=('https' if parsed.scheme=='ssh' and parsed.username=='git' else parsed.scheme)+'://'+(parsed.hostname or '').lower()+parsed.path
    return normalized=='https://github.com/u2giants/theoracle'


def publish_descriptor(value,profile):
    """Exclusive bounded metadata only; never a permission/admission issuer."""
    require(profile in PROFILES and type(value) is dict,'closed metadata profile/envelope required')
    schema=2 if profile.endswith('-v2') else 1
    require(value.get('profile')==profile and type(value.get('schema_version')) is int
        and value['schema_version']==schema and value.get('purpose')=='native-alternate-serialization'
        and type(value.get('action_id')) is str and re.fullmatch('[a-f0-9]{32}',value['action_id']),
        'closed metadata header required')
    raw=json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=True,allow_nan=False).encode()
    require(len(raw)+1<=1024**2,'metadata exceeds fixed bound')
    # Reuse the exact profile validator: typed fields, current stats, bounds,
    # PUBLIC runtime identity and custody commitments; it reads no captures.
    public=Path(__file__).resolve().parent/('oracle_native_alternate_v2_profile.py' if schema==2 else 'oracle_native_alternate_profile.py')
    spec=importlib.util.spec_from_file_location('oracle_descriptor_profile',public)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    module.validate_manifest(value,int(time.time()))
    _,root=roots();root=canonical_path(root)
    # Validate known metadata storage and ancestors without reading content.
    stat_control(root,root,lambda _:False,directory=True)
    fd=os.open('/',os.O_PATH|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:
        for part in root.parts[1:]:
            child=os.open(part,os.O_PATH|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd);os.close(fd);fd=child
        info=os.fstat(fd)
        require(info.st_uid==os.getuid() and stat.S_IMODE(info.st_mode)==0o700,'owned private metadata storage required')
        try:os.mkdir(profile,0o700,dir_fd=fd)
        except FileExistsError:pass
        directory=os.open(profile,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd)
        try:
            info=os.fstat(directory)
            require(info.st_uid==os.getuid() and stat.S_IMODE(info.st_mode)==0o700,'owned private profile storage required')
            # Existing/failed/expired action directories refuse before any write.
            os.mkdir(value['action_id'],0o700,dir_fd=directory)
            action=os.open(value['action_id'],os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=directory)
            try:
                os.fchmod(action,0o700)
                basename='oracle-native-action'+('-v2' if schema==2 else '')+'.manifest.json'
                file=os.open(basename,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=action)
                with os.fdopen(file,'wb') as output:
                    os.fchmod(output.fileno(),0o600)
                    info=os.fstat(output.fileno());require(stat.S_ISREG(info.st_mode) and info.st_uid==os.getuid() and info.st_nlink==1,'unsafe fresh descriptor')
                    output.write(raw+b'\n');output.flush();os.fsync(output.fileno())
                os.fsync(action)
            finally:os.close(action)
            os.fsync(directory)
            root_sync=os.open('.',os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd)
            try:os.fsync(root_sync)
            finally:os.close(root_sync)
        finally:os.close(directory)
    finally:os.close(fd)
    return root/profile/value['action_id']/basename
