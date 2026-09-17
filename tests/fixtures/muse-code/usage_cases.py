"""Muse Code durable-store usage cases invoked by the Muse Code engine suite.

Rows mirror the private store shape verified live on 2026-09-17 (plan
ai-muse-native-engine-parity §6a): token counters live under
.payload.event.usage on runtime.session / model_completed rows. No prompt or
response text is included.
"""
import importlib.util
import json
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('reviewer_usage', ROOT / 'tools/reviewer_usage.py')
usage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(usage)
PINNED = (ROOT / 'config' / 'muse-code' / 'version').read_text(encoding='utf-8').strip()
RUN = '15bc2f6e-c7db-4d34-a234-c7f5668ff30b'
DECOY = '99999999-9999-4999-8999-999999999999'


def completed(run, i, o, cr, cw, r):
    return {'payload_type': 'runtime.session',
            'payload': {'run_id': run,
                        'event': {'kind': 'model_completed', 'model': 'muse-spark-1.3-contributor',
                                  'usage': {'input_tokens': i, 'output_tokens': o, 'cached_tokens': cr,
                                            'cache_write_tokens': cw, 'cache_read_tokens': cr,
                                            'reasoning_tokens': r}}}}


class MuseCodeUsageCases(unittest.TestCase):
    def result(self, events, version=PINNED, run=RUN):
        return usage.muse_code(events, version, run)

    def test_maps_sums_and_scopes_model_completed_rows(self):
        events = [completed(RUN, 19835, 472, 8561, 0, 387),
                  {'payload_type': 'session.end'},
                  completed(RUN, 100, 28, 0, 0, 3),
                  completed(DECOY, 999999, 999999, 999999, 999999, 999999)]
        result = self.result(events)
        self.assertEqual(result['counters'], {'input': 19935, 'cache_read': 8561, 'cache_write': 0,
                                              'output': 500, 'reasoning': 390, 'total': None, 'cost': None})
        self.assertEqual(result['model_calls'], 2)
        self.assertEqual(result['completeness'], 'core-complete')
        self.assertIsNone(result['availability_reason'])
        self.assertEqual(result['counter_provenance'], 'muse-code-%s-durable-store-model-completed' % PINNED)
        self.assertIn('input includes cache_read', result['counting_semantics'])

    def test_unmatched_run_is_unavailable(self):
        result = self.result([completed(DECOY, 1, 2, 0, 0, 0)])
        self.assertEqual(result['completeness'], 'unavailable')
        self.assertEqual(result['availability_reason'], 'no-model-completed-for-run')
        self.assertIsNone(result['counters']['input'])

    def test_empty_run_scope_is_refused(self):
        result = self.result([completed(RUN, 1, 2, 0, 0, 0)], run='')
        self.assertEqual(result['availability_reason'], 'no-model-completed-for-run')

    def test_unqualified_runtime_does_not_reuse_semantics(self):
        result = self.result([completed(RUN, 1, 2, 0, 0, 0)], version='9.9.9')
        self.assertEqual(result['availability_reason'], 'unqualified-muse-code-version')
        self.assertIsNone(result['counters']['input'])

    def test_impossible_cache_subset_is_unknown(self):
        result = self.result([completed(RUN, 5, 2, 7, 0, 1)])
        self.assertIsNone(result['counters']['cache_read'])
        self.assertEqual(result['counters']['input'], 5)
        self.assertEqual(result['completeness'], 'partial')

    def test_invalid_counter_is_partial_never_zero(self):
        row = completed(RUN, 19835, 472, 8561, 0, 387)
        row['payload']['event']['usage']['input_tokens'] = 'many'
        result = self.result([row])
        self.assertIsNone(result['counters']['input'])
        self.assertEqual(result['completeness'], 'partial')
        self.assertEqual(result['availability_reason'], 'incomplete-or-invalid-model-completed-counters')

    def test_zero_is_preserved(self):
        result = self.result([completed(RUN, 0, 0, 0, 0, 0)])
        self.assertEqual(result['counters']['input'], 0)
        self.assertEqual(result['completeness'], 'core-complete')

    def test_non_object_row_is_unreadable(self):
        result = self.result(['junk'])
        self.assertEqual(result['availability_reason'], 'durable-store-unreadable')

    def test_reader_reports_garbage_lines_unreadable(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = pathlib.Path(tmp) / 'session.jsonl'
            path.write_text(json.dumps(completed(RUN, 1, 2, 0, 0, 0)) + '\nnot-json\n', encoding='utf-8')
            result = usage.muse_code_read(str(path), PINNED, RUN)
        self.assertEqual(result['completeness'], 'unavailable')
        self.assertEqual(result['availability_reason'], 'durable-store-unreadable')

    def test_reader_reports_missing_store_unreadable(self):
        missing = ROOT / 'tests' / 'fixtures' / 'muse-code' / 'absent-session.jsonl'
        result = usage.muse_code_read(str(missing), PINNED, RUN)
        self.assertEqual(result['availability_reason'], 'durable-store-unreadable')


if __name__ == '__main__':
    unittest.main()
