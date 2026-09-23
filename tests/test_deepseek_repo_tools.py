#!/usr/bin/env python3
"""Fast offline cases for tools/deepseek_repo_tools.py (no network, no key).

Run directly; exits non-zero on the first failing case. Called from
tests/test-ai-deepseek-agent.sh, and fast enough to pass to a reviewer as
--tests evidence on its own.
"""
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
HELPER = os.path.join(HERE, "..", "tools", "deepseek_repo_tools.py")
sys.path.insert(0, os.path.dirname(HELPER))
import deepseek_repo_tools as t  # noqa: E402

FAILED = []


def check(name, cond):
    print(("ok   " if cond else "FAIL ") + name)
    if not cond:
        FAILED.append(name)


def run(root, name, args):
    return t.run_tool(root, name, json.dumps(args))


with tempfile.TemporaryDirectory() as tmp:
    root = os.path.join(tmp, "repo")
    os.makedirs(os.path.join(root, "sub"))
    os.makedirs(os.path.join(root, ".git"))
    os.makedirs(os.path.join(root, "node_modules", "pkg"))
    with open(os.path.join(root, ".git", "config"), "w") as fh:
        fh.write("[core] needle\n")
    with open(os.path.join(root, "node_modules", "pkg", "index.js"), "w") as fh:
        fh.write("needle\n")
    with open(os.path.join(root, "sub", "a.txt"), "w") as fh:
        fh.write("alpha\nbeta needle\n")
    with open(os.path.join(root, ".env"), "w") as fh:
        fh.write("TOKEN=needle\n")
    with open(os.path.join(root, "outside-marker.txt"), "w") as fh:
        fh.write("inside\n")
    with open(os.path.join(tmp, "outside.txt"), "w") as fh:
        fh.write("outside needle\n")
    big = os.path.join(root, "big.txt")
    with open(big, "w") as fh:
        for i in range(1, 40001):
            fh.write(f"row {i} {'x' * 20}\n")
    check("big fixture exceeds the whole-file cap", os.path.getsize(big) > t.MAX_FILE_BYTES)

    # Windows-equivalent spellings of denied directories and secret files.
    for spelling in (".GIT/config", ".git./config", ".git /config", ".Git./config",
                     "NODE_MODULES/pkg/index.js", "node_modules./pkg/index.js"):
        check(f"denied directory spelling refused: {spelling}",
              run(root, "read_file", {"path": spelling}).startswith("Error:"))
    for spelling in (".ENV", ".env.", ".env ", "sub/../.env"):
        check(f"secret spelling refused: {spelling}",
              run(root, "read_file", {"path": spelling}).startswith("Error:"))
    check("alternate data stream syntax refused",
          run(root, "read_file", {"path": "sub/a.txt:hidden"}).startswith("Error:"))
    check("dots-only component refused", run(root, "read_file", {"path": "..."}).startswith("Error:"))
    check("parent escape refused", run(root, "read_file", {"path": "../outside.txt"}).startswith("Error:"))
    check("absolute path refused", run(root, "read_file", {"path": os.path.join(tmp, "outside.txt")}).startswith("Error:"))
    check("drive path refused", run(root, "read_file", {"path": "C:/Windows/win.ini"}).startswith("Error:"))
    listing = run(root, "list_dir", {"path": "."})
    check("listing hides denied directories", ".git" not in listing and "node_modules" not in listing)
    check("listing marks secret files unreadable", ".env (secret, unreadable)" in listing)

    # Large files: whole read refused with guidance; ranged read and grep work.
    check("whole read of a large file is refused with range guidance",
          "pass start_line and end_line" in run(root, "read_file", {"path": "big.txt"}))
    ranged = run(root, "read_file", {"path": "big.txt", "start_line": 39999, "end_line": 40000})
    check("ranged read of a large file works", "39999: row 39999" in ranged and "(lines 39999-40000 of 40000)" in ranged)
    check("grep searches a large file", "big.txt:40000:row 40000" in run(root, "grep", {"pattern": r"^row 40000 "}))
    out = run(root, "grep", {"pattern": "needle"})
    check("grep finds ordinary matches", "sub/a.txt:2:beta needle" in out)
    check("grep skips secrets, denied directories and outside files",
          ".env" not in out and ".git" not in out and "node_modules" not in out and "outside" not in out)
    check("invalid regular expression is refused", run(root, "grep", {"pattern": "("}).startswith("Error: invalid"))

    # Grep time budget stops a long search instead of running unbounded.
    saved = t.GREP_SECONDS
    t.GREP_SECONDS = 0
    check("grep stops at its time budget", "search stopped after" in run(root, "grep", {"pattern": "zzz-no-match"}))
    t.GREP_SECONDS = saved

    # Symbolic links are never followed (skipped where the OS cannot make one).
    link = os.path.join(root, "link.txt")
    try:
        os.symlink(os.path.join(tmp, "outside.txt"), link)
        made = os.path.islink(link)
    except (OSError, NotImplementedError):
        made = False
    if made:
        check("symbolic link refused", run(root, "read_file", {"path": "link.txt"}).startswith("Error:"))
        check("grep does not follow symbolic links", "outside" not in run(root, "grep", {"pattern": "outside"}))
    else:
        print("skip symbolic link cases (this filesystem cannot create a real symlink)")

    # step: budget exhaustion removes tools and asks for the final answer.
    req = os.path.join(tmp, "req.json")
    resp = os.path.join(tmp, "resp.json")
    log = os.path.join(tmp, "log.jsonl")
    msgs = os.path.join(tmp, "msgs.json")
    with open(msgs, "w") as fh:
        json.dump([{"role": "system", "content": "sys"}, {"role": "user", "content": "q"}], fh)
    subprocess.run([sys.executable, HELPER, "init", msgs, "m", req], check=True)
    call = {"id": "c1", "type": "function", "function": {"name": "read_file", "arguments": json.dumps({"path": "sub/a.txt"})}}
    with open(resp, "w") as fh:
        json.dump({"choices": [{"message": {"role": "assistant", "content": None, "tool_calls": [call]}}]}, fh)
    env = dict(os.environ, DEEPSEEK_TOOLS_MAX_ROUNDS="1")
    rc = subprocess.run([sys.executable, HELPER, "step", root, req, resp, log, "0"], env=env).returncode
    body = json.load(open(req))
    check("step continues with a tool result", rc == 10 and body["messages"][-2]["role"] == "tool")
    check("last round withholds tools and demands an answer",
          "tools" not in body and "budget exhausted" in body["messages"][-1]["content"])
    entry = json.loads(open(log).read().splitlines()[0])
    check("tool call is logged", entry["tool"] == "read_file" and entry["refused"] is False)

print(f"{'FAILED ' + str(len(FAILED)) if FAILED else 'all passed'}")
sys.exit(1 if FAILED else 0)
