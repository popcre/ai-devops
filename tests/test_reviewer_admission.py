"""Behavioral coverage for scoped refusal backoff; no provider calls."""
import importlib.util
import datetime
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

MODULE = pathlib.Path(__file__).resolve().parents[1] / 'tools/reviewer_admission.py'
spec = importlib.util.spec_from_file_location('admission', MODULE)
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)


class AdmissionTests(unittest.TestCase):
    def test_eastern_display_without_iana_handles_spring_and_fall_boundaries(self):
        with mock.patch.object(api, 'ZoneInfo', side_effect=api.ZoneInfoNotFoundError()):
            for utc, suffix in (('2026-03-08T06:59:59Z','01:59 AM EST'),('2026-03-08T07:00:00Z','03:00 AM EDT'),('2026-11-01T05:59:59Z','01:59 AM EDT'),('2026-11-01T06:00:00Z','01:00 AM EST')):
                self.assertTrue(api.eastern_reset_label(api.reset_epoch(utc)).endswith(suffix))
    def test_stale_reset_cannot_restore_fresh_exhaustion_and_fraction_rounds_up(self):
        data={'provider':'glm'}
        observation={'provider':'glm','state':'exhausted','observed_epoch':1000,'credential_profile_scope':'scope','model_scope':'model','reset_at':'1970-01-01T00:16:39Z'}
        self.assertEqual(api.capacity_observation(data,'glm',observation,1000)['status'],'held')
        self.assertIsNone(data['capacity_hold']['reset_at'])
        self.assertEqual(api.reset_epoch('1970-01-01T00:16:40.999Z'),1001)

    def test_concurrent_refusals_and_status_keep_latest_hold(self):
        import time
        import concurrent.futures
        now=int(time.time())
        future=datetime.datetime.fromtimestamp(now+7200,datetime.timezone.utc).isoformat()
        self.evidence.write_text(json.dumps({'provider':'qwen','failure_class':'allowance-exhausted','reset_at':future}))
        credit=[sys.executable,str(MODULE),'credit','qwen','--directory',str(self.directory),'--marker',str(self.evidence),'--record']
        status=[sys.executable,str(MODULE),'capacity-status','qwen','--directory',str(self.directory)]
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
            results=list(executor.map(lambda command:subprocess.run(command,capture_output=True,text=True),[credit,status,credit,status,credit,status]))
        self.assertTrue(all(result.returncode==0 for result in results))
        self.assertEqual(api.load(self.directory,'qwen')['capacity_hold']['reset_at'],future)
    def test_plain_quoted_allowance_or_reset_cannot_hold(self):
        for text in ('The assistant says monthly quota exhausted.', '{"response":"monthly quota exhausted","reset_at":"2999-01-01T00:00:00Z"}', 'tool error: weekly quota exceeded'):
            self.evidence.write_text(text)
            result=subprocess.run([sys.executable,str(MODULE),'credit','qwen','--directory',str(self.directory),'--scan',str(self.evidence),'--record'],capture_output=True,text=True)
            self.assertEqual(result.returncode,3,result.stdout)
        self.assertIsNone(api.load(self.directory,'qwen').get('capacity_hold'))

    def test_capacity_observation_rejects_wrong_provider(self):
        data={'provider':'glm'}
        result=api.capacity_observation(data,'glm',{'provider':'deepseek','state':'exhausted','observed_epoch':1000},1000)
        self.assertEqual(result['reason'],'wrong-provider')
        self.assertNotIn('capacity_hold',data)

    def test_partial_refusals_never_shorten_reset_and_precise_reset_enriches_unknown(self):
        import time
        now=int(time.time())
        def marker(delta):
            value=datetime.datetime.fromtimestamp(now+delta,datetime.timezone.utc).isoformat() if delta else None
            self.evidence.write_text(json.dumps({'provider':'qwen','failure_class':'allowance-exhausted','reset_at':value}))
            result=subprocess.run([sys.executable,str(MODULE),'credit','qwen','--directory',str(self.directory),'--marker',str(self.evidence),'--record'],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            effective=api.load(self.directory,'qwen')['capacity_hold']['reset_at']
            if effective:
                label=api.eastern_reset_label(api.reset_epoch(effective))
                self.assertIn(label,result.stdout)
            return api.load(self.directory,'qwen')['capacity_hold']['reset_at']
        later=marker(7200)
        self.assertEqual(marker(3600),later)
        self.assertEqual(marker(None),later)
        self.assertNotEqual(marker(10800),later)

    def test_precise_reset_enriches_legacy_unknown_but_stale_marker_cannot(self):
        import time
        now=int(time.time())
        hold={'provider':'qwen','failure_class':'allowance-exhausted','credential_profile_scope':None,'model_scope':None,'observed_epoch':now-1000,'reset_at':None,'next_check_epoch':now,'record_id':'old'}
        api.publish(self.directory,'qwen',{'version':2,'provider':'qwen','global':None,'backoffs':{},'capacity_hold':hold})
        reset=datetime.datetime.fromtimestamp(now+3600,datetime.timezone.utc).isoformat()
        self.evidence.write_text(json.dumps({'provider':'qwen','failure_class':'allowance-exhausted','reset_at':reset,'observed_epoch':now-300}))
        command=[sys.executable,str(MODULE),'credit','qwen','--directory',str(self.directory),'--marker',str(self.evidence),'--record']
        result=subprocess.run(command,capture_output=True,text=True)
        self.assertEqual(result.returncode,3)
        self.assertEqual(api.load(self.directory,'qwen')['capacity_hold'],hold)
        self.evidence.write_text(json.dumps({'provider':'qwen','failure_class':'allowance-exhausted','reset_at':reset,'observed_epoch':now}))
        result=subprocess.run(command,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(api.load(self.directory,'qwen')['capacity_hold']['reset_at'],reset)

    def test_invalid_reset_never_becomes_expiry(self):
        for reset in (True, False, float('nan'), '2026-01-01T00:00:00', 'invalid', '2999-01-01T00:00:00Z'):
            self.evidence.write_text(json.dumps({'provider':'qwen','failure_class':'allowance-exhausted','reset_at':reset}))
            result=subprocess.run([sys.executable,str(MODULE),'credit','qwen','--directory',str(self.directory),'--marker',str(self.evidence),'--record'],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertIsNone(api.load(self.directory,'qwen')['capacity_hold']['reset_at'])
    def test_provider_marker_allowance_stores_reset_without_overwriting_global(self):
        import time
        now=int(time.time())
        hold={'version':1,'provider':'qwen','failure_class':'authentication-failed','created_epoch':now,'expires_epoch':now+86400}
        api.publish(self.directory,'qwen',{'version':2,'provider':'qwen','global':hold,'backoffs':{}})
        reset=datetime.datetime.fromtimestamp(now+3600,datetime.timezone.utc).isoformat()
        self.evidence.write_text(json.dumps({'provider':'qwen','failure_class':'allowance-exhausted','error':{'code':'QuotaExceeded','message':'monthly quota exhausted'},'reset_at':reset}))
        result=subprocess.run([sys.executable,str(MODULE),'credit','qwen','--directory',str(self.directory),'--marker',str(self.evidence),'--record'],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('AI_REVIEWER_ALLOWANCE_EXHAUSTED',result.stdout)
        stored=api.load(self.directory,'qwen')
        self.assertEqual(stored['global'],hold)
        self.assertEqual(stored['capacity_hold']['reset_at'],reset)

    def test_stale_and_repeated_observation_cannot_release_hold(self):
        data={'provider':'glm'}
        base={'provider':'glm','state':'exhausted','observed_epoch':1000,'credential_profile_scope':'same','model_scope':'same'}
        api.capacity_observation(data,'glm',base,1000)
        self.assertEqual(api.capacity_observation(data,'glm',dict(base,state='available'),1000)['reason'],'older-observation')
        self.assertEqual(api.capacity_observation(data,'glm',dict(base,state='available'),1400)['reason'],'unknown-stale-or-unscoped')
        self.assertIsNotNone(data['capacity_hold'])
    def test_capacity_paid_hold_never_clock_expires_and_scope_controls_recovery(self):
        data = {'provider':'deepseek','global':{'stronger':'kept'},'backoffs':{}}
        exhausted = {'provider':'deepseek','state':'exhausted','observed_epoch':1000,'credential_profile_scope':'account-a','model_scope':'model-a','reset_at':'1970-01-01T00:20:00Z'}
        self.assertEqual(api.capacity_observation(data,'deepseek',exhausted,1000)['status'],'held')
        self.assertIsNone(data['capacity_hold']['reset_at'])
        positive = dict(exhausted,state='available',observed_epoch=1001,credential_profile_scope='account-b')
        self.assertEqual(api.capacity_observation(data,'deepseek',positive,1001)['reason'],'wrong-scope')
        positive['credential_profile_scope']='account-a'
        self.assertEqual(api.capacity_observation(data,'deepseek',positive,1001)['status'],'restored')
        self.assertEqual(data['global'],{'stronger':'kept'})

    def test_unknown_scope_exhaustion_holds_but_positive_cannot_release(self):
        data = {'provider':'gemini'}
        self.assertEqual(api.capacity_observation(data,'gemini',{'provider':'gemini','state':'exhausted','observed_epoch':1000},1000)['status'],'held')
        self.assertEqual(api.capacity_observation(data,'gemini',{'provider':'gemini','state':'available','observed_epoch':1001,'credential_profile_scope':'another','model_scope':'model'},1001)['reason'],'wrong-scope')
        self.assertEqual(api.capacity_observation(data,'gemini',{'provider':'gemini','state':'unknown'},1001)['status'],'deferred')
        self.assertEqual(data['capacity_hold']['next_check_epoch'],4601)

    def test_subscription_provider_reset_returns_candidate_without_clearing_stronger_hold(self):
        import time
        now=int(time.time())
        data={'version':2,'provider':'glm','global':{'version':1,'provider':'glm','failure_class':'authentication-failed','created_epoch':now,'expires_epoch':now+86400},'backoffs':{},'capacity_hold':{'provider':'glm','failure_class':'allowance-exhausted','credential_profile_scope':None,'model_scope':None,'observed_epoch':now-50,'reset_at':datetime.datetime.fromtimestamp(now-1,datetime.timezone.utc).isoformat(),'next_check_epoch':now-1}}
        api.publish(self.directory,'glm',data)
        result=subprocess.run([sys.executable,str(MODULE),'capacity-status','glm','--directory',str(self.directory)],capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(json.loads(result.stdout),None)
        stored=api.load(self.directory,'glm')
        self.assertEqual(stored['global'],data['global'])
        self.assertIsNotNone(stored['last_capacity_reset'])

    def test_expired_legacy_paid_credit_hold_remains(self):
        import time
        now=int(time.time())
        data={'version':2,'provider':'grok','global':{'version':1,'provider':'grok','failure_class':'out-of-credit','created_epoch':now-7200,'expires_epoch':now-3600},'backoffs':{}}
        api.publish(self.directory,'grok',data)
        result=subprocess.run([sys.executable,str(MODULE),'global','grok','--directory',str(self.directory)],capture_output=True,text=True)
        self.assertIsNone(json.loads(result.stdout))
        migrated=api.load(self.directory,'grok')
        self.assertEqual(migrated['legacy_capacity_evidence'],data['global'])
        self.assertEqual(migrated['capacity_hold']['failure_class'],'out-of-credit')
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.directory = pathlib.Path(self.tmp.name)
        self.evidence = self.directory / 'terminal.json'
        self.evidence.write_text('{"terminal":"usage-limit"}')

    def test_failure_pause_preserves_stronger_credit_and_scoped_backoff(self):
        hold = {'version': 1, 'provider': 'kimi', 'failure_class': 'out-of-credit',
                'created_epoch': 900, 'expires_epoch': 10000, 'record_id': 'original'}
        data = {'global': hold, 'backoffs': {'profile': {'unchanged': True}}}
        actual = api.pause_failure(data, 'kimi', 'provider-timeout', 1000)
        self.assertEqual(actual, hold)
        self.assertEqual(data['backoffs'], {'profile': {'unchanged': True}})

    def test_failure_pause_extends_active_hold_without_changing_credit_reason(self):
        hold = {'version': 1, 'provider': 'kimi', 'failure_class': 'out-of-credit',
                'created_epoch': 900, 'expires_epoch': 1100, 'record_id': 'original'}
        data = {'global': hold, 'backoffs': {}}
        actual = api.pause_failure(data, 'kimi', 'wrapper-crash', 1000)
        self.assertEqual(actual['expires_epoch'], 4600)
        self.assertEqual(actual['failure_class'], 'out-of-credit')
        self.assertEqual(actual['created_epoch'], 900)
        self.assertNotEqual(actual['record_id'], 'original')

    def test_failure_pause_refuses_non_integer_duration_and_non_string_cause(self):
        for seconds in (3600.0, True, False, '3600', None):
            with self.subTest(seconds=seconds):
                data = {'global': None}
                with self.assertRaises(ValueError):
                    api.pause_failure(data, 'kimi', 'provider-timeout', 1000, seconds)
                self.assertEqual(data, {'global': None})
        for reason in (None, 3600, {}, True):
            with self.subTest(reason=reason):
                with self.assertRaises(ValueError):
                    api.pause_failure({'global': None}, 'kimi', reason, 1000)
        for now in (1000.0, True, None):
            with self.subTest(now=now):
                with self.assertRaises(ValueError):
                    api.pause_failure({'global': None}, 'kimi', 'provider-timeout', now)

    def test_failure_pause_rejects_missing_cause_wrong_duration_and_malformed_hold(self):
        for reason, seconds in [('', 3600), ('provider-timeout', 1), ('provider-timeout', 86400)]:
            with self.assertRaises(ValueError):
                api.pause_failure({'global': None}, 'kimi', reason, 1000, seconds)
        with self.assertRaises(ValueError):
            api.pause_failure({'global': {'provider': 'other'}}, 'kimi', 'wrapper-crash', 1000)

    def test_expired_hold_does_not_mask_new_named_failure(self):
        data = {'global': {'version': 1, 'provider': 'kimi', 'failure_class': 'out-of-credit',
                           'created_epoch': 100, 'expires_epoch': 1000, 'record_id': 'old'}}
        actual = api.pause_failure(data, 'kimi', 'wrapper-crash', 1000)
        self.assertEqual(actual['failure_class'], 'wrapper-crash')
        self.assertEqual(actual['expires_epoch'], 4600)

    def test_observed_failure_window_is_fixed_and_replay_is_monotonic(self):
        data = {'global': None, 'backoffs': {}}
        initial = api.pause_failure(data, 'kimi', 'provider-timeout', 1000, observed=900)
        self.assertEqual(initial['created_epoch'], 900)
        self.assertEqual(initial['expires_epoch'], 4500)
        self.assertEqual(api.pause_failure(data, 'kimi', 'provider-timeout', 1200, observed=900), initial)
        snapshot = json.dumps(data, sort_keys=True)
        expired = api.pause_failure(data, 'kimi', 'provider-timeout', 4500, observed=900)
        self.assertEqual(expired['status'], 'expired')
        self.assertEqual(json.dumps(data, sort_keys=True), snapshot)
        for observed in (True, False, 900.0, -1, 1001, '900'):
            with self.subTest(observed=observed):
                with self.assertRaises(ValueError):
                    api.pause_failure({'global': None}, 'kimi', 'provider-timeout', 1000, observed=observed)

    def test_pause_status_and_expired_cli_do_not_rewrite_protected_record(self):
        data = {'version': 2, 'provider': 'kimi', 'global': {
            'version': 1, 'provider': 'kimi', 'failure_class': 'out-of-credit',
            'created_epoch': 100, 'expires_epoch': 1000, 'record_id': 'retained'}, 'backoffs': {}}
        api.publish(self.directory, 'kimi', data)
        file = self.directory / 'kimi.json'
        before, modified = file.read_bytes(), file.stat().st_mtime_ns
        command = [sys.executable, str(MODULE), 'pause-status', 'kimi', '--directory', str(self.directory)]
        actual = json.loads(subprocess.check_output(command, text=True))
        self.assertEqual(actual, data['global'])
        command = [sys.executable, str(MODULE), 'pause', 'kimi', '--directory', str(self.directory),
                   '--reason', 'provider-timeout', '--seconds', '3600', '--observed', '0']
        self.assertEqual(json.loads(subprocess.check_output(command, text=True))['status'], 'expired')
        self.assertEqual((file.read_bytes(), file.stat().st_mtime_ns), (before, modified))
        file.write_text('{"version":2,"provider":"other","global":null,"backoffs":{}}')
        self.assertNotEqual(subprocess.run([sys.executable, str(MODULE), 'pause-status', 'kimi', '--directory', str(self.directory)], capture_output=True).returncode, 0)

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
