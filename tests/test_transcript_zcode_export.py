#!/usr/bin/env python3
"""ZCode sqlite export for the transcript store. Synthetic fixtures only."""

import json
import os
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "transcript_store"))
import normalize  # noqa: E402
import zcode_export  # noqa: E402

T0 = 1793000000000  # milliseconds
ASK = "please look at the failing pipeline and tell me why it broke"
REPLY = "the pipeline broke because the deploy step lost its credentials"
THOUGHT = "private reasoning that must never be exported anywhere"


def make_db(path: Path) -> sqlite3.Connection:
    c = sqlite3.connect(path)
    c.executescript("""
      CREATE TABLE session (id TEXT, directory TEXT, parent_id TEXT);
      CREATE TABLE message (id TEXT, session_id TEXT, time_created INT, time_updated INT, data TEXT);
      CREATE TABLE part (id TEXT, message_id TEXT, session_id TEXT, time_created INT, data TEXT);
    """)
    c.execute("INSERT INTO session VALUES ('ses_1', 'C:\\repos\\demo-app', NULL)")
    c.execute("INSERT INTO session VALUES ('ses_empty', 'C:\\repos\\demo-app', NULL)")
    add(c, "m1", "ses_1", T0, "user", [{"type": "text", "text": ASK}])
    add(c, "m2", "ses_1", T0 + 1000, "assistant", [
        {"type": "reasoning", "text": THOUGHT},
        {"type": "tool", "tool": "bash", "state": {"output": "tool output stays out"}},
        {"type": "text", "text": REPLY}])
    add(c, "m3", "ses_empty", T0, "assistant", [{"type": "step-start"}])
    c.commit()
    return c


def add(c, mid, sid, ms, role, parts):
    c.execute("INSERT INTO message VALUES (?,?,?,?,?)", (mid, sid, ms, ms, json.dumps({"role": role})))
    for i, p in enumerate(parts):
        c.execute("INSERT INTO part VALUES (?,?,?,?,?)", (f"{mid}-{i}", mid, sid, ms + i, json.dumps(p)))


class Export(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)
        self.db = self.dir / "db.sqlite"
        self.dest = self.dir / "out"
        self.conn = make_db(self.db)
        self.addCleanup(self.conn.close)

    def test_normalizer_reads_the_export(self):
        self.assertEqual(zcode_export.export(self.db, self.dest), {"sessions": 2, "written": 1, "empty": 1})
        r = normalize.parse_file(self.dest / "ses_1.jsonl", machine="m", rel_path="m/zcode/sessions/ses_1.jsonl")
        self.assertEqual([t["role"] for t in r["turns"]], ["user", "assistant"])
        self.assertEqual(r["turns"][1]["tools"], ["bash"])
        self.assertEqual(r["meta"]["session_id"], "ses_1")
        self.assertEqual(r["meta"]["repo"], "demo-app")
        self.assertEqual(r["meta"]["last_ts"], zcode_export.iso(T0 + 1000))

    def test_reasoning_and_tool_output_stay_out(self):
        zcode_export.export(self.db, self.dest)
        raw = (self.dest / "ses_1.jsonl").read_text(encoding="utf-8")
        self.assertNotIn(THOUGHT, raw)
        self.assertNotIn("tool output stays out", raw)

    def test_mtime_is_last_activity_and_unchanged_session_is_not_rewritten(self):
        zcode_export.export(self.db, self.dest)
        target = self.dest / "ses_1.jsonl"
        self.assertAlmostEqual(target.stat().st_mtime, (T0 + 1000) / 1000, delta=1)
        self.assertEqual(zcode_export.export(self.db, self.dest)["written"], 0)

    def test_new_message_rewrites_the_session(self):
        zcode_export.export(self.db, self.dest)
        add(self.conn, "m4", "ses_1", T0 + 90000, "user", [{"type": "text", "text": ASK + " again"}])
        self.conn.commit()
        self.assertEqual(zcode_export.export(self.db, self.dest)["written"], 1)
        r = normalize.parse_file(self.dest / "ses_1.jsonl")
        self.assertEqual(len(r["turns"]), 3)

    def test_unsafe_session_id_is_refused(self):
        self.conn.execute("INSERT INTO session VALUES ('../esc', 'x', NULL)")
        add(self.conn, "m5", "../esc", T0, "user", [{"type": "text", "text": ASK}])
        self.conn.commit()
        with self.assertRaises(ValueError):
            zcode_export.export(self.db, self.dest)
        self.assertFalse(os.path.exists(self.dir / "esc.jsonl"))


if __name__ == "__main__":
    unittest.main()
