#!/usr/bin/env python3
"""Canonical DATA-only schema and optional Windows writer refusals."""
import json
import os
from pathlib import Path
import sys
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools/github-requests"))
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


if __name__ == "__main__":
    unittest.main()
