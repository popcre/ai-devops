#!/usr/bin/env python3
"""Transcript-store writer and read protocol (plan step 4). Synthetic only."""

import json
import os
import sqlite3
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "transcript_store"))
import build  # noqa: E402
import reader  # noqa: E402
import segment  # noqa: E402

NOSLEEP = lambda s: None  # noqa: E731
OLD = time.time() - 3 * 86400  # sessions quiet for days: no live-tail hold


def line(role, text, sid="s1", ts="2026-10-01T00:00:00Z"):
    return json.dumps({"type": role, "sessionId": sid, "cwd": "/home/u/repos/demo", "timestamp": ts,
                       "message": {"role": role, "content": [{"type": "text", "text": text},
                                                             {"type": "tool_use", "name": "Bash", "input": {}}]}})


class FakeSD:
    def __init__(self, fail=False):
        self.calls, self.fail = 0, fail

    def __call__(self, system, user):
        self.calls += 1
        if self.fail:
            raise segment.ScaleDownError("HTTP 429", 429)
        return f"### TOPIC: ci | Pipeline work number {self.calls} | repo=demo\ncleaned text {self.calls}"


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.archive = self.root / "chat_transcripts"
        self.store = self.root / "transcript-store"
        self.dbp = self.root / "work" / "store.db"
        self.conn = build.connect(self.dbp)

    def tearDown(self):
        self.conn.close()
        self.tmp.cleanup()

    def session(self, rel, lines, newline=True, mtime=OLD):
        p = self.archive / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("\n".join(lines) + ("\n" if newline else ""), encoding="utf-8")
        os.utime(p, (mtime, mtime))
        return p

    def run_build(self, sd, limit=None, now=None):
        r = build.Runner(self.conn, sd, "v1", threads=2, budget=build.Budget(limit), now=now, sleep=NOSLEEP)
        build.run_archive(self.conn, self.archive, r)
        return r.stats

    def count(self, sql, *args):
        return self.conn.execute(sql, args).fetchone()[0]


class Incremental(Base):
    def test_unchanged_file_skipped(self):
        self.session("m1/a.jsonl", [line("user", "first request about the pipeline")])
        sd = FakeSD()
        self.run_build(sd)
        self.assertEqual(sd.calls, 1)
        st = self.run_build(sd)
        self.assertEqual(sd.calls, 1)
        self.assertEqual(st["sessions_skipped"], 1)
        self.assertEqual(self.count("SELECT count(*) FROM segments"), 1)
        self.assertEqual(self.count("SELECT count(*) FROM segments_fts WHERE segments_fts MATCH 'cleaned'"), 1)

    def test_grown_file_only_new_turns(self):
        lines = [line("user", "first request about the pipeline")]
        self.session("m1/a.jsonl", lines)
        sd = FakeSD()
        self.run_build(sd)
        lines.append(line("assistant", "second message after the file grew"))
        self.session("m1/a.jsonl", lines, mtime=OLD + 10)
        self.run_build(sd)
        self.assertEqual(sd.calls, 2)
        rows = self.conn.execute("SELECT turn_keys_json FROM chunks ORDER BY created, rowid").fetchall()
        self.assertEqual([len(json.loads(r[0])) for r in rows], [1, 1])
        tools = self.conn.execute("SELECT tool_seq_json FROM chunks").fetchall()
        self.assertEqual(json.loads(tools[0][0]), [["Bash"]])

    def test_build_truncated_last_line_reread(self):
        full = line("assistant", "second message cut mid upload")
        self.session("m1/a.jsonl", [line("user", "first request about the pipeline"), full[:25]], newline=False)
        sd = FakeSD()
        self.run_build(sd)
        self.assertEqual(self.count("SELECT status FROM sessions"), "partial")
        self.assertEqual(self.count("SELECT count(*) FROM seen_turns"), 1)
        self.session("m1/a.jsonl", [line("user", "first request about the pipeline"), full], mtime=OLD + 5)
        self.run_build(sd)
        self.assertEqual(self.count("SELECT status FROM sessions"), "ok")
        self.assertEqual(self.count("SELECT count(*) FROM seen_turns"), 2)

    def test_shrunk_file_reprocessed(self):
        self.session("m1/a.jsonl", [line("user", f"request number {i} about things") for i in range(4)])
        sd = FakeSD()
        self.run_build(sd)
        self.session("m1/a.jsonl", [line("user", "request number 0 about things")], mtime=OLD + 5)
        self.run_build(sd)
        self.assertEqual(self.count("SELECT count(*) FROM seen_turns"), 1)
        self.assertEqual(self.count("SELECT count(*) FROM segments"), 1)

    def test_fork_dedup_and_helper_files_excluded(self):
        opening = [line("user", f"shared opening turn {i} text") for i in range(3)]
        self.session("m1/a.jsonl", opening, mtime=OLD)
        self.session("m1/b.jsonl", opening + [line("user", "fork only follow up turn")], mtime=OLD + 1)
        self.session("m1/.partial/c.jsonl", [line("user", "partial upload helper file")])
        self.session("m1/d (conflicted copy).jsonl", [line("user", "conflicted copy file here")])
        self.session("m1/e.txt", [line("user", "not a jsonl file at all")])
        self.run_build(FakeSD())
        self.assertEqual(self.count("SELECT count(*) FROM sessions"), 2)
        self.assertEqual(self.count("SELECT count(DISTINCT lineage_id) FROM sessions"), 1)
        self.assertEqual(self.count("SELECT count(*) FROM seen_turns"), 4)

    def test_failed_chunk_recorded_and_resumed(self):
        self.session("m1/a.jsonl", [line("user", "first request about the pipeline")])
        self.run_build(FakeSD(fail=True))
        self.assertEqual(self.count("SELECT status FROM chunks"), "failed")
        self.assertEqual(self.count("SELECT status FROM sessions"), "failed")
        cid = self.count("SELECT chunk_id FROM chunks")
        sd = FakeSD()
        self.run_build(sd)
        self.assertEqual(sd.calls, 1)
        self.assertEqual(self.count("SELECT chunk_id FROM chunks"), cid)
        self.assertEqual(self.count("SELECT status FROM chunks"), "ok")

    def test_limit_calls_leaves_sending_for_resume(self):
        for i in range(3):
            self.session(f"m1/s{i}.jsonl", [line("user", f"session {i} request text", sid=f"s{i}")], mtime=OLD + i)
        sd = FakeSD()
        self.run_build(sd, limit=1)
        self.assertEqual(sd.calls, 1)
        self.run_build(sd)
        self.assertEqual(sd.calls, 3)
        self.assertEqual(self.count("SELECT count(*) FROM chunks WHERE status='ok'"), 3)

    def test_limit_calls_counts_reasks(self):
        class Bad(FakeSD):
            def __call__(self, system, user):
                self.calls += 1
                return "### TOPIC: weather | off list label here | repo=x\nb"
        for i in range(3):
            self.session(f"m1/s{i}.jsonl", [line("user", f"session {i} request text", sid=f"s{i}")], mtime=OLD + i)
        sd = Bad()
        self.run_build(sd, limit=3)
        self.assertEqual(sd.calls, 3)  # each chunk costs 2 calls (ask + re-ask)

    def test_publish_pointer_replaced_atomically(self):
        build.publish(self.dbp, self.store, now=1_800_000_000, stage_dir=self.root / "stage")
        self.assertFalse(list(self.store.glob(".incoming-*")))
        self.assertIn("sha256", json.loads((self.store / "CURRENT.json").read_text()))

    def test_live_short_tail_pending(self):
        now = time.time()
        self.session("m1/a.jsonl", [line("user", "short live conversation turn")], mtime=now - 60)
        sd = FakeSD()
        self.run_build(sd, now=now)
        self.assertEqual(sd.calls, 0)
        self.assertEqual(self.count("SELECT status FROM chunks"), "pending")
        self.run_build(sd, now=now + 25 * 3600)
        self.assertEqual(sd.calls, 1)
        self.assertEqual(self.count("SELECT status FROM chunks"), "ok")

    def test_relabel_swaps_new_prompt_version(self):
        self.session("m1/a.jsonl", [line("user", "first request about the pipeline")])
        self.run_build(FakeSD())
        old_seg = self.count("SELECT id FROM segments")
        orig = segment.load_prompt
        segment.load_prompt = lambda v="v1": "relabel prompt " + v
        try:
            ok = build.relabel(self.conn, self.archive, FakeSD(), "v2", threads=1, budget=build.Budget(None), sleep=NOSLEEP)
        finally:
            segment.load_prompt = orig
        self.assertTrue(ok)
        self.assertEqual(self.count("SELECT prompt_version FROM segments"), "v2")
        self.assertNotEqual(self.count("SELECT id FROM segments"), old_seg)
        self.assertEqual(self.count("SELECT count(*) FROM chunks"), 1)
        self.assertEqual(self.count("SELECT value FROM meta WHERE key='prompt_version'"), "v2")
        self.assertEqual(self.count("SELECT count(*) FROM segments_fts"), 1)


class Labels(Base):
    def test_labels_import_mapping(self):
        ldb = self.root / "labels.db"
        c = sqlite3.connect(ldb)
        c.execute("CREATE TABLE review_labels(src, repo, work, mode, reviewer, verdict, value, why)")
        c.executemany("INSERT INTO review_labels VALUES (?,?,?,?,?,?,?,?)",
                      [(f"m/{i}.jsonl", "repo", "w", "mode", "rev", "APPROVE", "high", "why") for i in range(25)])
        c.commit()
        c.close()
        self.assertEqual(build.import_labels(self.conn, ldb), 25)
        self.assertEqual(build.import_labels(self.conn, ldb), 25)  # idempotent
        self.assertEqual(self.count("SELECT count(*) FROM question_labels"), 25)
        q, src, pv, fields = self.conn.execute(
            "SELECT question, src, prompt_version, fields_json FROM question_labels WHERE src='m/3.jsonl'").fetchone()
        self.assertEqual((q, pv), ("review-value-2026-10-29", "review-value-v0"))
        self.assertEqual(json.loads(fields), {"repo": "repo", "work": "w", "mode": "mode", "reviewer": "rev",
                                              "verdict": "APPROVE", "value": "high", "why": "why"})


class Inbox(Base):
    NAME = "review-value__20261029T120000Z__edge-dev.jsonl"

    def put(self, name, lines):
        inbox = self.store / "inbox"
        inbox.mkdir(parents=True, exist_ok=True)
        p = inbox / name
        p.write_bytes(lines if isinstance(lines, bytes) else ("\n".join(lines) + "\n").encode())
        return p

    def good(self, **over):
        row = {"question": "review-value", "src": "edge-dev/x.jsonl", "prompt_version": "p1",
               "fields": {"verdict": "ok", "n": 3, "flag": True}}
        row.update(over)
        return json.dumps(row)

    def test_applied_once(self):
        self.put(self.NAME, [self.good(), self.good(fields={"note": "pass " + "gh" + "p_" + "Q" * 24})])
        out = build.apply_inbox(self.conn, self.store / "inbox")
        self.assertEqual(out["applied"], 1)
        self.assertEqual(self.count("SELECT count(*) FROM question_labels"), 2)
        self.assertNotIn("p_QQQQ", self.count("SELECT group_concat(fields_json) FROM question_labels"))
        self.assertTrue((self.store / "inbox/applied" / self.NAME).exists())
        self.put(self.NAME, [self.good(), self.good(fields={"note": "pass " + "gh" + "p_" + "Q" * 24})])
        out = build.apply_inbox(self.conn, self.store / "inbox")
        self.assertEqual(out["duplicates"], 1)
        self.assertEqual(self.count("SELECT count(*) FROM question_labels"), 2)

    def assert_rejected(self, name, lines):
        self.put(name, lines)
        out = build.apply_inbox(self.conn, self.store / "inbox")
        self.assertEqual(out["rejected"], 1, name)
        self.assertTrue((self.store / "inbox/rejected" / (name + ".reason.txt")).exists())
        self.assertEqual(self.count("SELECT count(*) FROM question_labels"), 0)
        for f in (self.store / "inbox/rejected").iterdir():
            f.unlink()

    def test_build_inbox_rejects_bad_file(self):
        self.assert_rejected(self.NAME, [self.good(), "{bad json"])
        self.assert_rejected(self.NAME, [json.dumps({"question": "review-value", "src": "a", "prompt_version": "p",
                                                     "fields": {}, "extra": 1})])
        self.assert_rejected(self.NAME, [self.good(src="../../etc/passwd")])
        self.assert_rejected(self.NAME, [self.good(fields={"k": "x" * 9000})])
        self.assert_rejected(self.NAME, [self.good(fields={"nested": {"a": 1}})])
        self.assert_rejected(self.NAME, [self.good(question="other-q")])
        big = (self.good() + "\n").encode() * (build.INBOX_MAX_BYTES // len(self.good()) + 10)
        self.assert_rejected(self.NAME, big)

    def test_build_inbox_rejects_traversal(self):
        for name in ("..__20261029T120000Z__h.jsonl", "a..b__20261029T120000Z__h.jsonl",
                     "q__20261029T120000Z__h.txt", "Q__bad__h.jsonl"):
            self.assert_rejected(name, [self.good()])

    def test_conflicted_inbox_file_moved(self):
        name = "review-value__20261029T120000Z__edge-dev (conflicted copy).jsonl"
        self.put(name, [self.good()])
        out = build.apply_inbox(self.conn, self.store / "inbox")
        self.assertEqual(out["conflicts"], 1)
        self.assertTrue((self.store / "inbox/conflicts" / name).exists())

    def test_retention_only_in_applied_and_rejected(self):
        for sub in ("applied", "rejected", "conflicts"):
            d = self.store / "inbox" / sub
            d.mkdir(parents=True)
            f = d / "old.jsonl"
            f.write_text("x")
            os.utime(f, (time.time() - 100 * 86400,) * 2)
        build.apply_inbox(self.conn, self.store / "inbox")
        self.assertFalse((self.store / "inbox/applied/old.jsonl").exists())
        self.assertFalse((self.store / "inbox/rejected/old.jsonl").exists())
        self.assertTrue((self.store / "inbox/conflicts/old.jsonl").exists())


class Publish(Base):
    def publish(self, now):
        return build.publish(self.dbp, self.store, now=now, stage_dir=self.root / "stage")

    def test_versioned_file_then_pointer(self):
        self.session("m1/a.jsonl", [line("user", "first request about the pipeline")])
        self.run_build(FakeSD())
        self.conn.commit()
        out = self.publish(1_800_000_000)
        ptr = json.loads((self.store / "CURRENT.json").read_text())
        self.assertEqual(ptr["file"], out["file"])
        target = self.store / ptr["file"]
        self.assertEqual(target.stat().st_size, ptr["size"])
        self.assertEqual(build.sha256_file(target), ptr["sha256"])
        self.assertFalse(list((self.store / "db").glob(".incoming-*")))
        self.assertEqual(ptr["schema"], 1)
        c = sqlite3.connect(f"file:{target}?mode=ro", uri=True)
        self.assertEqual(c.execute("PRAGMA journal_mode").fetchone()[0], "delete")
        c.close()

    def test_keep_three_and_24h_rule(self):
        t0 = 1_800_000_000
        for i in range(5):
            self.publish(t0 + i * 60)
        self.assertEqual(len(list((self.store / "db").glob("store-*.db"))), 5)  # < 24 h: nothing pruned
        self.publish(t0 + 2 * 86400)
        self.assertEqual(len(list((self.store / "db").glob("store-*.db"))), 3)

    def test_conflicted_copy_moved_not_deleted(self):
        (self.store / "db").mkdir(parents=True)
        bad = self.store / "db" / "store-1 (conflicted copy).db"
        bad.write_text("x")
        out = self.publish(1_800_000_000)
        self.assertEqual(out["conflicts"], 1)
        self.assertFalse(bad.exists())
        self.assertTrue((self.store / "conflicts" / bad.name).exists())


class Reader(Base):
    def publish_two(self):
        build.publish(self.dbp, self.store, now=1_800_000_000, stage_dir=self.root / "stage")
        self.conn.execute("INSERT INTO meta VALUES ('marker', 'new')")
        self.conn.commit()
        build.publish(self.dbp, self.store, now=1_800_000_100, stage_dir=self.root / "stage")
        return json.loads((self.store / "CURRENT.json").read_text())

    def test_query_verifies_pointer_hash(self):
        ptr = self.publish_two()
        cache = self.root / "cache"
        conn = reader.open_store(self.store, cache, sleep=NOSLEEP)
        self.assertEqual(conn.execute("SELECT value FROM meta WHERE key='marker'").fetchone()[0], "new")
        info = reader.last_open_info()
        self.assertFalse(info.fallback)
        self.assertEqual(info.sha256, ptr["sha256"])
        with self.assertRaises(sqlite3.OperationalError):
            conn.execute("INSERT INTO meta VALUES ('x','y')")  # read-only
        conn.close()
        self.assertNotIn(str(self.store), str(info.path))
        # cache reuse: same file, no new copy
        again = reader.fetch_store(self.store, cache, sleep=NOSLEEP)
        self.assertEqual(again.path, info.path)

    def test_wrong_size_falls_back_to_previous(self):
        ptr = self.publish_two()
        ptr["size"] += 7
        (self.store / "CURRENT.json").write_text(json.dumps(ptr))
        waits = []
        info = reader.fetch_store(self.store, self.root / "cache", sleep=waits.append)
        self.assertTrue(info.fallback)
        self.assertEqual(waits, [reader.MISMATCH_WAIT])
        c = sqlite3.connect(f"file:{info.path}?mode=ro", uri=True)
        self.assertIsNone(c.execute("SELECT value FROM meta WHERE key='marker'").fetchone())
        c.close()

    def test_wrong_hash_falls_back(self):
        ptr = self.publish_two()
        ptr["sha256"] = "0" * 64
        (self.store / "CURRENT.json").write_text(json.dumps(ptr))
        self.assertTrue(reader.fetch_store(self.store, self.root / "cache", sleep=NOSLEEP).fallback)

    def test_query_placeholder_message(self):
        self.store.mkdir(parents=True)
        (self.store / "CURRENT.json").write_bytes(b"")
        with self.assertRaises(reader.StoreUnavailable) as cm:
            reader.fetch_store(self.store, self.root / "cache", sleep=NOSLEEP)
        self.assertEqual(str(cm.exception), reader.NOT_AVAILABLE)
        (self.store / "CURRENT.json").unlink()
        with self.assertRaises(reader.StoreUnavailable):
            reader.fetch_store(self.store, self.root / "cache", sleep=NOSLEEP)

    def test_unparsable_pointer_retried_then_unavailable(self):
        self.store.mkdir(parents=True)
        (self.store / "CURRENT.json").write_text("{half")
        waits = []
        with self.assertRaises(reader.StoreUnavailable):
            reader.fetch_store(self.store, self.root / "cache", sleep=waits.append)
        self.assertEqual(waits, [reader.POINTER_WAIT] * reader.POINTER_RETRIES)

    def test_pointer_outside_db_refused(self):
        self.store.mkdir(parents=True)
        (self.store / "CURRENT.json").write_text(json.dumps({"file": "../x.db", "sha256": "a", "size": 1}))
        with self.assertRaises(reader.StoreUnavailable):
            reader.fetch_store(self.store, self.root / "cache", sleep=NOSLEEP)


if __name__ == "__main__":
    unittest.main(verbosity=1)
