"""No credentials or network: prove bucket-specific subscription reset handling."""
import datetime
import io
import json
import pathlib
import sys
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1] / 'tools'))
import glm_credit as glm

NOW = datetime.datetime(2026, 10, 7, 12, tzinfo=datetime.timezone.utc)
EPOCH_MS = int(NOW.timestamp() * 1000)


class ResetTests(unittest.TestCase):
    def payload(self, five=0, weekly=0):
        return {'code': 200, 'data': {'limits': [
            {'type': 'CREDIT_LIMIT', 'unit': 3, 'number': 5,
             'remaining': five, 'percentage': 100 if five == 0 else 50,
             'nextResetTime': EPOCH_MS + 3600000},
            {'type': 'TOKENS_LIMIT', 'unit': 6, 'number': 1,
             'remaining': weekly, 'percentage': 100 if weekly == 0 else 50,
             'nextResetTime': EPOCH_MS + 86400000}]}}

    def read(self, payload):
        calls = []
        def opener(request, timeout):
            calls.append((request.full_url, request.method, timeout))
            return io.BytesIO(json.dumps(payload).encode())
        result = glm.observation('synthetic-private-key', opener=opener, now=NOW)
        self.assertEqual(calls, [(glm.ENDPOINT, 'GET', 15)])
        self.assertNotIn('synthetic-private-key', json.dumps(result))
        return result

    def test_both_exhausted_wait_for_latest_bucket(self):
        result = self.read(self.payload())
        self.assertEqual(result['state'], 'exhausted')
        self.assertEqual(result['reset_at'], '2026-10-08T12:00:00Z')
        self.assertEqual(result['quota_windows'], [
            {'bucket': 'glm-5h', 'state': 'exhausted', 'reset_at': '2026-10-07T13:00:00Z'},
            {'bucket': 'glm-weekly', 'state': 'exhausted', 'reset_at': '2026-10-08T12:00:00Z'}])

    def test_available_bucket_does_not_delay_exhausted_bucket(self):
        self.assertEqual(self.read(self.payload(weekly=3))['reset_at'], '2026-10-07T13:00:00Z')
        self.assertIsNone(self.read(self.payload(3, 3))['reset_at'])

    def test_missing_unknown_reset_does_not_erase_exhaustion(self):
        payload = self.payload()
        del payload['data']['limits'][1]['nextResetTime']
        result = self.read(payload)
        self.assertEqual(result['state'], 'exhausted')
        self.assertIsNone(result['reset_at'])

    def test_milliseconds_round_forward_never_before_reset(self):
        payload = self.payload(weekly=3)
        payload['data']['limits'][0]['nextResetTime'] += 123
        self.assertEqual(self.read(payload)['reset_at'], '2026-10-07T13:00:01Z')

    def test_bad_reset_never_grants_or_changes_capacity(self):
        for bad in (True, '2026-10-07T13:00:00Z', EPOCH_MS // 1000,
                    EPOCH_MS, -1, float('nan'), float('inf'),
                    EPOCH_MS + (5 * 3600 + 61) * 1000):
            with self.subTest(reset=bad):
                payload = self.payload(weekly=3)
                payload['data']['limits'][0]['nextResetTime'] = bad
                result = self.read(payload)
                self.assertEqual(result['state'], 'exhausted')
                self.assertIsNone(result['reset_at'])

    def test_tool_and_billing_reset_never_reenable_model(self):
        payload = self.payload()
        payload['data']['nextRenewTime'] = '2026-10-07T12:01:00Z'
        payload['data']['limits'].append({'type': 'TIME_LIMIT', 'unit': 5, 'number': 1,
                                         'nextResetTime': EPOCH_MS + 60000})
        self.assertEqual(self.read(payload)['reset_at'], '2026-10-08T12:00:00Z')

    def test_malformed_capacity_never_leaks_partial_resets(self):
        payload = self.payload()
        payload['data']['limits'][1]['remaining'] = True
        result = self.read(payload)
        self.assertEqual(result['state'], 'unknown')
        self.assertIsNone(result['reset_at'])
        self.assertEqual(result['quota_windows'], [])


if __name__ == '__main__':
    unittest.main()
