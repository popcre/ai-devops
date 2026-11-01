#!/usr/bin/env python3
"""Data-only HANDLE dispatch preserves output/status and ordinary qualification."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class EventDispatch(unittest.TestCase):
    def execute(self, platform, handle, helper=True, writer_status=0):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            collector = directory / "telemetry.sh"
            shutil.copyfile(ROOT / "tools/github-requests/telemetry.sh", collector)
            capture = directory / "captured.json"
            if helper:
                (directory / "windows_event.py").write_text(
                    "import json,os,sys\nfrom pathlib import Path\n"
                    "row=json.loads(sys.stdin.readline())\n"
                    "Path(os.environ['EVENT_TEST_CAPTURE']).write_text(json.dumps(row))\n"
                    f"sys.exit({writer_status})\n")
            result = subprocess.run(["bash", "-c", 'OSTYPE="$2"; source "$1"; gh_measure_workflow_evidence ai-pr-wait pr_wait aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; printf ORIGINAL',
                                     "bash", str(collector), platform],
                                    env=dict(os.environ, AI_GH_STATE_DIR=str(directory / "state"),
                                             AI_GH_QUALIFICATION_EVENT_HANDLE=handle, EVENT_TEST_CAPTURE=str(capture)),
                                    capture_output=True, text=True, timeout=4)
            row = json.loads(capture.read_text()) if capture.exists() else None
            return result, row

    def test_windows_route_transports_only_unqualified_fixed_schema(self):
        result, row = self.execute("msys", "123456")
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "ORIGINAL")
        self.assertEqual(row["schema"], 4)
        self.assertEqual(row["source_verified"], "unknown")
        self.assertEqual(row["clock_quality"], "unknown")
        self.assertIsNone(row["latency_ms"])
        self.assertNotIn("123456", json.dumps(row))

    def test_writer_failure_and_missing_helper_preserve_normal_capability(self):
        for helper, status in ((True, 1), (False, 0)):
            result, _ = self.execute("msys", "123456", helper, status)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "ORIGINAL")

    def test_non_windows_or_untrusted_handle_cannot_select_native_writer(self):
        for platform, handle in (("linux-gnu", "123456"), ("msys", "private-value"),
                                 ("msys", "1" * 21)):
            result, row = self.execute(platform, handle)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "ORIGINAL")
            self.assertIsNone(row)


if __name__ == "__main__": unittest.main()
