"""Public fixtures only; never contact API, SSH, Docker or credentials."""
import hashlib,importlib.util,json,os,subprocess,time
from pathlib import Path
from unittest.mock import patch
import pytest
ROOT=Path(__file__).parent
spec=importlib.util.spec_from_file_location('capability',ROOT/'inspect_capability.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
TEST_TARGET={'api':'http://127.0.0.1:8000/api/v1/version','host':'invented-host','user':'ai','port':22}
TEST_PEER={'node_id':1,'node_name':'invented.invalid.','addresses':['127.0.0.1/32','::1/128'],'node_key_sha256':hashlib.sha256(('nodekey:'+'1'*64).encode()).hexdigest(),'tags':['tag:server'],'route_device':'tailscale0','route_table':'52','route_source':'127.0.0.1'}

@pytest.fixture(autouse=True)
def invented_closed_commitments(monkeypatch):
    # Fixtures have no actual topology or claim authority; runtime pins remain fixed.
    monkeypatch.setattr(m,'TARGET_SHA256',m.canonical_commitment('oracle-platform-target/v4',TEST_TARGET))
    monkeypatch.setattr(m,'PEER_SHA256',m.canonical_commitment('oracle-platform-peer-route/v4',TEST_PEER))

def contract(mode='discover'):
    c={**m.FIXED,**TEST_TARGET,'mode':mode,'issued_at':int(time.time())-1,'expires_at':int(time.time())+600,'installed_gate':{'source_head':'a'*40,'launcher_sha256':'b'*64,'manifest_sha256':'c'*64},'claim_id':'public-invented-test','known_hosts_sha256':'a'*64,'tailnet':{**TEST_PEER,'os_cli':{k:{'binary_sha256':'a'*64,'package_manifest_sha256':'b'*64} for k in m.OS_FILES}}}
    for key,path in [('operator_sha256',ROOT/'inspect_capability.py'),('remote_sha256',ROOT/'remote.py'),('transport_helper_sha256',Path(m.helpers.__file__))]:c[key]=hashlib.sha256(path.read_bytes()).hexdigest()
    if mode=='qualify':c.update(helper_id='b'*64,helper_name='fixedhelper',helper_image=m.HELPER+':1.0.12',helper_image_id='sha256:'+'c'*64)
    return c

def public_report(tmp_path):
    path=tmp_path.parent/(tmp_path.name+'.report');path.write_bytes(b'PUBLIC INVENTED REPORT, NOT APPROVAL');path.chmod(0o600);return path

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
    source=(ROOT/'remote.py').read_text();discover=source[source.index("if C['mode']=='discover':"):source.index("    elif C['mode']=='qualify':")]
    assert "'exec'" not in discover and "'ps'" in discover and "'inspect'" in discover
    for forbidden in ['.Config.Env','.State.Health.Log','docker.sock','config.json','logs','restart','start','stop','remove']:
        assert forbidden not in source
    command=m.remote_command(contract(),(ROOT/'remote.py').read_bytes());assert command.startswith('/usr/bin/python3 -c ') and 'ssh' not in command


def test_no_helper_discovered_stays_unknown():
    c=contract();raw=json.dumps({'mode':'discover','coolify':{'id':'b'*64,'name':'/coolify','image':'coollabsio/coolify:4.4.6','image_id':'sha256:'+'c'*64,'state':'running'},'inventory':[],'configured_helper':'UNKNOWN','capabilities':'UNKNOWN'}).encode()
    out=m.validate(raw,c);assert out['configured_helper']=='UNKNOWN' and out['launch_admitted'] is False
    altered=json.loads(raw);altered['configured_helper']='latest-default';
    with pytest.raises(ValueError):m.validate(json.dumps(altered).encode(),c)


def test_genuine_gate_precedes_oneuse_claim_and_failure_retained(tmp_path):
    os.chmod(tmp_path,0o700);c=contract();gate=[]
    def reject(*a,**k):gate.append(a[0]);return type('R',(),{'returncode':3})()
    with patch.object(m,'verify_tailnet',lambda c:None),patch.object(m,'installed_gate',lambda c:None),patch.object(m.subprocess,'run',reject):
        with pytest.raises(ValueError):m.gate_and_claim(c,'a'*64,public_report(tmp_path),tmp_path)
    assert not list(tmp_path.iterdir())
    with patch.object(m,'verify_tailnet',lambda c:None),patch.object(m,'installed_gate',lambda c:None),patch.object(m.subprocess,'run',lambda *a,**k:type('R',(),{'returncode':0})()):
        claim=m.gate_and_claim(c,'a'*64,public_report(tmp_path),tmp_path);assert claim.stat().st_mode&0o777==0o600
        with pytest.raises(FileExistsError):m.gate_and_claim(c,'a'*64,public_report(tmp_path),tmp_path)
    assert json.loads(claim.read_text())['spent'] is True


def test_expiry_denies_before_gate_or_claim(tmp_path):
    os.chmod(tmp_path,0o700);c=contract();c['expires_at']=int(time.time())+119
    with patch.object(m.subprocess,'run',side_effect=AssertionError('gate ran')):
        with pytest.raises(ValueError):m.gate_and_claim(c,'a'*64,public_report(tmp_path),tmp_path)
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
    with patch.dict(os.environ,{'ORACLE_HETZ_READ_PASSWORD':'public-test-secret','ORACLE_COOLIFY_READ_TOKEN':'public-test-token'}),patch.object(m,'verify_tailnet',lambda c:None),patch.object(m,'installed_gate',lambda c:None),patch.object(subprocess,'run',fake):
        m.gate_and_claim(contract(),'a'*64,public_report(tmp_path),tmp_path)
    assert seen and all('ORACLE_HETZ_READ_PASSWORD' not in env and 'ORACLE_COOLIFY_READ_TOKEN' not in env for env in seen)


def test_symlink_custody_denies_before_lifecycle(tmp_path):
    target=tmp_path/'owned';target.mkdir(mode=0o700);link=tmp_path/'link';link.symlink_to(target,target_is_directory=True)
    with patch.object(subprocess,'run',side_effect=AssertionError('gate dispatched')):
        with pytest.raises(ValueError):m.gate_and_claim(contract(),'a'*64,public_report(tmp_path),link)


def test_capability_response_cannot_substitute_arbitrary_argv():
    c=contract('qualify');result={'mode':'qualify','identity':{'id':c['helper_id'],'name':'/'+c['helper_name'],'image':c['helper_image'],'image_id':c['helper_image_id'],'state':'running'},'capabilities':[{'argv':['cat','/etc/passwd'],'sha256':'a'*64,'bytes':1} for _ in range(5)],'expired_guard_refused':True,'configured_helper':'UNKNOWN','read_only':True}
    with pytest.raises(ValueError):m.validate(json.dumps(result).encode(),c)

@pytest.mark.parametrize('token',['bad\x00token','bad\ttoken','badétoken','a'*8193,'','bad token'])
def test_invalid_token_refuses_before_network(token):
    with patch.object(m.urllib.request,'build_opener',side_effect=AssertionError('network opener')):
        with pytest.raises(ValueError):m.version(token,contract())

@pytest.mark.parametrize('issued,expiry',[(True,600),(-1,4000),(600,1200),(0,1801)])
def test_actual_clock_and_maximum_lifetime(issued,expiry):
    c=contract();c.update(issued_at=issued,expires_at=expiry)
    with patch.object(m.time,'time',lambda:100):
        with pytest.raises(ValueError):m.lifetime(c)


def test_transport_helper_hash_before_execution():
    with patch.object(m,'bounded_file',lambda *a:b'raise AssertionError("EXECUTED")'):
        with pytest.raises(ValueError,match='before execution'):m.load_helpers()


def test_import_removes_credentials_before_project_helper():
    script='import importlib.util,os; s=importlib.util.spec_from_file_location("cap",'+repr(str(ROOT/'inspect_capability.py'))+');m=importlib.util.module_from_spec(s);s.loader.exec_module(m);assert "ORACLE_HETZ_READ_PASSWORD" not in os.environ and "ORACLE_COOLIFY_READ_TOKEN" not in os.environ'
    environment={**os.environ,'ORACLE_HETZ_READ_PASSWORD':'INVENTED','ORACLE_COOLIFY_READ_TOKEN':'INVENTED'}
    import sys
    result=subprocess.run([sys.executable,'-c',script],env=environment,capture_output=True,timeout=5)
    assert result.returncode==0


def test_remote_held_bytes_never_reread(tmp_path):
    c=contract();raw=json.dumps(c).encode();file=tmp_path/'c';file.write_bytes(raw)
    loaded=m.load_contract(file,hashlib.sha256(raw).hexdigest())
    with patch.object(Path,'read_bytes',side_effect=AssertionError('remote reread')):
        assert m.remote_command(loaded,loaded.remote_source).startswith('/usr/bin/python3 -c ')
    with pytest.raises(ValueError):m.remote_command(loaded,b'changed')


def test_fd_custody_refuses_renamed_parent_without_redirect(tmp_path):
    root=tmp_path/'custody';root.mkdir(mode=0o700);d=m.Custody(root)
    moved=tmp_path/'moved';root.rename(moved);root.mkdir(mode=0o700)
    try:
        with pytest.raises(ValueError,match='moved'):d.create('receipt.json',b'INVENTED')
        assert not list(root.iterdir()) and not list(moved.iterdir())
    finally:d.close()


def test_intermediate_symlink_and_dotdot_refuse(tmp_path):
    real=tmp_path/'real';real.mkdir(mode=0o700);(real/'child').mkdir(mode=0o700);link=tmp_path/'link';link.symlink_to(real)
    for p in (str(link/'child'),str(real)+'/../real/child'):
        with pytest.raises(ValueError):m.Custody(p)


def test_hardlinked_bounded_source_refuses(tmp_path):
    a=tmp_path/'a';a.write_bytes(b'public');os.link(a,tmp_path/'b')
    with pytest.raises(ValueError):m.bounded_file(a,100)


def test_fixed_gate_argv_home_and_secretless_child(tmp_path):
    tmp_path.chmod(0o700);calls=[]
    def fake(argv,**kw):calls.append((argv,kw));return type('R',(),{'returncode':0})()
    with patch.dict(os.environ,{'PATH':'/UNTRUSTED','HOME':'/UNTRUSTED'}),patch.object(m,'verify_tailnet',lambda c:None),patch.object(m,'installed_gate',lambda c:None),patch.object(m.subprocess,'run',fake):
        m.gate_and_claim(contract(),'a'*64,public_report(tmp_path),tmp_path)
    assert calls[0][0][0]=='/usr/local/bin/ai-task-gates'
    assert calls[0][1]['env']=={'PATH':'/usr/local/bin:/usr/bin:/bin','HOME':'/home/ahazan'}


def test_remote_long_lifetime_no_commands():
    c=contract('qualify');c['expires_at']=c['issued_at']+1801
    with patch.object(subprocess,'run',side_effect=AssertionError('remote ran')):
        with pytest.raises(SystemExit):exec(compile((ROOT/'remote.py').read_bytes(),'remote.py','exec'),{'C':c})


def test_anchored_ssh_askpass_public_bytes_and_no_credential_env(tmp_path):
    tmp_path.chmod(0o700);inputdir=tmp_path/'input';inputdir.mkdir(mode=0o700);hosts=inputdir/'hosts';hosts.write_bytes(b'INVENTED HOST KEY\n'.ljust(142,b' '));hosts.chmod(0o600);c=contract();c['known_hosts_sha256']=hashlib.sha256(hosts.read_bytes()).hexdigest();source=(ROOT/'remote.py').read_bytes();calls=[]
    original=subprocess.run
    def fake(argv,**kw):
        calls.append((argv,kw));assert argv[0]=='/usr/bin/ssh' and argv[-1].startswith('/usr/bin/python3 -c ')
        child=kw['env'];assert all('PASSWORD' not in k and 'TOKEN' not in k for k in child)
        result=original([child['SSH_ASKPASS']],env=child,capture_output=True,timeout=3)
        assert result.returncode==0 and result.stdout==b'INVENTED PASSWORD'
        kw['stdout'].write(b'{}');return type('R',(),{'returncode':0})()
    with patch.dict(os.environ,{'TMPDIR':str(tmp_path)}),patch.object(m.subprocess,'run',fake):
        held=m.HeldInput(hosts,142,exact_size=142)
        try:assert m.read_remote(c,held,'INVENTED PASSWORD',source)==b'{}'
        finally:held.close()
    assert calls and sorted(x.name for x in tmp_path.iterdir())==['input']


def test_installed_gate_manifest_source_identity(tmp_path):
    from types import SimpleNamespace
    launchers=tmp_path/'bin';sources=tmp_path/'source';launchers.mkdir();sources.mkdir()
    launcher=launchers/'gate';source=sources/'gate';manifest=tmp_path/'manifest';source.write_bytes(b'PUBLIC GATE');launcher.symlink_to(source)
    h=hashlib.sha256(source.read_bytes()).hexdigest();head='a'*40
    manifest.write_text('meta\tsource_sha\t'+head+'\t-\nsymlink\t'+str(launcher)+'\t'+str(source)+'\t'+h+'\n')
    manifest.chmod(0o600)
    c=contract();c['installed_gate']={'source_head':head,'launcher_sha256':h,'manifest_sha256':hashlib.sha256(manifest.read_bytes()).hexdigest()}
    original=m.os.lstat
    def root_fixture(path):
        st=original(path)
        if str(path)==str(launcher):return SimpleNamespace(st_mode=st.st_mode,st_uid=0,st_nlink=st.st_nlink)
        return st
    fstat=m.os.fstat
    def owned_ancestry(fd):
        info=fstat(fd)
        if __import__('stat').S_ISDIR(info.st_mode):
            values=list(info);values[0]&=~0o022;values[4]=0;return os.stat_result(values)
        return info
    seen=[];gitchecks=[]
    def checked_git(kind,pins):gitchecks.append((kind,pins))
    def fake(argv,**kw):
        seen.append((argv,kw));return SimpleNamespace(returncode=0,stdout=(head+'\n').encode() if argv[-1]=='HEAD' else b'')
    with patch.object(m,'GATE',str(launcher)),patch.object(m,'GATE_SOURCE',str(source)),patch.object(m,'MANIFEST',str(manifest)),patch.object(m.os,'lstat',root_fixture),patch.object(m.os,'fstat',owned_ancestry),patch.object(m.subprocess,'run',fake),patch.object(m,'os_identity',checked_git):
        m.installed_gate(c);assert len(gitchecks)==3 and all(kind=='git' and pins==c['tailnet']['os_cli']['git'] for kind,pins in gitchecks)
        assert len(seen)==2 and all(x[1]['env']['HOME']=='/home/ahazan' for x in seen)
        seen.clear()
        with patch.object(m,'os_identity',side_effect=ValueError('reviewed OS executable differs')):
            with pytest.raises(ValueError,match='executable differs'):m.installed_gate(c)
        assert seen==[]
        source.write_bytes(b'MOVED PUBLIC SOURCE')
        with pytest.raises(ValueError,match='managed source hash differs'):m.installed_gate(c)

@pytest.fixture
def invented_peer(monkeypatch):
    key='nodekey:'+'1'*64;expected={**TEST_PEER,'node_key_sha256':hashlib.sha256(key.encode()).hexdigest()}
    monkeypatch.setattr(m,'PEER_SHA256',m.canonical_commitment('oracle-platform-peer-route/v4',expected))
    for field,value in expected.items():monkeypatch.setitem(TEST_PEER,field,value)
    who={'Node':{'ID':expected['node_id'],'Name':expected['node_name'],'Addresses':expected['addresses'],'Key':key,'Tags':expected['tags'],'Expired':False,'KeyExpiry':'2099-01-01T00:00:00Z'}}
    route=[{'dst':'127.0.0.1','dev':'tailscale0','table':'52','prefsrc':expected['route_source'],'flags':[]}]
    monkeypatch.setattr(m,'os_identity',lambda *a:None);monkeypatch.setattr(m,'root_ancestry',lambda *a:(1,2))
    def local(argv,maximum):return who if argv[0]=='/usr/bin/tailscale' else route
    monkeypatch.setattr(m,'local_metadata',local)
    return who,route

@pytest.mark.parametrize('damage',['node','key','name','address','tags','missingtags','missingkey','route','device','source','table','expired','missing-expired','null-expired','nonbool-expired','missing-key-expiry','null-key-expiry','empty-key-expiry','malformed-key-expiry','naive-key-expiry','past-key-expiry','unknown'])
def test_wrong_peer_or_route_sends_zero_http_bytes(invented_peer,damage):
    who,route=invented_peer
    if damage=='node':who['Node']['ID']+=1
    elif damage=='key':who['Node']['Key']='nodekey:'+'2'*64
    elif damage=='name':who['Node']['Name']='foreign.ts.net.'
    elif damage=='address':who['Node']['Addresses']=[]
    elif damage=='tags':who['Node']['Tags']=['tag:foreign']
    elif damage=='missingtags':del who['Node']['Tags']
    elif damage=='missingkey':del who['Node']['Key']
    elif damage=='route':route.append(dict(route[0]))
    elif damage=='device':route[0]['dev']='eth0'
    elif damage=='source':route[0]['prefsrc']='192.0.2.1'
    elif damage=='table':route[0]['table']='main'
    elif damage=='expired':who['Node']['Expired']=True
    elif damage=='missing-expired':who['Node'].pop('Expired')
    elif damage=='null-expired':who['Node']['Expired']=None
    elif damage=='nonbool-expired':who['Node']['Expired']=0
    elif damage=='missing-key-expiry':who['Node'].pop('KeyExpiry')
    elif damage=='null-key-expiry':who['Node']['KeyExpiry']=None
    elif damage=='empty-key-expiry':who['Node']['KeyExpiry']=' '
    elif damage=='malformed-key-expiry':who['Node']['KeyExpiry']='not-a-time'
    elif damage=='naive-key-expiry':who['Node']['KeyExpiry']='2099-01-01T00:00:00'
    elif damage=='past-key-expiry':who['Node']['KeyExpiry']='2000-01-01T00:00:00Z'
    else:who.clear()
    with patch.object(m.urllib.request,'build_opener',side_effect=AssertionError('HTTP opener constructed')),patch.object(m.urllib.request,'Request',side_effect=AssertionError('bearer request constructed')):
        with pytest.raises((ValueError,TypeError)):m.version('INVENTED',contract())


def test_fixed_peer_finite_expiry_is_checked(invented_peer):
    assert m.verify_tailnet(contract())['peer_expiry']=='checked-current'


def test_peer_rechecked_after_http_before_metadata_accepted(invented_peer):
    who,_=invented_peer
    class Response:
        status=200
        def geturl(self):return TEST_TARGET['api']
        def __enter__(self):return self
        def __exit__(self,*args):pass
        def read(self,n):who['Node']['Key']='nodekey:'+'2'*64;return b'4.4.6\n'
    class Opener:
        def open(self,*a,**k):return Response()
    with patch.object(m.urllib.request,'build_opener',lambda *a:Opener()):
        with pytest.raises(ValueError,match='key moved'):m.version('INVENTED',contract())


def test_peer_failure_before_oneuse_claim(invented_peer,tmp_path):
    tmp_path.chmod(0o700);who,_=invented_peer;who['Node']['ID']+=1
    with patch.object(m,'installed_gate',lambda c:None),patch.object(m.subprocess,'run',lambda *a,**k:type('R',(),{'returncode':0})()):
        with pytest.raises(ValueError):m.gate_and_claim(contract(),'a'*64,public_report(tmp_path),tmp_path)
    assert not list(tmp_path.iterdir())

@pytest.mark.parametrize('report',['--first-managed-install','relative-report','/nonexistent/report'])
def test_malicious_report_no_gate_peer_or_http(report,tmp_path):
    tmp_path.chmod(0o700)
    with patch.object(m,'installed_gate',side_effect=AssertionError('gate inspected')),patch.object(m,'verify_tailnet',side_effect=AssertionError('peer ran')):
        with pytest.raises((ValueError,OSError)):m.gate_and_claim(contract(),'a'*64,report,tmp_path)
    assert not list(tmp_path.iterdir())


def test_fifo_read_refuses_without_waiting(tmp_path):
    fifo=tmp_path/'fifo';os.mkfifo(fifo,0o600)
    before=time.monotonic()
    with pytest.raises(ValueError):m.bounded_file(fifo,1024)
    assert time.monotonic()-before<1


def test_unknown_remote_mode_no_docker_exec():
    c=contract();c['mode']='foreign'
    with patch.object(subprocess,'run',side_effect=AssertionError('remote executed')):
        with pytest.raises(SystemExit):exec(compile((ROOT/'remote.py').read_bytes(),'remote.py','exec'),{'C':c})


def test_bound_http_socket_has_no_interface_fallback():
    calls=[]
    class Socket:
        def settimeout(self,n):calls.append(('timeout',n))
        def setsockopt(self,*a):calls.append(('device',a));raise PermissionError('INVENTED denied binding')
        def bind(self,*a):pytest.fail('source bind after denied interface')
        def connect(self,*a):pytest.fail('HTTP egress after denied interface')
        def close(self):calls.append(('closed',))
    with patch.object(m.socket,'socket',lambda *a:Socket()):
        with pytest.raises(PermissionError):m.BoundConnection('127.0.0.1:8000',contract=contract()).connect()
    assert calls[-1]==('closed',)


def test_multiple_exact_tags_preserved_not_subset(invented_peer,monkeypatch):
    who,_=invented_peer;expected={**TEST_PEER,'tags':['tag:a','tag:server']};monkeypatch.setattr(m,'PEER_SHA256',m.canonical_commitment('oracle-platform-peer-route/v4',expected))
    for field,value in expected.items():monkeypatch.setitem(TEST_PEER,field,value);who['Node']['Tags']=['tag:a','tag:server']
    assert m.verify_tailnet(contract())['encrypted_route_bound'] is True
    who['Node']['Tags']=['tag:server']
    with pytest.raises(ValueError):m.verify_tailnet(contract())


def test_review_templates_pin_current_code_and_stay_unadmitted():
    for name in ('discovery.v5.contract.template.json','qualification.v5.contract.template.json'):
        c=json.loads((ROOT/name).read_bytes())
        assert c['schema']=='oracle-platform-capability/v5' and c['issued_at']==0 and c['expires_at']==0
        assert c['api'] is None and c['host'] is None and all(v is None for v in c['tailnet'].values())
        assert c['operator_sha256']==hashlib.sha256((ROOT/'inspect_capability.py').read_bytes()).hexdigest()
        assert c['remote_sha256']==hashlib.sha256((ROOT/'remote.py').read_bytes()).hexdigest()
        assert c['transport_helper_sha256']==m.HELPER_SHA==hashlib.sha256(Path(m.helpers.__file__).read_bytes()).hexdigest()


def test_os_binary_mismatch_before_local_lookup(tmp_path,monkeypatch):
    binary=tmp_path/'binary';binary.write_bytes(b'PUBLIC INVENTED OS BINARY');binary.chmod(0o700)
    origin=tmp_path/'md5sums';origin.write_text(hashlib.md5(binary.read_bytes()).hexdigest()+'  '+str(binary)[1:]+'\n')
    monkeypatch.setattr(m,'OS_FILES',{'tailscale':(str(binary),str(origin))});monkeypatch.setattr(m,'root_ancestry',lambda *a:(1,2))
    with pytest.raises(ValueError,match='executable differs'):
        m.os_identity('tailscale',{'binary_sha256':'0'*64,'package_manifest_sha256':hashlib.sha256(origin.read_bytes()).hexdigest()})


def test_report_fifo_no_gate_and_no_wait(tmp_path):
    tmp_path.chmod(0o700);fifo=tmp_path/'fifo';os.mkfifo(fifo,0o600)
    with patch.object(m,'installed_gate',side_effect=AssertionError('gate ran')):
        with pytest.raises(ValueError):m.gate_and_claim(contract(),'a'*64,fifo,tmp_path)


@pytest.mark.parametrize('field',['api','host','user','port','route_source','route_device','route_table','node_id','node_name','addresses','tags','node_key_sha256'])
def test_wrong_closed_preimage_before_gate_or_credential_or_claim(tmp_path,field):
    c=contract()
    if field in TEST_TARGET:c[field]='foreign' if field!='port' else 23
    elif field=='node_id':c['tailnet'][field]+=1
    elif field in ('addresses','tags'):c['tailnet'][field]=[]
    else:c['tailnet'][field]='foreign'
    tmp_path.chmod(0o700)
    with patch.object(m,'installed_gate',side_effect=AssertionError('gate metadata read')),patch.object(m.subprocess,'run',side_effect=AssertionError('child')),patch.object(m.urllib.request,'build_opener',side_effect=AssertionError('HTTP')):
        with pytest.raises(ValueError):m.gate_and_claim(c,'a'*64,public_report(tmp_path),tmp_path)
    assert not list(tmp_path.iterdir())


def root_fixture_ancestry(monkeypatch):
    original=m.os.fstat
    def fixture(fd):
        info=original(fd)
        if __import__('stat').S_ISDIR(info.st_mode):
            values=list(info);values[0]&=~0o022;values[4]=0;return os.stat_result(values)
        return info
    monkeypatch.setattr(m.os,'fstat',fixture)


def test_receipt_current_user_uid_and_0600_are_supported(tmp_path,monkeypatch):
    receipt=tmp_path/'manifest';receipt.write_bytes(b'PUBLIC RECEIPT METADATA');receipt.chmod(0o600)
    assert receipt.stat().st_uid==os.getuid()
    monkeypatch.setattr(m,'MANIFEST',str(receipt));root_fixture_ancestry(monkeypatch)
    assert m.read_install_manifest()==b'PUBLIC RECEIPT METADATA'


@pytest.mark.parametrize('damage',['mode','hardlink','symlink','fifo','wronguid','ancestoruid','ancestormode','ancestorsymlink'])
def test_receipt_custody_denials_before_content_read(tmp_path,monkeypatch,damage):
    import stat
    parent=tmp_path/'parent';parent.mkdir();receipt=parent/'manifest';receipt.write_bytes(b'PUBLIC');receipt.chmod(0o600)
    original=m.os.fstat
    root_fixture_ancestry(monkeypatch);fixture=m.os.fstat
    if damage=='mode':receipt.chmod(0o644)
    elif damage=='hardlink':os.link(receipt,parent/'alias')
    elif damage=='symlink':receipt.unlink();receipt.symlink_to(parent/'missing')
    elif damage=='fifo':receipt.unlink();os.mkfifo(receipt,0o600)
    elif damage=='ancestorsymlink':
        link=tmp_path/'linked';link.symlink_to(parent,target_is_directory=True);receipt=link/'manifest'
    elif damage in ('wronguid','ancestoruid','ancestormode'):
        def unsafe(fd):
            info=fixture(fd);values=list(info)
            if damage=='wronguid' and stat.S_ISREG(info.st_mode):values[4]=os.getuid()+1
            if damage=='ancestoruid' and stat.S_ISDIR(info.st_mode):values[4]=os.getuid()
            if damage=='ancestormode' and stat.S_ISDIR(info.st_mode):values[0]|=0o022
            return os.stat_result(values)
        monkeypatch.setattr(m.os,'fstat',unsafe)
    monkeypatch.setattr(m,'MANIFEST',str(receipt))
    with patch.object(m.os,'read',side_effect=AssertionError('receipt content read')),patch.object(m.subprocess,'run',side_effect=AssertionError('gate child')):
        with pytest.raises((ValueError,OSError)):m.read_install_manifest()


@pytest.mark.parametrize('field',['st_dev','st_ino','st_uid','st_gid','st_mode','st_nlink','st_size','st_mtime_ns','st_ctime_ns',None])
def test_fresh_public_file_read_all_immutable_stats_except_atime(tmp_path,monkeypatch,field):
    from types import SimpleNamespace
    path=tmp_path/'fresh-public';path.write_bytes(b'PUBLIC FRESH SOURCE');calls=0;original=m.os.fstat
    def changed(fd):
        nonlocal calls
        calls+=1;info=original(fd)
        fields=('st_dev','st_ino','st_uid','st_gid','st_mode','st_nlink','st_size','st_mtime_ns','st_ctime_ns','st_atime_ns')
        value={k:getattr(info,k) for k in fields}
        if calls>1:value['st_atime_ns']+=1
        if calls>1 and field:value[field]+=1
        return SimpleNamespace(**value)
    monkeypatch.setattr(m.os,'fstat',changed)
    if field:
        with pytest.raises(ValueError,match='source moved'):m.bounded_file(path,1024)
    else:assert m.bounded_file(path,1024)==b'PUBLIC FRESH SOURCE'


def test_missing_protected_tmpdir_before_gate_or_credentials(tmp_path,monkeypatch):
    import sys
    c=contract();monkeypatch.setattr(m,'load_contract',lambda *a:c)
    monkeypatch.setattr(m,'_PASSWORD','INVENTED');monkeypatch.setattr(m,'_TOKEN','INVENTED')
    monkeypatch.delenv('TMPDIR',raising=False)
    monkeypatch.setattr(sys,'argv',['reader','--contract','/invented','--contract-sha256','a'*64,'--reviewer-approval','/invented','--known-hosts','/invented','--custody',str(tmp_path)])
    with patch.object(m,'gate_and_claim',side_effect=AssertionError('claim')),patch.object(m,'bounded_file',side_effect=AssertionError('credential/host read')),patch.object(m,'version',side_effect=AssertionError('HTTP')),patch.object(m,'read_remote',side_effect=AssertionError('SSH')):
        assert m.main()==3
    assert not list(tmp_path.iterdir())


@pytest.mark.parametrize('damage',['publicmode','symlink','dot'])
def test_insecure_tmpdir_before_gate_or_knownhost_read(tmp_path,monkeypatch,damage):
    import sys
    parent=tmp_path/'custody';parent.mkdir(mode=0o700)
    if damage=='publicmode':parent.chmod(0o755);value=str(parent)
    elif damage=='symlink':
        link=tmp_path/'linked';link.symlink_to(parent,target_is_directory=True);value=str(link)
    else:value=str(parent)+'/.'
    monkeypatch.setenv('TMPDIR',value);monkeypatch.setattr(m,'load_contract',lambda *a:contract())
    monkeypatch.setattr(m,'_PASSWORD','INVENTED');monkeypatch.setattr(m,'_TOKEN','INVENTED')
    monkeypatch.setattr(sys,'argv',['reader','--contract','/invented','--contract-sha256','a'*64,'--reviewer-approval','/invented','--known-hosts','/invented','--custody',str(parent)])
    with patch.object(m,'gate_and_claim',side_effect=AssertionError('claim')),patch.object(m,'bounded_file',side_effect=AssertionError('host read')):
        assert m.main()==3
    assert not list(parent.iterdir())


def test_wrong_target_precedes_api_credential_shape_or_ssh_credential_read(tmp_path):
    c=contract();c['api']='http://127.0.0.1:8000/api/v1/foreign'
    with patch.object(m,'bounded_file',side_effect=AssertionError('host/secret read')),patch.object(m.subprocess,'run',side_effect=AssertionError('child')),patch.object(m.urllib.request,'build_opener',side_effect=AssertionError('HTTP')):
        with pytest.raises(ValueError,match='target commitment differs'):m.version(None,c)
        with pytest.raises(ValueError,match='target commitment differs'):m.read_remote(c,tmp_path/'missing',None,b'')


@pytest.mark.parametrize('damage',['source','destination','duplicate','foreignrow'])
def test_every_managed_link_refuses_tamper_before_git_child(tmp_path,monkeypatch,damage):
    from types import SimpleNamespace
    launchers=tmp_path/'bin';sources=tmp_path/'source';launchers.mkdir();sources.mkdir()
    gate=sources/'gate';peer=sources/'peer';gate.write_bytes(b'PUBLIC GATE');peer.write_bytes(b'PUBLIC FOREIGN-CAPABILITY SOURCE')
    launcher=launchers/'gate';other=launchers/'peer';launcher.symlink_to(gate);other.symlink_to(peer)
    gh=hashlib.sha256(gate.read_bytes()).hexdigest();ph=hashlib.sha256(peer.read_bytes()).hexdigest();head='a'*40
    rows=[['meta','source_sha',head,'-'],['symlink',str(launcher),str(gate),gh],['symlink',str(other),str(peer),ph]]
    if damage=='source':peer.write_bytes(b'MOVED PUBLIC SOURCE')
    elif damage=='destination':other.unlink();other.symlink_to(gate)
    elif damage=='duplicate':rows.append(rows[-1])
    elif damage=='foreignrow':rows[-1][2]=str(tmp_path/'foreign-bytes')
    manifest=tmp_path/'manifest';manifest.write_text(''.join('\t'.join(r)+'\n' for r in rows));manifest.chmod(0o600)
    monkeypatch.setattr(m,'GATE',str(launcher));monkeypatch.setattr(m,'GATE_SOURCE',str(gate));monkeypatch.setattr(m,'MANIFEST',str(manifest))
    original=m.os.lstat
    def root_links(path):
        info=original(path)
        if m.stat.S_ISLNK(info.st_mode):return SimpleNamespace(st_mode=info.st_mode,st_uid=0,st_nlink=info.st_nlink)
        return info
    monkeypatch.setattr(m.os,'lstat',root_links);root_fixture_ancestry(monkeypatch)
    c={'installed_gate':{'source_head':head,'launcher_sha256':gh,'manifest_sha256':hashlib.sha256(manifest.read_bytes()).hexdigest()}}
    opened=[];reader=m.bounded_file
    def bounded(path,maximum):opened.append(str(path));return reader(path,maximum)
    with patch.object(m,'bounded_file',side_effect=bounded),patch.object(m.subprocess,'run',side_effect=AssertionError('git child before complete closure')):
        with pytest.raises(ValueError):m.installed_gate(c)
    assert str(tmp_path/'foreign-bytes') not in opened

@pytest.mark.parametrize('damage',['parentrename','parentsymlink','leafreplace','leafsymlink','leafwrite','leafmode'])
def test_report_changed_during_gate_creates_zero_claims(tmp_path,monkeypatch,damage):
    tmp_path.chmod(0o700);reportdir=tmp_path/'reports';reportdir.mkdir(mode=0o700)
    output=tmp_path/'output';output.mkdir(mode=0o700);report=reportdir/'report';report.write_bytes(b'PUBLIC ORIGINAL REPORT');report.chmod(0o600)
    original=report.stat();called=[]
    def gate(argv,**kw):
        called.append(argv)
        assert '/proc/' in argv[-1] and Path(argv[-1]).read_bytes()==b'PUBLIC ORIGINAL REPORT'
        if damage in ('parentrename','parentsymlink'):
            moved=tmp_path/'moved';reportdir.rename(moved)
            if damage=='parentrename':reportdir.mkdir(mode=0o700)
            else:reportdir.symlink_to(moved,target_is_directory=True)
        elif damage=='leafreplace':
            report.rename(report.with_name('old'));report.write_bytes(b'FOREIGN REPORT');report.chmod(0o600)
        elif damage=='leafsymlink':report.unlink();report.symlink_to(tmp_path/'foreign')
        elif damage=='leafwrite':report.write_bytes(b'MUTATED REPORT')
        else:report.chmod(0o644)
        return type('R',(),{'returncode':0})()
    monkeypatch.setattr(m,'installed_gate',lambda c:None);monkeypatch.setattr(m,'verify_tailnet',lambda c:None)
    with patch.object(m.subprocess,'run',side_effect=gate):
        with pytest.raises((ValueError,OSError)):m.gate_and_claim(contract(),'a'*64,report,output)
    assert len(called)==1 and not list(output.iterdir())


def test_report_mutation_after_gate_and_before_claim_creates_zero_claims(tmp_path,monkeypatch):
    tmp_path.chmod(0o700);reportdir=tmp_path/'reports';reportdir.mkdir(mode=0o700);report=reportdir/'report';report.write_bytes(b'PUBLIC REPORT');report.chmod(0o600)
    output=tmp_path/'output';output.mkdir(mode=0o700)
    monkeypatch.setattr(m,'installed_gate',lambda c:None)
    def changed(c):report.write_bytes(b'AFTER GATE MUTATION')
    monkeypatch.setattr(m,'verify_tailnet',changed)
    with patch.object(m.subprocess,'run',return_value=type('R',(),{'returncode':0})()):
        with pytest.raises(ValueError):m.gate_and_claim(contract(),'a'*64,report,output)
    assert not list(output.iterdir())


def test_held_report_symlink_and_fifo_denied_before_gate(tmp_path,monkeypatch):
    tmp_path.chmod(0o700);target=tmp_path/'target';target.write_bytes(b'PUBLIC REPORT');target.chmod(0o600)
    symlink=tmp_path/'link';symlink.symlink_to(target);fifo=tmp_path/'fifo';os.mkfifo(fifo,0o600)
    with patch.object(m.subprocess,'run',side_effect=AssertionError('gate ran')):
        for path in (symlink,fifo):
            with pytest.raises((ValueError,OSError)):m.HeldReport(path)


def projection_module():
    spec=importlib.util.spec_from_file_location('public_projection',ROOT/'describe_action.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);module.inspector=m
    return module


def projection_fixture(tmp_path,monkeypatch,mode='discover'):
    tmp_path.chmod(0o700);private=tmp_path/'private';private.mkdir(mode=0o700)
    c=contract(mode);manifest=b'meta\tsource_sha\t'+b'a'*40+b'\t-\n'+b'symlink\tNONPRIVATE METADATA\n'*97
    c['installed_gate']['manifest_sha256']=hashlib.sha256(manifest).hexdigest()
    path=private/'actual.contract.json';raw=json.dumps(c).encode();path.write_bytes(raw);path.chmod(0o600)
    monkeypatch.setenv('TMPDIR',str(tmp_path));monkeypatch.setattr(m,'installed_gate',lambda value:value['installed_gate'])
    monkeypatch.setattr(m,'read_install_manifest',lambda:manifest);monkeypatch.setattr(m,'verify_tailnet',lambda c:None)
    return path,hashlib.sha256(raw).hexdigest(),c


def test_projection_exact_closed_privacy_and_no_authority(tmp_path,monkeypatch):
    module=projection_module();path,seal,c=projection_fixture(tmp_path,monkeypatch)
    c['claim_id']='future-claim-secret-sentinel'
    c['issued_at']=int(time.time())-1
    c['expires_at']=c['issued_at']+600
    raw=json.dumps(c).encode();path.write_bytes(raw);path.chmod(0o600);seal=hashlib.sha256(raw).hexdigest()
    with patch.object(m,'gate_and_claim',side_effect=AssertionError('claim')),patch.object(m,'version',side_effect=AssertionError('HTTP')),patch.object(m,'read_remote',side_effect=AssertionError('SSH')):
        value=module.describe(path,seal)
    text=json.dumps(value,sort_keys=True)
    assert value['schema']==module.PROJECTION_SCHEMA and value['contract_sha256']==seal and value['managed_link_count']==97
    assert value['non_authorizing'] is True and value['claims_created']==0 and value['credentials_used'] is False and value['remote_traffic']==0
    assert 'future-claim-secret-sentinel' not in text and str(c['issued_at']) not in text and str(c['expires_at']) not in text
    for forbidden in (str(path),str(path.parent),c['api'],c['host'],c['tailnet']['node_name'],*c['tailnet']['addresses'],c['tailnet']['route_source']):assert forbidden not in text
    assert set(value)=={'schema','contract_schema','mode','contract_sha256','operator_sha256','remote_sha256','transport_helper_sha256','fixed_target_commitment_sha256','fixed_peer_route_commitment_sha256','installed_gate','managed_link_count','scope','non_authorizing','claims_created','credentials_used','remote_traffic'}
    assert len(list(path.parent.iterdir()))==1


@pytest.mark.parametrize('damage',['digest','expiry','target','qualification','mode','link','fifo'])
def test_projection_bad_contract_zero_egress(tmp_path,monkeypatch,damage):
    module=projection_module();path,seal,c=projection_fixture(tmp_path,monkeypatch)
    if damage=='digest':seal='f'*64
    elif damage in ('expiry','target','mode','qualification'):
        if damage=='expiry':c['expires_at']=int(time.time())-1
        elif damage=='target':c['api']='http://127.0.0.1:8000/api/v1/foreign'
        elif damage=='mode':c['mode']='foreign'
        else:c=contract('qualify')
        raw=json.dumps(c).encode();path.write_bytes(raw);path.chmod(0o600);seal=hashlib.sha256(raw).hexdigest()
    elif damage=='link':
        target=path.with_name('target');path.rename(target);path.symlink_to(target)
    else:path.unlink();os.mkfifo(path,0o600)
    with patch.object(m,'gate_and_claim',side_effect=AssertionError('claim')),patch.object(m,'version',side_effect=AssertionError('HTTP')),patch.object(m,'read_remote',side_effect=AssertionError('SSH')),patch.object(m,'verify_tailnet',side_effect=AssertionError('local peer before valid contract')):
        with pytest.raises((ValueError,OSError)):module.describe(path,seal)


@pytest.mark.parametrize('kind',['ordinary','linked','bare'])
def test_projection_git_contract_refused_without_content_read(tmp_path,monkeypatch,kind):
    module=projection_module();repo=tmp_path/'repo';repo.mkdir(mode=0o700)
    if kind=='ordinary':(repo/'.git').mkdir()
    elif kind=='linked':(repo/'.git').write_bytes(b'gitdir: PUBLIC FIXTURE')
    else:
        (repo/'HEAD').write_bytes(b'ref: refs/heads/main');(repo/'objects').mkdir();(repo/'refs').mkdir()
    path=repo/'contract';path.write_bytes(b'PRIVATE CONTROL FIXTURE');path.chmod(0o600)
    with patch.object(m,'load_contract',side_effect=AssertionError('contract bytes read')),patch.object(m,'installed_gate',side_effect=AssertionError('gate read')),patch.object(m,'verify_tailnet',side_effect=AssertionError('peer')):
        with pytest.raises(ValueError):module.describe(path,'a'*64)



def test_projection_cli_errors_never_echo_private_values(capsys):
    module=projection_module()
    assert module.main(['--unknown','PRIVATE-PATH-SENTINEL'])==3
    captured=capsys.readouterr();assert captured.out=='' and 'PRIVATE-PATH-SENTINEL' not in captured.err


def test_projection_parent_swap_before_runtime_metadata_denies(tmp_path,monkeypatch):
    module=projection_module();path,seal,c=projection_fixture(tmp_path,monkeypatch)
    def moved(value):
        old=path.parent;renamed=old.with_name('renamed');old.rename(renamed);old.mkdir(mode=0o700)
        return value['installed_gate']
    monkeypatch.setattr(m,'installed_gate',moved)
    with patch.object(m,'verify_tailnet',side_effect=AssertionError('peer after changed contract parent')):
        with pytest.raises((ValueError,OSError)):module.describe(path,seal)

@pytest.mark.parametrize('field',['st_uid','st_gid','st_mode','st_nlink','st_ino','st_size','st_mtime_ns','st_ctime_ns'])
def test_report_immutable_stat_change_after_gate_refuses_before_claim(tmp_path,monkeypatch,field):
    from types import SimpleNamespace
    tmp_path.chmod(0o700);reportdir=tmp_path/'reports';reportdir.mkdir(mode=0o700);report=reportdir/'report';report.write_bytes(b'PUBLIC REPORT');report.chmod(0o600)
    output=tmp_path/'output';output.mkdir(mode=0o700);damaged=False;original=m.os.fstat;inode=report.stat().st_ino
    def fstat(fd):
        info=original(fd)
        if damaged and info.st_ino==inode:
            fields=('st_dev','st_ino','st_uid','st_gid','st_mode','st_nlink','st_size','st_mtime_ns','st_ctime_ns')
            values={key:getattr(info,key) for key in fields};values[field]+=1
            return SimpleNamespace(**values)
        return info
    def gate(*a,**kw):
        nonlocal damaged
        damaged=True;return type('R',(),{'returncode':0})()
    monkeypatch.setattr(m.os,'fstat',fstat);monkeypatch.setattr(m,'installed_gate',lambda c:None);monkeypatch.setattr(m,'verify_tailnet',lambda c:None)
    with patch.object(m.subprocess,'run',side_effect=gate):
        with pytest.raises(ValueError):m.gate_and_claim(contract(),'a'*64,report,output)
    assert not list(output.iterdir())

@pytest.mark.parametrize('damage',['writable','foreignuid'])
def test_report_untrusted_intermediate_ancestry_denies_before_gate(tmp_path,monkeypatch,damage):
    tmp_path.chmod(0o700);intermediate=tmp_path/'intermediate';intermediate.mkdir(mode=0o700);leaf=intermediate/'reports';leaf.mkdir(mode=0o700);report=leaf/'report';report.write_bytes(b'PUBLIC REPORT');report.chmod(0o600)
    if damage=='writable':intermediate.chmod(0o777)
    else:
        original=m.os.fstat;inode=intermediate.stat().st_ino
        def untrusted(fd):
            info=original(fd)
            if info.st_ino==inode:
                values=list(info);values[4]=os.getuid()+1;return os.stat_result(values)
            return info
        monkeypatch.setattr(m.os,'fstat',untrusted)
    with patch.object(m.subprocess,'run',side_effect=AssertionError('gate ran')),patch.object(m.os,'read',side_effect=AssertionError('report content read')):
        with pytest.raises(ValueError):m.HeldReport(report)


@pytest.mark.parametrize('damage',['parentrename','parentsymlink','leafreplace','leafsymlink','leafmode','hardlink','git','baregit','bareheadsymlink'])
def test_v5_held_input_actual_metadata_refusals(tmp_path,damage):
    tmp_path.chmod(0o700);parent=tmp_path/'private';parent.mkdir(mode=0o700)
    leaf=parent/'contract';leaf.write_bytes(b'PUBLIC INVENTED CONTRACT');leaf.chmod(0o600)
    if damage in ('git','baregit','bareheadsymlink'):
        if damage=='git':(parent/'.git').write_text('PUBLIC GIT MARKER')
        else:
            (parent/'objects').mkdir();(parent/'refs').mkdir()
            if damage=='baregit':(parent/'HEAD').write_text('PUBLIC HEAD')
            else:(parent/'HEAD').symlink_to(parent/'missing')
        with pytest.raises(ValueError):m.HeldInput(leaf,8192)
        return
    held=m.HeldInput(leaf,8192)
    try:
        assert held.raw==b'PUBLIC INVENTED CONTRACT'
        if damage in ('parentrename','parentsymlink'):
            moved=tmp_path/'moved';parent.rename(moved)
            if damage=='parentrename':parent.mkdir(mode=0o700)
            else:parent.symlink_to(moved,target_is_directory=True)
        elif damage=='leafreplace':leaf.rename(parent/'original');leaf.write_bytes(b'FOREIGN');leaf.chmod(0o600)
        elif damage=='leafsymlink':leaf.unlink();leaf.symlink_to(parent/'foreign')
        elif damage=='leafmode':leaf.chmod(0o644)
        else:os.link(leaf,parent/'alias')
        with pytest.raises((ValueError,OSError)):held.check()
        assert held.raw==b'PUBLIC INVENTED CONTRACT'
    finally:held.close()

@pytest.mark.parametrize('mode',[0o644,0o400,0o660])
def test_v5_private_input_requires_exact_600_before_read(tmp_path,mode):
    tmp_path.chmod(0o700);leaf=tmp_path/'private';leaf.write_bytes(b'PUBLIC');leaf.chmod(mode)
    with patch.object(m.os,'read',side_effect=AssertionError('unprotected content read')):
        with pytest.raises(ValueError):m.HeldInput(leaf,8192)

@pytest.mark.parametrize('hostname',['--help','foreign.invalid','127.000.0.1','2130706433','0x7f000001','127.0.0.1%flag','[::1]'])
def test_v5_api_requires_normal_ipv4_before_any_cli(hostname,monkeypatch):
    c=contract();c['api']='http://'+hostname+':8000/api/v1/version'
    monkeypatch.setattr(m,'TARGET_SHA256',m.canonical_commitment('oracle-platform-target/v4',{k:c[k] for k in TEST_TARGET}))
    with patch.object(m.subprocess,'run',side_effect=AssertionError('CLI on malformed address')):
        with pytest.raises(ValueError):m.target_contract(c)

@pytest.mark.parametrize('role',['tailscale','ip','git'])
def test_v5_os_closure_missing_pin_denies_before_children(role):
    c=contract();del c['tailnet']['os_cli'][role]
    with patch.object(m.subprocess,'run',side_effect=AssertionError('CLI without complete reviewed closure')):
        with pytest.raises(ValueError):m.verify_tailnet(c)


def test_v5_git_package_binary_mismatch_before_git_child(tmp_path,monkeypatch):
    import hashlib
    code=tmp_path/'git';code.write_bytes(b'PUBLIC INVENTED GIT');code.chmod(0o700)
    origin=tmp_path/'git.md5sums';origin.write_text(hashlib.md5(code.read_bytes()).hexdigest()+'  '+str(code)[1:]+'\n')
    monkeypatch.setitem(m.OS_FILES,'git',(str(code),str(origin)))
    monkeypatch.setattr(m,'root_ancestry',lambda *a:None)
    with patch.object(m.subprocess,'run',side_effect=AssertionError('unverified git executed')):
        with pytest.raises(ValueError,match='executable differs'):m.os_identity('git',{'binary_sha256':'0'*64,'package_manifest_sha256':hashlib.sha256(origin.read_bytes()).hexdigest()})
        with pytest.raises(ValueError,match='package origin moved'):m.os_identity('git',{'binary_sha256':hashlib.sha256(code.read_bytes()).hexdigest(),'package_manifest_sha256':'0'*64})


def test_v5_execution_contract_and_host_swap_gate_zero_claim(tmp_path,monkeypatch):
    import sys
    tmp_path.chmod(0o700);inputs=tmp_path/'inputs';inputs.mkdir(mode=0o700)
    output=tmp_path/'out';output.mkdir(mode=0o700);scratch=tmp_path/'scratch';scratch.mkdir(mode=0o700)
    hosts=inputs/'known-hosts';hosts.write_bytes(b'PUBLIC INVENTED HOST KEY\n'.ljust(142,b' '));hosts.chmod(0o600)
    c=contract();c['known_hosts_sha256']=hashlib.sha256(hosts.read_bytes()).hexdigest()
    leaf=inputs/'contract';raw=json.dumps(c).encode();leaf.write_bytes(raw);leaf.chmod(0o600)
    report=public_report(tmp_path);seen=[]
    def gate(argv,**kw):
        seen.append(argv);leaf.rename(inputs/'old');leaf.write_bytes(raw);leaf.chmod(0o600)
        return type('R',(),{'returncode':0})()
    monkeypatch.setenv('TMPDIR',str(scratch));monkeypatch.setattr(m,'_PASSWORD','PUBLIC INVENTED PASSWORD');monkeypatch.setattr(m,'_TOKEN','PUBLIC-INVENTED-TOKEN')
    monkeypatch.setattr(m,'installed_gate',lambda c:None);monkeypatch.setattr(m,'verify_tailnet',lambda c:None)
    monkeypatch.setattr(sys,'argv',['reader','--contract',str(leaf),'--contract-sha256',hashlib.sha256(raw).hexdigest(),'--reviewer-approval',str(report),'--known-hosts',str(hosts),'--custody',str(output)])
    with patch.object(m.subprocess,'run',side_effect=gate),patch.object(m,'version',side_effect=AssertionError('HTTP')),patch.object(m,'read_remote',side_effect=AssertionError('SSH')):
        assert m.main()==3
    assert len(seen)==1 and not list(output.iterdir())


def test_v5_preserves_old_unadmitted_templates_and_denies_v4(tmp_path):
    for name in ('discovery.contract.template.json','qualification.contract.template.json'):
        old=json.loads((ROOT/name).read_bytes());assert old['schema']=='oracle-platform-capability/v4' and old['expires_at']==0
    c=contract();c['schema']='oracle-platform-capability/v4';raw=json.dumps(c).encode();leaf=tmp_path/'old';leaf.write_bytes(raw)
    with pytest.raises(ValueError,match='closed contract mismatch'):m.load_contract(leaf,hashlib.sha256(raw).hexdigest())


@pytest.mark.parametrize('damage',['write','mode','rename','symlink','hardlink'])
def test_v5_knownhost_change_during_transport_refuses_received_bytes(tmp_path,monkeypatch,damage):
    tmp_path.chmod(0o700);inputs=tmp_path/'input';inputs.mkdir(mode=0o700);scratch=tmp_path/'scratch';scratch.mkdir(mode=0o700)
    hosts=inputs/'known-hosts';hosts.write_bytes(b'PUBLIC INVENTED HOST KEY\n'.ljust(142,b' '));hosts.chmod(0o600)
    c=contract();c['known_hosts_sha256']=hashlib.sha256(hosts.read_bytes()).hexdigest();held=m.HeldInput(hosts,142,exact_size=142)
    def ssh(argv,**kw):
        if damage=='write':hosts.write_bytes(b'FOREIGN'.ljust(142,b' '))
        elif damage=='mode':hosts.chmod(0o644)
        elif damage=='rename':inputs.rename(tmp_path/'moved');inputs.mkdir(mode=0o700)
        elif damage=='symlink':hosts.unlink();hosts.symlink_to(inputs/'foreign')
        else:os.link(hosts,inputs/'alias')
        kw['stdout'].write(b'FOREIGN RECEIPT');return type('R',(),{'returncode':0})()
    monkeypatch.setenv('TMPDIR',str(scratch))
    try:
        with patch.object(m.subprocess,'run',side_effect=ssh):
            with pytest.raises((ValueError,OSError)):m.read_remote(c,held,'PUBLIC INVENTED PASSWORD',(ROOT/'remote.py').read_bytes())
        assert held.raw.startswith(b'PUBLIC INVENTED HOST KEY')
    finally:held.close()

@pytest.mark.parametrize('size',[141,143])
def test_v5_knownhost_exact142_before_byte_read(tmp_path,size):
    tmp_path.chmod(0o700);hosts=tmp_path/'known-hosts';hosts.write_bytes(b'X'*size);hosts.chmod(0o600)
    with patch.object(m.os,'read',side_effect=AssertionError('unexpected host bytes read')):
        with pytest.raises(ValueError):m.HeldInput(hosts,142,exact_size=142)


@pytest.mark.parametrize('damage',['leafwrite','leafreplace','parentrename'])
def test_final_held_contract_recheck_after_source_pin_loop(tmp_path,monkeypatch,damage):
    tmp_path.chmod(0o700);parent=tmp_path/'inputs';parent.mkdir(mode=0o700)
    leaf=parent/'contract';raw=json.dumps(contract()).encode();leaf.write_bytes(raw);leaf.chmod(0o600)
    held=m.HeldInput(leaf,8192);original=m.bounded_file;source_reads=[]
    def source_read(path,maximum):
        result=original(path,maximum);source_reads.append(str(path))
        if len(source_reads)==3:
            if damage=='leafwrite':leaf.write_bytes(b'MUTATED PUBLIC FIXTURE')
            elif damage=='leafreplace':leaf.rename(parent/'original');leaf.write_bytes(raw);leaf.chmod(0o600)
            else:parent.rename(tmp_path/'moved');parent.mkdir(mode=0o700)
        return result
    try:
        with patch.object(m,'bounded_file',side_effect=source_read),patch.object(m,'gate_and_claim',side_effect=AssertionError('claim')),patch.object(m,'verify_tailnet',side_effect=AssertionError('WHOIS')),patch.object(m.subprocess,'run',side_effect=AssertionError('child')):
            with pytest.raises((ValueError,OSError)):m.load_contract(held,hashlib.sha256(raw).hexdigest())
        assert len(source_reads)==3 and held.raw==raw
    finally:held.close()
