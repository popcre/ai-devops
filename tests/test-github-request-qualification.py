#!/usr/bin/env python3
"""Live-parent source custody and bounded event-time evidence for #658."""
import hashlib
import importlib.util
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/github-requests"))
import report


def event():
    now = time.time_ns() // 1_000_000
    return {"schema": 4, "utc": "2026-10-31T00:00:00Z", "measurement": "workflow_evidence",
            "caller": "ai-pr-wait", "workflow": "pr_wait", "workflow_id": "a" * 32,
            "cohort_id": None, "target_ordinal": None, "source_verified": "unknown",
            "source_fingerprint_start": None, "source_fingerprint_end": None,
            "install_generation_binding": None, "event_kind": "pr_merged",
            "eligible_utc_ms": now // 1000 * 1000, "observed_utc_ms": now,
            "delivered_utc_ms": now, "delivery_boundary": "terminal_report",
            "clock_quality": "unknown", "clock_error_bound_ms": None,
            "latency_ms": None, "unknown_reason": "metadata_absent"}


class EventTests(unittest.TestCase):
    def clocks(self):
        now = time.time_ns() // 1_000_000
        return ({"wall_ms": now - 100, "monotonic_ms": 1000, "error_bound_ms": 10},
                {"wall_ms": now + 100, "monotonic_ms": 1200, "error_bound_ms": 20})

    def test_live_interval_includes_host_and_server_timestamp_uncertainty(self):
        start, end = self.clocks()
        row = event()
        result = report.qualify_event(row, start, end, True)
        self.assertEqual(result["clock_quality"], "host_bound_github_utc_assumed")
        self.assertEqual(result["clock_error_bound_ms"], 1032)
        elapsed = row["delivered_utc_ms"] - row["eligible_utc_ms"]
        self.assertEqual(result["latency_lower_ms"], max(0, elapsed - 1032))
        self.assertEqual(result["latency_upper_ms"], elapsed + 1032)

    def test_clock_missing_source_missing_jump_and_invalid_event_stay_unknown(self):
        start, end = self.clocks()
        self.assertEqual(report.qualify_event(event(), start, end, False)["unknown_reason"], "source_unknown")
        self.assertEqual(report.qualify_event(event(), None, end, True)["unknown_reason"], "clock_unknown")
        moved = dict(end, wall_ms=end["wall_ms"] + 10000)
        self.assertEqual(report.qualify_event(event(), start, moved, True)["unknown_reason"], "clock_jump")
        row = event(); row["delivered_utc_ms"] = end["wall_ms"] + 2000
        self.assertEqual(report.qualify_event(row, start, end, True)["unknown_reason"], "event_invalid")
        row = event(); row["source_verified"] = "verified"
        self.assertFalse(report.unqualified_event(row))
        self.assertEqual(report.qualify_event(row, start, end, True)["unknown_reason"], "event_unknown")

    def test_unknown_delivery_and_forged_non_numeric_pipe_data(self):
        start, end = self.clocks()
        row = event(); row["delivery_boundary"] = "unknown"; row["delivered_utc_ms"] = None
        self.assertEqual(report.qualify_event(row, start, end, True)["unknown_reason"], "event_unknown")
        for name, value in (("eligible_utc_ms", "private-response"), ("observed_utc_ms", True),
                            ("workflow_id", "token"), ("unknown_reason", "private-response")):
            row = event(); row[name] = value
            self.assertFalse(report.unqualified_event(row))

    def test_clock_query_is_readonly_and_unsynchronized_clock_is_unknown(self):
        class Library:
            def adjtimex(self, pointer):
                self.modes = pointer._obj.modes
                pointer._obj.maxerror = 1000
                pointer._obj.status = 0x40
                return 5
        class Function:
            def __init__(self, library): self.library = library
            def __call__(self, pointer): return self.library.adjtimex(pointer)
        library = Library(); function = Function(library)
        wrapper = type("Wrapper", (), {"adjtimex": function})()
        with mock.patch.object(report.ctypes, "CDLL", return_value=wrapper):
            self.assertIsNone(report.qualification_clock())
        self.assertEqual(library.modes, 0)

    def test_command_receipts_do_not_invent_remote_useful_completions(self):
        with tempfile.TemporaryDirectory() as directory:
            rows = []
            for index, labels in enumerate(sorted(report.RECEIPT_LABELS)):
                caller, workflow, outcome = labels
                rows.append({"schema": 3, "utc": "2026-10-31T00:00:00Z", "measurement": "workflow_outcome",
                             "caller": caller, "workflow": workflow, "outcome": outcome,
                             "workflow_id": f"{index:032x}", "elapsed_ms": 3})
            path = Path(directory) / "2026-10-31.jsonl"
            path.write_text("".join(json.dumps(row) + "\n" for row in rows))
            result = report.summarize(directory)
            self.assertEqual(result["completed_workflow_receipts"], 6)
            self.assertTrue(any(row["outcome"] == "skipped" for row in result["workflow_outcomes"]))
            rows[-1]["outcome"] = "private-response"
            path.write_text("".join(json.dumps(row) + "\n" for row in rows))
            with self.assertRaises(ValueError): report.summarize(directory)

    def test_collector_exact_operation_allowlists_and_opaque_ids(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = dict(os.environ, AI_GH_STATE_DIR=directory)
            collector = str(ROOT / "tools/github-requests/telemetry.sh")
            for index, (caller, workflow, outcome) in enumerate(sorted(report.RECEIPT_LABELS)):
                result = subprocess.run(["bash", "-c", 'source "$1"; shift; gh_measure_workflow_outcome "$@"',
                                         "bash", collector, caller, workflow, f"{index:032x}", outcome, "3"],
                                        env=environment, capture_output=True)
                self.assertEqual(result.returncode, 0, (caller, workflow, outcome))
            result = subprocess.run(["bash", "-c", 'source "$1"; shift; gh_measure_workflow_outcome "$@"',
                                     "bash", collector, "ai-verify-run", "verify_dispatch", "private-target", "dispatched", "3"],
                                    env=environment, capture_output=True)
            self.assertEqual(result.returncode, 2)
            summary = report.summarize(Path(directory) / "measurements")
            self.assertEqual(summary["completed_workflow_receipts"], 6)


class ParentTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name) / "source"
        for directory in ("bin", "tools", "config"):
            (self.root / directory).mkdir(parents=True, exist_ok=True)
        self.waiter = self.root / "bin/ai-pr-wait"
        self.waiter.write_text("""#!/usr/bin/env bash
printf 'ORIGINAL terminal output\\n'
printf 'ORIGINAL diagnostic\\n' >&2
if [[ "${AI_GH_QUALIFICATION_EVENT_FD:-}" =~ ^[0-9]+$ ]]; then
  python3 - "$AI_GH_QUALIFICATION_EVENT_FD" <<'PY'
import json,os,sys,time
now=time.time_ns()//1000000
row=EVENT_PLACEHOLDER
row.update(eligible_utc_ms=now//1000*1000,observed_utc_ms=now,delivered_utc_ms=now)
os.write(int(sys.argv[1]),(json.dumps(row)+'\\n').encode())
PY
fi
exit "${1:-0}"
""".replace("EVENT_PLACEHOLDER", repr(event())))
        self.waiter.chmod(0o755)
        self.git("init", "-q")
        self.git("add", "bin", "tools", "config")
        self.git("-c", "user.name=Albert Hazan", "-c", "user.email=u2giants@users.noreply.github.com",
                 "commit", "-qm", "qualification fixture")
        self.sha = self.git("rev-parse", "HEAD").strip()
        self.launcher = Path(self.temp.name) / "installed-waiter"
        self.launcher.symlink_to(self.waiter)
        self.manifest = Path(self.temp.name) / "install-manifest.tsv"
        self.manifest.write_text(f"meta\tsource_sha\t{self.sha}\t-\nsymlink\t{self.launcher.parent / 'ai-pr-wait'}\t{self.waiter}\t{hashlib.sha256(self.waiter.read_bytes()).hexdigest()}\n")
        (self.launcher.parent / "ai-pr-wait").symlink_to(self.waiter)
        self.manifest.chmod(0o600)

    def tearDown(self): self.temp.cleanup()

    def git(self, *arguments):
        return subprocess.run(["git", "-C", str(self.root), *arguments], check=True,
                              capture_output=True, text=True).stdout

    def run_parent(self, status=0, extra_env=None, receipt=None):
        receipt = receipt or Path(self.temp.name) / f"receipt-{status}.json"
        environment = os.environ.copy(); environment.update(extra_env or {})
        result = subprocess.run([sys.executable, str(ROOT / "tools/github-requests/report.py"),
                                 "--qualify-wait", "--source-root", str(self.root),
                                 "--manifest", str(self.manifest), "--receipt", str(receipt),
                                 "--", str(status)], capture_output=True, text=True, env=environment,
                                timeout=30)
        text = receipt.read_text() if receipt.exists() else ""
        return result, json.loads(text) if text.startswith("{") else None

    def test_manifest_duplicate_tampered_symlink_and_moving_launcher_refused(self):
        identity, files = report.installed_source(self.root, self.manifest)
        self.assertEqual(identity["source_sha"], self.sha)
        self.assertIn("bin/ai-pr-wait", files)
        original = self.manifest.read_text()
        for bad in (original + f"meta\tsource_sha\t{self.sha}\t-\n",
                    original.replace(hashlib.sha256(self.waiter.read_bytes()).hexdigest(), "0" * 64)):
            self.manifest.write_text(bad)
            with self.assertRaises(ValueError): report.installed_source(self.root, self.manifest)
        self.manifest.write_text(original); self.manifest.chmod(0o644)
        with self.assertRaises(ValueError): report.installed_source(self.root, self.manifest)
        self.manifest.chmod(0o600)
        linked = self.manifest.with_name("linked.tsv"); linked.symlink_to(self.manifest)
        with self.assertRaises(OSError): report.installed_source(self.root, linked)
        launcher = self.launcher.parent / "ai-pr-wait"
        launcher.unlink(); launcher.symlink_to(ROOT / "bin/ai-gh")
        with self.assertRaises(ValueError): report.installed_source(self.root, self.manifest)

    def test_missing_manifest_preserves_stdout_stderr_status_and_unknown_source(self):
        self.manifest.unlink()
        result, receipt = self.run_parent(7, {"PR_WAIT_SOURCE_VERIFIED": "verified", "PR_WAIT_CLOCK_QUALITY": "verified_bound"})
        self.assertEqual(result.returncode, 7)
        self.assertEqual(result.stdout, "ORIGINAL terminal output\n")
        self.assertEqual(result.stderr, "ORIGINAL diagnostic\n")
        self.assertEqual(receipt["source_verified"], "unknown")
        self.assertIsNone(receipt["event"])

    def test_ambient_source_injection_never_becomes_verified(self):
        for name in ("BASH_ENV", "ENV", "PYTHONPATH", "LD_PRELOAD", "BASH_FUNC_fake%%"):
            with mock.patch.dict(os.environ, {name: "injected"}):
                with self.assertRaises(ValueError):
                    with report.retained_generation(self.root, self.manifest):
                        self.fail("ambient startup code was qualified")

    @unittest.skipUnless(sys.platform.startswith("linux") and shutil.which("bwrap"),
                         "Linux Bubblewrap source boundary required")
    def test_live_sealed_generation_ignores_original_source_replacement(self):
        original = report.installed_source
        def replaced(root, manifest):
            result = original(root, manifest)
            self.waiter.write_text("#!/usr/bin/env bash\nprintf 'REPLACED\\n'\nexit 9\n")
            return result
        receipt = Path(self.temp.name) / "sealed.json"
        with mock.patch.object(report, "installed_source", side_effect=replaced):
            status = report.qualify_wait(self.root, self.manifest, ["0"], receipt)
        self.assertEqual(status, 0)
        row = json.loads(receipt.read_text())
        self.assertEqual(row["source_verified"], "verified")
        self.assertEqual(row["source_sha"], self.sha)
        self.assertEqual(row["event"]["event_kind"], "pr_merged")
        self.assertEqual(self.waiter.read_text().splitlines()[-1], "exit 9")

    def test_receipt_failure_keeps_original_status(self):
        self.manifest.unlink()
        occupied = Path(self.temp.name) / "occupied.json"; occupied.write_text("KEEP")
        result, _ = self.run_parent(4, receipt=occupied)
        self.assertEqual(result.returncode, 4)
        self.assertEqual(occupied.read_text(), "KEEP")

    def test_sealed_bytes_reject_write_and_namespace_cannot_create_unbound_helper(self):
        if not sys.platform.startswith("linux") or not shutil.which("bwrap"):
            self.skipTest("Linux Bubblewrap source boundary required")
        descriptor = report.sealed_source(b"immutable")
        try:
            with self.assertRaises(OSError): os.write(descriptor, b"changed")
        finally:
            os.close(descriptor)
        (self.root / "tools/UNTRACKED").write_text("private local helper")
        with report.retained_generation(self.root, self.manifest) as generation:
            result = subprocess.run([*generation["argv_prefix"], generation["bash_path"], "-c",
                                     'test ! -e "$1/tools/UNTRACKED" && ! touch "$1/tools/ADDED"', "bash", str(self.root)],
                                    pass_fds=generation["pass_fds"], capture_output=True)
            self.assertEqual(result.returncode, 0)
        self.assertFalse((self.root / "tools/ADDED").exists())


if __name__ == "__main__":
    unittest.main()
