"""Offline fixtures for the closed native generated gate; no app/SQL/provider."""
import copy
import contextlib
import io
import types
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

sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('generated',ROOT/'tools/generated_definition_action.py')
g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)


class GeneratedAction(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.top=Path(self.temp.name);self.repo=self.top/'app';self.repo.mkdir()
        self.env=mock.patch.dict(os.environ,{'AI_TASK_GATES_DIR':str(self.top/'state'),'AI_TASK_GATES_FILE':str(ROOT/'config/task-gates.json')})
        self.env.start();self.addCleanup(self.env.stop)
        for name in g.SOURCE:
            p=self.repo/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_text('fixed generated source '+name);p.chmod(0o644)
        self.write(self.repo/'.gitignore',b'node_modules/\n')
        self.consumer={'schema_version':1,'paths':[{'glob':'plan_*.md','class':'reviewer-safety'}],
            'gates':{'reviewer-safety':{'required':['repository-rulebook-full-treatment'],'forbidden_actions':[]}}}
        self.json(self.repo/g.CONSUMER,self.consumer)
        self.git('init','-q');self.git('config','user.name','Fixture');self.git('config','user.email','fixture@example.invalid')
        self.git('remote','add','origin','https://github.com/popcre/designflow-backend.git')
        self.git('add','.');self.git('commit','-qm','true base');self.base=self.git('rev-parse','HEAD').strip()
        p=subprocess.run([str(ROOT/'bin/ai-task-gates'),'start','--class','reviewer-safety','--base',self.base,'--reason','offline fixture'],cwd=self.repo,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        self.assertEqual(p.returncode,0,p.stderr.decode())
        current=copy.deepcopy(self.consumer);current['gates']['reviewer-safety']['required'].append(g.GATE)
        self.json(self.repo/g.CONSUMER,current);self.write(self.repo/'plan_4250_generated_definition_qualification.md',b'fixed generated-only boundary')
        self.git('add','.');self.git('commit','-qm','selected opt in')
        self.head=self.git('rev-parse','HEAD').strip()
        self.report=self.top/'report.md';self.write(self.report,b'APPROVE protected source',0o600)
        self.state={'repository_root':str(self.repo),'head':self.head,'source_digest':g.IO.source_digest(self.repo),
            'status':'completed','verdict':'APPROVE','stale':False,'failure_class':None,'provider':'muse','implementer_engine':'codex',
            'review_mode':'final-check','tests':{'exit':0,'output_sha256':'a'*64},'report_path':str(self.report),'report_sha256':g.sha(self.report.read_bytes())}
        with mock.patch.object(g,'read',side_effect=lambda p,*a,**k:Path(p).read_bytes()):
            self.profile=copy.deepcopy(g.registry())
        self.profile['pins']['fixture_module_sha256']=g.sha((self.repo/'scripts/cutover-synthetic/generated-definition-fixtures.cjs').read_bytes())
        self.identity=g.source_identity(self.repo,self.state,self.profile)
        self.binary=self.top/'node24/bin/node';self.write(self.binary,b'fixed verified Node',0o755)
        self.npm=self.top/'node24/lib/node_modules/npm';self.json(self.npm/'package.json',{'version':'11.19.1'})
        self.deps=self.repo/'node_modules';self.json(self.deps/'pg/package.json',{'version':'8.23.1'});self.write(self.deps/'pg/lib/index.js',b'fixed pg client')
        (self.deps/'.bin').mkdir();(self.deps/'.bin/pg').symlink_to('../pg/lib/index.js')
        self.depdesc=self.inventory(self.deps,'deps');self.npmdesc=self.inventory(self.npm,'npm')
        pin=self.profile['pins'];pin.update(node_sha256=g.sha(self.binary.read_bytes()),package_sha256=g.sha((self.repo/'package.json').read_bytes()),
            npm_inventory_sha256=self.npmdesc['sha256'],dependency_inventory_sha256=self.depdesc['sha256'],pg_entry_sha256=g.sha((self.deps/'pg/lib/index.js').read_bytes()))
        self.log=self.top/'install.log';self.write(self.log,b'fixture install exit0',0o600)
        self.receipt={'scope':'fixed generated fixture dependency qualification ONLY; no Docker/SQL/provider/admission/production action',
            'sourceCommit':self.head,'clean':True,'packageSha256':pin['package_sha256'],
            'node':{'binary':str(self.binary),'version':'v24.22.0','sha256':pin['node_sha256']},
            'npm':{'version':'11.19.1',**self.npmdesc},'dependencies':self.depdesc,
            'pg':{'version':'8.23.1','entry':str(self.deps/'pg/lib/index.js'),'entrySha256':pin['pg_entry_sha256'],'importCheck':True},
            'sourceClosureSha256':self.identity['source_closure_sha256'],'fixtureSha256':pin['fixture_sha256'],'image':pin['image'],
            'resources':copy.deepcopy(g.RESOURCES),'limits':copy.deepcopy(g.LIMITS),'NODE_PATH':False,'admissionSelected':False,'execution':False,
            'install':{'exit':0,'log':str(self.log),'logSha256':g.sha(self.log.read_bytes()),'packagesAdded':756,
              'scriptPolicyWarnings':['bcrypt@6.0.0 install not covered by npm allowScripts','protobufjs@7.6.6 postinstall not covered by npm allowScripts'],
              'wholeApplicationRuntimeQualified':False}}
        self.result=self.top/'result.json'
        self.record={'admissionSchemaVersion':1,'kind':'generated-definition-qualification-admission','stage':'generated-only','admissionId':'a'*32,
            'source':{'repository':g.REPOSITORY,'commit':self.head,'closureSha256':self.identity['source_closure_sha256']},
            'fixture':{'id':g.FIXTURE,'sha256':pin['fixture_sha256']},'image':{'digest':pin['image']},'resources':copy.deepcopy(g.RESOURCES),'limits':copy.deepcopy(g.LIMITS),
            'output':{'resultPath':str(self.result),'policy':'exclusive-0600-sanitized'},'cleanup':{'policy':'owned-nonce-only','required':True}}
        self.recordpath=self.top/'admission.json';self.runtimepath=self.top/'runtime.json'
        self.refresh()
        patch=mock.patch.object(g,'registry',return_value=self.profile);patch.start();self.addCleanup(patch.stop)
        patch=mock.patch.object(g,'installed_enforcement',return_value={'kind':'VERIFIED_INSTALLED_SOURCE'});patch.start();self.addCleanup(patch.stop)

    def write(self,p,b,mode=0o644):
        p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b);p.chmod(mode)

    def json(self,p,value):
        self.write(p,json.dumps(value,separators=(',',':')).encode(),0o600)

    def git(self,*args):
        return subprocess.check_output(['/usr/bin/git','-C',str(self.repo),*args],stderr=subprocess.PIPE).decode()

    def inventory(self,root,label):
        rows=[]
        for p in sorted(root.rglob('*')):
            rel=p.relative_to(root).as_posix()
            if p.is_symlink():rows.append({'path':rel,'symlink':os.readlink(p),'resolvedTarget':str(p.resolve())})
            elif p.is_file():rows.append({'path':rel,'sha256':g.sha(p.read_bytes()),'bytes':p.stat().st_size})
        file=self.top/(label+'-files.json');self.json(file,rows)
        return {'root':str(root),'manifest':str(file),'sha256':g.sha(file.read_bytes()),'entries':len(rows),'externalSymlinks':0}

    def refresh(self):
        self.json(self.recordpath,self.record);self.json(self.runtimepath,self.receipt)
        self.envelope={'schema_version':1,'fixture_id':g.FIXTURE,'repository':g.REPOSITORY,'source_head':self.head,
            'source_closure_sha256':self.identity['source_closure_sha256'],'fixture_sha256':self.profile['pins']['fixture_sha256'],
            'admission_path':str(self.recordpath),'admission_sha256':g.sha(self.recordpath.read_bytes()),
            'runtime_receipt_path':str(self.runtimepath),'runtime_receipt_sha256':g.sha(self.runtimepath.read_bytes())}

    def validate(self):return g.validate(self.envelope,self.state)

    def test_exact_fixture_and_repeated_validation_are_audit_only(self):
        first=self.validate();self.assertEqual(first,self.validate());self.assertTrue(first['audit_only']);self.assertFalse(first['process_execution_authorized'])
        self.assertFalse(self.result.exists());self.assertNotIn('consumed',first)

    def test_closed_input_shape_and_numeric_types(self):
        for key,value in [('fixture_id','shared-db-770-isolated-timing-rehearsal-v1'),('repository','popcre/designflow-tracking'),('schema_version',True),('sql','SELECT 1'),('host','localhost')]:
            saved=copy.deepcopy(self.envelope);self.envelope[key]=value
            with self.assertRaises(ValueError):self.validate()
            self.envelope=saved
        for raw in [b'{"fixture_id":"x","fixture_id":"y"}',b'{"x":"\\ud800"}',b'{"x":NaN}',b'\xef\xbb\xbf{}']:
            with self.assertRaises((ValueError,UnicodeError)):g.decode(raw)

    def test_admission_resources_and_private_profile_cannot_authorize(self):
        for mutate in [lambda r:r.update(kind='private-profile'),lambda r:r['resources'].update(cpu=True),lambda r:r['limits'].update(wallMs=999999),lambda r:r['cleanup'].update(required=False),lambda r:r['source'].update(commit='f'*40),lambda r:r['fixture'].update(sha256='0'*64)]:
            saved=copy.deepcopy(self.record);mutate(self.record);self.refresh()
            with self.assertRaises(ValueError):self.validate()
            self.record=saved
        self.refresh()

    def test_source_seal_and_passing_tests_are_required(self):
        for key,value in [('verdict','REJECT'),('stale',True),('provider','codex'),('review_mode','plan-review'),('head','f'*40),('source_digest','f'*64),('code_only',{'export':True})]:
            saved=copy.deepcopy(self.state);self.state[key]=value
            with self.assertRaises(ValueError):self.validate()
            self.state=saved
        self.state['tests']['exit']=1
        with self.assertRaises(ValueError):self.validate()

    def test_changed_unreviewed_and_deleted_contributors_refuse(self):
        self.write(self.repo/'AGENTS.md',b'unsafe extra');self.git('add','.');self.git('commit','-qm','unapproved rules')
        self.state['head']=self.git('rev-parse','HEAD').strip();self.state['source_digest']=g.IO.source_digest(self.repo)
        with self.assertRaises(ValueError):g.source_identity(self.repo,self.state,self.profile)
        self.git('rm','package.json');self.git('commit','-qm','delete runtime source')
        self.state['head']=self.git('rev-parse','HEAD').strip()
        with self.assertRaises(ValueError):g.source_identity(self.repo,self.state,self.profile)

    def test_changed_compiled_fixture_module_refuses_even_on_reviewed_head(self):
        self.write(self.repo/'scripts/cutover-synthetic/generated-definition-fixtures.cjs',b'changed fixed fixture')
        self.git('add','.');self.git('commit','-qm','different fixture needs installed config qualification')
        self.state['head']=self.git('rev-parse','HEAD').strip()
        with self.assertRaisesRegex(ValueError,'fixed fixture module'):
            g.source_identity(self.repo,self.state,self.profile)

    def test_extra_consumer_policy_change_refuses(self):
        p=self.repo/g.CONSUMER;x=json.loads(p.read_text());x['paths']=[];self.json(p,x);self.git('add','.');self.git('commit','-qm','weaken rule')
        self.state['head']=self.git('rev-parse','HEAD').strip()
        with self.assertRaises(ValueError):g.source_identity(self.repo,self.state,self.profile)

    def test_explicit_original_consumer_prohibition_is_not_released(self):
        self.git('checkout','-qb','explicit-prohibition',self.base)
        before=copy.deepcopy(self.consumer);before['gates']['reviewer-safety']['forbidden_actions']=['database']
        self.json(self.repo/g.CONSUMER,before);self.git('add','.');self.git('commit','-qm','original explicit prohibition')
        base=self.git('rev-parse','HEAD').strip()
        p=subprocess.run([str(ROOT/'bin/ai-task-gates'),'start','--class','reviewer-safety','--base',base],cwd=self.repo,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        self.assertEqual(p.returncode,0)
        current=copy.deepcopy(before);current['gates']['reviewer-safety']['required'].append(g.GATE)
        self.json(self.repo/g.CONSUMER,current);self.git('add','.');self.git('commit','-qm','opt in cannot subtract local prohibition')
        self.state['head']=self.git('rev-parse','HEAD').strip()
        with self.assertRaisesRegex(ValueError,'explicit consumer'):
            g.source_identity(self.repo,self.state,self.profile)

    def test_redirected_git_or_runtime_environment_refuses(self):
        for key in ('GIT_DIR','GIT_CONFIG_COUNT','GIT_GRAFT_FILE','NODE_PATH','PGHOST','DOCKER_HOST','AI_TASK_GATES_FILE'):
            with mock.patch.dict(os.environ,{key:'/foreign'}):
                with self.assertRaises(ValueError):self.validate()

    def test_raw_git_replace_and_foreign_origin_refuse(self):
        self.git('update-ref','refs/replace/'+self.head,self.head)
        with self.assertRaises(ValueError):g.source_identity(self.repo,self.state,self.profile)
        self.git('update-ref','-d','refs/replace/'+self.head)
        self.git('remote','set-url','origin','https://github.com/foreign/designflow-backend.git')
        with self.assertRaises(ValueError):g.source_identity(self.repo,self.state,self.profile)

    def test_dependency_mutation_and_omission_refuse(self):
        entry=self.deps/'pg/lib/index.js';self.write(entry,b'changed runtime')
        with self.assertRaises(ValueError):self.validate()
        self.write(entry,b'fixed pg client');self.write(self.deps/'extra.js',b'omitted payload')
        with self.assertRaises(ValueError):self.validate()

    def test_self_consistent_caller_inventory_cannot_change_installed_pin(self):
        self.write(self.deps/'pg/lib/index.js',b'forged pg client')
        self.receipt['dependencies']=self.inventory(self.deps,'forged')
        self.refresh()
        with self.assertRaises(ValueError):self.validate()

    def test_dependency_external_symlink_and_special_file_refuse(self):
        self.write(self.top/'outside.js',b'outside');(self.deps/'outside.js').symlink_to(self.top/'outside.js')
        with self.assertRaises(ValueError):self.validate()
        (self.deps/'outside.js').unlink();os.mkfifo(self.deps/'pipe')
        with self.assertRaises(ValueError):self.validate()

    def test_admission_symlink_hardlink_and_existing_result_refuse(self):
        self.recordpath.chmod(0o644)
        with self.assertRaises(ValueError):self.validate()
        self.recordpath.chmod(0o600);os.link(self.recordpath,self.top/'hard')
        with self.assertRaises(ValueError):self.validate()
        (self.top/'hard').unlink();self.write(self.result,b'foreign',0o600)
        with self.assertRaises(ValueError):self.validate()

    def test_source_move_during_final_validation_refuses(self):
        original=g.source_identity;calls=0
        def move(*args):
            nonlocal calls
            calls+=1
            if calls==2:
                self.write(self.repo/'plan_4250_generated_definition_qualification.md',b'changed after validation')
            return original(*args)
        with mock.patch.object(g,'source_identity',side_effect=move):
            with self.assertRaises(ValueError):self.validate()

    def test_runtime_and_inventory_bounds_refuse(self):
        for mutate in [lambda r:r['node'].update(sha256='0'*64),lambda r:r['pg'].update(version='8.0.0'),lambda r:r['dependencies'].update(entries=32769),lambda r:r.update(NODE_PATH=True),lambda r:r['install'].update(wholeApplicationRuntimeQualified=True)]:
            saved=copy.deepcopy(self.receipt);mutate(self.receipt);self.refresh()
            with self.assertRaises(ValueError):self.validate()
            self.receipt=saved

    def test_native_cli_repeats_fresh_validation_without_lifecycle_consumption(self):
        statepath=self.top/'lifecycle.json';self.json(statepath,self.state);before=statepath.read_bytes()
        outputs=[]
        for _ in range(2):
            stream=types.SimpleNamespace(buffer=io.BytesIO(json.dumps(self.envelope).encode()))
            text=io.StringIO()
            with mock.patch.object(sys,'stdin',stream),contextlib.redirect_stdout(text):
                self.assertEqual(g.main(['generated-preaction',str(statepath)]),0)
            outputs.append(json.loads(text.getvalue()));self.assertEqual(statepath.read_bytes(),before)
        self.assertEqual(outputs[0],outputs[1]);self.assertTrue(outputs[0]['audit_only']);self.assertFalse(self.result.exists())

    def test_runtime_changes_after_a_file_hash_are_detected(self):
        original=g.read;changed=False;target=self.deps/'pg/lib/index.js'
        def mutate(p,*args,**kwargs):
            nonlocal changed
            raw=original(p,*args,**kwargs)
            if Path(p)==target and not changed:
                changed=True;target.write_bytes(b'changed after its read')
            return raw
        with mock.patch.object(g,'read',side_effect=mutate):
            with self.assertRaises(ValueError):self.validate()

    def test_wrong_platform_and_fake_action_profile_have_no_fallback(self):
        with mock.patch.object(g.sys,'platform','win32'):
            with self.assertRaises(ValueError):self.validate()
        self.state['action_profile_binding']={'profile':'shared-db-770-isolated-timing-rehearsal-v1'}
        with self.assertRaises(ValueError):self.validate()

    def test_installed_enforcement_is_mandatory_without_runtime_test_bypass(self):
        with mock.patch.object(g,'installed_enforcement',side_effect=ValueError('not installed')):
            with self.assertRaises(ValueError):self.validate()
        self.assertNotIn('AI_DEVOPS_TEST_MODE',Path(g.__file__).read_text())


if __name__=='__main__':unittest.main()
