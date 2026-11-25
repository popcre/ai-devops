"""Named tests for plan_github-continuity-pilot.md (section 9).

Portable tests run everywhere. Tests that drive the outage drill need Linux
(fcntl, bash, git http-backend) and run the real toolkit entry points against
the loopback fixture with a private HOME; the networkless, strace-audited
version of the same drill is run_drill.sh. A fixture pass alone never
satisfies a live gate.
"""

import json
import os
import shutil
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)

import sample  # noqa: E402
from timing_cases import TimingTests  # noqa: E402,F401  (test_timing_sample, test_paired_tail_gate)

try:
    import fcntl  # noqa: F401
    import outage
    LINUX = sys.platform.startswith("linux") and shutil.which("git") and shutil.which("jq")
except ImportError:
    outage = None
    LINUX = False


def _free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _window(consumed=100, bucket="core", principals=(("m1", "p1"),)):
    return {"bucket": bucket, "reset": 7200, "start": 3600, "limit": 5000,
            "consumed": consumed, "principals": list(principals)}


class FixtureArgumentTests(unittest.TestCase):
    def test_fields_headers_and_method(self):
        from fixtures import fake_gh
        with mock.patch.object(fake_gh, "request", return_value=(200, {}, b"")) as request:
            fake_gh.main(["api", "-H", "Accept: fixture", "pulls", "-f", "head=01",
                          "-F", "draft=true", "-X", "PATCH"])
            request.assert_called_once_with("PATCH", "pulls", {"head": "01", "draft": True},
                                            {"Accept": "fixture"})
            fake_gh.main(["api", "pulls?state=open", "-X", "GET", "-f", "head=a b"])
            request.assert_called_with("GET", "pulls?state=open&head=a+b", None, {})
            fake_gh.main(["api", "pulls", "--raw-field", "head=a"])
            request.assert_called_with("POST", "pulls", {"head": "a"}, {})


@unittest.skipUnless(outage, "requires fcntl")
class AuditPathTests(unittest.TestCase):
    def test_relative_chdir_and_resolved_write(self):
        with tempfile.NamedTemporaryFile(mode="w") as trace:
            trace.write('10 chdir("../.." <unfinished ...>\n'
                        '10 <... chdir resumed>) = 0\n'
                        '10 mkdir("outside", 0700) = 0\n'
                        '10 openat(AT_FDCWD</tmp>, "alias", O_WRONLY) = 4</outside/file>\n')
            trace.flush()
            report = outage.audit(trace.name, "/tmp/drill", ["/tmp"])
        self.assertEqual(report["writes_outside_scratch"], ["/outside", "/outside/file"])


class QuotaTests(unittest.TestCase):
    def test_quota_attribution(self):
        recs = [
            # verified GraphQL points, status and other
            {"t": 3700, "principal": "p1", "measurement": "observed_graphql_cost",
             "graphql_points": 30, "graphql_reset_at": "1970-01-01T02:00:00Z", "operation": "graphql.pr_status"},
            {"t": 3800, "principal": "p1", "measurement": "observed_graphql_cost",
             "graphql_points": 50, "graphql_reset_at": "1970-01-01T02:00:00Z", "operation": "api.graphql"},
            # wrong reset: not verified for this window
            {"t": 3900, "principal": "p1", "measurement": "observed_graphql_cost",
             "graphql_points": 999, "graphql_reset_at": "1970-01-01T05:00:00Z", "operation": "graphql.pr_status"},
            # opaque counts: never verified cost; unknown caller and mixed bucket
            {"t": 4000, "principal": "p1", "measurement": "opaque_cli_estimate",
             "operation": "pr.view", "bucket": "graphql", "cli_executions": 4},
            {"t": 4000, "principal": "p1", "measurement": "opaque_cli_estimate",
             "operation": "pr.view", "bucket": "core", "cli_executions": 9},
            {"t": 4100, "principal": "other", "measurement": "opaque_cli_estimate", "operation": "x"},
        ]
        got = sample.attribute(_window(100, "graphql"), recs, [])
        self.assertEqual((got["T"], got["S_verified"], got["O_verified"], got["U_unattributed"]), (100, 30, 50, 20))
        self.assertTrue(got["verdict"].startswith("run listener"))
        self.assertEqual(got["status_read_invocations"], 4)  # core-bucket record excluded
        self.assertEqual(got["invocations_other_or_unknown_identity"], 1)
        # core bucket has no verified cost: all spend is unknown -> inconclusive
        core = sample.attribute(_window(4165), recs, [])
        self.assertEqual((core["S_verified"], core["U_unattributed"]), (0, 4165))
        self.assertTrue(core["verdict"].startswith("inconclusive"))
        # verified other spend leaving (S+U)/T < 20% rules the listener out
        ruled = sample.attribute(_window(50, "graphql"), recs[1:2], [])
        self.assertTrue(ruled["verdict"].startswith("rule out"))

    def test_partial_window_and_budget(self):
        def snap(t, remaining, reset=7200):
            return {"machine": "m1", "principal": "p1", "t": t, "bucket": "core",
                    "remaining": remaining, "limit": 5000, "reset": reset}
        full = [snap(3600 + i * 300, 5000 - i * 10) for i in range(12)]
        late = [snap(3600 + 900 + i * 300, 5000 - i) for i in range(9)]
        rose = [snap(3600 + i * 300, 4000 + (500 if i == 5 else 0)) for i in range(12)]
        self.assertTrue(sample.windows(full)[0]["complete"])
        self.assertIn("late_first_snapshot", sample.windows(late)[0]["incomplete_reasons"])
        self.assertFalse(sample.windows(late)[0]["complete"])
        self.assertIn("remaining_rose", sample.windows(rose)[0]["incomplete_reasons"])
        ok = sample.check_budget([{"alloc": "discovery", "cost": 3}, {"alloc": "drafts", "cost": 6}])
        self.assertTrue(ok["ok"])
        over = sample.check_budget([{"alloc": "drafts", "cost": 13}, {"alloc": "mystery", "cost": 1}])
        self.assertEqual(over["over"], {"drafts": 1})
        self.assertEqual(over["unknown_allocations"], ["mystery"])
        self.assertFalse(over["ok"])

    def test_exchange_count(self):
        debug = "\n".join([
            "* Request at 2026-11-25 15:46:41",
            "* Request to https://api.github.com/repos/o/r/pulls?page=1",
            "> Authorization: token ████",
            "< HTTP/2.0 301 Moved Permanently",
            "* Request took 10ms",
            "* Request to https://api.github.com/repositories/1/pulls?page=1",  # redirect
            "< HTTP/2.0 502 Bad Gateway",
            "* Request to https://api.github.com/repositories/1/pulls?page=1",  # retry
            "* Request to https://api.github.com/repositories/1/pulls?page=2",  # page
            "* Request took 5ms",
        ])
        got = sample.count_exchanges(debug)
        self.assertEqual(len(got), 4)
        self.assertEqual(got[0], "repos/o/r/pulls")
        self.assertFalse(any("token" in g or "?" in g for g in got))


class EventTests(unittest.TestCase):
    def test_reject_invalid_event(self):
        self.skipTest("listener trial not run: verified status reads were below the 20% gate "
                      "(docs/verification/github-pilot.md); no receiver exists to test")


@unittest.skipUnless(LINUX, "outage drill needs Linux, git and jq")
class OutageDrillTests(unittest.TestCase):
    """One real drill (without the network namespace) shared by the named cases."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.mkdtemp(prefix="pilot-test-")
        cls.old_home = os.environ.get("HOME")
        os.environ["HOME"] = os.path.join(cls.tmp, "home")
        os.makedirs(os.environ["HOME"])
        fake = os.path.join(cls.tmp, "fake_gh")
        shutil.copy(os.path.join(HERE, "fixtures", "fake_gh.py"), fake)
        os.chmod(fake, 0o755)
        cls.drill = outage.Drill(os.path.join(cls.tmp, "drill"), ROOT, fake, _free_port())
        try:
            cls.result = cls.drill.run()
        finally:
            cls.drill.stop()

    @classmethod
    def tearDownClass(cls):
        os.environ["HOME"] = cls.old_home
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def entries(self, mode):
        return [r for r in self.result["entry_points"] if r["mode"] == mode]

    def test_real_offline_startup(self):
        # Safety: never a push, never an overridden collision; refusals fail closed.
        for mode in ("refused", "503", "delay"):
            rows = {(r["workspace"], r["entry"]): r for r in self.entries(mode)}
            for ws in ("a", "b"):
                self.assertEqual(rows[(ws, "task_gates")]["exit"], 0)
                self.assertFalse(rows[(ws, "memory_sync")]["pushed"], mode)
                if mode != "delay":
                    self.assertEqual(rows[(ws, "collision_check")]["exit"], 4, mode)
                    self.assertNotEqual(rows[(ws, "memory_sync")]["exit"], 0, mode)
                    self.assertTrue(rows[(ws, "collision_check")]["within_target"], mode)
        for ws in ("a", "b"):
            self.assertEqual(self.result["checks"]["offline_work_" + ws]["test_exit"], 0)

    def test_fixture_isolation(self):
        env = self.drill.entry_env("a", "probe")
        self.assertTrue(env["AI_GH_REAL_GH"].startswith(self.tmp))
        self.assertNotIn("GH_TOKEN", env)
        self.assertNotIn("GITHUB_TOKEN", env)
        self.assertTrue(env["HOME"].startswith(self.tmp))
        trace = os.path.join(self.tmp, "trace")
        with open(trace, "w") as handle:
            handle.write('10 connect(3<socket>, {sa_family=AF_INET, sin_port=htons(443), '
                         'sin_addr=inet_addr("140.82.112.6")}, 16) = 0\n')
            handle.write('10 openat(AT_FDCWD</root>, "x", O_WRONLY|O_CREAT, 0644) = 4</root/x>\n')
            handle.write('10 connect(3<socket>, {sa_family=AF_INET, sin_port=htons(18080), '
                         'sin_addr=inet_addr("127.0.0.1")}, 16) = 0\n')
        got = outage.audit(trace, "/tmp/drill", ["/tmp"])
        self.assertEqual(got["non_local_destinations"], ["140.82.112.6"])
        self.assertEqual(got["writes_outside_scratch"], ["/root/x"])

    def test_journal_recovery(self):
        kinds = {r["crash"]: r for r in self.result["journal"]}
        self.assertEqual(kinds["mid_write"]["record"], "previous")
        self.assertEqual(kinds["before_replace"]["record"], "previous")
        self.assertEqual(kinds["after_replace"]["record"], "new")
        for row in kinds.values():
            self.assertTrue(row["complete"] and row["commit_resolves"])
        checks = self.result["checks"]
        self.assertTrue(checks["recoverable_after_restart_a"])
        self.assertTrue(checks["recoverable_after_restart_b"])
        missing = os.path.join(self.tmp, "missing.json")
        outage.journal_write(missing, {"items": {"x": {"state": "pending", "commit": "0" * 40,
                                                       "base": "main", "title": "t"}}})
        locks = os.path.join(self.tmp, "locks-missing")
        self.assertEqual(outage.submit(missing, self.drill.ws["a"], "x", self.drill.api, locks),
                         "blocked_missing_commit")

    def test_retry_one_pr(self):
        checks = self.result["checks"]
        self.assertEqual(checks["prs_per_head"], {"pilot/a": 1, "pilot/b": 1})
        self.assertEqual(checks["force_pushes"], 0)
        self.assertTrue(checks["one_pr_per_submission"])
        steps = [r["state"] for r in self.result["worker"] if r["workspace"] == "a"]
        self.assertIn("create_uncertain", steps)  # lost response was simulated
        self.assertIn("crashed", steps)  # interrupted before marking delivered

    def test_conflict_preserves_work(self):
        checks = self.result["checks"]
        self.assertTrue(checks["conflict_stays_pending"])
        self.assertTrue(checks["dependency_order"])
        self.assertTrue(checks["both_changes_preserved"])
        self.assertEqual(checks["reconcile_a"]["test_exit"], 0)
        self.assertEqual(checks["reconcile_b"]["test_exit"], 0)

    def test_reconcile_current_head(self):
        checks = self.result["checks"]
        self.assertEqual(checks["journal_states"]["a"], {"state": "delivered", "outcome": "already_merged"})
        self.assertTrue(checks["reconcile_a"]["rebased"])
        self.assertTrue(checks["reconcile_b"]["on_top_of_a"])

    def test_unknown_until_verified(self):
        offline = [r for r in self.result["worker"]
                   if r["step"].startswith("outage_") or r["step"] == "restarted_offline"]
        self.assertEqual(len(offline), 8)
        for row in offline:
            self.assertEqual(row["state"], "deferred", row)
            self.assertLessEqual(row["seconds"], outage.TARGET + 1, row)
        for mode in ("refused", "503"):
            for row in self.entries(mode):
                if row["entry"] == "workspace_status":
                    self.assertTrue(row["says_unknown"], row)


if __name__ == "__main__":
    unittest.main()
