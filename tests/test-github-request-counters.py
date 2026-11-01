#!/usr/bin/env python3
"""Offline counters for #658 section 13 item 2: redundant reads and writes."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
TARGET = ROOT / "tools/github-requests/target_ordinal.py"
REPORT = ROOT / "tools/github-requests/report.py"
SINGLE = ROOT / "tools/github-requests/pr_status_singleflight.py"
sys.path.insert(0, str(ROOT / "tools/github-requests"))
import measure_append  # noqa: E402
import target_ordinal  # noqa: E402
import pr_status_singleflight as single  # noqa: E402
import report as report_module  # noqa: E402


class ProspectiveReadIntervals(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(); self.addCleanup(self.temporary.cleanup)
        self.state = Path(self.temporary.name) / "state"; self.state.mkdir(mode=0o700)
        self.environment = mock.patch.dict(os.environ, {"AI_GH_STATE_DIR": str(self.state),
                                  "AI_GH_WORKFLOW_ID": "c" * 32, "AI_GH_CALLER": "ai-pr-wait"})
        self.environment.start(); self.addCleanup(self.environment.stop)

    def body(self, head):
        return json.dumps({"data": {"repository": {"pullRequest": {
            "state": "OPEN", "headRefOid": head, "isInMergeQueue": False,
            "commits": {"nodes": [{"commit": {"oid": head, "statusCheckRollup": {
                "state": "SUCCESS", "contexts": {"nodes": [], "totalCount": 0,
                    "pageInfo": {"hasPreviousPage": False}}}}}]}}}}}).encode()

    def record(self, key="private-context private/repo 77", head="a" * 40,
               actual=None, start=1000, finish=1100, force=False, correlation=None, scope=None):
        rows = []
        if correlation is not None: os.environ["AI_GH_WORKFLOW_ID"] = correlation
        arrival = (start * 1000000, start, start * 1000000)
        end = (finish * 1000000, finish, finish * 1000000)
        with mock.patch.object(single, "read_clock", side_effect=[arrival, end]), \
             mock.patch.object(single, "_emit_record", side_effect=rows.append):
            interval = single.begin_read(key, head, 10, force)
            single.bind_read_scope(interval, scope or self.state)
            single.emit_read_observation(key, "upstream", interval=interval, raw=self.body(actual or head))
        self.assertEqual(len(rows), 1)
        self.assertTrue(report_module.valid_read_interval(rows[0]))
        return rows[0]

    def test_parent_id_and_actual_bracketed_interval_without_raw_identity(self):
        row = self.record()
        self.assertEqual(row["workflow_id"], "c" * 32)
        self.assertEqual(row["workflow_correlation"], "workflow")
        self.assertLessEqual(row["elapsed_monotonic_ms"][0], 100)
        self.assertGreaterEqual(row["elapsed_monotonic_ms"][1], 100)
        self.assertGreaterEqual(row["clock_resolution_ms"], 1)
        self.assertEqual(row["clock_state"], "local_unqualified")
        self.assertTrue(row["head_matches"])
        self.assertNotIn("private/repo", json.dumps(row))
        self.assertNotIn("a" * 40, json.dumps(row))

    def test_generation_changes_with_head_or_context_and_mutations_are_not_eligible(self):
        first = self.record()
        same = self.record(start=1050, finish=1200, correlation="d" * 32)
        head_change = self.record(head="b" * 40, correlation="e" * 32)
        context_change = self.record(key="other-private-context private/repo 77", correlation="f" * 32)
        self.assertEqual(first["generation_ordinal"], same["generation_ordinal"])
        self.assertNotEqual(first["generation_ordinal"], head_change["generation_ordinal"])
        self.assertNotEqual(first["generation_ordinal"], context_change["generation_ordinal"])
        other_scope = self.state / "other-cache"; other_scope.mkdir(mode=0o700)
        scoped = self.record(scope=other_scope)
        self.assertNotEqual(first["generation_ordinal"], scoped["generation_ordinal"])
        changed = self.record(actual="b" * 40, start=1300, finish=1400, correlation="e" * 32)
        forced = self.record(force=True, start=1500, finish=1600, correlation="f" * 32)
        metrics = report_module.summarize_read_intervals([first, same, changed, forced], {})
        self.assertEqual(metrics["conditional_overlap_candidates"], 1)
        self.assertTrue(metrics["qualification"].startswith("unknown"))

    def test_sequential_ttl_vs_overlap_vs_unknown_head(self):
        first = self.record(start=1000, finish=1100)
        later = self.record(start=1200, finish=1300, correlation="d" * 32)
        expired = self.record(start=12000, finish=12100, correlation="e" * 32)
        metrics = report_module.summarize_read_intervals([first, later, expired], {})
        self.assertEqual(metrics["conditional_overlap_candidates"], 0)
        self.assertEqual(metrics["conditional_ttl_candidates"], 1)
        unknown = self.record(head="any")
        self.assertFalse(unknown["head_known"])
        self.assertIsNone(unknown["generation_ordinal"])
        self.assertIsNone(unknown["head_matches"])

    def test_bad_parent_id_is_not_linked_and_wall_jump_is_not_qualified(self):
        with mock.patch.dict(os.environ, {"AI_GH_WORKFLOW_ID": "raw-private-ID", "PR_WAIT_RECEIPT_ID": ""}):
            first = self.record(); second = self.record()
        self.assertEqual(first["workflow_correlation"], "unknown")
        self.assertNotEqual(first["workflow_id"], second["workflow_id"])
        rows = []
        with mock.patch.object(single, "read_clock", side_effect=[(0, 1000, 0), (100000000, 9000, 100000000)]), \
             mock.patch.object(single, "_emit_record", side_effect=rows.append):
            interval = single.begin_read("k", "a" * 40, 10, False)
            single.emit_read_observation("k", "upstream", interval=interval, raw=self.body("a" * 40))
        self.assertEqual(rows[0]["clock_state"], "jump")
        self.assertTrue(report_module.valid_read_interval(rows[0]))
        self.assertEqual(report_module.summarize_read_intervals(rows, {})["conditional_overlap_candidates"], 0)

    def test_strict_variant_preserves_legacy_and_missing_clock_stays_unknown(self):
        row = self.record()
        for field, value in (("arrival_utc_ms", "private-time"), ("workflow_id", "target"),
                             ("head_known", 1), ("elapsed_monotonic_ms", [20, 10]), ("ttl_seconds", True)):
            bad = dict(row, **{field: value})
            self.assertFalse(report_module.valid_read_interval(bad))
        legacy = {name: value for name, value in row.items() if name in report_module.READ_OBSERVATION_KEYS}
        self.assertEqual(report_module.summarize_read_intervals([legacy], {})["legacy_records"], 1)
        rows = []
        with mock.patch.object(single, "read_clock", return_value=None), \
             mock.patch.object(single, "_emit_record", side_effect=rows.append):
            interval = single.begin_read("k", "a" * 40, 10, False)
            single.emit_read_observation("k", "upstream", interval=interval, raw=self.body("a" * 40))
        self.assertEqual(rows[0]["clock_state"], "unavailable")
        self.assertIsNone(rows[0]["elapsed_monotonic_ms"])
        self.assertTrue(report_module.valid_read_interval(rows[0]))

    def test_output_failure_emits_no_successful_read_and_fallback_id_is_explicit(self):
        class Failing:
            def write(self, data): raise BrokenPipeError("fixture output closed")
        from types import SimpleNamespace
        import io
        rows = []
        result = subprocess.CompletedProcess(["fixture"], 0, self.body("a" * 40), b"")
        with mock.patch.object(single.subprocess, "run", return_value=result), \
             mock.patch.object(single, "sys", SimpleNamespace(stdout=SimpleNamespace(buffer=Failing()),
                                                             stderr=SimpleNamespace(buffer=io.BytesIO()))), \
             mock.patch.object(single, "_emit_record", side_effect=rows.append):
            with self.assertRaises(BrokenPipeError):
                single.run(["fixture"], None, self.state / "age", self.state / "source", args_key="k",
                           interval=single.begin_read("k", "a" * 40, 10, False))
        self.assertEqual(rows, [])
        with mock.patch.dict(os.environ, {"AI_GH_WORKFLOW_ID": "invalid", "PR_WAIT_RECEIPT_ID": "e" * 32}):
            interval = single.begin_read("k", "a" * 40, 10, False)
        self.assertEqual(interval["workflow_id"], "e" * 32)
        self.assertEqual(interval["workflow_correlation"], "workflow")


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

    def test_concurrent_distinct_keys_get_distinct_ordinals(self):
        import concurrent.futures
        keys = [f"owner/repo#{n}" for n in range(20)]
        with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
            ordinals = list(pool.map(lambda k: target_ordinal.ordinal_for(self.state, k), keys))
        self.assertEqual(len(set(ordinals)), len(keys), ordinals)
        # Stable on re-read
        self.assertEqual(target_ordinal.ordinal_for(self.state, keys[0]), ordinals[0])

    def test_cross_process_lock_prevents_duplicate_ordinals(self):
        # Two real processes must not share one ordinal for distinct keys.
        script = (
            "import sys; sys.path.insert(0, sys.argv[1]);"
            "import target_ordinal; from pathlib import Path;"
            "print(target_ordinal.ordinal_for(Path(sys.argv[2]), sys.argv[3]))"
        )
        helper = str(ROOT / "tools/github-requests")
        procs = [
            subprocess.Popen(
                [sys.executable, "-c", script, helper, str(self.state), f"owner/repo#{n}"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            for n in range(8)
        ]
        out = [p.communicate(timeout=30)[0].strip() for p in procs]
        for p in procs:
            self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(len(set(out)), 8, out)
        self.assertTrue(all(o.isdigit() for o in out), out)


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

    def read_row(self, source, ordinal, workflow="pr_wait", caller="ai-pr-wait"):
        return {"schema": 6, "utc": "2026-10-12T00:00:00Z", "measurement": "read_observation",
                "caller": caller, "workflow": workflow, "target_ordinal": ordinal,
                "source": source, "cache_hit": source == "cache",
                "saved_upstream_read": source == "cache"}

    def write_row(self, action, relation, ordinal=1, workflow="blocker_watch_tick",
                  caller="ai-blocker-watch"):
        return {"schema": 6, "utc": "2026-10-12T00:00:00Z", "measurement": "write_observation",
                "caller": caller, "workflow": workflow, "target_ordinal": ordinal,
                "action": action, "content_relation": relation,
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

    def test_merge_group_evidence_observations_accepted(self):
        # telemetry.sh allows merge_group_evidence; report.py must not crash.
        self.write(self.read_row("cache", 1, workflow="merge_group_evidence",
                                 caller="ai-merge-group-evidence"))
        self.write(self.write_row("skipped", "unchanged", workflow="merge_group_evidence",
                                  caller="ai-merge-group-evidence"))
        summary = self.run_report()
        self.assertEqual(summary["section13_item2_redundant_reads"]["read_observations"], 1)
        self.assertEqual(summary["section13_item2_duplicate_writes"]["write_observations"], 1)


class SingleFlightEmits(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.state = self.base / "gh-state"
        # mkdir(parents=True) gives the parent umask permissions; the ordinal
        # store refuses a group-writable state dir, so create both private.
        self.state.mkdir(mode=0o700)
        (self.state / "measurements").mkdir(mode=0o700)
        self.count = self.base / "calls"
        self.fake = self.base / "fake.py"
        self.fake.write_text(
            """import json, os, time
with open(os.environ['COUNT'], 'a') as f: f.write('x\\n')
time.sleep(float(os.environ.get('DELAY', '0')))
mode = os.environ.get('MODE', 'open')
pr = {'state': 'OPEN', 'headRefOid': 'h1', 'isInMergeQueue': False, 'mergeCommit': None,
      'commits': {'nodes': [{'commit': {'statusCheckRollup': {
      'state': 'FAILURE' if mode == 'failed' else 'PENDING',
      'contexts': {'totalCount': 1 if mode == 'failed' else 0,
                   'pageInfo': {'hasPreviousPage': False},
                   'nodes': ([{'name': 'test', 'conclusion': 'FAILURE'}]
                             if mode == 'failed' else [])}}}}]}}
print(json.dumps({'data': {'repository': {'pullRequest': pr}}}))
"""
        )
        self.env = dict(os.environ, COUNT=str(self.count),
                        AI_GH_STATE_DIR=str(self.state),
                        AI_GH_CALLER="ai-pr-wait")

    def call(self, suffix, force=False, delay="0", mode="open", wait_seconds="4"):
        argv = [sys.executable, str(SINGLE), "--state-dir", str(self.base / "snap"),
                "--key", "same-target", "--expected-head", "h1", "--ttl", "10",
                "--wait-seconds", wait_seconds, "--age-file", str(self.base / (suffix + ".age")),
                "--source-file", str(self.base / (suffix + ".source"))]
        if force:
            argv.append("--force-refresh")
        argv.extend(["--", sys.executable, str(self.fake)])
        env = dict(self.env, DELAY=delay, MODE=mode)
        return subprocess.Popen(
            argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)

    def _rows(self):
        rows = []
        for path in (self.state / "measurements").glob("*.jsonl"):
            for line in path.read_text().splitlines():
                rows.append(json.loads(line))
        return rows

    def calls(self):
        return len(self.count.read_text().splitlines()) if self.count.exists() else 0

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

    def test_identical_skip_refreshes_mtime_for_in_flight_coalescing(self):
        # A failing snapshot is not TTL-cacheable, so waiters only share via
        # the same-flight mtime window. Skipping the identical content rewrite
        # must still bump mtime, or a waiter that joined during the refresh
        # re-hits upstream instead of sharing the completed read.
        first = self.call("a", mode="failed")
        out, err = first.communicate(timeout=8)
        self.assertEqual(first.returncode, 0, err)
        cache = next((self.base / "snap").glob("*.json"))
        before = cache.stat().st_mtime_ns
        owner = self.call("owner", force=True, delay="0.6", mode="failed", wait_seconds="8")
        time.sleep(0.2)
        joiner = self.call("joiner", mode="failed", wait_seconds="8")
        out, err = owner.communicate(timeout=10)
        self.assertEqual(owner.returncode, 0, err)
        out, err = joiner.communicate(timeout=10)
        self.assertEqual(joiner.returncode, 0, err)
        self.assertEqual((self.base / "owner.source").read_text(), "upstream")
        self.assertEqual((self.base / "joiner.source").read_text(), "cache")
        self.assertEqual(self.calls(), 2)
        after = cache.stat().st_mtime_ns
        self.assertGreater(after, before, "identical skip must refresh cache mtime")
        writes = [r for r in self._rows() if r.get("measurement") == "write_observation"]
        self.assertEqual(sorted(w["action"] for w in writes), ["skipped", "written"])
        self.assertFalse(any(w["duplicate_unchanged_write"] for w in writes))


if __name__ == "__main__":
    unittest.main()
