#!/usr/bin/env python3
"""Real local stat/namespace fixtures; never provider, permission or private reads."""
import copy
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('profile',ROOT/'tools/oracle_native_alternate_profile.py')
profile=importlib.util.module_from_spec(spec);spec.loader.exec_module(profile)
spec=importlib.util.spec_from_file_location('scope',ROOT/'bin/ai-review-code-only.py')
scope=importlib.util.module_from_spec(spec);spec.loader.exec_module(scope)
spec=importlib.util.spec_from_file_location('guardian',ROOT/'tools/oracle_native_alternate_guardian.py')
guardian=importlib.util.module_from_spec(spec);spec.loader.exec_module(guardian)


class OracleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.public_temp=tempfile.TemporaryDirectory();parent=Path(cls.public_temp.name);parent.chmod(0o700)
        cls.public_root=parent/'runtime';cls.public_receipt=profile.public_runtime_module().prepare(cls.public_root)
    @classmethod
    def tearDownClass(cls):cls.public_temp.cleanup()
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name);self.root.chmod(0o700)
        self.now=int(time.time());self.capture=self.root/'capture';self.capture.write_bytes(b'INVENTED ONLY');self.capture.chmod(0o600)
        self.register=self.root/'register';self.register.write_bytes(b'INVENTED REGISTER');self.register.chmod(0o600)
        def item(path):return {'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'role':path.name,'stat':profile.descriptor_stat(str(path))}
        self.manifest=dict(schema_version=1,profile=profile.PROFILE,purpose=profile.PURPOSE,action_id='a'*32,
            source_head='a'*40,source_digest='a'*64,observed_at=self.now,expires_at=self.now+600,
            permission_custody=dict(current_contract_metadata_sha256='a'*64,historical_capture_sha256='b'*64,current_owner='Albert Hazan',
                requires_external_registrar=False,external_registration_sha256=None,observed_at=self.now,expires_at=self.now+600),
            captures=[item(self.capture)],controls=[],census=copy.deepcopy(profile.CENSUS),output_parent={'path':str(self.root),'stat':profile.descriptor_stat(str(self.root),True)},
            output_leaf='new-alternate',runtime={'root':str(self.public_root),'closure_sha256':self.public_receipt['closure_sha256'],'bytes':self.public_receipt['bytes'],'bwrap':'/usr/bin/bwrap','bwrap_sha256':profile.public_bwrap_identity()['sha256']},limits=copy.deepcopy(profile.LIMITS))
        self.manifest['captures']=[]
        for index in range(33):
            path=self.root/('capture'+str(index));path.write_bytes(b'INVENTED ONLY '+str(index).encode());path.chmod(0o600)
            value=item(path);value['role']='group-'+str(index%8)+'-page-'+str(index+1)+'.json';self.manifest['captures'].append(value)
        self.capture=Path(self.manifest['captures'][0]['path'])
        for role in profile.CONTROL_ROLES:
            path=self.root/role;path.write_bytes(b'INVENTED CONTROL');path.chmod(0o600)
            value=item(path);value['sha256']=profile.CONTROL_HASHES.get(role,value['sha256']);self.manifest['controls'].append(value)
        self.manifest['output_parent']['stat']=profile.descriptor_stat(str(self.root),True)
    def tearDown(self):self.temp.cleanup()
    def test_preapproval_stat_never_reads_or_hashes_capture(self):
        with mock.patch('builtins.open',side_effect=AssertionError('content read before admission')),mock.patch.object(Path,'read_bytes',side_effect=AssertionError('content read')):
            result=profile.validate_manifest(self.manifest,self.now)
        self.assertFalse(result['capture_byte_hashes_verified'])
    def test_declared_hash_is_unverified_not_permission(self):
        self.manifest['captures'][0]['sha256']='0'*64
        self.assertFalse(profile.validate_manifest(self.manifest,self.now)['capture_byte_hashes_verified'])
    def test_unknown_contract_and_external_registrar_cannot_be_fabricated(self):
        self.manifest['permission_custody']['requires_external_registrar']=True
        with self.assertRaisesRegex(ValueError,'supported verifier'):profile.validate_manifest(self.manifest,self.now)
    def test_missing_or_expired_custody_fails(self):
        for key in ('current_contract_metadata_sha256','current_owner'):
            m=copy.deepcopy(self.manifest);del m['permission_custody'][key]
            with self.assertRaises(ValueError):profile.validate_manifest(m,self.now)
        self.manifest['permission_custody']['expires_at']=self.now
        with self.assertRaises(ValueError):profile.validate_manifest(self.manifest,self.now)
    def test_expired_future_and_too_short_action_deny(self):
        for delta in (-1,1):
            m=copy.deepcopy(self.manifest);m['observed_at']=self.now+delta*(601 if delta<0 else 1)
            with self.assertRaises(ValueError):profile.validate_manifest(m,self.now)
        self.manifest['expires_at']=self.now+179
        with self.assertRaises(ValueError):profile.validate_manifest(self.manifest,self.now)
    def test_source_extraction_renewal_and_changed_bounds_deny(self):
        for mutation in ({'purpose':'source-extraction'},{'limits':{**profile.LIMITS,'network':'host'}},{'active':True}):
            with self.assertRaises(ValueError):profile.validate_manifest({**self.manifest,**mutation},self.now)
    def test_symlink_wrong_mode_and_inode_drift_deny(self):
        self.capture.chmod(0o644)
        with self.assertRaises(ValueError):profile.validate_manifest(self.manifest,self.now)
        self.capture.chmod(0o600);self.capture.unlink();self.capture.symlink_to(self.register)
        with self.assertRaises(ValueError):profile.validate_manifest(self.manifest,self.now)
    def test_duplicate_input_output_collision_and_oversize_deny(self):
        for change in ('duplicate','output','size'):
            m=copy.deepcopy(self.manifest)
            if change=='duplicate':m['captures']*=2
            elif change=='output':(self.root/m['output_leaf']).mkdir()
            else:m['runtime']['bytes']=profile.LIMITS['input_bytes']
            with self.assertRaises(ValueError):profile.validate_manifest(m,self.now)
    def test_dual_scope_unique_unindented_lines_required(self):
        binding={'profile':profile.PROFILE,'manifest_descriptor_sha256':'a'*64,'permission_registration_descriptor_sha256':'b'*64}
        action='Action scope: '+profile.PROFILE+' descriptor sha256:'+'a'*64
        purpose='Purpose registration: '+profile.PROFILE+' descriptor sha256:'+'b'*64
        self.assertTrue(scope.has_exact_action_scope(action+'\n'+purpose,binding))
        for text in (action,purpose,' '+action+'\n'+purpose,action+'\n'+purpose+'\n'+purpose,action+'\n'+purpose.replace('b'*64,'c'*64)):
            self.assertFalse(scope.has_exact_action_scope(text,binding))
    def test_test_fixture_admission_cannot_be_consumed(self):
        binding={'installed_enforcement':{'kind':'NONAUTHORIZING_TEST_FIXTURE'}}
        record={'schema_version':profile.ADMISSION_SCHEMA,'kind':'descriptor-only-admission','profile':profile.PROFILE,'binding':binding,
            'action_id':self.manifest['action_id'],'expires_at':self.manifest['expires_at']}
        with self.assertRaisesRegex(ValueError,'test fixture'):guardian.consume(self.root/'admission.json',record,self.manifest,binding)
        for damage in ({'kind':'reviewer-approval'},{'action_id':'f'*32},{'binding':{}},{'expires_at':int(time.time())}):
            with self.assertRaisesRegex(ValueError,'descriptor-only admission'):guardian.consume(self.root/'admission.json',{**record,**damage},self.manifest,binding)
        self.assertFalse(list(self.root.glob('*.spent')))
    def test_real_gate_admits_descriptor_without_any_reviewer_verdict(self):
        # Real ai-task-gates run (#2041): no review lifecycle, report or verdict
        # exists; a valid descriptor admits, invalid ones and replays refuse.
        repo=self.root/'oracle-repo';repo.mkdir()
        env=dict(os.environ,AI_DEVOPS_TEST_MODE='1',AI_TASK_GATES_DIR=str(self.root/'gates'),
            AI_ORACLE_NATIVE_TEST_ADMISSION_ROOT=str(self.root/'admissions'),AI_REVIEW_LIFECYCLE_DIR=str(self.root/'no-reviews'))
        def git(*args):return subprocess.check_output(['git','-C',str(repo),*args],env=env).decode().strip()
        git('init','-q');git('config','user.name','Fixture');git('config','user.email','fixture@invalid.local')
        git('remote','add','origin','https://github.com/u2giants/theoracle')
        registry,_=profile.profile()
        for name in registry['paths']:
            target=repo/name;target.parent.mkdir(parents=True,exist_ok=True)
            target.write_bytes(json.dumps({'schema_version':1,'gates':{'private-tooling':{'required':['oracle-native-alternate-descriptor-only-admission'],'forbidden_actions':[]}}}).encode()
                if name=='.ai-devops/task-gates.json' else b'# Invented public source fixture only\n')
        git('add','--all');git('commit','-qm','public source fixture')
        identity=json.loads(subprocess.check_output([str(ROOT/'bin/ai-review-lifecycle'),'identity',str(repo)],env=env))
        gates=str(ROOT/'bin/ai-task-gates')
        def check(m):
            return subprocess.run([gates,'check','--before',profile.ACTION,'--action-manifest-stdin'],cwd=repo,env=env,
                input=json.dumps(m).encode(),capture_output=True)
        self.assertEqual(subprocess.run([gates,'start','--class','private-tooling'],cwd=repo,env=env,capture_output=True).returncode,0)
        with mock.patch.dict(os.environ,env):
            manifest=self.bound_manifest(identity) if hasattr(self,'bound_manifest') else copy.deepcopy(self.manifest)
        manifest.update(source_head=identity['head'],source_digest=identity['source_digest'])
        manifest['output_parent']['stat']=profile.descriptor_stat(str(self.root),True)
        for index,damage in enumerate(({'source_head':'0'*40},{'limits':{**profile.LIMITS,'network':'host'}},{'profile':'unknown'})):
            bad=copy.deepcopy(manifest);bad.update(damage);bad['action_id']=str(index)*32
            self.assertEqual(check(bad).returncode,3)
        admitted=check(manifest)
        self.assertEqual(admitted.returncode,0,admitted.stderr)
        self.assertIn(b'descriptor-only admission',admitted.stdout);self.assertNotIn(b'INVENTED',admitted.stdout+admitted.stderr)
        files=list((self.root/'admissions').rglob('*.json'));self.assertEqual(len(files),1)
        record=json.loads(files[0].read_text())
        self.assertIs(record['reviewer_verdict_required'],False);self.assertIsNone(record['advisory_review_report_sha256'])
        self.assertEqual(record['schema_version'],1);self.assertEqual(record['binding']['source_head'],identity['head'])
        self.assertEqual(record['binding']['installed_enforcement']['kind'],'NONAUTHORIZING_TEST_FIXTURE')
        self.assertEqual(check(manifest).returncode,3)  # one admission per action, no replay
        (repo/'docs/operations/offline-original-locators.md').write_text('uncommitted change')
        dirty=copy.deepcopy(manifest);dirty['action_id']='9'*32;self.assertEqual(check(dirty).returncode,3)
        with mock.patch.dict(os.environ,env):
            result=subprocess.run([sys.executable,str(ROOT/'tools'/('oracle_native_alternate_v2_guardian.py' if 'False'=='True' else 'oracle_native_alternate_guardian.py')),'--admission',str(files[0])],
                input=profile.canonical(manifest),env=env,capture_output=True)
        self.assertNotEqual(result.returncode,0);self.assertFalse(list((self.root/'admissions').rglob('*.spent')))
        self.assertFalse((self.root/manifest['output_leaf']).exists())
    def test_plain_manifest_is_not_provider_attachment(self):
        b={'profile':profile.PROFILE,'permission_registration_descriptor_sha256':'a'*64,'manifest_descriptor_sha256':'b'*64}
        text=profile.prompt({'action_profile_binding':b})
        self.assertNotIn(str(self.capture),text);self.assertNotIn('INVENTED ONLY',text)
        self.assertIn('NOT read or hash-verified',text)
    def test_sandbox_fixed_mounts_no_hosthome_network_or_callback(self):
        with mock.patch.object(guardian,'validate_sandbox_fds'):
            command=guardian.sandbox_command(self.manifest['runtime'],3,4,list(range(10,58)),'/fresh/output')
        self.assertIn('--unshare-all',command);self.assertIn('--clearenv',command)
        self.assertNotIn('/home',command);self.assertNotIn('--share-net',command);self.assertNotIn('sh',command)
        self.assertEqual(command.count('--ro-bind'),1)
        self.assertEqual(command.count('--ro-bind-fd'),48)
        self.assertEqual(command.count('--ro-bind-data'),2)
        self.assertNotIn('/proc/self/fd',str(command))
    def test_actual_linux_limits_and_namespace_or_exact_denial(self):
        code='import resource; resource.setrlimit(resource.RLIMIT_AS,(8589934592,)*2);resource.setrlimit(resource.RLIMIT_CPU,(120,)*2);print(resource.getrlimit(resource.RLIMIT_AS),resource.getrlimit(resource.RLIMIT_CPU))'
        result=subprocess.run([sys.executable,'-c',code],capture_output=True,text=True)
        self.assertEqual(result.returncode,0);self.assertIn('(8589934592, 8589934592)',result.stdout);self.assertIn('(120, 120)',result.stdout)
        # Public real namespace fixture: kernel-created DOWN tunnel devices are
        # permitted only with no usable non-loopback addresses/routes/egress.
        parent_namespace=os.readlink('/proc/self/ns/net')
        probe="""import errno,fcntl,json,os,socket,struct
assert os.readlink('/proc/self/ns/net') != PARENT_NAMESPACE
interfaces=socket.if_nameindex();assert any(name=='lo' for _,name in interfaces)
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as control:
 for _,name in interfaces:
  if name=='lo':continue
  request=struct.pack('256s',name.encode())
  flags=struct.unpack('H',fcntl.ioctl(control.fileno(),0x8913,request)[16:18])[0]
  assert not flags&1, 'non-loopback interface is UP'
  try:fcntl.ioctl(control.fileno(),0x8915,request)
  except OSError as exc:assert exc.errno in (errno.EADDRNOTAVAIL,errno.ENODEV)
  else:raise AssertionError('non-loopback IPv4 address')
for line in open('/proc/net/if_inet6'):
 fields=line.split();assert fields[-1]=='lo' and int(fields[0],16)==1
for line in list(open('/proc/net/route'))[1:]:assert line.split()[0]=='lo'
for line in open('/proc/net/ipv6_route'):
 fields=line.split();assert fields[-1]=='lo'
with socket.socket() as test:
 test.settimeout(0.2)
 try:test.connect(('192.0.2.1',9))
 except OSError as exc:assert exc.errno in (errno.ENETUNREACH,errno.EHOSTUNREACH)
 else:raise AssertionError('unexpected network egress')
print('distinct namespace; only loopback usable; no egress')
""".replace('PARENT_NAMESPACE',repr(parent_namespace))
        result=subprocess.run(['/usr/bin/bwrap','--unshare-all','--ro-bind','/usr','/usr','--ro-bind','/lib','/lib','--ro-bind','/lib64','/lib64',
            '--proc','/proc','--dev','/dev','/usr/bin/python3','-c',probe],capture_output=True,text=True,timeout=10)
        if result.returncode==0:self.assertEqual(result.stdout.strip(),'distinct namespace; only loopback usable; no egress')
        else:self.assertIn('Operation not permitted',result.stderr)

    def test_real_named_gate_preserves_generic_production_and_foreign_denials(self):
        repo=self.root/'repo';repo.mkdir()
        env=dict(os.environ,AI_TASK_GATES_DIR=str(self.root/'gates'),AI_REVIEW_LIFECYCLE_DIR=str(self.root/'reviews'))
        def command(*args):return subprocess.run(args,cwd=repo,env=env,capture_output=True)
        self.assertEqual(command('git','init','-q').returncode,0)
        command('git','config','user.name','Fixture');command('git','config','user.email','fixture@invalid.local')
        command('git','remote','add','origin','https://github.com/u2giants/theoracle')
        (repo/'.ai-devops').mkdir()
        (repo/'.ai-devops/task-gates.json').write_text(json.dumps({'schema_version':1,'gates':{'private-tooling':{'required':['synthetic-fixtures-only','oracle-native-alternate-descriptor-only-admission'],'forbidden_actions':[]}}}))
        command('git','add','.ai-devops/task-gates.json');command('git','commit','-qm','invented control only')
        gates=str(ROOT/'bin/ai-task-gates');self.assertEqual(command(gates,'start','--class','private-tooling').returncode,0)
        self.assertEqual(command(gates,'check','--before','production').returncode,3)
        # Missing native report/manifest always denies, even with exact opt-in.
        self.assertNotEqual(command(gates,'check','--before',profile.ACTION).returncode,0)
        command('git','remote','set-url','origin','https://github.com/popcre/designflow-backend')
        self.assertNotEqual(command(gates,'check','--before',profile.ACTION).returncode,0)

    def test_direct_guardian_cannot_self_issue(self):
        state=self.root/'state';state.write_text('{}');state.chmod(0o600)
        result=subprocess.run([sys.executable,str(ROOT/'tools/oracle_native_alternate_guardian.py'),'--admission',str(state)],
            input=profile.canonical(self.manifest),capture_output=True)
        self.assertNotEqual(result.returncode,0);self.assertNotIn(b'INVENTED',result.stderr)
        self.assertFalse(list(self.root.glob('*.spent')))

    def test_complete_seven_path_public_export_and_profile_preflight(self):
        from types import SimpleNamespace
        repo=self.root/'public-repo';repo.mkdir()
        def git(*args):return subprocess.check_output(['git','-C',str(repo),*args],stderr=subprocess.DEVNULL)
        git('init','-q');git('config','user.name','Invented Fixture');git('config','user.email','fixture@invalid.local')
        git('remote','add','origin','https://github.com/u2giants/theoracle')
        registry,_=profile.profile();paths=registry['paths']
        for name in paths:
            target=repo/name;target.parent.mkdir(parents=True,exist_ok=True)
            value=(ROOT/'tests/fixtures/oracle-native-public-producer.md').read_bytes() if name==scope.PUBLIC_PRODUCER_PATH else b'{}' if name.endswith('.json') else b'# Invented public source fixture only\n'
            if name=='.ai-devops/task-gates.json':value=json.dumps({'schema_version':1,'gates':{'private-tooling':{'required':['synthetic-fixtures-only','oracle-native-alternate-descriptor-only-admission'],'forbidden_actions':[]}}}).encode()
            target.write_bytes(value)
        git('add','--all');git('commit','-qm','public source fixture')
        pathsfile=self.root/'paths.json';pathsfile.write_text(json.dumps(paths));stage=self.root/'export'
        # Generic markdown and a foreign profile continue to refuse.
        with self.assertRaises(ValueError):scope.safe_path(scope.PUBLIC_PRODUCER_PATH)
        with self.assertRaises(ValueError):scope.public_document_context(repo,paths,'shared-db-770-isolated-timing-rehearsal-v1')
        scope.create(SimpleNamespace(source=str(repo),stage=str(stage),paths_file=str(pathsfile),base='HEAD',action_profile=profile.PROFILE))
        exported=scope.validate_snapshot(stage,git('rev-parse','HEAD').decode().strip())
        self.assertEqual(exported['paths'],paths)
        self.assertEqual((stage/scope.PUBLIC_PRODUCER_PATH).read_bytes(),(repo/scope.PUBLIC_PRODUCER_PATH).read_bytes())
        self.assertEqual(exported['document_profile'],profile.PROFILE)
        with mock.patch.dict(os.environ,{'AI_DEVOPS_TEST_MODE':'1','AI_TASK_GATES_DIR':str(self.root/'task-state')}):
            started=subprocess.run([str(ROOT/'bin/ai-task-gates'),'start','--class','private-tooling'],cwd=repo,capture_output=True)
            self.assertEqual(started.returncode,0,started.stderr)
            state=dict(normalized_upstream='https://github.com/u2giants/theoracle',provider='deepseek',implementer_engine='codex',review_mode='final-check',
                code_only_export=str(stage),code_only=exported,head=exported['original_head'],source_digest=exported['source_digest'],repository_root=str(repo))
            manifest=copy.deepcopy(self.manifest);manifest.update(source_head=state['head'],source_digest=state['source_digest'])
            manifest['output_parent']['stat']=profile.descriptor_stat(str(self.root),True)
            bound=profile.binding(state,manifest)
            self.assertEqual(bound['capture_count'],33)
            self.assertFalse(bound['root_action_authority'])
            self.assertFalse(bound['capture_byte_hashes_verified'])
            evidence=profile.evidence_projection(bound)
            self.assertEqual(evidence['runtime_identity']['sandbox_binary']['public_path'],'/usr/bin/bwrap')
            self.assertEqual(evidence['limits'],profile.LIMITS)
            self.assertNotIn(str(self.capture),json.dumps(evidence))

        # This is source export only; no provider completion, registration or admission exists.
        self.assertFalse(list(self.root.glob('*.spent')))
        (repo/scope.PUBLIC_PRODUCER_PATH).write_text('private substitution must refuse')
        with self.assertRaises(ValueError):scope.validate_snapshot(stage)


    def test_arbitrary_sandbox_binary_denies_before_private_content_open(self):
        m=copy.deepcopy(self.manifest);m['runtime']['bwrap']=str(self.capture)
        opened=[];real=os.open;private={i['path'] for i in m['controls']+m['captures']}
        def checked(path,flags,*a,**kw):
            if str(path) in private and not flags&os.O_PATH:opened.append(str(path))
            return real(path,flags,*a,**kw)
        with mock.patch.object(os,'open',side_effect=checked):
            with self.assertRaisesRegex(ValueError,'fixed public OS'):profile.validate_manifest(m,self.now)
        self.assertEqual(opened,[])
        with mock.patch.object(guardian,'validate_sandbox_fds'):
            self.assertEqual(guardian.sandbox_command(m['runtime'],3,4,list(range(10,58)),'c')[0],'/usr/bin/bwrap')
        m['runtime']['bwrap']='/usr/bin/bwrap';m['runtime']['bwrap_sha256']='0'*64
        with self.assertRaisesRegex(ValueError,'public executable changed'):profile.validate_manifest(m,self.now)

    def test_existing_lock_must_be_owned_private_regular_and_unaliased(self):
        from types import SimpleNamespace
        lock=self.root/'lock';lock.write_bytes(b'');lock.chmod(0o600);fd=os.open(lock,os.O_RDWR)
        try:
            profile.validate_lock_fd(fd)
            lock.chmod(0o666)
            with self.assertRaises(ValueError):profile.validate_lock_fd(fd)
            lock.chmod(0o600);info=os.fstat(fd)
            for key,value in (('st_uid',os.getuid()+1),('st_nlink',2)):
                fields={k:getattr(info,k) for k in ('st_mode','st_uid','st_nlink')};fields[key]=value
                with mock.patch.object(os,'fstat',return_value=SimpleNamespace(**fields)):
                    with self.assertRaises(ValueError):profile.validate_lock_fd(fd)
        finally:os.close(fd)

    def test_full_postclaim_stat_includes_uid_mode_and_link_count(self):
        from types import SimpleNamespace
        item=self.manifest['captures'][0];fd=os.open(item['path'],os.O_RDONLY|os.O_NOFOLLOW)
        try:
            guardian.validate_input_fd(fd,item);info=os.fstat(fd)
            keys=('st_dev','st_ino','st_uid','st_mode','st_size','st_mtime_ns','st_ctime_ns','st_nlink')
            for key,value in (('st_uid',info.st_uid+1),('st_mode',info.st_mode|0o020),('st_nlink',2)):
                fields={k:getattr(info,k) for k in keys};fields[key]=value
                with mock.patch.object(os,'fstat',return_value=SimpleNamespace(**fields)):
                    with self.assertRaises(ValueError):guardian.validate_input_fd(fd,item)
        finally:os.close(fd)



    def test_exclusive_metadata_publisher_is_not_authority_and_preserves_collisions(self):
        descriptors=self.root/'known-descriptor-metadata';descriptors.mkdir(mode=0o700)
        self.manifest['output_parent']['stat']=profile.descriptor_stat(str(self.root),True)
        controls=profile.control_metadata
        with mock.patch.dict(os.environ,{'AI_DEVOPS_TEST_MODE':'1','AI_ORACLE_NATIVE_TEST_DESCRIPTOR_ROOT':str(descriptors)}):
            invalid={**self.manifest,'source_text':'INVENTED RAW CAPTURE'}
            with self.assertRaises(ValueError):controls.publish_descriptor(invalid,profile.PROFILE)
            self.assertFalse(list(descriptors.iterdir()))
            for header in ({'profile':'unknown'},{'action_id':'wrong'},{'schema_version':True}):
                with self.assertRaises(ValueError):controls.publish_descriptor({**self.manifest,**header},profile.PROFILE)
            path=controls.publish_descriptor(self.manifest,profile.PROFILE)
            raw=path.read_bytes();self.assertEqual(path.stat().st_mode&0o777,0o600)
            self.assertEqual(path.parent.stat().st_mode&0o777,0o700)
            self.assertEqual(profile.metadata(path),self.manifest)
            self.assertFalse(list(self.root.glob('*.spent')))
            with self.assertRaises(FileExistsError):controls.publish_descriptor(self.manifest,profile.PROFILE)
            self.assertEqual(path.read_bytes(),raw)
            crashed='b'*32;(descriptors/profile.PROFILE/crashed).mkdir(mode=0o700)
            with self.assertRaises(FileExistsError):controls.publish_descriptor({**self.manifest,'action_id':crashed},profile.PROFILE)
            self.assertFalse(list((descriptors/profile.PROFILE/crashed).iterdir()))
            action='c'*32;directory=descriptors/profile.PROFILE;directory.chmod(0o755)
            with self.assertRaises(ValueError):controls.publish_descriptor({**self.manifest,'action_id':action},profile.PROFILE)
            directory.chmod(0o700);moved=directory.with_name('moved');directory.rename(moved);directory.symlink_to(moved,target_is_directory=True)
            with self.assertRaises(OSError):controls.publish_descriptor({**self.manifest,'action_id':action},profile.PROFILE)
            self.assertEqual(path.parent.name,self.manifest['action_id'])


    def clone_public_runtime(self):
        import shutil
        root=self.root/'staged-public';shutil.copytree(self.public_root,root)
        receipt=copy.deepcopy(self.public_receipt);receipt['root']=str(root)
        path=Path(str(root)+'.public-runtime.json');path.write_text(json.dumps(receipt));path.chmod(0o600)
        return root,receipt,path

    def test_trojan_staged_stdlib_self_claimed_closure_denies_before_claim(self):
        runtime=profile.public_runtime_module();root,receipt,path=self.clone_public_runtime()
        target=next(rel for rel in receipt['origins'] if rel.endswith('.py'))
        (root/target).write_bytes(b'# invented trojan staged stdlib\n')
        rows,total=runtime.staged_rows(root);receipt.update(closure_sha256=runtime.seal(runtime.canonical(rows)),bytes=total);path.write_text(json.dumps(receipt))
        with self.assertRaisesRegex(ValueError,'differ from live OS'):runtime.verify_recipe(root)
        self.assertFalse(list(self.root.glob('*.spent')))

    def test_staged_symlink_fifo_socket_and_device_denies_without_private_open(self):
        import socket,stat
        from types import SimpleNamespace
        runtime=profile.public_runtime_module();root,receipt,path=self.clone_public_runtime()
        rel=next(rel for rel in receipt['origins'] if rel.endswith('.py'));target=root/rel;original=target.read_bytes()
        private_opens=[];real_open=os.open
        def checked(name,flags,*args,**kwargs):
            if str(name)==str(self.capture) and not flags&os.O_PATH:private_opens.append(str(name))
            return real_open(name,flags,*args,**kwargs)
        target.unlink();target.symlink_to(self.capture)
        with mock.patch.object(os,'open',side_effect=checked):
            with self.assertRaises(ValueError):runtime.verify_recipe(root)
        self.assertEqual(private_opens,[]);target.unlink();os.mkfifo(target,0o600)
        with self.assertRaises(ValueError):runtime.verify_recipe(root)
        target.unlink();sock=socket.socket(socket.AF_UNIX)
        parent_fd=os.open(target.parent,os.O_PATH|os.O_DIRECTORY|os.O_NOFOLLOW)
        try:
            sock.bind('/proc/self/fd/'+str(parent_fd)+'/'+target.name);target.chmod(0o600)
            with mock.patch.object(os,'open',side_effect=checked):
                with self.assertRaises(ValueError):runtime.verify_recipe(root)
            self.assertEqual(private_opens,[])
        finally:
            sock.close();os.close(parent_fd);target.unlink(missing_ok=True)
        target.write_bytes(original);target.chmod(0o644)
        real_stat=os.stat
        def special(name,*args,**kwargs):
            info=real_stat(name,*args,**kwargs)
            if str(name)==target.name:
                fields={key:getattr(info,key) for key in ('st_uid','st_mode','st_nlink')};fields['st_mode']=stat.S_IFCHR|0o644
                return SimpleNamespace(**fields)
            return info
        with mock.patch.object(os,'stat',side_effect=special):
            with self.assertRaises(ValueError):runtime.staged_rows(root)
        self.assertFalse(list(self.root.glob('*.spent')))

    def test_staged_inventory_and_origin_substitution_cannot_admit(self):
        runtime=profile.public_runtime_module();root,receipt,path=self.clone_public_runtime()
        (root/'unexpected-empty').mkdir(mode=0o700)
        with self.assertRaisesRegex(ValueError,'unapproved runtime directory'):runtime.verify_recipe(root)
        (root/'unexpected-empty').rmdir()
        rel=next(rel for rel in receipt['origins'] if rel.endswith('.py'))
        receipt['origins'][rel]['origin']='/usr/bin/python3';path.write_text(json.dumps(receipt))
        with self.assertRaisesRegex(ValueError,'independently derived'):runtime.verify_recipe(root)
        self.assertFalse(list(self.root.glob('*.spent')))

    def test_ldd_substitution_denies_before_execution_or_private_opens(self):
        runtime=profile.public_runtime_module()
        with self.assertRaises(ValueError):runtime.public_tool_identity('arbitrary-sender')
        with self.assertRaises(ValueError):runtime.public_tool_identity('ldd','0'*64)
        with mock.patch.object(runtime,'public_tool_identity',side_effect=ValueError('untrusted ldd identity')),mock.patch.object(runtime.subprocess,'run',side_effect=AssertionError('unverified ldd executed')):
            with self.assertRaisesRegex(ValueError,'untrusted ldd'):runtime.expected_origins()
        self.assertFalse(list(self.root.glob('*.spent')))

    def test_actual_public_runtime_preparation_is_non_authorizing(self):
        probe = '''import sys,pathlib;sys.path.insert(0,"tools")
import oracle_native_alternate_runtime as runtime
import os;os.umask(0)
root=pathlib.Path(sys.argv[1]);receipt=runtime.prepare(root)
runtime.verify_recipe(root)
assert receipt["kind"]=="NONAUTHORIZING_PUBLIC_OS_STDLIB_PREPARATION"
assert receipt["bytes"]<=256*1024**2
assert all(p.stat().st_mode&0o777==0o700 for p in root.rglob('*') if p.is_dir())
assert not any("sitecustomize" in p or "site-packages" in p or "config-" in p for p in receipt["origins"])
'''
        result=subprocess.run(['/usr/bin/python3','-c',probe,str(self.root/'public-runtime')],cwd=ROOT,
            capture_output=True,text=True,timeout=30)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertFalse(list(self.root.glob('*.spent')))


if __name__=='__main__':unittest.main()
