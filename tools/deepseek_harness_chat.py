#!/usr/bin/env python3
"""One read-only DeepSeek Harness turn for bin/ai-deepseek-agent (#2549).

Runs the pinned dsh headless profile through the shared route registry
(tools/reviewer_routes.py) with a private DSH_HOME, the task on stdin or a
file, and only this route's credential in the child environment. Used by the
opt-in candidate engine (--route deepseek-openrouter); the default direct
engine is unchanged.

Output: the final assistant text on stdout; "SESSION <id>" as the first line
when a session id was observed. Exits 0 only on a completed final event.
"""
import argparse
import json
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import reviewer_routes as RR  # noqa: E402
from reviewer_usage import append_reviewer_attempt, reviewer_attempt  # noqa: E402


def main():
    ap = argparse.ArgumentParser(prog="deepseek-harness-chat")
    ap.add_argument("--route", required=True)
    ap.add_argument("--secrets-dir", required=True)
    ap.add_argument("--dsh-home", required=True,
                    help="private DSH_HOME for this conversation (persistent for resume)")
    ap.add_argument("--home", required=True, help="private HOME for the child process")
    ap.add_argument("--cwd", default=os.getcwd(),
                    help="read-only disposable workspace (default: this process's cwd)")
    ap.add_argument("--prompt-file", help="task text file (default: stdin)")
    ap.add_argument("--session", help="harness session id to resume")
    ap.add_argument("--timeout", type=int, default=1800)
    args = ap.parse_args()

    spec = RR.route(args.route)
    if spec["engine"] != "deepseek-harness":
        print(f"error: route {args.route} is not a deepseek-harness route", file=sys.stderr)
        return 2
    try:
        billing_id = RR.billing_session_id()
        affinity_id = billing_id or RR.cache_affinity_id(
            args.route, os.path.realpath(args.dsh_home), "named-session"
        )
    except RR.RouteError as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    key = RR.read_key(spec, secrets_dir=args.secrets_dir)
    if not key:
        print(f"error: credential missing ({spec['key_file']}) in {args.secrets_dir}",
              file=sys.stderr)
        return 3
    dsh = RR.resolve_deepseek_harness()
    if not dsh:
        print("error: deepseek harness binary not found; run bin/setup-deepseek-harness.sh",
              file=sys.stderr)
        return 3

    profiles = os.path.join(args.dsh_home, "profiles", "headless")
    os.makedirs(profiles, exist_ok=True)
    os.makedirs(args.home, exist_ok=True)
    with open(os.path.join(profiles, "cordis.patch.yml"), "w", encoding="utf-8") as fh:
        fh.write(RR.harness_patch_yaml(spec, affinity_id))

    prompt = open(args.prompt_file, encoding="utf-8").read() if args.prompt_file \
        else sys.stdin.read()

    env = {"PATH": os.environ.get("PATH", "/usr/bin:/bin"), "HOME": args.home,
           "DSH_HOME": args.dsh_home, "PYTHONDONTWRITEBYTECODE": "1",
           spec["key_env"]: key}
    for name in ("LANG", "TMPDIR", "TEMP", "TMP", "SYSTEMROOT", "PATHEXT", "COMSPEC",
                 "WINDIR", "SSL_CERT_FILE", "SSL_CERT_DIR", "NODE_EXTRA_CA_CERTS",
                 "AGENT_DSH_LOG"):
        if os.environ.get(name):
            env[name] = os.environ[name]
    if os.name == "nt":
        env["USERPROFILE"] = args.home

    cmd = [dsh, "--profile", "headless", "--json", "--permission-mode", "read-only",
           "--approval-policy", "never"]
    if args.session:
        cmd += ["--session-id", args.session]
    cmd.append("-")
    started = time.monotonic()

    def observe(outcome, events=""):
        if os.environ.get("AI_REVIEW_USAGE") != "1":
            return
        receipt = reviewer_attempt(
            events, route=args.route, model=spec["model"], engine=spec["engine"],
            outcome=outcome, elapsed=time.monotonic() - started, billing_id=billing_id,
        )
        path = os.path.join(args.dsh_home, "usage.jsonl")
        try:
            append_reviewer_attempt(path, receipt)
        except OSError:
            print("Usage receipt could not be recorded.", file=sys.stderr)

    proc = subprocess.Popen(cmd, cwd=args.cwd, env=env, stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, encoding="utf-8", errors="replace")
    try:
        out, err = proc.communicate(prompt, timeout=args.timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        proc.communicate()
        observe("timeout")
        print(f"error: no answer within {args.timeout}s", file=sys.stderr)
        return 3

    final_text, error_text = "", []
    session = args.session
    for line in out.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if not isinstance(ev, dict):
            continue
        if ev.get("type") == "session" and ev.get("sessionId"):
            session = session or ev["sessionId"]
        elif ev.get("type") == "error":
            error_text.append(json.dumps(ev.get("error", ev.get("message", ev)))[:2000])
        elif ev.get("type") == "final":
            reason = ev.get("reason") or {}
            if isinstance(reason, dict) and reason.get("kind") == "completed":
                final_text = ev.get("text") or ""
            else:
                detail = reason.get("error") if isinstance(reason, dict) else reason
                error_text.append(json.dumps(detail or reason or "final without completion")[:2000])
    problem = "\n".join(x for x in (error_text + [(err or "")[-2000:]]) if x.strip())
    answered = bool(final_text and not error_text and proc.returncode == 0)
    observe("answer" if answered else "failed", out)
    if not answered:
        print("error: no completed final answer"
              + (f": {problem[:800]}" if problem else ""), file=sys.stderr)
        return 3
    if session:
        print(f"SESSION {session}")
    sys.stdout.write(final_text.rstrip() + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
