#!/usr/bin/env python3
"""Lifecycle regressions for #2171; no network or model calls."""
import copy
import importlib.util
import json
import os
import re
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

    def test_invalid_branch_receipts_are_rejected(self):
        for branch in ("", "-bad", "@", "a b", "a\nb", "a?b", "a[b", "a\\b",
                       "a..b", "a@{b", "a.", "/a", "a/", "a//b", ".a", "a/.b", "a.lock/b"):
            with self.subTest(branch=branch), self.assertRaises(ValueError):
                m.validate(dict(self.data, target_branch=branch), "o/r")
        for branch in ("owner/work", "release/v1.2", "feature_test", "fix+one"):
            m.validate(dict(self.data, target_branch=branch), "o/r")

    def test_legitimate_bot_owner_is_valid(self):
        m.validate(dict(self.data, owner="github-actions[bot]"), "o/r")
        for owner in ("--bad", "bad user", "[bot]", "user[other]"):
            with self.assertRaises(ValueError):
                m.validate(dict(self.data, owner=owner), "o/r")

    def test_assignment_failure_preserves_deferral_and_retirement(self):
        self.pr["head"]["sha"] = NEXT
        self.pulls = [self.fixer_pr(), dict(self.fixer_pr(), number=10)]
        def gh(*args):
            if "--add-assignee" in args:
                raise subprocess.CalledProcessError(1, "gh")
            self.commands.append(args)
            return ""
        with patch.object(m, "gh", side_effect=gh):
            self.assertFalse(self.state.check(self.data))
            self.state.retire("owner/work")
        self.assertTrue(self.deferred())
        for number in (9, 10):
            self.assertTrue(any(c[:3] == ("pr", "close", number) for c in self.commands))
        self.assertTrue(any("--body" in c and "@owner" in c[c.index("--body") + 1] for c in self.commands))

    def test_trusted_default_branch_adapters_preserve_github_authentication(self):
        with tempfile.TemporaryDirectory() as trusted:
            script = Path(trusted) / "scripts/review-fixer-lifecycle.mjs"
            script.parent.mkdir()
            script.touch()
            with patch.dict(os.environ, REVIEW_FIXER_TRUSTED_ROOT=trusted, GH_TOKEN="fixture-token", HOME=trusted), patch.object(
                    m.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "", "")) as run, patch.object(
                    m.subprocess, "check_output", return_value="file.py\0"):
                self.assertTrue(self.state.check(self.data, "/unused"))
                self.pulls = [self.fixer_pr()]
                self.pr["head"]["sha"] = NEXT
                self.state.retire("owner/work")
                self.assertEqual(run.call_count, 2)
                for call in run.call_args_list:
                    env = call.kwargs.get("env", os.environ)
                    self.assertEqual(env["GH_TOKEN"], "fixture-token")
                    self.assertEqual(env["HOME"], trusted)
                    self.assertEqual(call.args[0][1], str(script))

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
        real = self.api
        with patch.object(m, "api", side_effect=lambda endpoint: {"object": {"sha": NEXT}} if "/git/ref/" in endpoint else real(endpoint)):
            self.assertFalse(self.state.check(self.data))

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
        return {"number": 9, "base": {"ref": "owner/work"}, "head": {"ref": "review-fix/7", "repo": {"full_name": "o/r"}}, "body": m.encoded_marker(self.data)}

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
            self.state.retire("owner/work")
        self.assertFalse(self.commands)

    def test_foreign_fork_cannot_forge_same_named_fixer_receipt(self):
        pr = self.fixer_pr()
        pr["head"]["repo"]["full_name"] = "foreign/r"
        self.pulls = [pr]
        self.pr["head"]["sha"] = NEXT
        with patch.object(self.state, "issue", side_effect=AssertionError("foreign PR cannot dereference issue")):
            self.state.retire("owner/work")
        self.assertFalse(self.commands)

    def test_business_issue_cannot_be_deferred_by_forged_fixer(self):
        self.pulls = [self.fixer_pr()]
        self.issue["labels"] = []
        self.pr["head"]["sha"] = NEXT
        self.state.retire("owner/work")
        self.assertFalse(self.commands)

    def test_receipt_must_bind_actual_finding_reviewed_commit(self):
        self.pr["head"]["sha"] = NEXT
        for bad in (dict(self.data, reviewed_head=NEXT, target_head=NEXT),
                    dict(self.data, target_head=NEXT), dict(self.data, owner="other-owner"),
                    dict(self.data, source_pr=8)):
            pr = self.fixer_pr()
            pr["body"] = m.encoded_marker(bad)
            self.pulls = [pr]
            self.state.retire("owner/work")
        self.assertFalse(self.commands)

    def test_receipt_target_commit_must_equal_reviewed_commit(self):
        with self.assertRaises(ValueError):
            m.validate(dict(self.data, target_head=NEXT), "o/r", self.fixer_pr())

    def test_stale_source_at_prepare_defers_to_named_owner(self):
        self.pr["head"]["sha"] = NEXT
        data, _ = self.state.source(self.issue)
        self.assertEqual(data["target_head"], NEXT)
        self.assertFalse(self.state.check(data))
        self.assertTrue(self.deferred())
        self.assertTrue(any("--add-assignee" in c and "owner" in c for c in self.commands))

    def test_retirement_api_failure_still_refuses_visibly(self):
        self.pulls = [self.fixer_pr()]
        with patch.object(self.state, "issue", side_effect=subprocess.CalledProcessError(1, "gh")), self.assertRaises(subprocess.CalledProcessError):
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

    def event_plan(self, event, payload, number=None):
        with tempfile.TemporaryDirectory() as tmp:
            event_path = Path(tmp) / "event.json"
            event_path.write_text(json.dumps(payload), encoding="utf-8")
            with patch.dict(os.environ, GITHUB_EVENT_NAME=event, GITHUB_EVENT_PATH=str(event_path)):
                return self.state.plan(number)

    def test_cleanup_events_only_select_exact_affected_target_without_model_work(self):
        self.pulls = [self.fixer_pr(), {"base": {"ref": "other"}, "head": {"ref": "review-fix/9"}}]
        for event, payload in (("push", {"ref": "refs/heads/owner/work"}),
                               ("delete", {"ref": "owner/work", "ref_type": "branch"}),
                               ("pull_request", {"pull_request": self.pr}),
                               ("pull_request_target", {"pull_request": self.pr})):
            plan = self.event_plan(event, payload)
            self.assertEqual([(x["target"], x["issues"]) for x in plan["include"]], [("owner/work", [])])

    def test_unrelated_branch_update_selects_no_existing_fixer(self):
        self.pulls = [self.fixer_pr()]
        self.assertEqual(self.event_plan("push", {"ref": "refs/heads/unrelated"}), {"include": []})

    def test_generated_fixer_branch_push_and_delete_have_no_jobs(self):
        with patch.object(self.state, "pulls", side_effect=AssertionError("unnecessary API query")):
            self.assertEqual(self.event_plan("push", {"ref": "refs/heads/review-fix/7"}), {"include": []})
            self.assertEqual(self.event_plan("delete", {"ref": "review-fix/7", "ref_type": "branch"}), {"include": []})

    def test_tag_push_and_delete_have_no_jobs(self):
        with patch.object(self.state, "pulls", side_effect=AssertionError("unnecessary API query")):
            self.assertEqual(self.event_plan("push", {"ref": "refs/tags/v1"}), {"include": []})
            self.assertEqual(self.event_plan("delete", {"ref": "v1", "ref_type": "tag"}), {"include": []})

    def test_fork_pr_updates_never_target_same_named_local_branch(self):
        pr = copy.deepcopy(self.pr)
        pr["head"]["repo"]["full_name"] = "foreign/r"
        self.pulls = [self.fixer_pr()]
        self.assertEqual(self.event_plan("pull_request_target", {"pull_request": pr}), {"include": []})
        pr["head"]["repo"] = None
        self.assertEqual(self.event_plan("pull_request_target", {"pull_request": pr}), {"include": []})

    def test_explicit_issue_dispatch_cleans_only_its_target(self):
        self.pulls = [self.fixer_pr(), {"base": {"ref": "other"}, "head": {"ref": "review-fix/9"}}]
        for event in ("workflow_dispatch", "issues"):
            plan = self.event_plan(event, {}, 7)
            self.assertEqual([(x["target"], x["issues"]) for x in plan["include"]], [("owner/work", [7])])

    def test_unknown_and_malformed_events_fail_without_broad_sweep(self):
        for event, payload in (("unknown", {}), ("push", {}), ("push", {"ref": "bad"}), ("push", {"ref": "refs/tags/"}),
                               ("delete", {"ref": "branch"}), ("delete", {"ref_type": "branch"}),
                               ("delete", {"ref_type": "tag"}),
                               ("pull_request_target", {}), ("pull_request_target", {"pull_request": {"head": {"repo": {}}}}),
                               ("pull_request_target", {"pull_request": {"head": {}}}),
                               ("issues", {})):
            with patch.object(self.state, "pulls", side_effect=AssertionError("broad sweep is forbidden")), self.assertRaises(ValueError):
                self.event_plan(event, payload)
        with patch.dict(os.environ, GITHUB_EVENT_NAME="push", GITHUB_EVENT_PATH=""), self.assertRaises(ValueError):
            self.state.plan()

    def test_sweep_never_recreates_deferred_work(self):
        self.issue["labels"].append({"name": "fixer-deferred"})
        self.assertEqual(self.state.plan(), {"include": []})

    def test_workflow_conditions_do_not_embed_unquoted_yaml_mapping_values(self):
        workflow = (ROOT / ".github/workflows/review-fixer.yml").read_text()
        for line in workflow.splitlines():
            if not line.lstrip().startswith("if:"):
                continue
            expression = line.split("if:", 1)[1].strip()
            if not expression.startswith(("'", '"', ">", "|")):
                self.assertNotRegex(expression, r":\s", "unquoted colon-space prevents the workflow from registering")

    def test_workflow_serializes_repository_target_for_all_entry_points(self):
        workflow = (ROOT / ".github/workflows/review-fixer.yml").read_text()
        self.assertIn("group: review-fixer-${{ github.repository }}-${{ matrix.key }}", workflow)
        self.assertIn("cancel-in-progress: false", workflow)
        self.assertIn("python3 toolkit/tools/ci/review-fixer-state.py retire", workflow)
        self.assertIn("pull_request_target:", workflow)
        self.assertIn("caller-trusted", workflow)

    def test_prepare_and_fix_share_the_existing_caller_runner_contract(self):
        workflow = (ROOT / ".github/workflows/review-fixer.yml").read_text()
        expected = "${{ fromJSON(inputs.runner_labels || '[\"self-hosted\", \"ai-devops-linux\"]') }}"
        for job in ("prepare", "fix"):
            block = re.search(r"^  " + job + r":\n(.*?)(?=^  [A-Za-z][A-Za-z0-9_-]*:|\Z)", workflow, re.M | re.S)
            self.assertIsNotNone(block)
            runners = re.findall(r"^    runs-on: (.+)$", block[1], re.M)
            self.assertEqual(runners, [expected])


if __name__ == "__main__":
    unittest.main(verbosity=2)
