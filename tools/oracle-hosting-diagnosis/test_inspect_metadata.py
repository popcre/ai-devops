import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

HERE=Path(__file__).parent
spec=importlib.util.spec_from_file_location('inspector',HERE/'inspect_metadata.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
C=json.loads((HERE/'contract.json').read_bytes())


def row():
    return {'id':'a'*64,'name':'/'+C['project']+'-gateway-1','image_id':'sha256:'+'b'*64,'image':C['image'],'service':'gateway','project':C['project'],'application':C['application'],'revision':C['revision'],'status':'running','health':'unhealthy','exit_code':0,'started_at':'2026-10-13T12:00:00Z','finished_at':'0001-01-01T00:00:00Z','restarts':0}


class TestInspector(unittest.TestCase):
    def test_pinned_contract(self):
        p=HERE/'contract.json'
        self.assertEqual(m.load_contract(p,hashlib.sha256(p.read_bytes()).hexdigest()),C)
        with self.assertRaises(ValueError):m.load_contract(p,'0'*64)

    def test_missing_roles_unhealthy_preserved(self):
        out=m.validate_rows(json.dumps([row()]).encode(),C)
        self.assertEqual(out['cause'],'UNKNOWN')
        self.assertEqual(len(out['missing_roles']),17)
        self.assertEqual(out['containers'][0]['health'],'unhealthy')

    def test_sensitive_and_foreign_fields_refuse(self):
        for key,value in [('env',{'PASSWORD':'forbidden'}),('project','other'),('application','other'),('name','/other'),('service','other'),('image','https://user:password@example.com')]:
            r=row();r[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):m.validate_rows(json.dumps([r]).encode(),C)

    def test_duplicate_and_oversized_refuse(self):
        with self.assertRaises(ValueError):m.validate_rows(json.dumps([row(),row()]).encode(),C)
        with self.assertRaises(ValueError):m.validate_rows(b' '*65537,C)

    def test_remote_only_inspects_named_metadata(self):
        command=m.remote_command(C)
        self.assertNotIn('docker exec',command)
        self.assertNotIn('docker logs',command)
        self.assertNotIn('.Env',m.TEMPLATE)
        self.assertNotIn('.Health.Log',m.TEMPLATE)
        self.assertIn('coolify.applicationUuid',m.TEMPLATE)

    def test_auth_secret_absent_child_environment_and_cleanup(self):
        with tempfile.TemporaryDirectory() as d:
            hosts=Path(d)/'known-hosts';hosts.write_text('fixture-host-key\n')
            c=dict(C,known_hosts_sha256=hashlib.sha256(hosts.read_bytes()).hexdigest())
            helpers=[]
            def fake_run(args,**kwargs):
                env=kwargs['env'];self.assertNotIn('ORACLE_HETZ_READ_PASSWORD',env)
                self.assertNotIn('fixture-credential',' '.join(args))
                helper=Path(env['SSH_ASKPASS']);helpers.append(helper)
                self.assertEqual(helper.stat().st_mode&0o777,0o700)
                password=helper.parent/'password'
                self.assertEqual(password.stat().st_mode&0o777,0o600)
                self.assertEqual(password.read_text(),'fixture-credential')
                self.assertEqual(helper.parent.stat().st_mode&0o777,0o700)
                kwargs['stdout'].write(json.dumps([row()]).encode())
                return type('R',(),{'returncode':0})()
            with patch.dict(os.environ,{'ORACLE_HETZ_READ_PASSWORD':'fixture-credential'}),patch.object(m.subprocess,'run',fake_run):
                self.assertTrue(m.read_remote(c,hosts))
                self.assertNotIn('ORACLE_HETZ_READ_PASSWORD',os.environ)
            self.assertTrue(all(not helper.exists() for helper in helpers))

    def test_host_key_drift_precedes_credential_read(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'known-hosts';p.write_text('wrong')
            with patch.dict(os.environ,{'ORACLE_HETZ_READ_PASSWORD':'fixture-credential'}),patch.object(m.subprocess,'run') as run:
                with self.assertRaises(ValueError):m.read_remote(C,p)
                run.assert_not_called()

if __name__=='__main__':unittest.main()
