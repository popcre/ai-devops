#!/usr/bin/env python3
"""Offline counters for #658 section 13 item 2: redundant reads and writes."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "tools/github-requests/target_ordinal.py"
REPORT = ROOT / "tools/github-requests/report.py"
SINGLE = ROOT / "tools/github-requests/pr_status_singleflight.py"
sys.path.insert(0, str(ROOT / "tools/github-requests"))
import measure_append  # noqa: E402
import target_ordinal  # noqa: E402


class TargetOrdinal(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = Path(self.tmp.name) / "state"
        self.state.mkdir(mode=0o700)

    def test_same_key_stable_and_distinct_keys_differ(self):
        first = target_ordinal.ordinal_for(self.state, "owner/repo#12")
        second = target_ordinal.ordinal_for(self.state, "owner/repo#12")
        other = target_ordinal.ordinal_for(self.state, "owner/repo#13")
        self.assertEqual(first, second)
        self.assertNotEqual(first, other)
        self.assertGreaterEqual(first, 1)

    def test_cli_refuses_non_private_directory(self):
        if os.name == "nt":
            self.skipTest("unix private-directory predicate")
        public = Path(self.tmp.name) / "public"
        public.mkdir(mode=0o777)
        os.chmod(public, 0o777)
        result = subprocess.run(
            [sys.executable, str(TARGET), "--state-dir", str(public), "--key", "k"],
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 3)
        self.assertEqual(result.stdout, "")

    def test_cli_prints_ordinal(self):
        result = subprocess.run(
            [sys.executable, str(TARGET), "--state-dir", str(self.state), "--key", "owner/repo#7"],
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertRegex(result.stdout.strip(), r"^[1-9][0-9]*$")


class MeasureAppend(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name) / "measurements"
        self.dir.mkdir(mode=0o700)

    def test_append_writes_daily_line(self):
        record = '{"schema":6,"utc":"2026-10-12T00:00:00Z","measurement":"read_observation"}'
        self.assertTrue(measure_append.append_record(self.dir, record))
        files = list(self.dir.glob("????-??-??.jsonl"))
        self.assertEqual(len(files), 1)
        self.assertEqual(files[0].read_text(encoding="utf-8").strip(), record)

    def test_append_rejects_embedded_newline(self):
        self.assertFalse(measure_append.append_record(self.dir, "a\nb"))


class ReportCounters(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name) / "measurements"
        self.dir.mkdir(mode=0o700)

    def write(self, row):
        with (self.dir / "2026-10-12.jsonl").open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(row, separators=(",", ":")) + "\n")

    def run_report(self):
        result = subprocess.run(
            [sys.executable, str(REPORT), str(self.dir)],
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def read_row(self, source, ordinal):
        return {"schema": 6, "utc": "2026-10-12T00:00:00Z", "measurement": "read_observation",
                "caller": "ai-pr-wait", "workflow": "pr_wait", "target_ordinal": ordinal,
                "source": source, "cache_hit": source == "cache",
                "saved_upstream_read": source == "cache"}

    def write_row(self, action, relation, ordinal=1):
        return {"schema": 6, "utc": "2026-10-12T00:00:00Z", "measurement": "write_observation",
                "caller": "ai-blocker-watch", "workflow": "blocker_watch_tick",
                "target_ordinal": ordinal, "action": action, "content_relation": relation,
                "duplicate_unchanged_write": action == "written" and relation == "unchanged"}

    def test_replay_denominator_and_reduction(self):
        # target 1: first upstream, then two cache replays
        self.write(self.read_row("upstream", 1))
        self.write(self.read_row("cache", 1))
        self.write(self.read_row("cache", 1))
        # target 2: first touch only
        self.write(self.read_row("upstream", 2))
        summary = self.run_report()["section13_item2_redundant_reads"]
        self.assertEqual(summary["read_observations"], 4)
        self.assertEqual(summary["unique_correlated_targets"], 2)
        self.assertEqual(summary["first_touch_reads"], 2)
        self.assertEqual(summary["same_target_replay_reads"], 2)
        self.assertEqual(summary["replay_served_from_cache"], 2)
        self.assertEqual(summary["replay_served_upstream"], 0)
        self.assertEqual(summary["replay_upstream_reduction_rate"], 1.0)

    def test_zero_replay_is_unknown_not_zero(self):
        self.write(self.read_row("upstream", 1))
        summary = self.run_report()["section13_item2_redundant_reads"]
        self.assertEqual(summary["same_target_replay_reads"], 0)
        self.assertIsNone(summary["replay_upstream_reduction_rate"])
        self.assertIn("denominator", summary["note"])

    def test_duplicate_unchanged_write_counted(self):
        self.write(self.write_row("written", "new"))
        self.write(self.write_row("skipped", "unchanged"))
        self.write(self.write_row("written", "unchanged"))
        summary = self.run_report()["section13_item2_duplicate_writes"]
        self.assertEqual(summary["write_observations"], 3)
        self.assertEqual(summary["written_new"], 1)
        self.assertEqual(summary["skipped_unchanged"], 1)
        self.assertEqual(summary["duplicate_unchanged_writes"], 1)

    def test_invalid_read_observation_rejected(self):
        bad = self.read_row("cache", 1)
        bad["cache_hit"] = False
        self.write(bad)
        result = subprocess.run(
            [sys.executable, str(REPORT), str(self.dir)],
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)


class SingleFlightEmits(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.state = self.base / "gh-state"
        (self.state / "measurements").mkdir(parents=True, mode=0o700)
        self.count = self.base / "calls"
        self.fake = self.base / "fake.py"
        self.fake.write_text(
            """import json, os
with open(os.environ['COUNT'], 'a') as f: f.write('x\\n')
pr = {'state': 'OPEN', 'headRefOid': 'h1', 'isInMergeQueue': False, 'mergeCommit': None,
      'commits': {'nodes': [{'commit': {'statusCheckRollup': {
      'state': 'PENDING', 'contexts': {'totalCount': 0,
                   'pageInfo': {'hasPreviousPage': False},
                   'nodes': []}}}}]}}
print(json.dumps({'data': {'repository': {'pullRequest': pr}}}))
"""
        )
        self.env = dict(os.environ, COUNT=str(self.count),
                        AI_GH_STATE_DIR=str(self.state),
                        AI_GH_CALLER="ai-pr-wait")

    def call(self, suffix):
        return subprocess.Popen(
            [sys.executable, str(SINGLE), "--state-dir", str(self.base / "snap"),
             "--key", "same-target", "--expected-head", "h1", "--ttl", "10",
             "--wait-seconds", "4", "--age-file", str(self.base / (suffix + ".age")),
             "--source-file", str(self.base / (suffix + ".source")),
             "--", sys.executable, str(self.fake)],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=self.env)

    def _rows(self):
        rows = []
        for path in (self.state / "measurements").glob("*.jsonl"):
            for line in path.read_text().splitlines():
                rows.append(json.loads(line))
        return rows

    def test_cache_hit_emits_saved_read_and_upstream_emits_read(self):
        first = self.call("a")
        out, err = first.communicate(timeout=8)
        self.assertEqual(first.returncode, 0, err)
        self.assertEqual((self.base / "a.source").read_text(), "upstream")
        second = self.call("b")
        out, err = second.communicate(timeout=8)
        self.assertEqual(second.returncode, 0, err)
        self.assertEqual((self.base / "b.source").read_text(), "cache")
        rows = self._rows()
        reads = [r for r in rows if r.get("measurement") == "read_observation"]
        writes = [r for r in rows if r.get("measurement") == "write_observation"]
        self.assertEqual(len(reads), 2, rows)
        sources = sorted(r["source"] for r in reads)
        self.assertEqual(sources, ["cache", "upstream"])
        cache = next(r for r in reads if r["source"] == "cache")
        self.assertTrue(cache["cache_hit"])
        self.assertTrue(cache["saved_upstream_read"])
        self.assertEqual(len(writes), 1)
        self.assertTrue(writes[0]["content_relation"] == "new")
        self.assertTrue(writes[0]["action"] == "written")
        self.assertFalse(writes[0]["duplicate_unchanged_write"])
        self.assertIsInstance(reads[0]["target_ordinal"], int)

    def test_identical_rewrite_is_skipped_not_written_unchanged(self):
        # Force a second upstream refresh of the identical snapshot.
        first = self.call("a")
        first.communicate(timeout=8)
        argv = [sys.executable, str(SINGLE), "--state-dir", str(self.base / "snap"),
                "--key", "same-target", "--expected-head", "h1", "--ttl", "10",
                "--wait-seconds", "4", "--age-file", str(self.base / "c.age"),
                "--source-file", str(self.base / "c.source"),
                "--force-refresh", "--", sys.executable, str(self.fake)]
        second = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=self.env)
        out, err = second.communicate(timeout=8)
        self.assertEqual(second.returncode, 0, err)
        self.assertEqual((self.base / "c.source").read_text(), "upstream")
        writes = [r for r in self._rows() if r.get("measurement") == "write_observation"]
        self.assertEqual(len(writes), 2, writes)
        self.assertEqual(sorted(w["action"] for w in writes), ["skipped", "written"])
        skipped = next(w for w in writes if w["action"] == "skipped")
        self.assertEqual(skipped["content_relation"], "unchanged")
        self.assertFalse(skipped["duplicate_unchanged_write"])


if __name__ == "__main__":
    unittest.main()
