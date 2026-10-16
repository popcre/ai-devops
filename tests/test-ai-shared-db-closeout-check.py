#!/usr/bin/env python3
"""Offline regression tests for the read-only shared-db closeout check."""

import json
import os
from pathlib import Path
import shutil
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
        "labels": [{"name": "db-claim"}],
        "body": ("```db-claim\nversion: 20261015000000\nwrites:\n  - table core.widget\n```\n"
                 f"```db-author-lease\nowner: {owner}\nbranch: codex/test\nworktree: /tmp/test\n"
                 f"expires_at: {expires}\ncapacity_state: {state}\n```{suffix}"),
    }


def nonclaim_issue(number, labels=None):
    return {"number": number, "state": "open",
            "labels": [{"name": label} for label in (labels if labels is not None else ["triage"])],
            "body": "ordinary open issue"}


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
        self.repo = self.root / "repo"
        bindir = self.repo / "bin"
        bindir.mkdir(parents=True)
        self.calls = self.root / "calls.jsonl"
        self.data = self.root / "data.json"
        self.checker = bindir / "ai-shared-db-closeout-check"
        self.checker.write_bytes(CHECKER.read_bytes())
        self.bash = shutil.which("bash")
        self.assertIsNotNone(self.bash, "Bash is required to run the checker")
        gh_impl = self.root / "fake-ai-gh.py"
        gh_impl.write_text(r'''#!/usr/bin/env python3
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
    output = data.get("open_pages", [[{"number": 900, "state": "open", "labels": [{"name": "triage"}], "body": "ordinary open issue"}]])
elif path.startswith("search/issues?"):
    output = data.get("search", {"total_count": 0, "incomplete_results": False, "items": []})
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
        gh = bindir / "ai-gh"
        gh.write_text('''#!/usr/bin/env bash
set -eu
for candidate in python python3; do
  path="$(command -v "$candidate" 2>/dev/null || true)"
  if [ -n "$path" ] && "$path" -c 'import sys; raise SystemExit(0 if sys.version_info.major == 3 else 1)' >/dev/null 2>&1; then
    exec "$path" "$FAKE_GH_IMPL" "$@"
  fi
done
exit 127
''', encoding="utf-8")
        gh.chmod(0o644)
        self.checker.chmod(0o755)
        self.env = os.environ.copy()
        self.env.update({
            "PATH": f"{bindir}{os.pathsep}{self.env.get('PATH', '')}",
            "FAKE_GH_CALLS": str(self.calls),
            "FAKE_GH_DATA": str(self.data),
            "FAKE_GH_IMPL": str(gh_impl),
            "CODEX_THREAD_ID": SESSION,
        })
        self.write_data({"open_pages": [[nonclaim_issue(900)]], "search": {"total_count": 0, "incomplete_results": False, "items": []},
                         "stages": {}, "messages": {}})

    def write_data(self, data):
        self.data.write_text(json.dumps(data), encoding="utf-8")

    def run_check(self, *args, env=None):
        return subprocess.run([self.bash, str(self.checker), *args], capture_output=True, text=True,
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
                self.write_data({"open_pages": [[issue(17, f"Codex chat {SESSION} on edge-dev", capacity, expires)]],
                                 "stages": {}, "messages": {}})
                result = self.run_check()
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(self.summary(result)["blocking_claims"], [{"issue": 17}])

    def test_relinquished_handoff_ready_claim_still_blocks_until_owner_changes(self):
        ready = issue(18, f"codex/{SESSION}-4152", "relinquished",
                      suffix="\n\nOwner handoff-ready receipt was recorded.")
        self.write_data({"open_pages": [[ready]], "stages": {}, "messages": {}})
        result = self.run_check()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.summary(result)["blocking_claims"], [{"issue": 18}])

    def test_raw_uppercase_session_uuid_owner_is_normalized_and_blocks(self):
        self.write_data({"open_pages": [[issue(19, SESSION.upper())]], "stages": {}, "messages": {}})
        result = self.run_check()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.summary(result)["blocking_claims"], [{"issue": 19}])

    def test_unsupported_owner_label_with_session_uuid_fails_closed(self):
        self.write_data({"open_pages": [[issue(20, f"legacy-owner={SESSION};retained")]],
                         "stages": {}, "messages": {}})
        result = self.run_check()
        self.assertEqual(result.returncode, 2)
        self.assertIn("unsupported format", self.summary(result)["error"])

    def test_foreign_owner_and_uuid_in_unrelated_issue_text_do_not_block(self):
        row = issue(21, f"Claude chat {FOREIGN} on edge-dev")
        row["body"] += f"\nOld session note: {SESSION}"
        self.write_data({"open_pages": [[row]], "stages": {}, "messages": {}})
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.summary(result)["ok"])

    def test_zero_claims_uses_search_crosscheck(self):
        self.write_data({"open_pages": [[nonclaim_issue(50)]], "search": {"total_count": 0, "incomplete_results": False, "items": []},
                         "stages": {}, "messages": {}})
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.summary(result)["open_issues_seen"], 1)
        self.assertTrue(any(args[-1].startswith("search/issues?") for args in self.calls_made()))

    def test_nonclaim_issue_with_null_body_is_valid(self):
        row = nonclaim_issue(59)
        row["body"] = None
        self.write_data({"open_pages": [[row]], "search": {"total_count": 0, "incomplete_results": False,
                                                               "items": []}, "stages": {}, "messages": {}})
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_empty_or_pr_only_issue_listing_fails_closed(self):
        for pages in ([], [[]], [[{"number": 51, "pull_request": {"url": "https://api.github.com/pulls/51"}}]]):
            with self.subTest(pages=pages):
                self.calls.unlink(missing_ok=True)
                self.write_data({"open_pages": pages, "stages": {}, "messages": {}})
                result = self.run_check()
                self.assertEqual(result.returncode, 2)
                self.assertIn("contained no issues", self.summary(result)["error"])
                self.assertFalse(any(args[-1].startswith("search/issues?") for args in self.calls_made()))

    def test_nonclaim_listing_must_agree_with_search(self):
        self.write_data({"open_pages": [[nonclaim_issue(52)]],
                         "search": {"total_count": 1, "incomplete_results": False, "items": [{"number": 53}]},
                         "stages": {}, "messages": {}})
        result = self.run_check()
        self.assertEqual(result.returncode, 2)
        self.assertIn("search found open db-claim", self.summary(result)["error"])

    def test_unlabelled_claim_body_fails_closed(self):
        row = nonclaim_issue(54)
        row["body"] = "```db-author-lease\nowner: " + SESSION + "\n```"
        self.write_data({"open_pages": [[row]], "stages": {}, "messages": {}})
        result = self.run_check()
        self.assertEqual(result.returncode, 2)
        self.assertIn("missing the db-claim label", self.summary(result)["error"])

    def test_malformed_issue_labels_fail_closed(self):
        for labels in (None, "db-claim", ["db-claim"], [{"name": 17}]):
            with self.subTest(labels=labels):
                row = nonclaim_issue(55)
                if labels is None:
                    row.pop("labels")
                else:
                    row["labels"] = labels
                self.write_data({"open_pages": [[row]], "stages": {}, "messages": {}})
                result = self.run_check()
                self.assertEqual(result.returncode, 2)
                self.assertIn("malformed issue labels", self.summary(result)["error"])

    def test_wrong_label_does_not_match_db_claim(self):
        self.write_data({"open_pages": [[nonclaim_issue(56, ["db-claim-extra"])]],
                         "search": {"total_count": 0, "incomplete_results": False, "items": []}, "stages": {}, "messages": {}})
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.summary(result)["open_claims_checked"], 0)

    def test_pull_requests_are_excluded_from_issue_label_validation(self):
        pr = {"number": 57, "pull_request": {"url": "https://api.github.com/pulls/57"}}
        self.write_data({"open_pages": [[pr, nonclaim_issue(58)]], "search": {"total_count": 0, "incomplete_results": False, "items": []},
                         "stages": {}, "messages": {}})
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.summary(result)["open_issues_seen"], 1)

    def test_paginated_owned_claim_blocks(self):
        self.write_data({"open_pages": [[issue(31, f"codex-chat-{FOREIGN}@edge-dev")],
                                          [issue(32, f"codex/{SESSION}-4152", "relinquished")]],
                         "stages": {}, "messages": {}})
        result = self.run_check()
        self.assertEqual(result.returncode, 1, result.stderr)
        summary = self.summary(result)
        self.assertEqual(summary["open_claims_checked"], 2)
        self.assertEqual(summary["blocking_claims"], [{"issue": 32}])

    def test_owned_stage_holder_blocks(self):
        sha = "b" * 40
        self.write_data({"open_pages": [[nonclaim_issue(900)]], "stages": {"preview": {"sha": sha}},
                         "messages": {sha: stage_message(SESSION)}})
        result = self.run_check()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.summary(result)["blocking_stages"], [{"stage": "preview"}])

    def test_owned_stage_owner_label_blocks_with_foreign_workflow_holder(self):
        sha = "d" * 40
        self.write_data({"open_pages": [[nonclaim_issue(900)]], "stages": {"preview": {"sha": sha}},
                         "messages": {sha: stage_message(owner=f"Claude chat {SESSION} on edge-dev")}})
        result = self.run_check()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.summary(result)["blocking_stages"], [{"stage": "preview"}])

    def test_foreign_stage_owner_and_holder_substring_do_not_block(self):
        sha = "e" * 40
        message = stage_message(holder="github-actions:555",
                                owner=f"Claude chat {FOREIGN} on edge-dev")
        self.write_data({"open_pages": [[nonclaim_issue(900)]], "stages": {"preview": {"sha": sha}},
                         "messages": {sha: message}})
        result = self.run_check()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.summary(result)["ok"])

    def test_authenticated_stage_404_is_absent(self):
        self.write_data({"open_pages": [[nonclaim_issue(900)]], "stages": {}, "messages": {}})
        env = self.env.copy()
        env["GH_HOST"] = "example.invalid"
        env["AI_SHARED_DB_CLOSEOUT_BASH"] = "/bin/false"
        env["AI_SHARED_DB_CLOSEOUT_GH_SCRIPT"] = "/bin/false"
        result = self.run_check(env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.summary(result)["ok"])
        for args in self.calls_made():
            if args[:1] == ["api"]:
                self.assertIn("--hostname", args)
                self.assertEqual(args[args.index("--hostname") + 1], "github.com")

    def test_cygpath_adaptation_and_python3_fallback(self):
        cygpath_log = self.root / "cygpath.jsonl"
        cygpath = self.repo / "bin/cygpath"
        cygpath.write_text('#!/usr/bin/env python3\n'
                           'import json, os, sys\n'
                           'with open(os.environ["CYGPATH_LOG"], "a") as f: f.write(json.dumps(sys.argv[1:]) + "\\n")\n'
                           'print(sys.argv[-1])\n', encoding="utf-8")
        cygpath.chmod(0o755)
        fake_python = self.repo / "bin/python"
        fake_python.write_text("#!/usr/bin/env bash\nexit 1\n", encoding="utf-8")
        fake_python.chmod(0o755)
        env = self.env.copy()
        env["CYGPATH_LOG"] = str(cygpath_log)
        result = self.run_check(env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        calls = [json.loads(line) for line in cygpath_log.read_text().splitlines()]
        self.assertEqual(len(calls), 2)
        self.assertTrue(all(call[0] == "-m" for call in calls))
        self.assertEqual(self.summary(result)["open_claims_checked"], 0)

    def test_api_failure_and_malformed_response_fail_closed(self):
        endpoint = "repos/popcre/shared-db/issues?state=open&per_page=100"
        cases = [
            ({"open_pages": [[nonclaim_issue(900)]], "stages": {}, "messages": {},
              "failures": [{"path": endpoint, "stderr": "gh: Forbidden (HTTP 403)"}]}, "GitHub request failed"),
            ({"open_pages": [[nonclaim_issue(900)]], "stages": {}, "messages": {},
              "malformed": {"issues?state=open&per_page=100": "{}"}},
             "claim pages have an invalid shape"),
            ({"open_pages": [[nonclaim_issue(900)]], "search": {"total_count": "0",
              "incomplete_results": False, "items": []}, "stages": {}, "messages": {}},
             "db-claim search cross-check was malformed"),
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
        self.write_data({"open_pages": [[nonclaim_issue(900)]], "stages": {"preview": {"sha": sha}},
                         "messages": {sha: "unrecognized commit"}})
        result = self.run_check()
        self.assertEqual(result.returncode, 2)
        self.assertIn("canonical lease format", self.summary(result)["error"])


if __name__ == "__main__":
    unittest.main()
