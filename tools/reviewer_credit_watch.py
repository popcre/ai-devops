#!/usr/bin/env python3
"""Hourly non-generating credit observations through the existing duty pool.

check reads only; tick first claims the existing duty lease and applies only
explicit exhaustion holds. No scheduler, credential fetch, unpause or roster edit.
"""
import datetime
import json
import math
import os
import pathlib
import re
import subprocess
import sys
import struct
import uuid
import tempfile

from reviewer_maintenance import physical, Blocked

ROOT = pathlib.Path(__file__).resolve().parent.parent
UNQUALIFIED = ('grok', 'muse', 'qwen')

def windows_git_roots():
    """OS folder authority; caller environment is never installation authority."""
    import ctypes
    shell = ctypes.WinDLL('shell32', use_last_error=True)
    ole = ctypes.WinDLL('ole32', use_last_error=True)
    shell.SHGetKnownFolderPath.argtypes = [ctypes.c_void_p, ctypes.c_uint32,
                                          ctypes.c_void_p, ctypes.POINTER(ctypes.c_void_p)]
    shell.SHGetKnownFolderPath.restype = ctypes.c_long
    ole.CoTaskMemFree.argtypes = [ctypes.c_void_p]
    ole.CoTaskMemFree.restype = None
    roots = []
    for identifier, suffix in (
            ('905e63b6-c1bf-494e-b29c-65b732d3d21a', 'Git'),
            ('f1b32785-6fba-4fcf-9d55-7b8e7f157091', 'Programs/Git')):
        guid = ctypes.create_string_buffer(uuid.UUID(identifier).bytes_le)
        result = ctypes.c_void_p()
        status = shell.SHGetKnownFolderPath(guid, 0, None, ctypes.byref(result))
        try:
            if status != 0 or not result.value:
                raise OSError('known-folder-unavailable')
            folder = pathlib.Path(ctypes.wstring_at(result.value))
            if not folder.is_absolute():
                raise OSError('known-folder-unqualified')
            roots.append(folder / suffix)
        finally:
            if result.value:
                ole.CoTaskMemFree(result)
    return roots

def validate_pe_executable(path):
    """Bounded format/executable check, not a vendor authenticity claim."""
    with path.open('rb') as stream:
        size = os.fstat(stream.fileno()).st_size
        header = stream.read(64)
        if len(header) != 64 or header[:2] != b'MZ' or not 64 <= size <= 512 * 1024 * 1024:
            raise OSError('unqualified-executable')
        offset = struct.unpack_from('<I', header, 60)[0]
        if not 64 <= offset <= min(size - 26, 1024 * 1024):
            raise OSError('unqualified-executable')
        stream.seek(offset)
        header = stream.read(26)
        if len(header) != 26 or header[:4] != b'PE\0\0':
            raise OSError('unqualified-executable')
        machine, sections = struct.unpack_from('<HH', header, 4)
        optional_size, flags, magic = struct.unpack_from('<HHH', header, 20)
        if (machine not in (0x14c, 0x8664, 0xaa64) or not 1 <= sections <= 96
                or not flags & 2 or flags & 0x2000 or magic not in (0x10b, 0x20b)
                or optional_size < 2 or offset + 24 + optional_size + 40 * sections > size):
            raise OSError('unqualified-executable')

def tool_command(tool, *args, platform=None):
    if tool not in ('ai-gemini-usage', 'ai-deepseek-agent', 'ai-review-preflight', 'ai-local-watch'):
        raise ValueError('unqualified-tool')
    script = ROOT / 'bin' / tool
    if (platform or os.name) != 'nt':
        return [str(script), *args]
    supplied = os.environ.get('AI_REVIEW_CREDIT_WATCH_BASH', '')
    if not supplied:
        raise OSError('qualified-bash-unavailable')
    supplied_path = pathlib.Path(supplied)
    if not supplied_path.is_absolute():
        raise OSError('unqualified-bash')
    try:
        executable = physical(supplied_path)
    except Blocked:
        raise OSError('unqualified-bash') from None
    roots = windows_git_roots()
    allowed = { root / folder / 'bash.exe' for root in roots for folder in ('bin', 'usr/bin') }
    if executable not in allowed or executable != supplied_path or not executable.is_file():
        raise OSError('unqualified-bash')
    validate_pe_executable(executable)
    return [str(executable), script.as_posix(), *args]

def observed_epoch(value):
    if not isinstance(value, str) or not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z', value):
        raise ValueError('invalid-observation-time')
    checked = datetime.datetime.strptime(value, '%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=datetime.timezone.utc)
    return int(checked.timestamp())

def fresh(value, now):
    try:
        return 0 <= now.timestamp() - observed_epoch(value) <= 120
    except (TypeError, ValueError, OverflowError):
        return False

def normalize(provider, value, now):
    result = {'provider': provider, 'state': 'unknown', 'reason': 'unqualified-response'}
    if not isinstance(value, dict) or value.get('provider') != provider or not fresh(value.get('checked_at'), now):
        return result
    result['observed_epoch'] = observed_epoch(value['checked_at'])
    if provider in ('deepseek', 'glm', 'stepfun'):
        version, source, model = {'deepseek': ('user-balance-v1', 'official-user-balance', 'deepseek-flash'),
                                 'glm': ('zai-model-quota-v1', 'official-zai-model-quota', 'glm-5.3'),
                                 'stepfun': ('stepfun-account-v1', 'official-stepfun-account', 'step-5-preview')}[provider]
        if (value.get('qualified_version') != version
                or value.get('source_kind') != source
                or value.get('model_scope') != model
                or not isinstance(value.get('credential_profile_scope'), str)
                or not re.fullmatch(r'sha256:[0-9a-f]{64}', value['credential_profile_scope'])):
            return result
        if value.get('state') in ('available', 'exhausted'):
            expected_reason = 'reported-capacity' if value['state'] == 'available' else 'reported-exhaustion'
            if value.get('reason') == expected_reason:
                result.update(state=value['state'], reason=expected_reason,
                    credential_profile_scope=value['credential_profile_scope'], model_scope=value['model_scope'], reset_at=value.get('reset_at'))
        return result
    buckets = {}
    resets = {}
    groups = value.get('groups')
    if not isinstance(groups, list):
        return result
    for group in groups:
        if not isinstance(group, dict) or not isinstance(group.get('buckets'), list):
            return result
        for bucket in group['buckets']:
            if isinstance(bucket, dict) and bucket.get('id') in ('gemini-weekly', 'gemini-5h'):
                remaining = bucket.get('remaining_percent')
                if type(remaining) not in (int, float) or not math.isfinite(remaining) or not 0 <= remaining <= 100:
                    return result
                if bucket['id'] in buckets:
                    return result
                buckets[bucket['id']] = remaining
                resets[bucket['id']] = bucket.get('reset_time')
    if set(buckets) != {'gemini-weekly', 'gemini-5h'}:
        return result
    # Any authoritative zero bucket exhausts the account; unknown buckets never
    # become available. Positive data is an observation, not admission readiness.
    exhausted = 0 in buckets.values()
    result.update(state='exhausted' if exhausted else 'available', reason='reported-exhaustion' if exhausted else 'reported-capacity',
                  scope_identity='unknown', provenance='current-authenticated-agy-usage')
    exhausted_resets = [resets[key] for key, amount in buckets.items() if amount == 0]
    try:
        parsed = [datetime.datetime.fromisoformat(v.replace('Z', '+00:00')) for v in exhausted_resets]
        result['reset_at'] = max(parsed).isoformat() if parsed and all(v.tzinfo and v > now for v in parsed) else None
    except (ValueError, TypeError, AttributeError):
        result['reset_at'] = None
    profile = value.get('credential_profile_scope')
    if isinstance(profile, str) and re.fullmatch(r'sha256:[0-9a-f]{64}', profile):
        result.update(credential_profile_scope=profile, model_scope='gemini-3.8-flash')
    return result


def reconcile(provider, observation, run=subprocess.run):
    """Only qualified normalized observations enter the existing admission store."""
    with tempfile.TemporaryDirectory(prefix='reviewer-capacity-') as directory:
        path = pathlib.Path(directory) / 'observation.json'
        path.write_text(json.dumps(observation))
        response = run(tool_command('ai-review-preflight', 'capacity-observe', provider, '--observation-file', str(path)),
                       capture_output=True, text=True, timeout=10, check=False)
        if response.returncode != 0:
            return 'failed'
        try:
            return json.loads(response.stdout)['status']
        except (ValueError, KeyError, TypeError):
            return 'failed'

def read_provider(provider, run=subprocess.run, now=None):
    try:
        command = ([sys.executable, str(ROOT / 'tools/glm_credit.py'), 'check'] if provider == 'glm' else
                   [sys.executable, str(ROOT / 'tools/stepfun_credit.py')] if provider == 'stepfun' else
                   tool_command('ai-gemini-usage' if provider == 'gemini' else 'ai-deepseek-agent',
                                '--json' if provider == 'gemini' else 'balance'))
        response = run(command, capture_output=True, text=True, timeout=75 if provider == 'gemini' else 20 if provider in ('glm', 'stepfun') else 10, check=False)
        if response.returncode != 0 or len(response.stdout) > 65536:
            raise ValueError('unreadable')
        return normalize(provider, json.loads(response.stdout), now or datetime.datetime.now(datetime.timezone.utc))
    except (OSError, subprocess.TimeoutExpired, ValueError, TypeError, KeyError):
        return {'provider': provider, 'state': 'unknown', 'reason': 'read-unavailable'}

def main(args=None, run=subprocess.run):
    args = sys.argv[1:] if args is None else args
    if len(args) == 2 and args[0] == 'refresh' and args[1] in ('gemini', 'deepseek', 'glm', 'stepfun'):
        observation = read_provider(args[1], run=run)
        try:
            status = reconcile(args[1], observation, run)
        except (OSError, subprocess.TimeoutExpired):
            status = 'failed'
        return 1 if status == 'failed' else 0
    if args in (['--help'], ['help']):
        print('ai-review-credit-watch check|tick; scheduled hourly by ai-local-watch tick-all')
        return 0
    if args not in (['check'], ['tick']):
        return 2
    if args == ['tick']:
        try:
            claimed = run(tool_command('ai-local-watch', 'claim'), stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL, timeout=60, check=False)
            if claimed.returncode != 0:
                print('credit-watch: duty claim unavailable; no observations or holds')
                return claimed.returncode
        except (OSError, subprocess.TimeoutExpired):
            print('credit-watch: duty claim unavailable; no observations or holds')
            return 1
    failed = False
    if args == ['tick']:
        # The existing scheduler owns reset-time qualification, including Qwen
        # whose predictive allowance reader remains unsupported.
        for provider in ('gemini', 'qwen'):
            try:
                response = run(tool_command('ai-review-preflight', 'reset-requalify', provider),
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=1900, check=False)
                failed |= response.returncode != 0
            except (OSError, subprocess.TimeoutExpired):
                failed = True
    for provider in ('gemini', 'deepseek', 'glm', 'stepfun'):
        observation = read_provider(provider, run=run)
        hold = 'unchanged'
        if args == ['tick'] and observation['state'] in ('available', 'exhausted'):
            try:
                hold = reconcile(provider, observation, run)
            except (OSError, subprocess.TimeoutExpired):
                hold = 'failed'
            failed |= hold == 'failed'
        # Deliberately discard all numeric balances, allowance, profile hashes,
        # response bodies and stderr. Available never clears an existing hold.
        public = {key: value for key, value in observation.items() if key not in ('observed_epoch','credential_profile_scope','model_scope')}
        print(json.dumps({**public, 'hold': hold}, separators=(',', ':')))
    for provider in UNQUALIFIED:
        print(json.dumps({'provider': provider, 'state': 'unknown', 'reason': 'no-qualified-interface', 'hold': 'unchanged'}, separators=(',', ':')))
    return 1 if failed else 0

if __name__ == '__main__':
    sys.exit(main())
