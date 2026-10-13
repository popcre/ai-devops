import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
import subprocess
from uuid import uuid4
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

    def test_vendor_absent_revision_expected_and_wrong_image_finding(self):
        rows=[]
        for index,service in enumerate(C['services']):
            r=row();r.update(id=format(index+1,'064x'),service=service,name='/'+C['project']+'-'+service+'-1')
            if service in C['vendor_images']:
                r.update(image=C['vendor_images'][service],revision='')
            rows.append(r)
        out=m.validate_rows(json.dumps(rows).encode(),C)
        self.assertEqual(out['image_mismatch_roles'],[])
        self.assertEqual(out['revision_mismatch_roles'],[])
        self.assertEqual(out['missing_roles'],[])
        ledger=next(r for r in rows if r['service']=='ledger')
        ledger['image']=ledger['image'].split('@')[0]+'@sha256:'+'d'*64
        out=m.validate_rows(json.dumps(rows).encode(),C)
        self.assertEqual(out['image_mismatch_roles'],['ledger'])
        self.assertIn('{{else}}""{{end}}',m.TEMPLATE)

    def test_credential_nul_and_oversize_rejected_before_child(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'known-hosts';p.write_text('fixture')
            c=dict(C,known_hosts_sha256=hashlib.sha256(p.read_bytes()).hexdigest())
            for password in ['bad\x00value','x'*65537]:
                with self.subTest(length=len(password)),patch.object(m.os,'environ',{'ORACLE_HETZ_READ_PASSWORD':password}),patch.object(m.subprocess,'run') as run:
                    with self.assertRaises(ValueError):m.read_remote(c,p)
                    run.assert_not_called()
                    self.assertNotIn('ORACLE_HETZ_READ_PASSWORD',os.environ)

    def test_askpass_nofollow_secret_read(self):
        real_run=m.subprocess.run
        with tempfile.TemporaryDirectory() as d:
            hosts=Path(d)/'known-hosts';hosts.write_text('fixture')
            c=dict(C,known_hosts_sha256=hashlib.sha256(hosts.read_bytes()).hexdigest())
            def fake_run(args,**kwargs):
                helper=Path(kwargs['env']['SSH_ASKPASS']);secret=helper.parent/'password'
                result=real_run([str(helper)],stdout=m.subprocess.PIPE,stderr=m.subprocess.DEVNULL,env=kwargs['env'])
                self.assertEqual(result.stdout,b'fixture-credential')
                # An accidental link cannot make the helper read another file.
                other=helper.parent/'foreign';other.write_text('foreign-fixture')
                secret.unlink();secret.symlink_to(other)
                result=real_run([str(helper)],stdout=m.subprocess.PIPE,stderr=m.subprocess.DEVNULL,env=kwargs['env'])
                self.assertNotEqual(result.returncode,0)
                self.assertEqual(result.stdout,b'')
                kwargs['stdout'].write(json.dumps([row()]).encode())
                return type('R',(),{'returncode':0})()
            with patch.dict(os.environ,{'ORACLE_HETZ_READ_PASSWORD':'fixture-credential'}),patch.object(m.subprocess,'run',fake_run):m.read_remote(c,hosts)

    def test_host_key_drift_precedes_credential_read(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'known-hosts';p.write_text('wrong')
            with patch.dict(os.environ,{'ORACLE_HETZ_READ_PASSWORD':'fixture-credential'}),patch.object(m.subprocess,'run') as run:
                with self.assertRaises(ValueError):m.read_remote(C,p)
                run.assert_not_called()

    def test_verified_host_bytes_remain_pinned_after_input_swap(self):
        with tempfile.TemporaryDirectory() as directory:
            hosts=Path(directory)/'hosts';hosts.write_bytes(b'original-fixture-key')
            contract=dict(C,known_hosts_sha256=hashlib.sha256(hosts.read_bytes()).hexdigest())
            def fake_run(args,**kwargs):
                hosts.write_bytes(b'changed-after-verification')
                pinned=Path(next(x.split('=',1)[1] for x in args if x.startswith('UserKnownHostsFile=')))
                self.assertNotEqual(pinned,hosts)
                self.assertEqual(pinned.read_bytes(),b'original-fixture-key')
                self.assertEqual(pinned.stat().st_mode&0o777,0o600)
                kwargs['stdout'].write(json.dumps([row()]).encode())
                return type('R',(),{'returncode':0})()
            with patch.dict(os.environ,{'ORACLE_HETZ_READ_PASSWORD':'fixture-credential'}),patch.object(m.subprocess,'run',fake_run):
                m.read_remote(contract,hosts)

    def test_input_links_pipes_and_oversize_refuse_without_blocking(self):
        with tempfile.TemporaryDirectory() as directory:
            file=Path(directory)/'file';file.write_bytes(b'x'*9)
            link=Path(directory)/'link';link.symlink_to(file)
            pipe=Path(directory)/'pipe';os.mkfifo(pipe)
            with self.assertRaises(ValueError):m.bounded_file(file,8)
            with self.assertRaises(OSError):m.bounded_file(link,16)
            with self.assertRaises(ValueError):m.bounded_file(pipe,16)

    def test_unprotected_explicit_temp_parent_refuses_before_child(self):
        with tempfile.TemporaryDirectory() as directory:
            hosts=Path(directory)/'hosts';hosts.write_bytes(b'fixture')
            contract=dict(C,known_hosts_sha256=hashlib.sha256(hosts.read_bytes()).hexdigest())
            parent=Path(directory)/'parent';parent.mkdir(mode=0o755)
            parent.chmod(0o755)
            with patch.dict(os.environ,{'ORACLE_HETZ_READ_PASSWORD':'fixture-credential','TMPDIR':str(parent)}),patch.object(m.subprocess,'run') as run:
                with self.assertRaises(ValueError):m.read_remote(contract,hosts)
                run.assert_not_called()

    def test_transport_error_reveals_only_fixed_category(self):
        self.assertEqual(m.transport_failure(255,b'Permission denied fixture-credential'),'ssh_authentication_refused')
        self.assertEqual(m.transport_failure(255,b'Host key verification failed private-fixture'),'ssh_host_key_refused')
        self.assertEqual(m.transport_failure(3,b'private-fixture'),'remote_metadata_reader_refused')
        self.assertEqual(m.transport_failure(255,b'private-fixture'),'ssh_transport_failed')

    def test_failed_ssh_discards_sensitive_stderr(self):
        with tempfile.TemporaryDirectory() as directory:
            hosts=Path(directory)/'hosts';hosts.write_bytes(b'fixture')
            contract=dict(C,known_hosts_sha256=hashlib.sha256(hosts.read_bytes()).hexdigest())
            def fake_run(args,**kwargs):
                kwargs['stderr'].write(b'Permission denied fixture-credential')
                return type('R',(),{'returncode':255})()
            with patch.dict(os.environ,{'ORACLE_HETZ_READ_PASSWORD':'fixture-credential','TMPDIR':directory}),patch.object(m.subprocess,'run',fake_run):
                with self.assertRaisesRegex(ValueError,'^ssh_authentication_refused$'):
                    m.read_remote(contract,hosts)

    def test_real_docker_missing_health_is_metadata_not_template_failure(self):
        # A new, never-started local invented fixture contains no job/store data.
        # Record its exact metadata before recoverable fixture cleanup.
        name='oracle2-synthetic-metadata-'+uuid4().hex
        image=C['vendor_images']['ledger']
        created=subprocess.run(['docker','create','--name',name,'--label','oracle.metadata.synthetic=true',
          '--network','none','--read-only','--cap-drop','ALL','--user','10001:10001',image,'/bin/true'],capture_output=True,text=True)
        self.assertEqual(created.returncode,0,'owned local formatter fixture required')
        cid=created.stdout.strip()
        try:
            rendered=subprocess.run(['docker','inspect','--format',m.TEMPLATE,cid],capture_output=True,text=True)
            self.assertEqual(rendered.returncode,0,'Docker absent-health field must render safely')
            row=json.loads(rendered.stdout)
            self.assertEqual(row['health'],'absent')
            self.assertEqual(row['status'],'created')
            self.assertEqual(row['started_at'],'0001-01-01T00:00:00Z')
        finally:
            labels=subprocess.check_output(['docker','inspect','--format','{{json .Config.Labels}}',cid],text=True)
            self.assertEqual(json.loads(labels)['oracle.metadata.synthetic'],'true')
            self.assertEqual(subprocess.check_output(['docker','inspect','--format','{{.State.Status}}',cid],text=True).strip(),'created')
            subprocess.run(['docker','rm','-v',cid],check=True,stdout=subprocess.DEVNULL)

if __name__=='__main__':unittest.main()
