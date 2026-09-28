#!/usr/bin/env python3
"""Offline multi-process cases for the PR status sharing boundary."""

import json
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "tools/github-requests/pr_status_singleflight.py"
CONTEXT = ROOT / "tools/github-requests/pr-status-context"
WINDOWS_ACL = ROOT / "tools/github-requests/secure-windows-path.ps1"


def secure_windows_directory(path):
    result = subprocess.run(
        ["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
         "-File", str(WINDOWS_ACL), "-Mode", "EnsureCache", "-Path", str(path)],
        capture_output=True, check=False,
    )
    if result.returncode:
        raise AssertionError(result.stderr.decode(errors="replace"))


def bash_path(path):
    if os.name != "nt":
        return str(path)
    return subprocess.check_output(["cygpath", "-u", str(path)], text=True).strip()


class SingleFlight(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=Path.home() if os.name == "nt" else None)
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.count = self.base / "calls"
        self.fake = self.base / "fake.py"
        self.fake.write_text(
            """import json, os, time
with open(os.environ['COUNT'], 'a') as f: f.write('x\\n')
time.sleep(float(os.environ.get('DELAY', '0')))
mode = os.environ.get('MODE', 'open')
pr = {'state': 'MERGED' if mode == 'merged' else 'CLOSED' if mode == 'closed' else 'OPEN',
      'headRefOid': os.environ.get('HEAD', 'h1'),
      'isInMergeQueue': mode == 'queued', 'mergeCommit': None,
      'commits': {'nodes': [{'commit': {'statusCheckRollup': {
      'state': 'FAILURE' if mode == 'failed' else 'PENDING',
      'contexts': {'totalCount': 101 if mode == 'truncated' else 1 if mode in ('failed', 'status_failed') else 0,
                   'pageInfo': {'hasPreviousPage': mode == 'truncated'},
                   'nodes': ([{'name': 'test', 'conclusion': 'FAILURE'}] if mode == 'failed' else
                             [{'context': 'legacy', 'state': 'ERROR'}] if mode == 'status_failed' else [])}}}}]}}
print(json.dumps({'errors': [{'message': 'partial'}]} if mode == 'partial' else
                 {'data': {'repository': {'pullRequest': pr}}}))
"""
        )

    def call(self, key="scope-a", head="h1", mode="open", delay="0", suffix="a",
             force=False, wait_seconds="4"):
        env = dict(os.environ, COUNT=str(self.count), HEAD=head, MODE=mode, DELAY=delay)
        argv = [sys.executable, str(HELPER), "--state-dir", str(self.base / "state"),
                "--key", key, "--expected-head", head, "--ttl", "10",
                "--wait-seconds", wait_seconds, "--age-file", str(self.base / (suffix + ".age")),
                "--source-file", str(self.base / (suffix + ".source")),
                "--", sys.executable, str(self.fake)]
        if force:
            argv.insert(argv.index("--"), "--force-refresh")
        return subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)

    def calls(self):
        return len(self.count.read_text().splitlines()) if self.count.exists() else 0

    def test_two_simultaneous_first_waiters_share_one_read(self):
        first = self.call(key="discovery", head="any", delay="0.3", suffix="a")
        second = self.call(key="discovery", head="any", delay="0.3", suffix="b")
        for process in (first, second):
            out, err = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0, err)
            self.assertEqual(json.loads(out)["data"]["repository"]["pullRequest"]["state"], "OPEN")
        self.assertEqual(self.calls(), 1)
        self.assertEqual(
            sorted([(self.base / (suffix + ".source")).read_text() for suffix in ("a", "b")]),
            ["cache", "upstream"],
        )
        if os.name == "nt":
            secure_windows_directory(self.base / "state")
        else:
            self.assertEqual((self.base / "state").stat().st_mode & 0o077, 0)

    def test_queued_waiters_share_one_fresh_terminal_or_ejection_read(self):
        for mode in ("merged", "closed", "ejected"):
            key = "queued-" + mode
            seed = self.call(key=key, mode="queued", suffix=mode + "-seed")
            seed_out, seed_err = seed.communicate(timeout=6)
            self.assertEqual(seed.returncode, 0, seed_err)
            self.assertTrue(json.loads(seed_out)["data"]["repository"]["pullRequest"]["isInMergeQueue"])
            before = self.calls()
            first = self.call(key=key, mode=mode, delay="0.6", suffix=mode + "-first", force=True)
            started = time.monotonic()
            while self.calls() == before and time.monotonic() - started < 4:
                time.sleep(0.01)
            self.assertEqual(self.calls(), before + 1)
            second = self.call(key=key, mode=mode, suffix=mode + "-second", force=True)
            results = []
            for process in (first, second):
                out, err = process.communicate(timeout=7)
                self.assertEqual(process.returncode, 0, err)
                results.append(json.loads(out)["data"]["repository"]["pullRequest"])
            self.assertEqual(self.calls(), before + 1)
            self.assertEqual(results[0]["state"], results[1]["state"])
            self.assertEqual(results[0]["isInMergeQueue"], results[1]["isInMergeQueue"])
            self.assertEqual((self.base / (mode + "-second.source")).read_text(), "cache")
            # A later queued waiter must re-read: the shared result is scoped
            # to subscribers present before the response was written.
            later = self.call(key=key, mode=mode, suffix=mode + "-later", force=True)
            _, later_err = later.communicate(timeout=6)
            self.assertEqual(later.returncode, 0, later_err)
            self.assertEqual(self.calls(), before + 2)

    def test_lock_wait_and_upstream_share_one_deadline(self):
        leader = self.call(key="deadline", mode="partial", delay="1.2", suffix="leader")
        start = time.monotonic()
        while self.calls() == 0 and time.monotonic() - start < 3:
            time.sleep(0.01)
        self.assertEqual(self.calls(), 1)
        supervisor = self.base / "slow_supervisor.py"
        supervisor.write_text(
            """import json, os, sys, time
limit = int(sys.argv[sys.argv.index('--timeout-seconds') + 1])
with open(os.environ['LIMIT_FILE'], 'w') as output: output.write(str(limit))
time.sleep(limit)
sys.exit(124)
"""
        )
        limit_file = self.base / "observed-limit"
        env = dict(os.environ, LIMIT_FILE=str(limit_file))
        argv = [sys.executable, str(HELPER), "--state-dir", str(self.base / "state"),
                "--key", "deadline", "--expected-head", "h1", "--ttl", "10",
                "--wait-seconds", "5", "--cap-supervisor-timeout", "--force-refresh",
                "--age-file", str(self.base / "follower.age"),
                "--source-file", str(self.base / "follower.source"), "--",
                sys.executable, str(supervisor), "--timeout-seconds", "5"]
        started = time.monotonic()
        follower = subprocess.run(argv, capture_output=True, env=env, timeout=7)
        elapsed = time.monotonic() - started
        _, leader_err = leader.communicate(timeout=5)
        self.assertEqual(leader.returncode, 4, leader_err)
        self.assertEqual(follower.returncode, 124, follower.stderr)
        self.assertLess(elapsed, 5.8)
        self.assertTrue(limit_file.exists())
        self.assertLess(int(limit_file.read_text()), 5)

    def test_different_access_keys_never_share(self):
        for key in ("scope-a", "scope-b"):
            process = self.call(key=key, suffix=key)
            process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0)
        self.assertEqual(self.calls(), 2)

    def test_colliding_lock_shard_does_not_share_snapshots_or_grow_locks(self):
        keys = {}
        collision = None
        for number in range(1000):
            key = f"separate-access-{number}"
            shard = hashlib.sha256(key.encode()).hexdigest()[:2]
            if shard in keys:
                collision = (keys[shard], key)
                break
            keys[shard] = key
        self.assertIsNotNone(collision)
        first = self.call(key=collision[0], head="h1", delay="0.7", suffix="collision-first")
        started = time.monotonic()
        while self.calls() == 0 and time.monotonic() - started < 4:
            time.sleep(0.01)
        self.assertEqual(self.calls(), 1)
        second = self.call(key=collision[1], head="h2", suffix="collision-second")
        for process, head in ((first, "h1"), (second, "h2")):
            out, err = process.communicate(timeout=8)
            self.assertEqual(process.returncode, 0, err)
            self.assertEqual(json.loads(out)["data"]["repository"]["pullRequest"]["headRefOid"], head)
        self.assertEqual(self.calls(), 2)
        shard = hashlib.sha256(collision[0].encode()).hexdigest()[:2]
        self.assertEqual([path.name for path in (self.base / "state").glob(".flight-*.lock")],
                         [f".flight-{shard}.lock"])
        for index, (key, head) in enumerate(zip(collision, ("h1", "h2"))):
            process = self.call(key=key, head=head, suffix=f"collision-cached-{index}")
            out, err = process.communicate(timeout=8)
            self.assertEqual(process.returncode, 0, err)
            self.assertEqual(json.loads(out)["data"]["repository"]["pullRequest"]["headRefOid"], head)
            self.assertEqual((self.base / f"collision-cached-{index}.source").read_text(), "cache")
        self.assertEqual(self.calls(), 2)

        owner = self.call(key=collision[0], head="h1", delay="5", suffix="collision-owner",
                          force=True, wait_seconds="8")
        started = time.monotonic()
        while self.calls() == 2 and time.monotonic() - started < 4:
            time.sleep(0.01)
        self.assertEqual(self.calls(), 3)
        contender = self.call(key=collision[1], head="h2", suffix="collision-deadline",
                              force=True, wait_seconds="2")
        _, contender_err = contender.communicate(timeout=7)
        self.assertEqual(contender.returncode, 75, contender_err)
        self.assertFalse((self.base / "collision-deadline.source").exists())
        _, owner_err = owner.communicate(timeout=9)
        self.assertEqual(owner.returncode, 0, owner_err)
        self.assertEqual(self.calls(), 3)

    @unittest.skipUnless(os.name == "nt", "Windows ACL case")
    def test_parent_with_other_user_replace_rights_runs_uncached(self):
        subprocess.run(["icacls.exe", str(self.base), "/grant", "*S-1-1-0:(M)"],
                       check=True, capture_output=True)
        for index in range(2):
            process = self.call(key="replaceable-parent", suffix=f"parent-{index}")
            _, err = process.communicate(timeout=8)
            self.assertEqual(process.returncode, 0, err)
            self.assertEqual((self.base / f"parent-{index}.source").read_text(), "upstream")
        self.assertEqual(self.calls(), 2)
        self.assertFalse((self.base / "state").exists())


    def test_head_change_is_not_served_from_old_key(self):
        for head in ("h1", "h2"):
            process = self.call(key="target-" + head, head=head, suffix=head)
            process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0)
        self.assertEqual(self.calls(), 2)

    def test_terminal_and_failed_reads_are_not_cached(self):
        for mode in ("merged", "failed", "status_failed"):
            for index in range(2):
                process = self.call(key=mode, mode=mode, suffix=mode + str(index))
                process.communicate(timeout=5)
                self.assertEqual(process.returncode, 0)
        self.assertEqual(self.calls(), 6)

    def test_truncation_and_partial_graphql_fail_closed(self):
        for mode in ("truncated", "partial"):
            for index in range(2):
                process = self.call(key=mode, mode=mode, suffix=mode + str(index))
                _, err = process.communicate(timeout=5)
                self.assertEqual(process.returncode, 4, err)
                self.assertIn(b"incomplete", err)
        self.assertEqual(self.calls(), 4)

    @unittest.skipIf(os.name == "nt", "Unix signal case")
    def test_cancelled_subscriber_does_not_cancel_refresh_owner(self):
        leader = self.call(key="shared", delay="0.5", suffix="leader")
        deadline = time.monotonic() + 2
        while self.calls() == 0 and time.monotonic() < deadline:
            time.sleep(0.01)
        self.assertEqual(self.calls(), 1)
        follower = self.call(key="shared", delay="0.5", suffix="follower")
        time.sleep(0.05)
        follower.terminate()
        follower.communicate(timeout=3)
        _, err = leader.communicate(timeout=3)
        self.assertEqual(leader.returncode, 0, err)
        self.assertEqual(self.calls(), 1)

    @unittest.skipIf(os.name == "nt", "Unix signal case")
    def test_dead_refresh_owner_releases_os_lock(self):
        owner = self.call(key="dead", delay="2", suffix="owner")
        deadline = time.monotonic() + 2
        while self.calls() == 0 and time.monotonic() < deadline:
            time.sleep(0.01)
        self.assertEqual(self.calls(), 1)
        owner.kill()
        owner.communicate(timeout=3)
        recovery = self.call(key="dead", delay="0", suffix="recovery")
        _, err = recovery.communicate(timeout=3)
        self.assertEqual(recovery.returncode, 0, err)
        self.assertEqual(self.calls(), 2)


class AccessContext(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=Path.home() if os.name == "nt" else None)
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.state = self.base / "state"
        if os.name == "nt":
            secure_windows_directory(self.state)
            secure_windows_directory(self.state / "identities")
        else:
            (self.state / "identities").mkdir(parents=True, mode=0o700)
            self.state.chmod(0o700)
            (self.state / "identities").chmod(0o700)
        (self.state / "principal-salt").write_text("a" * 64)
        (self.state / "principal-salt").chmod(0o600)
        self.fake = self.base / "gh"
        self.fake.write_text("#!/bin/sh\n[ \"$1 $2 $3\" = 'auth token --hostname' ] || exit 8\nprintf '%s\\n' \"$TOKEN\"\n")
        self.fake.chmod(0o700)

    def context(self, token, principal="123"):
        digest = hashlib.sha256((token + "\n").encode()).hexdigest()
        key = hashlib.sha256(f"3 github.com {digest}".encode()).hexdigest()
        (self.state / "identities" / key).write_text(f"{principal} 1000\n")
        (self.state / "identities" / key).chmod(0o600)
        env = dict(os.environ, AI_GH_STATE_DIR=bash_path(self.state),
                   AI_GH_REAL_GH=bash_path(self.fake), TOKEN=token)
        return subprocess.run(["bash", str(CONTEXT)], capture_output=True, env=env, check=False)

    def test_same_principal_different_tokens_have_different_access_keys(self):
        first = self.context("ghp_scope_one")
        second = self.context("ghp_scope_two")
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(second.returncode, 0, second.stderr)
        self.assertNotEqual(first.stdout, second.stdout)
        self.assertNotIn(b"ghp_", first.stdout + second.stdout)

    def test_unverified_identity_disables_sharing(self):
        result = self.context("ghp_unknown", principal="unknown")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"")

    def test_permissive_state_directory_disables_sharing(self):
        if os.name == "nt":
            subprocess.run(["icacls.exe", str(self.state), "/grant", "*S-1-1-0:(M)"],
                           check=True, capture_output=True)
        else:
            self.state.chmod(0o755)
        result = self.context("ghp_visible")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"")

    @unittest.skipUnless(os.name == "nt", "Windows ACL case")
    def test_read_only_group_on_verified_identity_does_not_grant_snapshot_access(self):
        subprocess.run(["icacls.exe", str(self.state), "/grant", "*S-1-1-0:(R)"],
                       check=True, capture_output=True)
        result = self.context("ghp_readonly")
        self.assertEqual(result.returncode, 0, result.stderr)

    @unittest.skipUnless(os.name == "nt", "Windows ACL case")
    def test_other_user_read_cannot_reach_snapshot(self):
        secure_windows_directory(self.base / "snapshot")
        subprocess.run(["icacls.exe", str(self.base / "snapshot"), "/grant", "*S-1-1-0:(R)"],
                       check=True, capture_output=True)
        response = {"data": {"repository": {"pullRequest": {
            "state": "OPEN", "headRefOid": "h1", "isInMergeQueue": False,
            "commits": {"nodes": [{"commit": {"statusCheckRollup": {
                "state": "PENDING", "contexts": {"totalCount": 0,
                "pageInfo": {"hasPreviousPage": False}, "nodes": []}}}}]}}}}}
        source = self.base / "status.py"
        source.write_text(f"print({json.dumps(json.dumps(response))})\n")
        for index in range(2):
            process = subprocess.run(
                [sys.executable, str(HELPER), "--state-dir", str(self.base / "snapshot"),
                 "--key", "scope", "--expected-head", "h1", "--ttl", "10",
                 "--wait-seconds", "4", "--age-file", str(self.base / f"age-{index}"),
                 "--source-file", str(self.base / f"source-{index}"),
                 "--", sys.executable, str(source)], capture_output=True, check=False,
            )
            self.assertEqual(process.returncode, 0, process.stderr)
            self.assertEqual((self.base / f"source-{index}").read_text(), "upstream")
        self.assertFalse(list((self.base / "snapshot").glob("*.json")))


if __name__ == "__main__":
    unittest.main()
