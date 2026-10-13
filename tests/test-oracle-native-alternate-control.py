#!/usr/bin/env python3
"""Known control storage fixtures; no actual platform files/permission issuance."""
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
spec=importlib.util.spec_from_file_location('control',ROOT/'tools/oracle_native_alternate_control.py')
control=importlib.util.module_from_spec(spec);spec.loader.exec_module(control)

class Controls(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name);self.root.chmod(0o700)
        self.lifecycle=self.root/'lifecycle';self.lifecycle.mkdir(mode=0o700)
        self.descriptors=self.root/'descriptors';self.descriptors.mkdir(mode=0o700)
        self.env=mock.patch.dict(os.environ,{'AI_DEVOPS_TEST_MODE':'1','AI_ORACLE_NATIVE_TEST_LIFECYCLE_ROOT':str(self.lifecycle),'AI_ORACLE_NATIVE_TEST_DESCRIPTOR_ROOT':str(self.descriptors)})
        self.env.start()
        self.path=self.lifecycle/'runs'/control.KEY/'deepseek'/'codex'/'code-only-1791927000-123-42.json'
        self.path.parent.mkdir(parents=True)
        for directory in (self.lifecycle/'runs',self.lifecycle/'runs'/control.KEY,self.lifecycle/'runs'/control.KEY/'deepseek'):directory.chmod(0o755)
        self.path.parent.chmod(0o700)
        self.path.write_bytes(b'{"NONAUTHORIZING_FIXTURE":true}');self.path.chmod(0o600)
    def tearDown(self):self.env.stop();self.temp.cleanup()
    def deny(self,path):
        reader=mock.Mock(side_effect=AssertionError('must not read candidate bytes'))
        with self.assertRaises((ValueError,OSError)):control.read_lifecycle(path,reader)
        reader.assert_not_called()
    def test_current_native_pattern_stat_only_and_legitimate_0755_intermediates(self):
        calls=[];real=os.open
        def opened(path,flags,*args,**kw):calls.append(flags);return real(path,flags,*args,**kw)
        with mock.patch.object(os,'open',side_effect=opened):result=control.lifecycle(self.path)
        self.assertTrue(all(flags&os.O_PATH for flags in calls));self.assertEqual(len(result),8)
        reader=mock.Mock(return_value=b'INVENTED METADATA');self.assertEqual(control.read_lifecycle(self.path,reader),b'INVENTED METADATA')
    def test_raw_capture_foreign_readme_bad_basename_tag_provider_and_repository_deny_before_read(self):
        raw=self.root/'group-0-page-1.json';raw.write_bytes(b'INVENTED RAW CAPTURE');raw.chmod(0o600)
        self.deny(raw)
        for path in (self.path.with_name('README.md'),self.path.with_name('capture.json'),self.path.with_name('code-only-0-123-42.json'),
            self.path.with_name('code-only-text.json'),self.path.parent.parent/'deepseek'/self.path.name,
            self.lifecycle/'runs'/('b'*64)/'deepseek'/'codex'/self.path.name,
            self.lifecycle/'runs'/control.KEY/'foreign'/'codex'/self.path.name):self.deny(path)
    def test_file_modes_links_foreign_uid_and_parent_modes_deny_before_read(self):
        self.path.chmod(0o644);self.deny(self.path);self.path.chmod(0o600)
        alias=self.root/'alias';os.link(self.path,alias);self.deny(self.path);alias.unlink()
        self.path.parent.chmod(0o755);self.deny(self.path);self.path.parent.chmod(0o700)
        self.lifecycle.chmod(0o755);self.deny(self.path);self.lifecycle.chmod(0o700)
        real=os.fstat
        def foreign(fd):
            st=real(fd);fields={k:getattr(st,k) for k in ('st_dev','st_ino','st_uid','st_mode','st_nlink','st_size','st_mtime_ns','st_ctime_ns')}
            fields['st_uid']=st.st_uid+1;return SimpleNamespace(**fields)
        with mock.patch.object(os,'fstat',side_effect=foreign):self.deny(self.path)
    def test_all_linked_parent_and_renamed_leaf_cases_deny_before_read(self):
        moved=self.path.parent.with_name('moved');self.path.parent.rename(moved);self.path.parent.symlink_to(moved,target_is_directory=True)
        self.deny(self.path);self.path.parent.unlink();moved.rename(self.path.parent)
        target=self.path.with_name('renamed.json');self.path.rename(target);self.deny(self.path)
        self.path.symlink_to(target);self.deny(self.path)
    def test_actual_home_comes_from_pwd_and_actualmode_overrides_deny(self):
        with mock.patch.object(control.pwd,'getpwuid',return_value=SimpleNamespace(pw_dir=str(self.root/'real-home'))):
            with mock.patch.dict(os.environ,{'AI_DEVOPS_TEST_MODE':'0','AI_ORACLE_NATIVE_TEST_LIFECYCLE_ROOT':'','AI_ORACLE_NATIVE_TEST_DESCRIPTOR_ROOT':'','HOME':str(self.root/'forged-home'),'AI_REVIEW_LIFECYCLE_DIR':''}):
                self.assertEqual(control.roots()[0],self.root/'real-home/.local/state/ai-devops/review-lifecycle')
                self.deny(self.path)
            with mock.patch.dict(os.environ,{'AI_DEVOPS_TEST_MODE':'0'}):self.deny(self.path)
    def test_metadata_move_during_reader_is_refused(self):
        def reader(_):self.path.write_bytes(b'CHANGED METADATA');return b'OLD METADATA'
        with self.assertRaisesRegex(ValueError,'moved'):control.read_lifecycle(self.path,reader)
    def test_descriptor_fixed_profile_action_basename_before_and_after_read(self):
        for profile in control.PROFILES:
            action='a'*32;parent=self.descriptors/profile/action;parent.mkdir(parents=True);parent.parent.chmod(0o700);parent.chmod(0o700)
            path=parent/('oracle-native-action'+('-v2' if profile.endswith('v2') else '')+'.manifest.json');path.write_bytes(b'INVENTED METADATA');path.chmod(0o600)
            value={'profile':profile,'action_id':action}
            self.assertEqual(control.read_descriptor(path,profile,lambda _:json.dumps(value).encode(),json.loads),value)
            for invalid in (path.with_name('rawcapture.json'),self.root/path.name):
                reader=mock.Mock(side_effect=AssertionError('raw bytes'))
                with self.assertRaises((ValueError,OSError)):control.read_descriptor(invalid,profile,reader,json.loads)
                reader.assert_not_called()
            with self.assertRaisesRegex(ValueError,'directory differs'):
                control.read_descriptor(path,profile,lambda _:json.dumps({**value,'action_id':'b'*32}).encode(),json.loads)
    def test_normal_oracle_cwd_auto_route_refuses_wrong_state_before_generic_reader(self):
        repo=self.root/'public-oracle';repo.mkdir()
        for args in [('init','-q'),('remote','add','origin','https://github.com/u2giants/theoracle')]:subprocess.run(['/usr/bin/git','-C',str(repo),*args],check=True,capture_output=True)
        capture=self.root/'capture.json';capture.write_bytes(b'INVENTED_CAPTURE_SENTINEL');capture.chmod(0o600)
        result=subprocess.run([sys.executable,str(ROOT/'tools/review_action_profile.py'),'preaction',str(capture)],cwd=repo,env={**os.environ,'GIT_DIR':'/bad/inherited/path'},capture_output=True)
        self.assertNotEqual(result.returncode,0);self.assertIn(b'Oracle native metadata routing refused',result.stderr)
        self.assertNotIn(b'Traceback',result.stderr);self.assertNotIn(b'INVENTED_CAPTURE_SENTINEL',result.stderr)
        self.path.write_text(json.dumps({'NONAUTHORIZING_FIXTURE':True,'status':'running','action_profile_binding':{'profile':'oracle-native-alternate-serialization-v2'}}))
        result=subprocess.run([sys.executable,str(ROOT/'tools/review_action_profile.py'),'finish',str(self.path)],cwd=repo,input=b'{}',capture_output=True)
        self.assertNotIn(b'Oracle native metadata routing refused',result.stderr)
        self.assertNotIn(b'Traceback',result.stderr)

    def test_oracle_cwd_and_lexical_auto_route_call_zero_generic_readers_for_misroutes(self):
        spec=importlib.util.spec_from_file_location('routing',ROOT/'tools/review_action_profile.py')
        routing=importlib.util.module_from_spec(spec);spec.loader.exec_module(routing)
        repo=self.root/'public-repo';repo.mkdir()
        for args in [('init','-q'),('remote','add','origin','git@GitHub.COM:u2giants/theoracle.git')]:subprocess.run(['/usr/bin/git','-C',str(repo),*args],check=True,capture_output=True)
        capture=self.root/'capture.json';capture.write_bytes(b'INVENTED RAW');capture.chmod(0o600)
        previous=os.getcwd()
        try:
            os.chdir(repo)
            reader=mock.Mock(side_effect=AssertionError('candidate byte read forbidden'))
            with mock.patch.object(routing._native,'private_read',reader),mock.patch.object(sys,'argv',['tool','preaction',str(capture)]):
                self.assertEqual(routing.main(),1)
            reader.assert_not_called()
            os.chdir(ROOT)
            malformed=self.root/control.KEY/'capture.json'
            with mock.patch.object(routing._native,'private_read',reader),mock.patch.object(sys,'argv',['tool','preaction',str(malformed)]):
                self.assertEqual(routing.main(),1)
            reader.assert_not_called()
        finally:os.chdir(previous)


if __name__=='__main__':unittest.main()
