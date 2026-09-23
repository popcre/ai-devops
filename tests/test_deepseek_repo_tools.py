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
import time

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

    # Secret-named directories, late binary content, non-string arguments.
    os.makedirs(os.path.join(root, "credentials"))
    with open(os.path.join(root, "credentials", "plain.txt"), "w") as fh:
        fh.write("needle-in-secret-dir\n")
    check("secret-named directory is not readable",
          run(root, "read_file", {"path": "credentials/plain.txt"}).startswith("Error: secret"))
    check("grep skips secret-named directories", "secret-dir" not in run(root, "grep", {"pattern": "needle"}))
    with open(os.path.join(root, "late.bin"), "wb") as fh:
        fh.write(b"text needle\n" * 2000 + b"x\0y needle\n")
    check("binary content after the first 8 KB is refused",
          run(root, "read_file", {"path": "late.bin", "start_line": 1, "end_line": 3}).startswith("Error: binary"))
    check("grep reports nothing from a late-binary file", "late.bin" not in run(root, "grep", {"pattern": "needle"}))
    check("non-string grep pattern is a tool error", run(root, "grep", {"pattern": 5}).startswith("Error: pattern"))
    check("non-string path is a tool error", run(root, "read_file", {"path": ["a"]}).startswith("Error:"))

    # usage-sum counts every paid round; a missing counter is dropped.
    r1, r2, fin, out_u = (os.path.join(tmp, n) for n in ("r1.json", "r2.json", "fin.json", "sum.json"))
    json.dump({"usage": {"prompt_tokens": 10, "completion_tokens": 1, "total_tokens": 11}}, open(r1, "w"))
    json.dump({"usage": {"prompt_tokens": 20, "completion_tokens": 2, "total_tokens": 22, "prompt_cache_hit_tokens": 5}}, open(r2, "w"))
    json.dump({"choices": [{"message": {"content": "done"}}],
               "usage": {"prompt_tokens": 30, "completion_tokens": 3, "total_tokens": 33}}, open(fin, "w"))
    subprocess.run([sys.executable, HELPER, "usage-sum", out_u, fin, r1, r2], check=True)
    summed = json.load(open(out_u))
    check("usage-sum adds every round", summed["usage"].get("prompt_tokens") == 60 and summed["usage"].get("total_tokens") == 66)
    check("usage-sum drops a counter one round lacks", "prompt_cache_hit_tokens" not in summed["usage"])
    check("usage-sum keeps the final answer", summed["choices"][0]["message"]["content"] == "done")

    for name in ("client_secret.json", "password.txt", "terraform.tfstate", "prod.tfvars",
                 "db-credentials.yaml", "service-account-prod.json"):
        with open(os.path.join(root, name), "w") as fh:
            fh.write("needle\n")
        check(f"secret-looking name refused: {name}",
              run(root, "read_file", {"path": name}).startswith("Error: secret"))
    check("grep skips secret-looking names",
          not any(n in run(root, "grep", {"pattern": "needle"}) for n in ("client_secret", "password.txt", "tfstate")))

    # Malformed tool-call structures become tool errors, not helper crashes.
    for bad in ([{"id": "x", "function": "not-a-dict"}], ["not-a-dict"],
                [{"id": "y", "function": {"name": "read_file", "arguments": {"path": "sub/a.txt"}}}]):
        breq, bresp, blog = (os.path.join(tmp, n) for n in ("breq.json", "bresp.json", "blog.jsonl"))
        with open(breq, "w") as fh:
            json.dump({"model": "m", "messages": [{"role": "user", "content": "q"}], "tools": t.TOOLS}, fh)
        with open(bresp, "w") as fh:
            json.dump({"choices": [{"message": {"role": "assistant", "tool_calls": bad}}]}, fh)
        brc = subprocess.run([sys.executable, HELPER, "step", root, breq, bresp, blog, "0"],
                             capture_output=True).returncode
        check(f"malformed tool call handled: {json.dumps(bad)[:40]}", brc == 10)
        sent = json.load(open(breq))["messages"]
        asst = [m for m in sent if m.get("role") == "assistant"][-1]
        good = all(isinstance(c.get("id"), str) and c["id"] and isinstance(c["function"]["name"], str)
                   and isinstance(c["function"]["arguments"], str) for c in asst["tool_calls"])
        replies = [m["tool_call_id"] for m in sent if m.get("role") == "tool"]
        check(f"forwarded tool calls are well-formed: {json.dumps(bad)[:40]}",
              good and replies == [c["id"] for c in asst["tool_calls"]])

    # Grep time budget stops a long search instead of running unbounded.
    saved = t.GREP_SECONDS
    t.GREP_SECONDS = 0
    check("grep stops at its time budget", "search stopped after" in run(root, "grep", {"pattern": "zzz-no-match"}))
    with open(os.path.join(root, "evil.txt"), "w") as fh:
        fh.write("a" * 40 + "!\n")
    t.GREP_SECONDS = 1
    began = time.monotonic()
    out = run(root, "grep", {"pattern": r"^(a+)+$", "path": "evil.txt"})
    check("catastrophic regular expression stops at the grep budget",
          out.startswith("Error: search stopped") and time.monotonic() - began < 20)
    t.GREP_SECONDS = saved

    # A handle that is not the checked file (swapped between check and open) is refused.
    def swapping_open(path, *a, **k):
        return open(os.path.join(tmp, "outside.txt"), *a, **k)
    t.open = swapping_open
    try:
        check("handle that is not the checked file is refused",
              run(root, "read_file", {"path": "sub/a.txt"}).startswith("Error: file changed"))
    finally:
        del t.open

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
