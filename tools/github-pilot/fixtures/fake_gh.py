#!/usr/bin/env python3
"""Fixture gh for the outage drill (AI_GH_REAL_GH points here).

Accepts the gh arguments the toolkit uses and answers only from the loopback
test API named by PILOT_API. It holds no credential and never resolves a
public host. Connection refusal, HTTP errors and slow answers surface the way
gh surfaces them: an error on stderr and a non-zero exit.
"""

import json
import os
import subprocess
import sys
import urllib.error
import urllib.request

API = os.environ.get("PILOT_API", "http://127.0.0.1:9")
REPO = os.environ.get("PILOT_REPO", "pilot-owner/pilot-repo")


def fail(message, code=1):
    sys.stderr.write(message + "\n")
    sys.exit(code)


def request(method, path, body=None):
    url = API.rstrip("/") + "/api/" + path.lstrip("/")
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, method=method,
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as resp:  # no client timeout, like gh
            return resp.status, dict(resp.headers), resp.read()
    except urllib.error.HTTPError as exc:
        fail("HTTP %d: fixture error (%s)" % (exc.code, url.split("/api/")[0]))
    except (urllib.error.URLError, ConnectionError, OSError) as exc:
        fail("error connecting to api.github.com: %s" % type(exc).__name__)


def emit(body, jq, include=None):
    if include is not None:
        status, headers = include
        sys.stdout.write("HTTP/1.1 %d OK\r\n" % status)
        for key, value in headers.items():
            sys.stdout.write("%s: %s\r\n" % (key, value))
        sys.stdout.write("\r\n")
        sys.stdout.flush()
    if jq:
        out = subprocess.run(["jq", "-r", jq], input=body, capture_output=True)
        if out.returncode:
            fail("jq failed")
        sys.stdout.write(out.stdout.decode())
    else:
        sys.stdout.write(body.decode())
        if body and not body.endswith(b"\n"):
            sys.stdout.write("\n")


def option(args, name, default=None):
    if name in args:
        i = args.index(name)
        return args[i + 1] if i + 1 < len(args) else default
    return default


def main(args):
    if not args:
        fail("usage: gh <command>")
    if args[0] == "--version":
        print("gh version 0.0.0-fixture")
        return
    if args[:2] == ["auth", "token"]:
        print("fixture-token-not-a-credential")
        return
    if args[:2] == ["auth", "status"]:
        print("Logged in to fixture host")
        return
    if args[0] == "api":
        rest = args[1:]
        method = option(rest, "-X") or option(rest, "--method") or "GET"
        jq = option(rest, "--jq") or option(rest, "-q")
        include = "--include" in rest or "-i" in rest
        skip = {"-X", "--method", "--jq", "-q", "-H", "--header", "--hostname",
                "-f", "-F", "--field", "--raw-field", "--cache", "--template", "-t"}
        path = None
        i = 0
        while i < len(rest):
            item = rest[i]
            if item in skip:
                i += 2
                continue
            if item.startswith("-"):
                i += 1
                continue
            path = item
            break
        if path is None:
            fail("api: missing path")
        status, headers, body = request(method, path)
        emit(body, jq, (status, headers) if include else None)
        return
    if args[0] == "pr":
        sub = args[1] if len(args) > 1 else ""
        repo = option(args, "--repo") or option(args, "-R") or REPO
        jq = option(args, "--jq") or option(args, "-q")
        if sub == "view":
            branch = subprocess.run(["git", "rev-parse", "--abbrev-ref", "HEAD"],
                                    capture_output=True, text=True).stdout.strip()
            _, _, body = request("GET", "repos/%s/pulls?state=open&head=%s" % (repo, branch))
            pulls = json.loads(body)
            if not pulls:
                fail("no pull requests found for branch \"%s\"" % branch)
            emit(json.dumps(pulls[0]).encode(), jq)
            return
        if sub == "list":
            head = option(args, "--head", "")
            _, _, body = request("GET", "repos/%s/pulls?state=all&head=%s" % (repo, head))
            emit(body, jq)
            return
    if args[0] == "issue" and len(args) > 1 and args[1] == "view":
        _, _, body = request("GET", "repos/%s/issues/%s" % (option(args, "-R") or REPO, args[2]))
        emit(body, option(args, "--jq"))
        return
    fail("fixture gh: unsupported command %s" % args[0], 2)


if __name__ == "__main__":
    main(sys.argv[1:])
