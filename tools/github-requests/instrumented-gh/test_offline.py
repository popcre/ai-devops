#!/usr/bin/env python3
"""Offline metadata-contract tests; do not claim Go/build/live qualification."""
import importlib.util
import json
import pathlib
import unittest

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("counter_runner", HERE / "run.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


def channel(**overrides):
    final = {"schema": 1, "finished": True, "observed_completed_writes": 4,
             "failed_write_attempts": 0, "observed_external_writes": 1,
             "incomplete": False, "http_requests": None}
    final.update(overrides)
    return b'{"schema":1,"started":true}\n' + json.dumps(final).encode() + b"\n"


class OfflineContract(unittest.TestCase):
    def test_builtin_scope_excludes_durable_and_arbitrary_children(self):
        for args in (['api', 'private'], ['api', 'pages', '--paginate'], ['api', 'private', '-XGET'],
                     ['auth', 'status'], ['pr', 'checks', '1'], ['workflow', 'view', '1']):
            self.assertTrue(runner.eligible(args))
        for args in ([], ['auth', 'setup-git'], ['auth', 'login'], ['skills', 'install'],
                     ['codespace', 'ssh'], ['alias', 'set'], ['fixture-extension'],
                     ['api', 'private', '-XPOST'], ['api', 'private', '--method=DELETE'],
                     ['api', 'private', '-fquery=mutation'], ['pr', 'view', '1', '--web']):
            self.assertFalse(runner.eligible(args))

    def test_completed_subset_remains_unknown_total(self):
        record = runner.validate(channel())
        self.assertTrue(record["complete"])
        self.assertEqual(record["observed_completed_writes"], 4)
        self.assertIsNone(record["http_requests"])

    def test_failed_write_is_partial(self):
        record = runner.validate(channel(failed_write_attempts=1, incomplete=True))
        self.assertFalse(record["complete"])
        self.assertEqual(record["observed_completed_writes"], 4)
        self.assertIsNone(record["http_requests"])

    def test_malformed_or_oversized_channel_is_unknown(self):
        for raw in (b"", b'[]\n', b'null\n', b'fake-secret-sentinel', b'x' * 4097,
                    b'{"schema":1,"started":true}\n',
                    channel() + b'{}\n', channel().replace(b'"started":true', b'"started":1'),
                    channel().replace(b'"schema":1', b'"schema":false,"schema":1')):
            self.assertEqual(runner.validate(raw), runner.UNKNOWN)

    def test_invalid_counts_and_extra_content_are_unknown(self):
        for key in ("observed_completed_writes", "failed_write_attempts", "observed_external_writes"):
            for value in (True, -1, 1000000001, 1.0, "4", None):
                self.assertEqual(runner.validate(channel(**{key: value})), runner.UNKNOWN)
        self.assertEqual(runner.validate(channel(error="fake-secret-sentinel")), runner.UNKNOWN)
        self.assertEqual(runner.validate(channel(http_requests=4)), runner.UNKNOWN)


if __name__ == "__main__":
    unittest.main()
