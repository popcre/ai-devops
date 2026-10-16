#!/usr/bin/env python3
"""Offline regression tests for the read-only shared-db closeout check."""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CHECKER = ROOT / "bin/ai-shared-db-closeout-check"
SESSION = "11111111-2222-4333-8444-555555555555"
FOREIGN = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"


def issue(number, owner, state="active", expires="2026-10-14T00:00:00Z", suffix=""):
    return {
        "number": number,
        "state": "open",
        "body": ("```db-claim\nversion: 20261015000000\nwrites:\n  - table core.widget\n```\n"
                 f"```db-author-lease\nowner: {owner}\nbranch: codex/test\nworktree: /tmp/test\n"
                 f"expires_at: {expires}\ncapacity_state: {state}\n```{suffix}"),
    }


def stage_message(holder="github-actions:555", kind="preview", owner="none"):
    return (f"db-coordination {kind} request-1 pr=none head={'a' * 40}\n\n"
            "lease_version: 1\n"
            f"kind: {kind}\n"
            f"holder_id: {holder}\n"
            f"github_run_id: none\ngithub_run_attempt: none\nowner: {owner}\npr: none\n"
            f"head_sha: {'a' * 40}\nmigration_versions: none\n"
            "acquired_at: 2026-10-15T00:00:00Z\ngeneration: 1")


class CloseoutCheck(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        bindir = self.root / "bin"
        bindir.mkdir()
        self.calls = self.root / "calls.jsonl"
        self.data = self.root / "data.json"
        gh = bindir / "gh"
        gh.write_text(r'''#!/usr/bin/env python3
import json, os, sys
args = sys.argv[1:]
with open(os.environ["FAKE_GH_CALLS"], "a", encoding="utf-8") as f:
    f.write(json.dumps(args) + "\n")
if args[:2] == ["auth", "status"]:
    sys.exit(0)
data = json.load(open(os.environ["FAKE_GH_DATA"], encoding="utf-8"))
if args[:1] != ["api"]:
    print("unexpected command", file=sys.stderr); sys.exit(2)
path = args[-1]
for entry in data.get("failures", []):
    if entry["path"] == path:
        print(entry.get("stderr", "gh: API failure"), file=sys.stderr); sys.exit(entry.get("code", 1))
if path.startswith("repos/popcre/shared-db/issues?"):
    output = data.get("claim_pages", [[]])
elif "/git/ref/" in path:
    stage = path.rsplit("/", 1)[-1]
    record = data.get("stages", {}).get(stage)
    if record is None:
        print("gh: Not Found (HTTP 404)", file=sys.stderr); sys.exit(1)
    output = {"object": {"sha": record["sha"]}}
elif "/git/commits/" in path:
    sha = path.rsplit("/", 1)[-1]
    output = {"message": data.get("messages", {}).get(sha, "")}
else:
    print("gh: unexpected endpoint", file=sys.stderr); sys.exit(2)
malformed = data.get("malformed", {})
for suffix, raw in malformed.items():
    if path.endswith(suffix):
        print(raw); sys.exit(0)
print(json.dumps(output))
''', encoding="utf-8")
        gh.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update({
            "PATH": f"{bindir}{os.pathsep}{self.env.get('PATH', '')}",
            "FAKE_GH_CALLS": str(self.calls),
            "FAKE_GH_DATA": str(self.data),
            "CODEX_THREAD_ID": SESSION,
        })
        self.write_data({"claim_pages": [[]], "stages": {}, "messages": {}})

    def write_data(self, data):
        self.data.write_text(json.dumps(data), encoding="utf-8")

    def run_check(self, *args, env=None):
        return subprocess.run([str(CHECKER), *args], capture_output=True, text=True,
                              env=self.env if env is None else env, check=False)

    def summary(self, result):
        self.assertTrue(result.stdout.strip(), result.stderr)
        return json.loads(result.stdout)

    def calls_made(self):
        return [json.loads(line) for line in self.calls.read_text().splitlines()] if self.calls.exists() else []

    def test_missing_identity_fails_before_any_github_call(self):
        env = self.env.copy()
        env.pop("CODEX_THREAD_ID")
        env.pop("CLAUDE_CODE_SESSION_ID", None)
        result = self.run_check(env=env)
        self.assertEqual(result.returncode, 2)
        self.assertIn("session identity is missing", self.summary(result)["error"])
        self.assertEqual(self.calls_made(), [])

    def test_explicit_identity_cannot_override_different_client_identity(self):
        result = self.run_check("--session-id", FOREIGN)
        self.assertEqual(result.returncode, 2)
        self.assertIn("sources disagree", self.summary(result)["error"])
        self.assertEqual(self.calls_made(), [])

    def test_conflicting_client_identity_environment_variables_refuse(self):
        env = self.env.copy()
        env["CLAUDE_CODE_SESSION_ID"] = FOREIGN
        result = self.run_check(env=env)
        self.assertEqual(result.returncode, 2)
        self.assertIn("sources disagree", self.summary(result)["error"])
        self.assertEqual(self.calls_made(), [])

    def test_owned_active_relinquished_and_expired_claims_all_block(self):
        rows = (
            ("active", "active", "2026-10-16T01:00:00Z"),
            ("relinquished", "relinquished", "2026-10-14T00:00:00Z"),
            ("expired", "active", "2026-10-14T00:00:00Z"),
        )
        for label, capacity, expires in rows:
            with self.subTest(state=label):
                self.calls.unlink(missing_ok=True)
                self.write_data({"claim_pages": [[issue(17, f"Codex chat {SESSION} on edge-dev", capacity, expires)]],
                                 "stages": {}, "messages": {}})
                result = self.run_check()
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(self.summary(result)["blocking_claims"], [{"issue": 17}])

    def test_relinquished_handoff_ready_claim_still_blocks_until_owner_changes(self):
        ready = issue(18, f"codex/{SESSION}-4152", "relinquished",
                      suffix="\n\nOwner handoff-ready receipt was recorded.")
        self.write_data({"claim_pages": [[ready]], "stages": {}, "messages": {}})
        result = self.run_check()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.summary(result)["blocking_claims"], [{"issue": 18}])

    def test_foreign_owner_and_uuid_in_unrelated_issue_text_do_not_block(self):
        row = issue(21, f"Claude chat {FOREIGN} on edge-dev")
        row["body"] += f"\nOld session note: {SESSION}"
        self.write_data({"claim_pages": [[row]], "stages": {}, "messages": {}})
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.summary(result)["ok"])

    def test_paginated_owned_claim_blocks(self):
        self.write_data({"claim_pages": [[issue(31, f"codex-chat-{FOREIGN}@edge-dev")],
                                          [issue(32, f"codex/{SESSION}-4152", "relinquished")]],
                         "stages": {}, "messages": {}})
        result = self.run_check()
        self.assertEqual(result.returncode, 1, result.stderr)
        summary = self.summary(result)
        self.assertEqual(summary["open_claims_checked"], 2)
        self.assertEqual(summary["blocking_claims"], [{"issue": 32}])

    def test_owned_stage_holder_blocks(self):
        sha = "b" * 40
        self.write_data({"claim_pages": [[]], "stages": {"preview": {"sha": sha}},
                         "messages": {sha: stage_message(SESSION)}})
        result = self.run_check()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.summary(result)["blocking_stages"], [{"stage": "preview"}])

    def test_owned_stage_owner_label_blocks_with_foreign_workflow_holder(self):
        sha = "d" * 40
        self.write_data({"claim_pages": [[]], "stages": {"preview": {"sha": sha}},
                         "messages": {sha: stage_message(owner=f"Claude chat {SESSION} on edge-dev")}})
        result = self.run_check()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.summary(result)["blocking_stages"], [{"stage": "preview"}])

    def test_foreign_stage_owner_and_holder_substring_do_not_block(self):
        sha = "e" * 40
        message = stage_message(holder=f"github-actions:{SESSION}",
                                owner=f"Claude chat {FOREIGN} on edge-dev")
        self.write_data({"claim_pages": [[]], "stages": {"preview": {"sha": sha}},
                         "messages": {sha: message}})
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.summary(result)["ok"])

    def test_authenticated_stage_404_is_absent(self):
        self.write_data({"claim_pages": [[]], "stages": {}, "messages": {}})
        env = self.env.copy()
        env["GH_HOST"] = "example.invalid"
        result = self.run_check(env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.summary(result)["ok"])
        for args in self.calls_made():
            if args[:1] == ["api"]:
                self.assertIn("--hostname", args)
                self.assertEqual(args[args.index("--hostname") + 1], "github.com")

    def test_api_failure_and_malformed_response_fail_closed(self):
        endpoint = "repos/popcre/shared-db/issues?state=open&per_page=100&labels=db-claim"
        cases = [
            ({"claim_pages": [[]], "stages": {}, "messages": {},
              "failures": [{"path": endpoint, "stderr": "gh: Forbidden (HTTP 403)"}]}, "GitHub request failed"),
            ({"claim_pages": [[]], "stages": {}, "messages": {},
              "malformed": {"issues?state=open&per_page=100&labels=db-claim": "{}"}},
             "claim pages have an invalid shape"),
        ]
        for data, error in cases:
            with self.subTest(error=error):
                self.calls.unlink(missing_ok=True)
                self.write_data(data)
                result = self.run_check()
                self.assertEqual(result.returncode, 2)
                self.assertIn(error, self.summary(result)["error"])

    def test_malformed_stage_commit_fails_closed(self):
        sha = "c" * 40
        self.write_data({"claim_pages": [[]], "stages": {"preview": {"sha": sha}},
                         "messages": {sha: "unrecognized commit"}})
        result = self.run_check()
        self.assertEqual(result.returncode, 2)
        self.assertIn("canonical lease format", self.summary(result)["error"])


if __name__ == "__main__":
    unittest.main()
