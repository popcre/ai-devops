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


class EventTests(unittest.TestCase):
    def test_unsupported_native_event_pipe_is_explicitly_unknown(self):
        with mock.patch.object(measure_append.sys, "platform", "win32"):
            self.assertFalse(measure_append.write_event_fd(3, "{}"))
            self.assertIsNone(report.qualification_clock())

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
        return subprocess.run(["git", "-C", str(self.root), *arguments], check=True,
                              capture_output=True, text=True).stdout

    def fixture_installation(self):
        # Only tests substitute the protected canonical-I/O boundary. There
        # is no production flag/environment path to bless this private file.
        return mock.patch.object(report, "canonical_installation",
                                 side_effect=lambda root, manifest: (Path(manifest).read_bytes(),
                                                                    self.launcher.parent / "ai-pr-wait"))

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
        with self.assertRaises(ValueError): report.installed_source(self.root, self.manifest)
        self.manifest.chmod(0o600)
        linked = self.manifest.with_name("linked.tsv"); linked.symlink_to(self.manifest)
        with self.assertRaises((OSError, ValueError)): report.installed_source(self.root, linked)
        launcher = self.launcher.parent / "ai-pr-wait"
        launcher.unlink(); launcher.symlink_to(ROOT / "bin/ai-gh")
        with self.assertRaises(ValueError): report.installed_source(self.root, self.manifest)

    def test_arbitrary_owner_private_manifest_cannot_certify_installation(self):
        with self.assertRaises((ValueError, OSError)):
            report.installed_source(self.root, self.manifest)

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


if __name__ == "__main__":
    unittest.main()
