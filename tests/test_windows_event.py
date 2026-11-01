#!/usr/bin/env python3
"""Canonical DATA-only schema and optional Windows writer refusals."""
import json
import ctypes
import os
from pathlib import Path
import sys
import subprocess
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/github-requests"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import windows_event
from test_remote_wait import canonical_report, event


class EventWriterTests(unittest.TestCase):
    def setUp(self):
        self.reference = canonical_report()
        self.patch = mock.patch.dict(sys.modules, {"report": self.reference})
        self.patch.start()
        self.addCleanup(self.patch.stop)

    def test_canonical_unqualified_event_only(self):
        self.assertEqual(json.loads(windows_event.event_bytes(event())), event())
        for key, value in (("source_verified", "verified"), ("clock_quality", "verified_bound"), ("extra", 1)):
            row = event()
            row[key] = value
            self.assertIsNone(windows_event.event_bytes(row))

    def test_duplicate_keys_and_oversize_are_not_sent(self):
        self.assertIsNone(windows_event.event_bytes('{"schema":4,"schema":4}'))
        self.assertIsNone(windows_event.event_bytes("x" * 4097))

    def test_unsupported_or_missing_handle_is_optional(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertFalse(windows_event.emit_event(event()))
        with mock.patch.dict(os.environ, {windows_event.HANDLE_ENV: "not-a-handle"}):
            self.assertFalse(windows_event.emit_event(event()))


class ActiveWriterTests(unittest.TestCase):
    def setUp(self):
        self.reference = canonical_report()
        self.patch = mock.patch.dict(sys.modules, {"report": self.reference})
        self.patch.start(); self.addCleanup(self.patch.stop)
        self.begin = {"schema": 1, "measurement": "active_completion_boundary", "phase": "begin",
                      "caller": "ai-blocker-watch", "workflow": "blocker_watch_alarm", "workflow_id": "a" * 32,
                      "parent_workflow_id": None, "boundary": "alarm_scan"}

    def direct(self, ack, times=(0, .001, .002)):
        kernel = mock.Mock()
        def read(handle, buffer, maximum, count, overlap):
            raw = json.dumps(ack).encode() + b"\n"
            ctypes.memmove(buffer, raw, len(raw)); count._obj.value = len(raw)
            return True
        kernel.ReadFile.side_effect = read
        with mock.patch.object(windows_event, "_kernel", return_value=kernel), \
             mock.patch.object(windows_event, "_message_pipe", return_value=True), \
             mock.patch.object(windows_event, "_write_once", return_value=True), \
             mock.patch.object(windows_event.time, "monotonic", side_effect=times), \
             mock.patch.dict(os.environ, {windows_event.ACTIVE_EVENT: "50", windows_event.ACTIVE_ACK: "51"}):
            return windows_event._active_direct("begin", self.begin, .250)

    def test_exact_timely_ack_only(self):
        ack = {"schema": 1, "phase": "ack", "workflow_id": "a" * 32}
        self.assertTrue(self.direct(ack))
        for change in ({"extra": 1}, {"schema": True}, {"phase": "end"}, {"workflow_id": "b" * 32}):
            self.assertFalse(self.direct(dict(ack, **change)))
        self.assertFalse(self.direct(ack, (0, .001, .251)))

    def test_child_claims_and_aliases_refused(self):
        self.begin["source_verified"] = "verified"
        self.assertFalse(windows_event._active_direct("begin", self.begin, .250))
        with mock.patch.dict(os.environ, {windows_event.ACTIVE_EVENT: "50", windows_event.ACTIVE_ACK: "50"}):
            with self.assertRaises(ValueError): windows_event._active_handles()

    def test_provider_original_once_even_if_closure_uncertain(self):
        kernel = mock.Mock(); kernel.GetStdHandle.return_value = 99
        kernel.CloseHandle.return_value = True; kernel.GetHandleInformation.return_value = False
        command = ["C:/Program Files/Git/usr/bin/timeout.exe", "2", "provider", "quoted space", "日本語"]
        for safe in (True, False):
            child = mock.Mock(); child.wait.return_value = 7
            environment = {windows_event.ACTIVE_EVENT: "50", windows_event.ACTIVE_ACK: "51",
                           "AI_GH_ACTIVE_PYTHON": "private", "AI_GH_QUALIFICATION_EVENT_HANDLE": "52",
                           "AI_GH_HTTP_COUNTER_HANDLE": "53", "SDK_CONTEXT_SENTINEL": "unchanged"}
            with mock.patch.object(windows_event, "_kernel", return_value=kernel), \
                 mock.patch.object(windows_event, "_message_pipe", return_value=safe), \
                 mock.patch.object(windows_event, "_write_once", return_value=False), \
                 mock.patch.object(ctypes, "get_last_error", return_value=6, create=True), \
                 mock.patch.object(ctypes, "set_last_error", create=True), \
                 mock.patch.dict(os.environ, environment, clear=True), \
                 mock.patch.object(windows_event.subprocess, "Popen", return_value=child) as launch:
                self.assertEqual(windows_event.active_harness_exec(command), 7)
                launch.assert_called_once()
                self.assertEqual(launch.call_args.args[0], command)
                self.assertTrue(launch.call_args.kwargs["close_fds"])
                self.assertEqual(launch.call_args.kwargs["env"], {"SDK_CONTEXT_SENTINEL": "unchanged"})


@unittest.skipUnless(os.name == "nt", "native Windows reciprocal pipe components")
class NativeActiveComponents(unittest.TestCase):
    def test_native_reciprocal_pipes_provider_isolation_and_compatibility(self):
        root = Path(__file__).resolve().parents[1]
        powershell = Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"
        result = subprocess.run([str(powershell), "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
                                 "-File", str(root / "tests/test-windows-active-completion.ps1"),
                                 "-SourceRoot", str(root), "-PythonExe", sys.executable],
                                capture_output=True, timeout=240)
        self.assertEqual(result.returncode, 0, result.stdout.decode(errors="replace") + result.stderr.decode(errors="replace"))
        rows = [json.loads(line) for line in result.stdout.decode().splitlines() if line.startswith("{")]
        self.assertEqual(len(rows), 1)
        self.assertGreaterEqual(rows[0]["native_active_component_cases"], 50)
        self.assertTrue(rows[0]["component_only"])
        self.assertFalse(rows[0]["original_active_qualified"])
        self.assertFalse(rows[0]["real_api_or_notifications"])


if __name__ == "__main__":
    unittest.main()
