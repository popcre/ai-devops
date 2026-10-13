"""ROOT #27/#58 owned NONAUTHORIZING discovery projection; no issuer or claim.

The private actual contract stays outside every ordinary/linked/bare Git tree.
This helper consolidates existing inspector validators; it never invokes its
production gate, HTTP, SSH, remote Docker or credential paths.
"""
import argparse,hashlib,importlib.util,json,os,stat,sys
from pathlib import Path

SPEC=importlib.util.spec_from_file_location('platform_projection_inspector',Path(__file__).with_name('inspect_capability.py'))
inspector=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(inspector)
# This entrypoint has no credential operation and retains none from import.
inspector._PASSWORD=inspector._TOKEN=None
PROJECTION_SCHEMA='oracle-platform-discovery-action-projection/v1'
SCOPE={'api_version':{'method':'GET','resource':'/api/v1/version'},'coolify_identity_fields':['id','name','image','image_id','state'],'helper_inventory':{'maximum':16,'fields':['id','image','name','state']},'remote_mutations':0}

def outside_git(path):
    raw=str(path)
    inspector.require(raw.startswith('/') and all(p not in ('','.','..','.git') for p in raw.split('/')[1:]),'canonical outside-Git contract required')
    fd=os.open('/',os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    try:
        for part in Path(raw).parts[1:-1]:
            child=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd);os.close(fd);fd=child
            try:os.stat('.git',dir_fd=fd,follow_symlinks=False)
            except FileNotFoundError:pass
            else:raise ValueError('Git ancestry refused')
            # A bare repository has no .git child. Metadata only; never read it.
            try:
                head=os.stat('HEAD',dir_fd=fd,follow_symlinks=False)
                objects=os.stat('objects',dir_fd=fd,follow_symlinks=False)
                refs=os.stat('refs',dir_fd=fd,follow_symlinks=False)
            except FileNotFoundError:pass
            else:
                inspector.require(not(stat.S_ISREG(head.st_mode) and stat.S_ISDIR(objects.st_mode) and stat.S_ISDIR(refs.st_mode)),'bare Git ancestry refused')
    finally:os.close(fd)

def describe(path,seal):
    outside_git(path)
    parent=inspector.Custody(Path(path).parent);fd=None
    try:
        fd=os.open(Path(path).name,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK,dir_fd=parent.fd)
        before=os.fstat(fd)
        inspector.require(stat.S_ISREG(before.st_mode) and before.st_uid==os.getuid() and stat.S_IMODE(before.st_mode)==0o600 and before.st_nlink==1 and 0<before.st_size<=8192,'protected private contract leaf required')
        def unchanged():
            parent.recheck();outside_git(path)
            inspector.require(inspector.file_identity(os.fstat(fd))==inspector.file_identity(before) and inspector.file_identity(os.stat(Path(path).name,dir_fd=parent.fd,follow_symlinks=False))==inspector.file_identity(before),'private contract moved')
        unchanged()
        anchor='/proc/'+str(os.getpid())+'/fd/'+str(parent.fd)+'/'+Path(path).name
        c=inspector.load_contract(anchor,seal);unchanged()
        inspector.require(c['mode']=='discover','qualification projection requires its own complete scope')
        temporary=inspector.Custody(os.environ.get('TMPDIR',''));temporary.close()
        installed=inspector.installed_gate(c);unchanged()
        manifest=inspector.read_install_manifest()
        inspector.require(hashlib.sha256(manifest).hexdigest()==installed['manifest_sha256'],'installed manifest moved during projection')
        rows=[r.split('\t') for r in manifest.decode('ascii').splitlines()]
        closure_count=sum(r[0]=='symlink' for r in rows)
        inspector.verify_tailnet(c);unchanged();inspector.lifetime(c,120)
        return {'schema':PROJECTION_SCHEMA,'contract_schema':c['schema'],'mode':c['mode'],'claim_id':c['claim_id'],'issued_at':c['issued_at'],'expires_at':c['expires_at'],'contract_sha256':seal,'operator_sha256':c['operator_sha256'],'remote_sha256':c['remote_sha256'],'transport_helper_sha256':c['transport_helper_sha256'],'fixed_target_commitment_sha256':inspector.TARGET_SHA256,'fixed_peer_route_commitment_sha256':inspector.PEER_SHA256,'installed_gate':installed,'managed_link_count':closure_count,'scope':SCOPE,'non_authorizing':True,'claims_created':0,'credentials_used':False,'remote_traffic':0}
    finally:
        if fd is not None:os.close(fd)
        parent.close()

class PrivateArgumentParser(argparse.ArgumentParser):
    def error(self,message):raise ValueError('projection arguments refused')

def main(argv=None):
    try:
        parser=PrivateArgumentParser(prog='describe_action.py');parser.add_argument('--contract',required=True);parser.add_argument('--contract-sha256',required=True);args=parser.parse_args(argv)
        value=describe(args.contract,args.contract_sha256)
        print(json.dumps(value,sort_keys=True,separators=(',',':'),ensure_ascii=True,allow_nan=False));return 0
    except Exception:
        print('platform discovery projection refused; no action admitted',file=sys.stderr);return 3
if __name__=='__main__':raise SystemExit(main())
