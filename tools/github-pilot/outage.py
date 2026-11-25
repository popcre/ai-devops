#!/usr/bin/env python3
"""Outage continuity drill for the GitHub continuity pilot (plan step 2).

Subcommands
  server  ROOT PORT        loopback Git (smart HTTP) + test API; mode from ROOT/mode
  worker  JOURNAL WS ...   journalled, serialized, idempotent submission of one branch
  drill   SCRATCH TOOLKIT  the whole scenario; prints one JSON result line
  audit   TRACE ALLOWED... strace audit: every destination local, every write allowed

Run `drill` only inside a process with no outbound network and tmpfs over HOME
and /tmp (see run_drill.sh). Nothing here contacts GitHub or reads host state.
Standard library only.
"""

import fcntl
import http.client
import http.server
import json
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request

OWNER = "pilot-owner"
REPO_NAME = "pilot-repo"
REPO = OWNER + "/" + REPO_NAME
WATCHDOG = 120
TARGET = 5.0


# --------------------------------------------------------------------------
# Loopback server
# --------------------------------------------------------------------------

def _load(root):
    path = os.path.join(root, "state.json")
    if os.path.exists(path):
        with open(path) as handle:
            return json.load(handle)
    return {"pulls": [], "next": 1, "requests": {}}


def _save(root, state):
    tmp = os.path.join(root, "state.json.tmp")
    with open(tmp, "w") as handle:
        json.dump(state, handle)
    os.replace(tmp, os.path.join(root, "state.json"))


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"
    root = None
    lock = threading.Lock()

    def log_message(self, *args):
        return

    def _mode(self):
        try:
            with open(os.path.join(self.root, "mode")) as handle:
                return handle.read().strip()
        except OSError:
            return "healthy"

    def _count(self, kind):
        with self.lock:
            state = _load(self.root)
            mode = self._mode()
            key = "%s:%s" % (mode, kind)
            state["requests"][key] = state["requests"].get(key, 0) + 1
            _save(self.root, state)

    def _gate(self, kind):
        mode = self._mode()
        self._count(kind)
        if mode == "503":
            self.send_response(503)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            self.wfile.write(b"service unavailable\n")
            return False
        if mode.startswith("delay"):
            time.sleep(float(mode.split(":")[1]) if ":" in mode else 60)
        return True

    def _json(self, code, body, headers=None):
        raw = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        for key, value in (headers or {}).items():
            self.send_header(key, value)
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        self._dispatch("GET")

    def do_POST(self):
        self._dispatch("POST")

    def do_PATCH(self):
        self._dispatch("PATCH")

    def _dispatch(self, method):
        if self.path.startswith("/git/"):
            if self._gate("git"):
                self._git(method)
            return
        if not self.path.startswith("/api/"):
            self._json(404, {"message": "not found"})
            return
        path, _, query = self.path[5:].partition("?")
        kind = "api:" + _classify(path)
        if not self._gate(kind):
            return
        params = dict(p.split("=", 1) for p in query.split("&") if "=" in p)
        now = int(time.time())
        if path == "user":
            self._json(200, {"id": 424242, "login": "pilot-fixture"})
        elif path == "rate_limit":
            res = {b: {"limit": 5000, "remaining": 4990, "reset": now + 3600, "used": 10}
                   for b in ("core", "graphql", "search")}
            self._json(200, {"resources": res, "rate": res["core"]},
                       {"x-ratelimit-limit": "5000", "x-ratelimit-remaining": "4990",
                        "x-ratelimit-reset": str(now + 3600), "x-ratelimit-resource": "core"})
        elif path.endswith("/actions/runners"):
            self._json(200, {"total_count": 1, "runners": [{"name": "pilot-runner", "busy": False}]})
        elif re.fullmatch(r"repos/[^/]+/[^/]+/pulls", path):
            self._pulls(method, params)
        elif re.fullmatch(r"repos/[^/]+/[^/]+", path):
            self._json(200, {"private": True, "visibility": "private"})
        elif re.fullmatch(r"repos/[^/]+/[^/]+/issues/\d+", path):
            self._json(200, {"url": "fixture", "author": {"login": "pilot-fixture"},
                             "body": "", "comments": []})
        else:
            self._json(404, {"message": "not found"})

    def _pulls(self, method, params):
        with self.lock:
            state = _load(self.root)
            if method == "GET":
                head = params.get("head", "").split(":")[-1]
                want = params.get("state", "open")
                found = [p for p in state["pulls"]
                         if (not head or p["head"] == head)
                         and (want == "all" or p["state"] == want)]
                self._json(200, found)
                return
            length = int(self.headers.get("Content-Length") or 0)
            body = json.loads(self.rfile.read(length) or b"{}")
            pull = {"number": state["next"], "head": body["head"], "base": body["base"],
                    "head_sha": body.get("head_sha"), "draft": True, "state": "open",
                    "merged": False, "url": "fixture://pull/%d" % state["next"]}
            state["next"] += 1
            state["pulls"].append(pull)
            state.setdefault("creates", []).append(body["head"])
            _save(self.root, state)
            lose = os.path.join(self.root, "lose_next_create")
            if os.path.exists(lose):
                os.unlink(lose)
                self.close_connection = True
                self.connection.shutdown(socket.SHUT_RDWR)
                return
        self._json(201, pull)

    def _git(self, method):
        rel = self.path[len("/git"):]
        path_info, _, query = rel.partition("?")
        env = {
            "PATH": os.environ.get("PATH", "/usr/bin:/bin"),
            "GIT_PROJECT_ROOT": os.path.join(self.root, "git"),
            "GIT_HTTP_EXPORT_ALL": "1",
            "REMOTE_USER": "pilot",
            "REQUEST_METHOD": method,
            "PATH_INFO": path_info,
            "QUERY_STRING": query,
            "CONTENT_TYPE": self.headers.get("Content-Type", ""),
            "CONTENT_LENGTH": self.headers.get("Content-Length", "0"),
            "HOME": os.environ.get("HOME", "/tmp"),
        }
        if self.headers.get("Content-Encoding"):
            env["HTTP_CONTENT_ENCODING"] = self.headers["Content-Encoding"]
        length = int(self.headers.get("Content-Length") or 0)
        data = self.rfile.read(length) if length else b""
        out = subprocess.run(["git", "http-backend"], input=data, env=env,
                             capture_output=True).stdout
        head, _, body = out.partition(b"\r\n\r\n")
        status = 200
        headers = []
        for line in head.split(b"\r\n"):
            key, _, value = line.decode().partition(":")
            if key.lower() == "status":
                status = int(value.strip().split()[0])
            elif key:
                headers.append((key, value.strip()))
        self.send_response(status)
        for key, value in headers:
            self.send_header(key, value)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def _classify(path):
    if path in ("user", "rate_limit"):
        return path
    if path.endswith("/pulls"):
        return "pulls"
    if path.endswith("/actions/runners"):
        return "runners"
    if "/issues/" in path:
        return "issue"
    return "repo"


def serve(root, port):
    Handler.root = root
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.daemon_threads = True
    server.serve_forever()


# --------------------------------------------------------------------------
# Journal (atomic, crash hooks)
# --------------------------------------------------------------------------

def _crash(point):
    if os.environ.get("PILOT_CRASH") == point:
        os._exit(137)


def journal_read(path):
    try:
        with open(path) as handle:
            return json.load(handle)
    except FileNotFoundError:
        return {"seq": 0, "items": {}}


def journal_write(path, data):
    data = dict(data, seq=data.get("seq", 0) + 1)
    tmp = path + ".tmp"
    with open(tmp, "w") as handle:
        json.dump(data, handle, sort_keys=True)
        _crash("mid_write")
        handle.flush()
        os.fsync(handle.fileno())
    _crash("before_replace")
    os.replace(tmp, path)
    dirfd = os.open(os.path.dirname(path), os.O_RDONLY)
    try:
        os.fsync(dirfd)
    finally:
        os.close(dirfd)
    _crash("after_replace")
    return data


# --------------------------------------------------------------------------
# Worker: serialized, idempotent submission
# --------------------------------------------------------------------------

def _git(ws, *args, timeout=None):
    return subprocess.run(["git", "-C", ws] + list(args), capture_output=True,
                          text=True, timeout=timeout)


def _api(api, method, path, body=None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(api + "/api/" + path, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=TARGET) as resp:
        return json.loads(resp.read() or b"null")


def submit(journal, ws, branch, api, locks):
    """One submission attempt. Returns the item's new state."""
    os.makedirs(locks, exist_ok=True)
    lock_path = os.path.join(locks, "%s__%s.lock" % (REPO.replace("/", "_"), branch.replace("/", "_")))
    with open(lock_path, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        data = journal_read(journal)
        item = data["items"][branch]
        if item["state"] in ("delivered", "pending_conflict"):
            return item["state"]
        if _git(ws, "cat-file", "-e", item["commit"] + "^{commit}").returncode:
            item["state"] = "blocked_missing_commit"
            journal_write(journal, data)
            return item["state"]
        dep = item.get("depends_on")
        if dep:
            try:
                remote = _git(ws, "ls-remote", "origin", "refs/heads/" + dep["branch"], timeout=TARGET)
            except subprocess.TimeoutExpired:
                return "deferred"
            if remote.returncode or dep["commit"] not in remote.stdout:
                return "waiting_dependency" if remote.returncode == 0 else "deferred"
        try:
            existing = _api(api, "GET", "repos/%s/pulls?state=all&head=%s:%s" % (REPO, OWNER, branch))
        except (urllib.error.URLError, OSError, ValueError):
            return "deferred"
        if existing:
            pull = existing[0]
            item.update(state="delivered", pr=pull["number"],
                        outcome="already_merged" if pull.get("merged") else "adopted_existing")
            _crash("before_delivered")
            journal_write(journal, data)
            return "delivered"
        try:
            push = _git(ws, "push", "origin", "%s:refs/heads/%s" % (item["commit"], branch),
                        timeout=TARGET * 4)
        except subprocess.TimeoutExpired:
            return "deferred"
        if push.returncode:
            return "deferred"
        item["state"] = "create_uncertain"
        journal_write(journal, data)
        try:
            pull = _api(api, "POST", "repos/%s/pulls" % REPO,
                        {"head": branch, "base": item["base"], "head_sha": item["commit"],
                         "draft": True, "title": item["title"]})
        except (urllib.error.URLError, OSError, ValueError, http.client.HTTPException):
            return "create_uncertain"
        item.update(state="delivered", pr=pull["number"], outcome="created")
        _crash("before_delivered")
        journal_write(journal, data)
        return "delivered"


# --------------------------------------------------------------------------
# Drill
# --------------------------------------------------------------------------

class Drill:
    def __init__(self, scratch, toolkit, fake_gh, port):
        self.s = scratch
        self.toolkit = toolkit
        self.fake_gh = fake_gh
        self.port = port
        self.api = "http://127.0.0.1:%d" % port
        self.srv_root = os.path.join(scratch, "server")
        self.server = None
        self.result = {"entry_points": [], "worker": [], "journal": [], "checks": {}}

    def sh(self, *cmd, cwd=None, env=None, timeout=60, check=True):
        out = subprocess.run(list(cmd), cwd=cwd, env=env or self.env(), capture_output=True,
                             text=True, timeout=timeout)
        if check and out.returncode:
            raise RuntimeError("%s failed: %s" % (cmd[:3], out.stderr[-400:]))
        return out

    def env(self, extra=None):
        env = {
            "PATH": os.environ["PATH"], "HOME": os.environ["HOME"], "LANG": "C.UTF-8",
            "TMPDIR": os.path.join(self.s, "tmp"), "PYTHONDONTWRITEBYTECODE": "1",
            "GIT_TERMINAL_PROMPT": "0", "GIT_CONFIG_NOSYSTEM": "1",
            "GIT_AUTHOR_NAME": "Pilot", "GIT_AUTHOR_EMAIL": "pilot@fixture.invalid",
            "GIT_COMMITTER_NAME": "Pilot", "GIT_COMMITTER_EMAIL": "pilot@fixture.invalid",
            "PILOT_API": self.api, "PILOT_REPO": REPO,
        }
        env.update(extra or {})
        return env

    # -- server control
    def mode(self, mode):
        with open(os.path.join(self.srv_root, "mode"), "w") as handle:
            handle.write(mode)
        if mode == "refused":
            self.stop()
        elif self.server is None:
            self.server = subprocess.Popen([sys.executable, "-B", __file__, "server", self.srv_root,
                                            str(self.port)], env=self.env())
            for _ in range(100):
                try:
                    socket.create_connection(("127.0.0.1", self.port), 0.1).close()
                    break
                except OSError:
                    time.sleep(0.05)

    def stop(self):
        if self.server is not None:
            self.server.terminate()
            self.server.wait()
            self.server = None

    # -- fixture repositories
    def setup(self):
        for d in ("server/git", "tmp", "locks", "state"):
            os.makedirs(os.path.join(self.s, d), exist_ok=True)
        bare = os.path.join(self.srv_root, "git", "pilot.git")
        mem = os.path.join(self.srv_root, "git", "memory.git")
        self.sh("git", "init", "-q", "--bare", "-b", "main", bare)
        self.sh("git", "init", "-q", "--bare", "-b", "main", mem)
        for repo in (bare, mem):
            self.sh("git", "-C", repo, "config", "http.receivepack", "true")
            self.sh("git", "-C", repo, "config", "receive.denyNonFastForwards", "true")
            hook = os.path.join(repo, "hooks", "pre-receive")
            with open(hook, "w") as handle:
                handle.write("#!/bin/sh\nwhile read old new ref; do\n"
                             "  forced=no\n"
                             "  if [ \"$old\" != 0000000000000000000000000000000000000000 ] && "
                             "! git merge-base --is-ancestor \"$old\" \"$new\"; then forced=yes; fi\n"
                             "  echo \"$(date +%%s.%%N) $ref $old $new $forced\" >> %s\n"
                             "done\n" % os.path.join(self.srv_root, "pushes.log"))
            os.chmod(hook, 0o755)
        seed = os.path.join(self.s, "seed")
        self.sh("git", "init", "-q", "-b", "main", seed)
        files = {
            "a.txt": "alpha base\n",
            "shared.txt": "line one\nline two\nline three\n",
            "test_fixture.py": ("import unittest\n"
                                "class T(unittest.TestCase):\n"
                                "    def test_files(self):\n"
                                "        for name in ('a.txt', 'shared.txt'):\n"
                                "            with open(name) as h:\n"
                                "                self.assertNotIn('<<<<<<<', h.read())\n"),
        }
        for name, text in files.items():
            with open(os.path.join(seed, name), "w") as handle:
                handle.write(text)
        self.sh("git", "-C", seed, "add", ".")
        self.sh("git", "-C", seed, "commit", "-qm", "seed")
        self.mode("healthy")
        self.sh("git", "-C", seed, "push", "-q", self.api + "/git/pilot.git", "main")
        self.sh("git", "-C", seed, "push", "-q", self.api + "/git/memory.git", "main")
        self.clone = os.path.join(self.s, "clone")
        self.sh("git", "clone", "-q", self.api + "/git/pilot.git", self.clone)
        self.base = self.sh("git", "-C", self.clone, "rev-parse", "origin/main").stdout.strip()
        self.ws = {}
        for name in ("a", "b"):
            path = os.path.join(self.s, "ws-" + name)
            self.sh("git", "-C", self.clone, "worktree", "add", "-q", "-b", "pilot/" + name,
                    path, self.base)
            self.ws[name] = path
        runner = os.path.join(self.s, "runner")
        os.makedirs(runner)
        with open(os.path.join(runner, ".runner"), "w") as handle:
            json.dump({"agentName": "pilot-runner",
                       "gitHubUrl": "https://github.com/" + REPO}, handle)
        self.runner_dir = runner

    # -- entry points
    def entry_env(self, ws, label):
        state = os.path.join(self.s, "state", "%s-%s" % (ws, label))
        os.makedirs(state, exist_ok=True)
        return self.env({
            "AI_GH_STATE_DIR": state, "AI_GH_REAL_GH": self.fake_gh,
            "AI_MEMORY_TEST_MODE": "1", "AI_MEMORY_REMOTE": self.api + "/git/memory.git",
            "AI_MEMORY_HUB": os.path.join(state, "hub"),
            "AI_MEMORY_LOG": os.path.join(state, "memory.log"),
            "AI_MEMORY_CLAUDE_PROJECTS": os.path.join(state, "projects"),
            "AI_TEST_RUNNER_DIRS": self.runner_dir, "AI_TEST_RUNNER_REPO": REPO,
        })

    def entry_points(self, label):
        bin_ = os.path.join(self.toolkit, "bin")
        cases = [
            ("task_gates", [bin_ + "/ai-task-gates", "start", "--class", "code",
                            "--reason", "pilot outage drill"]),
            ("workspace_status", [bin_ + "/ai-workspace-status"]),
            ("memory_sync", [bin_ + "/ai-memory-sync"]),
            ("collision_check", [bin_ + "/ai-test-local", "--check-collision"]),
        ]
        rows = []
        lock = threading.Lock()

        def run_ws(ws_name):
            for case, cmd in cases:
                started = time.monotonic()
                try:
                    out = subprocess.run(cmd, cwd=self.ws[ws_name], env=self.entry_env(ws_name, label),
                                         capture_output=True, text=True, timeout=WATCHDOG)
                    code, text = out.returncode, (out.stdout + out.stderr)
                    killed = False
                except subprocess.TimeoutExpired as exc:
                    code, killed = None, True
                    text = (exc.stdout or b"").decode(errors="replace") if isinstance(exc.stdout, bytes) else (exc.stdout or "")
                elapsed = round(time.monotonic() - started, 2)
                row = {"mode": label, "workspace": ws_name, "entry": case, "exit": code,
                       "seconds": elapsed, "watchdog_killed": killed,
                       "within_target": (not killed) and elapsed <= TARGET,
                       "says_unknown": bool(re.search(r"unknown|unavailable|could not verify|defer", text, re.I)),
                       "pushed": bool(re.search(r"pushed|-> main", text))}
                with open(os.path.join(self.s, "state", "out-%s-%s-%s.txt" % (label, ws_name, case)), "w") as h:
                    h.write(text[-4000:])
                with lock:
                    rows.append(row)

        threads = [threading.Thread(target=run_ws, args=(w,)) for w in ("a", "b")]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        self.result["entry_points"].extend(sorted(rows, key=lambda r: (r["workspace"], r["entry"])))

    # -- local work
    def local_work(self, ws_name, filename, text, message):
        ws = self.ws[ws_name]
        started = time.monotonic()
        with open(os.path.join(ws, filename), "a") as handle:
            handle.write(text)
        test = self.sh(sys.executable, "-B", "-m", "unittest", "-q", cwd=ws, check=False)
        self.sh("git", "-C", ws, "add", filename)
        self.sh("git", "-C", ws, "commit", "-qm", message)
        commit = self.sh("git", "-C", ws, "rev-parse", "HEAD").stdout.strip()
        self.result["checks"]["offline_work_%s" % ws_name] = {
            "test_exit": test.returncode, "seconds": round(time.monotonic() - started, 2)}
        return commit

    def journal_path(self, ws_name):
        d = os.path.join(self.s, "journal-" + ws_name)
        os.makedirs(d, mode=0o700, exist_ok=True)
        return os.path.join(d, "journal.json")

    def record(self, ws_name, commit, base, depends=None, crash=None):
        path = self.journal_path(ws_name)
        data = journal_read(path)
        data["items"]["pilot/" + ws_name] = {
            "repo": REPO, "base": base, "branch": "pilot/" + ws_name, "commit": commit,
            "depends_on": depends, "title": "pilot " + ws_name, "state": "pending",
            "identity": "%s#pilot/%s" % (REPO, ws_name)}
        self.sh("git", "-C", self.ws[ws_name], "update-ref",
                "refs/pilot/journal/%s/%d" % (ws_name, data["seq"] + 1), commit)
        payload = json.dumps(data)
        code = subprocess.run([sys.executable, "-B", __file__, "journal-write", path],
                              input=payload, text=True, env=self.env({"PILOT_CRASH": crash or ""})).returncode
        return code

    def worker(self, ws_name, label, crash=None, wait=True):
        cmd = [sys.executable, "-B", __file__, "worker", self.journal_path(ws_name), self.ws[ws_name],
               "pilot/" + ws_name, self.api, os.path.join(self.s, "locks")]
        proc = subprocess.Popen(cmd, env=self.env({"PILOT_CRASH": crash or ""}),
                                stdout=subprocess.PIPE, text=True)
        if not wait:
            return proc
        return self.finish(proc, ws_name, label)

    def finish(self, proc, ws_name, label, started=None):
        started = started or time.monotonic()
        try:
            out, _ = proc.communicate(timeout=WATCHDOG)
            state = out.strip() or ("crashed" if proc.returncode == 137 else "error")
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.communicate()
            state = "watchdog_timeout"
        row = {"step": label, "workspace": ws_name, "state": state, "exit": proc.returncode,
               "seconds": round(time.monotonic() - started, 2)}
        self.result["worker"].append(row)
        return state

    def journal_kill_tests(self):
        path = os.path.join(self.s, "journal-killtest", "journal.json")
        os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
        first = {"seq": 0, "items": {"x": {"commit": self.base, "state": "pending"}}}
        subprocess.run([sys.executable, "-B", __file__, "journal-write", path],
                       input=json.dumps(first), text=True, env=self.env(), check=True)
        for point in ("mid_write", "before_replace", "after_replace"):
            before = journal_read(path)
            new = dict(before, items={"x": {"commit": self.base, "state": "updated-" + point}})
            code = subprocess.run([sys.executable, "-B", __file__, "journal-write", path],
                                  input=json.dumps(new), text=True,
                                  env=self.env({"PILOT_CRASH": point})).returncode
            after = journal_read(path)
            complete = after.get("seq") in (before["seq"], before["seq"] + 1)
            resolves = self.sh("git", "-C", self.clone, "cat-file", "-e",
                               after["items"]["x"]["commit"] + "^{commit}", check=False).returncode == 0
            self.result["journal"].append({"crash": point, "exit": code,
                                           "record": "new" if after["seq"] == before["seq"] + 1 else "previous",
                                           "complete": complete, "commit_resolves": resolves})

    def run(self):
        self.setup()
        # 1. online control, then the three outage modes before any work starts
        self.entry_points("healthy")
        for mode in ("refused", "503", "delay:30"):
            self.mode(mode)
            self.entry_points(mode.split(":")[0])
        # 2. offline work in both workspaces (GitHub refused)
        self.mode("refused")
        a1 = self.local_work("a", "a.txt", "alpha change\n", "pilot a change")
        self.sh("git", "-C", self.ws["b"], "rebase", "-q", "pilot/a")
        b1 = self.local_work("b", "shared.txt", "line four from b\n", "pilot b change")
        self.record("a", a1, "main")
        self.record("b", b1, "pilot/a", {"branch": "pilot/a", "commit": a1})
        self.journal_kill_tests()
        # 3. submission attempts during each outage mode defer within target
        for mode in ("refused", "503", "delay:30"):
            self.mode(mode)
            self.worker("a", "outage_" + mode.split(":")[0])
            self.worker("b", "outage_" + mode.split(":")[0])
        # 4. restart both workers during the outage (kill mid-run, then restart)
        self.mode("delay:30")
        for name in ("a", "b"):
            proc = self.worker(name, "restart", wait=False)
            time.sleep(1)
            proc.send_signal(signal.SIGKILL)
            self.finish(proc, name, "killed_mid_outage")
        self.mode("refused")
        for name in ("a", "b"):
            self.worker(name, "restarted_offline")
            data = journal_read(self.journal_path(name))
            commit = data["items"]["pilot/" + name]["commit"]
            self.result["checks"]["recoverable_after_restart_" + name] = self.sh(
                "git", "-C", self.ws[name], "cat-file", "-e", commit + "^{commit}", check=False).returncode == 0
        # 5. reconnect with an overlapping upstream edit
        self.mode("healthy")
        other = os.path.join(self.s, "upstream-editor")
        self.sh("git", "clone", "-q", self.api + "/git/pilot.git", other)
        with open(os.path.join(other, "shared.txt"), "a") as handle:
            handle.write("line four from upstream\n")
        self.sh("git", "-C", other, "commit", "-qam", "upstream overlapping edit")
        self.sh("git", "-C", other, "push", "-q", "origin", "main")
        self.sh("git", "-C", self.ws["a"], "fetch", "-q", "origin")
        self.sh("git", "-C", self.ws["a"], "rebase", "-q", "origin/main")
        a2 = self.sh("git", "-C", self.ws["a"], "rev-parse", "HEAD").stdout.strip()
        rerun_a = self.sh(sys.executable, "-B", "-m", "unittest", "-q", cwd=self.ws["a"], check=False)
        self.result["checks"]["reconcile_a"] = {"rebased": a2 != a1, "test_exit": rerun_a.returncode}
        self.record("a", a2, "main")
        conflict = self.sh("git", "-C", self.ws["b"], "rebase", "-q", "--onto", a2, a1, check=False)
        conflicted = conflict.returncode != 0
        if conflicted:
            self.sh("git", "-C", self.ws["b"], "rebase", "--abort")
        data = journal_read(self.journal_path("b"))
        data["items"]["pilot/b"]["state"] = "pending_conflict"
        data["items"]["pilot/b"]["depends_on"]["commit"] = a2
        journal_write(self.journal_path("b"), data)
        b_state = self.worker("b", "conflict_pending")
        self.result["checks"]["conflict_stays_pending"] = conflicted and b_state == "pending_conflict"
        # 6. A: lost response after create, then interrupt before marking delivered
        open(os.path.join(self.srv_root, "lose_next_create"), "w").close()
        self.worker("a", "lost_response")
        self.worker("a", "interrupted_before_delivered", crash="before_delivered")
        procs = [self.worker("a", "concurrent_restart", wait=False) for _ in range(2)]
        for proc in procs:
            self.finish(proc, "a", "concurrent_restart")
        # 7. resolve B's conflict, rerun its test, then submit after A
        self.sh("git", "-C", self.ws["b"], "rebase", "-q", "--onto", a2, a1, check=False)
        with open(os.path.join(self.ws["b"], "shared.txt"), "w") as handle:
            handle.write("line one\nline two\nline three\nline four from upstream\nline four from b\n")
        self.sh("git", "-C", self.ws["b"], "add", "shared.txt")
        self.sh("git", "-C", self.ws["b"], "-c", "core.editor=true", "rebase", "--continue")
        b2 = self.sh("git", "-C", self.ws["b"], "rev-parse", "HEAD").stdout.strip()
        rerun_b = self.sh(sys.executable, "-B", "-m", "unittest", "-q", cwd=self.ws["b"], check=False)
        self.result["checks"]["reconcile_b"] = {"test_exit": rerun_b.returncode,
                                                "on_top_of_a": self.sh("git", "-C", self.ws["b"], "merge-base",
                                                                       "--is-ancestor", a2, b2, check=False).returncode == 0}
        self.record("b", b2, "pilot/a", {"branch": "pilot/a", "commit": a2})
        self.worker("b", "submit_after_resolve")
        # 8. already-merged: mark A merged, replay a stale journal, resubmit
        with Handler.lock:
            state = _load(self.srv_root)
            for pull in state["pulls"]:
                if pull["head"] == "pilot/a":
                    pull.update(merged=True, state="closed")
            _save(self.srv_root, state)
        stale = journal_read(self.journal_path("a"))
        stale["items"]["pilot/a"]["state"] = "create_uncertain"
        journal_write(self.journal_path("a"), stale)
        self.worker("a", "stale_journal_after_merge")
        self.verify(a2, b2)
        self.stop()
        return self.result

    def verify(self, a2, b2):
        state = _load(self.srv_root)
        creates = state.get("creates", [])
        pushes = []
        log = os.path.join(self.srv_root, "pushes.log")
        if os.path.exists(log):
            with open(log) as handle:
                for line in handle:
                    ts, ref, old, new, forced = line.split()
                    pushes.append({"ref": ref, "new": new, "forced": forced == "yes"})
        order = [p["ref"] for p in pushes if p["ref"].startswith("refs/heads/pilot/")]
        tip = self.sh("git", "--git-dir", os.path.join(self.srv_root, "git", "pilot.git"),
                      "show", "pilot/b:shared.txt", check=False).stdout + \
            self.sh("git", "--git-dir", os.path.join(self.srv_root, "git", "pilot.git"),
                    "show", "pilot/b:a.txt", check=False).stdout
        journals = {n: journal_read(self.journal_path(n))["items"]["pilot/" + n] for n in ("a", "b")}
        self.result["checks"].update({
            "prs_per_head": {h: creates.count(h) for h in sorted(set(creates))},
            "one_pr_per_submission": sorted(creates) == ["pilot/a", "pilot/b"],
            "force_pushes": sum(p["forced"] for p in pushes),
            "dependency_order": order.index("refs/heads/pilot/a") < order.index("refs/heads/pilot/b")
            if "refs/heads/pilot/a" in order and "refs/heads/pilot/b" in order else False,
            "both_changes_preserved": all(s in tip for s in ("alpha change", "line four from b",
                                                             "line four from upstream")),
            "journal_states": {n: {"state": j["state"], "outcome": j.get("outcome")} for n, j in journals.items()},
            "server_requests": state["requests"],
            "pr_list_after": [{"head": p["head"], "merged": p["merged"]} for p in state["pulls"]],
        })


# --------------------------------------------------------------------------
# strace audit
# --------------------------------------------------------------------------

CONNECT = re.compile(r"(?:connect|sendto|sendmsg)\(.*?sa_family=(AF_INET6?|AF_UNIX|AF_NETLINK)"
                     r"(?:.*?(?:inet_addr\(\"([^\"]+)\"\)|inet_pton\(AF_INET6, \"([^\"]+)\"))?")
WRITE_OPEN = re.compile(r"^(\d+)\s+(?:openat|open|creat)\((?:(AT_FDCWD(?:<[^>]*>)?|\d+<[^>]*>), )?\"([^\"]+)\", ([A-Z_|]+)")
PATH_CALL = re.compile(r"^(\d+)\s+(rename|renameat2?|unlink|unlinkat|mkdir|mkdirat|link|symlink|truncate|chdir)\((.*)\)\s+=\s+(-?\d+)")
FCHDIR = re.compile(r"^(\d+)\s+fchdir\(\d+<([^>]+)>\)\s+=\s+0")
FORK = re.compile(r"^(\d+)\s+(?:(?:clone3?|fork|vfork)\(|<\.\.\. (?:clone3?|fork|vfork) resumed>).*\)\s+=\s+(\d+)")


def audit(trace, root_cwd, allowed):
    cwd = {}
    bad_dest, bad_write, dests = [], [], set()

    def absolute(pid, path, dirfd=None):
        if path.startswith("/"):
            return os.path.normpath(path)
        if dirfd and "<" in dirfd:
            base = dirfd.split("<", 1)[1].rstrip(">")
        else:
            base = cwd.get(pid, root_cwd)
        return os.path.normpath(os.path.join(base, path))

    def ok(path):
        return any(path == a or path.startswith(a.rstrip("/") + "/") for a in allowed)

    with open(trace, errors="replace") as handle:
        for line in handle:
            m = FORK.match(line)
            if m:
                cwd[m.group(2)] = cwd.get(m.group(1), root_cwd)
                continue
            m = FCHDIR.match(line)
            if m:
                cwd[m.group(1)] = m.group(2)
                continue
            m = CONNECT.search(line)
            if m:
                fam, v4, v6 = m.groups()
                addr = v4 or v6 or fam
                dests.add(addr)
                if fam in ("AF_INET", "AF_INET6") and addr not in ("127.0.0.1", "::1", "::ffff:127.0.0.1"):
                    bad_dest.append(addr)
                continue
            m = WRITE_OPEN.match(line)
            if m:
                pid, dirfd, path, flags = m.groups()
                if any(f in flags for f in ("O_WRONLY", "O_RDWR", "O_CREAT", "O_TRUNC")) and not line.rstrip().endswith(("ENOENT (No such file or directory)", "EACCES (Permission denied)", "EROFS (Read-only file system)")):
                    full = absolute(pid, path, dirfd)
                    if not ok(full):
                        bad_write.append(full)
                continue
            m = PATH_CALL.match(line)
            if m:
                pid, call, args, ret = m.groups()
                paths = re.findall(r"\"([^\"]+)\"", args)
                if call == "chdir":
                    if ret == "0" and paths:
                        cwd[pid] = absolute(pid, paths[0])
                    continue
                if ret != "0":
                    continue
                for path in paths[-1:] if call in ("link", "symlink") else paths:
                    full = absolute(pid, path)
                    if not ok(full):
                        bad_write.append(full)
    return {"destinations": sorted(dests), "non_local_destinations": sorted(set(bad_dest)),
            "writes_outside_scratch": sorted(set(bad_write))[:50],
            "writes_outside_scratch_count": len(set(bad_write))}


# --------------------------------------------------------------------------

def main(argv):
    cmd = argv[1] if len(argv) > 1 else ""
    if cmd == "server":
        serve(argv[2], int(argv[3]))
    elif cmd == "journal-write":
        journal_write(argv[2], json.loads(sys.stdin.read()))
    elif cmd == "worker":
        print(submit(argv[2], argv[3], argv[4], argv[5], argv[6]), flush=True)
    elif cmd == "drill":
        mounts = open("/proc/self/mountinfo").read()
        for point in (os.environ["HOME"], "/tmp"):
            if not re.search(r" %s .* - tmpfs " % re.escape(point), mounts):
                sys.exit("abort: %s is not a private tmpfs" % point)
        drill = Drill(argv[2], argv[3], argv[4], int(argv[5]) if len(argv) > 5 else 18080)
        try:
            print(json.dumps(drill.run(), sort_keys=True))
        finally:
            drill.stop()
    elif cmd == "audit":
        print(json.dumps(audit(argv[2], argv[3], argv[4:]), sort_keys=True))
    else:
        sys.exit(__doc__)



if __name__ == "__main__":
    main(sys.argv)
