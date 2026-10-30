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
        "SELECT s.id, s.subject, s.text, s.repo, s.topic_slugs, c.tool_seq_json, se.last_ts, se.first_ts"
        " FROM segments s LEFT JOIN chunks c ON c.chunk_id = s.chunk_id"
        " LEFT JOIN sessions se ON se.path = s.path").fetchall()
    out = []
    for sid, subj, text, repo, slugs, seq, last, first in rows:
        out.append({"id": sid, "subject": subj or "", "text": text or "", "repo": repo or "unknown",
                    "slugs": slugs or "", "tools": _tools(seq), "ts": parse_ts(last),
                    "timed": bool(first and last and first != last)})
    return out


def _tools(seq_json) -> list:
    try:
        seq = json.loads(seq_json or "[]")
    except ValueError:
        return []
    if not isinstance(seq, list):
        return []
    # the writer stores one list of tool names per turn; flatten to call order
    out = []
    for t in seq:
        out.extend(t if isinstance(t, list) else [t])
    return out


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
    """The 3 rarest 4+-letter words of the bold lead-in, else of the bullet.

    Segments are ScaleDown summaries, not verbatim text, so a whole lead-in
    sentence never matches; its rarest words do (tuned 2026-10-30, #2063).
    """
    m = re.match(r"\*\*(.+?)\*\*", bullet)
    src = m.group(1) if m and words(m.group(1)) else bullet
    ws = sorted(set(words(src)), key=lambda w: (idf.df.get(w, 0), w))
    return ws[:3]


# ------------------------------------------------------------------ git and gh

def run(cmd, cwd=None) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=120)


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
        self.cache.put(key, found)
        return found or None

    def tree(self, full: str) -> set | None:
        """Paths on the default branch, cached for the day (trees change; answers about numbers do not)."""
        key = f"mine:tree:{dt.date.today().isoformat()}:{full}"
        hit = self.cache.get(key)
        if hit is not None:
            return set(hit)
        self._gate("core")
        self.calls += 1
        r = self.runner(["gh", "api", f"repos/{full}/git/trees/HEAD?recursive=1", "--jq", ".tree[].path"])
        if r.returncode != 0 or not r.stdout.strip():
            return None
        paths = r.stdout.splitlines()
        self.cache.put(key, paths)
        return set(paths)

    def all_repos(self) -> list:
        """Every repository of the owners (cached); a commit may live outside the repo set."""
        hit = self.cache.get("mine:all-repos")
        if hit is not None:
            return hit
        out = []
        for owner in OWNERS:
            self._gate("core")
            self.calls += 1
            r = self.runner(["gh", "repo", "list", owner, "--limit", "1000", "--json", "nameWithOwner"])
            try:
                out += [x["nameWithOwner"] for x in json.loads(r.stdout or "[]")]
            except (ValueError, KeyError, TypeError):
                return out  # transient: do not cache
        self.cache.put("mine:all-repos", out)
        return out

    def commit(self, full: str, sha: str) -> bool:
        """True when GitHub still serves ``sha`` in ``full`` (squash-merged branch commits included)."""
        key = f"mine:commit:{full}@{sha}"
        hit = self.cache.get(key)
        if hit is not None:
            return bool(hit)
        self._gate("core")
        self.calls += 1
        r = self.runner(["gh", "api", f"repos/{full}/commits/{sha}", "--jq", ".sha"])
        if r.returncode != 0 and "No commit found" not in (getattr(r, "stderr", "") or "") \
                and "422" not in (getattr(r, "stderr", "") or ""):
            return True  # transient or auth failure: do not flag, do not cache
        ok = r.returncode == 0
        self.cache.put(key, ok)
        return ok

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


def commit_known(repo_dir: Path, sha: str) -> bool:
    return run(["git", "-C", str(repo_dir), "cat-file", "-e", f"{sha}^{{commit}}"]).returncode == 0


# ----------------------------------------------------------------- the checks

ON_REQUEST = re.compile(r'"(?:ask|run this by|use|have|debate|review with|delegate)\b', re.I)
DELEGATION = re.compile(r"^FROZEN\b|\bdelegat|\bsecond[- ]opinion\b", re.I)
CLAUDE_TOOLS = {"Bash", "Read", "Edit", "Write", "Grep", "Glob", "Agent", "Task"}
CODEX_TOOLS = {"exec", "exec_command", "shell_command", "apply_patch", "shell"}


def skill_applies(sk: dict, names: set) -> bool:
    """False for a skill that runs only when asked by name, or belongs to another client."""
    if ON_REQUEST.search(sk["description"]) or DELEGATION.search(sk["description"]):
        return False  # "ask X", "use X", "run this by X": not using it is not a bypass
    client = sk["file"].split("/")[1] if sk["file"].count("/") > 2 else "shared"
    if client == "codex" and names & CLAUDE_TOOLS and not names & CODEX_TOOLS:
        return False
    if client == "claude" and names & CODEX_TOOLS and not names & CLAUDE_TOOLS:
        return False
    return client in ("shared", "claude", "codex")


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
        if seg["slugs"].split(",")[0] == "database":
            continue  # schema and migration work around a skill's data is not the skill's task
        low = (seg["subject"] + " " + seg["text"]).lower()
        for sk, sv in svecs:
            sc = cosine(sv, v)
            # A named skill was used (Codex reads SKILL.md by path) or is being worked on.
            if sc >= thr and "Skill" not in names and sk["name"] not in names and skill_applies(sk, names) \
                    and sk["name"] not in low and "skill" not in seg["subject"].lower():
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
            need = min(len(kp), 2)  # tuned 2026-10-30 (#2063): all 3 missed paraphrases
            seen[sig] = sum(1 for t in lows if sum(k in t for k in kp) >= need)
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


GENERIC_TOOLS = {"Bash", "exec", "exec_command", "shell_command", "shell", "PowerShell", "js", "Edit",
                 "MultiEdit", "Write", "apply_patch", "write_stdin", "mcp__ccd_turn__update_plan"}


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
            if j - i >= 5 and names[i] and names[i] not in GENERIC_TOOLS:
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


def attributed(text: str, pos: int, default: str, resolved: dict) -> str:
    """The repo named just before ``pos`` (e.g. "shared-db PR #12"), else ``default``."""
    before = text[max(0, pos - 40):pos].lower()
    best, at = default, -1
    for name in resolved:
        i = before.rfind(name.lower())
        if i > at:
            best, at = name, i
    return best


def lookup_all(gh, resolved: dict, wanted: dict) -> dict:
    """{(repo, n): answer} for every wanted number in its repo and every other repo-set repo."""
    allnums = set().union(*wanted.values()) if wanted else set()
    out = {}
    for name, full in resolved.items():
        got = gh.numbers(full, allnums)
        for n, v in got.items():
            out[(name, n)] = v
    return out


def exists_elsewhere(answers: dict, resolved: dict, n: int) -> bool:
    return any(answers.get((name, n)) for name in resolved)


def check_refs(segs, ctx, thr):
    gh, now = ctx["gh"], ctx["now"]
    recent = [s for s in segs if s["ts"] and s["ts"] >= now - dt.timedelta(days=30)]
    resolved, unresolved = repo_set(segs, gh)
    skill_names = {s["name"] for s in ctx["skills"]}
    # GitHub's default branch is the source of truth; a local checkout may sit on any branch.
    files_cache = {full: gh.tree(full) or tracked_files(ctx["repos_home"] / name) for name, full in resolved.items()}
    nums_wanted = defaultdict(set)
    flags, stats = [], Counter()
    for s in recent:
        if s["repo"] not in resolved:
            stats["segments_outside_repo_set"] += 1
            continue
        full = resolved[s["repo"]]
        files = files_cache[full]
        tops = {f.split("/", 1)[0] for f in files} if files else set()
        for p in set(PATH_RE.findall(s["text"])):
            p = p.rstrip(".")
            if files is None or p.split("/", 1)[0] not in tops or "*" in p or "<" in p or "..." in p \
                    or not re.search(r"\.[A-Za-z0-9]{1,6}$", p.rsplit("/", 1)[-1]):
                continue  # extensionless tails are usually truncated summary text
            stats["paths"] += 1
            if p not in files and not any(p in (f or ()) for f in files_cache.values()):
                flags.append({"segment": s["id"], "subject": s["subject"], "object": f"{full}:{p}",
                              "kind": "path"})
        for m in SKILL_RE.finditer(s["text"]):
            name = m.group(1) or m.group(2)
            stats["skills"] += 1
            if name not in skill_names and full == ctx["home_repo"]:
                flags.append({"segment": s["id"], "subject": s["subject"], "object": f"skill {name}",
                              "kind": "skill"})
        for m in NUM_RE.finditer(s["text"]):
            nums_wanted[attributed(s["text"], m.start(), s["repo"], resolved)].add(int(m.group(1)))
            stats["numbers"] += 1
    answers = lookup_all(gh, resolved, nums_wanted)
    done = set()
    for s in recent:
        if s["repo"] not in resolved:
            continue
        for m in NUM_RE.finditer(s["text"]):
            n, name = int(m.group(1)), attributed(s["text"], m.start(), s["repo"], resolved)
            if (s["id"], name, n) in done:
                continue
            done.add((s["id"], name, n))
            if (name, n) not in answers:
                stats["numbers_unchecked"] += 1
            elif answers[(name, n)] is None and not exists_elsewhere(answers, resolved, n):
                flags.append({"segment": s["id"], "subject": s["subject"], "object": f"{resolved[name]}#{n}",
                              "kind": "number"})
    stats["unresolved_repos"] = len(unresolved)
    return flags, {**dict(stats), "repo_set": len(resolved), "unresolved": unresolved}


CLAIM_RE = re.compile(r"\b(merged|done|fixed|pushed)\b", re.I)
SHA_RE = re.compile(r"\bcommit\s+`?([0-9a-f]{7,40})\b", re.I)


NEG = re.compile(r"\b(?:not|never|un|blocked|before|after|once|until|when|if|be|will|to|awaiting|ready)\W*$",
                 re.I)
MERGED_NUM = re.compile(r"\b(?:PR|pull request)\s*#(\d{1,6})\s+(?:was\s+|is\s+|has been\s+|got\s+|now\s+)?merged\b"
                        r"|\bmerged\s+(?:PR\s*|pull request\s*)?#(\d{1,6})\b", re.I)
OTHER_NUM = re.compile(r"\b(fixed|pushed|done)\s+(?:in|to|via|on|by)\s+(?:PR\s*|issue\s*)?#(\d{1,6})\b"
                       r"|#(\d{1,6})\s+(?:is\s+|was\s+)?(fixed|done)\b", re.I)
COMMIT = re.compile(r"\b(merged|fixed|pushed)\b[^.\n]{0,20}?\bcommit\s+`?([0-9a-f]{7,40})\b", re.I)


def claim_refs(text: str, window: int = 0):
    """(word, kind, value, pos): refs stated directly as merged/fixed/pushed/done.

    Tuned 2026-10-30 (#2063): a loose window caught neighbouring numbers and
    "merge blocked"/"will be merged" phrasing, so only adjacent forms count.
    """
    out = set()
    for m in MERGED_NUM.finditer(text):
        if NEG.search(text[max(0, m.start() - 15):m.start()]):
            continue
        if re.match(r"\s+(?:origin/)?main\s+into\b", text[m.start() + 6:m.start() + 26], re.I):
            continue
        n = m.group(1) or m.group(2)
        out.add(("merged", "number", int(n), m.start(m.lastindex)))
    for m in OTHER_NUM.finditer(text):
        w, n = (m.group(1), m.group(2)) if m.group(1) else (m.group(4), m.group(3))
        out.add((w.lower(), "number", int(n), m.start()))
    for m in COMMIT.finditer(text):
        sha = m.group(2).lower()
        if re.search(r"[a-f]", sha) and re.search(r"\d", sha):
            out.add((m.group(1).lower(), "commit", sha, m.start()))
    return out


def check_claims(segs, ctx, thr):
    gh = ctx["gh"]
    grace = dt.timedelta(hours=thr if thr else 6)
    resolved, unresolved = repo_set(segs, gh)
    found, stats0 = [], Counter()
    for s in segs:
        if s["repo"] in resolved and s["ts"]:
            for w, kind, val, pos in claim_refs(s["text"]):
                # attribute to the nearest repo named before the ref, unresolved ones included
                name = attributed(s["text"], pos, s["repo"], {**resolved, **{u: None for u in unresolved}})
                if name not in resolved:
                    stats0["other_repo_unchecked"] += 1
                    continue
                if kind == "commit" and not (7 <= len(val) <= 12 or len(val) == 40):
                    stats0["truncated_sha"] += 1
                    continue
                found.append((s, (w, kind, val, name)))
    by_repo = defaultdict(set)
    for s, (_, kind, val, name) in found:
        if kind == "number":
            by_repo[name].add(val)
    answers = lookup_all(gh, resolved, by_repo)
    flags, stats = [], Counter(claims=len(found), **stats0)
    for s, (word, kind, val, name) in found:
        full = resolved[name]
        base = {"segment": s["id"], "subject": s["subject"], "claim": word}
        if kind == "commit":
            dirs = [ctx["repos_home"] / n2 for n2 in resolved if (ctx["repos_home"] / n2 / ".git").exists()]
            if not dirs:
                stats["commits_unchecked"] += 1
            elif not any(commit_known(d, val) for d in dirs) \
                    and not any(gh.commit(f2, val) for f2 in resolved.values()) \
                    and not any(gh.commit(f2, val) for f2 in gh.all_repos() if f2 not in resolved.values()):
                flags.append({**base, "object": f"{full}@{val}", "why": "commit not found"})
            continue
        if (name, val) not in answers:
            stats["numbers_unchecked"] += 1
            continue
        v = answers[(name, val)]
        if v is None:
            if exists_elsewhere(answers, resolved, val):
                stats["ambiguous_repo"] += 1
            else:
                flags.append({**base, "object": f"{full}#{val}", "why": "does not exist"})
            continue
        # Only "merged" about a PR is a closure claim; "fixed in #N", "pushed to #N" and
        # "done on #N" legitimately precede an issue's closing (tuned 2026-10-30, #2063).
        if word != "merged" or v["type"] != "PullRequest":
            stats["existence_only"] += 1
        elif not v["merged_at"]:
            flags.append({**base, "object": f"{full}#{val}", "why": f"PR not merged ({v['state']})"})
        elif not s.get("timed"):
            stats["untimed_session"] += 1  # one timestamp only: the session end is unknown
        elif parse_ts(v["merged_at"]) > s["ts"] + grace:
            flags.append({**base, "object": f"{full}#{val}", "why": "merged after the segment"})
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
    conn = sqlite3.connect(f"file:{a.db}?mode=ro", uri=True) if a.db else reader.open_store(store_root)
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
        thr = a.threshold if a.threshold is not None else DEFAULTS.get(check, 6 if check == "claims" else 0)
        flags, stats = RUNNERS[check](segs, ctx, thr)
        p = write_report(out_dir, check, flags, stats, thr, a.date or today)
        print(f"{check}: {len(flags)} flags -> {p.name}")
    print(f"gh calls: {ctx['gh'].calls}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
