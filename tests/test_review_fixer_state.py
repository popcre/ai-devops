#!/usr/bin/env python3
"""Lifecycle regressions for #2171; no network or model calls."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("fixer_state", ROOT / "tools/ci/review-fixer-state.py")
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
HEAD = "a" * 40
NEXT = "b" * 40


def finding(number=7):
    return {"number": number, "state": "open", "labels": [{"name": "review-finding"}],
            "body": f"PR: https://github.com/o/r/pull/2\nHead SHA: `{HEAD}`\nReviewer: glm\n"}


def source():
    return {"number": 2, "state": "open", "user": {"login": "owner"},
            "head": {"ref": "owner/work", "sha": HEAD, "repo": {"full_name": "o/r"}},
            "base": {"ref": "main"}}


class StateTests(unittest.TestCase):
    def setUp(self):
        self.env = patch.dict(os.environ, GITHUB_REPOSITORY="o/r", GITHUB_EVENT_NAME="workflow_dispatch", AI_GH_SIGNATURE="Posted by test")
        self.env.start(); self.addCleanup(self.env.stop)
        self.issue = finding()
        self.pr = source()
        self.pulls = []
        self.commands = []
        self.api_patch = patch.object(m, "api", side_effect=self.api)
        self.api_patch.start(); self.addCleanup(self.api_patch.stop)
        self.gh_patch = patch.object(m, "gh", side_effect=lambda *args: self.commands.append(args) or "")
        self.gh_patch.start(); self.addCleanup(self.gh_patch.stop)
        self.paged_patch = patch.object(m, "paged", side_effect=self.paged)
        self.paged_patch.start(); self.addCleanup(self.paged_patch.stop)
        self.state = m.State()
        self.data, _ = self.state.source(self.issue)

    def api(self, endpoint):
        if endpoint.endswith("/pulls/2"):
            return copy.deepcopy(self.pr)
        if "/issues/" in endpoint:
            return copy.deepcopy(self.issue)
        if "/git/ref/heads/" in endpoint:
            return {"object": {"sha": HEAD}}
        raise AssertionError(endpoint)

    def paged(self, endpoint):
        if "/pulls?" in endpoint:
            return copy.deepcopy(self.pulls)
        if "/issues?" in endpoint:
            return [copy.deepcopy(self.issue)]
        if "/files?" in endpoint:
            return [{"filename": "file.py"}]
        raise AssertionError(endpoint)

    def deferred(self):
        return any("--add-label" in c and "fixer-deferred" in c for c in self.commands)

    def test_current_finding_may_run(self):
        self.assertTrue(self.state.check(self.data))
        self.assertFalse(self.commands)

    def test_moved_source_defers_to_owner_without_closing_finding(self):
        self.pr["head"]["sha"] = NEXT
        self.assertFalse(self.state.check(self.data))
        self.assertTrue(self.deferred())
        self.assertTrue(any("--add-assignee" in c and "owner" in c for c in self.commands))
        self.assertFalse(any(c[:2] == ("issue", "close") for c in self.commands))

    def test_closed_source_never_falls_back_to_main(self):
        self.pr["state"] = "closed"
        self.assertFalse(self.state.check(self.data))
        self.assertTrue(self.deferred())

    def test_fork_source_does_not_run(self):
        self.pr["head"]["repo"]["full_name"] = "other/r"
        self.assertFalse(self.state.check(self.data))

    def test_deleted_target_defers(self):
        real = self.api
        def api(endpoint):
            if "/git/ref/" in endpoint:
                raise subprocess.CalledProcessError(1, "gh", stderr="HTTP 404")
            return real(endpoint)
        with patch.object(m, "api", side_effect=api):
            self.assertFalse(self.state.check(self.data))
        self.assertTrue(self.deferred())

    def test_transient_api_failure_is_not_a_permanent_deferral(self):
        real = self.api
        def api(endpoint):
            if "/git/ref/" in endpoint:
                raise subprocess.CalledProcessError(1, "gh", stderr="HTTP 503")
            return real(endpoint)
        with patch.object(m, "api", side_effect=api), self.assertRaises(subprocess.CalledProcessError):
            self.state.check(self.data)
        self.assertFalse(self.deferred())

    def test_target_drift_refuses_publication(self):
        data = dict(self.data, target_head=NEXT)
        self.assertFalse(self.state.check(data))

    def test_pending_fixer_defers_additional_finding(self):
        self.pulls = [{"number": 9, "base": {"ref": "owner/work"}, "head": {"ref": "review-fix/8"}}]
        self.assertFalse(self.state.check(self.data))
        self.assertTrue(self.deferred())

    def test_rerun_existing_fix_is_idempotent(self):
        self.pulls = [{"number": 9, "base": {"ref": "owner/work"}, "head": {"ref": "review-fix/7"}}]
        self.assertFalse(self.state.check(self.data))
        self.assertFalse(self.commands)

    def test_deferred_done_failed_and_closed_findings_do_not_rerun(self):
        for label in ("fixer-deferred", "fixer-done", "fixer-failed"):
            self.issue["labels"].append({"name": label})
            self.assertFalse(self.state.check(self.data))
            self.issue["labels"].pop()
        self.issue["state"] = "closed"
        self.assertFalse(self.state.check(self.data))

    def test_unlabelled_issue_cannot_start_fixer(self):
        self.issue["labels"] = []
        self.assertFalse(self.state.check(self.data))

    def test_missing_or_foreign_metadata_refuses(self):
        for body in ("no source", f"PR: https://github.com/foreign/r/pull/2\nHead SHA: `{HEAD}`", "PR: https://github.com/o/r/pull/2\nHead SHA: `bad`"):
            with self.assertRaises(ValueError):
                self.state.source(dict(self.issue, body=body))

    def test_owner_source_pr_is_excluded_from_overlap(self):
        self.pulls = [self.pr]
        with patch.object(m.subprocess, "check_output", return_value="file.py\0"):
            self.assertTrue(self.state.check(self.data, "/unused"))

    def test_other_owner_overlap_defers_not_resolves(self):
        self.pulls = [{"number": 3, "base": {"ref": "main"}, "head": {"ref": "other-work"}}]
        with patch.object(m.subprocess, "check_output", return_value="file.py\0"):
            self.assertFalse(self.state.check(self.data, "/unused"))
        self.assertTrue(self.deferred())

    def test_new_overlap_after_initial_check_still_refuses_publication(self):
        with patch.object(m.subprocess, "check_output", return_value="file.py\0") as git:
            self.assertTrue(self.state.check(self.data, "/unused"))
            self.pulls = [{"number": 3, "base": {"ref": "main"}, "head": {"ref": "owner-new-work"}}]
            self.assertFalse(self.state.check(self.data, "/unused"))
            self.assertIn(HEAD, git.call_args.args[0])
            self.assertIn("-z", git.call_args.args[0])
        self.assertTrue(self.deferred())

    def test_nul_paths_preserve_newlines_and_quotes(self):
        self.pulls = [{"number": 3, "base": {"ref": "main"}, "head": {"ref": "owner-new-work"}}]
        original = self.paged
        def paged(endpoint):
            return [{"filename": 'odd\n"file.py'}] if "/files?" in endpoint else original(endpoint)
        with patch.object(m, "paged", side_effect=paged), patch.object(m.subprocess, "check_output", return_value='odd\n"file.py\0'):
            self.assertFalse(self.state.check(self.data, "/unused"))

    def test_unrelated_target_work_does_not_collide(self):
        self.pulls = [{"number": 3, "base": {"ref": "unrelated"}, "head": {"ref": "other-work"}}]
        with patch.object(m.subprocess, "check_output", return_value="file.py\0"):
            self.assertTrue(self.state.check(self.data, "/unused"))

    def fixer_pr(self):
        return {"number": 9, "base": {"ref": "owner/work"}, "head": {"ref": "review-fix/7"}, "body": m.encoded_marker(self.data)}

    def test_stale_fix_retires_but_finding_stays_open(self):
        self.pulls = [self.fixer_pr()]
        self.pr["head"]["sha"] = NEXT
        self.state.retire("owner/work")
        self.assertTrue(any(c[:3] == ("pr", "close", 9) for c in self.commands))
        self.assertFalse(any(c[:2] == ("issue", "close") for c in self.commands))

    def test_current_and_legacy_fix_prs_are_not_guessed_stale(self):
        self.pulls = [self.fixer_pr()]
        self.state.retire("owner/work")
        self.pulls[0]["body"] = "legacy fix"
        self.state.retire("owner/work")
        self.assertFalse(self.commands)

    def test_generated_legacy_fix_retires_with_exact_issue_source_target(self):
        pr = self.fixer_pr()
        pr["body"] = "Closes #7\n\nPosted by review-fixer workflow run 123"
        self.pulls = [pr]
        self.pr["head"]["sha"] = NEXT
        self.state.retire("owner/work")
        self.assertTrue(any(c[:3] == ("pr", "close", 9) for c in self.commands))
        self.assertTrue(self.deferred())

    def test_lookalike_legacy_manual_pr_is_not_retired(self):
        pr = self.fixer_pr()
        pr["body"] = "Closes #7\n\nPosted by a person"
        self.pulls = [pr]
        self.pr["head"]["sha"] = NEXT
        self.state.retire("owner/work")
        self.assertFalse(self.commands)

    def test_hostile_receipt_cannot_retire_foreign_issue(self):
        pr = self.fixer_pr()
        for bad in (dict(self.data, issue=8), dict(self.data, repository="foreign/r"), dict(self.data, owner="--bad"), dict(self.data, reviewed_head="bad")):
            pr["body"] = m.encoded_marker(bad)
            self.pulls = [pr]
            with self.assertRaises(ValueError):
                self.state.retire("owner/work")
        self.assertFalse(self.commands)

    def test_marker_escapes_comment_terminators(self):
        data = dict(self.data, evidence="x --> <script>")
        text = m.encoded_marker(data, m.INVALID)
        self.assertEqual(text.count("-->"), 1)
        self.assertEqual(m.marker(text, m.INVALID), data)

    def test_sweep_groups_all_pending_findings_and_existing_fix_targets(self):
        self.pulls = [{"base": {"ref": "other"}, "head": {"ref": "review-fix/9"}}]
        plan = self.state.plan()
        self.assertEqual({x["target"]: x["issues"] for x in plan["include"]}, {"other": [], "owner/work": [7]})
        self.assertTrue(all(len(x["key"]) == 64 for x in plan["include"]))

    def test_cleanup_events_never_schedule_model_work(self):
        for event in ("push", "pull_request", "pull_request_target", "delete"):
            with patch.dict(os.environ, GITHUB_EVENT_NAME=event):
                self.assertEqual(self.state.plan(), {"include": []})

    def test_sweep_never_recreates_deferred_work(self):
        self.issue["labels"].append({"name": "fixer-deferred"})
        self.assertEqual(self.state.plan(), {"include": []})

    def test_workflow_serializes_repository_target_for_all_entry_points(self):
        workflow = (ROOT / ".github/workflows/review-fixer.yml").read_text()
        self.assertIn("group: review-fixer-${{ github.repository }}-${{ matrix.key }}", workflow)
        self.assertIn("cancel-in-progress: false", workflow)
        self.assertIn("python3 toolkit/tools/ci/review-fixer-state.py retire", workflow)
        self.assertIn("pull_request_target:", workflow)
        self.assertIn("caller-trusted", workflow)


if __name__ == "__main__":
    unittest.main(verbosity=2)
