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


class SingleFlight(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.count = self.base / "calls"
        self.fake = self.base / "fake.py"
        self.fake.write_text(
            """import json, os, time
with open(os.environ['COUNT'], 'a') as f: f.write('x\\n')
time.sleep(float(os.environ.get('DELAY', '0')))
mode = os.environ.get('MODE', 'open')
pr = {'state': 'MERGED' if mode == 'merged' else 'OPEN',
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

    def call(self, key="scope-a", head="h1", mode="open", delay="0", suffix="a"):
        env = dict(os.environ, COUNT=str(self.count), HEAD=head, MODE=mode, DELAY=delay)
        argv = [sys.executable, str(HELPER), "--state-dir", str(self.base / "state"),
                "--key", key, "--expected-head", head, "--ttl", "10",
                "--wait-seconds", "4", "--age-file", str(self.base / (suffix + ".age")),
                "--", sys.executable, str(self.fake)]
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
        self.assertEqual((self.base / "state").stat().st_mode & 0o077, 0)

    def test_different_access_keys_never_share(self):
        for key in ("scope-a", "scope-b"):
            process = self.call(key=key, suffix=key)
            process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0)
        self.assertEqual(self.calls(), 2)


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
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.state = self.base / "state"
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
        env = dict(os.environ, AI_GH_STATE_DIR=str(self.state), AI_GH_REAL_GH=str(self.fake), TOKEN=token)
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
        self.state.chmod(0o755)
        result = self.context("ghp_visible")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"")


if __name__ == "__main__":
    unittest.main()
