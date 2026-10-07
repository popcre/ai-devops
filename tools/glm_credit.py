#!/usr/bin/env python3
"""Provisioning-only private cache and one official, non-generating quota read."""
import datetime
import hashlib
import json
import math
import os
import pathlib
import shutil
import socket
import stat
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from reviewer_maintenance import physical, Blocked

ROOT = pathlib.Path(__file__).resolve().parent.parent
ENDPOINT = 'https://api.z.ai/api/monitor/usage/quota/limit'
MODEL = 'glm-5.3'
MAX_BYTES = 65536

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None

def fingerprint(value):
    return 'sha256:' + hashlib.sha256(value.encode()).hexdigest()

def reference_digest(config):
    lines = (config / 'mcp.env').read_text().splitlines()
    references = [line for line in lines if line.startswith('ZAI_API_KEY=op://')]
    if len(references) != 1:
        raise ValueError('unbound-reference')
    return fingerprint(references[0])

def unlinked(path):
    if not path.is_absolute():
        raise ValueError('relative-path')
    physical(path, conversion_timeout=2)

def windows_private(path, action, *, payload=None, directory=False):
    executable = shutil.which('pwsh') or shutil.which('powershell')
    if not executable:
        raise ValueError('acl-unavailable')
    helper = ROOT / 'bin/windows-private-file.ps1'
    environment = dict(os.environ, AI_DEVOPS_PRIVATE_HELPER=str(helper),
                       AI_DEVOPS_PRIVATE_TARGET=str(path))
    if action == 'publish':
        command = ('. $env:AI_DEVOPS_PRIVATE_HELPER; '
                   '$bytes=[Text.Encoding]::UTF8.GetBytes([Console]::In.ReadToEnd()); '
                   '$null=Set-AiDevOpsPrivateFileAtomic -Path $env:AI_DEVOPS_PRIVATE_TARGET -Bytes $bytes')
    elif action == 'protect':
        command = ('. $env:AI_DEVOPS_PRIVATE_HELPER; Protect-AiDevOpsPrivatePath '
                   '-Path $env:AI_DEVOPS_PRIVATE_TARGET' + (' -Directory' if directory else ''))
    else:
        command = '. $env:AI_DEVOPS_PRIVATE_HELPER; Assert-AiDevOpsPrivateAcl -Path $env:AI_DEVOPS_PRIVATE_TARGET'
    result = subprocess.run([executable, '-NoProfile', '-NonInteractive', '-Command', command],
                            input=payload, text=True, capture_output=True, env=environment,
                            timeout=15, check=False)
    if result.returncode:
        raise ValueError('acl-refused')

def private(path, *, directory=False):
    unlinked(path)
    info = path.stat()
    if directory != stat.S_ISDIR(info.st_mode) or (not directory and not stat.S_ISREG(info.st_mode)):
        raise ValueError('wrong-file-kind')
    if os.name == 'nt':
        windows_private(path, 'assert')
    elif info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != (0o700 if directory else 0o600):
        raise ValueError('insecure-cache')

def publish(config, key):
    unlinked(config)
    if not key or len(key) > 4096 or any(ord(c) < 33 or ord(c) > 126 for c in key):
        raise ValueError('invalid-key')
    parent = config / 'secrets'
    unlinked(parent)
    if not parent.exists():
        parent.mkdir(mode=0o700)
        if os.name == 'nt':
            windows_private(parent, 'protect', directory=True)
    private(parent, directory=True)
    path = parent / 'zai-coding-plan-key.json'
    unlinked(path)
    if path.exists():
        private(path)
    data = {'schema_version': 1, 'provider': 'glm', 'model': MODEL, 'endpoint': ENDPOINT,
            'reference_digest': reference_digest(config), 'key_fingerprint': fingerprint(key),
            'key': key}
    payload = json.dumps(data, separators=(',', ':'))
    if os.name == 'nt':
        windows_private(path, 'publish', payload=payload)
    else:
        descriptor, candidate = tempfile.mkstemp(prefix='.zai-key-', dir=parent)
        try:
            with os.fdopen(descriptor, 'w') as stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
            private(pathlib.Path(candidate))
            os.replace(candidate, path)
        finally:
            if os.path.exists(candidate):
                os.unlink(candidate)
    private(path)

def cached_key(config):
    path = config / 'secrets/zai-coding-plan-key.json'
    private(path.parent, directory=True)
    private(path)
    descriptor = os.open(path, os.O_RDONLY | getattr(os, 'O_NOFOLLOW', 0))
    with os.fdopen(descriptor) as stream:
        payload = stream.read(8193)
    if len(payload) > 8192:
        raise ValueError('oversize-cache')
    value = json.loads(payload)
    if not isinstance(value, dict):
        raise ValueError('malformed-cache')
    key = value.get('key')
    if (type(value.get('schema_version')) is not int or value['schema_version'] != 1 or value.get('provider') != 'glm'
            or value.get('model') != MODEL or value.get('endpoint') != ENDPOINT
            or value.get('reference_digest') != reference_digest(config)
            or not isinstance(key, str) or not key or len(key) > 4096
            or any(ord(c) < 33 or ord(c) > 126 for c in key)
            or value.get('key_fingerprint') != fingerprint(key)):
        raise ValueError('unbound-cache')
    return key

def observation(key, *, opener=None, now=None):
    checked = (now or datetime.datetime.now(datetime.timezone.utc)).strftime('%Y-%m-%dT%H:%M:%SZ')
    result = {'provider': 'glm', 'state': 'unknown', 'reason': 'read-unavailable',
              'checked_at': checked, 'qualified_version': 'zai-model-quota-v1',
              'source_kind': 'official-zai-model-quota', 'model_scope': MODEL,
              'credential_profile_scope': fingerprint(key) if isinstance(key, str) else None}
    try:
        if not isinstance(key, str) or not key or len(key) > 4096 or any(ord(c) < 33 or ord(c) > 126 for c in key):
            raise ValueError('invalid-key')
        request = urllib.request.Request(ENDPOINT, headers={'authorization': key, 'Accept': 'application/json'}, method='GET')
        open_request = opener or urllib.request.build_opener(NoRedirect()).open
        with open_request(request, timeout=15) as response:
            payload = response.read(MAX_BYTES + 1)
        if len(payload) > MAX_BYTES:
            raise ValueError('oversize')
        value = json.loads(payload)
        if (not isinstance(value, dict) or type(value.get('code')) is not int
                or value['code'] not in (0, 200) or value.get('success') is False):
            raise ValueError('unsuccessful-envelope')
        limits = value.get('data', {}).get('limits')
        if not isinstance(limits, list):
            raise ValueError('missing-limits')
        periods = {}
        for limit in limits:
            if not isinstance(limit, dict):
                raise ValueError('malformed-limit')
            if limit.get('type') not in ('TOKENS_LIMIT', 'CREDIT_LIMIT'):
                continue
            if type(limit.get('unit')) is not int or type(limit.get('number')) is not int:
                raise ValueError('malformed-period')
            period = (limit['unit'], limit['number'])
            if period not in ((3, 5), (6, 1)):
                raise ValueError('unqualified-model-period')
            if period in periods:
                raise ValueError('duplicate-period')
            remaining = limit.get('remaining')
            used = limit.get('percentage')
            if (type(remaining) not in (int, float) or not math.isfinite(remaining) or remaining < 0
                    or type(used) not in (int, float) or not math.isfinite(used) or not 0 <= used <= 100
                    or (remaining == 0) != (used == 100)):
                raise ValueError('malformed-or-conflicting-capacity')
            periods[period] = remaining
        if set(periods) != {(3, 5), (6, 1)}:
            raise ValueError('missing-period')
        exhausted = 0 in periods.values()
        result.update(state='exhausted' if exhausted else 'available',
                      reason='reported-exhaustion' if exhausted else 'reported-capacity')
    except urllib.error.HTTPError as error:
        result['reason'] = 'authentication-error' if error.code in (401, 403) else 'transport-error'
    except (TimeoutError, socket.timeout):
        result['reason'] = 'timeout'
    except urllib.error.URLError as error:
        result['reason'] = 'timeout' if isinstance(error.reason, (TimeoutError, socket.timeout)) else 'transport-error'
    except (OSError, ValueError, TypeError, AttributeError):
        result['reason'] = 'unqualified-response'
    return result

def main(args=None):
    args = sys.argv[1:] if args is None else args
    try:
        if os.environ.get('AI_GLM_MODEL', MODEL) != MODEL:
            raise ValueError('unqualified-model-profile')
        configured = os.environ.get('AI_DEVOPS_CONFIG_DIR', str(pathlib.Path.home() / '.config/ai-devops'))
        if not pathlib.Path(configured).is_absolute() and not (os.name == 'nt' and configured.startswith('/')):
            raise ValueError('relative-config')
        config = physical(configured, conversion_timeout=2)
        if args == ['publish']:
            publish(config, sys.stdin.read(4097).rstrip('\r\n'))
            return 0
        if args != ['check']:
            return 2
        result = observation(cached_key(config))
    except (OSError, ValueError, TypeError, subprocess.SubprocessError, Blocked):
        result = {'provider': 'glm', 'state': 'unknown', 'reason': 'unbound-cache'}
        if args == ['publish']:
            return 1
    # Private fingerprint is retained only within the observation pipeline.
    print(json.dumps(result, separators=(',', ':')))
    return 0

if __name__ == '__main__':
    sys.exit(main())
