import contextlib
import copy
import datetime
import importlib.machinery
import importlib.util
import io
import json
import pathlib
import os
import socket
import subprocess
import sys
import types
import tempfile
import unittest
import struct
from unittest import mock
import urllib.error

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
def load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module

balance = load('balance', ROOT / 'tools/deepseek_balance.py')
watch = load('watch', ROOT / 'tools/reviewer_credit_watch.py')
glm = load('glm', ROOT / 'tools/glm_credit.py')
stepfun = load('stepfun', ROOT / 'tools/stepfun_credit.py')
admission = load('credit_admission', ROOT / 'tools/reviewer_admission.py')
NOW = datetime.datetime(2026, 10, 6, 20, tzinfo=datetime.timezone.utc)
STAMP = '2026-10-06T20:00:00Z'

def gemini(a=50, b=50):
    return {'provider': 'gemini', 'checked_at': STAMP, 'groups': [{'buckets': [
        {'id': 'gemini-weekly', 'remaining_percent': a},
        {'id': 'gemini-5h', 'remaining_percent': b}]}]}

class Response(io.BytesIO):
    pass

class CreditTests(unittest.TestCase):
    def step_response(self, payload):
        response = Response(payload if isinstance(payload, bytes) else json.dumps(payload).encode())
        response.status = 200
        response.geturl = lambda: stepfun.ENDPOINT
        return response

    def test_stepfun_fixed_prepaid_endpoint_and_no_private_amounts(self):
        value = dict(object='account', type='prepaid', balance=1.25, total_cash_balance=2, total_voucher_balance=3)
        calls = []
        def read(request, **kwargs):
            calls.append((request, kwargs))
            return self.step_response(value)
        with mock.patch.object(stepfun, 'read_key', return_value='private-key'):
            result = stepfun.check(opener=types.SimpleNamespace(open=read), environment={})
        self.assertEqual(result['state'], 'available')
        self.assertEqual(calls[0][0].full_url, stepfun.ENDPOINT)
        self.assertEqual(calls[0][0].get_method(), 'GET')
        self.assertEqual(calls[0][0].get_header('Authorization'), 'Bearer private-key')
        self.assertEqual(calls[0][1], {'timeout': 15})
        public = watch.normalize('stepfun', result, datetime.datetime.now(datetime.timezone.utc))
        self.assertEqual(public['state'], 'available')
        self.assertNotIn('private-key', json.dumps(public))
        self.assertEqual(public['credential_profile_scope'], result['credential_profile_scope'])
        self.assertNotIn('balance', result)

    def test_stepfun_zero_only_prepaid_exhaustion_and_strict_schema(self):
        good = dict(object='account', type='prepaid', balance=0, total_cash_balance=2, total_voucher_balance=3)
        self.assertEqual(stepfun.classify(good), 'exhausted')
        bad = [dict(good, type='postpaid'), dict(good, object='other'), dict(good, extra=1),
               {k:v for k,v in good.items() if k!='balance'}]
        for field in ('balance', 'total_cash_balance', 'total_voucher_balance'):
            bad += [dict(good, **{field: number}) for number in (True, '0', None, -1, float('nan'), float('inf'))]
        for value in bad:
            with self.assertRaises((ValueError, OverflowError)): stepfun.classify(value)

    def test_stepfun_duplicate_redirect_timeout_auth_and_bounds_unknown(self):
        duplicate = b'{"object":"account","type":"prepaid","balance":0,"balance":10,"total_cash_balance":2,"total_voucher_balance":3}'
        with mock.patch.object(stepfun, 'read_key', return_value='private-key'):
            for body in (duplicate, b'not-json', b' ' * 65537):
                result = stepfun.check(opener=types.SimpleNamespace(open=lambda *a, **k: self.step_response(body)), environment={})
                self.assertEqual(result['state'], 'unknown')
            for error in (socket.timeout(), urllib.error.HTTPError(stepfun.ENDPOINT, 302, '', {}, None), urllib.error.HTTPError(stepfun.ENDPOINT, 401, '', {}, None)):
                def fail(*args, **kwargs): raise error
                self.assertEqual(stepfun.check(opener=types.SimpleNamespace(open=fail), environment={})['state'], 'unknown')
            redirect = self.step_response({})
            redirect.geturl = lambda: 'https://evil.invalid'
            self.assertEqual(stepfun.check(opener=types.SimpleNamespace(open=lambda *a, **k: redirect), environment={})['state'], 'unknown')

    def test_stepfun_bad_profile_or_cache_never_networks(self):
        client = types.SimpleNamespace(open=mock.Mock(side_effect=ValueError('unexpected network')))
        for env in ({'AI_STEPFUN_BASE_URL':'https://evil.invalid'}, {'AI_STEPFUN_MODEL':'other'}, {'AI_STEPFUN_KEY_STORE':'elsewhere'}, {'AI_STEPFUN_OP_REF':'another-reference'}):
            with mock.patch.object(stepfun, 'read_key', side_effect=ValueError('unexpected cache read')) as key_read:
                self.assertEqual(stepfun.check(opener=client, environment=env)['state'], 'unknown')
                key_read.assert_not_called()
        with mock.patch.object(stepfun, 'read_key', side_effect=ValueError('private cache refused')):
            self.assertEqual(stepfun.check(opener=client, environment={})['state'], 'unknown')
        client.open.assert_not_called()
        self.assertIsNone(stepfun.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://evil.invalid'))

    def test_stepfun_explicit_exhaustion_uses_existing_hold_only(self):
        now = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        observation = {'provider':'stepfun','qualified_version':'stepfun-account-v1','source_kind':'official-stepfun-account','model_scope':'step-5-preview','credential_profile_scope':'sha256:'+'a'*64,'checked_at':now,'state':'exhausted','reason':'reported-exhaustion'}
        calls=[]
        def run(command, **kwargs):
            calls.append(command)
            if any(arg.endswith('stepfun_credit.py') for arg in command):
                return subprocess.CompletedProcess(command, 0, json.dumps(observation))
            if any(arg.endswith('ai-local-watch') or arg.endswith('ai-review-preflight') for arg in command):
                return subprocess.CompletedProcess(command, 0, '{"status":"held"}')
            return subprocess.CompletedProcess(command, 1, '')
        with contextlib.redirect_stdout(io.StringIO()) as out: self.assertEqual(watch.main(['tick'], run=run), 0)
        pauses=[c for c in calls if 'capacity-observe' in c]
        self.assertEqual(len(pauses), 1)
        rows = [json.loads(line) for line in out.getvalue().splitlines()]
        self.assertEqual(next(row for row in rows if row['provider'] == 'stepfun')['hold'], 'held')
        self.assertNotIn('applied', [row['hold'] for row in rows])
        self.assertIn('capacity-observe', pauses[0])
        self.assertNotIn('credential_profile_scope', out.getvalue())
        calls.clear(); observation.update(state='available',reason='reported-capacity')
        with contextlib.redirect_stdout(io.StringIO()): watch.main(['tick'],run=run)
        self.assertFalse(any('pause' in c or 'unpause' in c for c in calls))

    def test_shared_windows_path_conversion_is_bounded_absolute_and_fail_closed(self):
        import reviewer_maintenance as paths
        with tempfile.TemporaryDirectory(prefix='credit config spaced ') as directory:
            target = pathlib.Path(directory)
            windows = types.SimpleNamespace(name='nt', path=os.path)
            with mock.patch.object(paths, 'os', windows), mock.patch.object(paths.subprocess, 'run') as run:
                run.return_value = subprocess.CompletedProcess([], 0, str(target), '')
                self.assertEqual(paths.physical('/C/user/config space', conversion_timeout=2), target.resolve())
                self.assertEqual(run.call_args.args[0], ['cygpath', '-w', '/C/user/config space'])
                self.assertEqual(run.call_args.kwargs['timeout'], 2)
                for result in (subprocess.CompletedProcess([], 1, str(target), ''),
                               subprocess.CompletedProcess([], 0, 'relative/path', ''),
                               subprocess.CompletedProcess([], 0, '', '')):
                    run.return_value = result
                    with self.assertRaises(paths.Blocked): paths.physical('/C/user', conversion_timeout=2)
                run.side_effect = subprocess.TimeoutExpired('cygpath', 2)
                with self.assertRaises(subprocess.TimeoutExpired): paths.physical('/C/user', conversion_timeout=2)
        for error in (subprocess.TimeoutExpired('cygpath', 2), paths.Blocked('conversion-refused')):
            with mock.patch.dict(os.environ, {'AI_DEVOPS_CONFIG_DIR': '/C/user/config space'}), \
                    mock.patch.object(glm, 'physical', side_effect=error):
                output = io.StringIO()
                with contextlib.redirect_stdout(output): self.assertEqual(glm.main(['check']), 0)
                self.assertEqual(json.loads(output.getvalue())['state'], 'unknown')
                self.assertEqual(glm.main(['publish']), 1)

    def setUp(self):
        self.git_directory = tempfile.TemporaryDirectory(prefix='Git Bash spaced ')
        self.addCleanup(self.git_directory.cleanup)
        self.git_root = pathlib.Path(self.git_directory.name)
        self.bash_executable = self.git_root / 'Git/bin/bash.exe'
        self.bash_executable.parent.mkdir(parents=True)
        self.pe = bytearray(512)
        self.pe[:2] = b'MZ'
        struct.pack_into('<I', self.pe, 60, 64)
        self.pe[64:68] = b'PE\0\0'
        struct.pack_into('<HH', self.pe, 68, 0x8664, 1)
        struct.pack_into('<HHH', self.pe, 84, 240, 2, 0x20b)
        self.bash_executable.write_bytes(self.pe)
        folders = mock.patch.object(watch, 'windows_git_roots', return_value=[self.git_root / 'Git'])
        folders.start()
        self.addCleanup(folders.stop)
        environment = mock.patch.dict(os.environ, {'ProgramFiles': str(self.git_root),
                                     'AI_REVIEW_CREDIT_WATCH_BASH': str(self.bash_executable)})
        environment.start()
        self.addCleanup(environment.stop)

    def test_native_windows_fixed_argv_spaced_paths_and_forgery_refusal(self):
        command = watch.tool_command('ai-review-preflight', 'pause', 'glm',
                                     'out-of-credit', '--seconds', '3600', platform='nt')
        self.assertEqual(command, [str(self.bash_executable), (ROOT / 'bin/ai-review-preflight').as_posix(),
                                  'pause', 'glm', 'out-of-credit', '--seconds', '3600'])
        self.assertIn('Git Bash spaced ', command[0])
        with mock.patch.object(watch, 'ROOT', self.git_root / 'toolkit with spaces'):
            spaced = watch.tool_command('ai-local-watch', 'claim', platform='nt')
            self.assertEqual(spaced[1], (self.git_root / 'toolkit with spaces/bin/ai-local-watch').as_posix())
            self.assertEqual(len(spaced), 3)
        for supplied in ('', 'bash.exe', str(self.git_root / 'missing.exe'),
                         str(self.git_root / 'forged.exe')):
            with mock.patch.dict(os.environ, {'AI_REVIEW_CREDIT_WATCH_BASH': supplied}):
                with self.assertRaises(OSError): watch.tool_command('ai-local-watch', 'claim', platform='nt')
        forged = self.git_root / 'forged.exe'; forged.write_bytes(b'not-git-bash')
        with mock.patch.dict(os.environ, {'AI_REVIEW_CREDIT_WATCH_BASH': str(forged)}):
            with self.assertRaises(OSError): watch.tool_command('ai-local-watch', 'claim', platform='nt')
        if os.name != 'nt':
            self.bash_executable.unlink()
            self.bash_executable.symlink_to(forged)
            with self.assertRaises(OSError): watch.tool_command('ai-local-watch', 'claim', platform='nt')
        with self.assertRaises(ValueError): watch.tool_command('arbitrary;command', platform='nt')
        self.assertEqual(watch.tool_command('ai-local-watch', 'claim', platform='posix'),
                         [str(ROOT / 'bin/ai-local-watch'), 'claim'])

    def test_windows_environment_never_supplies_installation_authority(self):
        with mock.patch.object(watch, 'windows_git_roots', return_value=[self.git_root / 'real/Git']):
            with self.assertRaises(OSError): watch.tool_command('ai-local-watch', platform='nt')
        with mock.patch.object(watch, 'windows_git_roots', side_effect=OSError('missing-discovery')):
            with self.assertRaises(OSError): watch.tool_command('ai-local-watch', platform='nt')

    def test_windows_known_folder_api_uses_os_results_and_frees_failed_allocations(self):
        import ctypes
        # setUp's discovery substitute is removed only for this real API boundary test.
        source = load('watch_folder_api', ROOT / 'tools/reviewer_credit_watch.py')
        allocations, identifiers, freed = [], [], []
        status = [0]
        def query(guid, flags, token, output):
            identifiers.append(bytes(guid)[:16])
            value = ctypes.create_unicode_buffer(str(self.git_root / ('System' if len(identifiers) % 2 else 'User')))
            allocations.append(value)
            ctypes.cast(output, ctypes.POINTER(ctypes.c_void_p))[0] = ctypes.addressof(value)
            return status[0]
        def release(value): freed.append(value.value)
        shell = types.SimpleNamespace(SHGetKnownFolderPath=query)
        ole = types.SimpleNamespace(CoTaskMemFree=release)
        with mock.patch.object(ctypes, 'WinDLL', side_effect=lambda name, **kw: shell if name == 'shell32' else ole, create=True), \
                mock.patch.dict(os.environ, {'ProgramFiles': '/forged', 'LOCALAPPDATA': '/forged'}):
            self.assertEqual(source.windows_git_roots(), [self.git_root / 'System/Git', self.git_root / 'User/Programs/Git'])
            self.assertEqual(identifiers, [source.uuid.UUID(identifier).bytes_le for identifier in
                ('905e63b6-c1bf-494e-b29c-65b732d3d21a', 'f1b32785-6fba-4fcf-9d55-7b8e7f157091')])
            self.assertEqual(len(freed), 2)
            status[0] = -1
            with self.assertRaises(OSError): source.windows_git_roots()
            self.assertEqual(len(freed), 3)

    def test_windows_supported_system_and_per_user_layouts(self):
        for root in (self.git_root / 'System/Git', self.git_root / 'User/Programs/Git'):
            for layout in ('bin', 'usr/bin'):
                executable = root / layout / 'bash.exe'
                executable.parent.mkdir(parents=True, exist_ok=True)
                executable.write_bytes(self.pe)
                with mock.patch.object(watch, 'windows_git_roots', return_value=[root]), \
                        mock.patch.dict(os.environ, {'AI_REVIEW_CREDIT_WATCH_BASH': str(executable)}):
                    self.assertEqual(watch.tool_command('ai-local-watch', platform='nt')[0], str(executable))

    def test_windows_plaintext_truncated_nonexecutable_and_linked_parents_refuse(self):
        for content in (b'fake bash', self.pe[:90], bytes(512)):
            self.bash_executable.write_bytes(content)
            with self.assertRaises(OSError): watch.tool_command('ai-local-watch', platform='nt')
        for flags in (0, 0x2002):
            content = bytearray(self.pe)
            struct.pack_into('<H', content, 86, flags)
            self.bash_executable.write_bytes(content)
            with self.assertRaises(OSError): watch.tool_command('ai-local-watch', platform='nt')
        self.bash_executable.write_bytes(self.pe)
        with mock.patch.object(watch, 'physical', side_effect=watch.Blocked('reparse parent')):
            with self.assertRaises(OSError): watch.tool_command('ai-local-watch', platform='nt')
    def test_glm_official_auth_periods_and_private_result(self):
        payload = {'code': 200, 'success': True, 'data': {'limits': [
            {'type': 'CREDIT_LIMIT', 'unit': 3, 'number': 5, 'remaining': 5, 'percentage': 50},
            {'type': 'TOKENS_LIMIT', 'unit': 6, 'number': 1, 'remaining': 0, 'percentage': 100}]}}
        def read(request, timeout):
            self.assertEqual((request.full_url, request.method, timeout), (glm.ENDPOINT, 'GET', 15))
            self.assertEqual(request.get_header('Authorization'), 'private-key')
            return Response(json.dumps(payload).encode())
        result = glm.observation('private-key', opener=read, now=NOW)
        self.assertEqual(result['state'], 'exhausted')
        self.assertEqual(watch.normalize('glm', result, NOW)['state'], 'exhausted')
        self.assertNotIn('remaining', result)
        self.assertNotIn('private-key', json.dumps(result))
        payload['data']['limits'][1].update(remaining=1, percentage=50)
        self.assertEqual(glm.observation('private-key', opener=read, now=NOW)['state'], 'available')

    def test_glm_nondefault_model_never_reads_cache_or_network(self):
        with mock.patch.dict(os.environ, {'AI_GLM_MODEL':'other'}), mock.patch.object(glm, 'physical') as path, mock.patch.object(glm, 'cached_key') as cache, mock.patch.object(glm, 'observation') as network, mock.patch.object(glm.sys.stdin, 'read') as secret:
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(glm.main(['check']), 0)
            self.assertEqual(json.loads(output.getvalue())['state'], 'unknown')
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(glm.main(['publish']), 1)
            self.assertEqual(output.getvalue(), '')
            path.assert_not_called(); cache.assert_not_called(); network.assert_not_called(); secret.assert_not_called()

    def test_glm_qualified_default_model_keeps_existing_read_path(self):
        with mock.patch.dict(os.environ, {'AI_GLM_MODEL':glm.MODEL}), mock.patch.object(glm, 'physical', return_value=pathlib.Path('/qualified/private')) as path, mock.patch.object(glm, 'cached_key', return_value='fake-test-key') as cache, mock.patch.object(glm, 'observation', return_value={'provider':'glm','state':'available'}) as network:
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(glm.main(['check']), 0)
            self.assertEqual(json.loads(output.getvalue())['state'], 'available')
            path.assert_called_once(); cache.assert_called_once_with(pathlib.Path('/qualified/private')); network.assert_called_once_with('fake-test-key')

    def test_glm_period_schema_refuses_missing_duplicate_conflicting_and_bool(self):
        good = [{'type': 'CREDIT_LIMIT', 'unit': 3, 'number': 5, 'remaining': 3, 'percentage': 20},
                {'type': 'CREDIT_LIMIT', 'unit': 6, 'number': 1, 'remaining': 2, 'percentage': 40}]
        bad_limits = [good[:1], good + good[:1], [dict(good[0], remaining=True), good[1]],
                      [dict(good[0], remaining=0), good[1]],
                      [dict(good[0], unit=True), good[1]],
                      [dict(good[0], number=1), good[1]],
                      [dict(good[0], percentage=float('nan')), good[1]],
                      [{'type': 'TIME_LIMIT', 'unit': 5, 'number': 1, 'remaining': 0, 'percentage': 100}]]
        for limits in bad_limits:
            data = {'code': 200, 'success': True, 'data': {'limits': limits}}
            result = glm.observation('key', opener=lambda *a, **k: Response(json.dumps(data).encode()), now=NOW)
            self.assertEqual(result['state'], 'unknown')
        for data in ({}, {'code': True}, {'code': 200, 'success': False}, {'code': 200, 'data': None}):
            self.assertEqual(glm.observation('key', opener=lambda *a, **k: Response(json.dumps(data).encode()))['state'], 'unknown')

    def test_glm_timeout_redirect_auth_and_invalid_key_no_calls(self):
        for error in (socket.timeout(), urllib.error.HTTPError(glm.ENDPOINT, 302, '', {}, None),
                      urllib.error.HTTPError(glm.ENDPOINT, 401, '', {}, None)):
            def fail(*a, **k): raise error
            self.assertEqual(glm.observation('key', opener=fail)['state'], 'unknown')
        self.assertIsNone(glm.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://evil.invalid'))
        for key in ('', 'x\ny', None):
            self.assertEqual(glm.observation(key, opener=lambda *a, **k: self.fail('network called'))['state'], 'unknown')

    def test_windows_acl_publication_uses_existing_helper_and_secret_stdin(self):
        target = ROOT / 'private-test-cache.json'
        with mock.patch.object(glm.shutil, 'which', return_value='powershell.exe'), \
                mock.patch.object(glm.subprocess, 'run', return_value=mock.Mock(returncode=0)) as run:
            glm.windows_private(target, 'publish', payload='private-test-secret')
            arguments, options = run.call_args
            self.assertIn('Set-AiDevOpsPrivateFileAtomic', arguments[0][-1])
            self.assertIn('[Console]::In.ReadToEnd()', arguments[0][-1])
            self.assertNotIn('private-test-secret', str(arguments))
            self.assertEqual(options['input'], 'private-test-secret')
            self.assertEqual(options['timeout'], 15)
            self.assertEqual(options['env']['AI_DEVOPS_PRIVATE_TARGET'], str(target))
            glm.windows_private(target.parent, 'protect', directory=True)
            self.assertIn('Protect-AiDevOpsPrivatePath', run.call_args.args[0][-1])
            self.assertIn('-Directory', run.call_args.args[0][-1])
            glm.windows_private(target, 'assert')
            self.assertIn('Assert-AiDevOpsPrivateAcl', run.call_args.args[0][-1])
            run.return_value.returncode = 1
            with self.assertRaises(ValueError): glm.windows_private(target, 'assert')
        with mock.patch.object(glm.shutil, 'which', return_value=None):
            with self.assertRaises(ValueError): glm.windows_private(target, 'assert')

    @unittest.skipIf(os.name == 'nt', 'Unix permission assertions; Windows uses the existing ACL helper')
    def test_glm_atomic_cache_permissions_binding_and_link_refusal(self):
        with tempfile.TemporaryDirectory() as directory:
            config = pathlib.Path(directory)
            (config / 'mcp.env').write_text('ZAI_API_KEY=op://vibe_coding/glm/key\n')
            glm.publish(config, 'private-key')
            self.assertEqual(glm.cached_key(config), 'private-key')
            cache = config / 'secrets/zai-coding-plan-key.json'
            self.assertEqual(cache.stat().st_mode & 0o777, 0o600)
            self.assertEqual(cache.parent.stat().st_mode & 0o777, 0o700)
            (config / 'mcp.env').write_text('ZAI_API_KEY=op://vibe_coding/changed/key\n')
            with self.assertRaises(ValueError): glm.cached_key(config)
            glm.publish(config, 'replacement')
            self.assertEqual(glm.cached_key(config), 'replacement')
            cache.chmod(0o644)
            with self.assertRaises(ValueError): glm.cached_key(config)
            cache.chmod(0o600)
            value = json.loads(cache.read_text()); value['model'] = 'other'; cache.write_text(json.dumps(value))
            with self.assertRaises(ValueError): glm.cached_key(config)
            cache.unlink(); cache.symlink_to(config / 'mcp.env')
            with self.assertRaises(glm.Blocked): glm.publish(config, 'key')
            self.assertFalse(list(cache.parent.glob('.zai-key-*')))

    def test_fixed_endpoint_bounded_request_and_secret_free_result(self):
        calls = []
        def open_(request, timeout):
            calls.append((request.full_url, request.method, timeout))
            self.assertEqual(request.get_header('Authorization'), 'Bearer private-key')
            return Response(b'{"is_available":false,"balance_infos":[{"total_balance":"secret-balance"}]}')
        result = balance.observation('private-key', opener=open_, now=NOW)
        self.assertEqual(calls, [(balance.ENDPOINT, 'GET', 5)])
        self.assertEqual(result['state'], 'exhausted')
        self.assertNotIn('private-key', json.dumps(result))
        self.assertNotIn('secret-balance', json.dumps(result))
        self.assertEqual(watch.normalize('deepseek', result, NOW)['state'], 'exhausted')

    def test_bad_schema_never_exhausts(self):
        for payload in (b'{}', b'{"is_available":0,"balance_infos":[]}', b'not json',
                        b'{"is_available":false}', b'x' * 65537):
            with self.subTest(payload=payload[:30]):
                self.assertEqual(balance.observation('key', opener=lambda *a, **k: Response(payload))['state'], 'unknown')

    def test_transport_auth_timeout_and_redirect_fail_closed(self):
        for error, reason in ((urllib.error.HTTPError(balance.ENDPOINT, 401, '', {}, None), 'authentication-error'),
                              (urllib.error.HTTPError(balance.ENDPOINT, 302, '', {}, None), 'transport-error'),
                              (urllib.error.URLError(socket.timeout()), 'timeout')):
            def fail(*args, **kwargs): raise error
            self.assertEqual(balance.observation('key', opener=fail)['reason'], reason)
        self.assertIsNone(balance.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://evil.invalid'))

    def test_invalid_key_never_requests(self):
        for key in ('', 'x\ny', 'x\x00y', 'é'):
            self.assertEqual(balance.observation(key, opener=lambda *a, **k: self.fail('network called'))['state'], 'unknown')

    def test_gemini_all_buckets_required_and_strict_numeric(self):
        self.assertEqual(watch.normalize('gemini', gemini(0), NOW)['state'], 'exhausted')
        self.assertEqual(watch.normalize('gemini', gemini(), NOW)['state'], 'available')
        for invalid in (None, True, '0', -1, 101, float('nan')):
            self.assertEqual(watch.normalize('gemini', gemini(invalid), NOW)['state'], 'unknown')
        missing = gemini(); missing['groups'][0]['buckets'].pop()
        self.assertEqual(watch.normalize('gemini', missing, NOW)['state'], 'unknown')

    def test_stale_future_wrong_provider_and_model_refuse(self):
        for stamp in ('2026-10-06T19:55:00Z', '2026-10-06T20:01:00Z', None):
            value = gemini(); value['checked_at'] = stamp
            self.assertEqual(watch.normalize('gemini', value, NOW)['state'], 'unknown')
        value = gemini(); value['provider'] = 'grok'
        self.assertEqual(watch.normalize('gemini', value, NOW)['state'], 'unknown')
        result = balance.observation('key', opener=lambda *a, **k: Response(b'{"is_available":false,"balance_infos":[]}'), now=NOW)
        result['model_scope'] = 'other'
        self.assertEqual(watch.normalize('deepseek', result, NOW)['state'], 'unknown')

    def test_deepseek_scope_and_reason_strict(self):
        result = balance.observation('key', opener=lambda *a, **k: Response(b'{"is_available":false,"balance_infos":[]}'), now=NOW)
        for bad in ('sha256:' + 'z' * 64, 'sha256:' + 'a' * 63, None, True):
            value = dict(result, credential_profile_scope=bad)
            self.assertEqual(watch.normalize('deepseek', value, NOW)['state'], 'unknown')
        for bad in (None, '', 'private provider body', True):
            value = dict(result, reason=bad)
            self.assertEqual(watch.normalize('deepseek', value, NOW)['state'], 'unknown')

    def test_tick_only_exhaustion_pauses_and_never_unpauses(self):
        calls = []
        current = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        def run(command, **kwargs):
            calls.append(command)
            value = gemini(0); value['checked_at'] = current
            if any(arg.endswith('ai-gemini-usage') for arg in command):
                return subprocess.CompletedProcess(command, 0, json.dumps(value), 'private stderr')
            if any(arg.endswith('ai-deepseek-agent') for arg in command):
                return subprocess.CompletedProcess(command, 1, '', 'private stderr')
            return subprocess.CompletedProcess(command, 0, '{"status":"unchanged"}')
        out = io.StringIO()
        with contextlib.redirect_stdout(out): self.assertEqual(watch.main(['tick'], run=run), 0)
        pauses = [c for c in calls if any(arg.endswith('ai-review-preflight') for arg in c)]
        self.assertIn('capacity-observe', pauses[0])
        self.assertEqual(len(pauses), 1)
        self.assertNotIn('private', out.getvalue())
        self.assertNotIn('remaining_percent', out.getvalue())
        self.assertEqual(len(out.getvalue().splitlines()), 7)
        calls.clear()
        with contextlib.redirect_stdout(io.StringIO()): watch.main(['check'], run=run)
        self.assertFalse(any('pause' in c for c in calls))

    def test_original_observation_window_is_not_freshened(self):
        original = int(datetime.datetime.now(datetime.timezone.utc).timestamp()) - 60
        observation = {'provider': 'gemini', 'state': 'exhausted', 'reason': 'reported-exhaustion', 'observed_epoch': original}
        calls = []
        def run(command, **kwargs):
            calls.append(command)
            return subprocess.CompletedProcess(command, 0)
        def reconcile(provider, value, run):
            calls.append(dict(value))
            return 'unchanged'
        with mock.patch.object(watch, 'reconcile', side_effect=reconcile), mock.patch.object(watch, 'read_provider', side_effect=lambda provider, **kwargs: dict(observation, provider=provider)):
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(watch.main(['tick'], run=run), 0)
                self.assertEqual(watch.main(['tick'], run=run), 0)
        pauses = [command for command in calls if isinstance(command, dict)]
        self.assertEqual(len(pauses), 8)
        self.assertTrue(all(command['observed_epoch'] == original for command in pauses))
        self.assertNotIn('observed_epoch', output.getvalue())

    def test_all_providers_refuse_invalid_observation_times(self):
        for provider in ('gemini', 'deepseek', 'glm', 'stepfun'):
            for stamp in (None, True, '2026-1-01T00:00:00Z', '2026-13-01T00:00:00Z',
                          (NOW + datetime.timedelta(seconds=1)).strftime('%Y-%m-%dT%H:%M:%SZ'),
                          (NOW - datetime.timedelta(seconds=121)).strftime('%Y-%m-%dT%H:%M:%SZ')):
                with self.subTest(provider=provider, stamp=stamp):
                    value = {'provider': provider, 'checked_at': stamp, 'state': 'exhausted'}
                    result = watch.normalize(provider, value, NOW)
                    self.assertEqual(result['state'], 'unknown')
                    self.assertNotIn('observed_epoch', result)

    def test_merged_pause_api_preserves_stronger_hold_and_original_window(self):
        now = int(datetime.datetime.now(datetime.timezone.utc).timestamp())
        original = now - 60
        state = {'global': {'version': 1, 'provider': 'gemini',
                           'failure_class': 'credential-error', 'created_epoch': now - 10,
                           'expires_epoch': now + 86400, 'record_id': 'existing-fixture-record'}}
        before = copy.deepcopy(state)
        calls = []
        def run(command, **kwargs):
            return subprocess.CompletedProcess(command, 0)
        def reconcile(provider, value, run):
            calls.append(value)
            result = admission.capacity_observation(state, provider, value, now)
            self.assertIn(result['status'], ('held', 'unchanged'))
            return result['status']
        def observation(provider, **kwargs):
            return {'provider': provider, 'state': 'exhausted' if provider == 'gemini' else 'unknown',
                    'reason': 'isolated-fixture', 'observed_epoch': original}
        with mock.patch.object(watch, 'reconcile', side_effect=reconcile), mock.patch.object(watch, 'read_provider', side_effect=observation):
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(watch.main(['tick'], run=run), 0)
                self.assertEqual(watch.main(['tick'], run=run), 0)
        self.assertEqual(state['global'], before['global'])
        self.assertEqual(len(calls), 2)
        self.assertTrue(all(command['observed_epoch'] == original for command in calls))
        public = [json.loads(line) for line in output.getvalue().splitlines()]
        self.assertTrue(all(row['hold'] in ('held', 'unchanged') for row in public if row['provider'] == 'gemini'))
        self.assertTrue(all(row['hold'] == 'unchanged' for row in public if row['provider'] != 'gemini'))
        self.assertNotIn('existing-fixture-record', output.getvalue())

    def test_claim_refusal_stops_before_provider_reads(self):
        calls = []
        def run(command, **kwargs):
            calls.append(command); return subprocess.CompletedProcess(command, 3)
        with contextlib.redirect_stdout(io.StringIO()): self.assertEqual(watch.main(['tick'], run=run), 3)
        self.assertEqual(len(calls), 1)

    def test_one_existing_scheduler_hourly(self):
        config = json.loads((ROOT / 'config/local-watch.json').read_text())
        self.assertEqual(config['tools']['review-credit-watch'], {'tick_minutes': 60, 'command': 'ai-review-credit-watch'})
        self.assertNotIn('register_timer', (ROOT / 'tools/reviewer_credit_watch.py').read_text())

if __name__ == '__main__': unittest.main()
