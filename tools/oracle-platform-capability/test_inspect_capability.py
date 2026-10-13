"""Public fixtures only; never contact API, SSH, Docker or credentials."""
import hashlib,importlib.util,json,os,subprocess,time
from pathlib import Path
from unittest.mock import patch
import pytest
ROOT=Path(__file__).parent
spec=importlib.util.spec_from_file_location('capability',ROOT/'inspect_capability.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def contract(mode='discover'):
    c={**m.FIXED,'mode':mode,'expires_at':int(time.time())+3600,'claim_id':'public-invented-test','known_hosts_sha256':'a'*64}
    for key,path in [('operator_sha256',ROOT/'inspect_capability.py'),('remote_sha256',ROOT/'remote.py'),('transport_helper_sha256',Path(m.helpers.__file__))]:c[key]=hashlib.sha256(path.read_bytes()).hexdigest()
    if mode=='qualify':c.update(helper_id='b'*64,helper_name='fixedhelper',helper_image=m.HELPER+':1.0.12',helper_image_id='sha256:'+'c'*64)
    return c

def test_closed_contract_and_source_pins(tmp_path):
    for mode in ['discover','qualify']:
        c=contract(mode);raw=json.dumps(c).encode();path=tmp_path/'contract';path.write_bytes(raw)
        assert m.load_contract(path,hashlib.sha256(raw).hexdigest())==c
        c['remote_sha256']='f'*64;raw=json.dumps(c).encode();path.write_bytes(raw)
        with pytest.raises(ValueError):m.load_contract(path,hashlib.sha256(raw).hexdigest())

@pytest.mark.parametrize('field,value',[('api','https://foreign.invalid'),('host','foreign'),('application','oldforeign'),('mode','exec'),('helper_id','x; reboot'),('helper_name','$(cat /etc/passwd)'),('helper_image','foreign/image:latest')])
def test_closed_scope_refusal(tmp_path,field,value):
    c=contract('qualify');c[field]=value;raw=json.dumps(c).encode();p=tmp_path/'c';p.write_bytes(raw)
    with pytest.raises(ValueError):m.load_contract(p,hashlib.sha256(raw).hexdigest())


def test_discovery_never_execs_or_reads_environment_source():
    source=(ROOT/'remote.py').read_text();discover=source[source.index("if C['mode']=='discover':"):source.index('    else:')]
    assert "'exec'" not in discover and "'ps'" in discover and "'inspect'" in discover
    for forbidden in ['.Config.Env','.State.Health.Log','docker.sock','config.json','logs','restart','start','stop','remove']:
        assert forbidden not in source
    command=m.remote_command(contract());assert command.startswith('python3 -c ') and 'ssh' not in command


def test_no_helper_discovered_stays_unknown():
    c=contract();raw=json.dumps({'mode':'discover','coolify':{'id':'b'*64,'name':'/coolify','image':'coollabsio/coolify:4.4.6','image_id':'sha256:'+'c'*64,'state':'running'},'inventory':[],'configured_helper':'UNKNOWN','capabilities':'UNKNOWN'}).encode()
    out=m.validate(raw,c);assert out['configured_helper']=='UNKNOWN' and out['launch_admitted'] is False
    altered=json.loads(raw);altered['configured_helper']='latest-default';
    with pytest.raises(ValueError):m.validate(json.dumps(altered).encode(),c)


def test_genuine_gate_precedes_oneuse_claim_and_failure_retained(tmp_path):
    os.chmod(tmp_path,0o700);c=contract();gate=[]
    def reject(*a,**k):gate.append(a[0]);return type('R',(),{'returncode':3})()
    with patch.object(m.subprocess,'run',reject):
        with pytest.raises(ValueError):m.gate_and_claim(c,'a'*64,'report',tmp_path)
    assert not list(tmp_path.iterdir())
    with patch.object(m.subprocess,'run',lambda *a,**k:type('R',(),{'returncode':0})()):
        claim=m.gate_and_claim(c,'a'*64,'report',tmp_path);assert claim.stat().st_mode&0o777==0o600
        with pytest.raises(FileExistsError):m.gate_and_claim(c,'a'*64,'report',tmp_path)
    assert json.loads(claim.read_text())['spent'] is True


def test_expiry_denies_before_gate_or_claim(tmp_path):
    os.chmod(tmp_path,0o700);c=contract();c['expires_at']=int(time.time())+119
    with patch.object(m.subprocess,'run',side_effect=AssertionError('gate ran')):
        with pytest.raises(ValueError):m.gate_and_claim(c,'a'*64,'report',tmp_path)
    assert not list(tmp_path.iterdir())


def test_fixed_local_public_guard_without_remote_container():
    p=subprocess.run(['/bin/sh','-c','test 0 -gt $(/bin/date +%s)'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=2)
    assert p.returncode==1 and not p.stdout

@pytest.mark.parametrize('bad',['none','wrong-identity','no-timeout-k','no-wait','post-changed'])
def test_remote_program_exact_qualification_or_refusal_no_mutation(bad,capsys):
    c=contract('qualify');calls=[];inspection=0
    row={'id':c['helper_id'],'name':'/'+c['helper_name'],'image':c['helper_image'],'image_id':c['helper_image_id'],'state':'running'}
    def fake(args,**kwargs):
        nonlocal inspection
        calls.append(args)
        if args[1]=='inspect':
            inspection+=1;value=dict(row)
            if bad=='wrong-identity' or bad=='post-changed' and inspection==2:value['image_id']='sha256:'+'f'*64
            raw=json.dumps(value).encode();code=0
        else:
            assert args[:3]==['docker','exec',c['helper_id']]
            tail=args[3:];code=0
            if tail==['/bin/sh','-c','test 0 -gt $(/bin/date +%s)']:code=1;raw=b''
            elif tail==['/bin/sh','-c','test 1 -eq 1']:raw=b''
            elif tail==['/bin/date','+%s']:raw=b'1791922800\n'
            elif tail==['timeout','--help']:raw=b'-s -k' if bad!='no-timeout-k' else b'-s'
            elif tail==['docker','compose','version','--short']:raw=b'2.40.3\n'
            elif tail==['docker','compose','wait','--help']:raw=b'wait help' if bad!='no-wait' else b'unknown'
            else:raise AssertionError('arbitrary capability argv')
        return type('R',(),{'returncode':code,'stdout':raw})()
    with patch.object(subprocess,'run',fake):
        if bad=='none':
            exec(compile((ROOT/'remote.py').read_text(),'remote.py','exec'),{'C':c})
            result=m.validate(capsys.readouterr().out.encode(),c);assert result['launch_admitted'] is False
        else:
            with pytest.raises(SystemExit) as error:exec(compile((ROOT/'remote.py').read_text(),'remote.py','exec'),{'C':c})
            assert error.value.code==3
    if bad=='wrong-identity':assert not any(args[1]=='exec' for args in calls)
    assert all(args[1] in {'inspect','exec'} for args in calls)


def test_lifecycle_child_has_no_credential_environment(tmp_path):
    os.chmod(tmp_path,0o700);seen=[]
    def fake(*args,**kwargs):seen.append(kwargs['env']);return type('R',(),{'returncode':0})()
    with patch.dict(os.environ,{'ORACLE_HETZ_READ_PASSWORD':'public-test-secret','ORACLE_COOLIFY_READ_TOKEN':'public-test-token'}),patch.object(subprocess,'run',fake):
        m.gate_and_claim(contract(),'a'*64,'report',tmp_path)
    assert seen and all('ORACLE_HETZ_READ_PASSWORD' not in env and 'ORACLE_COOLIFY_READ_TOKEN' not in env for env in seen)


def test_symlink_custody_denies_before_lifecycle(tmp_path):
    target=tmp_path/'owned';target.mkdir(mode=0o700);link=tmp_path/'link';link.symlink_to(target,target_is_directory=True)
    with patch.object(subprocess,'run',side_effect=AssertionError('gate dispatched')):
        with pytest.raises(ValueError):m.gate_and_claim(contract(),'a'*64,'report',link)


def test_capability_response_cannot_substitute_arbitrary_argv():
    c=contract('qualify');result={'mode':'qualify','identity':{'id':c['helper_id'],'name':'/'+c['helper_name'],'image':c['helper_image'],'image_id':c['helper_image_id'],'state':'running'},'capabilities':[{'argv':['cat','/etc/passwd'],'sha256':'a'*64,'bytes':1} for _ in range(5)],'expired_guard_refused':True,'configured_helper':'UNKNOWN','read_only':True}
    with pytest.raises(ValueError):m.validate(json.dumps(result).encode(),c)
