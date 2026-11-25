#!/usr/bin/env python3
"""Offline tests for bin/ai-second-opinion and its ai-glm/ai-muse/ai-stepfun shims (#2074).

A fake OpenCode records its arguments and answers; no provider is contacted."""
import json
import os
import pathlib
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
    import json, os, sys, time
    state = os.environ["AI_REVIEW_SIMPLE_FAKE_STATE"]
    prompt = sys.stdin.read()
    args = sys.argv[1:]
    with open(os.path.join(state, "calls.jsonl"), "a") as fh:
        fh.write(json.dumps({"args": args, "prompt": prompt, "cwd": os.getcwd(), "files": sorted(os.listdir("."))}) + "\\n")
    mode = open(os.path.join(state, "mode")).read().strip() if os.path.exists(os.path.join(state, "mode")) else "ok"
    if mode == "credit":
        print(json.dumps({"type": "error", "error": {"message": "status 429 rate limit exceeded"}}))
        sys.exit(1)
    if mode == "doctor-secret":
        print(json.dumps({"type": "error", "error": {"message": "status 503 api_key=" + os.environ.get("ZHIPU_API_KEY", "")}}))
        sys.exit(1)
    if mode == "doctor-answer-secret":
        print(json.dumps({"type": "text", "part": {"text": os.environ.get("ZHIPU_API_KEY", "")}}))
        sys.exit(0)
    if mode == "doctor-timeout":
        time.sleep(10)
    if mode == "need-models":
        # Real OpenCode 1.18 with an empty cache uses its bundled catalogue and dies.
        mp = os.environ.get("OPENCODE_MODELS_PATH", "")
        cat = json.load(open(mp)) if mp and os.path.isfile(mp) else {}
        if "glm-5.4" not in cat.get("zai-coding-plan", {}).get("models", {}):
            print(json.dumps({"type": "error", "error": {"message": "ProviderModelNotFoundError: Model not found: zai-coding-plan/glm-5.4"}}))
            sys.exit(1)
    if mode == "write":
        with open("NEW.txt", "w") as fh:
            fh.write("made by fake\\n")
    sid = "--session" in args and args[args.index("--session") + 1] or "ses_fake1"
    print(json.dumps({"type": "step_start", "sessionID": sid, "part": {}}))
    text = "ANSWER for: " + prompt.splitlines()[0]
    if mode == "verdict":
        text += "\\nVERDICT: APPROVE"
    print(json.dumps({"type": "text", "sessionID": sid, "part": {"text": text}}))
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
                        AI_SECOND_OPINION_HOME=os.path.join(t, "so"),
                        AI_OPENCODE_MODELS_CACHE=os.path.join(t, "models-cache", "models.json"),
                        AI_OPENCODE_MODELS_URL=pathlib.Path(t, "catalogue.json").as_uri())
        with open(os.path.join(t, "catalogue.json"), "w") as fh:
            json.dump({"zai-coding-plan": {"models": {"glm-5.4": {}}}}, fh)
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
        self.assertIn("zai-coding-plan/glm-5.4", call["args"])
        self.assertNotEqual(os.path.realpath(call["cwd"]), os.path.realpath(self.repo))
        with open(os.path.join(call["cwd"], "a.txt")) as fh:
            self.assertEqual(fh.read(), "one\ntwo\n")  # uncommitted edit carried over
        self.assertTrue(os.path.exists(os.path.join(call["cwd"], "untracked.txt")))
        self.assertFalse(os.access(os.path.join(call["cwd"], "a.txt"), os.W_OK))

    def test_fresh_tree_gets_current_model_catalogue(self):
        with open(os.path.join(self.state, "mode"), "w") as fh:
            fh.write("need-models")
        r = self.run_tool("glm", "ask", "first run?")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(os.path.isfile(self.env["AI_OPENCODE_MODELS_CACHE"]))
        # Offline afterwards: the shared copy still seeds the next fresh tree.
        os.remove(os.path.join(self.tmp, "catalogue.json"))
        os.utime(self.env["AI_OPENCODE_MODELS_CACHE"], (0, 0))
        r = self.run_tool("glm", "ask", "offline run?")
        self.assertEqual(r.returncode, 0, r.stderr)

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

    def test_review_without_verdict_is_incomplete(self):
        r = self.run_tool("stepfun", "review", "--base", "HEAD")
        self.assertEqual(r.returncode, 3)
        self.assertIn("without a VERDICT", r.stderr)

    def test_session_mode_mismatch_is_refused(self):
        self.assertEqual(self.run_tool("muse", "new", "ro", "q").returncode, 0)
        r = self.run_tool("muse", "implement", "ro", "change it")
        self.assertEqual(r.returncode, 2)

    def test_review_includes_diff(self):
        with open(os.path.join(self.state, "mode"), "w") as fh:
            fh.write("verdict")
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
        self.assertEqual(models, ["zai-coding-plan/glm-5.4", "meta-model-api/muse-spark-1.3-contributor",
                                  "stepfun-api/step-5-preview"])

    def doctor_receipt(self):
        import pathlib
        paths = list(pathlib.Path(self.env["AI_SECOND_OPINION_HOME"]).glob(".doctor-diagnostics/glm/*/outcomes.json"))
        self.assertEqual(len(paths), 1)
        path = paths[0]
        if os.name != "nt":
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(path.parent.stat().st_mode & 0o777, 0o700)
        return json.loads(path.read_text()), path.read_text()

    def test_doctor_success_preserves_private_outcome_and_only_sends_ready_in_empty_repo(self):
        result = self.run_tool("glm", "doctor", "--live")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("live diagnostics:", result.stderr)
        receipt, text = self.doctor_receipt()
        self.assertEqual(receipt["status"], "passed")
        self.assertEqual([row["outcome"] for row in receipt["attempts"]], ["ready"])
        self.assertNotIn("k-123456789", text + result.stdout + result.stderr)
        call = self.calls()[0]
        self.assertEqual(call["prompt"], "Reply with exactly the word READY.")
        self.assertEqual(call["files"], [".git", "README"])
        self.assertNotIn("a.txt", call["files"])
        self.assertNotIn("untracked.txt", call["files"])
        self.assertFalse(os.path.exists(call["cwd"]))  # probe worktree still cleans up
        self.assertEqual(len(self.calls()), 1)

    def test_doctor_failure_retains_all_three_redacted_outcomes_without_qualification(self):
        with open(os.path.join(self.state, "mode"), "w") as fh:
            fh.write("doctor-secret")
        result = self.run_tool("glm", "doctor", "--live")
        self.assertEqual(result.returncode, 3)
        receipt, text = self.doctor_receipt()
        self.assertEqual(receipt["status"], "failed")
        self.assertEqual(len(receipt["attempts"]), 3)
        self.assertTrue(all(row["exit_code"] == 3 for row in receipt["attempts"]))
        self.assertIn("[REDACTED]", text)
        self.assertNotIn("k-123456789", text + result.stdout + result.stderr)
        self.assertEqual(len(self.calls()), 3)

    def test_doctor_unexpected_answer_redacts_stdout_and_private_excerpt(self):
        with open(os.path.join(self.state, "mode"), "w") as fh:
            fh.write("doctor-answer-secret")
        result = self.run_tool("glm", "doctor", "--live")
        self.assertEqual(result.returncode, 3)
        receipt, text = self.doctor_receipt()
        self.assertEqual(len(receipt["attempts"]), 3)
        self.assertTrue(all(row["outcome"] == "unexpected_reply" for row in receipt["attempts"]))
        self.assertIn("[REDACTED]", result.stdout)
        self.assertNotIn("k-123456789", result.stdout + result.stderr + text)

    def test_doctor_local_exception_is_redacted_retained_and_fails_without_retry(self):
        code = """import runpy, sys, os
ns = runpy.run_path(sys.argv[1])
def fail(*args):
    with open(os.path.join(os.environ['AI_REVIEW_SIMPLE_FAKE_STATE'], 'probe-path'), 'w') as fh:
        fh.write(args[2])
    raise RuntimeError('local failure k-123456789')
ns['main'].__globals__['start'] = fail
sys.exit(ns['main'](['glm', 'doctor', '--live']))
"""
        result = subprocess.run([sys.executable, "-c", code, TOOL], cwd=self.repo, env=self.env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        receipt, text = self.doctor_receipt()
        self.assertEqual(receipt["status"], "failed")
        self.assertEqual([row["outcome"] for row in receipt["attempts"]], ["local_error"])
        self.assertIn("RuntimeError", text)
        self.assertIn("[REDACTED]", text)
        self.assertNotIn("k-123456789", text + result.stdout + result.stderr)
        self.assertFalse(os.path.exists(os.path.join(self.state, "calls.jsonl")))
        with open(os.path.join(self.state, "probe-path")) as fh:
            self.assertFalse(os.path.exists(fh.read()))

    def test_doctor_timeout_retains_failed_attempts_and_does_not_pass(self):
        self.env["AI_SECOND_OPINION_TIMEOUT"] = "1"
        with open(os.path.join(self.state, "mode"), "w") as fh:
            fh.write("doctor-timeout")
        result = self.run_tool("glm", "doctor", "--live")
        self.assertEqual(result.returncode, 3)
        receipt, text = self.doctor_receipt()
        self.assertEqual(receipt["status"], "failed")
        self.assertEqual([row["outcome"] for row in receipt["attempts"]], ["timeout"] * 3)
        self.assertTrue(all(row["elapsed_ms"] >= 900 for row in receipt["attempts"]))
        self.assertNotIn("k-123456789", text)
        self.assertEqual(len(self.calls()), 3)


FAKE_AGY = textwrap.dedent("""\
    #!/usr/bin/env python3
    import json, os, sys
    state = os.environ["AI_REVIEW_SIMPLE_FAKE_STATE"]
    prompt = sys.stdin.read()
    args = sys.argv[1:]
    with open(os.path.join(state, "agy-calls.jsonl"), "a") as fh:
        fh.write(json.dumps({"args": args, "prompt": prompt, "cwd": os.getcwd()}) + "\\n")
    mode = open(os.path.join(state, "mode")).read().strip() if os.path.exists(os.path.join(state, "mode")) else "ok"
    if mode == "auth":
        print(json.dumps({"conversation_id": "", "status": "ERROR", "response": "",
                          "error": "authentication failed or timed out"}))
        sys.exit(1)
    if mode == "ready":
        print(json.dumps({"conversation_id": "cid-doc", "status": "SUCCESS", "response": "READY\\n"}))
        sys.exit(0)
    if mode == "write":
        with open("AGY_NEW.txt", "w") as fh:
            fh.write("edited by agy\\n")
    cid = "--conversation" in args and args[args.index("--conversation") + 1] or "cid_fake1"
    print(json.dumps({"conversation_id": cid, "status": "SUCCESS",
                      "response": "AGY_ANSWER: " + prompt.splitlines()[-1]}))
""")


class AntigravitySecondOpinion(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        t = self.tmp
        self.state = os.path.join(t, "fake")
        os.makedirs(self.state)
        fake = os.path.join(t, "agy")
        with open(fake, "w") as fh:
            fh.write(FAKE_AGY)
        os.chmod(fake, 0o755)
        if os.name == "nt":
            with open(fake + ".cmd", "w") as fh:
                fh.write('@"%s" "%s" %%*\r\n' % (sys.executable, fake))
            fake += ".cmd"
        self.repo = os.path.join(t, "repo")
        subprocess.run(["git", "init", "-q", self.repo], check=True)
        with open(os.path.join(self.repo, "a.txt"), "w") as fh:
            fh.write("one\n")
        g = ["git", "-C", self.repo, "-c", "user.name=t", "-c", "user.email=t@l"]
        subprocess.run(g[:3] + ["add", "a.txt"], check=True)
        subprocess.run(g + ["commit", "-qm", "base"], check=True)
        self.env = dict(os.environ, AI_REVIEW_SIMPLE_AGY=fake, AI_REVIEW_SIMPLE_FAKE_STATE=self.state,
                        PYTHONDONTWRITEBYTECODE="1", AI_SECOND_OPINION_HOME=os.path.join(t, "so"))

    def tearDown(self):
        for d, dirs, files in os.walk(self.tmp):
            for x in dirs + files:
                try:
                    os.chmod(os.path.join(d, x), 0o700)
                except OSError:
                    pass
        shutil.rmtree(self.tmp, ignore_errors=True)

    def run_tool(self, *args):
        return subprocess.run([sys.executable, TOOL] + list(args), cwd=self.repo, env=self.env,
                              capture_output=True, text=True)

    def calls(self):
        with open(os.path.join(self.state, "agy-calls.jsonl")) as fh:
            return [json.loads(x) for x in fh]

    def test_named_session_resumes_conversation(self):
        r1 = self.run_tool("antigravity", "new", "s1", "first question")
        self.assertEqual(r1.returncode, 0, r1.stderr)
        self.assertIn("AGY_ANSWER: first question", r1.stdout)
        r2 = self.run_tool("antigravity", "ask", "s1", "follow up")
        self.assertEqual(r2.returncode, 0, r2.stderr)
        calls = self.calls()
        self.assertEqual(len(calls), 2)
        self.assertIn("--mode", calls[0]["args"])
        self.assertEqual(calls[0]["args"][calls[0]["args"].index("--mode") + 1], "plan")
        self.assertIn("--conversation", calls[1]["args"])
        self.assertEqual(calls[1]["args"][calls[1]["args"].index("--conversation") + 1], "cid_fake1")
        for call in calls:
            args = call["args"]
            with open(args[args.index("--settings") + 1], encoding="utf-8") as fh:
                allow = json.load(fh)["permissions"]["allow"]
            self.assertIn("command(grep)", allow)
            self.assertNotIn("command(*)", allow)
            self.assertFalse({"--dangerously-skip-permissions", "--yolo"} & set(args))
            self.assertTrue(call["prompt"].startswith("Read-only session:"))

    def test_implement_uses_accept_edits_and_returns_diff(self):
        with open(os.path.join(self.state, "mode"), "w") as fh:
            fh.write("write")
        r = self.run_tool("antigravity", "implement", "imp1", "add file")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("AGY_NEW.txt", r.stdout)
        self.assertFalse(os.path.exists(os.path.join(self.repo, "AGY_NEW.txt")))
        call = self.calls()[0]
        self.assertEqual(call["args"][call["args"].index("--mode") + 1], "accept-edits")
        self.assertNotIn("--settings", call["args"])

    def test_doctor_and_store_key_and_auth_error(self):
        r = self.run_tool("antigravity", "store-key")
        self.assertEqual(r.returncode, 0, r.stderr)
        with open(os.path.join(self.state, "mode"), "w") as fh:
            fh.write("ready")
        r = self.run_tool("antigravity", "doctor", "--live")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("doctor: OK", r.stdout)
        with open(os.path.join(self.state, "mode"), "w") as fh:
            fh.write("auth")
        r = self.run_tool("antigravity", "ask", "hello")
        self.assertEqual(r.returncode, 3)


CODEX_FAKE = textwrap.dedent("""\
    #!/usr/bin/env python3
    import json, os, sys
    state = os.environ["AI_REVIEW_SIMPLE_FAKE_STATE"]
    prompt = sys.stdin.read()
    args = sys.argv[1:]
    with open(os.path.join(state, "codex-calls.jsonl"), "a") as fh:
        fh.write(json.dumps({"args": args, "prompt": prompt, "cwd": os.getcwd()}) + "\\n")
    mode = open(os.path.join(state, "mode")).read().strip() if os.path.exists(os.path.join(state, "mode")) else "ok"
    print(json.dumps({"type": "thread.started", "thread_id": "th_fake1"}))
    print(json.dumps({"type": "item.completed", "item": {"type": "agent_message", "text": "CODEX: " + prompt.splitlines()[-1]}}))
    if mode == "fail":
        print(json.dumps({"type": "turn.failed", "error": {"message": "usage limit"}}))
        sys.exit(1)
    if mode == "write":
        open("CODEX_NEW.txt", "w").write("x\\n")
    print(json.dumps({"type": "turn.completed", "usage": {}}))
""")


class CodexSecondOpinion(AntigravitySecondOpinion):
    def setUp(self):
        super().setUp()
        fake = os.path.join(self.tmp, "codex")
        with open(fake, "w") as fh:
            fh.write(CODEX_FAKE)
        os.chmod(fake, 0o755)
        self.env["AI_REVIEW_SIMPLE_CODEX"] = fake

    def calls(self):
        with open(os.path.join(self.state, "codex-calls.jsonl")) as fh:
            return [json.loads(x) for x in fh]

    def test_named_session_resumes_conversation(self):
        r1 = self.run_tool("codex", "new", "s1", "first question")
        self.assertEqual(r1.returncode, 0, r1.stderr)
        self.assertIn("CODEX: first question", r1.stdout)
        r2 = self.run_tool("codex", "ask", "s1", "follow up")
        self.assertEqual(r2.returncode, 0, r2.stderr)
        first, second = self.calls()
        self.assertIn('sandbox_mode="read-only"', first["args"])
        self.assertEqual(second["args"][:2], ["exec", "resume"])
        self.assertIn("th_fake1", second["args"])
        self.assertFalse(any("dangerously" in a for a in first["args"] + second["args"]))

    test_implement_uses_accept_edits_and_returns_diff = None  # Antigravity-only

    def test_implement_uses_private_writable_copy(self):
        with open(os.path.join(self.state, "mode"), "w") as fh:
            fh.write("write")
        r = self.run_tool("codex", "implement", "imp1", "add file")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("CODEX_NEW.txt", r.stdout)
        self.assertFalse(os.path.exists(os.path.join(self.repo, "CODEX_NEW.txt")))
        self.assertIn('sandbox_mode="workspace-write"', self.calls()[0]["args"])

    def test_effort_defaults_low_and_refuses_high(self):
        self.assertEqual(self.run_tool("codex", "ask", "hello").returncode, 0)
        self.assertIn('model_reasoning_effort="low"', self.calls()[0]["args"])
        self.env["AI_CODEX_EFFORT"] = "high"
        self.assertEqual(self.run_tool("codex", "ask", "hello again").returncode, 2)

    def test_failed_turn_is_unavailable(self):
        with open(os.path.join(self.state, "mode"), "w") as fh:
            fh.write("fail")
        r = self.run_tool("codex", "ask", "hello")
        self.assertEqual(r.returncode, 3)

    def test_doctor_and_store_key_and_auth_error(self):
        r = self.run_tool("codex", "store-key")
        self.assertEqual(r.returncode, 0, r.stderr)
        r = self.run_tool("codex", "doctor")
        self.assertIn("doctor: OK", r.stdout)


if __name__ == "__main__":
    unittest.main()
