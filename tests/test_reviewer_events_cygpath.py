#!/usr/bin/env python3
"""find_passing_report must fall through to the next candidate on cygpath failure.

Regression for the DeepSeek final-check finding on e8584976: an unguarded
subprocess.run(["cygpath", ...]) raised FileNotFoundError/TimeoutExpired and
aborted the whole approval lookup instead of trying the next candidate.
Codex Low follow-up: the fall-through test must observe the next candidate
being returned, not merely that the call does not raise.
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import reviewer_events as events  # noqa: E402


def write_record(runs, provider, run_id, report_path, report_body, **overrides):
    report_path = Path(report_path)
    report_path.write_text(report_body, encoding="utf-8")
    row = {
        "schema_version": 1,
        "status": "completed",
        "verdict": "APPROVE",
        "stale": False,
        "failure_class": None,
        "head": "a" * 40,
        "source_digest": "b" * 64,
        "repository_key": "c" * 64,
        "provider": provider,
        "review_mode": "final-check",
        "run_id": run_id,
        "report_path": str(report_path),
        "report_sha256": events.digest(report_path.read_bytes()),
        "finished_at": "2026-10-12T00:00:00Z",
    }
    row.update(overrides)
    out = runs / provider / "zcode" / f"{run_id}.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(row), encoding="utf-8")
    return out


REPORT_BODY = (
    "# deepseek final-check\n\n"
    "| reviewed commit | `" + "a" * 40 + "` |\n"
    "| source digest | `" + "b" * 64 + "` |\n\n"
    "## Verdict\nAPPROVE\n"
)


@unittest.skipUnless(os.name == "nt", "cygpath conversion is a Windows concern")
class CygpathFallThrough(unittest.TestCase):
    def setUp(self):
        self.state = Path(tempfile.mkdtemp(prefix="cygpath-fallthrough-"))
        self.runs = self.state / "runs" / ("c" * 64)
        self.report_dir = self.state / "reports"
        self.report_dir.mkdir()

    def tearDown(self):
        import shutil
        shutil.rmtree(self.state, ignore_errors=True)

    def lookup(self, patch_subprocess):
        with mock.patch.object(events.subprocess, "run", side_effect=patch_subprocess):
            with mock.patch.object(events.os, "name", "nt"):
                return events.find_passing_report(
                    self.state, "any", "final-check", "a" * 40, "b" * 64, "c" * 64
                )

    def test_cygpath_failure_falls_through_to_next_candidate(self):
        """A cygpath failure on one candidate must yield the next candidate.

        Both records are otherwise valid APPROVEs. The first would win (later
        finished_at) if cygpath converted its POSIX report path. The second
        keeps a native Windows path and needs no conversion. Asserting the
        second is returned — not None — fails if find_passing_report returns
        early instead of continuing.
        """
        first = self.report_dir / "deepseek-final-check-1.md"
        second = self.report_dir / "deepseek-final-check-2.md"
        # Later finished_at: first would be selected if its path resolved.
        write_record(self.runs, "deepseek", "1", first, REPORT_BODY,
                     finished_at="2026-10-12T02:00:00Z")
        write_record(self.runs, "deepseek", "2", second, REPORT_BODY,
                     finished_at="2026-10-12T01:00:00Z")
        # Only the first candidate takes the /path cygpath branch.
        node = self.runs / "deepseek" / "zcode" / "1.json"
        row = json.loads(node.read_text())
        row["report_path"] = "/tmp/generic/" + first.name
        node.write_text(json.dumps(row))

        def fake_run(cmd, **kwargs):
            if cmd and cmd[0] == "cygpath":
                # Scoped to the first candidate: only its path is POSIX.
                self.assertIn("deepseek-final-check-1", cmd[-1])
                raise FileNotFoundError("cygpath")
            raise AssertionError(f"unexpected subprocess {cmd}")

        result = self.lookup(fake_run)
        self.assertIsNotNone(
            result,
            "lookup must fall through past a cygpath failure to the next candidate",
        )
        self.assertEqual(result["run_id"], "2")
        self.assertEqual(result["report"], str(second))

    def test_cygpath_timeout_skips_candidate(self):
        first = self.report_dir / "deepseek-final-check-1.md"
        write_record(self.runs, "deepseek", "1", first, REPORT_BODY)
        node = next((self.runs / "deepseek" / "zcode").glob("*.json"))
        row = json.loads(node.read_text())
        row["report_path"] = "/tmp/generic/deepseek-final-check-1.md"
        node.write_text(json.dumps(row))

        def fake_run(cmd, **kwargs):
            if cmd and cmd[0] == "cygpath":
                raise subprocess.TimeoutExpired(cmd=cmd, timeout=kwargs.get("timeout", 5))
            raise AssertionError(f"unexpected subprocess {cmd}")

        result = self.lookup(fake_run)
        self.assertIsNone(result)

    def test_cygpath_nonzero_exit_skips_candidate(self):
        first = self.report_dir / "deepseek-final-check-1.md"
        write_record(self.runs, "deepseek", "1", first, REPORT_BODY)
        node = next((self.runs / "deepseek" / "zcode").glob("*.json"))
        row = json.loads(node.read_text())
        row["report_path"] = "/tmp/generic/deepseek-final-check-1.md"
        node.write_text(json.dumps(row))

        def fake_run(cmd, **kwargs):
            if cmd and cmd[0] == "cygpath":
                return subprocess.CompletedProcess(cmd, 1, stdout="", stderr="boom")
            raise AssertionError(f"unexpected subprocess {cmd}")

        result = self.lookup(fake_run)
        self.assertIsNone(result)


class CygpathBound(unittest.TestCase):
    def test_cygpath_invocation_is_bounded(self):
        source = (ROOT / "tools" / "reviewer_events.py").read_text(encoding="utf-8")
        self.assertIn('["cygpath", "-w", report]', source)
        self.assertIn("subprocess.SubprocessError", source)
        self.assertIn("OSError", source)
        # The timeout must stay bounded well below the old 30s hang window.
        self.assertIn("timeout=5", source)


if __name__ == "__main__":
    unittest.main()
