"""Unit tests for timing.py. Run: python -m unittest test_timing -v"""

import json
import os
import subprocess
import sys
import unittest
from collections import Counter

import timing

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURE = os.path.join(HERE, "fixtures", "timing_basic.json")


def _job(report, run_id, attempt, job_id):
    for rec in report["jobs"]:
        if (rec["run_id"], rec["attempt"], rec["job_id"]) == (run_id, attempt, job_id):
            return rec
    raise AssertionError("job not found: %s/%s/%s" % (run_id, attempt, job_id))


def _pr(report, number):
    for entry in report["prs"]:
        if entry["pr"] == number:
            return entry
    raise AssertionError("pr not found: %s" % number)


def _pairs(baselines, candidates):
    return list(zip(baselines, candidates))


class TimingTests(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        with open(FIXTURE, encoding="utf-8") as handle:
            cls.report = timing.analyze(json.load(handle))

    def test_timing_sample(self):
        r = self.report

        # PR 101 per-job values. Run 1001 created 10:00:00, settle 30 -> ready 10:00:30.
        # lint: start 10:00:40 -> start_minus_created 40 - 0 = 40; ready_wait 10:00:40 - 10:00:30 = 10
        lint = _job(r, 1001, 1, 1)
        self.assertEqual((lint["start_minus_created"], lint["ready_wait"]), (40, 10))
        # test: start 10:00:30 -> start_minus_created 30; ready_wait 10:00:30 - 10:00:30 = 0
        test = _job(r, 1001, 1, 2)
        self.assertEqual((test["start_minus_created"], test["ready_wait"]), (30, 0))
        # gate needs lint and test; ready = max(10:00:30, lint done 10:02:30, test done 10:05:30) = 10:05:30
        # start_minus_created 10:05:50 - 10:00:00 = 350; ready_wait 10:05:50 - 10:05:30 = 20
        gate = _job(r, 1001, 1, 3)
        self.assertEqual(gate["readiness"], "known")
        self.assertEqual((gate["start_minus_created"], gate["ready_wait"]), (350, 20))
        # rerun lint (attempt 2, settle 0, created 10:00:00): start 10:10:00
        # start_minus_created 10:10:00 - 10:00:00 = 600; ready_wait 10:10:00 - 10:00:00 = 600
        rerun_lint = _job(r, 1001, 2, 4)
        self.assertEqual(rerun_lint["category"], "rerun")
        self.assertEqual((rerun_lint["start_minus_created"], rerun_lint["ready_wait"]), (600, 600))
        # merge-check (merge_group run created 10:20:00, settle 60 -> ready 10:21:00)
        # start_minus_created 10:21:30 - 10:20:00 = 90; ready_wait 10:21:30 - 10:21:00 = 30
        merge = _job(r, 1003, 1, 5)
        self.assertEqual(merge["category"], "merge_group")
        self.assertEqual((merge["start_minus_created"], merge["ready_wait"]), (90, 30))

        # PR 101 critical path, first_created = 10:00:00.
        pr101 = _pr(r, 101)
        # pr checks done = latest pull_request job = rerun lint 10:12:00 -> 10:12:00 - 10:00:00 = 720
        self.assertEqual(pr101["pr_checks_done_s"], 720)
        # required (gate) done = 10:06:50 - 10:00:00 = 410
        self.assertEqual(pr101["required_done_s"], 410)
        # advisory (lint, test, rerun lint) latest = 10:12:00 - 10:00:00 = 720
        self.assertEqual(pr101["advisory_done_s"], 720)
        # merge group done = 10:31:30 - 10:00:00 = 1890
        self.assertEqual(pr101["merge_group_done_s"], 1890)
        # critical path = latest included job 10:31:30 - 10:00:00 = 1890
        self.assertEqual(pr101["critical_path_s"], 1890)
        # enqueued_to_merged = 10:40:00 - 10:15:00 = 1500
        self.assertEqual(pr101["enqueued_to_merged_s"], 1500)

        # PR 102 exclusions: null-start (null_time), negative-duration (negative_time),
        # second copy of job 10 (duplicate). One of each.
        pr102_reasons = Counter(
            e["reason"] for e in r["excluded_jobs"] if e["pr"] == 102
        )
        self.assertEqual(
            dict(pr102_reasons), {"null_time": 1, "negative_time": 1, "duplicate": 1}
        )
        self.assertEqual(
            r["excluded"], {"null_time": 1, "negative_time": 1, "duplicate": 1}
        )
        # cancelled job 11 is not excluded; it sits in the cancelled category
        self.assertEqual(_job(r, 1004, 1, 11)["category"], "cancelled")

        # PR 102 orphan job: needs "missing-job", which is not in the run -> unknown readiness
        orphan = _job(r, 1004, 1, 14)
        self.assertEqual(orphan["readiness"], "unknown")
        self.assertIsNone(orphan["ready_wait"])
        # PR 102 critical path: build done 12:03:20 - 12:00:00 = 200; the cancelled job is ignored
        pr102 = _pr(r, 102)
        self.assertEqual(pr102["required_done_s"], 200)
        # advisory = orphan done 12:02:00 - 12:00:00 = 120
        self.assertEqual(pr102["advisory_done_s"], 120)
        self.assertEqual(pr102["critical_path_s"], 200)
        self.assertIsNone(pr102["merge_group_done_s"])
        self.assertIsNone(pr102["enqueued_to_merged_s"])

        # PR 103 has no runs: critical path null
        pr103 = _pr(r, 103)
        self.assertEqual(pr103["considered_jobs"], 0)
        self.assertIsNone(pr103["critical_path_s"])

        # Group (pr, CI, ubuntu-latest): lint 1001/1, test, gate, build, orphan. n = 5.
        # durations: lint 110, test 300, gate 60, build 180, orphan 90
        #   sorted 60, 90, 110, 180, 300 -> median rank ceil(2.5)=3 -> 110; p95 rank ceil(4.75)=5 -> 300
        # start_minus_created: 40, 30, 350, 20, 30 -> sorted 20, 30, 30, 40, 350
        #   median rank 3 -> 30; p95 rank 5 -> 350
        # ready_wait known only: 10, 0, 20, 20 (orphan unknown) -> sorted 0, 10, 20, 20
        #   median rank 2 -> 10; p95 rank ceil(3.8)=4 -> 20; unknown count 1
        group = next(
            g for g in r["groups"]
            if (g["category"], g["workflow"], g["runner_label"]) == ("pr", "CI", "ubuntu-latest")
        )
        self.assertEqual(group["n"], 5)
        self.assertEqual(group["duration"], {"n": 5, "median": 110, "p95": 300})
        self.assertEqual(group["start_minus_created"], {"n": 5, "median": 30, "p95": 350})
        self.assertEqual(group["ready_wait"], {"n": 4, "median": 10, "p95": 20})
        self.assertEqual(group["unknown_readiness"], 1)

        # Category totals for pr: settle = 30 + 30 + 30 (run 1001) + 0 + 0 = 90
        # ready_wait known = 10 + 0 + 20 + 20 = 50; unknown = 1
        self.assertEqual(r["totals"]["pr"]["settle_seconds"], 90)
        self.assertEqual(r["totals"]["pr"]["ready_wait_seconds"], 50)
        self.assertEqual(r["totals"]["pr"]["unknown_readiness"], 1)

    def test_paired_tail_gate(self):
        # 20 pairs, baseline 100 each, candidate 70 each.
        # median 100 -> 70, improvement 1 - 70/100 = 0.30 >= 0.20,
        # diffs all -30, p90 = sorted[ceil(18)-1] = -30 <= 0 -> pass
        ok = timing.paired_gate(_pairs([100] * 20, [70] * 20))
        self.assertTrue(ok["passed"])
        self.assertIsNone(ok["reason"])
        self.assertEqual(ok["n"], 20)
        self.assertEqual(ok["median_baseline"], 100)
        self.assertEqual(ok["median_candidate"], 70)
        self.assertAlmostEqual(ok["improvement"], 0.30)
        self.assertEqual(ok["p90_diff"], -30)

        # 19 pairs with the same values -> fails on count
        few = timing.paired_gate(_pairs([100] * 19, [70] * 19))
        self.assertFalse(few["passed"])
        self.assertEqual(few["reason"], "fewer_than_20_pairs")

        # 20 pairs, median improvement 30% (candidate 70 vs baseline 100), but 3 pairs
        # are slower (150 vs 100, diff +50). Sorted diffs: 17 x -30, then 3 x +50.
        # p90 = sorted[ceil(18)-1] = sorted[17] = +50 > 0 -> fails on tail
        tail = timing.paired_gate(
            _pairs([100] * 20, [70] * 17 + [150] * 3)
        )
        self.assertFalse(tail["passed"])
        self.assertEqual(tail["reason"], "p90_diff_positive")
        self.assertEqual(tail["p90_diff"], 50)
        self.assertAlmostEqual(tail["improvement"], 0.30)

        # Zero baseline: 20 pairs of 0 -> median baseline 0 -> fails
        zero = timing.paired_gate(_pairs([0] * 20, [0] * 20))
        self.assertFalse(zero["passed"])
        self.assertEqual(zero["reason"], "non_positive_baseline")
        self.assertIsNone(zero["improvement"])

    def test_nearest_rank_examples(self):
        # [10,20,30,40]: p50 rank ceil(2)=2 -> 20; p95 rank ceil(3.8)=4 -> 40
        self.assertEqual(timing.nearest_rank([10, 20, 30, 40], 50), 20)
        self.assertEqual(timing.nearest_rank([10, 20, 30, 40], 95), 40)
        self.assertIsNone(timing.nearest_rank([], 50))

    def test_cli_prints_json(self):
        completed = subprocess.run(
            [sys.executable, os.path.join(HERE, "timing.py"), FIXTURE],
            capture_output=True, text=True, check=True,
        )
        parsed = json.loads(completed.stdout)
        self.assertEqual(_pr(parsed, 101)["critical_path_s"], 1890)


if __name__ == "__main__":
    unittest.main()
