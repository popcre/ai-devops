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
        self.fake.write_text('#!/usr/bin/env bash\nprintf "%s\\n" "$*"\n')
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

    def start(self, name, **settings):
        self.bash = os.environ.get("AI_TEST_BASH") or shutil.which("bash")
        pidfile = self.base / f"pid-{len(self.children)}"
        p = subprocess.Popen([self.bash, "-c", 'printf "%s\\n" "$$" > "$1"; shift; exec "$BASH" "$@"', "--",
                              pidfile.as_posix(), (ROOT / "bin/ai-gh").as_posix(), "api", name],
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

    def finish(self, p, expected=0):
        out, err = p.communicate(timeout=20)
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
