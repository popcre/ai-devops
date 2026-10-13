#!/usr/bin/env python3
"""Public OS Python/stdlib-only runtime preparation; never private inputs.

Creates no permission/admission. Package provenance and exact closure must still
be reviewed for the installed action. No model assets or site-packages copied.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import sysconfig


def public_origin(path):
    actual=Path(path).resolve(strict=True);info=actual.stat()
    if not (str(actual).startswith('/usr/') or str(actual).startswith('/lib/')) or info.st_uid!=0 or info.st_mode&0o022:
        raise ValueError('root-owned public OS runtime origin required')
    return actual


def prepare(root):
    root=Path(root);root.mkdir(mode=0o700)
    for name in ('input','output','code','proc','dev'): (root/name).mkdir(mode=0o700)
    for index in range(48):(root/'input'/('c'+str(index))).touch()
    for name in ('operator.py','native_alternate.py'):(root/'code'/name).touch()
    origins={};pending=[];total=0
    def copy(origin,destination):
        nonlocal total
        original=public_origin(origin);destination=Path(destination)
        if str(destination).lstrip('/') in origins:return
        target=root/str(destination).lstrip('/');target.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
        # pathlib intermediate parents do not inherit mode; seal every staging directory.
        for ancestor in [target.parent,*target.parent.parents]:
            if ancestor==root:break
            ancestor.chmod(0o700)
        total+=original.stat().st_size
        if total>256*1024**2:raise ValueError('public runtime exceeds aggregate bound')
        shutil.copyfile(original,target);target.chmod(0o755 if os.access(original,os.X_OK) else 0o644)
        digest=hashlib.sha256(target.read_bytes()).hexdigest()
        origins[str(destination).lstrip('/')]=dict(origin=str(original),sha256=digest,bytes=target.stat().st_size)
        if target.read_bytes()[:4]==b'\x7fELF':pending.append(original)
    copy(sys.executable,'/usr/bin/python3')
    stdlib=public_origin(sysconfig.get_path('stdlib'))
    for folder,dirs,files in os.walk(stdlib):
        dirs[:]=sorted(d for d in dirs if d not in {'site-packages','dist-packages','__pycache__'} and not d.startswith('config-'))
        for name in sorted(files):
            if name.endswith('.pyc') or name in {'sitecustomize.py','usercustomize.py'}:continue
            original=Path(folder)/name
            if original.is_file():copy(original,original)
    seen=set()
    while pending:
        original=pending.pop()
        if original in seen:continue
        seen.add(original)
        result=subprocess.run(['/usr/bin/ldd',str(original)],capture_output=True,text=True,check=True)
        for line in result.stdout.splitlines():
            path=line.strip().split('=>')[-1].strip().split(' ')[0]
            if path.startswith('/'):copy(path,path)
    # The dynamic ELF interpreter needs its absolute loader name as well.
    loader=Path('/lib64/ld-linux-x86-64.so.2')
    if loader.exists():copy(loader,loader)
    rows=[]
    for folder,dirs,files in os.walk(root):
        dirs.sort()
        for name in sorted(files):
            path=Path(folder)/name;rows.append(dict(path=str(path.relative_to(root)),bytes=path.stat().st_size,
                sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    raw=json.dumps(rows,sort_keys=True,separators=(',',':'),ensure_ascii=True).encode()
    receipt=dict(schema_version=1,kind='NONAUTHORIZING_PUBLIC_OS_STDLIB_PREPARATION',root=str(root),
        closure_sha256=hashlib.sha256(raw).hexdigest(),bytes=sum(r['bytes'] for r in rows),origins=origins)
    path=Path(str(root)+'.public-runtime.json')
    fd=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,'w') as out:json.dump(receipt,out,sort_keys=True);out.flush();os.fsync(out.fileno())
    return receipt


def verify_recipe(root):
    """Origin hashes only before private action: never hash runtime candidate bytes."""
    path=Path(str(root)+'.public-runtime.json');info=path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid!=os.getuid() or info.st_mode&0o077 or info.st_size>1024**2:
        raise ValueError('owned bounded public runtime recipe required')
    receipt=json.loads(path.read_bytes())
    if receipt.get('kind')!='NONAUTHORIZING_PUBLIC_OS_STDLIB_PREPARATION' or receipt.get('root')!=str(root):raise ValueError('fixed public runtime recipe required')
    expected=set(receipt['origins'])|{'code/operator.py','code/native_alternate.py'}|{'input/c'+str(i) for i in range(48)}
    observed={str(p.relative_to(root)) for p in Path(root).rglob('*') if p.is_file() or p.is_symlink()}
    if observed!=expected:raise ValueError('runtime contains unapproved files')
    for rel,item in receipt['origins'].items():
        original=public_origin(item['origin'])
        if hashlib.sha256(original.read_bytes()).hexdigest()!=item['sha256']:raise ValueError('public runtime origin changed')
        target=Path(root)/rel;info=target.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_uid!=os.getuid() or info.st_mode&0o022:raise ValueError('runtime metadata differs')
    return receipt
