#!/usr/bin/env python3
"""Candidate reviewer route tests (#2549/#2550, plan_deepseek-harness-openrouter.md).

Fakes record arguments, environment and prompts; no provider is contacted.
Covers the section 9/10 gates: route registry and secret scope, plan fallback
and stop rules, exact-head attribution, second-opinion route resume, atomic
Muse failover, and read-only candidate isolation."""
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
SCRIPT = os.path.join(ROOT, "bin", "ai-review-simple")
SO = os.path.join(ROOT, "bin", "ai-second-opinion")
sys.path.insert(0, os.path.join(ROOT, "tools"))
import reviewer_routes as RR  # noqa: E402

FAKE_OC = textwrap.dedent("""\
    #!/usr/bin/env python3
    import json, os, sys, time
    state = os.environ["AI_REVIEW_SIMPLE_FAKE_STATE"]
    prompt = sys.stdin.read()
    args = sys.argv[1:]
    mode = "ok"
    mpath = os.path.join(state, "mode")
    if os.path.exists(mpath):
        lines = [ln for ln in open(mpath).read().splitlines() if ln]
        if lines:
            mode = lines[0]
            rest = lines[1:]
            open(mpath, "w").write("\\n".join(rest + (["ok"] if not rest else [])))
    watched = ("OPENROUTER_API_KEY", "MODEL_API_KEY", "DEEPSEEK_API_KEY", "ZHIPU_API_KEY",
               "STEPFUN_API_KEY", "AI_MUSE_KEY", "AI_OPENROUTER_KEY", "HOME", "USERPROFILE")
    env_seen = {k: os.environ.get(k) for k in watched if os.environ.get(k)}
    cfg = {}
    cp = os.path.join(os.environ.get("XDG_CONFIG_HOME", ""), "opencode", "opencode.json")
    if os.path.isfile(cp):
        cfg = json.load(open(cp))
    with open(os.path.join(state, "oc-calls.jsonl"), "a") as fh:
        fh.write(json.dumps({"args": args, "env": env_seen, "config": cfg,
                             "prompt_head": prompt[:400], "cwd": os.getcwd()}) + "\\n")
    def text(t):
        print(json.dumps({"type": "text", "part": {"text": t}}))
    if mode == "credit":
        print(json.dumps({"type": "error", "error": {"message": "HTTP 402 Insufficient Balance"}}))
        sys.exit(1)
    if mode == "auth":
        print(json.dumps({"type": "error", "error": {"message": "status 401 invalid api key"}}))
        sys.exit(1)
    if mode == "policy":
        print(json.dumps({"type": "error", "error": {"message": "status 403 forbidden: usage policy"}}))
        sys.exit(1)
    if mode == "outage-shared":
        print(json.dumps({"type": "error", "error": {"message": "openrouter outage: all providers failing"}}))
        sys.exit(1)
    if mode == "bearer":
        print("Authorization: Bearer " + os.environ.get("OPENROUTER_API_KEY", "none"), file=sys.stderr)
        sys.exit(1)
    if mode == "write":
        with open("NEW.txt", "w") as fh:
            fh.write("no\\n")
        text("wrote it")
        sys.exit(0)
    if mode == "sleep":
        time.sleep(30)
    sid = "--session" in args and args[args.index("--session") + 1] or "ses_" + mode
    print(json.dumps({"type": "step_start", "sessionID": sid, "part": {}}))
    text("ANSWER[" + mode + "] for: " + prompt.splitlines()[0] + "\\nVERDICT: APPROVE")
    """)

FAKE_DSH = textwrap.dedent("""\
    #!/usr/bin/env python3
    import json, os, sys, time
    state = os.environ["AI_REVIEW_SIMPLE_FAKE_STATE"]
    task = sys.stdin.read()
    args = sys.argv[1:]
    mode = "approve"
    mpath = os.path.join(state, "mode")
    if os.path.exists(mpath):
        lines = [ln for ln in open(mpath).read().splitlines() if ln]
        if lines:
            mode = lines[0]
            rest = lines[1:]
            open(mpath, "w").write("\\n".join(rest + (["approve"] if not rest else [])))
    dsh = os.environ.get("DSH_HOME", "")
    patch = ""
    pp = os.path.join(dsh, "profiles", "headless", "cordis.patch.yml")
    if os.path.isfile(pp):
        patch = open(pp).read()
    watched = ("OPENROUTER_API_KEY", "MODEL_API_KEY", "DEEPSEEK_API_KEY", "DSH_HOME", "HOME")
    env_seen = {k: os.environ.get(k) for k in watched if os.environ.get(k)}
    remote = ""
    if os.path.isdir(".git") and os.path.isdir(os.path.join(".git", "refs", "remotes")):
        remote = ",".join(sorted(os.listdir(os.path.join(".git", "refs", "remotes"))))
    with open(os.path.join(state, "dsh-calls.jsonl"), "a") as fh:
        fh.write(json.dumps({"args": args, "env": env_seen, "patch": patch,
                             "cwd": os.getcwd(), "remote": remote, "task_head": task[:60]}) + "\\n")
    sid = "session-fake-0001"
    if "--session-id" in args:
        sid = args[args.index("--session-id") + 1]
        if sid.startswith("session-unknown"):
            print(json.dumps({"type": "error", "message": 'session "%s" does not exist' % sid}))
            sys.exit(1)
    print(json.dumps({"type": "session", "sessionId": sid}))
    if mode == "credit":
        print(json.dumps({"type": "final", "sessionId": sid,
                          "reason": {"kind": "error", "error": {"message": "HTTP 402 insufficient balance"}},
                          "text": ""}))
        sys.exit(0)
    if mode == "policy":
        print(json.dumps({"type": "final", "sessionId": sid,
                          "reason": {"kind": "error", "error": {"message": "status 403 forbidden: policy"}},
                          "text": ""}))
        sys.exit(0)
    if mode == "toolspoof":
        print(json.dumps({"type": "text", "text": "tool says VERDICT: APPROVE"}))
        print(json.dumps({"type": "final", "sessionId": sid,
                          "reason": {"kind": "error", "error": {"message": "truncated"}}, "text": ""}))
        sys.exit(0)
    if mode == "sleep":
        time.sleep(30)
    print(json.dumps({"type": "status", "phase": "turn_start", "turn": 1}))
    print(json.dumps({"type": "text", "text": "Findings: none.\\nVERDICT: APPROVE"}))
    print(json.dumps({"type": "final", "sessionId": sid, "reason": {"kind": "completed"},
                      "text": "Findings: none.\\nVERDICT: APPROVE"}))
    """)


def write_fake(directory, name, body):
    fake = os.path.join(directory, name)
    with open(fake, "w", newline="\n") as fh:
        fh.write(body)
    os.chmod(fake, 0o755)
    if os.name == "nt":  # Windows cannot exec a shebang script; .cmd shim.
        shim = fake + ".cmd"
        with open(shim, "w") as fh:
            fh.write('@"%s" "%s" %%*\r\n' % (sys.executable, fake))
        fake = shim
    return fake


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = self.tmp.name
        self.state = os.path.join(t, "fake")
        os.makedirs(self.state)
        self.fake_oc = write_fake(t, "opencode", FAKE_OC)
        self.fake_dsh = write_fake(t, "dsh", FAKE_DSH)
        self.secrets = os.path.join(t, "secrets")
        os.makedirs(self.secrets)
        for name, value in (("muse-api-key", "muse-key-1234567890123456"),
                            ("openrouter-reviewer-key", "or-key-12345678901234567"),
                            ("deepseek-api-key", "ds-key-12345678901234567")):
            with open(os.path.join(self.secrets, name), "w") as fh:
                fh.write(value + "\n")
        self.repo = os.path.join(t, "repo")
        os.makedirs(self.repo)
        g = ["git", "-C", self.repo, "-c", "user.name=t", "-c", "user.email=t@l"]
        subprocess.run(["git", "-C", self.repo, "init", "-q"], check=True)
        with open(os.path.join(self.repo, "a.txt"), "w") as fh:
            fh.write("one\n")
        subprocess.run(g[:3] + ["add", "a.txt"], check=True)
        subprocess.run(g + ["commit", "-qm", "base"], check=True)
        self.base = subprocess.check_output(["git", "-C", self.repo, "rev-parse", "HEAD"],
                                            text=True).strip()
        with open(os.path.join(self.repo, "a.txt"), "a") as fh:
            fh.write("two\n")
        subprocess.run(g + ["commit", "-qam", "head"], check=True)
        self.head = subprocess.check_output(["git", "-C", self.repo, "rev-parse", "HEAD"],
                                            text=True).strip()
        self.out = os.path.join(t, "out.json")
        self.env = dict(os.environ, AI_REVIEW_SIMPLE_OPENCODE=self.fake_oc,
                        AI_REVIEW_SIMPLE_DSH=self.fake_dsh,
                        AI_REVIEW_SIMPLE_SECRETS_DIR=self.secrets,
                        AI_REVIEW_SIMPLE_FAKE_STATE=self.state,
                        PYTHONDONTWRITEBYTECODE="1",
                        AI_OPENCODE_MODELS_CACHE=os.path.join(t, "mc", "models.json"),
                        AI_OPENCODE_MODELS_URL=pathlib.Path(t, "cat.json").as_uri(),
                        AI_SECOND_OPINION_HOME=os.path.join(t, "so"))
        with open(os.path.join(t, "cat.json"), "w") as fh:
            json.dump({}, fh)
        for k in ("AI_MUSE_KEY", "AI_OPENROUTER_KEY", "DEEPSEEK_API_KEY", "ZAI_API_KEY"):
            self.env.pop(k, None)
        self.results = os.path.join(t, "results")

    def tearDown(self):
        self.tmp.cleanup()

    def mode(self, *lines):
        with open(os.path.join(self.state, "mode"), "w") as fh:
            fh.write("\n".join(lines) + "\n")

    def oc_calls(self):
        return self._calls("oc-calls.jsonl")

    def dsh_calls(self):
        return self._calls("dsh-calls.jsonl")

    def _calls(self, name):
        path = os.path.join(self.state, name)
        if not os.path.exists(path):
            return []
        with open(path) as fh:
            return [json.loads(line) for line in fh if line.strip()]

    def run_review(self, *extra, route=None, provider=None, head=None):
        cmd = [sys.executable, SCRIPT]
        if route:
            cmd += ["--route", route]
        else:
            cmd += ["--provider", provider or "muse"]
        cmd += ["--repo", self.repo, "--base", self.base, "--head", head or self.head,
                "--out", self.out, *extra]
        proc = subprocess.run(cmd, env=self.env, capture_output=True, text=True, timeout=180)
        result = None
        if os.path.exists(self.out):
            with open(self.out) as fh:
                result = json.load(fh)
        return proc, result

    def run_plan(self, plan):
        proc = subprocess.run(
            [sys.executable, SCRIPT, "--run-plan", " ".join(plan), "--repo", self.repo,
             "--base", self.base, "--head", self.head, "--results-dir", self.results],
            env=self.env, capture_output=True, text=True, timeout=300)
        return proc

    def plan_results(self):
        out = {}
        for name in sorted(os.listdir(self.results)):
            if name == "order":
                continue
            with open(os.path.join(self.results, name)) as fh:
                out[name[:-5]] = json.load(fh)
        return out


class RegistryTests(Base):
    def test_registry_enumerates_four_routes_and_rejects_unknown(self):
        self.assertEqual(sorted(RR.routes()), sorted(RR.EXPECTED_ROUTES))
        with self.assertRaises(RR.RouteError):
            RR.route("bogus-route")
        proc, _ = self.run_review(route="bogus-route")
        self.assertEqual(proc.returncode, 2)

    def test_candidate_plan_expands_rotation_and_keeps_default(self):
        self.assertEqual(RR.candidate_plan(["muse", "glm", "deepseek", "stepfun"]),
                         ["muse-meta", "muse-openrouter", "glm", "deepseek-openrouter",
                          "stepfun", "hy4-openrouter"])
        proc = subprocess.run([sys.executable, SCRIPT, "--rotation", "3"], env=self.env,
                              capture_output=True, text=True)
        self.assertEqual(proc.stdout.split(), ["stepfun", "muse", "glm", "deepseek"])

    def test_classification_order(self):
        self.assertEqual(RR.classify("HTTP 403 forbidden"), ("terminal", "policy"))
        self.assertEqual(RR.classify("Error: status 402 insufficient balance"), ("advance", "credit"))
        self.assertEqual(RR.classify("status 401 invalid api key"), ("advance", "auth"))
        self.assertEqual(RR.classify("openrouter outage: all providers failing"),
                         ("advance", "shared-outage"))
        self.assertEqual(RR.classify("connection reset by peer"), ("advance", "transport"))
        self.assertEqual(RR.classify("read-only file system"), ("terminal", "readonly"))


class SecretScopeTests(Base):
    def test_route_scopes_credentials_and_ignores_ambient(self):
        self.env["AI_MUSE_KEY"] = "ambient-muse-key-9999999"
        self.env["DEEPSEEK_API_KEY"] = "ambient-deepseek-key"
        self.mode("ok")
        proc, result = self.run_review(route="muse-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(result["provider"], "muse-openrouter")
        self.assertEqual(result["route"], "muse-openrouter")
        self.assertEqual(result["engine"], "opencode")
        call = self.oc_calls()[0]
        env = call["env"]
        self.assertEqual(env.get("OPENROUTER_API_KEY"), "or-key-12345678901234567")
        for banned in ("MODEL_API_KEY", "DEEPSEEK_API_KEY", "ZHIPU_API_KEY",
                       "STEPFUN_API_KEY", "AI_MUSE_KEY"):
            self.assertNotIn(banned, env, f"{banned} leaked into the candidate run")
        cfg = call["config"]
        self.assertEqual(sorted(cfg.get("provider", {})), ["openrouter-muse"])

    def test_harness_route_env_and_private_profile(self):
        self.mode("approve")
        proc, result = self.run_review(route="deepseek-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual((result["engine"], result["route"]), ("deepseek-harness", "deepseek-openrouter"))
        call = self.dsh_calls()[0]
        self.assertEqual(call["env"].get("OPENROUTER_API_KEY"), "or-key-12345678901234567")
        self.assertNotIn("DEEPSEEK_API_KEY", call["env"])
        self.assertNotIn("MODEL_API_KEY", call["env"])
        self.assertIn("baseURL: https://openrouter.ai/api/v1", call["patch"])
        self.assertIn("id: \"deepseek/deepseek-v4.1-flash-1017\"", call["patch"])
        self.assertEqual(call["remote"], "")  # workspace has no git remote
        self.assertIn("--json", call["args"])
        self.assertEqual(call["args"][call["args"].index("--permission-mode") + 1],
                         "read-only")

    def test_candidate_agent_config_is_read_only(self):
        self.mode("ok")
        proc, _ = self.run_review(route="muse-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        call = self.oc_calls()[0]
        self.assertEqual(call["config"]["model"], "openrouter-muse/meta/muse-spark-1.3-contributor")
        self.assertEqual(call["config"]["share"], "disabled")
        # The workspace agent markdown is the only read-only enforcement OpenCode
        # honors; prove it directly from a fresh workspace build.
        import importlib.machinery, importlib.util, tempfile as tf
        loader = importlib.machinery.SourceFileLoader("ars_test", SCRIPT)
        spec = importlib.util.spec_from_loader("ars_test", loader)
        ars = importlib.util.module_from_spec(spec)
        loader.exec_module(ars)
        with tf.TemporaryDirectory() as wtmp:
            work, _home = ars.make_workspace(self.repo, self.head, "muse", wtmp,
                                             spec=ars.spec_for("muse", "muse-openrouter"))
            agent = open(os.path.join(wtmp, "xdg", "config", "opencode", "agent",
                                      "simple-review.md")).read()
            for tool in ("write:", "edit:", "patch:", "bash:"):
                self.assertIn(f"{tool} false", agent)
            ars._force_rmtree(wtmp)


class FailureTests(Base):
    def test_credit_is_unavailable(self):
        self.mode("credit")
        proc, result = self.run_review(route="deepseek-openrouter")
        self.assertEqual(proc.returncode, 3)
        self.assertEqual(result["error"], "out-of-credit")

    def test_policy_refusal_is_terminal_exit_2(self):
        self.mode("policy")
        proc, result = self.run_review(route="deepseek-openrouter")
        self.assertEqual(proc.returncode, 2)
        self.assertTrue(result["error"].startswith("refused"))

    def test_tool_event_verdict_never_counts(self):
        self.mode("toolspoof", "toolspoof")
        proc, result = self.run_review(route="deepseek-openrouter")
        self.assertEqual((proc.returncode, result["verdict"]), (3, None))

    def test_failure_text_is_redacted(self):
        self.mode("bearer", "bearer")
        proc, result = self.run_review(route="muse-openrouter")
        self.assertEqual(proc.returncode, 3)
        self.assertNotIn("or-key-12345678901234567", json.dumps(result))

    def test_head_mismatch_refused_with_route(self):
        self.mode("approve")
        proc, result = self.run_review(route="muse-openrouter", head=self.base)
        self.assertEqual(proc.returncode, 2)
        self.assertIn("head mismatch", result["error"])
        self.assertEqual(len(self.oc_calls()), 0)


class RunPlanTests(Base):
    def test_meta_failure_falls_through_to_openrouter_and_stops(self):
        self.mode("credit", "ok")
        proc = self.run_plan(["muse-meta", "muse-openrouter", "hy4-openrouter"])
        self.assertEqual(proc.returncode, 0, proc.stderr)
        results = self.plan_results()
        self.assertEqual(results["muse-meta"]["error"], "out-of-credit")
        self.assertEqual(results["muse-openrouter"]["verdict"], "APPROVE")
        self.assertNotIn("hy4-openrouter", results)
        with open(os.path.join(self.results, "order")) as fh:
            self.assertEqual(fh.read().split(), ["muse-meta", "muse-openrouter"])

    def test_forced_exhaustion_reaches_hy4(self):
        self.mode("credit", "credit", "ok")
        self.run_plan(["muse-meta", "muse-openrouter", "hy4-openrouter"])
        results = self.plan_results()
        self.assertEqual(results["hy4-openrouter"]["verdict"], "APPROVE")

    def test_shared_outage_skips_remaining_openrouter_routes(self):
        self.mode("outage-shared", "outage-shared")
        self.run_plan(["muse-openrouter", "deepseek-openrouter", "hy4-openrouter"])
        results = self.plan_results()
        self.assertIn("skipped: shared OpenRouter outage",
                      results["deepseek-openrouter"]["error"])
        self.assertIn("skipped: shared OpenRouter outage", results["hy4-openrouter"]["error"])
        self.assertEqual(len(self.oc_calls()), 2)  # the failed route retried once, then the plan skipped

    def test_terminal_refusal_stops_the_plan(self):
        self.mode("policy", "ok")
        self.run_plan(["muse-meta", "muse-openrouter"])
        results = self.plan_results()
        self.assertEqual(len(results), 1)
        self.assertTrue(results["muse-meta"]["error"].startswith("refused"))


class AttributionTests(Base):
    def load_ars(self):
        import importlib.machinery, importlib.util
        loader = importlib.machinery.SourceFileLoader("ars_attr", SCRIPT)
        spec = importlib.util.spec_from_loader("ars_attr", loader)
        ars = importlib.util.module_from_spec(spec)
        loader.exec_module(ars)
        return ars

    def test_route_attribution_and_spoof_rejection(self):
        ars = self.load_ars()
        good = {"provider": "muse-openrouter", "route": "muse-openrouter", "engine": "opencode",
                "head": self.head, "verdict": "APPROVE", "findings": "", "elapsed": 1}
        spoof = {"provider": "muse-openrouter", "route": "muse-meta", "engine": "opencode",
                 "head": self.head, "verdict": "REJECT", "findings": "x", "elapsed": 1}
        summary = ars.combine([good, spoof], self.head, routes=set(RR.routes()))
        self.assertEqual(summary["state"], "pass")
        good_row = [r for r in summary["rows"] if r.get("route") == "muse-openrouter"][0]
        self.assertEqual(good_row["verdict"], "APPROVE")
        spoofed_row = [r for r in summary["rows"] if r.get("route") == "muse-meta"][0]
        self.assertEqual(spoofed_row["verdict"], "unavailable")
        self.assertEqual(spoofed_row["error"], "unverified route attribution")
        comment = ars.render_comment(summary, self.head)
        self.assertIn("Route", comment)
        self.assertIn("muse-openrouter", comment)

    def test_default_comment_shape_unchanged_without_routes(self):
        ars = self.load_ars()
        row = {"provider": "muse", "head": self.head, "verdict": "APPROVE",
               "findings": "", "elapsed": 2}
        summary = ars.combine([row], self.head)
        self.assertEqual(summary["state"], "pass")
        self.assertNotIn("Route", ars.render_comment(summary, self.head))


class SecondOpinionRouteTests(Base):
    def run_so(self, *args, **kw):
        env = kw.get("env", self.env)
        env.setdefault("AI_SECOND_OPINION_TIMEOUT", "60")
        return subprocess.run([sys.executable, SO, *args], cwd=self.repo, env=env,
                              capture_output=True, text=True, timeout=180)

    def so_dir(self, provider, name):
        return os.path.join(self.env["AI_SECOND_OPINION_HOME"], provider, name)

    def meta(self, provider, name):
        with open(os.path.join(self.so_dir(provider, name), "meta.json")) as fh:
            return json.load(fh)

    def test_explicit_route_session_resumes_and_is_sticky(self):
        self.mode("ok")
        r = self.run_so("muse", "--route", "muse-openrouter", "new", "s1", "first question")
        self.assertEqual(r.returncode, 0, r.stderr)
        m = self.meta("muse", "s1")
        self.assertEqual(m["route"], "muse-openrouter")
        self.assertTrue(m["session"])
        r2 = self.run_so("muse", "--route", "muse-openrouter", "ask", "s1", "follow up")
        self.assertEqual(r2.returncode, 0, r2.stderr)
        self.assertIn("--session", self.oc_calls()[-1]["args"])
        r3 = self.run_so("muse", "--route", "muse-meta", "ask", "s1", "wrong route")
        self.assertEqual(r3.returncode, 2)
        self.assertIn("bound to route", r3.stderr)

    def test_auto_failover_is_atomic(self):
        self.mode("ok", "credit", "ok")
        r = self.run_so("muse", "--route", "auto", "new", "fa", "question one")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.meta("muse", "fa")["route"], "muse-meta")
        r2 = self.run_so("muse", "--route", "auto", "ask", "fa", "second question")
        self.assertEqual(r2.returncode, 0, r2.stderr)
        m = self.meta("muse", "fa")
        self.assertEqual(m["route"], "muse-openrouter")
        self.assertEqual(m["turns"], 2)
        self.assertEqual(len(m["visible"]), 2)
        transcript = open(os.path.join(self.so_dir("muse", "fa"), "transcript.md")).read()
        self.assertIn("route failover: muse-meta -> muse-openrouter", transcript)
        calls = self.oc_calls()
        self.assertEqual(calls[0]["args"][calls[0]["args"].index("--model") + 1],
                         "meta-model-api/muse-spark-1.3-contributor")
        self.assertEqual(calls[2]["args"][calls[2]["args"].index("--model") + 1],
                         "openrouter-muse/meta/muse-spark-1.3-contributor")
        self.assertNotIn("--session", calls[2]["args"])
        self.assertEqual(sorted(calls[2]["config"].get("provider", {})), ["openrouter-muse"])
        self.assertIn("Prior conversation", calls[2]["prompt_head"])
        self.assertIn("question one", calls[2]["prompt_head"])
        self.assertIn("second question", calls[2]["prompt_head"])

    def test_failing_fallback_keeps_last_good(self):
        self.mode("ok", "credit", "credit")
        r = self.run_so("muse", "--route", "auto", "new", "fb", "question one")
        self.assertEqual(r.returncode, 0, r.stderr)
        r2 = self.run_so("muse", "--route", "auto", "ask", "fb", "second question")
        self.assertEqual(r2.returncode, 3)
        m = self.meta("muse", "fb")
        self.assertEqual(m["route"], "muse-meta")
        self.assertEqual(m["turns"], 1)
        self.assertIn("last-good session retained", r2.stderr)

    def test_concurrent_turn_is_rejected(self):
        self.mode("ok")
        r = self.run_so("muse", "--route", "muse-meta", "new", "cc", "hi")
        self.assertEqual(r.returncode, 0, r.stderr)
        os.makedirs(os.path.join(self.so_dir("muse", "cc"), ".lock"))
        env = dict(self.env, AI_SECOND_OPINION_LOCK_WAIT="1")
        r2 = self.run_so("muse", "--route", "muse-meta", "ask", "cc", "again", env=env)
        self.assertEqual(r2.returncode, 1)
        self.assertIn("busy", r2.stderr)

    def test_deepseek_route_uses_harness_with_native_resume(self):
        self.mode("approve")
        r = self.run_so("deepseek", "--route", "deepseek-openrouter", "new", "ds1", "hello")
        self.assertEqual(r.returncode, 0, r.stderr)
        m = self.meta("deepseek", "ds1")
        self.assertEqual(m["route"], "deepseek-openrouter")
        self.assertEqual(m["session"], "session-fake-0001")
        self.mode("approve")
        r2 = self.run_so("deepseek", "--route", "deepseek-openrouter", "ask", "ds1", "again")
        self.assertEqual(r2.returncode, 0, r2.stderr)
        args = self.dsh_calls()[-1]["args"]
        self.assertIn("--session-id", args)

    def test_harness_resume_failure_keeps_session(self):
        self.mode("approve")
        self.run_so("deepseek", "--route", "deepseek-openrouter", "new", "ds2", "hello")
        m = self.meta("deepseek", "ds2")
        m["session"] = "session-unknown-9"
        with open(os.path.join(self.so_dir("deepseek", "ds2"), "meta.json"), "w") as fh:
            json.dump(m, fh)
        self.mode("approve")
        r = self.run_so("deepseek", "--route", "deepseek-openrouter", "ask", "ds2", "again")
        self.assertEqual(r.returncode, 3)
        self.assertEqual(self.meta("deepseek", "ds2")["session"], "session-unknown-9")

    def test_implement_rejects_route(self):
        self.mode("ok")
        r = self.run_so("muse", "--route", "muse-meta", "implement", "x1", "do it")
        self.assertEqual(r.returncode, 2)
        self.assertIn("read-only", r.stderr)

    def test_start_copy_failure_reports_cleanly(self):
        import subprocess as sp
        empty = os.path.join(self.tmp.name, "not-a-repo")
        os.makedirs(empty)
        r = sp.run([sys.executable, SO, "muse", "--route", "muse-meta", "new", "bx",
                    "--repo", empty, "hello"], env=self.env, capture_output=True,
                   text=True, timeout=60)
        self.assertEqual(r.returncode, 1)
        self.assertIn("could not copy the repository", r.stderr)
        self.assertNotIn("Traceback", r.stderr)

    def test_route_shaped_provider_entry_selects_itself(self):
        self.mode("ok")
        r = self.run_so("hy4-openrouter", "new", "hp", "hello there")
        self.assertEqual(r.returncode, 0, r.stderr)
        m = self.meta("hy4-openrouter", "hp")
        self.assertEqual(m["route"], "hy4-openrouter")
        self.assertEqual(self.oc_calls()[0]["args"][self.oc_calls()[0]["args"].index("--model") + 1],
                         "openrouter-hy4/tencent/hy4")

    def test_legacy_session_defaults_unchanged(self):
        self.mode("ok")
        r = self.run_so("muse", "new", "lg", "plain question")
        self.assertEqual(r.returncode, 0, r.stderr)
        m = self.meta("muse", "lg")
        self.assertNotIn("route", m)
        self.assertNotIn("visible", m)




FAKE_AGENT_DSH = textwrap.dedent("""\
    #!/usr/bin/env python3
    import json, os, sys
    task = sys.stdin.read()
    args = sys.argv[1:]
    sid = "session-agent-0001"
    if "--session-id" in args:
        sid = args[args.index("--session-id") + 1]
        if sid.startswith("session-unknown"):
            print(json.dumps({"type": "error", "message": 'session "%s" does not exist' % sid}))
            sys.exit(1)
    log = os.environ.get("AGENT_DSH_LOG")
    if log:
        patch = ""
        pp = os.path.join(os.environ.get("DSH_HOME", ""), "profiles", "headless", "cordis.patch.yml")
        if os.path.isfile(pp):
            patch = open(pp).read()
        with open(log, "a") as fh:
            fh.write(json.dumps({"args": args, "cwd": os.getcwd(),
                                 "has_or_key": bool(os.environ.get("OPENROUTER_API_KEY")),
                                 "has_ds_key": bool(os.environ.get("DEEPSEEK_API_KEY")),
                                 "patch": patch}) + "\\n")
    reply = "DEEPSEEK_REVIEWER_HEALTHY" if "DEEPSEEK_REVIEWER_HEALTHY" in task \
        else "Findings: none.\\nVERDICT: APPROVE"
    print(json.dumps({"type": "session", "sessionId": sid}))
    print(json.dumps({"type": "final", "sessionId": sid, "reason": {"kind": "completed"},
                      "text": reply}))
    """)

OP_STUB = """#!/usr/bin/env bash
while [ "$#" -gt 0 ]; do
  case "$1" in
    --env-file) shift 2;;
    --) shift; DEEPSEEK_API_KEY=fixture-from-op exec "$@";;
    *) shift;;
  esac
done
"""


class DeepseekAgentHarnessTests(Base):
    """The opt-in DeepSeek Harness engine in bin/ai-deepseek-agent (#2549).

    A full private fixture: fake 1Password CLI, protected direct and OpenRouter
    key stores, and a fake pinned dsh. The direct engine is untouched."""

    def setUp(self):
        super().setUp()
        t = self.tmp.name
        self.fx = os.path.join(t, "fx")
        for d in ("bin", os.path.join("home", ".config", "ai-devops"), "repo", "events"):
            os.makedirs(os.path.join(self.fx, d))
        with open(os.path.join(self.fx, "home", ".config", "ai-devops",
                               "op-service-account"), "w") as fh:
            fh.write("placeholder-token\n")
        with open(os.path.join(self.fx, "home", ".config", "ai-devops", "mcp.env"), "w") as fh:
            fh.write("DEEPSEEK_API_KEY=op://example\n")
        op = os.path.join(self.fx, "bin", "op")
        with open(op, "w", newline="\n") as fh:
            fh.write(OP_STUB)
        os.chmod(op, 0o755)
        py = os.path.join(self.fx, "bin", "python")
        if os.name == "nt":
            shutil.copy(sys.executable, py + ".exe")
        else:
            os.symlink(sys.executable, py)
        self.fake_agent_dsh = write_fake(self.fx, "dsh-bin", FAKE_AGENT_DSH)
        self.repo = os.path.join(self.fx, "repo")
        g = ["git", "-C", self.repo, "-c", "user.name=t", "-c", "user.email=t@l"]
        subprocess.run(["git", "-C", self.repo, "init", "-q"], check=True)
        with open(os.path.join(self.repo, ".git", "info", "exclude"), "a") as fh:
            fh.write(".ai/\n")
        with open(os.path.join(self.repo, "tracked.txt"), "w") as fh:
            fh.write("x\n")
        subprocess.run(g[:3] + ["add", "tracked.txt"], check=True)
        subprocess.run(g + ["commit", "-qm", "init"], check=True)
        self.dsh_log = os.path.join(self.fx, "dsh-log.jsonl")
        test_dir, home_dir, path_sep = self.fx, os.path.join(self.fx, "home"), os.pathsep
        if os.name == "nt":  # Git Bash fixtures use POSIX-style paths and separators
            test_dir = subprocess.run(["cygpath", "-u", self.fx], capture_output=True,
                                      text=True, check=True).stdout.strip()
            home_dir = subprocess.run(["cygpath", "-u", os.path.join(self.fx, "home")],
                                      capture_output=True, text=True, check=True).stdout.strip()
            path_sep = ":" if ":" in os.environ.get("PATH", "") else os.pathsep
        self.agent_env = dict(os.environ, HOME=home_dir,
                              USERPROFILE=os.path.join(self.fx, "home"),
                              PATH=(test_dir + "/bin" + path_sep + os.environ.get("PATH", "")),
                              AI_DEEPSEEK_TEST_DIR=test_dir,
                              AI_REVIEW_EVENT_DIR=os.path.join(self.fx, "events"),
                              AI_REVIEW_SIMPLE_DSH=self.fake_agent_dsh,
                              AGENT_DSH_LOG=self.dsh_log,
                              AI_DEEPSEEK_HARNESS_TIMEOUT="60",
                              PYTHONDONTWRITEBYTECODE="1")
        for k in ("DEEPSEEK_API_KEY", "AI_MUSE_KEY", "AI_OPENROUTER_KEY"):
            self.agent_env.pop(k, None)
        # The direct store is populated through the script's own protected flow.
        subprocess.run(["bash", os.path.join(ROOT, "bin", "ai-deepseek-agent"), "store-key"],
                       env=self.agent_env, cwd=self.repo, capture_output=True, timeout=120)
        self.or_store = os.path.join(self.fx, "home", ".config", "ai-devops", "secrets",
                                     "openrouter-reviewer-key")

    def protect_or_store(self):
        os.makedirs(os.path.dirname(self.or_store), exist_ok=True)
        with open(self.or_store, "w") as fh:
            fh.write("or-agent-key-123456789012345\n")
        if os.name == "nt":
            helper = os.path.join(ROOT, "bin", "windows-private-file.ps1")
            subprocess.run(["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass",
                            "-Command", ". '%s'; Protect-AiDevOpsPrivatePath -Path '%s'"
                            % (helper, self.or_store)], check=True, capture_output=True)
        else:
            os.chmod(os.path.dirname(self.or_store), 0o700)
            os.chmod(self.or_store, 0o600)

    def agent(self, *args):
        return subprocess.run(["bash", os.path.join(ROOT, "bin", "ai-deepseek-agent"), *args],
                              env=self.agent_env, cwd=self.repo, capture_output=True,
                              text=True, timeout=180)

    def dsh_log_rows(self):
        if not os.path.exists(self.dsh_log):
            return []
        with open(self.dsh_log) as fh:
            return [json.loads(line) for line in fh if line.strip()]

    def test_harness_send_reply_and_show(self):
        self.protect_or_store()
        r = self.agent("send", "--route", "deepseek-openrouter", "hello there")
        self.assertEqual(r.returncode, 0, r.stderr)
        sid_line = [ln for ln in r.stdout.splitlines() if ln.startswith("SESSION_ID:")]
        self.assertTrue(sid_line, r.stdout + r.stderr)
        session_id = sid_line[0].split(":", 1)[1].strip()
        sess_path = os.path.join(self.repo, ".ai", "deepseek-sessions", session_id + ".json")
        value = json.load(open(sess_path))
        self.assertEqual(value["engine"], "deepseek-harness")
        self.assertEqual(value["harness_session"], "session-agent-0001")
        self.assertEqual(len(value["turns"]), 2)
        rows = self.dsh_log_rows()
        self.assertTrue(rows[0]["has_or_key"])
        self.assertFalse(rows[0]["has_ds_key"])
        self.assertIn("deepseek/deepseek-v4.1-flash-1017", rows[0]["patch"])
        self.assertIn("read-only", rows[0]["args"])
        r2 = self.agent("show", session_id)
        self.assertEqual(r2.returncode, 0, r2.stderr)
        self.assertIn("HARNESS deepseek-openrouter", r2.stdout)
        r3 = self.agent("reply", session_id, "--route", "deepseek-openrouter", "second turn")
        self.assertEqual(r3.returncode, 0, r3.stderr)
        rows = self.dsh_log_rows()
        self.assertIn("--session-id", rows[-1]["args"])
        value = json.load(open(sess_path))
        self.assertEqual(len(value["turns"]), 4)

    def test_harness_doctor_live_route(self):
        self.protect_or_store()
        r = self.agent("doctor", "--live", "--route", "deepseek-openrouter")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("live provider response (deepseek-openrouter)", r.stdout)

    def test_missing_or_store_refuses(self):
        r = self.agent("send", "--route", "deepseek-openrouter", "hello")
        self.assertEqual(r.returncode, 1)
        self.assertIn("openrouter reviewer key store is missing", r.stderr)

    def test_route_refuses_review_combination(self):
        self.protect_or_store()
        r = self.agent("send", "--route", "deepseek-openrouter", "--review", "hello")
        self.assertEqual(r.returncode, 2)
        self.assertIn("cannot be combined", r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
