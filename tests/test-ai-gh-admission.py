#!/usr/bin/env python3
"""Real subprocess admission tests; fake gh never accesses the network."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AdmissionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.state = self.base / "state"
        self.state.mkdir()
        self.fake = self.base / "fake-gh"
        self.fake.write_text('''#!/usr/bin/env bash
[ -z "${FAKE_CALL_LOG:-}" ] || printf '%s\\n' "$*" >> "$FAKE_CALL_LOG"
if [ "${FAKE_IGNORE_TERM:-}" = 1 ]; then trap '' TERM; while :; do sleep 1; done; fi
[ -z "${FAKE_EXIT:-}" ] || exit "$FAKE_EXIT"
[ -z "${FAKE_DELAY:-}" ] || sleep "$FAKE_DELAY"
if [ "${FAKE_GRAPHQL:-}" = merged ] && [ "$1 $2" = 'api graphql' ]; then
  printf '%s\\n' '{"data":{"repository":{"pullRequest":{"state":"MERGED","isInMergeQueue":false,"mergeCommit":{"oid":"fixture123"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS","contexts":{"nodes":[]}}}}]}}}}}'
else
  printf "%s\\n" "$*"
fi
''')
        self.fake.chmod(0o700)
        self.env = dict(os.environ, AI_GH_STATE_DIR=self.state.as_posix(),
                        AI_GH_REAL_GH=self.fake.as_posix(), AI_GH_QUOTA_PROBE_SECONDS="off",
                        AI_GH_MIN_SPACING_SECONDS="0", AI_GH_RESERVATION_LOG=(self.base / "reservations").as_posix())
        self.children = []
        self.addCleanup(self.stop_children)

    def stop_children(self):
        for p in self.children:
            if p.poll() is None:
                self.signal(p, "TERM")
            try:
                p.communicate(timeout=3)
            except subprocess.TimeoutExpired:
                self.signal(p, "KILL")
                p.communicate()

    def signal(self, p, name):
        # Native Windows TerminateProcess bypasses Bash traps and its process
        # ID is not Git Bash's PID. Ask the same Bash runtime to deliver the
        # signal to the PID recorded by the fixture's exec wrapper.
        if p.pidfile.exists():
            subprocess.run([self.bash, "-c", 'kill -"$1" "$2"', "--", name,
                            p.pidfile.read_text().strip()], stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=3)
        else:
            p.kill()

    def start(self, name, waiter=None, arguments=None, **settings):
        self.bash = os.environ.get("AI_TEST_BASH") or shutil.which("bash")
        pidfile = self.base / f"pid-{len(self.children)}"
        command = [(ROOT / "bin" / (waiter or "ai-gh")).as_posix()]
        command += arguments if arguments is not None else ["api", name]
        p = subprocess.Popen([self.bash, "-c", 'printf "%s\\n" "$$" > "$1"; shift; exec "$BASH" "$@"', "--",
                              pidfile.as_posix(), *command],
                             env=dict(self.env, **settings), stdout=subprocess.PIPE,
                             stderr=subprocess.PIPE, text=True)
        p.pidfile = pidfile
        self.children.append(p)
        return p

    def ticket_count(self):
        return len(list((self.state / "admission.d").glob("[0-9]*")))

    def wait_for(self, predicate):
        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.02)
        self.fail("fixture did not reach expected admission state")

    def hold(self):
        lock = self.state / "lock.d"
        lock.mkdir()
        (lock / "owner").write_text(f"123 {int(time.time())} fixture\n")
        return lock

    def finish(self, p, expected=0, timeout=20):
        out, err = p.communicate(timeout=timeout)
        self.assertEqual(p.returncode, expected, err)
        return out

    def test_old_waiter_precedes_continuing_arrivals(self):
        lock = self.hold()
        old = self.start("old")
        self.wait_for(lambda: self.ticket_count() == 1)
        newcomers = []
        for i in range(4):
            newcomers.append(self.start(f"new-{i}"))
            self.wait_for(lambda: self.ticket_count() == i + 2)
        shutil.rmtree(lock)  # only the fixture-owned mutex
        for i in range(4, 12):
            newcomers.append(self.start(f"new-{i}"))
            time.sleep(0.03)
        self.assertEqual(self.finish(old), "api old\n")
        for p in newcomers:
            self.finish(p)
        rows = (self.base / "reservations").read_text().splitlines()
        self.assertEqual(int(rows[0].split()[2]), int(old.pidfile.read_text()))
        self.assertEqual(len(rows), 13)
        self.assertEqual(self.ticket_count(), 0)

    def test_network_timeout_starts_after_admission(self):
        lock = self.hold()
        p = self.start("after-admission", AI_GH_CALL_TIMEOUT_SECONDS="1")
        self.wait_for(lambda: self.ticket_count() == 1)
        time.sleep(2)
        shutil.rmtree(lock)
        self.assertEqual(self.finish(p), "api after-admission\n")

    def test_network_timeout_preserves_ordinary_and_graphql_exit(self):
        for kind in ("ordinary", "graphql"):
            with self.subTest(kind=kind):
                self.finish(self.start(kind, AI_GH_CALL_TIMEOUT_SECONDS="1", FAKE_DELAY="3"), 124)

    def test_invalid_network_timeout_refuses_before_call(self):
        for value in ("0", "off", "-1"):
            with self.subTest(value=value):
                self.finish(self.start("invalid", AI_GH_CALL_TIMEOUT_SECONDS=value), 2)

    def test_network_timeout_kills_term_ignoring_backend(self):
        for kind in ("ordinary", "graphql"):
            with self.subTest(kind=kind):
                start = time.monotonic()
                self.finish(self.start(kind, AI_GH_CALL_TIMEOUT_SECONDS="1", FAKE_IGNORE_TERM="1"), 124)
                self.assertLess(time.monotonic() - start, 12)

    def test_natural_exit_137_is_not_relabelled_timeout(self):
        for kind in ("ordinary", "graphql"):
            with self.subTest(kind=kind):
                self.finish(self.start(kind, AI_GH_CALL_TIMEOUT_SECONDS="5", FAKE_EXIT="137"), 137)

    def test_generic_waiter_keeps_ticket_past_old_short_default(self):
        self.waiter_after_busy_lock("ai-gh-wait", ["--until-regex", "api observed", "--timeout-minutes", "1", "--", "api", "observed"])

    def test_pr_waiter_keeps_ticket_past_old_short_default(self):
        self.waiter_after_busy_lock("ai-pr-wait", ["1", "--repo", "popcre/ai-devops", "--timeout-minutes", "1", "--api-timeout-seconds", "1"], FAKE_GRAPHQL="merged")

    def waiter_after_busy_lock(self, script, args, **settings):
        lock = self.hold()
        # Exercise the real production default, not the shortened test default.
        settings.update(AI_DEVOPS_TEST_MODE="0", AI_TASK_GATES_MODE="none")
        p = self.start("waiter", waiter=script, arguments=args, **settings)
        self.wait_for(lambda: self.ticket_count() == 1)
        time.sleep(12)  # beyond the previous 10-second admission abandonment
        shutil.rmtree(lock)
        self.finish(p, timeout=45)

    def test_generic_waiter_deadline_does_not_start_late_api_call(self):
        self.hold()
        calls = self.base / "calls"
        p = self.start("deadline", waiter="ai-gh-wait", arguments=["--until-regex", "observed", "--timeout-minutes", "1", "--", "api", "observed"],
                       AI_DEVOPS_TEST_MODE="1", AI_GH_WAIT_TEST_DEADLINE_EPOCH=str(int(time.time()) + 2), FAKE_CALL_LOG=calls.as_posix())
        self.finish(p, 2)
        self.assertFalse(calls.exists())

    def test_explicit_zero_admission_override_is_preserved(self):
        self.hold()
        calls = self.base / "calls"
        p = self.start("override", waiter="ai-gh-wait", arguments=["--until-regex", "observed", "--timeout-minutes", "1", "--", "api", "observed"],
                       AI_GH_NO_WAIT_LOCK_SECONDS="0", FAKE_CALL_LOG=calls.as_posix())
        self.finish(p, 2)
        self.assertFalse(calls.exists())

    def test_cancelled_waiter_removes_only_its_ticket(self):
        lock = self.hold()
        old = self.start("cancel")
        self.wait_for(lambda: self.ticket_count() == 1)
        following = self.start("following")
        self.wait_for(lambda: self.ticket_count() == 2)
        self.signal(old, "TERM")
        old.communicate(timeout=3)
        self.wait_for(lambda: self.ticket_count() == 1)
        self.assertTrue((lock / "owner").is_file())
        shutil.rmtree(lock)
        self.assertEqual(self.finish(following), "api following\n")

    def test_expired_ticket_does_not_remove_live_mutex(self):
        queue = self.state / "admission.d"
        queue.mkdir()
        abandoned = queue / "1000000000000.ABCDEF"
        abandoned.touch()
        os.utime(abandoned, (time.time() - 120, time.time() - 120))
        lock = self.hold()
        p = self.start("no-wait", AI_GH_NO_WAIT="1", AI_GH_NO_WAIT_LOCK_SECONDS="1")
        self.finish(p, 75)
        self.assertFalse(abandoned.exists())
        self.assertEqual((lock / "owner").read_text().split()[-1], "fixture")
        self.assertEqual(self.ticket_count(), 0)

    def test_hard_killed_waiter_expires_without_pid_recovery(self):
        lock = self.hold()
        dead = self.start("killed")
        self.wait_for(lambda: self.ticket_count() == 1)
        self.signal(dead, "KILL")
        dead.communicate(timeout=3)
        tickets = list((self.state / "admission.d").glob("[0-9]*"))
        self.assertEqual(len(tickets), 1)
        os.utime(tickets[0], (time.time() - 120, time.time() - 120))
        shutil.rmtree(lock)
        self.assertEqual(self.finish(self.start("recovered")), "api recovered\n")
        self.assertEqual(self.ticket_count(), 0)

    def test_backward_clock_arrival_is_placed_after_visible_ticket(self):
        lock = self.hold()
        queue = self.state / "admission.d"
        queue.mkdir()
        future = queue / "9999999999990.ABCDEF"
        future.touch()
        p = self.start("clock")
        self.wait_for(lambda: self.ticket_count() == 2)
        names = sorted(x.name for x in queue.glob("[0-9]*"))
        self.assertEqual(names[0], future.name)
        future.unlink()
        shutil.rmtree(lock)
        self.assertEqual(self.finish(p), "api clock\n")

    def test_admission_directory_symlink_refuses_without_touching_target(self):
        target = self.base / "foreign"
        target.mkdir()
        try:
            (self.state / "admission.d").symlink_to(target, target_is_directory=True)
        except OSError:
            self.skipTest("symlink creation unavailable on this Windows account")
        p = self.start("unsafe")
        self.finish(p, 3)
        self.assertEqual(list(target.iterdir()), [])


if __name__ == "__main__":
    unittest.main()
