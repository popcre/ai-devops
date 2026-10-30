#!/usr/bin/env python3
"""Transcript-store mining checks (plan step 9, #2063). Synthetic data only."""

import datetime as dt
import json
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "transcript_store"))
import build  # noqa: E402
import mine  # noqa: E402

NOW = dt.datetime(2026, 10, 30, tzinfo=dt.timezone.utc)
RECENT = "2026-10-25T12:00:00Z"
OLD = "2026-01-01T00:00:00Z"


class R:
    def __init__(self, out="", code=0):
        self.stdout, self.returncode = out, code


class FakeGH:
    """Answers gh calls; popcre/demo exists with #10 merged PR, #11 open PR, #12 open issue."""

    def __init__(self, remaining=5000):
        self.calls, self.remaining = [], remaining

    def __call__(self, cmd):
        self.calls.append(cmd)
        if cmd[:3] == ["gh", "api", "rate_limit"]:
            res = {"remaining": self.remaining, "reset": 100}
            return R(json.dumps({"resources": {"core": res, "graphql": res}}))
        if cmd[:3] == ["gh", "repo", "view"]:
            return R(json.dumps({"nameWithOwner": "popcre/demo"})) if cmd[3] == "popcre/demo" else R("", 1)
        if cmd[:3] == ["gh", "api", "graphql"]:
            known = {10: {"__typename": "PullRequest", "state": "MERGED", "mergedAt": "2026-10-20T00:00:00Z",
                          "closedAt": "2026-10-20T00:00:00Z"},
                     11: {"__typename": "PullRequest", "state": "OPEN", "mergedAt": None, "closedAt": None},
                     12: {"__typename": "Issue", "state": "OPEN", "closedAt": None}}
            q = cmd[-1]
            import re
            nums = [int(n) for n in re.findall(r"n(\d+): issueOrPullRequest", q)]
            return R(json.dumps({"data": {"repository": {f"n{n}": known.get(n) for n in nums}}}))
        return R("", 1)


def make_store(path: Path, segs, chunks=None):
    conn = sqlite3.connect(path)
    conn.executescript(build.SCHEMA)
    for i, (subject, text, repo, ts, tools) in enumerate(segs):
        cid, p = f"c{i}", f"m/s{i}.jsonl"
        conn.execute("INSERT INTO sessions (path, last_ts, repo) VALUES (?,?,?)", (p, ts, repo))
        conn.execute("INSERT INTO chunks (chunk_id, path, tool_seq_json) VALUES (?,?,?)", (cid, p, json.dumps(tools)))
        conn.execute("INSERT INTO segments (id, chunk_id, section_no, path, subject, repo, text) VALUES"
                     " (?,?,?,?,?,?,?)", (f"g{i}", cid, 1, p, subject, repo, text))
    for cid, tools in (chunks or {}).items():
        conn.execute("INSERT INTO chunks (chunk_id, tool_seq_json) VALUES (?,?)", (cid, json.dumps(tools)))
    conn.commit()
    return conn


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.root = self.tmp / "toolkit"
        sk = self.root / "skills" / "shared"
        for name, desc in (("pdf-merge", "Merge combine split rotate watermark pdf documents pages"),
                           ("pdf-split", "Split combine merge rotate pdf documents pages watermark"),
                           ("dns-audit", "Audit cloudflare zone records nameservers propagation")):
            (sk / name).mkdir(parents=True)
            (sk / name / "SKILL.md").write_text(f"---\nname: {name}\ndescription: {desc}\n---\nbody\n")
        (self.root / "templates" / "system").mkdir(parents=True)
        (self.root / "templates" / "system" / "G.md").write_text(
            "# G\n\n- **Quote every time in zebra format:** always.\n"
            "- **Never mention unicorns** anywhere.\n"
            "- Rotate the flux capacitor weekly and log the flux capacitor rotation.\n"
            "- Rotate the flux capacitor weekly and log the flux capacitor rotation please.\n")
        self.home = self.tmp / "repos"
        demo = self.home / "demo"
        (demo / "bin").mkdir(parents=True)
        (demo / "bin" / "real-tool").write_text("x\n")
        g = ["git", "-C", str(demo)]
        subprocess.run(g + ["init", "-q"], check=True)
        subprocess.run(g + ["add", "."], check=True)
        subprocess.run(g + ["-c", "user.name=t", "-c", "user.email=t@e", "commit", "-qm", "i"], check=True)
        self.sha = subprocess.run(g + ["rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()

    def ctx(self, conn, fake=None):
        cache = mine.Cache(self.tmp / "meta.db")
        return {"conn": conn, "skills": mine.load_skills(self.root), "bullets": mine.load_bullets(self.root),
                "now": NOW, "gh": mine.GH(cache, runner=fake or FakeGH(), sleep=lambda s: None, now=lambda: 0),
                "repos_home": self.home, "home_repo": "popcre/demo"}

    def filler(self, n=20, repo="demo", ts=RECENT):
        return [(f"filler {i}", f"ordinary note {i} about lunch weather", repo, ts, []) for i in range(n)]


class TestMine(Base):
    def test_skill_bypass_flags_only_without_skill_call(self):
        text = "merge split rotate watermark pdf documents pages"
        segs = [("pdf work", text, "demo", RECENT, ["Bash"]),
                ("pdf work again", text, "demo", RECENT, ["Skill", "Bash"])] + self.filler()
        conn = make_store(self.tmp / "s.db", segs)
        flags, _ = mine.check_skill_bypass(mine.segments(conn), self.ctx(conn), 0.35)
        ids = {f["segment"] for f in flags}
        self.assertEqual(ids, {"g0"})
        self.assertFalse(any("dns-audit" in f["object"] for f in flags))

    def test_instructions_unused_and_redundant(self):
        segs = [("t", "we quote every time in zebra format here", "demo", RECENT, []),
                ("u", "never mention unicorns ok", "demo", OLD, [])] + self.filler()
        conn = make_store(self.tmp / "s.db", segs)
        flags, _ = mine.check_instructions(mine.segments(conn), self.ctx(conn), 0.8)
        unused = [f for f in flags if f["subject"] == "unused bullet"]
        self.assertTrue(any("unicorns" in f["object"] for f in unused))  # only an old hit
        self.assertFalse(any("zebra" in f["object"] for f in unused))
        self.assertEqual(sum(1 for f in flags if f["subject"] == "redundant pair"), 1)

    def test_key_phrase_bold_or_rarest(self):
        idf = mine.Idf([["common", "rare1"], ["common"]])
        self.assertEqual(mine.key_phrase("**Lead in.** rest", idf), ["lead in"])
        self.assertEqual(len(mine.key_phrase("alpha bravo charlie delta echo", idf)), 3)

    def test_triggers_overlap(self):
        conn = make_store(self.tmp / "s.db", [])
        flags, _ = mine.check_triggers([], self.ctx(conn), 0.5)
        self.assertEqual([f["object"] for f in flags], ["pdf-merge <> pdf-split"])

    def test_toolseq_patterns(self):
        conn = make_store(self.tmp / "s.db", [], chunks={
            "rep": ["Grep"] * 5 + ["Bash"],
            "short": ["Grep"] * 4,
            "reread": [{"name": "Edit", "path": "a"}, {"name": "Read", "path": "a"}],
            "other": [{"name": "Edit", "path": "a"}, {"name": "Read", "path": "b"}],
            "poll": [{"name": "Bash", "command": "gh pr view 1"}] * 3,
            "names": ["Edit", "Read"]})
        flags, stats = mine.check_toolseq([], self.ctx(conn), 0)
        got = sorted((f["segment"], f["pattern"]) for f in flags)
        self.assertEqual(got, [("poll", "poll"), ("rep", "repeat"), ("reread", "reread")])
        self.assertEqual(stats["edit_then_read_names_only"], 1)

    def test_refs_stale_paths_and_numbers(self):
        segs = [("paths", "see bin/real-tool and bin/gone-tool and #10 and #99", "demo", RECENT, []),
                ("old", "bin/gone-old", "demo", OLD, []),
                ("other", "bin/gone-elsewhere #5", "ghost", RECENT, [])] + self.filler() \
            + self.filler(20, "ghost")
        conn = make_store(self.tmp / "s.db", segs)
        flags, stats = mine.check_refs(mine.segments(conn), self.ctx(conn), 0)
        objs = sorted(f["object"] for f in flags)
        self.assertEqual(objs, ["popcre/demo#99", "popcre/demo:bin/gone-tool"])
        self.assertEqual(stats["unresolved"], ["ghost"])

    def test_claims_hallucination(self):
        text = (f"PR #10 merged. merged #11 now. fixed in #99. step done on #12. "
                f"pushed commit {self.sha[:9]} and pushed commit abc1234ff")
        segs = [("claims", text, "demo", RECENT, []),
                ("early", "merged #10", "demo", "2026-10-01T00:00:00Z", [])] + self.filler()
        conn = make_store(self.tmp / "s.db", segs)
        flags, stats = mine.check_claims(mine.segments(conn), self.ctx(conn), 20)
        got = sorted((f["segment"], f["object"].split("/")[-1]) for f in flags)
        self.assertEqual(got, [("g0", "demo#11"), ("g0", "demo#99"), ("g0", "demo@abc1234ff"), ("g1", "demo#10")])
        self.assertEqual(stats["open_issue_done_claims"], 1)

    def test_gh_cache_and_rate_gate(self):
        fake = FakeGH(remaining=10)
        slept = []
        gh = mine.GH(mine.Cache(self.tmp / "m.db"), runner=fake, sleep=slept.append, now=lambda: 40)
        self.assertEqual(gh.numbers("popcre/demo", list(range(1, 120)))[10]["type"], "PullRequest")
        self.assertEqual(sum(1 for c in fake.calls if c[2] == "graphql"), 3)  # batches of 50
        self.assertTrue(slept and slept[0] == 61)
        n = len(fake.calls)
        gh2 = mine.GH(mine.Cache(self.tmp / "m.db"), runner=fake, sleep=slept.append, now=lambda: 40)
        gh2.numbers("popcre/demo", [10, 11])
        self.assertEqual(len(fake.calls), n)  # cached: a re-run costs nothing

    def test_main_writes_reports_without_text(self):
        segs = [("pdf work", "merge split rotate watermark pdf documents pages SECRETWORD", "demo", RECENT,
                 ["Bash"])] + self.filler()
        make_store(self.tmp / "s.db", segs).close()
        out = self.tmp / "reports"
        rc = mine.main(["skill-bypass", "--db", str(self.tmp / "s.db"), "--reports", str(out), "--cache",
                        str(self.tmp / "c.db"), "--repo-root", str(self.root), "--now", NOW.isoformat(),
                        "--date", "2026-10-30"])
        self.assertEqual(rc, 0)
        body = (out / "skill-bypass-2026-10-30.md").read_text()
        self.assertIn("pdf work", body)
        self.assertNotIn("SECRETWORD", body)


if __name__ == "__main__":
    unittest.main(verbosity=1)
