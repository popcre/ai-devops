#!/usr/bin/env python3
"""Paired measurements must preserve uncertainty and workload identity (#658)."""
import copy
import importlib.util
import json
import pathlib
import subprocess
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('cohort_compare', ROOT / 'tools/github-requests/compare.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def cohort(phase, size=20):
    return {'schema': 1, 'phase': phase, 'workload_kind': 'offline_trace_replay', 'source_sha': 'a' * 40,
            'observations': [{'case_id': f'{i:032x}', 'operation': 'pr_wait', 'outcome': 'merged',
                              'observed_completed_writes': 10 if phase == 'baseline' else 6,
                              'failed_write_attempts': 0, 'observed_external_writes': 0, 'complete': True,
                              'graphql_points': 10 if phase == 'baseline' else 6,
                              'replay_reads': 10 if phase == 'baseline' else 5, 'unchanged_writes': 0,
                              'duration_ms': [1000, 1000], 'detection_ms': [100, 200]} for i in range(size)]}


class Comparison(unittest.TestCase):
    def setUp(self):
        self.before, self.after = cohort('baseline'), cohort('candidate')

    def metric(self):
        return MODULE.compare(self.before, self.after)['operations']['pr_wait']

    def test_exact_floors_and_thresholds_are_computed_without_granting_programme_acceptance(self):
        result = MODULE.compare(self.before, self.after)
        self.assertEqual(result['equivalence'], 'pass')
        self.assertEqual(result['programme_acceptance'], 'not_evaluated')
        self.assertIsNone(result['http_requests'])
        item = result['operations']['pr_wait']
        self.assertEqual(item['managed_observed_write_reduction_30_percent']['state'], 'pass')
        self.assertEqual(item['duplicate_read_reduction_50_percent']['reduction_percent'], 50)
        self.assertEqual(item['detection_ceiling'], 'pass')

    def test_missing_total_is_unknown_not_zero(self):
        self.after['observations'][0]['observed_completed_writes'] = None
        self.assertEqual(self.metric()['managed_observed_write_reduction_30_percent']['state'], 'unknown')

    def test_failed_or_external_writes_cannot_qualify_observed_subset(self):
        for field in ('failed_write_attempts', 'observed_external_writes'):
            with self.subTest(field=field):
                after = copy.deepcopy(self.after)
                after['observations'][0][field] = 1
                item = MODULE.compare(self.before, after)['operations']['pr_wait']
                self.assertEqual(item['managed_observed_write_reduction_30_percent']['state'], 'unknown')

    def test_equivalent_terminal_outcomes_and_case_identity_required(self):
        self.after['observations'][0]['outcome'] = 'checks_failed'
        self.assertEqual(MODULE.compare(self.before, self.after)['equivalence'], 'fail')
        self.after = cohort('candidate')
        self.after['observations'][0]['case_id'] = 'f' * 32
        self.assertEqual(MODULE.compare(self.before, self.after)['equivalence'], 'fail')

    def test_replay_cannot_be_relabelled_as_natural_candidate(self):
        self.after['workload_kind'] = 'natural_live'
        self.assertEqual(MODULE.compare(self.before, self.after)['equivalence'], 'fail')

    def test_small_sample_does_not_produce_p95_verdict(self):
        result = MODULE.compare(cohort('baseline', 19), cohort('candidate', 19))
        self.assertEqual(result['operations']['pr_wait']['sample_floor'], 'unknown')
        self.assertNotIn('p95_duration_within_5_percent', result['operations']['pr_wait'])

    def test_latency_intervals_must_clear_threshold_conservatively(self):
        for row in self.after['observations']:
            row['duration_ms'] = [1040, 1060]
        self.assertEqual(self.metric()['p95_duration_within_5_percent']['state'], 'unknown')
        for row in self.after['observations']:
            row['duration_ms'] = [1060, 1080]
        self.assertEqual(self.metric()['p95_duration_within_5_percent']['state'], 'fail')
        for row in self.after['observations']:
            row['duration_ms'] = [1030, 1050]
        self.assertEqual(self.metric()['p95_duration_within_5_percent']['state'], 'pass')

    def test_detection_interval_straddling_ceiling_is_unknown(self):
        self.after['observations'][0]['detection_ms'] = [299900, 300100]
        self.assertEqual(self.metric()['detection_ceiling'], 'unknown')

    def test_unknown_or_nonzero_duplicate_writes_never_pass(self):
        self.after['observations'][0]['unchanged_writes'] = None
        self.assertEqual(self.metric()['zero_duplicate_unchanged_writes'], 'unknown')
        self.after['observations'][0]['unchanged_writes'] = 1
        self.assertEqual(self.metric()['zero_duplicate_unchanged_writes'], 'fail')

    def test_zero_baseline_does_not_manufacture_reduction(self):
        for data in (self.before, self.after):
            for row in data['observations']:
                row['replay_reads'] = 0
        self.assertEqual(self.metric()['duplicate_read_reduction_50_percent']['state'], 'unknown')

    def test_deadlines_are_not_successful_work(self):
        for data in (self.before, self.after):
            data['observations'][0]['outcome'] = 'deadline'
        self.assertEqual(self.metric()['sample_floor'], 'unknown')

    def test_duplicate_ids_unknown_fields_and_boolean_counts_refused(self):
        for change in ('duplicate', 'unknown', 'boolean', 'backward_interval'):
            with self.subTest(change=change):
                bad = copy.deepcopy(self.after)
                if change == 'duplicate':
                    bad['observations'][1]['case_id'] = bad['observations'][0]['case_id']
                elif change == 'unknown':
                    bad['observations'][0]['raw_argument'] = 'not permitted'
                elif change == 'boolean':
                    bad['observations'][0]['observed_completed_writes'] = True
                else:
                    bad['observations'][0]['duration_ms'] = [10, 1]
                with self.assertRaises(ValueError):
                    MODULE.compare(self.before, bad)

    def test_cli_reports_only_aggregate_and_bound_digests(self):
        with tempfile.TemporaryDirectory() as directory:
            paths = [pathlib.Path(directory) / name for name in ('before.json', 'after.json')]
            for path, data in zip(paths, (self.before, self.after)):
                path.write_text(json.dumps(data))
            run = subprocess.run([sys.executable, str(ROOT / 'tools/github-requests/compare.py'), *map(str, paths)],
                                 capture_output=True, text=True, timeout=10)
            self.assertEqual(run.returncode, 0, run.stderr)
            self.assertNotIn('case_id', run.stdout)
            self.assertNotIn(directory, run.stdout)
            self.assertEqual(len(json.loads(run.stdout)['input_sha256']['baseline']), 64)
            paths[0].write_text('{"schema":1,"schema":1}')
            run = subprocess.run([sys.executable, str(ROOT / 'tools/github-requests/compare.py'), *map(str, paths)],
                                 capture_output=True, text=True, timeout=10)
            self.assertEqual(run.returncode, 2)
            self.assertEqual(run.stdout, '')


if __name__ == '__main__':
    unittest.main()
