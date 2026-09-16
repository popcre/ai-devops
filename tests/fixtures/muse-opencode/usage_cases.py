"""Provider-shaped usage cases invoked by the existing Muse contract suite."""
import copy
import importlib.util
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
spec = importlib.util.spec_from_file_location('reviewer_usage', ROOT / 'tools/reviewer_usage.py')
usage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(usage)
FIXTURE = json.loads((pathlib.Path(__file__).parent / 'usage-1.18.12.json').read_text())


class UsageCases(unittest.TestCase):
    def events(self):
        return copy.deepcopy(FIXTURE['events'])

    def test_live_three_step_fixture(self):
        result = usage.opencode(self.events(), '1.18.12')
        self.assertEqual(result['counters'], FIXTURE['expected'])
        self.assertEqual(result['unique_steps'], 3)
        self.assertIn('provider-missingness-unknown', result['completeness'])
        self.assertAlmostEqual(result['adapter_cost_estimate'], 0.0295689)
        self.assertIsNone(result['counters']['cost'])

    def test_exact_duplicate_parts_not_double_counted(self):
        events = self.events()
        self.assertEqual(usage.opencode(events + events, '1.18.12')['counters'], FIXTURE['expected'])

    def test_message_aggregates_never_added(self):
        events = self.events() + [{'type':'message.updated','info':{'tokens':{'input':999999},'cost':999}}]
        self.assertEqual(usage.opencode(events, '1.18.12')['counters'], FIXTURE['expected'])

    def test_conflicting_cumulative_duplicate_is_unknown(self):
        events = self.events()
        changed = copy.deepcopy(events[-1]); changed['part']['tokens']['total'] += 1
        result = usage.opencode(events + [changed], '1.18.12')
        self.assertEqual(result['completeness'], 'partial')
        self.assertIsNone(result['counters']['total'])

    def test_missing_final_event_is_not_a_turn_total(self):
        self.assertIsNone(usage.opencode(self.events()[:-1], '1.18.12')['counters']['input'])

    def test_missing_identity_is_not_deduplicated_by_text(self):
        events = self.events(); del events[-1]['part']['id']
        self.assertIsNone(usage.opencode(events, '1.18.12')['counters']['input'])

    def test_mixed_sessions_are_not_added(self):
        events = self.events(); events[-1]['sessionID'] = 'another-session'
        self.assertIsNone(usage.opencode(events, '1.18.12')['counters']['input'])

    def test_missing_nested_cache_remains_unknown(self):
        events = self.events(); del events[-1]['part']['tokens']['cache']['read']
        result = usage.opencode(events, '1.18.12')
        self.assertIsNone(result['counters']['input'])
        self.assertIsNone(result['counters']['cache_read'])
        self.assertEqual(result['counters']['output'], 2508)

    def test_zero_is_preserved(self):
        result = usage.deepseek({'usage':{'prompt_tokens':0,'completion_tokens':0,'prompt_cache_hit_tokens':0,'total_tokens':0}})
        self.assertEqual(result['counters']['input'], 0)
        self.assertEqual(result['counters']['cache_read'], 0)
        self.assertEqual(result['counters']['output'], 0)

    def test_missing_null_invalid_are_unknown(self):
        for value in (None, '0', True, -1, 1.5, float('nan'), float('inf'), {}, []):
            with self.subTest(value=value):
                result = usage.deepseek({'usage':{'prompt_tokens':value}})
                self.assertIsNone(result['counters']['input'])
                self.assertIsNone(result['counters']['output'])

    def test_deepseek_reasoning_not_added_to_output(self):
        result = usage.deepseek({'id':'synthetic','usage':{'prompt_tokens':10,'completion_tokens':7,'total_tokens':17,'completion_tokens_details':{'reasoning_tokens':5}}})
        self.assertEqual(result['counters']['output'], 7)
        self.assertEqual(result['counters']['reasoning'], 5)
        self.assertEqual(result['counters']['total'], 17)

    def test_impossible_cache_subset_is_unknown(self):
        result = usage.deepseek({'usage':{'prompt_tokens':2,'completion_tokens':1,'prompt_cache_hit_tokens':3}})
        self.assertIsNone(result['counters']['cache_read'])
        self.assertEqual(result['completeness'], 'partial')

    def test_unqualified_runtime_does_not_reuse_semantics(self):
        result = usage.opencode(self.events(), '1.19.0')
        self.assertIsNone(result['counters']['input'])
        self.assertEqual(result['availability_reason'], 'unqualified-opencode-version')


if __name__ == '__main__':
    unittest.main()
