"""Behavioral coverage for scoped refusal backoff; no provider calls."""
import importlib.util
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest

MODULE = pathlib.Path(__file__).resolve().parents[1] / 'tools/reviewer_admission.py'
spec = importlib.util.spec_from_file_location('admission', MODULE)
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)


class AdmissionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.directory = pathlib.Path(self.tmp.name)
        self.evidence = self.directory / 'terminal.json'
        self.evidence.write_text('{"terminal":"usage-limit"}')

    def observe(self, **kwargs):
        args = dict(directory=self.directory, provider='kimi', profile='profile-a',
                    model='model-a', run_id='run-a', observed=1000, now=1000,
                    seconds=30, evidence=self.evidence, reason='usage-limit')
        args.update(kwargs)
        return api.observe(**args)

    def test_scope_and_expiry_never_claim_quota(self):
        result = self.observe()
        self.assertEqual((result['state'], result['quota_state'], result['reset_at']),
                         ('backoff', 'unknown', None))
        data = api.load(self.directory, 'kimi')
        for profile, model, now in [('other', 'model-a', 1001),
                                    ('profile-a', 'other', 1001),
                                    ('profile-a', 'model-a', 1030)]:
            self.assertEqual(api.admission(data, profile, model, now)['state'], 'eligible')
        self.assertEqual(api.admission(data, '', 'model-a', 1001)['state'], 'unknown')

    def test_home_aliases_share_profile_without_reading_credentials(self):
        home = self.directory / 'ActualCase'
        home.mkdir()
        original = api.home_profile(str(home))
        self.assertEqual(original, api.home_profile(str(home / '..' / 'ActualCase')))
        if os.name == 'nt':
            self.assertEqual(original, api.home_profile(str(home).swapcase()))
        self.assertNotEqual(original, api.home_profile(str(self.directory / 'different')))
        with self.assertRaises(ValueError):
            api.home_profile('')

    def test_replay_cannot_extend_policy(self):
        self.observe()
        replay = self.observe(now=1010, seconds=100)
        self.assertEqual(replay['policy_expires_epoch'], 1030)
        self.evidence.write_text('changed')
        with self.assertRaises(ValueError):
            self.observe(now=1010)

    def test_local_failure_and_stale_observation_do_not_publish(self):
        for kwargs in [dict(reason='provider-busy'), dict(reason='authentication-failed'),
                       dict(observed=800), dict(observed=1001), dict(profile=''),
                       dict(seconds=True)]:
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                self.observe(**kwargs)
        self.assertFalse((self.directory / 'kimi.json').exists())

    def test_refusal_run_cannot_be_reassigned_to_another_scope(self):
        self.observe()
        for kwargs in [dict(profile='profile-b'), dict(model='model-b')]:
            with self.subTest(kwargs=kwargs), self.assertRaises(ValueError):
                self.observe(**kwargs)
        self.assertEqual(len(api.load(self.directory, 'kimi')['backoffs']), 1)

    def test_legacy_quarantine_survives_scoped_publication(self):
        legacy = dict(version=1, provider='kimi', created_epoch=900,
                      expires_epoch=2000, failure_class='authentication-failed')
        (self.directory / 'kimi.json').write_text(json.dumps(legacy))
        self.observe()
        self.assertEqual(api.load(self.directory, 'kimi')['global'], legacy)

    def test_invalid_record_fails_closed(self):
        self.observe()
        data = api.load(self.directory, 'kimi')
        data['backoffs'][api.scope_key('profile-a', 'model-a')] = 'corrupt'
        (self.directory / 'kimi.json').write_text(json.dumps(data))
        with self.assertRaises(ValueError):
            api.load(self.directory, 'kimi')

    def test_concurrent_scopes_preserved(self):
        command = [sys.executable, str(MODULE), 'observe', 'kimi', '--directory',
                   str(self.directory), '--model', 'model-a', '--reason', 'usage-limit',
                   '--evidence', str(self.evidence), '--observed', str(int(api.time.time()))]
        processes = [subprocess.Popen(command + ['--profile', str(i), '--run-id', str(i)],
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                     for i in range(8)]
        for process in processes:
            output, error = process.communicate(timeout=15)
            self.assertEqual(process.returncode, 0, error.decode())
        self.assertEqual(len(api.load(self.directory, 'kimi')['backoffs']), 8)

    def test_killed_owner_releases_lock(self):
        script = ("import importlib.util,pathlib,time; "
                  "s=importlib.util.spec_from_file_location('a',__import__('sys').argv[1]); "
                  "a=importlib.util.module_from_spec(s); s.loader.exec_module(a); "
                  "c=a.locked(pathlib.Path(__import__('sys').argv[2]),'kimi'); "
                  "c.__enter__(); print('locked',flush=True); time.sleep(60)")
        process = subprocess.Popen([sys.executable, '-c', script, str(MODULE), str(self.directory)],
                                   stdout=subprocess.PIPE, text=True)
        try:
            self.assertEqual(process.stdout.readline().strip(), 'locked')
        finally:
            process.kill(); process.wait(timeout=5); process.stdout.close()
        self.assertEqual(self.observe()['state'], 'backoff')


class ClassifyEventTests(unittest.TestCase):
    """#1115: outage-side events never enter the code-defect stream."""

    def test_credit_and_usage_limit_are_outage_not_code_defect(self):
        cases = [
            ('Your team has used all available credits or reached its monthly spending limit', 'credit'),
            ('402 Payment Required: insufficient_quota - Your account has insufficient credits', 'credit'),
            ('Insufficient Balance', 'credit'),
            ('{"terminal":"usage-limit"}', 'usage-limit'),
            ('You exceeded your current usage limit', 'usage-limit'),
        ]
        for text, expected_class in cases:
            with self.subTest(text=text):
                stream, failure_class = api.classify_event(text, 'grok')
                self.assertEqual(stream, api.STREAM_OUTAGE)
                self.assertEqual(failure_class, expected_class)
                self.assertNotEqual(stream, api.STREAM_CODE)

    def test_quota_and_capacity_are_outage_not_code_defect(self):
        cases = [
            'API error (status 429 Too Many Requests): Rate limit reached for requests per minute.',
            '{"error":{"code":429,"message":"Resource has been exhausted (e.g. check quota).","status":"RESOURCE_EXHAUSTED"}}',
            'Throttling.RateQuota: Requests rate limit exceeded, please try again later.',
            'You exceeded your current quota, please check your plan and billing details',
            'allowance exhausted for this model',
        ]
        for text in cases:
            with self.subTest(text=text):
                stream, failure_class = api.classify_event(text, 'grok')
                self.assertEqual((stream, failure_class), (api.STREAM_OUTAGE, 'capacity'))
                self.assertNotEqual(stream, api.STREAM_CODE)

    def test_bare_404_and_403_stay_code_config(self):
        for text in ('HTTP 404 Not Found: model_not_found',
                     'Error: 404 page not found',
                     '403 Forbidden',
                     'Request failed with status code 403'):
            with self.subTest(text=text):
                stream, failure_class = api.classify_event(text, 'muse')
                self.assertEqual((stream, failure_class), (api.STREAM_CODE, 'code-config'))

    def test_provider_down_is_outage(self):
        for text in ('connection refused', 'Service Unavailable', 'HTTP 503',
                     'Bad Gateway', 'ECONNRESET', 'upstream is unreachable'):
            with self.subTest(text=text):
                stream, failure_class = api.classify_event(text, 'grok')
                self.assertEqual((stream, failure_class), (api.STREAM_OUTAGE, 'outage'))

    def test_credit_beats_capacity_when_both_appear(self):
        stream, failure_class = api.classify_event(
            '403 rate limit: insufficient_quota out of credits', 'grok')
        self.assertEqual((stream, failure_class), (api.STREAM_OUTAGE, 'credit'))

    def test_classify_cli_scans_files_and_text(self):
        tmp = pathlib.Path(tempfile.mkdtemp())
        self.addCleanup(lambda: __import__('shutil').rmtree(tmp, ignore_errors=True))
        evidence = tmp / 'err.txt'
        evidence.write_text('connection refused while contacting the model endpoint')
        command = [sys.executable, str(MODULE), 'classify', 'grok',
                   '--scan', str(evidence), '--text', 'reviewer failed']
        output = subprocess.check_output(command, text=True)
        result = json.loads(output)
        self.assertEqual(result, {'stream': 'provider-outage', 'failure_class': 'outage'})

    def test_qwen_insufficient_quota_is_capacity_not_credit(self):
        stream, failure_class = api.classify_event('insufficient_quota', 'qwen')
        self.assertEqual((stream, failure_class), (api.STREAM_OUTAGE, 'capacity'))


if __name__ == '__main__':
    unittest.main()
