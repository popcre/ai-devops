#!/usr/bin/env python3
"""Bounded, read-only SSH Docker metadata; no logs, env, exec, ingress or writes.

Owner: Oracle #27/#58 coordinator. Retire after native hosting acceptance, or
consolidate into an existing platform metadata reader. Runtime contract is
independently reviewed by digest; this tool creates no operational authority.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import resource
import sys
import stat

LIMIT = 65536
APP = 'vhmcdkdk23dgvjvcvhyhcjzd'
SAFE_FAILURES = {'input file bound exceeded', 'known-hosts changed',
                 'protected credential missing', 'protected temp parent required',
                 'ssh_authentication_refused', 'ssh_host_key_refused',
                 'ssh_name_resolution_failed', 'ssh_connection_refused',
                 'ssh_transport_failed', 'remote_metadata_reader_refused',
                 'metadata fields differ', 'metadata bound exceeded',
                 'container count differs', 'container namespace differs',
                 'container identity differs', 'state differs', 'state types differ',
                 'timestamp differs', 'revision differs', 'image differs',
                 'duplicate role differs'}
FIELDS = {'id', 'name', 'image_id', 'image', 'service', 'project', 'application', 'revision', 'status', 'health', 'exit_code', 'started_at', 'finished_at', 'restarts'}
# Go template reads only the named fields. Never marshal .Config or .State.
TEMPLATE = ('{"id":{{json .Id}},"name":{{json .Name}},"image_id":{{json .Image}},'
 '"image":{{json .Config.Image}},"service":{{json (index .Config.Labels "com.docker.compose.service")}},'
 '"project":{{json (index .Config.Labels "com.docker.compose.project")}},"application":{{json (index .Config.Labels "coolify.applicationUuid")}},'
 '"revision":{{with (index .Config.Labels "org.opencontainers.image.revision")}}{{json .}}{{else}}""{{end}},'
 '"status":{{json .State.Status}},"health":{{with (index .State "Health")}}{{json .Status}}{{else}}"absent"{{end}},'
 '"exit_code":{{json .State.ExitCode}},"started_at":{{json .State.StartedAt}},'
 '"finished_at":{{json .State.FinishedAt}},"restarts":{{json .RestartCount}}}')


def require(value, reason):
    if not value:
        raise ValueError(reason)


def transport_failure(code, error):
    # Classify only fixed transport phrases. Never return, persist or hash the
    # raw stderr; a remote peer could place sensitive text there.
    if code != 255:
        return 'remote_metadata_reader_refused'
    for phrase, reason in ((b'Permission denied', 'ssh_authentication_refused'),
                           (b'Host key verification failed', 'ssh_host_key_refused'),
                           (b'Could not resolve hostname', 'ssh_name_resolution_failed'),
                           (b'Connection refused', 'ssh_connection_refused')):
        if phrase in error:
            return reason
    return 'ssh_transport_failed'


def bounded_file(path, limit):
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    try:
        require(stat.S_ISREG(os.fstat(fd).st_mode), 'regular input file required')
        value = os.read(fd, limit + 1)
        require(len(value) <= limit, 'input file bound exceeded')
        return value
    finally:
        os.close(fd)


def load_contract(path, digest):
    raw = bounded_file(path, LIMIT)
    require(len(raw) <= LIMIT and hashlib.sha256(raw).hexdigest() == digest, 'contract digest differs')
    contract = json.loads(raw)
    require(set(contract) == {'schema', 'application', 'host', 'user', 'port', 'known_hosts_sha256', 'services', 'image', 'revision', 'application_label', 'project', 'vendor_images'}, 'contract fields differ')
    require(contract['application_label'] == 'coolify.applicationUuid', 'application label differs')
    require(contract['schema'] == 'oracle-hosting-metadata/v1' and contract['application'] == APP, 'application differs')
    require(re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9.-]{0,252}', contract['host']) and re.fullmatch(r'[a-z_][a-z0-9_-]{0,31}', contract['user']), 'SSH identity differs')
    require(type(contract['port']) is int and 1 <= contract['port'] <= 65535, 'SSH port differs')
    require(re.fullmatch(r'[a-f0-9]{64}', contract['known_hosts_sha256']), 'host-key digest differs')
    require(contract['host'] == 'hetz' and contract['user'] == 'ai' and contract['port'] == 22, 'pinned host differs')
    require(contract['project'] == 'oracle-native-' + APP, 'project differs')
    services = contract['services']
    require(type(services) is list and len(services) == 18 and len(set(services)) == 18 and all(re.fullmatch(r'[a-z0-9][a-z0-9-]{0,63}', s) for s in services), '18-role closure differs')
    require(re.fullmatch(r'ghcr.io/u2giants/theoracle-native@sha256:[a-f0-9]{64}', contract['image']) and re.fullmatch(r'[a-f0-9]{40}', contract['revision']), 'source pin differs')
    require(contract['vendor_images'] == {
        'ledger':'postgres:16.10-alpine@sha256:029660641a0cfc575b14f336ba448fb8a75fd595d42e1fa316b9fb4378742297',
        'candidate':'falkordb/falkordb:v4.20.7@sha256:13996aa523f0dd283f6bd6df6620b094dcea525452417c4d6ef9bef15dc9998d',
        'confirmed':'falkordb/falkordb:v4.20.7@sha256:13996aa523f0dd283f6bd6df6620b094dcea525452417c4d6ef9bef15dc9998d'}, 'vendor pins differ')
    return contract


def remote_command(contract):
    # Remote output is already allowlisted. IDs are selected by exact namespace
    # name token and independently checked against the reviewed 18-role closure.
    program = '''import json,re,subprocess,sys\nAPP=%r\nLABEL=%r\nTEMPLATE=%r\np=subprocess.run(['docker','ps','-a','--no-trunc','--filter','label='+LABEL+'='+APP,'--format','{{.ID}}'],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=8)\nif p.returncode or len(p.stdout)>8192: sys.exit(3)\nids=p.stdout.decode('ascii').splitlines()\nif not 1<=len(ids)<=18 or any(not re.fullmatch('[a-f0-9]{64}',i) for i in ids):sys.exit(3)\nrows=[]\nfor i in ids:\n p=subprocess.run(['docker','inspect','--format',TEMPLATE,i],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,timeout=2)\n if p.returncode or len(p.stdout)>4096:sys.exit(3)\n row=json.loads(p.stdout)\n if not re.search(r'(^|[-_])'+APP+r'($|[-_])',row['name']):sys.exit(3)\n rows.append(row)\nprint(json.dumps(rows,separators=(',',':')))\n''' % (APP, contract['application_label'], TEMPLATE)
    encoded = base64.b64encode(program.encode()).decode('ascii')
    return 'python3 -c "import base64;exec(base64.b64decode(\'' + encoded + '\'))"'


def validate_rows(raw, contract):
    require(len(raw) <= LIMIT, 'metadata bound exceeded')
    rows = json.loads(raw)
    require(type(rows) is list and 1 <= len(rows) <= 18, 'container count differs')
    seen = set()
    for row in rows:
        require(type(row) is dict and set(row) == FIELDS, 'metadata fields differ')
        require(re.fullmatch(r'[a-f0-9]{64}', row['id']) and row['id'] not in seen, 'container identity differs')
        seen.add(row['id'])
        require(re.search(r'(^|[-_])' + APP + r'($|[-_])', row['name']) and row['service'] in contract['services'] and row['project'] == contract['project'] and row['application'] == APP and row['name'] == '/' + contract['project'] + '-' + row['service'] + '-1', 'container namespace differs')
        require(row['status'] in {'created','running','paused','restarting','removing','exited','dead'} and row['health'] in {'absent','starting','healthy','unhealthy'}, 'state differs')
        require(type(row['exit_code']) is int and type(row['restarts']) is int and row['restarts'] >= 0, 'state types differ')
        for key in ('started_at','finished_at'):
            require(type(row[key]) is str and re.fullmatch(r'[0-9T:Z.+-]{1,40}', row[key]), 'timestamp differs')
        require(type(row['revision']) is str and (row['revision'] == '' or re.fullmatch(r'[a-f0-9]{40}', row['revision'])), 'revision differs')
        require(re.fullmatch(r'sha256:[a-f0-9]{64}', row['image_id']) and type(row['image']) is str and re.fullmatch(r'[a-z0-9./:_-]+@sha256:[a-f0-9]{64}', row['image']), 'image differs')
    roles = [row['service'] for row in rows]
    require(len(set(roles)) == len(roles), 'duplicate role differs')
    # Missing/exited roles are findings, never silently healthy completion.
    return {'schema':'oracle-hosting-metadata-result/v1','application':APP,'contract_sha256':hashlib.sha256(json.dumps(contract,sort_keys=True,separators=(',',':')).encode()).hexdigest(),
            'expected_image':contract['image'],'expected_revision':contract['revision'],'missing_roles':sorted(set(contract['services'])-set(roles)),
            'image_mismatch_roles':sorted(row['service'] for row in rows if row['image'] != contract['vendor_images'].get(row['service'],contract['image'])),
            'revision_mismatch_roles':sorted(row['service'] for row in rows if row['service'] not in contract['vendor_images'] and row['revision'] != contract['revision']),
            'containers':sorted(rows,key=lambda row:row['service']),'metadata_sha256':hashlib.sha256(raw).hexdigest(),'cause':'UNKNOWN'}


def read_remote(contract, known_hosts):
    hosts=bounded_file(known_hosts,8192)
    require(len(hosts)<=8192 and hashlib.sha256(hosts).hexdigest()==contract['known_hosts_sha256'],'known-hosts changed')
    password=os.environ.pop('ORACLE_HETZ_READ_PASSWORD',None)
    require(type(password) is str and password and len(password.encode('utf-8')) <= LIMIT and '\x00' not in password and '\n' not in password and '\r' not in password,'protected credential missing')
    parent=os.environ.get('TMPDIR')
    if parent is not None:
        parent_stat=os.stat(parent,follow_symlinks=False)
        require(stat.S_ISDIR(parent_stat.st_mode) and parent_stat.st_uid==os.getuid() and stat.S_IMODE(parent_stat.st_mode)==0o700,'protected temp parent required')
    with tempfile.TemporaryDirectory(prefix='oracle-metadata-',dir=parent) as directory:
        os.chmod(directory,0o700)
        pinned_hosts=Path(directory)/'known-hosts'
        fd=os.open(pinned_hosts,os.O_CREAT|os.O_EXCL|os.O_WRONLY|os.O_NOFOLLOW,0o600)
        with os.fdopen(fd,'wb') as stream:stream.write(hosts)
        secret=Path(directory)/'password'
        fd=os.open(secret,os.O_CREAT|os.O_EXCL|os.O_WRONLY|os.O_NOFOLLOW,0o600)
        with os.fdopen(fd,'w') as stream:stream.write(password)
        del password
        helper=Path(directory)/'askpass'
        helper_source=('#!'+sys.executable+'\nimport os,stat,sys\n'
          'try:fd=os.open('+repr(str(secret))+',os.O_RDONLY|os.O_NOFOLLOW)\n'
          'except OSError:sys.exit(3)\n'
          'st=os.fstat(fd)\n'
          'if not stat.S_ISREG(st.st_mode) or st.st_uid!=os.getuid() or st.st_mode&0o777!=0o600 or st.st_size>65536:sys.exit(3)\n'
          'with os.fdopen(fd,\"rb\") as stream:sys.stdout.buffer.write(stream.read(65537))\n')
        fd=os.open(helper,os.O_CREAT|os.O_EXCL|os.O_WRONLY|os.O_NOFOLLOW,0o700)
        with os.fdopen(fd,'w') as stream:stream.write(helper_source)
        child={'PATH':'/usr/bin:/bin','LANG':'C','SSH_ASKPASS':str(helper),'SSH_ASKPASS_REQUIRE':'force','DISPLAY':'oracle-metadata:0'}
        command=['/usr/bin/ssh','-F','/dev/null','-T','-p','22','-o','StrictHostKeyChecking=yes','-o','UserKnownHostsFile='+str(pinned_hosts),'-o','GlobalKnownHostsFile=/dev/null','-o','ConnectTimeout=10','-o','ConnectionAttempts=1','-o','NumberOfPasswordPrompts=1','-o','IdentitiesOnly=yes','-o','PubkeyAuthentication=no','-o','PreferredAuthentications=password','-o','ProxyCommand=none','-o','ProxyJump=none','-o','ClearAllForwardings=yes','ai@hetz',remote_command(contract)]
        def bound_file():resource.setrlimit(resource.RLIMIT_FSIZE,(LIMIT,LIMIT))
        with tempfile.TemporaryFile(dir=directory) as output, tempfile.TemporaryFile(dir=directory) as error:
            result=subprocess.run(command,stdin=subprocess.DEVNULL,stdout=output,stderr=error,timeout=55,env=child,start_new_session=True,preexec_fn=bound_file)
            if result.returncode:
                error.seek(0)
                raise ValueError(transport_failure(result.returncode,error.read(4097)))
            output.seek(0)
            return output.read(LIMIT+1)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--contract',required=True)
    parser.add_argument('--contract-sha256',required=True)
    parser.add_argument('--remote-command',action='store_true')
    parser.add_argument('--known-hosts')
    args=parser.parse_args()
    try:
        contract=load_contract(args.contract,args.contract_sha256)
        if args.remote_command:
            print(remote_command(contract))
            return 0
        raw=read_remote(contract,args.known_hosts) if args.known_hosts else sys.stdin.buffer.read(LIMIT+1)
        print(json.dumps(validate_rows(raw,contract),sort_keys=True))
    except Exception as error:
        reason = str(error) if isinstance(error, ValueError) and str(error) in SAFE_FAILURES else 'metadata_reader_refused'
        print(json.dumps({'completed':False,'read_only':True,'reason':reason}),file=sys.stderr)
        return 3
    return 0

if __name__=='__main__':
    raise SystemExit(main())
