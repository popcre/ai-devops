#!/usr/bin/env python3
"""Transcript-store mining checks (plan_transcript-store.md step 9, #2063).

One subcommand per check; each writes a private Markdown report to
``Dropbox/ai/transcript-store/reports/<check>-<date>.md``. Stdlib only and no
model calls: everything here is word counting, regexes, git and gh lookups.

Reports carry segment ids, subjects and the referenced object, never segment
text, so a flag can be hand-checked without reading transcript content.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import math
import re
import sqlite3
import subprocess
import sys
import time
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import reader  # noqa: E402

CHECKS = ("skill-bypass", "instructions", "triggers", "toolseq", "refs", "claims")
DEFAULTS = {"skill-bypass": 0.35, "instructions": 0.8, "triggers": 0.5}
OWNERS = ("popcre", "u2giants")
REPOS_HOME = Path.home() / "repos"
STOP = set("""
about above after again against also because been before being below between both
could does doing down during each from further have having here into itself just
more most only other ours over same should some such than that their theirs them
then there these they this those through under until very what when where which
while will with would your yours""".split())
WORD = re.compile(r"[a-z][a-z0-9]{3,}")


# ----------------------------------------------------------------- text math

def words(text: str) -> list[str]:
    return [w for w in WORD.findall((text or "").lower()) if w not in STOP]


class Idf:
    """Document frequencies over a corpus of word sets."""

    def __init__(self, docs):
        self.df: Counter = Counter()
        self.n = 0
        for d in docs:
            self.n += 1
            self.df.update(set(d))

    def idf(self, w: str) -> float:
        return math.log((self.n + 1) / (self.df.get(w, 0) + 1)) + 1.0

    def vec(self, toks: list[str]) -> dict:
        tf = Counter(toks)
        v = {w: (1 + math.log(c)) * self.idf(w) for w, c in tf.items()}
        norm = math.sqrt(sum(x * x for x in v.values())) or 1.0
        return {w: x / norm for w, x in v.items()}


def cosine(a: dict, b: dict) -> float:
    if len(a) > len(b):
        a, b = b, a
    return sum(x * b.get(w, 0.0) for w, x in a.items())


# --------------------------------------------------------------- store access

def parse_ts(s) -> dt.datetime | None:
    if not s:
        return None
    try:
        t = dt.datetime.fromisoformat(str(s).replace("Z", "+00:00"))
    except ValueError:
        return None
    return t if t.tzinfo else t.replace(tzinfo=dt.timezone.utc)


def segments(conn: sqlite3.Connection) -> list[dict]:
    """Segments with their chunk tool sequence and session end time."""
    rows = conn.execute(
        "SELECT s.id, s.subject, s.text, s.repo, s.topic_slugs, c.tool_seq_json, se.last_ts, s.created"
        " FROM segments s LEFT JOIN chunks c ON c.chunk_id = s.chunk_id"
        " LEFT JOIN sessions se ON se.path = s.path").fetchall()
    out = []
    for sid, subj, text, repo, slugs, seq, last, created in rows:
        out.append({"id": sid, "subject": subj or "", "text": text or "", "repo": repo or "unknown",
                    "slugs": slugs or "", "tools": _tools(seq), "ts": parse_ts(last) or parse_ts(created)})
    return out


def _tools(seq_json) -> list:
    try:
        seq = json.loads(seq_json or "[]")
    except ValueError:
        return []
    return seq if isinstance(seq, list) else []


def tool_name(t) -> str:
    return t.get("name", "") if isinstance(t, dict) else str(t)


# --------------------------------------------------------------- repo sources

def frontmatter(path: Path) -> dict:
    text = path.read_text(encoding="utf-8", errors="replace")
    m = re.match(r"---\s*\n(.*?)\n---", text, re.S)
    out = {}
    if m:
        key = None
        for ln in m.group(1).splitlines():
            km = re.match(r"([A-Za-z_-]+):\s*(.*)", ln)
            if km:
                key, out[km.group(1)] = km.group(1), km.group(2).strip().strip("'\"")
            elif key and ln.startswith((" ", "\t")):
                out[key] = (out[key] + " " + ln.strip()).strip()
    return out


def load_skills(root: Path) -> list[dict]:
    skills = []
    for p in sorted((root / "skills").glob("**/SKILL.md")):
        fm = frontmatter(p)
        desc = fm.get("description", "")
        if desc in (">", "|", ">-", "|-"):
            desc = ""
        skills.append({"name": fm.get("name") or p.parent.name, "file": p.relative_to(root).as_posix(),
                       "description": desc})
    return skills


BULLET = re.compile(r"^- (.*)")


def load_bullets(root: Path) -> list[dict]:
    """Top-level bullets of the globals templates, joined with continuations."""
    out = []
    for p in sorted((root / "templates" / "system").glob("*.md")):
        cur = None
        for ln in p.read_text(encoding="utf-8", errors="replace").splitlines():
            m = BULLET.match(ln)
            if m:
                cur = {"file": p.relative_to(root).as_posix(), "text": m.group(1)}
                out.append(cur)
            elif cur and ln.startswith("  ") and ln.strip():
                cur["text"] += " " + ln.strip()
            else:
                cur = None
    return out


def key_phrase(bullet: str, idf: Idf) -> list[str]:
    m = re.match(r"\*\*(.+?)\*\*", bullet)
    if m:
        return [m.group(1).strip().rstrip(".:").lower()]
    ws = sorted(set(words(bullet)), key=lambda w: (idf.df.get(w, 0), w))
    return ws[:3]


# ------------------------------------------------------------------ git and gh

def run(cmd, cwd=None) -> subprocess.CompletedProcess:
    try:
        return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=120)
    except (subprocess.TimeoutExpired, OSError):
        return subprocess.CompletedProcess(cmd, 127, stdout="", stderr="lookup unavailable")


class Cache:
    """Answers cached in a sqlite ``meta`` table (the store is read-only)."""

    def __init__(self, path: Path):
        path.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(str(path))
        self.conn.execute("CREATE TABLE IF NOT EXISTS meta (key TEXT PRIMARY KEY, value TEXT)")

    def get(self, key):
        r = self.conn.execute("SELECT value FROM meta WHERE key=?", (key,)).fetchone()
        return json.loads(r[0]) if r else None

    def put(self, key, value):
        self.conn.execute("INSERT OR REPLACE INTO meta VALUES (?,?)", (key, json.dumps(value)))
        self.conn.commit()


class GH:
    """gh lookups with a rate-limit gate and a persistent answer cache."""

    def __init__(self, cache: Cache, runner=run, sleep=time.sleep, now=time.time):
        self.cache, self.runner, self.sleep, self.now = cache, runner, sleep, now
        self.calls = 0

    def _gate(self, resource: str):
        r = self.runner(["gh", "api", "rate_limit"])
        if r.returncode != 0:
            return
        try:
            res = json.loads(r.stdout)["resources"][resource]
        except (ValueError, KeyError):
            return
        if res.get("remaining", 1000) < 500:
            wait = max(0, int(res.get("reset", 0)) - int(self.now())) + 1
            self.sleep(min(wait, 3700))

    def repo(self, name: str):
        """``owner/name`` for the first owner that has it, else None."""
        key = f"mine:repo:{name}"
        hit = self.cache.get(key)
        if hit is not None:
            return hit or None
        found = ""
        for owner in OWNERS:
            self._gate("core")
            self.calls += 1
            r = self.runner(["gh", "repo", "view", f"{owner}/{name}", "--json", "nameWithOwner"])
            if r.returncode == 0:
                try:
                    found = json.loads(r.stdout)["nameWithOwner"]
                except (ValueError, KeyError):
                    found = f"{owner}/{name}"
                break
        if found:
            self.cache.put(key, found)
        return found or None

    def numbers(self, full: str, nums) -> dict:
        """{n: {"type","state","merged_at","closed_at"} or None (missing)}."""
        out, todo = {}, []
        for n in sorted(set(nums)):
            hit = self.cache.get(f"mine:num:{full}#{n}")
            if hit is not None:
                out[n] = hit or None
            else:
                todo.append(n)
        owner, name = full.split("/", 1)
        for i in range(0, len(todo), 50):
            part = todo[i:i + 50]
            fields = " ".join(
                f"n{n}: issueOrPullRequest(number: {n}) {{ __typename"
                f" ... on Issue {{ state closedAt }} ... on PullRequest {{ state mergedAt closedAt }} }}"
                for n in part)
            q = f'query {{ repository(owner: "{owner}", name: "{name}") {{ {fields} }} }}'
            self._gate("graphql")
            self.calls += 1
            r = self.runner(["gh", "api", "graphql", "-f", f"query={q}"])
            if r.returncode != 0:
                continue
            try:
                data = json.loads(r.stdout or "{}").get("data") or {}
            except ValueError:
                data = {}
            repo = data.get("repository")
            if repo is None:
                continue  # transient failure: leave uncached, report as unchecked
            for n in part:
                v = repo.get(f"n{n}")
                val = {"type": v["__typename"], "state": v.get("state"), "merged_at": v.get("mergedAt"),
                       "closed_at": v.get("closedAt")} if v else {}
                self.cache.put(f"mine:num:{full}#{n}", val)
                out[n] = val or None
        return out


def tracked_files(repo_dir: Path) -> set | None:
    if not (repo_dir / ".git").exists():
        return None
    r = run(["git", "-C", str(repo_dir), "ls-files"])
    return set(r.stdout.splitlines()) if r.returncode == 0 else None


def commit_known(repo_dir: Path, sha: str) -> bool | None:
    r = run(["git", "-C", str(repo_dir), "cat-file", "-e", f"{sha}^{{commit}}"])
    return None if r.returncode == 127 else r.returncode == 0


def tracked_branches(repo_dir: Path) -> set | None:
    if not (repo_dir / ".git").exists():
        return None
    r = run(["git", "-C", str(repo_dir), "for-each-ref", "--format=%(refname)",
             "refs/heads/", "refs/remotes/"])
    if r.returncode != 0:
        return None
    branches = set()
    for ref in r.stdout.splitlines():
        if ref.startswith("refs/heads/"):
            branches.add(ref[len("refs/heads/"):])
        elif ref.startswith("refs/remotes/"):
            remote = ref[len("refs/remotes/"):]
            branches.add(remote)
            branches.add(remote.split("/", 1)[-1])
    return branches


# ----------------------------------------------------------------- the checks

def check_skill_bypass(segs, ctx, thr):
    skills = [s for s in ctx["skills"] if s["description"]]
    toks = [words(s["subject"] + " " + s["text"]) for s in segs]
    idf = Idf(toks)
    svecs = [(s, idf.vec(words(s["description"]))) for s in skills]
    flags = []
    for seg, tk in zip(segs, toks):
        if not tk:
            continue
        v = idf.vec(tk)
        names = {tool_name(t) for t in seg["tools"]}
        for sk, sv in svecs:
            sc = cosine(sv, v)
            if sc >= thr and "Skill" not in names and sk["name"] not in names:
                flags.append({"segment": seg["id"], "subject": seg["subject"], "object": f"skill {sk['name']}",
                              "score": round(sc, 3)})
    return flags, {"skills": len(skills), "segments": len(segs)}


def check_instructions(segs, ctx, thr):
    now = ctx["now"]
    recent = [s for s in segs if s["ts"] and s["ts"] >= now - dt.timedelta(days=90)]
    idf = Idf(words(s["subject"] + " " + s["text"]) for s in segs)
    lows = [(s["subject"] + " " + s["text"]).lower() for s in recent]
    flags, seen = [], {}
    bullets = ctx["bullets"]
    for b in bullets:
        kp = key_phrase(b["text"], idf)
        if not kp:
            continue
        sig = tuple(kp)
        if sig not in seen:
            seen[sig] = sum(1 for t in lows if all(k in t for k in kp))
        if seen[sig] == 0:
            flags.append({"segment": "-", "subject": "unused bullet", "object": f"{b['file']}: {b['text'][:100]}",
                          "key": " + ".join(kp)})
    bidf = Idf(words(b["text"]) for b in bullets)
    by_file = defaultdict(list)
    for b in bullets:
        by_file[b["file"]].append((b, bidf.vec(words(b["text"]))))
    for f, items in by_file.items():
        for i in range(len(items)):
            for j in range(i + 1, len(items)):
                sc = cosine(items[i][1], items[j][1])
                if sc >= thr:
                    flags.append({"segment": "-", "subject": "redundant pair",
                                  "object": f"{f}: {items[i][0]['text'][:60]} || {items[j][0]['text'][:60]}",
                                  "score": round(sc, 3)})
    return flags, {"bullets": len(bullets), "recent_segments": len(recent)}


def check_triggers(segs, ctx, thr):
    skills = [s for s in ctx["skills"] if s["description"]]
    idf = Idf(words(s["description"]) for s in skills)
    vecs = [idf.vec(words(s["description"])) for s in skills]
    flags = []
    for i in range(len(skills)):
        for j in range(i + 1, len(skills)):
            sc = cosine(vecs[i], vecs[j])
            if sc >= thr:
                flags.append({"segment": "-", "subject": "overlapping triggers",
                              "object": f"{skills[i]['name']} <> {skills[j]['name']}", "score": round(sc, 3)})
    return flags, {"skills": len(skills)}


def check_toolseq(segs, ctx, thr):
    conn = ctx["conn"]
    first_subject = dict(conn.execute(
        "SELECT chunk_id, subject FROM segments s WHERE section_no ="
        " (SELECT MIN(section_no) FROM segments t WHERE t.chunk_id = s.chunk_id)").fetchall())
    flags, stats = [], Counter()
    for cid, seq_json in conn.execute("SELECT chunk_id, tool_seq_json FROM chunks"):
        seq = _tools(seq_json)
        stats["chunks"] += 1
        names = [tool_name(t) for t in seq]
        detailed = any(isinstance(t, dict) for t in seq)
        i = 0
        while i < len(names):
            j = i
            while j < len(names) and names[j] == names[i]:
                j += 1
            if j - i >= 5 and names[i]:
                flags.append({"segment": cid, "subject": first_subject.get(cid, ""),
                              "object": f"{names[i]} x{j - i} in a row", "pattern": "repeat"})
            i = j
        for a, b in zip(seq, seq[1:]):
            if tool_name(a) in ("Edit", "Write") and tool_name(b) == "Read":
                if detailed and isinstance(a, dict) and isinstance(b, dict) and a.get("path") \
                        and a.get("path") == b.get("path"):
                    flags.append({"segment": cid, "subject": first_subject.get(cid, ""),
                                  "object": f"Read after {tool_name(a)} of same file", "pattern": "reread"})
                elif not detailed:
                    stats["edit_then_read_names_only"] += 1
        run_cmd, run_len = None, 0
        for t in seq:
            cmd = t.get("command") if isinstance(t, dict) and tool_name(t) == "Bash" else None
            run_len = run_len + 1 if cmd and cmd == run_cmd else (1 if cmd else 0)
            run_cmd = cmd
            if run_len == 3:
                flags.append({"segment": cid, "subject": first_subject.get(cid, ""),
                              "object": "3+ identical Bash calls", "pattern": "poll"})
    return flags, dict(stats)


PATH_RE = re.compile(r"(?<![\w./-])((?:bin|tools|skills|docs|tests|templates|config|scripts|HANDOFF\.d)"
                     r"/[A-Za-z0-9_./-]*[A-Za-z0-9_])")
NUM_RE = re.compile(r"(?<![\w/&])#(\d{2,6})\b")
SKILL_RE = re.compile(r"`([a-z0-9][a-z0-9-]{2,60})`\s+skill\b|\bskill\s+`([a-z0-9][a-z0-9-]{2,60})`")
BRANCH_RE = re.compile(r"\bbranch\s+`?([A-Za-z0-9_][A-Za-z0-9_./-]*)", re.I)


def repo_set(segs, gh, min_refs=20):
    counts = Counter(s["repo"] for s in segs if s["repo"] and s["repo"] != "unknown")
    resolved, unresolved = {}, []
    for name, c in counts.items():
        if c < min_refs:
            continue
        full = gh.repo(name)
        if full:
            resolved[name] = full
        else:
            unresolved.append(name)
    return resolved, sorted(unresolved)


def check_refs(segs, ctx, thr):
    gh, now = ctx["gh"], ctx["now"]
    recent = [s for s in segs if s["ts"] and s["ts"] >= now - dt.timedelta(days=30)]
    resolved, unresolved = repo_set(segs, gh)
    skill_names = {s["name"] for s in ctx["skills"]}
    files_cache: dict = {}
    branches_cache: dict = {}
    nums_wanted = defaultdict(set)
    flags, stats = [], Counter()
    for s in recent:
        if s["repo"] not in resolved:
            stats["segments_outside_repo_set"] += 1
            continue
        full = resolved[s["repo"]]
        if full not in files_cache:
            files_cache[full] = tracked_files(ctx["repos_home"] / s["repo"])
        files = files_cache[full]
        for branch in set(BRANCH_RE.findall(s["text"])):
            branch = branch.rstrip(".")
            if full not in branches_cache:
                branches_cache[full] = tracked_branches(ctx["repos_home"] / s["repo"])
            branches = branches_cache[full]
            if branches is None:
                stats["branches_unchecked"] += 1
            else:
                stats["branches"] += 1
                if branch not in branches:
                    flags.append({"segment": s["id"], "subject": s["subject"],
                                  "object": f"{full}:branch {branch}", "kind": "branch"})
        tops = {f.split("/", 1)[0] for f in files} if files else set()
        for p in set(PATH_RE.findall(s["text"])):
            p = p.rstrip(".")
            if files is None or p.split("/", 1)[0] not in tops or "*" in p or "<" in p:
                continue
            stats["paths"] += 1
            if p not in files and not any(f.startswith(p + "/") for f in files):
                flags.append({"segment": s["id"], "subject": s["subject"], "object": f"{full}:{p}",
                              "kind": "path"})
        for m in SKILL_RE.finditer(s["text"]):
            name = m.group(1) or m.group(2)
            stats["skills"] += 1
            if name not in skill_names and full == ctx["home_repo"]:
                flags.append({"segment": s["id"], "subject": s["subject"], "object": f"skill {name}",
                              "kind": "skill"})
        for n in set(NUM_RE.findall(s["text"])):
            nums_wanted[full].add(int(n))
            stats["numbers"] += 1
    for full, nums in nums_wanted.items():
        got = gh.numbers(full, nums)
        for s in recent:
            if resolved.get(s["repo"]) != full:
                continue
            for n in set(NUM_RE.findall(s["text"])):
                n = int(n)
                if n not in got:
                    stats["numbers_unchecked"] += 1
                elif got[n] is None:
                    flags.append({"segment": s["id"], "subject": s["subject"], "object": f"{full}#{n}",
                                  "kind": "number"})
    stats["unresolved_repos"] = len(unresolved)
    return flags, {**dict(stats), "repo_set": len(resolved), "unresolved": unresolved}


CLAIM_RE = re.compile(r"\b(merged|done|fixed|pushed)\b", re.I)
SHA_RE = re.compile(r"\bcommit\s+`?([0-9a-f]{7,40})\b", re.I)


def claim_refs(text: str, window: int = 30):
    """(word, kind, value) for refs within ``window`` chars of a claim word; one per ref."""
    best: dict = {}
    rank = {"merged": 0, "fixed": 1, "pushed": 2, "done": 3}
    for m in CLAIM_RE.finditer(text):
        lo, hi = max(0, m.start() - window), m.end() + window
        span = text[lo:hi]
        w = m.group(1).lower()
        refs = [("number", int(n)) for n in NUM_RE.findall(span)]
        refs += [("commit", sha.lower()) for sha in SHA_RE.findall(span)
                 if re.search(r"[a-f]", sha, re.I) and re.search(r"\d", sha)]
        for ref in refs:
            if ref not in best or rank[w] < rank[best[ref]]:
                best[ref] = w
    return {(w, kind, val) for (kind, val), w in best.items()}


def check_claims(segs, ctx, thr):
    gh = ctx["gh"]
    window = int(thr) if thr else 30
    resolved, unresolved = repo_set(segs, gh)
    found = []
    for s in segs:
        if s["repo"] in resolved and s["ts"]:
            for ref in claim_refs(s["text"], window):
                found.append((s, ref))
    by_repo = defaultdict(set)
    for s, (_, kind, val) in found:
        if kind == "number":
            by_repo[resolved[s["repo"]]].add(val)
    answers = {full: gh.numbers(full, nums) for full, nums in by_repo.items()}
    flags, stats = [], Counter(claims=len(found))
    for s, (word, kind, val) in found:
        full = resolved[s["repo"]]
        base = {"segment": s["id"], "subject": s["subject"], "claim": word}
        if kind == "commit":
            d = ctx["repos_home"] / s["repo"]
            if not (d / ".git").exists():
                stats["commits_unchecked"] += 1
            else:
                known = commit_known(d, val)
                if known is None:
                    stats["commits_unchecked"] += 1
                elif not known:
                    flags.append({**base, "object": f"{full}@{val}", "why": "commit not found"})
            continue
        got = answers.get(full, {})
        if val not in got:
            stats["numbers_unchecked"] += 1
            continue
        v = got[val]
        if v is None:
            flags.append({**base, "object": f"{full}#{val}", "why": "does not exist"})
            continue
        when = parse_ts(v["merged_at"] if v["type"] == "PullRequest" else v["closed_at"])
        if v["type"] == "PullRequest" and word == "merged" and not v["merged_at"]:
            flags.append({**base, "object": f"{full}#{val}", "why": f"PR not merged ({v['state']})"})
        elif when is None:
            if v["type"] == "PullRequest" or word in ("fixed", "merged"):
                flags.append({**base, "object": f"{full}#{val}", "why": f"{v['type']} still {v['state']}"})
            else:
                stats["open_issue_done_claims"] += 1  # "step done on #N" is not a closure claim
        elif when > s["ts"] + dt.timedelta(hours=1):
            flags.append({**base, "object": f"{full}#{val}", "why": "merged/closed after the segment"})
    return flags, {**dict(stats), "repo_set": len(resolved), "unresolved": unresolved}


RUNNERS = {"skill-bypass": check_skill_bypass, "instructions": check_instructions, "triggers": check_triggers,
           "toolseq": check_toolseq, "refs": check_refs, "claims": check_claims}


# ------------------------------------------------------------------- reports

def write_report(out_dir: Path, check: str, flags, stats, thr, date: str) -> Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    p = out_dir / f"{check}-{date}.md"
    lines = [f"# Mining check: {check} ({date})", "", "Private report. Subjects and referenced objects only.", "",
             f"- threshold: {thr}", f"- flags: {len(flags)}"]
    for k, v in sorted(stats.items()):
        lines.append(f"- {k}: {v}")
    lines += ["", "## Flags", ""]
    for i, f in enumerate(flags, 1):
        extra = ", ".join(f"{k}={v}" for k, v in f.items() if k not in ("segment", "subject", "object"))
        lines.append(f"{i}. `{f['segment']}` | {f['subject']} | {f['object']}" + (f" | {extra}" if extra else ""))
    p.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return p


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("check", choices=CHECKS + ("all",))
    ap.add_argument("--db", help="a local store file (tests); default: the published store via the reader")
    ap.add_argument("--store-root", help="Dropbox transcript-store folder")
    ap.add_argument("--reports", help="report folder (default <store-root>/reports)")
    ap.add_argument("--cache", help="gh answer cache (default ~/.local/share/ai-devops/transcript-store/mine-meta.db)")
    ap.add_argument("--repo-root", default=str(REPO_ROOT))
    ap.add_argument("--repos-home", default=str(REPOS_HOME))
    ap.add_argument("--threshold", type=float)
    ap.add_argument("--now", help="ISO time treated as now (tests)")
    ap.add_argument("--date", help="report date stamp (default today, America/New_York)")
    a = ap.parse_args(argv)

    store_root = Path(a.store_root) if a.store_root else reader.default_store_root()
    conn = sqlite3.connect(f"{Path(a.db).resolve().as_uri()}?mode=ro", uri=True) if a.db else reader.open_store(store_root)
    root = Path(a.repo_root)
    cache = Cache(Path(a.cache) if a.cache else
                  Path.home() / ".local/share/ai-devops/transcript-store/mine-meta.db")
    now = parse_ts(a.now) if a.now else dt.datetime.now(dt.timezone.utc)
    try:
        from zoneinfo import ZoneInfo
        today = dt.datetime.now(ZoneInfo("America/New_York")).strftime("%Y-%m-%d")
    except Exception:
        today = now.strftime("%Y-%m-%d")
    origin = run(["git", "-C", str(root), "remote", "get-url", "origin"]).stdout.strip()
    home = re.sub(r"\.git$", "", origin.rstrip("/")).split(":")[-1].split("github.com/")[-1]
    ctx = {"conn": conn, "skills": load_skills(root), "bullets": load_bullets(root), "now": now,
           "gh": GH(cache), "repos_home": Path(a.repos_home), "home_repo": home or "popcre/ai-devops"}
    segs = segments(conn)
    out_dir = Path(a.reports) if a.reports else store_root / "reports"
    for check in (CHECKS if a.check == "all" else (a.check,)):
        thr = a.threshold if a.threshold is not None else DEFAULTS.get(check, 30 if check == "claims" else 0)
        flags, stats = RUNNERS[check](segs, ctx, thr)
        p = write_report(out_dir, check, flags, stats, thr, a.date or today)
        print(f"{check}: {len(flags)} flags -> {p.name}")
    print(f"gh calls: {ctx['gh'].calls}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
