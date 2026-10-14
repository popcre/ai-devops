#!/usr/bin/env python3
"""Public OS Python/stdlib runtime, independently verified before admission.

Staged PUBLIC runtime bytes and live root-owned OS origins may be read before
approval. Retained captures/original/control inputs are never read by this module.
No permission, installation, model assets or source adoption is provided here.
"""
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import sysconfig

LIMIT=256*1024**2
PLACEHOLDERS={'code/operator.py','code/native_alternate.py','code/native_chain.py'}|{'input/c'+str(i) for i in range(48)}

def require(ok,message):
    if not ok:raise ValueError(message)
def canonical(value):return json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=True).encode()
def seal(raw):return hashlib.sha256(raw).hexdigest()
def fields(info):return tuple(getattr(info,k) for k in ('st_dev','st_ino','st_uid','st_mode','st_nlink','st_size','st_mtime_ns','st_ctime_ns'))

def public_origin(path):
    actual=Path(path).resolve(strict=True)
    require(str(actual).startswith('/usr/') or str(actual).startswith('/lib/'),'public OS origin required')
    for ancestor in [actual,*actual.parents]:
        info=ancestor.stat();require(info.st_uid==0 and not info.st_mode&0o022,'root-owned nonwritable public OS origin required')
    return actual

def public_tool_identity(name,expected=None):
    require(name in ('bwrap','ldd'),'unsupported public OS executable')
    fd=os.open('/',os.O_PATH|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:
        for part in ('usr','bin'):
            new=os.open(part,os.O_PATH|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd);os.close(fd);fd=new
            info=os.fstat(fd);require(info.st_uid==0 and not info.st_mode&0o022,'public executable parent is writable')
        binary=os.open(name,os.O_RDONLY|os.O_NOFOLLOW,dir_fd=fd)
        try:
            before=os.fstat(binary)
            require(stat.S_ISREG(before.st_mode) and before.st_uid==0 and not before.st_mode&0o022 and before.st_nlink==1 and 0<before.st_size<=16*1024**2,'root-owned regular public executable required')
            with os.fdopen(os.dup(binary),'rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
            require(fields(os.fstat(binary))==fields(before) and (expected is None or expected==digest),'public executable changed')
            return {'public_path':'/usr/bin/'+name,'sha256':digest,'uid':before.st_uid,'mode':stat.S_IMODE(before.st_mode),'provenance':'root-owned-public-OS-binary'}
        finally:os.close(binary)
    finally:os.close(fd)

def public_bytes(path):
    original=public_origin(path);fd=os.open(original,os.O_RDONLY|os.O_NOFOLLOW)
    try:
        before=os.fstat(fd);require(stat.S_ISREG(before.st_mode) and before.st_uid==0 and not before.st_mode&0o022 and before.st_nlink==1 and before.st_size<=LIMIT,'regular bounded public OS file required')
        with os.fdopen(os.dup(fd),'rb') as stream:raw=stream.read(before.st_size+1)
        require(len(raw)==before.st_size and fields(os.fstat(fd))==fields(before),'public OS bytes changed')
        return raw
    finally:os.close(fd)

def expected_origins():
    """Derive the complete runtime source set from live OS, never the recipe."""
    origins={};pending=[];seen=set()
    def add(origin,destination):
        key=str(Path(destination)).lstrip('/')
        if key in origins:return
        original=public_origin(origin);raw=public_bytes(original)
        origins[key]={'origin':str(original),'sha256':seal(raw),'bytes':len(raw)}
        require(sum(v['bytes'] for v in origins.values())<=LIMIT,'public runtime exceeds aggregate bound')
        if raw[:4]==b'\x7fELF':pending.append(original)
    add('/usr/bin/python3','/usr/bin/python3')
    # This helper must run with the supported public OS interpreter ABI.
    require(public_origin(sys.executable)==public_origin('/usr/bin/python3'),'supported public OS interpreter required')
    stdlib=public_origin(sysconfig.get_path('stdlib'))
    for folder,dirs,files in os.walk(stdlib,followlinks=False):
        dirs[:]=sorted(d for d in dirs if d not in {'site-packages','dist-packages','__pycache__'} and not d.startswith('config-'))
        for name in sorted(files):
            if name.endswith('.pyc') or name in {'sitecustomize.py','usercustomize.py'}:continue
            original=Path(folder)/name
            require(original.is_file(),'unsupported public stdlib node')
            add(original,original)
    ldd=public_tool_identity('ldd')
    while pending:
        original=pending.pop()
        if original in seen:continue
        seen.add(original);public_tool_identity('ldd',ldd['sha256'])
        result=subprocess.run(['/usr/bin/ldd',str(original)],capture_output=True,text=True,check=True,timeout=10,env={'PATH':'/usr/bin:/bin','LC_ALL':'C','LANG':'C'})
        require(len(result.stdout.encode())+len(result.stderr.encode())<=65536,'public dependency metadata exceeds bound')
        for line in result.stdout.splitlines():
            path=line.strip().split('=>')[-1].strip().split(' ')[0]
            if path.startswith('/'):add(path,path)
    loader=Path('/lib64/ld-linux-x86-64.so.2')
    if loader.exists():add(loader,loader)
    return origins,ldd

def rooted_directory(path):
    path=Path(path);require(path.is_absolute() and '..' not in path.parts,'fixed absolute runtime directory required')
    fd=os.open('/',os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:
        for part in path.parts[1:]:
            new=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd);os.close(fd);fd=new
        info=os.fstat(fd);require(info.st_uid==os.getuid() and stat.S_IMODE(info.st_mode)==0o700,'owned0700runtime required')
        return fd
    except Exception:os.close(fd);raise

def staged_rows(root,maximum=LIMIT,expected_files=None):
    """FD-anchored, nofollow regular files only; reject every special node."""
    rows=[];total=0;root_fd=rooted_directory(root)
    allowed_dirs={'code','input','output','proc','dev'}
    if expected_files is not None:
        for rel in expected_files:allowed_dirs.update(str(p) for p in Path(rel).parents if str(p)!='.')
    def visit(fd,prefix):
        nonlocal total
        for name in sorted(os.listdir(fd)):
            info=os.stat(name,dir_fd=fd,follow_symlinks=False);rel=prefix+name
            require(info.st_uid==os.getuid() and not info.st_mode&0o022,'public staging ownership/mode differs')
            if stat.S_ISDIR(info.st_mode):
                require(expected_files is None or rel in allowed_dirs,'unapproved runtime directory')
                child=os.open(name,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd)
                try:
                    require(fields(os.fstat(child))==fields(info),'staged directory moved');visit(child,rel+'/')
                finally:os.close(child)
            else:
                require(expected_files is None or rel in expected_files,'unapproved runtime file')
                require(stat.S_ISREG(info.st_mode) and info.st_nlink==1,'nonregular/linked runtime node refused')
                leaf=os.open(name,os.O_RDONLY|os.O_NOFOLLOW,dir_fd=fd)
                try:
                    before=os.fstat(leaf);require(fields(before)==fields(info),'staged runtime file moved')
                    total+=before.st_size;require(total<=maximum,'staged runtime bound exceeded')
                    with os.fdopen(os.dup(leaf),'rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
                    require(fields(os.fstat(leaf))==fields(before),'staged runtime bytes moved')
                    rows.append({'path':rel,'bytes':before.st_size,'sha256':digest})
                finally:os.close(leaf)
    try:visit(root_fd,'')
    finally:os.close(root_fd)
    # Match the historical builder's deterministic directory/file ordering.
    rows.sort(key=lambda r:(str(Path(r['path']).parent),Path(r['path']).name))
    return rows,total

def prepare(root):
    root=Path(root);root.mkdir(mode=0o700)
    for name in ('input','output','code','proc','dev'):(root/name).mkdir(mode=0o700)
    for rel in PLACEHOLDERS:(root/rel).touch(mode=0o600)
    origins,ldd=expected_origins()
    for rel,item in origins.items():
        target=root/rel;target.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
        for ancestor in [target.parent,*target.parent.parents]:
            if ancestor==root:break
            ancestor.chmod(0o700)
        raw=public_bytes(item['origin']);require(seal(raw)==item['sha256'],'live public origin moved while preparing')
        fd=os.open(target,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o755 if os.access(item['origin'],os.X_OK) else 0o644)
        with os.fdopen(fd,'wb') as out:out.write(raw);out.flush();os.fsync(out.fileno())
    rows,total=staged_rows(root,expected_files=set(origins)|PLACEHOLDERS)
    receipt={'schema_version':1,'kind':'NONAUTHORIZING_PUBLIC_OS_STDLIB_PREPARATION','root':str(root),'closure_sha256':seal(canonical(rows)),'bytes':total,'origins':origins,'ldd_identity':ldd}
    path=Path(str(root)+'.public-runtime.json');fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,'w') as out:json.dump(receipt,out,sort_keys=True);out.flush();os.fsync(out.fileno())
    return receipt

def verify_recipe(root):
    """Compare every staged PUBLIC byte to independently derived live OS origins."""
    root=Path(root);parent=rooted_directory(root.parent)
    try:
        fd=os.open(root.name+'.public-runtime.json',os.O_RDONLY|os.O_NOFOLLOW,dir_fd=parent)
        try:
            info=os.fstat(fd);require(stat.S_ISREG(info.st_mode) and info.st_uid==os.getuid() and stat.S_IMODE(info.st_mode)==0o600 and info.st_nlink==1 and info.st_size<=1024**2,'owned bounded recipe required')
            with os.fdopen(os.dup(fd),'rb') as stream:raw=stream.read(info.st_size+1)
            require(fields(os.fstat(fd))==fields(info),'recipe moved')
            receipt=json.loads(raw)
        finally:os.close(fd)
    finally:os.close(parent)
    require(receipt.get('schema_version')==1 and receipt.get('kind')=='NONAUTHORIZING_PUBLIC_OS_STDLIB_PREPARATION' and receipt.get('root')==str(root),'fixed public recipe required')
    expected,ldd=expected_origins()
    require(receipt.get('origins')==expected and receipt.get('ldd_identity')==ldd,'recipe differs from independently derived public OS source')
    rows,total=staged_rows(root,expected_files=set(expected)|PLACEHOLDERS);observed={r['path']:r for r in rows}
    require(set(observed)==set(expected)|PLACEHOLDERS,'public staging inventory differs')
    for rel,item in expected.items():require(observed[rel]['sha256']==item['sha256'] and observed[rel]['bytes']==item['bytes'],'staged public runtime bytes differ from live OS')
    for rel in PLACEHOLDERS:require(observed[rel]['bytes']==0 and observed[rel]['sha256']==seal(b''),'fixed empty runtime placeholders required')
    require(receipt.get('closure_sha256')==seal(canonical(rows)) and receipt.get('bytes')==total,'actual public runtime closure differs')
    receipt['public_os_origin_set_sha256']=seal(canonical(expected))
    return receipt
