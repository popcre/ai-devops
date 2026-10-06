import contextlib
import datetime
import importlib.machinery
import importlib.util
import io
import json
import pathlib
import socket
import subprocess
import unittest
import urllib.error

ROOT = pathlib.Path(__file__).resolve().parents[1]
def load(name, path):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    module = importlib.util.module_from_spec(spec)
    loader.exec_module(module)
    return module

balance = load('balance', ROOT / 'tools/deepseek_balance.py')
watch = load('watch', ROOT / 'bin/ai-review-credit-watch')
NOW = datetime.datetime(2026, 10, 6, 20, tzinfo=datetime.timezone.utc)
STAMP = '2026-10-06T20:00:00Z'

def gemini(a=50, b=50):
    return {'provider': 'gemini', 'checked_at': STAMP, 'groups': [{'buckets': [
        {'id': 'gemini-weekly', 'remaining_percent': a},
        {'id': 'gemini-5h', 'remaining_percent': b}]}]}

class Response(io.BytesIO):
    pass

class CreditTests(unittest.TestCase):
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

    def test_tick_only_exhaustion_pauses_and_never_unpauses(self):
        calls = []
        current = datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        def run(command, **kwargs):
            calls.append(command)
            value = gemini(0); value['checked_at'] = current
            if command[0].endswith('ai-gemini-usage'):
                return subprocess.CompletedProcess(command, 0, json.dumps(value), 'private stderr')
            if command[0].endswith('ai-deepseek-agent'):
                return subprocess.CompletedProcess(command, 1, '', 'private stderr')
            return subprocess.CompletedProcess(command, 0)
        out = io.StringIO()
        with contextlib.redirect_stdout(out): self.assertEqual(watch.main(['tick'], run=run), 0)
        pauses = [c for c in calls if c[0].endswith('ai-review-preflight')]
        self.assertEqual(pauses[0][1:], ['pause', 'gemini', 'out-of-credit', '--seconds', '3600'])
        self.assertEqual(len(pauses), 1)
        self.assertNotIn('private', out.getvalue())
        self.assertNotIn('remaining_percent', out.getvalue())
        self.assertEqual(len(out.getvalue().splitlines()), 7)
        calls.clear()
        with contextlib.redirect_stdout(io.StringIO()): watch.main(['check'], run=run)
        self.assertFalse(any('pause' in c for c in calls))

    def test_claim_refusal_stops_before_provider_reads(self):
        calls = []
        def run(command, **kwargs):
            calls.append(command); return subprocess.CompletedProcess(command, 3)
        with contextlib.redirect_stdout(io.StringIO()): self.assertEqual(watch.main(['tick'], run=run), 3)
        self.assertEqual(len(calls), 1)

    def test_one_existing_scheduler_hourly(self):
        config = json.loads((ROOT / 'config/local-watch.json').read_text())
        self.assertEqual(config['tools']['review-credit-watch'], {'tick_minutes': 60, 'command': 'ai-review-credit-watch'})
        self.assertNotIn('register_timer', (ROOT / 'bin/ai-review-credit-watch').read_text())

if __name__ == '__main__': unittest.main()
