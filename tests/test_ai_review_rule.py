#!/usr/bin/env python3
"""Tests for the ai-review advisory rule, rotation and docs-only classifier (plan REVISION phase A)."""
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "bin", "ai-review-simple")
loader = importlib.machinery.SourceFileLoader("ai_review_simple", SCRIPT)
spec = importlib.util.spec_from_loader("ai_review_simple", loader)
ars = importlib.util.module_from_spec(spec)
loader.exec_module(ars)

HEAD = "a" * 40


def r(provider, verdict, head=HEAD):
    return {"provider": provider, "head": head, "verdict": verdict,
            "error": None if verdict else "out-of-credit", "elapsed": 1.0, "findings": ""}


class RuleTests(unittest.TestCase):
    def test_approve_passes(self):
        s = ars.combine([r("glm", "APPROVE")], HEAD)
        self.assertEqual((s["state"], s["reviewer"]), ("pass", "glm"))

    def test_reject_and_revise_are_findings_never_fail(self):
        for v in ("REJECT", "REVISE"):
            s = ars.combine([r("muse", None), r("glm", v)], HEAD)
            self.assertEqual((s["state"], s["reviewer"]), ("findings", "glm"))
        for rows in ([], [r("muse", None)], [r("muse", "REJECT"), r("glm", "REJECT")]):
            self.assertIn(ars.combine(rows, HEAD)["state"], ("pass", "findings", "neutral"))

    def test_unavailable_or_stale_is_neutral(self):
        self.assertEqual(ars.combine([r("muse", None)], HEAD)["state"], "neutral")
        self.assertEqual(ars.combine([r("muse", "REJECT", head="b" * 40)], HEAD)["state"], "neutral")

    def test_first_finished_verdict_decides(self):
        s = ars.combine([r("deepseek", None), r("stepfun", "APPROVE"), r("muse", "REJECT")], HEAD)
        self.assertEqual((s["state"], s["reviewer"]), ("pass", "stepfun"))

    def test_rotation_is_pr_mod_4_with_fallthrough(self):
        self.assertEqual(ars.rotation(8), ["muse", "glm", "deepseek", "stepfun"])
        self.assertEqual(ars.rotation(2045), ["glm", "deepseek", "stepfun", "muse"])
        self.assertEqual(ars.rotation(3)[0], "stepfun")
        out = subprocess.run([sys.executable, SCRIPT, "--rotation", "6"], capture_output=True,
                             text=True, check=True).stdout.split()
        self.assertEqual(out, ["deepseek", "stepfun", "muse", "glm"])

    def test_docs_only_classifier(self):
        yes = [["README.md"], ["docs/x.json", "HANDOFF.d/a.txt", "a/b/NOTES.md"], ["docs/plan_x.md"]]
        no = [[], ["plan_simple-reviewer-rebuild.md"], ["IMPLEMENTATION-PLAN.md"],
              ["README.md", "bin/x"], ["sub/plan_y.md"], [".github/workflows/a.yml"]]
        for paths in yes:
            self.assertTrue(ars.is_docs_only(paths), paths)
        for paths in no:
            self.assertFalse(ars.is_docs_only(paths), paths)
        with tempfile.TemporaryDirectory() as t:
            lst = os.path.join(t, "files")
            with open(lst, "w") as fh:
                fh.write("README.md\ndocs/a.md\n")
            out = subprocess.run([sys.executable, SCRIPT, "--docs-only", lst], capture_output=True,
                                 text=True, check=True).stdout.strip()
            self.assertEqual(out, "true")

    def test_combine_cli_and_comment(self):
        with tempfile.TemporaryDirectory() as t:
            paths = []
            for row in (r("muse", None), r("glm", "REVISE")):
                p = os.path.join(t, row["provider"] + ".json")
                with open(p, "w") as fh:
                    json.dump(row, fh)
                paths.append(p)
            paths.append(os.path.join(t, "stepfun.json"))  # missing result
            comment = os.path.join(t, "comment.md")
            out = subprocess.run([sys.executable, SCRIPT, "--combine", *paths, "--head", HEAD,
                                  "--comment-out", comment], capture_output=True, text=True,
                                 env=dict(os.environ, AI_GH_SIGNATURE="-- sig"), check=True)
            summary = json.loads(out.stdout)
            self.assertEqual((summary["state"], summary["reviewer"]), ("findings", "glm"))
            with open(comment) as fh:
                body = fh.read()
            self.assertIn("| stepfun | unavailable |", body)
            self.assertIn("Unavailable: result missing", body)
            self.assertIn("**Outcome: findings.** Review is advisory", body)
            self.assertIn("review-finding", body)
            self.assertTrue(body.rstrip().endswith("-- sig"))

    def test_comment_findings_cannot_close_details_or_leak(self):
        row = r("muse", None)
        row["error"] = "no verdict: API_KEY=sk-live-123456 Bearer abc.def"
        bad = r("glm", "REVISE")
        bad["findings"] = "x</details><b>escape</b>"
        body = ars.render_comment(ars.combine([row, bad], HEAD), HEAD)
        self.assertNotIn("sk-live-123456", body)
        self.assertNotIn("abc.def", body)
        self.assertEqual(body.count("</details>"), 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
