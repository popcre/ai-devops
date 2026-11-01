#!/usr/bin/env python3
"""Offline source-bound trace replay; no GitHub requests or private fixture text."""
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import sys

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("replay", ROOT / "tools/github-requests/replay.py")
replay = importlib.util.module_from_spec(SPEC); SPEC.loader.exec_module(replay)


def row(second, target=1):
    return {"schema": 6, "utc": f"2026-10-15T00:00:{second:02d}Z", "measurement": "read_observation",
            "caller": "ai-pr-wait", "workflow": "pr_wait", "target_ordinal": target,
            "source": "upstream", "cache_hit": False, "saved_upstream_read": False}


@unittest.skipUnless(sys.platform.startswith("linux"), "Linux offline trace replay; not Windows runtime qualification")
class ReplayTests(unittest.TestCase):
    def test_empty_malformed_digest_backward_and_duplicate_fields_refused(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "2026-10-15.jsonl"
            with self.assertRaises(ValueError): replay.read_trace(directory, "0" * 64)
            for text in ('{}\n', '{"measurement":"read_observation","measurement":"x"}\n',
                         json.dumps(row(20)) + "\n" + json.dumps(row(10)) + "\n",
                         json.dumps(dict(row(10), target_ordinal="raw-private-target")) + "\n"):
                path.write_text(text)
                with self.assertRaises(ValueError):
                    replay.read_trace(directory, hashlib.sha256(text.encode()).hexdigest())
            text = json.dumps(row(1)) + "\n"; path.write_text(text)
            with self.assertRaises(ValueError): replay.read_trace(directory, "0" * 64)

    def test_duplicate_target_ordinals_preserve_order_without_exporting_target(self):
        with tempfile.TemporaryDirectory() as directory:
            text = "".join(json.dumps(row(second, 73)) + "\n" for second in (1, 10, 30))
            (Path(directory) / "2026-10-15.jsonl").write_text(text)
            trace, _ = replay.read_trace(directory, hashlib.sha256(text.encode()).hexdigest())
            self.assertEqual([target for _, target in trace], [73, 73, 73])
            self.assertEqual([stamp - trace[0][0] for stamp, _ in trace], [0, 9_000_000_000, 29_000_000_000])

    def phases(self, trace, profile, failure=None):
        with tempfile.TemporaryDirectory() as directory:
            scratch = Path(directory)
            first, before = replay.execute_phase(ROOT, replay.BASELINE, "baseline", profile, trace,
                                                  "a" * 64, scratch, fixture_failure=failure)
            second, after = replay.execute_phase(ROOT, replay.CANDIDATE, "candidate", profile, trace,
                                                  "a" * 64, scratch, fixture_failure=failure)
            return first, before, second, after

    def test_actual_before_after_skip_duplicate_content_writes_not_upstream_reads(self):
        trace = [(1_792_022_400_000_000_000 + i * 20_000_000_000, 1) for i in range(20)]
        first, before, second, after = self.phases(trace, "stable_open")
        self.assertEqual(before["upstream_fixture_invocations"], 20)
        self.assertEqual(after["upstream_fixture_invocations"], 20)
        self.assertEqual(before["duplicate_unchanged_content_writes"], 19)
        self.assertEqual(after["duplicate_unchanged_content_writes"], 0)
        self.assertEqual(after["cache_metadata_refreshes"], 19)
        self.assertEqual([r["case_id"] for r in first["observations"]], [r["case_id"] for r in second["observations"]])
        self.assertTrue(all(r["observed_completed_writes"] is None and r["graphql_points"] is None
                            and r["detection_ms"] is None and not r["complete"] for r in second["observations"]))

    def test_stable_head_vs_unknown_head_changes_cache_eligibility(self):
        trace = [(1_792_022_400_000_000_000 + i * 1_000_000_000, 1) for i in range(3)]
        _, before, _, after = self.phases(trace, "stable_open")
        self.assertEqual(before["upstream_fixture_invocations"], 1)
        self.assertEqual(after["upstream_fixture_invocations"], 1)
        _, before, _, after = self.phases(trace, "unknown_head")
        self.assertEqual(before["upstream_fixture_invocations"], 3)
        self.assertEqual(after["upstream_fixture_invocations"], 3)

    def test_actual_fixture_failure_is_preserved_and_not_a_remote_outcome(self):
        trace = [(1_792_022_400_000_000_000 + i * 20_000_000_000, 1) for i in range(3)]
        first, _, second, _ = self.phases(trace, "stable_open", failure=1)
        for result in (first, second):
            self.assertEqual([r["outcome"] for r in result["observations"]], ["completed", "failed", "completed"])
            self.assertTrue(all(r["operation"] == "verify_status" for r in result["observations"]))


if __name__ == "__main__": unittest.main()
