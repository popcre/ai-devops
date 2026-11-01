#!/usr/bin/env python3
"""Framed Windows delivery, Linux clock bounds, and no-replay custody tests."""
import base64
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/github-requests"))
import remote_wait as remote


def canonical_report():
    # Allows an isolated dependency branch to test the exact composing source;
    # CI uses its normal adjacent reporter, never a substitute validator.
    path = os.environ.get("AI_TEST_REPORT_PATH")
    if not path:
        return remote.get_report()
    spec = importlib.util.spec_from_file_location("observer_reference_report", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def event():
    return {"schema": 4, "utc": "2026-10-31T00:00:00Z", "measurement": "workflow_evidence",
            "caller": "ai-pr-wait", "workflow": "pr_wait", "workflow_id": "a" * 32,
            "cohort_id": None, "target_ordinal": None, "source_verified": "unknown",
            "source_fingerprint_start": None, "source_fingerprint_end": None,
            "install_generation_binding": None, "event_kind": "pr_merged", "eligible_utc_ms": 2000000000000,
            "observed_utc_ms": 2000000002000, "delivered_utc_ms": 2000000003000,
            "delivery_boundary": "terminal_report", "clock_quality": "unknown", "clock_error_bound_ms": None,
            "latency_ms": None, "unknown_reason": "source_unknown"}


def start(argument_hash):
    return {"schema": 1, "frame": "started", "observer_run_id": "a" * 32,
            "observer_arguments_sha256": argument_hash, "source_sha": "b" * 40,
            "source_fingerprint": "c" * 64, "source_scope": "git_raw_bin_tools_config_v1",
            "execution_profile": "restricted_read", "stdin_profile": "read_only_no_stdin", "start_boundary": "process_resumed"}


def receipt(started, row):
    result = {key: value for key, value in started.items() if key != "frame"}
    result.update(loaded_source_fingerprint=started["source_fingerprint"], install_generation_binding="d" * 64,
                  source_boundary="windows_locked_generation", child_exit=3, source_verified="verified",
                  unknown_reason="none", boundary_detail="none", clock_quality="unknown", clock_error_bound_ms=None,
                  observer_event_json=json.dumps(row), observer_event_status="received")
    return result


def clocks():
    return ({"wall_ms": 1999999995000, "monotonic_ms": 1000, "error_bound_ms": 2, "basis": "linux_adjtimex_maxerror"},
            {"wall_ms": 2000000004000, "monotonic_ms": 10000, "error_bound_ms": 3, "basis": "linux_adjtimex_maxerror"})


class Capture:
    def __init__(self):
        self.buffer = io.BytesIO()
    def write(self, value):
        self.buffer.write(value.encode())
    def flush(self):
        pass


class ObserverTests(unittest.TestCase):
    def setUp(self):
        self.report = canonical_report()
        self.patch = mock.patch.object(remote, "get_report", return_value=self.report)
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def test_native_supervisor_uses_only_process_scoped_script_policy(self):
        with mock.patch.dict(os.environ, {"SystemRoot": "C:/Windows"}):
            command = remote.windows_supervisor_command("C:/repos/ai-devops", b'["--help"]', 123, 456)
        self.assertEqual(command[1:5], ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File"])
        self.assertTrue(command[0].replace("\\", "/").endswith("System32/WindowsPowerShell/v1.0/powershell.exe"))
        self.assertNotIn("Set-ExecutionPolicy", command)
        self.assertIn("-ReadOnlyNoStdin", command)
        self.assertNotIn("-ArgumentsFile", command)
        self.assertEqual(base64.b64decode(command[command.index("-ArgumentsBase64")+1]), b'["--help"]')

    def test_linux_receive_bound_includes_transport_not_windows_wall(self):
        row = event()
        row["observed_utc_ms"] += 500000
        row["delivered_utc_ms"] += 500000
        result = remote.qualify_remote_event(row, *clocks(), True)
        self.assertEqual((result["latency_lower_ms"], result["latency_upper_ms"]), (2997, 4003))
        self.assertEqual(result["delivery_boundary"], "linux_parent_received_over_ssh")
        self.assertTrue(result["github_utc_assumption"])

    def test_source_and_bad_clocks_never_upgrade(self):
        row = event()
        self.assertEqual(remote.qualify_remote_event(row, *clocks(), False)["unknown_reason"], "source_unknown")
        for value in (None, {"wall_ms": 1}, {**clocks()[0], "error_bound_ms": True}):
            self.assertEqual(remote.qualify_remote_event(row, value, clocks()[1], True)["clock_quality"], "unknown")

    def test_jump_and_event_before_observed_start_refused(self):
        before, after = clocks()
        after["wall_ms"] += 10000
        self.assertEqual(remote.qualify_remote_event(event(), before, after, True)["unknown_reason"], "clock_jump")
        row = event()
        row["eligible_utc_ms"] = before["wall_ms"]
        self.assertEqual(remote.qualify_remote_event(row, *clocks(), True)["unknown_reason"], "event_before_observed_start")

    def test_forged_child_qualification_and_extra_fields_refused(self):
        for key, value in (("source_verified", "verified"), ("clock_quality", "verified_bound"), ("extra", "payload")):
            row = event()
            row[key] = value
            self.assertEqual(remote.qualify_remote_event(row, *clocks(), True)["unknown_reason"], "event_unknown")

    def test_output_is_bytes_never_nested_control(self):
        payload = b'\x00\xff{"protocol":1,"kind":"receipt"}\n'
        decoded = remote.parse_frame(remote.frame("stdout", data=base64.b64encode(payload).decode()))
        self.assertEqual(decoded["decoded"], payload)
        self.assertEqual(decoded["kind"], "stdout")

    def test_duplicate_json_wrong_shapes_and_large_frames_refused(self):
        for value in (b'{"protocol":1,"protocol":1,"kind":"exit","code":0}\n',
                      b'{"protocol":1,"kind":"stdout","data":"!"}\n', b'x' * (remote.MAX_FRAME + 1)):
            with self.assertRaises((ValueError, TypeError)):
                remote.parse_frame(value)

    def test_argument_and_generation_binding_required(self):
        started = start("f" * 64)
        self.assertTrue(remote.valid_start(started, "f" * 64))
        self.assertFalse(remote.valid_start(started, "e" * 64))
        result = receipt(started, event())
        self.assertTrue(remote.valid_receipt(result, started))
        result["source_sha"] = "e" * 40
        self.assertFalse(remote.valid_receipt(result, started))
        self.assertFalse(remote.valid_receipt(receipt(started, event()), None))

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux observer process required")
    def test_live_framing_ack_receipt_and_original_exit_without_api(self):
        arguments = ["123", "--repo", "popcre/ai-devops"]
        argument_hash = hashlib.sha256(json.dumps(arguments, separators=(",", ":")).encode()).hexdigest()
        started = start(argument_hash)
        source = receipt(started, event())
        payload = b'original\x00\xff\n'
        frames = (remote.frame("started", record=started) + remote.frame("stdout", data=base64.b64encode(payload).decode())
                  + remote.frame("stderr", data=base64.b64encode(b"original error\n").decode())
                  + remote.frame("receipt", record=source))
        code = ("import sys,json;sys.stdout.buffer.write(" + repr(frames) + ");sys.stdout.buffer.flush();"
                "a=json.loads(sys.stdin.buffer.readline());"
                "assert a=={'protocol':1,'kind':'ack','observer_run_id':'" + "a" * 32 + "'};"
                "sys.stdout.buffer.write(" + repr(remote.frame("exit", code=3)) + ");sys.stdout.buffer.flush();sys.exit(3)")
        out, err = Capture(), Capture()
        with tempfile.TemporaryDirectory() as temporary, mock.patch.object(sys, "stdout", out), mock.patch.object(sys, "stderr", err), mock.patch.object(self.report, "qualification_clock", side_effect=clocks()), mock.patch.object(remote.time, "perf_counter_ns", side_effect=[100, 400, 1100]):
            target = Path(temporary) / "receipt.json"
            result = remote.observe([sys.executable, "-I", "-c", code], arguments, target, 5)
            saved = json.loads(target.read_text())
        self.assertEqual(result, 3)
        self.assertEqual(out.buffer.getvalue(), payload)
        self.assertEqual(err.buffer.getvalue(), b"original error\n")
        self.assertEqual(saved["event_qualification"]["latency_upper_ms"], 4003)
        self.assertEqual(saved["transport"], "ssh_included")
        self.assertEqual(saved["observation_timing_basis"], "linux_parent_perf_counter_ns_before_ssh_popen")
        self.assertEqual(saved["started_frame_elapsed_ns"], 300)
        self.assertEqual(saved["receipt_elapsed_ns"], 1000)

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux observer process required")
    def test_malicious_event_data_never_changes_original_exit(self):
        arguments = ["123", "--repo", "popcre/ai-devops"]
        argument_hash = hashlib.sha256(json.dumps(arguments, separators=(",", ":")).encode()).hexdigest()
        started = start(argument_hash)
        source = receipt(started, event())
        source["observer_event_json"] = '{"schema":4,"schema":4}'
        frames = remote.frame("started", record=started) + remote.frame("receipt", record=source)
        code = ("import sys;sys.stdout.buffer.write(" + repr(frames) + ");sys.stdout.buffer.flush();"
                "assert sys.stdin.buffer.readline();sys.stdout.buffer.write(" + repr(remote.frame("exit", code=3))
                + ");sys.stdout.buffer.flush();sys.exit(3)")
        with tempfile.TemporaryDirectory() as temporary, mock.patch.object(self.report, "qualification_clock", side_effect=clocks()):
            target = Path(temporary) / "receipt.json"
            result = remote.observe([sys.executable, "-I", "-c", code], arguments, target, 5)
            saved = json.loads(target.read_text())
        self.assertEqual(result, 3)
        self.assertEqual(saved["event_qualification"]["unknown_reason"], "event_invalid")
        self.assertIsNone(saved["event_qualification"]["latency_upper_ms"])

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux observer process required")
    def test_control_eof_cancels_without_false_receipt(self):
        code = "import sys;assert sys.stdin.buffer.read()==b'';sys.exit(130)"
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / "receipt.json"
            # A finite parent deadline closes stdin; owned controller exits
            # instead of leaving a background command or replaying a request.
            with self.assertRaises(TimeoutError):
                remote.observe([sys.executable, "-I", "-c", code], [], target, 0.1)
            self.assertFalse(target.exists())


class CounterCapsuleTests(unittest.TestCase):
    def test_exact_inline_argument_bytes_and_bounds_precede_process_creation(self):
        raw=b' [ "--help" ] '
        with mock.patch.dict(os.environ,{"SystemRoot":"C:/Windows"}):
            command=remote.windows_supervisor_command('C:/repos/ai-devops',raw,123,456)
            self.assertEqual(base64.b64decode(command[command.index('-ArgumentsBase64')+1]),raw)
            for bad in (b'x'*8193,b'["\\u0000"]',b'[1]',b'{}',b'["\xff"]'):
                with self.subTest(bad=bad[:20]),self.assertRaises((ValueError,UnicodeError)):
                    remote.windows_supervisor_command('C:/repos/ai-devops',bad,123,456)
        with mock.patch.object(remote.subprocess,'Popen') as popen:
            with self.assertRaises(ValueError):
                remote.observe(['never-launched'],['x'*8193],'unused.json',1)
            popen.assert_not_called()

    def binding(self):
        return dict(schema=1, manifest_sha256="a"*64, image_sha256="b"*64,
                    counter_source_fingerprint="c"*64, runtime_version="2.97.0",
                    ordinary_image_sha256="d"*64, closure_entry="extra/counter.exe",
                    scope="primary_constructor_subset", http_requests=None,
                    graphql_operations=None, qualification_only=True)

    def raw(self, completed=0, incomplete=False):
        return (json.dumps(dict(schema=1, started=True))+"\n"+json.dumps(dict(schema=1, finished=True,
                observed_completed_writes=completed, failed_write_attempts=0, observed_external_writes=0,
                incomplete=incomplete, http_requests=None))+"\n")

    def test_counter_binding_finite_and_distinct(self):
        row=self.binding()
        self.assertTrue(remote.valid_counter_binding(row,"a"*64))
        for key,value in (("manifest_sha256","e"*64),("closure_entry","bin/gh.exe"),
                          ("http_requests",0),("qualification_only",False),("scope","all_http")):
            with self.subTest(key=key):
                altered={**row,key:value}
                self.assertFalse(remote.valid_counter_binding(altered,"a"*64))
        self.assertFalse(remote.valid_counter_binding({**row,"unbound":True},"a"*64))

    def test_numeric_pipe_unknown_never_zero(self):
        zero=remote.counter_aggregate(self.raw())
        self.assertTrue(zero["complete"])
        self.assertEqual(zero["counted_invocations"],1)
        self.assertTrue(remote.valid_counter_measurement(zero))
        self.assertEqual(remote.counter_aggregate(self.raw(2)+self.raw(3))["observed_completed_writes"],5)
        for raw in (None,"",self.raw()[:-5],self.raw(incomplete=True),"x"*65537,
                    '{"schema":1,"started":true}\n'*2,self.raw()*65):
            with self.subTest(raw=str(raw)[:40]):
                unknown=remote.counter_aggregate(raw)
                self.assertFalse(unknown["complete"])
                self.assertIsNone(unknown["observed_completed_writes"])
                self.assertTrue(remote.valid_counter_measurement(unknown))
        self.assertFalse(remote.valid_counter_measurement({**zero,"http_requests":0}))
        self.assertFalse(remote.valid_counter_measurement({**zero,"failed_write_attempts":1}))
        self.assertFalse(remote.valid_counter_measurement({**remote.counter_aggregate(None),"complete":0}))

    def test_counter_source_receipt_requires_explicit_expected_manifest(self):
        s=start("a"*64);r=receipt(s,event())
        r.update(counter_binding=self.binding(),counter_measurement=remote.counter_aggregate(self.raw()))
        self.assertFalse(remote.valid_receipt(r,s))
        self.assertTrue(remote.valid_receipt(r,s,"a"*64))
        self.assertFalse(remote.valid_receipt(r,s,"e"*64))
        self.assertFalse(remote.valid_receipt({**r,"counter_raw":"untrusted raw bytes"},s,"a"*64))

    def test_counter_controller_keeps_original_profile_and_process_policy(self):
        with mock.patch.dict(os.environ,{"SystemRoot":"C:/Windows"}):
            command=remote.windows_supervisor_command("C:/repos/ai-devops",b'["issue","view","658","--repo","popcre/ai-devops","--json","state,title"]',123,456,
                       "C:/Program Files/owned/build.json","a"*64)
        self.assertIn("-RestrictedReadProfile",command)
        self.assertIn("-ReadOnlyNoStdin",command)
        self.assertNotIn("-ObserverEvents",command)
        self.assertEqual(command[command.index("-EntryPoint")+1],"bin/ai-gh")
        self.assertEqual(command[command.index("-ExecutionPolicy")+1],"Bypass")
        self.assertEqual(command[command.index("-ExpectedCounterManifestSha256")+1],"a"*64)

    @unittest.skipUnless(sys.platform.startswith("linux"), "Linux observer process required")
    def test_counter_ack_while_custody_and_original_binary_output(self):
        arguments=['issue','view','658','--repo','popcre/ai-devops','--json','state,title']
        arg_hash=hashlib.sha256(json.dumps(arguments,separators=(',',':')).encode()).hexdigest()
        started=start(arg_hash);source=receipt(started,event())
        source.update(observer_event_json=None,observer_event_status='unavailable',counter_binding=self.binding(),
                      counter_measurement=remote.counter_aggregate(self.raw(4)))
        payload=b'original\x00\xff\n'
        frames=(remote.frame('started',record=started)+remote.frame('stdout',data=base64.b64encode(payload).decode())
                +remote.frame('receipt',record=source))
        code=("import sys,json;sys.stdout.buffer.write("+repr(frames)+");sys.stdout.buffer.flush();"
              "assert json.loads(sys.stdin.buffer.readline())['kind']=='ack';"
              "sys.stdout.buffer.write("+repr(remote.frame('exit',code=3))+");sys.stdout.buffer.flush();sys.exit(3)")
        out=Capture();err=Capture()
        with tempfile.TemporaryDirectory() as temporary, mock.patch.object(sys,'stdout',out), mock.patch.object(sys,'stderr',err):
            target=Path(temporary)/'counter.json'
            status=remote.observe([sys.executable,'-I','-c',code],arguments,target,5,'a'*64)
            saved=json.loads(target.read_text())
        self.assertEqual(status,3)
        self.assertEqual(out.buffer.getvalue(),payload)
        self.assertEqual(saved['measurement'],'linux_observed_windows_managed_read_counter')
        self.assertEqual(saved['counter_measurement']['observed_completed_writes'],4)
        self.assertIsNone(saved['counter_measurement']['http_requests'])
        self.assertEqual(saved['event_qualification']['unknown_reason'],'event_unknown')
        self.assertGreaterEqual(saved['receipt_elapsed_ns'],saved['started_frame_elapsed_ns'])


class ActiveCompletionRemoteTests(unittest.TestCase):
    def setUp(self):
        self.report = canonical_report()
        patch = mock.patch.object(remote, "get_report", return_value=self.report)
        patch.start(); self.addCleanup(patch.stop)

    def test_profiles_are_named_and_do_not_relabel_active_work(self):
        with mock.patch.dict(os.environ, {"SystemRoot": "C:/Windows"}):
            ordinary = remote.windows_supervisor_command("C:/repo", b'["tick"]', 50, 51, active_completion=True)
            sdk = remote.windows_supervisor_command("C:/repo", b'["alarm"]', 50, 51, active_completion=True, sdk_coordinator=True)
            self.assertIn("-ActiveCompletion", ordinary)
            self.assertIn("-ActiveNoStdin", ordinary)
            for flag in ("-RestrictedReadProfile", "-ReadOnlyNoStdin", "-ActiveSdkProfile"):
                self.assertNotIn(flag, ordinary)
            self.assertIn("-ActiveSdkProfile", sdk)
            for args in (b'["tick"]', b'["arbitrary"]', b'["alarm","extra"]'):
                with self.assertRaises(ValueError):
                    remote.windows_supervisor_command("C:/repo", args, 50, 51, active_completion=True, sdk_coordinator=True)

    def run_transport(self, sdk=False, duplicate=False):
        arguments = ["alarm"] if sdk else ["tick"]
        arg_hash = hashlib.sha256(json.dumps(arguments, separators=(",", ":")).encode()).hexdigest()
        started = start(arg_hash)
        started.update(execution_profile="active_sdk_coordinator" if sdk else "original_active", stdin_profile="active_no_stdin")
        source = receipt(started, event())
        source.update(observer_event_json=None, observer_event_status="unavailable", active_channel_status="valid")
        if not sdk:
            source.update(source_verified="unknown", unknown_reason="boundary_unavailable", boundary_detail="active_original_context_unqualified")
        identity, parent = "1" * 32, None if sdk else "2" * 32
        begin = {"schema": 1, "measurement": "active_completion_boundary", "phase": "begin", "caller": "ai-blocker-watch",
                 "workflow": "blocker_watch_alarm", "workflow_id": identity, "parent_workflow_id": parent, "boundary": "alarm_scan"}
        end = {"schema": 3, "utc": "2026-11-01T00:00:00Z", "measurement": "workflow_outcome", "caller": "ai-blocker-watch",
               "workflow": "blocker_watch_alarm", "workflow_id": identity, "parent_workflow_id": parent, "boundary": "alarm_scan",
               "outcome": "completed", "elapsed_ms": 2, "attempted_count": 1, "succeeded_count": 1, "failed_count": 0, "skipped_count": 0}
        def active(row): return remote.frame("active", record={"data": json.dumps(row), "queued": False})
        frames = active(end) + (active(end) if duplicate else b"")
        if not sdk:
            tick = {key: end[key] for key in self.report.RECEIPT_KEYS}
            tick.update(workflow="blocker_watch_tick", workflow_id=parent)
            frames += active(tick)
        frames += remote.frame("receipt", record=source)
        payload = b"original\x00\xff\n"
        code = ("import sys,json;sys.stdout.buffer.write(" + repr(remote.frame("started", record=started) + active(begin))
                + ");sys.stdout.buffer.flush();a=json.loads(sys.stdin.buffer.readline());assert a['kind']=='active_ack' and a['workflow_id']=='" + identity
                + "';sys.stdout.buffer.write(" + repr(remote.frame("stdout", data=base64.b64encode(payload).decode()) + frames)
                + ");sys.stdout.buffer.flush();assert json.loads(sys.stdin.buffer.readline())['kind']=='ack';sys.stdout.buffer.write("
                + repr(remote.frame("exit", code=3)) + ");sys.stdout.buffer.flush();sys.exit(3)")
        out, err = Capture(), Capture()
        with tempfile.TemporaryDirectory() as directory, mock.patch.object(sys, "stdout", out), mock.patch.object(sys, "stderr", err):
            target = Path(directory) / "active.json"
            status = remote.observe([sys.executable, "-I", "-c", code], arguments, target, 5,
                                    active_completion=True, sdk_coordinator=sdk)
            saved = json.loads(target.read_text())
        self.assertEqual(status, 3)
        self.assertEqual(out.buffer.getvalue(), payload)
        self.assertEqual(saved["measurement"], "linux_observed_windows_active_completion")
        self.assertEqual(saved["qualification_profile"], "sdk_only_no_provider" if sdk else "original_context")
        self.assertFalse(saved["original_privilege_equivalence"])
        self.assertIsNone(saved["detection_latency_ms"])
        self.assertGreaterEqual(saved["receipt_elapsed_ns"], saved["started_frame_elapsed_ns"])
        return saved

    def test_original_tick_never_upgrades_even_after_valid_ack(self):
        result = self.run_transport()
        self.assertFalse(result["active_completion_qualified"])
        self.assertTrue(result["active_completion_records"])
        self.assertEqual(result["active_completion_records"][0]["completion_qualification"]["unknown_reason"], "source_unknown")

    def test_sdk_data_requires_final_source_and_global_transcript(self):
        self.assertTrue(self.run_transport(sdk=True)["active_completion_qualified"])
        self.assertFalse(self.run_transport(sdk=True, duplicate=True)["active_completion_qualified"])

    def test_active_admission_refuses_before_process_creation(self):
        with mock.patch.object(remote.subprocess, "Popen") as launch:
            with self.assertRaises(ValueError):
                remote.observe(["unused"], ["tick"], "/unused", 1, active_completion=True, sdk_coordinator=True)
            launch.assert_not_called()


if __name__ == "__main__":
    unittest.main()
