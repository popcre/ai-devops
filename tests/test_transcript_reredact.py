#!/usr/bin/env python3
"""Re-redaction pass over published store text (#2367 step 5.3). Synthetic only."""

import datetime as dt
import io
import json
import shutil
import sqlite3
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "transcript_store"))
import build  # noqa: E402
import reredact  # noqa: E402

# Synthetic shapes from tests/test_transcript_normalize.py (#2456); never real values.
AUTH_BODY = "-H \"Authorization: " + "a" * 20 + "\""
VENDOR_BODY = "erp_key: " + "k" * 16
CLEAN_BODY = "nothing secret in this body"


def old_built(hours: int = 3) -> str:
    """A build.py-style ``built`` stamp comfortably outside the 2 h guard."""
    try:
        from zoneinfo import ZoneInfo
        t = dt.datetime.now(ZoneInfo("America/New_York")) - dt.timedelta(hours=hours)
        return t.strftime("%Y-%m-%d %I:%M %p ") + (t.tzname() or "ET")
    except Exception:
        return (dt.datetime.now(dt.timezone.utc) - dt.timedelta(hours=hours)).isoformat()


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.store = self.store_root = self.root / "transcript-store"
        self.dbdir = self.store / "db"
        self.dbdir.mkdir(parents=True)
        self.work = self.root / "work" / "store.db"
        conn = build.connect(self.work)
        # two segments with unredacted stored text, one already clean
        for n, body in enumerate((AUTH_BODY, VENDOR_BODY, CLEAN_BODY), 1):
            conn.execute(
                "INSERT INTO segments (id, chunk_id, section_no, path, topic_slugs, subject, repo,"
                " repo_hint, text, label_flags, prompt_version, created)"
                " VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                (f"id{n}", "c1", n, "m1/a.jsonl", "ci", f"subject {n}", "demo", "demo",
                 body, "", "v5", "2026-10-30T07:00:00+00:00"))
            conn.execute("INSERT INTO segments_fts(rowid, subject, text) VALUES (?,?,?)",
                         (conn.execute("SELECT rowid FROM segments WHERE id=?", (f"id{n}",)).fetchone()[0],
                          f"subject {n}", body))
        conn.execute("INSERT INTO machine_status VALUES ('m1','ok','x','y',0,0,0,'z')")
        conn.commit()
        conn.close()
        self.src = self.dbdir / "store-20261108T130042Z.db"
        shutil.copyfile(self.work, self.src)
        self.pointer(before=True)

    def pointer(self, before=False, file=None):
        ptr = {"file": f"db/{self.src.name}", "sha256": build.sha256_file(self.src),
               "size": self.src.stat().st_size,
               "built": old_built(0 if not before else 3), "schema": 1}
        (self.store / "CURRENT.json").write_text(json.dumps(ptr), encoding="utf-8")
        return ptr

    def run_tool(self, *extra):
        out = io.StringIO()
        with redirect_stdout(out):
            rc = reredact.main(["--store-root", str(self.store), *extra])
        return rc, json.loads(out.getvalue())

    def dbs(self):
        return sorted(p.name for p in self.dbdir.glob("store-*.db"))

    def tearDown(self):
        self.tmp.cleanup()


class DryRun(Base):
    def test_counts_two_and_writes_nothing(self):
        ptr_before = (self.store / "CURRENT.json").read_text()
        rc, out = self.run_tool("--dry-run")
        self.assertEqual(rc, 0)
        self.assertTrue(out["dry_run"])
        self.assertEqual(out["segments"], 3)
        self.assertEqual(out["changed"], 2)
        self.assertEqual(out["by_kind"], {"authorization-header": 1, "vendor-key": 1})
        self.assertEqual({a["id"] for a in out["affected"]}, {"id1", "id2"})
        self.assertEqual(self.dbs(), [self.src.name])            # no new db file
        self.assertEqual((self.store / "CURRENT.json").read_text(), ptr_before)  # pointer untouched


class RealRun(Base):
    def test_new_db_original_untouched_ids_stable_and_pointer_repointed(self):
        src_sha = build.sha256_file(self.src)
        rc, out = self.run_tool()
        self.assertEqual(rc, 0)
        self.assertEqual(out["changed"], 2)
        self.assertEqual(out["by_kind"], {"authorization-header": 1, "vendor-key": 1})
        self.assertEqual(len(self.dbs()), 2)                     # copy created, original kept
        self.assertEqual(build.sha256_file(self.src), src_sha)   # original byte-identical
        ptr = json.loads((self.store / "CURRENT.json").read_text())
        self.assertEqual(ptr["file"], out["file"])
        self.assertNotEqual(ptr["file"], f"db/{self.src.name}")
        new = self.store / ptr["file"]
        self.assertEqual(new.stat().st_size, ptr["size"])
        self.assertEqual(build.sha256_file(new), ptr["sha256"])
        c = sqlite3.connect(f"file:{new}?mode=ro", uri=True)
        rows = dict(c.execute("SELECT id, text FROM segments").fetchall())
        subjects = dict(c.execute("SELECT id, subject FROM segments").fetchall())
        self.assertEqual(set(rows), {"id1", "id2", "id3"})       # ids unchanged
        self.assertIn("[REDACTED:authorization-header]", rows["id1"])
        self.assertNotIn("a" * 20, rows["id1"])
        self.assertIn("[REDACTED:vendor-key]", rows["id2"])
        self.assertNotIn("k" * 16, rows["id2"])
        self.assertEqual(rows["id3"], CLEAN_BODY)                 # clean row untouched
        for rowid, subj, text in c.execute("SELECT rowid, subject, text FROM segments"):
            fts = c.execute("SELECT subject, text FROM segments_fts WHERE rowid=?", (rowid,)).fetchone()
            self.assertEqual(fts, (subj, text))                   # FTS rebuilt in step
        self.assertEqual(c.execute("SELECT machine FROM machine_status").fetchall(), [("m1",)])  # untouched
        self.assertEqual(c.execute("PRAGMA journal_mode").fetchone()[0], "delete")
        self.assertTrue(all("[REDACTED:" not in s for s in subjects.values()))  # no subject matched
        c.close()

    def test_no_changes_leaves_store_as_is(self):
        c = sqlite3.connect(self.src)
        c.execute("UPDATE segments SET text='clean text only', subject='s'")
        c.commit()
        c.close()
        self.pointer(before=True)  # re-point: the edit changed the file's sha
        ptr_before = (self.store / "CURRENT.json").read_text()
        rc, out = self.run_tool()
        self.assertEqual(rc, 0)
        self.assertEqual(out["changed"], 0)
        self.assertEqual(self.dbs(), [self.src.name])             # no copy minted
        self.assertEqual((self.store / "CURRENT.json").read_text(), ptr_before)


class Guards(Base):
    def test_fresh_build_refused(self):
        self.pointer(before=False)  # built now
        with self.assertRaises(SystemExit) as cm:
            self.run_tool()
        self.assertIn("less than 2 h", str(cm.exception))

    def test_missing_db_refused(self):
        self.src.unlink()
        with self.assertRaises(SystemExit) as cm:
            self.run_tool()
        self.assertIn("missing", str(cm.exception))

    def test_sha_mismatch_refused(self):
        ptr = json.loads((self.store / "CURRENT.json").read_text())
        ptr["sha256"] = "0" * 64
        (self.store / "CURRENT.json").write_text(json.dumps(ptr), encoding="utf-8")
        with self.assertRaises(SystemExit) as cm:
            self.run_tool()
        self.assertIn("sha256", str(cm.exception))


if __name__ == "__main__":
    unittest.main(verbosity=1)
