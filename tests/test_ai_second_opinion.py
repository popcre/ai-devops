#!/usr/bin/env python3
"""Offline tests for bin/ai-second-opinion and its ai-glm/ai-muse/ai-stepfun shims (#2074).

A fake OpenCode records its arguments and answers; no provider is contacted."""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOL = os.path.join(ROOT, "bin", "ai-second-opinion")

FAKE = textwrap.dedent("""\
    #!/usr/bin/env python3
    import json, os, sys
    state = os.environ["AI_REVIEW_SIMPLE_FAKE_STATE"]
    prompt = sys.stdin.read()
    args = sys.argv[1:]
    with open(os.path.join(state, "calls.jsonl"), "a") as fh:
        fh.write(json.dumps({"args": args, "prompt": prompt, "cwd": os.getcwd()}) + "\\n")
    mode = open(os.path.join(state, "mode")).read().strip() if os.path.exists(os.path.join(state, "mode")) else "ok"
    if mode == "credit":
        print(json.dumps({"type": "error", "error": {"message": "status 429 rate limit exceeded"}}))
        sys.exit(1)
    if mode == "write":
        with open("NEW.txt", "w") as fh:
            fh.write("made by fake\\n")
    sid = "--session" in args and args[args.index("--session") + 1] or "ses_fake1"
    print(json.dumps({"type": "step_start", "sessionID": sid, "part": {}}))
    print(json.dumps({"type": "text", "sessionID": sid, "part": {"text": "ANSWER for: " + prompt.splitlines()[0]}}))
""")


class SecondOpinion(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        t = self.tmp
        self.state = os.path.join(t, "fake")
        os.makedirs(self.state)
        fake = os.path.join(t, "opencode")
        with open(fake, "w") as fh:
            fh.write(FAKE)
        os.chmod(fake, 0o755)
        if os.name == "nt":
            # Windows cannot exec a shebang script; run the same fake through a .cmd shim.
            with open(fake + ".cmd", "w") as fh:
                fh.write('@"%s" "%s" %%*\r\n' % (sys.executable, fake))
            fake += ".cmd"
        secrets = os.path.join(t, "secrets")
        os.makedirs(secrets)
        for name in ("muse-api-key", "stepfun-api-key"):
            with open(os.path.join(secrets, name), "w") as fh:
                fh.write("k-123456789\n")
        with open(os.path.join(secrets, "zai-coding-plan-key.json"), "w") as fh:
            json.dump({"key": "k-123456789"}, fh)
        self.repo = os.path.join(t, "repo")
        subprocess.run(["git", "init", "-q", self.repo], check=True)
        with open(os.path.join(self.repo, "a.txt"), "w") as fh:
            fh.write("one\n")
        g = ["git", "-C", self.repo, "-c", "user.name=t", "-c", "user.email=t@l"]
        subprocess.run(g[:3] + ["add", "a.txt"], check=True)
        subprocess.run(g + ["commit", "-qm", "base"], check=True)
        with open(os.path.join(self.repo, "a.txt"), "a") as fh:
            fh.write("two\n")
        with open(os.path.join(self.repo, "untracked.txt"), "w") as fh:
            fh.write("u\n")
        self.env = dict(os.environ, AI_REVIEW_SIMPLE_OPENCODE=fake, AI_REVIEW_SIMPLE_SECRETS_DIR=secrets,
                        AI_REVIEW_SIMPLE_FAKE_STATE=self.state, PYTHONDONTWRITEBYTECODE="1",
                        AI_SECOND_OPINION_HOME=os.path.join(t, "so"))
        for k in ("AI_MUSE_KEY", "AI_STEPFUN_KEY", "ZAI_API_KEY"):
            self.env.pop(k, None)

    def tearDown(self):
        for d, dirs, files in os.walk(self.tmp):
            for x in dirs + files:
                try:
                    os.chmod(os.path.join(d, x), 0o700)
                except OSError:
                    pass
        shutil.rmtree(self.tmp, ignore_errors=True)

    def run_tool(self, *args, tool=None, stdin=""):
        cmd = [tool] if tool else [sys.executable, TOOL]
        return subprocess.run(cmd + list(args), cwd=self.repo, env=self.env, input=stdin,
                              capture_output=True, text=True)

    def calls(self):
        with open(os.path.join(self.state, "calls.jsonl")) as fh:
            return [json.loads(x) for x in fh]

    def test_one_shot_ask_is_read_only_copy(self):
        r = self.run_tool("glm", "ask", "is this bounded?")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("ANSWER for: is this bounded?", r.stdout)
        call = self.calls()[0]
        self.assertIn("second-opinion", call["args"])
        self.assertIn("zai-coding-plan/glm-5.3", call["args"])
        self.assertNotEqual(os.path.realpath(call["cwd"]), os.path.realpath(self.repo))
        with open(os.path.join(call["cwd"], "a.txt")) as fh:
            self.assertEqual(fh.read(), "one\ntwo\n")  # uncommitted edit carried over
        self.assertTrue(os.path.exists(os.path.join(call["cwd"], "untracked.txt")))
        self.assertFalse(os.access(os.path.join(call["cwd"], "a.txt"), os.W_OK))

    def test_named_session_continues(self):
        self.assertEqual(self.run_tool("muse", "new", "s1", "first").returncode, 0)
        r = self.run_tool("muse", "ask", "s1", "second")
        self.assertEqual(r.returncode, 0, r.stderr)
        c = self.calls()
        self.assertNotIn("--session", c[0]["args"])
        self.assertEqual(c[1]["args"][c[1]["args"].index("--session") + 1], "ses_fake1")
        listing = self.run_tool("muse", "list").stdout
        self.assertIn("s1\tread-only\tidle\tturns=2", listing)
        self.assertIn("second", self.run_tool("muse", "transcript", "s1").stdout)
        self.assertEqual(self.run_tool("muse", "delete", "s1").returncode, 0)
        self.assertEqual(self.run_tool("muse", "list").stdout, "")

    def test_review_includes_diff(self):
        r = self.run_tool("stepfun", "review", "--base", "HEAD")
        self.assertEqual(r.returncode, 0, r.stderr)
        prompt = self.calls()[0]["prompt"]
        self.assertIn("+two", prompt)
        self.assertIn("VERDICT: APPROVE", prompt)

    def test_implement_returns_diff_and_leaves_checkout(self):
        with open(os.path.join(self.state, "mode"), "w") as fh:
            fh.write("write")
        r = self.run_tool("stepfun", "implement", "i1", "add a file")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("implement", self.calls()[0]["args"])
        self.assertIn("+made by fake", r.stdout)
        self.assertFalse(os.path.exists(os.path.join(self.repo, "NEW.txt")))
        self.assertIn("+made by fake", self.run_tool("stepfun", "diff", "i1").stdout)

    def test_unavailable_is_exit_3(self):
        with open(os.path.join(self.state, "mode"), "w") as fh:
            fh.write("credit")
        r = self.run_tool("glm", "ask", "hello there")
        self.assertEqual(r.returncode, 3)
        self.assertIn("out of credit", r.stderr)
        self.assertNotIn("k-123456789", r.stderr)

    def test_missing_key_is_exit_3(self):
        os.remove(os.path.join(self.env["AI_REVIEW_SIMPLE_SECRETS_DIR"], "muse-api-key"))
        self.assertEqual(self.run_tool("muse", "ask", "hello there").returncode, 3)
        self.assertEqual(self.run_tool("muse", "doctor").returncode, 3)

    def test_store_key_if_missing_and_stdin(self):
        r = self.run_tool("stepfun", "store-key", "--if-missing")
        self.assertIn("already present", r.stdout)
        os.remove(os.path.join(self.env["AI_REVIEW_SIMPLE_SECRETS_DIR"], "stepfun-api-key"))
        r = self.run_tool("stepfun", "store-key", stdin="new-key-value\n")
        self.assertEqual(r.returncode, 0, r.stderr)
        p = os.path.join(self.env["AI_REVIEW_SIMPLE_SECRETS_DIR"], "stepfun-api-key")
        with open(p) as fh:
            self.assertEqual(fh.read(), "new-key-value\n")
        if os.name != "nt":  # NTFS has no POSIX mode bits to check
            self.assertEqual(os.stat(p).st_mode & 0o777, 0o600)

    def test_shims_route_to_provider(self):
        for prov in ("glm", "muse", "stepfun"):
            r = self.run_tool("ask", f"hi from {prov}", tool=os.path.join(ROOT, "bin", f"ai-{prov}" + (".cmd" if os.name == "nt" else "")))
            self.assertEqual(r.returncode, 0, r.stderr)
        models = [c["args"][c["args"].index("--model") + 1] for c in self.calls()]
        self.assertEqual(models, ["zai-coding-plan/glm-5.3", "meta-model-api/muse-spark-1.3-contributor",
                                  "stepfun-api/step-5-preview"])


if __name__ == "__main__":
    unittest.main()
