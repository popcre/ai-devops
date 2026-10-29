#!/usr/bin/env python3
"""Tests for the ai-review merge rule (plan_simple-reviewer-rebuild.md section 8)."""
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
    def test_two_approve_one_reject_passes(self):
        s = ars.combine([r("muse", "APPROVE"), r("glm", "APPROVE"), r("deepseek", "REJECT"), r("stepfun", None)], HEAD)
        self.assertEqual(s["state"], "pass")
        self.assertTrue(s["lone_reject"])

    def test_one_approve_two_reject_fails(self):
        s = ars.combine([r("muse", "APPROVE"), r("glm", "REJECT"), r("deepseek", "REJECT"), r("stepfun", None)], HEAD)
        self.assertEqual(s["state"], "fail")

    def test_one_finished_is_neutral(self):
        s = ars.combine([r("muse", "APPROVE"), r("glm", None), r("deepseek", None), r("stepfun", None)], HEAD)
        self.assertEqual((s["state"], s["finished"]), ("neutral", 1))
        stale = ars.combine([r("muse", "APPROVE"), r("glm", "APPROVE", head="b" * 40)], HEAD)
        self.assertEqual(stale["state"], "neutral")

    def test_revise_counts_as_reject(self):
        s = ars.combine([r("muse", "APPROVE"), r("glm", "REVISE"), r("deepseek", "REVISE"), r("stepfun", "APPROVE")], HEAD)
        self.assertEqual((s["state"], s["reject"]), ("fail", 2))

    def test_combine_cli_and_comment(self):
        with tempfile.TemporaryDirectory() as t:
            paths = []
            for row in (r("muse", "APPROVE"), r("glm", "APPROVE"), r("deepseek", "REVISE")):
                p = os.path.join(t, row["provider"] + ".json")
                with open(p, "w") as fh:
                    json.dump(row, fh)
                paths.append(p)
            paths.append(os.path.join(t, "stepfun.json"))  # missing result
            comment = os.path.join(t, "comment.md")
            out = subprocess.run([sys.executable, SCRIPT, "--combine", *paths, "--head", HEAD,
                                  "--comment-out", comment], capture_output=True, text=True,
                                 env=dict(os.environ, AI_GH_SIGNATURE="-- sig"), check=True)
            self.assertEqual(json.loads(out.stdout)["state"], "pass")
            with open(comment) as fh:
                body = fh.read()
            self.assertIn("| stepfun | unavailable |", body)
            self.assertTrue(body.rstrip().endswith("-- sig"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
