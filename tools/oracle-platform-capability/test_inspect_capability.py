"""Public fixtures only; never contact API, SSH, Docker or credentials."""
import hashlib,importlib.util,json,os,subprocess,time
from pathlib import Path
from unittest.mock import patch
import pytest
ROOT=Path(__file__).parent
spec=importlib.util.spec_from_file_location('capability',ROOT/'inspect_capability.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def contract(mode='discover'):
    c={**m.FIXED,'mode':mode,'issued_at':int(time.time())-1,'expires_at':int(time.time())+600,'installed_gate':{'source_head':'a'*40,'launcher_sha256':'b'*64,'manifest_sha256':'c'*64},'claim_id':'public-invented-test','known_hosts_sha256':'a'*64,'tailnet':{**m.PEER,'os_cli':{k:{'binary_sha256':'a'*64,'package_manifest_sha256':'b'*64} for k in m.OS_FILES}}}
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
    tmp_path.chmod(0o700);hosts=tmp_path/'hosts';hosts.write_bytes(b'INVENTED HOST KEY\n');c=contract();c['known_hosts_sha256']=hashlib.sha256(hosts.read_bytes()).hexdigest();source=(ROOT/'remote.py').read_bytes();calls=[]
    original=subprocess.run
    def fake(argv,**kw):
        calls.append((argv,kw));assert argv[0]=='/usr/bin/ssh' and argv[-1].startswith('/usr/bin/python3 -c ')
        child=kw['env'];assert all('PASSWORD' not in k and 'TOKEN' not in k for k in child)
        result=original([child['SSH_ASKPASS']],env=child,capture_output=True,timeout=3)
        assert result.returncode==0 and result.stdout==b'INVENTED PASSWORD'
        kw['stdout'].write(b'{}');return type('R',(),{'returncode':0})()
    with patch.dict(os.environ,{'TMPDIR':str(tmp_path)}),patch.object(m.subprocess,'run',fake):
        assert m.read_remote(c,hosts,'INVENTED PASSWORD',source)==b'{}'
    assert calls and sorted(x.name for x in tmp_path.iterdir())==['hosts']


def test_installed_gate_manifest_source_identity(tmp_path):
    from types import SimpleNamespace
    launcher=tmp_path/'gate';source=tmp_path/'source';manifest=tmp_path/'manifest';source.write_bytes(b'PUBLIC GATE');launcher.symlink_to(source)
    h=hashlib.sha256(source.read_bytes()).hexdigest();head='a'*40
    manifest.write_text('meta\tsource_sha\t'+head+'\t-\nsymlink\t'+str(launcher)+'\t'+str(source)+'\t'+h+'\n')
    manifest.chmod(0o644)
    c=contract();c['installed_gate']={'source_head':head,'launcher_sha256':h,'manifest_sha256':hashlib.sha256(manifest.read_bytes()).hexdigest()}
    original=m.os.lstat
    def root_fixture(path):
        st=original(path)
        if str(path) in (str(launcher),str(manifest)):return SimpleNamespace(st_mode=st.st_mode,st_uid=0,st_nlink=st.st_nlink)
        return st
    seen=[]
    def fake(argv,**kw):
        seen.append((argv,kw));return SimpleNamespace(returncode=0,stdout=(head+'\n').encode() if argv[-1]=='HEAD' else b'')
    with patch.object(m,'GATE',str(launcher)),patch.object(m,'GATE_SOURCE',str(source)),patch.object(m,'MANIFEST',str(manifest)),patch.object(m.os,'lstat',root_fixture),patch.object(m.subprocess,'run',fake):
        m.installed_gate(c);assert len(seen)==2 and all(x[1]['env']['HOME']=='/home/ahazan' for x in seen)
        source.write_bytes(b'MOVED PUBLIC SOURCE')
        with pytest.raises(ValueError,match='source changed'):m.installed_gate(c)

@pytest.fixture
def invented_peer(monkeypatch):
    key='nodekey:'+'1'*64;expected={**m.PEER,'node_key_sha256':hashlib.sha256(key.encode()).hexdigest()}
    monkeypatch.setattr(m,'PEER',expected)
    who={'Node':{'ID':expected['node_id'],'Name':expected['node_name'],'Addresses':expected['addresses'],'Key':key,'Tags':expected['tags']}}
    route=[{'dst':m.TARGET,'dev':'tailscale0','table':'52','prefsrc':expected['route_source'],'flags':[]}]
    monkeypatch.setattr(m,'os_identity',lambda *a:None);monkeypatch.setattr(m,'root_ancestry',lambda *a:(1,2))
    def local(argv,maximum):return who if argv[0]=='/usr/bin/tailscale' else route
    monkeypatch.setattr(m,'local_metadata',local)
    return who,route

@pytest.mark.parametrize('damage',['node','key','name','address','tags','missingtags','missingkey','route','device','source','table','expired','unknown'])
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
    else:who.clear()
    with patch.object(m.urllib.request,'build_opener',side_effect=AssertionError('HTTP constructed')):
        with pytest.raises((ValueError,TypeError)):m.version('INVENTED',contract())


def test_fixed_peer_null_expiry_is_unknown_not_unexpired(invented_peer):
    who,_=invented_peer
    assert m.verify_tailnet(contract())['peer_expiry']=='UNKNOWN'
    who['Node'].update(KeyExpiry=None,Expired=None)
    assert m.verify_tailnet(contract())['peer_expiry']=='UNKNOWN'


def test_peer_rechecked_after_http_before_metadata_accepted(invented_peer):
    who,_=invented_peer
    class Response:
        status=200
        def geturl(self):return m.API
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
        with pytest.raises(PermissionError):m.BoundConnection(m.TARGET,8000).connect()
    assert calls[-1]==('closed',)


def test_multiple_exact_tags_preserved_not_subset(invented_peer,monkeypatch):
    who,_=invented_peer;expected={**m.PEER,'tags':['tag:a','tag:server']};monkeypatch.setattr(m,'PEER',expected);who['Node']['Tags']=['tag:a','tag:server']
    assert m.verify_tailnet(contract())['encrypted_route_bound'] is True
    who['Node']['Tags']=['tag:server']
    with pytest.raises(ValueError):m.verify_tailnet(contract())


def test_review_templates_pin_current_code_and_stay_unadmitted():
    for name in ('discovery.contract.template.json','qualification.contract.template.json'):
        c=json.loads((ROOT/name).read_bytes())
        assert c['schema']=='oracle-platform-capability/v3' and c['issued_at']==0 and c['expires_at']==0
        assert c['tailnet']['tags']==['tag:server'] and c['tailnet']['node_key_sha256']=='7f327508633eb57fdd8b054f2334e059e5d9c0354ea0932c5879865eaac0c039'
        assert c['operator_sha256']==hashlib.sha256((ROOT/'inspect_capability.py').read_bytes()).hexdigest()
        assert c['remote_sha256']==hashlib.sha256((ROOT/'remote.py').read_bytes()).hexdigest()


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
