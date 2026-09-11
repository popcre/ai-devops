"""Behavioral coverage for scoped refusal backoff; no provider calls."""
import importlib.util
import json
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


if __name__ == '__main__':
    unittest.main()
