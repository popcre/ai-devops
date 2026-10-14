#!/usr/bin/env python3
"""Invented fixture regression tests for the third public source review."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
from types import SimpleNamespace
ROOT=Path(__file__).resolve().parents[1]
def module(name,path):
    spec=importlib.util.spec_from_file_location(name,ROOT/path);value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value
scope=module('scope','bin/ai-review-code-only.py')
output=module('output','tools/oracle_native_alternate_output.py')

class Security(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name);self.root.chmod(0o700)
    def tearDown(self):self.temp.cleanup()
    def git(self,repo,*args):return subprocess.check_output(['git','-C',str(repo),*args],stderr=subprocess.DEVNULL)
    def test_actual_producer_and_v2_contract_bytes_under_git_hidden_flags_never_export(self):
        for profile in scope.PUBLIC_PRODUCER_PROFILES:
            registry=json.loads((ROOT/'config/review-action-profiles.json').read_text())['profiles'][profile]
            for flag in ('--assume-unchanged','--skip-worktree'):
                for target,fixture in [(scope.PUBLIC_PRODUCER_PATH,'oracle-native-public-producer.md')]+([(scope.PUBLIC_V2_CONTRACT_PATH,'oracle-native-v2-public-contract.json')] if profile.endswith('v2') else []):
                    with self.subTest(profile=profile,flag=flag,target=target):
                        repo=self.root/'repo';repo.mkdir()
                        self.git(repo,'init','-q');self.git(repo,'config','user.name','Invented');self.git(repo,'config','user.email','fixture@invalid.local');self.git(repo,'remote','add','origin',registry['repository'])
                        for name in registry['paths']:
                            path=repo/name;path.parent.mkdir(parents=True,exist_ok=True)
                            content=b'{}' if name.endswith('.json') else b'# invented source only\n'
                            if name==scope.PUBLIC_PRODUCER_PATH:content=(ROOT/'tests/fixtures/oracle-native-public-producer.md').read_bytes()
                            if name==scope.PUBLIC_V2_CONTRACT_PATH:content=(ROOT/'tests/fixtures/oracle-native-v2-public-contract.json').read_bytes()
                            path.write_bytes(content)
                        self.git(repo,'add','--all');self.git(repo,'commit','-qm','invented public closure');self.git(repo,'update-index',flag,'--',target)
                        secret=b'INVENTED_PRIVATE_SENTINEL_MUST_NOT_EXPORT'
                        (repo/target).write_bytes(secret)
                        self.assertFalse(self.git(repo,'status','--porcelain','--',target))
                        with self.assertRaisesRegex(ValueError,'actual public'):
                            scope.current_bytes(repo,target,profile)
                        pathsfile=self.root/'paths.json';pathsfile.write_text(json.dumps(registry['paths']))
                        stage=self.root/'export'
                        with self.assertRaisesRegex(ValueError,'actual public'):
                            scope.create(SimpleNamespace(source=str(repo),stage=str(stage),paths_file=str(pathsfile),base='HEAD',action_profile=profile))
                        if stage.exists():
                            for item in stage.rglob('*'):
                                if item.is_file():self.assertNotIn(secret,item.read_bytes())
                        import shutil
                        shutil.rmtree(repo)
                        if stage.exists():shutil.rmtree(stage)
    def test_generic_docs_json_stays_denied(self):
        for profile in (None,*scope.PUBLIC_PRODUCER_PROFILES):
            with self.assertRaises(ValueError):scope.safe_path('docs/operations/native-alternate-chain-v2-contract.json',profile)

    def test_malformed_dispatch_arguments_state_and_binding_fail_cleanly(self):
        state=self.root/'state';state.chmod(0o600) if state.exists() else None
        for value in (None,[],{}, {'action_profile_binding':None},{'action_profile_binding':[]},{'action_profile_binding':True}):
            state.write_text(json.dumps(value));state.chmod(0o600)
            commands=[['tools/review_action_profile.py','preaction',str(state),'--profile'],['tools/review_action_profile.py','preaction',str(state)],
                ['tools/oracle_native_alternate_profile.py','prompt',str(state)],['tools/oracle_native_alternate_v2_profile.py','prompt',str(state)]]
            for command in commands:
                result=subprocess.run([sys.executable,str(ROOT/command[0]),*command[1:]],capture_output=True,input=b'{}')
                self.assertNotEqual(result.returncode,0);self.assertNotIn(b'Traceback',result.stderr)
                self.assertNotIn(b'NoneType',result.stderr)
        self.assertFalse(list(self.root.glob('*.spent')))
    def fixture_output(self):
        root=self.root/'output';root.mkdir(mode=0o700)
        hashes=[]
        for index in range(33):
            raw=b'INVENTED OUTPUT '+str(index).encode();path=root/('c'+str(index)+'.json');path.write_bytes(raw);path.chmod(0o600);hashes.append(hashlib.sha256(raw).hexdigest())
        receipt={'artifact_count':33,'output_bytes':sum(p.stat().st_size for p in root.iterdir()),'outputs_sha256':hashlib.sha256(json.dumps(hashes,separators=(',',':')).encode()).hexdigest()}
        limits={'per_file_bytes':8*1024**2,'output_bytes':256*1024**2}
        return root,receipt,limits
    def test_output_actual_receipt_and_owner_mode_checks(self):
        root,receipt,limits=self.fixture_output();fd=output.open_directory(root);initial=os.fstat(fd)
        try:
            output.verify(fd,initial,receipt,limits)
            for key,value in [('output_bytes',receipt['output_bytes']+1),('outputs_sha256','0'*64),('artifact_count',True)]:
                bad={**receipt,key:value}
                with self.assertRaises(ValueError):output.verify(fd,initial,bad,limits)
            path=root/'c0.json';path.chmod(0o644)
            with self.assertRaisesRegex(ValueError,'unsafe'):output.verify(fd,initial,receipt,limits)
            path.chmod(0o600);root.chmod(0o755)
            with self.assertRaisesRegex(ValueError,'directory changed'):output.verify(fd,initial,receipt,limits)
            root.chmod(0o700)
            real=os.fstat
            def foreign(check):
                st=real(check)
                if __import__('stat').S_ISREG(st.st_mode):
                    fields={k:getattr(st,k) for k in ('st_dev','st_ino','st_uid','st_mode','st_nlink','st_size','st_mtime_ns','st_ctime_ns')};fields['st_uid']=st.st_uid+1;return SimpleNamespace(**fields)
                return st
            with mock.patch.object(os,'fstat',side_effect=foreign):
                with self.assertRaisesRegex(ValueError,'unsafe'):output.verify(fd,initial,receipt,limits)
        finally:os.close(fd)
    def test_symlink_fifo_hardlink_directory_and_extra_output_fail_before_content_opens(self):
        import shutil
        for kind in ('symlink','fifo','hardlink','directory','extra'):
            root,receipt,limits=self.fixture_output();fd=output.open_directory(root);initial=os.fstat(fd);target=root/'c0.json'
            if kind=='symlink':target.unlink();target.symlink_to(root/'c1.json')
            elif kind=='fifo':target.unlink();os.mkfifo(target,0o600)
            elif kind=='hardlink':target.unlink();os.link(root/'c1.json',target)
            elif kind=='directory':target.unlink();target.mkdir(mode=0o700)
            else:(root/'extra').write_bytes(b'INVENTED')
            opened=[];real=os.open
            def checked(path,flags,*args,**kwargs):
                if str(path)=='c0.json' and not flags&os.O_PATH:opened.append(path)
                return real(path,flags,*args,**kwargs)
            try:
                with mock.patch.object(os,'open',side_effect=checked):
                    with self.assertRaises(ValueError):output.verify(fd,initial,receipt,limits)
                self.assertEqual(opened,[])
            finally:os.close(fd);shutil.rmtree(root)
    def test_linked_output_parent_and_fd_resource_limit(self):
        root,receipt,limits=self.fixture_output();link=self.root/'link';link.symlink_to(self.root,target_is_directory=True)
        with self.assertRaises(OSError):output.open_directory(link/'output')
        for name in ('tools/oracle_native_alternate_guardian.py','tools/oracle_native_alternate_v2_guardian.py'):
            guardian=module(name,name)
            with mock.patch.object(guardian.resource,'setrlimit') as setter:
                guardian.limits()
                setter.assert_any_call(guardian.resource.RLIMIT_NOFILE,(128,128))

    def test_actual_v1_v2_sealed_fd_sandbox_and_fixed_descriptor_denials(self):
        import fcntl
        import shutil
        for v2 in (False,True):
            guardian=module('guardian','tools/oracle_native_alternate_'+('v2_' if v2 else '')+'guardian.py')
            runtime=guardian.profile.public_runtime_module();root=self.root/('runtime-v2' if v2 else 'runtime-v1');receipt=runtime.prepare(root)
            files=self.root/('inputs-v2' if v2 else 'inputs-v1');files.mkdir(mode=0o700);output_dir=self.root/('output-v2' if v2 else 'output-v1');output_dir.mkdir(mode=0o700)
            identities=[]
            for index in range(48):
                path=files/('c'+str(index));path.write_bytes(b'INVENTED INPUT '+str(index).encode());path.chmod(0o600);st=path.stat();identities.append((st.st_dev,st.st_ino))
            codes=['/code/operator.py','/code/native_alternate.py']+(['/code/native_chain.py'] if v2 else [])
            code=("import os,resource,hashlib,json\nassert os.getpid() in (1,2)\nassert resource.getrlimit(resource.RLIMIT_NOFILE)==(128,128)\n"+
                "identities="+repr(identities)+"\n"+
                "mounts={line.split()[4]:line.split()[5] for line in open('/proc/self/mountinfo')}\n"+
                "for path in "+repr(codes)+":\n assert 'ro' in mounts[path].split(',')\n try:open(path,'wb')\n except OSError:pass\n else:raise AssertionError('code writable')\n"+
                "for index in range(48):\n path='/input/c'+str(index)\n assert open(path,'rb').read()==b'INVENTED INPUT '+str(index).encode()\n assert 'ro' in mounts[path].split(',')\n assert os.stat(path).st_mode&0o777==0o600\n assert (os.stat(path).st_dev,os.stat(path).st_ino)==identities[index]\n try:open(path,'wb')\n except OSError:pass\n else:raise AssertionError('input writable')\n"+
                "assert os.stat('/output').st_mode&0o777==0o700\nprint(json.dumps({'status':'NONAUTHORIZING_PUBLIC_FIXTURE','code_hashes':[hashlib.sha256(open(p,'rb').read()).hexdigest() for p in "+repr(codes)+"]}))\n").encode()
            fds=[];inputs=[]
            try:
                for raw in [code,b'INVENTED DECODER']+([b'INVENTED CHAIN'] if v2 else []):
                    fd=os.memfd_create('invented-public-code',os.MFD_ALLOW_SEALING);fds.append(fd);os.write(fd,raw);os.lseek(fd,0,os.SEEK_SET)
                    fcntl.fcntl(fd,fcntl.F_ADD_SEALS,fcntl.F_SEAL_WRITE|fcntl.F_SEAL_GROW|fcntl.F_SEAL_SHRINK|fcntl.F_SEAL_SEAL)
                for index in range(48):
                    path=files/('c'+str(index));inputs.append(os.open(path,os.O_RDONLY|os.O_NOFOLLOW))
                command=guardian.sandbox_command({'root':str(root)},*fds,inputs,str(output_dir))
                self.assertNotIn('/proc/self/fd',str(command));self.assertEqual(command.count('--ro-bind-fd'),48);self.assertEqual(command.count('--ro-bind-data'),len(fds))
                result=subprocess.run(command,pass_fds=tuple(fds+inputs),preexec_fn=guardian.limits,env={'PATH':'/usr/bin:/bin'},capture_output=True,timeout=10)
                self.assertEqual(result.returncode,0,result.stderr);self.assertEqual(json.loads(result.stdout),{'status':'NONAUTHORIZING_PUBLIC_FIXTURE','code_hashes':[hashlib.sha256(raw).hexdigest() for raw in [code,b'INVENTED DECODER']+([b'INVENTED CHAIN'] if v2 else [])]})
                self.assertFalse(list(output_dir.iterdir()));self.assertFalse(list(self.root.glob('*.spent')))
                for invalid in (inputs[:-1],inputs+[inputs[0]],[inputs[0]]*48,[True]+inputs[1:],[-1]+inputs[1:],[999999]+inputs[1:]):
                    with self.assertRaises((ValueError,OSError)):guardian.sandbox_command({'root':str(root)},*fds,invalid,str(output_dir))
                with self.assertRaises(ValueError):guardian.sandbox_command({'root':str(root)},*([fds[0]]*len(fds)),inputs,str(output_dir))
                with self.assertRaises(ValueError):guardian.sandbox_command({'root':str(root)},*(fds[:-1]+[inputs[0]]),inputs,str(output_dir))
                with self.assertRaises(TypeError):guardian.sandbox_command({'root':str(root)},*fds,inputs,str(output_dir),'unknown')
                unsealed=os.memfd_create('invented-unsealed',os.MFD_ALLOW_SEALING)
                try:
                    with self.assertRaises(ValueError):guardian.sandbox_command({'root':str(root)},*(fds[:-1]+[unsealed]),inputs,str(output_dir))
                finally:os.close(unsealed)
                descriptors=[{'path':str(files/('c'+str(index))),'stat':guardian.profile.descriptor_stat(files/('c'+str(index)))} for index in range(48)]
                guardian.revalidate_input_paths(descriptors,inputs)
                marker=self.root/('fixture-spent-'+str(v2));marker.write_bytes(b'INVENTED SPENT NO AUTHORITY')
                first=files/'c0';moved=files/'renamed';first.rename(moved)
                with mock.patch.object(os,'read',side_effect=AssertionError('private byte read')):
                    with self.assertRaises((ValueError,OSError)):guardian.revalidate_input_paths(descriptors,inputs)
                moved.rename(first)
                first.rename(moved);first.write_bytes(b'INVENTED CROSS INODE');first.chmod(0o600)
                with mock.patch.object(os,'read',side_effect=AssertionError('private byte read')):
                    with self.assertRaises((ValueError,OSError)):guardian.revalidate_input_paths(descriptors,inputs)
                first.unlink();moved.rename(first)
                parent=self.root/('moved-parent-'+str(v2));files.rename(parent);files.symlink_to(parent,target_is_directory=True)
                with mock.patch.object(os,'read',side_effect=AssertionError('private byte read')):
                    with self.assertRaises((ValueError,OSError)):guardian.revalidate_input_paths(descriptors,inputs)
                files.unlink();parent.rename(files)
                first.unlink()
                with mock.patch.object(os,'read',side_effect=AssertionError('private byte read')):
                    with self.assertRaises((ValueError,OSError)):guardian.revalidate_input_paths(descriptors,inputs)
                self.assertEqual(marker.read_bytes(),b'INVENTED SPENT NO AUTHORITY')
            finally:
                for fd in fds+inputs:os.close(fd)


if __name__=='__main__':unittest.main()
