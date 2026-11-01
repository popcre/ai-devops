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
import signal
import selectors
from contextlib import contextmanager
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/github-requests"))
import report
import measure_append


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


def receipt_fixture(caller, workflow, outcome, identifier):
    row = {"schema": 3, "utc": "2026-10-31T00:00:00Z", "measurement": "workflow_outcome",
           "caller": caller, "workflow": workflow, "outcome": outcome,
           "workflow_id": identifier, "elapsed_ms": 3}
    if workflow in report.ACTIVE_RECEIPT_BOUNDARIES:
        attempted, succeeded, failed, skipped = {
            "completed": (1, 1, 0, 0), "partial": (2, 1, 1, 0), "failed": (1, 0, 1, 0),
            "skipped": (0, 0, 0, 1), "process_succeeded": (1, 1, 0, 0),
            "process_failed": (1, 0, 1, 0), "refused": (1, 0, 0, 1),
        }[outcome]
        row.update(boundary=report.ACTIVE_RECEIPT_BOUNDARIES[workflow], attempted_count=attempted,
                   succeeded_count=succeeded, failed_count=failed, skipped_count=skipped,
                   parent_workflow_id=None)
    return row


class EventTests(unittest.TestCase):
    def test_unsupported_native_event_pipe_is_explicitly_unknown(self):
        with mock.patch.object(measure_append.sys, "platform", "win32"):
            self.assertFalse(measure_append.write_event_fd(3, "{}"))
            self.assertIsNone(report.qualification_clock())

    def clocks(self):
        now = time.time_ns() // 1_000_000
        return ({"wall_ms": now - 2000, "monotonic_ms": 1000, "error_bound_ms": 10},
                {"wall_ms": now + 100, "monotonic_ms": 3100, "error_bound_ms": 20})

    def test_preexisting_or_start_overlapping_eligibility_is_not_detection(self):
        start, end = self.clocks()
        row = event()
        for eligible in (start["wall_ms"] - 2000, start["wall_ms"] + 5):
            row["eligible_utc_ms"] = eligible
            result = report.qualify_event(row, start, end, True)
            self.assertEqual(result["unknown_reason"], "eligibility_not_observed")
            self.assertIsNone(result["latency_lower_ms"])
            self.assertIsNone(result["latency_upper_ms"])

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

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux kernel clock API")
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
                rows.append(receipt_fixture(caller, workflow, outcome, f"{index:032x}"))
            path = Path(directory) / "2026-10-31.jsonl"
            path.write_text("".join(json.dumps(row) + "\n" for row in rows))
            result = report.summarize(directory)
            self.assertEqual(result["completed_workflow_receipts"], 6)
            self.assertEqual(sum(row["successful_active_operations"]
                                 for row in result["active_blocker_watch_operations"]), 3)
            self.assertTrue(any(row["outcome"] == "skipped" for row in result["workflow_outcomes"]))
            rows[-1]["outcome"] = "private-response"
            path.write_text("".join(json.dumps(row) + "\n" for row in rows))
            with self.assertRaises(ValueError): report.summarize(directory)

    def test_collector_exact_operation_allowlists_and_opaque_ids(self):
        with tempfile.TemporaryDirectory() as directory:
            environment = dict(os.environ, AI_GH_STATE_DIR=directory)
            collector = str(ROOT / "tools/github-requests/telemetry.sh")
            for index, (caller, workflow, outcome) in enumerate(sorted(report.RECEIPT_LABELS)):
                row = receipt_fixture(caller, workflow, outcome, f"{index:032x}")
                arguments = [caller, workflow, row["workflow_id"], outcome, "3"]
                if workflow in report.ACTIVE_RECEIPT_BOUNDARIES:
                    arguments += [row["boundary"], *[str(row[name]) for name in
                                  ("attempted_count", "succeeded_count", "failed_count", "skipped_count")], ""]
                result = subprocess.run(["bash", "-c", 'source "$1"; shift; gh_measure_workflow_outcome "$@"',
                                         "bash", collector, *arguments],
                                        env=environment, capture_output=True)
                self.assertEqual(result.returncode, 0, (caller, workflow, outcome))
            result = subprocess.run(["bash", "-c", 'source "$1"; shift; gh_measure_workflow_outcome "$@"',
                                     "bash", collector, "ai-verify-run", "verify_dispatch", "private-target", "dispatched", "3"],
                                    env=environment, capture_output=True)
            self.assertEqual(result.returncode, 2)
            # New active labels cannot silently reuse the old receipt shape.
            result = subprocess.run(["bash", "-c", 'source "$1"; shift; gh_measure_workflow_outcome "$@"',
                                     "bash", collector, "ai-blocker-watch", "blocker_watch_alarm", "a" * 32,
                                     "completed", "3"], env=environment, capture_output=True)
            self.assertEqual(result.returncode, 2)
            summary = report.summarize(Path(directory) / "measurements")
            self.assertEqual(summary["completed_workflow_receipts"], 6)

    def test_fixed_gate_and_fixer_callers_do_not_widen_arbitrary_labels(self):
        collector = str(ROOT / "tools/github-requests/telemetry.sh")
        for caller, expected in (("ai-task-gates", "ai-task-gates"), ("review-fixer", "review-fixer"),
                                 ("review-fixer:private-target", "unknown")):
            result = subprocess.run(["bash", "-c", 'source "$1"; gh_measure_init api graphql; printf "%s" "$GH_MEASURE_CALLER"',
                                     "bash", collector], env=dict(os.environ, AI_GH_CALLER=caller),
                                    capture_output=True, text=True, check=True)
            self.assertEqual(result.stdout, expected)
        self.assertIn("ai-task-gates", report.CALLERS)
        self.assertIn("review-fixer", report.CALLERS)
        self.assertNotIn("review-fixer:private-target", report.CALLERS)

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux inherited-pipe boundary")
    def test_optional_event_pipe_full_or_closed_is_nonblocking_and_preserves_flags(self):
        import fcntl
        read_fd, write_fd = os.pipe()
        try:
            original = fcntl.fcntl(write_fd, fcntl.F_GETFL)
            os.set_blocking(write_fd, False)
            while True:
                try: os.write(write_fd, b"x" * 4096)
                except BlockingIOError: break
            os.set_blocking(write_fd, True)
            start = time.monotonic()
            self.assertFalse(measure_append.write_event_fd(write_fd, "{}"))
            self.assertLess(time.monotonic() - start, 0.5)
            self.assertEqual(fcntl.fcntl(write_fd, fcntl.F_GETFL), original)
            with tempfile.TemporaryDirectory() as directory:
                result = subprocess.run(["bash", "-c", 'source "$1"; gh_measure_workflow_evidence ai-pr-wait pr_wait aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa; printf OK',
                                         "bash", str(ROOT / "tools/github-requests/telemetry.sh")],
                                        env=dict(os.environ, AI_GH_STATE_DIR=directory,
                                                 AI_GH_QUALIFICATION_EVENT_FD=str(write_fd)),
                                        pass_fds=(write_fd,), capture_output=True, text=True, timeout=3)
                self.assertEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "OK")
            os.close(read_fd); read_fd = None
            self.assertFalse(measure_append.write_event_fd(write_fd, "{}"))
            self.assertEqual(fcntl.fcntl(write_fd, fcntl.F_GETFL), original)
            self.assertFalse(measure_append.write_event_fd(1, "{}"))
            self.assertFalse(measure_append.write_event_fd(write_fd, "x" * 4096))
        finally:
            if read_fd is not None: os.close(read_fd)
            os.close(write_fd)


@unittest.skipUnless(sys.platform.startswith("linux"), "Linux sealed source; native Windows has its own custody suite")
class ParentTests(unittest.TestCase):
    def setUp(self):
        self.native_git = None
        for candidate in ("/usr/bin/git", "/bin/git", shutil.which("git")):
            if candidate is None:
                continue
            try:
                self.native_git = report.trusted_boundary_executable(candidate)
                break
            except (OSError, ValueError):
                continue
        if self.native_git is None:
            raise RuntimeError("Qualification fixture requires an existing root-trusted native Git")
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
        (self.root / "tools/helper.py").write_text("ORIGINAL_HELPER = True\n")
        (self.root / ".gitattributes").write_text("*.cmd text eol=crlf\n")
        (self.root / "bin/windows-fixture.cmd").write_bytes(b"@echo off\r\nexit /b 0\r\n")
        self.git("init", "-q")
        self.git("add", "bin", "tools", "config", ".gitattributes")
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
        return subprocess.run([self.native_git, "-C", str(self.root), *arguments], check=True,
                              capture_output=True, text=True).stdout

    @contextmanager
    def fixture_installation(self):
        # Only tests substitute the protected canonical-I/O boundary. There
        # is no production flag/environment path to bless this private file.
        # Hosted images may put a mutable /usr/local Git before the distro Git.
        # This synthetic positive fixture selects an actually validated native
        # prerequisite; production keeps refusing the original untrusted PATH.
        path = str(Path(self.native_git).parent) + os.pathsep + os.environ.get("PATH", "")
        with mock.patch.dict(os.environ, {"PATH": path}), mock.patch.object(
                report, "canonical_installation",
                side_effect=lambda root, manifest: (Path(manifest).read_bytes(),
                                                   self.launcher.parent / "ai-pr-wait")):
            yield

    def test_fixture_trusted_git_does_not_bless_original_untrusted_path(self):
        shadow_directory = Path(self.temp.name) / "mutable-bin"
        shadow_directory.mkdir()
        shadow = shadow_directory / "git"
        shadow.write_text("#!/bin/sh\nexit 89\n")
        shadow.chmod(0o755)
        path = str(shadow_directory) + os.pathsep + os.environ.get("PATH", "")
        with mock.patch.dict(os.environ, {"PATH": path}):
            self.assertTrue(Path(shutil.which("git")).samefile(shadow))
            with self.fixture_installation():
                self.assertTrue(Path(shutil.which("git")).samefile(self.native_git))
                identity, _ = report.installed_source(self.root, self.manifest)
                self.assertEqual(identity["source_sha"], self.sha)
            self.assertEqual(os.environ["PATH"], path)
            self.assertTrue(Path(shutil.which("git")).samefile(shadow))
            with mock.patch.object(report, "canonical_installation", return_value=(
                    self.manifest.read_bytes(), self.launcher.parent / "ai-pr-wait")):
                with self.assertRaisesRegex(ValueError, "boundary executable ancestor is untrusted"):
                    report.installed_source(self.root, self.manifest)

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
        with self.fixture_installation():
            identity, files = report.installed_source(self.root, self.manifest)
        self.assertEqual(identity["source_sha"], self.sha)
        self.assertNotEqual(identity["source_fingerprint"], identity["loaded_source_fingerprint"])
        self.assertIn("bin/ai-pr-wait", files)
        original = self.manifest.read_text()
        for bad in (original + f"meta\tsource_sha\t{self.sha}\t-\n",
                    original.replace(hashlib.sha256(self.waiter.read_bytes()).hexdigest(), "0" * 64)):
            self.manifest.write_text(bad)
            with self.fixture_installation(), self.assertRaises(ValueError):
                report.installed_source(self.root, self.manifest)
        self.manifest.write_text(original); self.manifest.chmod(0o644)
        with self.assertRaises((OSError, ValueError)): report.installed_source(self.root, self.manifest)
        self.manifest.chmod(0o600)
        linked = self.manifest.with_name("linked.tsv"); linked.symlink_to(self.manifest)
        with self.assertRaises((OSError, ValueError)): report.installed_source(self.root, linked)
        launcher = self.launcher.parent / "ai-pr-wait"
        launcher.unlink(); launcher.symlink_to(ROOT / "bin/ai-gh")
        with self.assertRaises((OSError, ValueError)): report.installed_source(self.root, self.manifest)

    def test_arbitrary_owner_private_manifest_cannot_certify_installation(self):
        with self.assertRaises((ValueError, OSError)):
            report.installed_source(self.root, self.manifest)

    def test_missing_canonical_installation_never_certifies_fixture(self):
        with mock.patch.object(report, "protected_directory", side_effect=FileNotFoundError):
            with self.assertRaises((OSError, ValueError)):
                report.installed_source(self.root, self.manifest)

    def test_unsupported_owner_identity_preserves_original_fallback(self):
        original_os = report.os
        class WithoutPosixIdentity:
            def __getattr__(self, name):
                if name == "geteuid": raise AttributeError(name)
                return getattr(original_os, name)
        receipt = self.root / "unsupported-receipt.json"
        bash = shutil.which("bash")
        with mock.patch.object(report, "os", WithoutPosixIdentity()), mock.patch.object(report.sys, "platform", "win32"), mock.patch.object(report.shutil, "which", return_value=bash):
            status = report.qualify_wait(self.root, self.manifest, ["7"], receipt)
        self.assertEqual(status, 7)
        self.assertEqual(json.loads(receipt.read_text())["execution_profile"], "unsupported")

    def test_mount_prefix_survives_child_limit_restoration(self):
        import resource
        prototype = ROOT / "tools/github-requests/instrumented-gh"
        sys.path.insert(0, str(prototype))
        try:
            from managed_read import native_mount_prefix
        finally: sys.path.remove(str(prototype))
        lease = mock.MagicMock()
        lease.__enter__.return_value = (1024, resource.getrlimit(resource.RLIMIT_NOFILE)[1])
        with self.fixture_installation(), mock.patch.object(report, "source_descriptor_lease", return_value=lease):
            with report.retained_generation(self.root, self.manifest) as generation:
                with report.retained_generation_launch(generation) as launch:
                    self.assertEqual(launch["argv_prefix"], launch["mount_prefix"] + launch["execution_prefix"])
                    native = native_mount_prefix(launch, "/fixture-native", 13, "/fixture-native/gh")
                    self.assertLess(native.index("--ro-bind-data"), native.index("--"))
                    self.assertEqual(native[native.index("--") + 1:], launch["execution_prefix"])
                    result = subprocess.run([*launch["argv_prefix"], sys.executable, "-c",
                                             "import resource;print(resource.getrlimit(resource.RLIMIT_NOFILE)[0])"],
                                            pass_fds=launch["pass_fds"], capture_output=True, text=True, check=True)
                    self.assertEqual(result.stdout.strip(), "1024")

    def test_git_environment_and_replace_objects_do_not_rewrite_generation(self):
        original = (self.root / "tools/helper.py").read_bytes()
        (self.root / "tools/helper.py").write_text("REPLACED_HELPER = True\n")
        self.git("add", "tools/helper.py")
        self.git("-c", "user.name=Albert Hazan", "-c", "user.email=u2giants@users.noreply.github.com",
                 "commit", "-qm", "replacement fixture")
        replacement = self.git("rev-parse", "HEAD").strip()
        self.git("checkout", "-q", "--detach", self.sha)
        self.git("replace", self.sha, replacement)
        with self.fixture_installation(), mock.patch.dict(os.environ,
                 {"GIT_DIR": str(self.root / "not-a-git-repository"), "GIT_WORK_TREE": "/untrusted"}):
            identity, files = report.installed_source(self.root, self.manifest)
        self.assertEqual(identity["source_sha"], self.sha)
        self.assertEqual(files["tools/helper.py"], original)

    def test_partial_or_stale_installed_generation_is_unknown(self):
        (self.root / "tools/helper.py").write_text("DIRTY = True\n")
        with self.fixture_installation(), self.assertRaises(subprocess.CalledProcessError):
            report.installed_source(self.root, self.manifest)

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
        with self.fixture_installation(), mock.patch.object(report, "installed_source", side_effect=replaced):
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
        with self.fixture_installation(), report.retained_generation(self.root, self.manifest) as generation:
            with report.retained_generation_launch(generation) as launch:
                result = subprocess.run([*launch["argv_prefix"], generation["bash_path"], "-c",
                                         ': >/dev/null && git -C "$1" diff --quiet HEAD -- && [ -z "$(git -C "$1" status --porcelain --untracked-files=no)" ] && test ! -e "$1/tools/UNTRACKED" && ! touch "$1/tools/ADDED"', "bash", str(self.root)],
                                        pass_fds=launch["pass_fds"], capture_output=True)
                self.assertEqual(result.returncode, 0)
        self.assertFalse((self.root / "tools/ADDED").exists())

    def test_live_factory_custody_rejects_forgery_and_closed_context_and_reuses_bytes(self):
        if not sys.platform.startswith("linux") or not shutil.which("bwrap"):
            self.skipTest("Linux Bubblewrap required")
        with self.fixture_installation(), report.retained_generation(self.root, self.manifest) as generation:
            self.assertTrue(report.retained_generation_valid(generation))
            self.assertFalse(report.retained_generation_valid(dict(generation)))
            with self.assertRaises(ValueError):
                report.RetainedGenerationMapping(None, dict(generation), ())
            with self.assertRaises(TypeError): generation["identity"]["source_sha"] = "0" * 40
            for _ in range(2):
                with report.retained_generation_launch(generation) as launch:
                    result = subprocess.run([*launch["argv_prefix"], generation["bash_path"],
                                             str(self.waiter), "0"], pass_fds=launch["pass_fds"], capture_output=True)
                    self.assertEqual(result.returncode, 0)
                    self.assertEqual(result.stdout, b"ORIGINAL terminal output\n")
        self.assertFalse(report.retained_generation_valid(generation))
        with self.assertRaises(ValueError):
            with report.retained_generation_launch(generation): pass

    def test_private_tmpfs_copy_has_no_writable_alias_and_cannot_be_remounted(self):
        if not sys.platform.startswith("linux") or not shutil.which("bwrap"):
            self.skipTest("Linux Bubblewrap required")
        helper = self.root / 'tools/helper.py'
        original = helper.read_bytes()
        attributes = self.root / '.gitattributes'
        original_attributes = attributes.read_bytes()
        attributes_stat = attributes.stat()
        probe = r'''
import ctypes,errno,fcntl,os,pathlib,stat,sys
root=pathlib.Path(sys.argv[1]);helper=root/'tools/helper.py'
assert helper.read_bytes()==b'ORIGINAL_HELPER = True\n'
for name in ('bin','tools','config'):
    assert os.statvfs(root/name).f_flag & os.ST_RDONLY
def refused(action):
    try: action()
    except OSError as error:
        assert error.errno in (errno.EROFS,errno.EPERM,errno.EBADF),error.errno
    else: raise AssertionError('immutable source mutation succeeded')
refused(lambda:helper.write_bytes(b'changed'))
refused(lambda:os.chmod(helper,0o777))
refused(lambda:os.link(helper,root/'tools/alias'))
refused(lambda:os.symlink('helper.py',root/'tools/symlink'))
refused(lambda:os.mkdir(root/'tools/added'))
refused(lambda:os.rename(helper,root/'tools/moved'))
refused(lambda:os.unlink(helper))
refused(lambda:(root/'tools/new-helper.py').write_bytes(b'changed'))
library=ctypes.CDLL(None,use_errno=True)
assert library.mount(None,os.fsencode(root/'tools'),None,32,None)==-1
assert ctypes.get_errno()==errno.EPERM
# A further user/mount namespace cannot recover write authority over the
# inherited private read-only mount. Kernels may refuse the namespace itself.
pid=os.fork()
if pid==0:
    if library.unshare(0x10020000)!=0:
        os._exit(0 if ctypes.get_errno() in (errno.EPERM,errno.EINVAL,errno.ENOSYS) else 3)
    result=library.mount(None,os.fsencode(root/'tools'),None,32,None)
    os._exit(0 if result==-1 and ctypes.get_errno()==errno.EPERM else 4)
assert os.waitpid(pid,0)[1]==0
# A leaked setup writer could bypass a later read-only bind remount. Check
# actual inherited regular descriptors, not just future pathname opens.
for name in os.listdir('/proc/self/fd'):
    descriptor=int(name)
    if descriptor<=2:continue
    try:info=os.fstat(descriptor)
    except OSError:continue
    if stat.S_ISREG(info.st_mode):refused(lambda:os.write(descriptor,b'X'))
assert helper.read_bytes()==b'ORIGINAL_HELPER = True\n'
assert (root/'bin/ai-pr-wait').stat().st_mode & 0o777 == 0o500
assert helper.stat().st_mode & 0o777 == 0o400
'''
        with self.fixture_installation(), report.retained_generation(self.root, self.manifest) as generation:
            # An ordinary concurrent canonical edit cannot alter captured bytes.
            helper.write_bytes(b'HOST_ONLY_CHANGE = True\n')
            try:
                for _ in range(2):
                    with report.retained_generation_launch(generation) as launch:
                        result = subprocess.run([*launch['argv_prefix'], sys.executable, '-I', '-S', '-c', probe, str(self.root)],
                                                pass_fds=launch['pass_fds'], capture_output=True)
                        self.assertEqual(result.returncode, 0, result.stderr.decode())
                self.assertEqual(helper.read_bytes(), b'HOST_ONLY_CHANGE = True\n')
            finally: helper.write_bytes(original)
        self.assertFalse((self.root/'tools/new-helper.py').exists())
        self.assertEqual(attributes.read_bytes(), original_attributes)
        after = attributes.stat()
        for key in ('st_dev','st_ino','st_mode','st_uid','st_gid','st_size','st_mtime_ns','st_ctime_ns'):
            self.assertEqual(getattr(after,key),getattr(attributes_stat,key),key)

    def test_qualifier_cancellation_reaps_its_owned_child_group(self):
        self.waiter.write_text('#!/usr/bin/env bash\nsleep 60 &\nprintf "READY %s\\n" "$!"\nwait\n')
        for cancellation in (signal.SIGINT, signal.SIGTERM):
            process = subprocess.Popen([sys.executable, str(ROOT / "tools/github-requests/report.py"),
                                        "--qualify-wait", "--source-root", str(self.root),
                                        "--manifest", str(self.manifest), "--receipt", str(self.root / "unused.json"),
                                        "--", "0"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            selector = selectors.DefaultSelector(); selector.register(process.stdout, selectors.EVENT_READ)
            try:
                self.assertTrue(selector.select(timeout=3))
                line = process.stdout.readline().strip()
                self.assertTrue(line.startswith("READY "), line)
                descendant = int(line.split()[1])
                process.send_signal(cancellation)
                process.communicate(timeout=7)
                self.assertEqual(process.returncode, 128 + cancellation)
                status_file = Path(f"/proc/{descendant}/stat")
                if status_file.exists():
                    self.assertEqual(status_file.read_text().split()[2], "Z")
            finally:
                selector.close()
                if process.poll() is None: process.kill(); process.wait()


class SourceBoundaryRegressionTests(unittest.TestCase):
    def test_python_read_and_write_labels_cannot_persist_arbitrary_text(self):
        import pr_status_singleflight as single
        rows = []
        with mock.patch.object(single, "_target_ordinal", return_value=1), \
             mock.patch.object(single, "_emit_record", side_effect=rows.append), \
             mock.patch.dict(os.environ, {"AI_GH_CALLER": "untrusted-label-sentinel"}):
            single.emit_read_observation("opaque-test-key", "upstream")
            single.emit_write_observation("opaque-test-key", "written", True)
            single.emit_read_observation("opaque-test-key", "cache", caller="another-untrusted-label")
        self.assertEqual([row["caller"] for row in rows], ["unknown"] * 3)
        self.assertNotIn("untrusted", json.dumps(rows))
        self.assertEqual(single.observation_caller("ai-pr-wait"), "ai-pr-wait")
        self.assertEqual(single.observation_caller("ai-merge-group-evidence"), "ai-merge-group-evidence")

    @unittest.skipUnless(os.name == "posix", "Linux observer layout")
    def test_execution_identity_accepts_aliases_but_rejects_external_hardlinks(self):
        directory = str(ROOT / "tools/github-requests/instrumented-gh")
        sys.path.insert(0, directory)
        try:
            from managed_read import same_execution_layout
        finally:
            sys.path.remove(directory)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / "source"; source.mkdir()
            transport = source / "ai-gh"; transport.write_text("public fixture source")
            bash = root / "bash"; bash.write_text("native fixture identity")
            alias = root / "alias"; alias.symlink_to(source, target_is_directory=True)
            bash_alias = root / "bash-alias"; bash_alias.symlink_to(bash)
            self.assertTrue(same_execution_layout(alias / "ai-gh", transport, bash_alias, bash))
            foreign = root / "foreign"; foreign.mkdir()
            os.link(transport, foreign / "ai-gh")
            self.assertFalse(same_execution_layout(foreign / "ai-gh", transport, bash, bash))
            different = source / "different"; different.write_bytes(transport.read_bytes())
            self.assertFalse(same_execution_layout(different, transport, bash, bash))
            self.assertFalse(same_execution_layout(source / "missing", transport, bash, bash))


class DescriptorCustodyTests(unittest.TestCase):
    def test_scoped_raise_nested_restore_and_actual_child_limit(self):
        # Dedicated process: never alter the test runner's own descriptor ceiling.
        code = '''import resource, subprocess, sys
import report
old=resource.getrlimit(resource.RLIMIT_NOFILE)
resource.setrlimit(resource.RLIMIT_NOFILE,(1024,old[1]))
with report.source_descriptor_lease(4096) as limits:
 assert limits==(1024,old[1])
 with report.source_descriptor_lease(4096) as nested: assert nested==limits
 result=subprocess.check_output(['/usr/bin/prlimit','--nofile='+':'.join(map(str,limits)),'--',sys.executable,'-c','import resource;print(resource.getrlimit(resource.RLIMIT_NOFILE)[0])'],text=True)
 assert result.strip()=='1024'
 assert resource.getrlimit(resource.RLIMIT_NOFILE)[0]==4096
assert resource.getrlimit(resource.RLIMIT_NOFILE)==(1024,old[1])
'''
        subprocess.run([sys.executable, "-c", code], env=dict(os.environ, PYTHONPATH=str(ROOT / "tools/github-requests")), check=True)

    def test_lease_refuses_threads_hard_ceiling_and_foreign_changes(self):
        import resource
        with mock.patch.object(resource, "getrlimit", return_value=(1024, 2048)), mock.patch.object(resource, "setrlimit") as change:
            with self.assertRaises(ValueError), report.source_descriptor_lease(2049): pass
            with mock.patch.object(report.threading, "active_count", return_value=2):
                with self.assertRaises(ValueError), report.source_descriptor_lease(2048): pass
            change.assert_not_called()
        with mock.patch.object(resource, "getrlimit", side_effect=[(1024, 4096), (3072, 4096)]), mock.patch.object(resource, "setrlimit") as change:
            with self.assertRaises(ValueError), report.source_descriptor_lease(2048): pass
            change.assert_called_once_with(resource.RLIMIT_NOFILE, (2048, 4096))

    def test_infinite_hard_limit_is_not_a_negative_ceiling(self):
        import resource
        with mock.patch.object(resource, "getrlimit", side_effect=[(1024, resource.RLIM_INFINITY), (4096, resource.RLIM_INFINITY)]), mock.patch.object(resource, "setrlimit") as change:
            with report.source_descriptor_lease(4096) as original:
                self.assertEqual(original, (1024, resource.RLIM_INFINITY))
            self.assertEqual(change.call_args_list,
                             [mock.call(resource.RLIMIT_NOFILE, (4096, resource.RLIM_INFINITY)),
                              mock.call(resource.RLIMIT_NOFILE, (1024, resource.RLIM_INFINITY))])

    def test_inherited_manifest_is_canonical_readonly_and_offset_independent(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); manifest = root / "install-manifest.tsv"
            manifest.write_bytes(b"canonical bytes"); manifest.chmod(0o600)
            other = root / "other"; other.write_bytes(manifest.read_bytes()); other.chmod(0o600)
            for path, flags, expected in [(manifest, os.O_RDONLY, "launcher reached"),
                                           (other, os.O_RDONLY, "custody differs"),
                                           (manifest, os.O_RDWR, "not readonly")]:
                descriptor = os.open(path, flags)
                os.lseek(descriptor, 4, os.SEEK_SET)
                try:
                    with mock.patch.object(report, "protected_directory", side_effect=[os.open(root, os.O_RDONLY | os.O_DIRECTORY), ValueError("launcher reached")]):
                        with self.assertRaisesRegex(ValueError, expected):
                            report.canonical_installation(root, manifest, descriptor)
                    self.assertEqual(os.lseek(descriptor, 0, os.SEEK_CUR), 4)
                finally: os.close(descriptor)
            manifest.chmod(0o644)
            descriptor = os.open(manifest, os.O_RDONLY)
            try:
                with mock.patch.object(report, "protected_directory", return_value=os.open(root, os.O_RDONLY | os.O_DIRECTORY)):
                    with self.assertRaisesRegex(ValueError, "custody differs"):
                        report.canonical_installation(root, manifest, descriptor)
            finally: os.close(descriptor)


@unittest.skipUnless(sys.platform.startswith("linux"), "Linux reciprocal completion; native transport tested separately")
class ActiveParentTests(unittest.TestCase):
    def setUp(self):
        self.fixture = ParentTests()
        self.fixture.setUp()
        self.root, self.manifest = self.fixture.root, self.fixture.manifest
        folder = self.root / "tools/github-requests"
        folder.mkdir()
        for name in ("report.py", "telemetry.sh", "measure_append.py", "pr_status_singleflight.py", "target_ordinal.py"):
            shutil.copyfile(ROOT / "tools/github-requests" / name, folder / name)
        self.script = self.root / "bin/ai-blocker-watch"
        self.script.write_text('''#!/usr/bin/env bash
set -u
printf 'original active stdout\\n'; printf 'original active stderr\\n' >&2
printf x >> "$ACTIVE_TEST_INVOCATIONS"
source "$(dirname "$0")/../tools/github-requests/telemetry.sh"
op="$1"; parent=''; [ "$op" != tick ] || parent="$(gh_measure_workflow_id)"
for kind in $(if [ "$op" = tick ]; then printf 'alarm links'; else printf '%s' "$op"; fi); do
  workflow="blocker_watch_$kind"; id="$(gh_measure_workflow_id)"; boundary="${kind}_scan"
  BW_ACTIVE_OBSERVER_READY=0
  if gh_measure_active_begin "$workflow" "$id" "$parent" "$boundary"; then BW_ACTIVE_OBSERVER_READY=1; fi
  sleep 0.02
  outcome="${ACTIVE_TEST_OUTCOME:-completed}"; succeeded=1; attempted=1; failed=0; skipped=0
  case "$outcome" in skipped) succeeded=0;attempted=0;skipped=1;; partial) attempted=2;failed=1;; failed) succeeded=0;failed=1;; esac
  gh_measure_workflow_outcome ai-blocker-watch "$workflow" "$id" "$outcome" 1 "$boundary" "$attempted" "$succeeded" "$failed" "$skipped" "$parent" || :
done
if [ "$op" = tick ] && [ "${ACTIVE_TEST_STATUS:-0}" = 0 ]; then
  gh_measure_workflow_outcome ai-blocker-watch blocker_watch_tick "$parent" completed 1 || :
fi
exit "${ACTIVE_TEST_STATUS:-0}"
''')
        self.script.chmod(0o755)
        self.fixture.git("add", "bin/ai-blocker-watch", "tools")
        self.fixture.git("-c", "user.name=Albert Hazan", "-c", "user.email=u2giants@users.noreply.github.com",
                         "commit", "-qm", "active source fixture")
        self.sha = self.fixture.git("rev-parse", "HEAD").strip()
        self.manifest.write_text(self.manifest.read_text().replace(self.fixture.sha, self.sha))
        self.state = Path(self.fixture.temp.name) / "state"
        self.state.mkdir(mode=0o700)
        self.invocations = Path(self.fixture.temp.name) / "invocations"
        self.credentials = Path(self.fixture.temp.name) / "credential-context"
        self.credentials.mkdir(mode=0o700)
        for name in ("hosts.yml", "config.yml"):
            (self.credentials / name).write_text("fixture credential bytes must not be read\n")
            (self.credentials / name).chmod(0o600)

    def tearDown(self): self.fixture.tearDown()

    @staticmethod
    def clock():
        value = time.monotonic_ns() // 1_000_000
        return {"monotonic_ms": value, "wall_ms": value + 100000, "error_bound_ms": 1}

    def run_active(self, operation="alarm", profile="sdk_only_no_provider", **environment):
        receipt = Path(self.fixture.temp.name) / f"active-{time.monotonic_ns()}.json"
        stdout, stderr = tempfile.TemporaryFile(), tempfile.TemporaryFile()
        original = subprocess.Popen
        def capture(*args, **kwargs):
            if len(args[0]) >= 2 and str(args[0][-2]).endswith("/bin/ai-blocker-watch"):
                kwargs.update(stdout=stdout, stderr=stderr)
            return original(*args, **kwargs)
        with self.fixture.fixture_installation(), mock.patch.dict(os.environ, {
                "AI_DEVOPS_TEST_MODE": "1", "AI_GH_STATE_DIR": str(self.state),
                "ACTIVE_TEST_INVOCATIONS": str(self.invocations), "GH_CONFIG_DIR": str(self.credentials), **environment}), \
                mock.patch.object(report, "qualification_clock", side_effect=self.clock), \
                mock.patch.object(report.subprocess, "Popen", side_effect=capture):
            status = report.qualify_blocker_watch(self.root, self.manifest, [operation], receipt, profile)
        stdout.seek(0); stderr.seek(0)
        output, diagnostic = stdout.read(), stderr.read()
        stdout.close(); stderr.close()
        return status, json.loads(receipt.read_text()), output, diagnostic

    def test_real_custody_acknowledged_envelope_and_original_streams_once(self):
        status, receipt, out, error = self.run_active()
        self.assertEqual((status, out, error), (0, b"original active stdout\n", b"original active stderr\n"))
        self.assertEqual(self.invocations.read_text(), "x")
        self.assertEqual(receipt["workload_kind"], "fixture")
        self.assertEqual(receipt["source_verified"], "verified")
        self.assertEqual(receipt["source_sha"], self.sha)
        q = receipt["active_outcomes"][0]["completion_qualification"]
        self.assertEqual(q["boundary"], "parent_acknowledged_active_begin_to_end")
        self.assertGreater(q["duration_upper_ms"], 10)
        self.assertIsNone(q["detection_latency_ms"])
        self.assertEqual(receipt["programme_acceptance"], "unknown")

    def test_multiple_child_boundaries_have_own_envelopes_and_parent(self):
        _, receipt, _, _ = self.run_active("tick")
        self.assertEqual(receipt["source_verified"], "unknown")
        self.assertEqual(receipt["active_outcomes"], [])
        self.assertFalse(receipt["provider_acceptance"])

    def test_idle_partial_failed_and_failed_tick_do_not_become_useful_success(self):
        for outcome in ("skipped", "partial", "failed"):
            with self.subTest(outcome=outcome):
                status, receipt, _, _ = self.run_active(ACTIVE_TEST_OUTCOME=outcome, ACTIVE_TEST_STATUS="9")
                self.assertEqual(status, 9)
                self.assertFalse(receipt["active_outcomes"][0]["active_success"])
        status, receipt, _, _ = self.run_active("tick", ACTIVE_TEST_STATUS="7")
        self.assertEqual(status, 7)
        self.assertEqual(receipt["source_verified"], "unknown")
        self.assertEqual(receipt["active_outcomes"], [])

    def test_rejected_namespace_falls_back_once_without_forged_authority(self):
        with mock.patch.object(report, "retained_generation", side_effect=ValueError("fixture refusal")):
            status, receipt, _, _ = self.run_active(ACTIVE_TEST_STATUS="6", AI_GH_ACTIVE_EVENT_FD="1",
                                                   AI_GH_ACTIVE_ACK_FD="2", AI_GH_ACTIVE_PYTHON="forged")
        self.assertEqual(status, 6)
        self.assertEqual(self.invocations.read_text(), "x")
        self.assertEqual(receipt["source_verified"], "unknown")

    def test_source_replacement_after_capture_cannot_replace_loaded_operation(self):
        original = subprocess.Popen
        def replace(*args, **kwargs):
            if len(args[0]) >= 2 and str(args[0][-2]).endswith("/bin/ai-blocker-watch"):
                self.script.write_text("#!/usr/bin/env bash\nexit 89\n")
            return original(*args, **kwargs)
        with mock.patch.object(report.subprocess, "Popen", side_effect=replace):
            status, receipt, output, _ = self.run_active()
        self.assertEqual(status, 0)
        self.assertEqual(output, b"original active stdout\n")
        self.assertEqual(receipt["source_sha"], self.sha)
        self.assertEqual(receipt["source_verified"], "verified")

    def test_clock_jump_and_producer_elapsed_never_create_clock_authority(self):
        start = self.clock(); end = dict(start, wall_ms=start["wall_ms"] + 5000)
        self.assertEqual(report.active_completion_interval(start, end, True)["unknown_reason"], "clock_jump")
        self.assertEqual(report.active_completion_interval(start, end, False)["unknown_reason"], "source_unknown")

    def test_real_privilege_comparison_is_explicit_and_default_preserves_original(self):
        _, receipt, _, _ = self.run_active()
        context = receipt["privilege_context"]
        self.assertIsNotNone(context)
        self.assertIn("user_namespace_inode", context["difference_fields"])
        self.assertFalse(receipt["original_privilege_equivalence"])
        _, declined, _, _ = self.run_active(profile="original_context")
        self.assertEqual(declined["source_verified"], "unknown")
        self.assertEqual(self.invocations.read_text(), "xx")
        state = report.active_privilege_state()
        for field in ("Uid", "Gid", "Seccomp"):
            changed = dict(state, **{field: "not equivalent"})
            self.assertFalse(report.active_sdk_profile(state, changed))
        for field in ("CapEff", "CapPrm", "CapAmb"):
            self.assertFalse(report.active_sdk_profile(state, dict(state, **{field: "1"})))

    def test_credential_probe_reads_no_contents_and_decline_exposes_no_paths(self):
        with mock.patch.object(report.os, "read", side_effect=AssertionError("credential contents read")):
            access = report.active_credential_access({"GH_CONFIG_DIR": str(self.credentials)})
        self.assertEqual(access["mode"], "fixed_config_readability")
        (self.credentials / "hosts.yml").chmod(0o644)
        _, declined, _, _ = self.run_active()
        self.assertEqual(declined["source_verified"], "unknown")
        self.assertFalse(declined["credential_context"]["metadata_guard_passed"])
        text = json.dumps(declined)
        self.assertNotIn(str(self.credentials), text)
        self.assertNotIn("fixture credential bytes", text)
        self.assertEqual(self.invocations.read_text(), "x")

    def test_mismatched_fixed_credential_objects_decline_before_original_work(self):
        with mock.patch.object(report, "active_credential_access", return_value={
                "mode": "fixed_config_readability", "fixed_files": {"hosts.yml": [0], "config.yml": None}}):
            status, receipt, _, _ = self.run_active(ACTIVE_TEST_STATUS="5")
        self.assertEqual(status, 5)
        self.assertEqual(self.invocations.read_text(), "x")
        self.assertFalse(receipt["credential_context"]["readability_preserved"])
        self.assertEqual(receipt["source_verified"], "unknown")

    def test_actual_fifo_credential_substitution_is_promptly_refused(self):
        path = self.credentials / "hosts.yml"
        path.unlink(); os.mkfifo(path, 0o600)
        code = '''import sys
sys.path.insert(0,sys.argv[1]);import report
try:report.active_credential_access({'GH_CONFIG_DIR':sys.argv[2]})
except ValueError:print('refused')
else:raise SystemExit('FIFO unexpectedly accepted')
'''
        result = subprocess.run([sys.executable, "-I", "-S", "-c", code,
                                 str(ROOT / "tools/github-requests"), str(self.credentials)],
                                capture_output=True, timeout=2)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"refused\n")

    def test_original_fallback_preserves_legitimate_fd_and_session_not_observer_pipes(self):
        import fcntl
        output = Path(self.fixture.temp.name) / "context-result.json"
        sentinel = tempfile.TemporaryFile()
        sentinel.write(b"sentinel"); sentinel.flush(); sentinel.seek(0)
        reader, writer = os.pipe()
        legit = fcntl.fcntl(sentinel.fileno(), fcntl.F_DUPFD, 180)
        reserved = fcntl.fcntl(writer, fcntl.F_DUPFD, 190)
        os.set_inheritable(legit, True); os.set_inheritable(reserved, True)
        identity = os.fstat(reserved)
        self.script.write_text('''#!/usr/bin/env bash
printf x >> "$ACTIVE_TEST_INVOCATIONS"
/usr/bin/python3 - "$ACTIVE_TEST_LEGIT" "$ACTIVE_TEST_RESERVED" "$ACTIVE_TEST_RESULT" <<'PY'
import json,os,sys
try:
 s=os.fstat(int(sys.argv[2])); reserved=[s.st_dev,s.st_ino]
except OSError: reserved=None
with open(sys.argv[3],'w') as f:json.dump({'session':os.getsid(0),'sentinel':os.read(int(sys.argv[1]),8).decode(),'reserved':reserved,'observer_env':any(x.startswith('AI_GH_ACTIVE_') for x in os.environ)},f)
PY
exit 7
''')
        try:
            status, receipt, _, _ = self.run_active(profile="original_context", AI_GH_ACTIVE_EVENT_FD=str(reserved),
                ACTIVE_TEST_LEGIT=str(legit), ACTIVE_TEST_RESERVED=str(reserved), ACTIVE_TEST_RESULT=str(output))
            observed = json.loads(output.read_text())
            self.assertEqual(status, 7)
            self.assertEqual(observed["session"], os.getsid(0))
            self.assertEqual(observed["sentinel"], "sentinel")
            self.assertNotEqual(observed["reserved"], [identity.st_dev, identity.st_ino])
            self.assertFalse(observed["observer_env"])
            self.assertTrue(os.get_inheritable(legit)); self.assertTrue(os.get_inheritable(reserved))
            self.assertFalse(receipt["control_session_isolated"])
            self.assertEqual(self.invocations.read_text(), "x")
        finally:
            for fd in (reader, writer, legit, reserved): os.close(fd)
            sentinel.close()

    def test_forged_typed_custody_reordered_duplicate_and_unknown_fields_rejected(self):
        begin = {"schema": 1, "measurement": "active_completion_boundary", "phase": "begin",
                 "caller": "ai-blocker-watch", "workflow": "blocker_watch_alarm", "workflow_id": "a" * 32,
                 "parent_workflow_id": None, "boundary": "alarm_scan"}
        row = {"schema": 3, "utc": "2026-11-01T00:00:00Z", "measurement": "workflow_outcome",
               "caller": "ai-blocker-watch", "workflow": "blocker_watch_alarm", "workflow_id": "a" * 32,
               "parent_workflow_id": None, "boundary": "alarm_scan", "outcome": "completed", "elapsed_ms": 0,
               "attempted_count": 1, "succeeded_count": 1, "failed_count": 0, "skipped_count": 0}
        for data in (dict(row, source_verified="verified"), dict(begin, clock_quality="verified")):
            self.assertFalse(report.active_begin_valid(data) or report.active_outcome_valid(data))
        observer = report.ActiveCompletionObserver({"identity": {"source_verified": "verified"}}, "alarm", lambda _: True)
        observer.receive(begin, self.clock())
        self.assertFalse(observer.result(0)[0])
        with self.fixture.fixture_installation(), report.retained_generation(self.root, self.manifest) as generation:
            for sequence in ((row,), (begin, begin, row), (begin, row, row)):
                observer = report.ActiveCompletionObserver(generation, "alarm", lambda _: True)
                for item in sequence: observer.receive(item, self.clock())
                self.assertFalse(observer.result(0)[0])
            observer = report.ActiveCompletionObserver(generation, "alarm", lambda _: True)
            observer.receive(begin, self.clock(), queued=True)
            observer.receive(row, self.clock())
            self.assertFalse(observer.result(0)[0])

    def test_dead_parent_ack_is_bounded_and_never_returns_success(self):
        read, write = os.pipe(); ack_read, ack_write = os.pipe()
        row = {"schema": 1, "measurement": "active_completion_boundary", "phase": "begin",
               "caller": "ai-blocker-watch", "workflow": "blocker_watch_alarm", "workflow_id": "a" * 32,
               "parent_workflow_id": None, "boundary": "alarm_scan"}
        try:
            with mock.patch.dict(os.environ, {"AI_GH_ACTIVE_EVENT_FD": str(write), "AI_GH_ACTIVE_ACK_FD": str(ack_read)}):
                started = time.monotonic()
                self.assertFalse(report.active_channel_helper("begin", json.dumps(row).encode()))
                self.assertLess(time.monotonic() - started, 0.75)
        finally:
            for fd in (read, write, ack_read, ack_write): os.close(fd)

    def test_late_ack_cannot_qualify_and_data_only_transcript_cannot_grant_source(self):
        import threading
        read, write = os.pipe(); ack_read, ack_write = os.pipe()
        begin = {"schema": 1, "measurement": "active_completion_boundary", "phase": "begin",
                 "caller": "ai-blocker-watch", "workflow": "blocker_watch_alarm", "workflow_id": "a" * 32,
                 "parent_workflow_id": None, "boundary": "alarm_scan"}
        def late():
            os.read(read, 4096)
            time.sleep(0.30)
            os.write(ack_write, (json.dumps({"schema": 1, "phase": "ack", "workflow_id": "a" * 32}) + "\n").encode())
        thread = threading.Thread(target=late)
        thread.start()
        try:
            with mock.patch.dict(os.environ, {"AI_GH_ACTIVE_EVENT_FD": str(write), "AI_GH_ACTIVE_ACK_FD": str(ack_read)}):
                self.assertFalse(report.active_channel_helper("begin", json.dumps(begin).encode()))
        finally:
            thread.join(timeout=2)
            for fd in (read, write, ack_read, ack_write): os.close(fd)
        transcript = report.ActiveCompletionTranscript("alarm", lambda _: True)
        row = receipt_fixture("ai-blocker-watch", "blocker_watch_alarm", "completed", "a" * 32)
        row.update(workflow_id="a" * 32, parent_workflow_id=None)
        transcript.receive(begin, self.clock())
        transcript.receive(row, self.clock())
        self.assertTrue(transcript.protocol_result(0)[0])
        verified, records = transcript.result(0)
        self.assertFalse(verified)
        self.assertEqual(records[0]["completion_qualification"]["unknown_reason"], "source_unknown")
        for invalid in (dict(begin, workflow=[]), dict(row, outcome={}), dict(row, elapsed_ms=True)):
            self.assertFalse(report.active_begin_valid(invalid) or report.active_outcome_valid(invalid))

    def test_multiple_correlated_child_envelopes_are_not_whole_tick_duration(self):
        transcript = report.ActiveCompletionTranscript("tick", lambda _: True)
        for index, workflow in enumerate(("blocker_watch_alarm", "blocker_watch_links")):
            row = receipt_fixture("ai-blocker-watch", workflow, "completed", str(index + 1) * 32)
            row.update(workflow_id=str(index + 1) * 32, parent_workflow_id="f" * 32)
            begin = {key: row[key] for key in ("caller", "workflow", "workflow_id", "parent_workflow_id", "boundary")}
            begin.update(schema=1, measurement="active_completion_boundary", phase="begin")
            start = {"wall_ms": 1000 + index * 1000, "monotonic_ms": 1000 + index * 1000, "error_bound_ms": 1}
            end = dict(start, wall_ms=start["wall_ms"] + 50 + index * 25,
                       monotonic_ms=start["monotonic_ms"] + 50 + index * 25)
            transcript.receive(begin, start); transcript.receive(row, end)
        parent = receipt_fixture("ai-blocker-watch", "blocker_watch_tick", "completed", "f" * 32)
        parent["workflow_id"] = "f" * 32
        transcript.receive(parent, self.clock())
        self.assertTrue(transcript.protocol_result(0)[0])
        _, records = transcript.result(0, source_verified=True)  # Unit input only; no live authority receipt.
        self.assertEqual([x["completion_qualification"]["duration_upper_ms"] for x in records], [54, 79])

    def test_observer_failure_after_launch_does_not_replay_or_change_original_status(self):
        with mock.patch.object(report.ActiveCompletionObserver, "result", side_effect=ValueError("fixture observer failure")):
            status, receipt, _, _ = self.run_active(ACTIVE_TEST_STATUS="4")
        self.assertEqual(status, 4)
        self.assertEqual(self.invocations.read_text(), "x")
        self.assertEqual(receipt["source_verified"], "unknown")
        self.assertTrue(receipt["observer_cleanup_complete"])
        self.assertGreaterEqual(receipt["qualification_elapsed_ns"], receipt["observer_setup_elapsed_ns"])
        self.assertEqual(receipt["whole_observer_budget_qualification"], "unknown")

    def test_provider_cannot_inherit_channels_and_status_argv_streams_survive(self):
        read, write = os.pipe(); ack_read, ack_write = os.pipe()
        environment = dict(os.environ, AI_GH_ACTIVE_EVENT_FD=str(write), AI_GH_ACTIVE_ACK_FD=str(ack_read),
                           AI_GH_ACTIVE_PYTHON=sys.executable)
        program = '''import os,sys
assert not any(k.startswith("AI_GH_ACTIVE_") for k in os.environ)
for fd in map(int,sys.argv[1:3]):
 try: os.fstat(fd)
 except OSError: pass
 else: raise AssertionError("inherited observer descriptor")
assert sys.argv[3] == 'space "quote" Ω'
print("provider stdout");print("provider stderr",file=sys.stderr);sys.exit(7)
'''
        arguments = [sys.executable, "-c", program, str(write), str(ack_read), 'space "quote" Ω']
        try:
            child = subprocess.run([sys.executable, str(ROOT / "tools/github-requests/report.py"), "--active-harness"],
                input=b"\0".join(os.fsencode(x) for x in arguments) + b"\0", capture_output=True,
                env=environment, pass_fds=(write, ack_read), timeout=5)
            self.assertEqual(child.returncode, 7)
            self.assertEqual(child.stdout, b"provider stdout\n")
            self.assertEqual(child.stderr, b"provider stderr\n")
        finally:
            for fd in (read, write, ack_read, ack_write): os.close(fd)


class ActiveEventConsumerTests(unittest.TestCase):
    def clock(self, value):
        return {"wall_ms": value, "monotonic_ms": value, "error_bound_ms": 1}

    def transcript(self, operation="alarm", outcome="completed", ack=True):
        row = receipt_fixture("ai-blocker-watch", "blocker_watch_" + operation, outcome, "a" * 32)
        begin = {key: row[key] for key in ("caller", "workflow", "workflow_id", "parent_workflow_id", "boundary")}
        begin.update(schema=1, measurement="active_completion_boundary", phase="begin")
        transcript = report.ActiveCompletionTranscript(operation, lambda _: ack)
        transcript.receive(begin, self.clock(1000)); transcript.receive(row, self.clock(4000))
        return transcript, row

    def facts(self, operation="alarm"):
        value = event()
        value.update(caller="ai-blocker-watch", workflow="blocker_watch_" + operation,
                     target_ordinal=None, event_kind="alarm_stale" if operation == "alarm" else "unknown",
                     eligible_utc_ms=2000 if operation == "alarm" else None,
                     observed_utc_ms=2500, delivered_utc_ms=3000,
                     delivery_boundary=operation + "_batch_acknowledged", unknown_reason="source_unknown")
        return {"schema": 1, "measurement": "active_event_facts", "phase": "facts", "event": value}

    def test_alarm_parent_envelope_and_facts_clock_are_distinct(self):
        transcript, _ = self.transcript()
        transcript.receive(self.facts(), self.clock(4100))
        valid, records = transcript.result(0, source_verified=True)  # Unit protocol input, not live authority.
        self.assertTrue(valid)
        self.assertEqual(records[0]["completion_qualification"]["duration_upper_ms"], 3004)
        self.assertEqual(records[0]["event_parent_clock"], self.clock(4100))
        qualified = records[0]["event_qualification"]
        self.assertEqual(qualified["unknown_reason"], "none")
        self.assertEqual(qualified["latency_upper_ms"], 2004)
        self.assertEqual(qualified["latency_lower_ms"], 0)

    def test_duplicate_unknown_reordered_and_forged_facts_invalidate(self):
        for mutation in ("duplicate", "unknown_id", "before_end", "authority", "malformed"):
            with self.subTest(mutation=mutation):
                transcript, _ = self.transcript()
                frame = self.facts()
                if mutation == "unknown_id": frame["event"]["workflow_id"] = "b" * 32
                if mutation == "before_end": transcript.completed.clear()
                if mutation == "authority": frame["event"]["source_verified"] = "verified"
                if mutation == "malformed": frame["extra"] = True
                transcript.receive(frame, self.clock(4100))
                if mutation == "duplicate": transcript.receive(frame, self.clock(4200))
                self.assertFalse(transcript.result(0, source_verified=True)[0])

    def test_source_false_and_unacknowledged_never_qualify(self):
        for ack in (True, False):
            transcript, _ = self.transcript(ack=ack)
            transcript.receive(self.facts(), self.clock(4100))
            self.assertEqual(transcript.result(0)[1][0]["event_qualification"]["unknown_reason"], "source_unknown")

    def test_partial_failed_refused_or_links_are_not_detection(self):
        for operation, outcome in (("alarm", "partial"), ("alarm", "failed"), ("alarm", "skipped"),
                                   ("links", "completed")):
            transcript, _ = self.transcript(operation, outcome)
            transcript.receive(self.facts(operation), self.clock(4100))
            self.assertEqual(transcript.result(0, source_verified=True)[1][0]["event_qualification"]["unknown_reason"], "event_unknown")

    def test_eligibility_before_begin_and_future_or_jumping_clocks_unknown(self):
        for mutation, reason in (("old", "eligibility_not_observed"), ("future", "event_invalid"),
                                 ("jump", "clock_jump"), ("missing", "clock_unknown")):
            frame = self.facts(); end = self.clock(4100)
            if mutation == "old": frame["event"]["eligible_utc_ms"] = 999
            if mutation == "future": frame["event"]["delivered_utc_ms"] = 5000
            if mutation == "jump": end["wall_ms"] += 100
            if mutation == "missing": end = None
            self.assertEqual(report.qualify_blocker_event(frame["event"], self.clock(1000), end, True, True)["unknown_reason"], reason)

    def test_fact_limit_shares_existing_transcript_budget(self):
        transcript, _ = self.transcript()
        transcript.frames = report.ACTIVE_MAX_FRAMES
        transcript.receive(self.facts(), self.clock(4100))
        self.assertFalse(transcript.result(0, source_verified=True)[0])

    def test_nonzero_original_status_cannot_qualify_alarm_detection(self):
        transcript, _ = self.transcript()
        transcript.receive(self.facts(), self.clock(4100))
        self.assertEqual(transcript.result(7, source_verified=True)[1][0]["event_qualification"]["unknown_reason"], "event_unknown")

    def test_actual_telemetry_append_precedes_forward_and_failure_preserves_status(self):
        script = '''source "$1"
gh_measure_append(){ printf 'APPEND\\n'; return "$APPEND_STATUS"; }
gh_measure_active_channel(){ printf 'FORWARD:%s:%s\\n' "$1" "$2"; return 1; }
gh_measure_blocker_evidence blocker_watch_alarm aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa alarm_stale 2000 2500 3000 alarm_batch_acknowledged
exit $?'''
        for append_status in (0, 9):
            child = subprocess.run(["bash", "-c", script, "fixture", str(ROOT / "tools/github-requests/telemetry.sh")],
                                   env=dict(os.environ, APPEND_STATUS=str(append_status)), capture_output=True, timeout=5)
            self.assertEqual(child.returncode, append_status)
            lines = child.stdout.decode().splitlines()
            self.assertEqual(lines[0], "APPEND")
            if append_status:
                self.assertEqual(len(lines), 1)
            else:
                prefix, phase, payload = lines[1].split(":", 2)
                self.assertEqual((prefix, phase), ("FORWARD", "facts"))
                self.assertTrue(report.active_event_frame_valid(json.loads(payload)))

    def test_actual_facts_pipe_needs_no_ack_and_rejects_oversize(self):
        read, write = os.pipe(); ack_read, ack_write = os.pipe()
        try:
            with mock.patch.dict(os.environ, AI_GH_ACTIVE_EVENT_FD=str(write), AI_GH_ACTIVE_ACK_FD=str(ack_read)):
                data = json.dumps(self.facts()).encode()
                self.assertTrue(report.active_channel_helper("facts", data))
                self.assertTrue(report.active_event_frame_valid(json.loads(os.read(read, 4096))))
                self.assertFalse(report.active_channel_helper("facts", b" " * 4097))
        finally:
            for fd in (read, write, ack_read, ack_write): os.close(fd)

    def test_saved_event_data_does_not_become_a_pr_event(self):
        frame = self.facts()
        self.assertTrue(report.unqualified_blocker_event(frame["event"]))
        self.assertFalse(report.unqualified_event(frame["event"]))
        self.assertEqual(report.qualify_event(frame["event"], self.clock(1000), self.clock(4100), True)["unknown_reason"], "event_unknown")


if __name__ == "__main__":
    unittest.main()
