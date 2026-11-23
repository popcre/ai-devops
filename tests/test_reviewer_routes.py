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

from bash_resolution import resolve_bash

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
               "STEPFUN_API_KEY", "AI_MUSE_KEY", "AI_OPENROUTER_KEY", "HOME", "USERPROFILE",
               "SYSTEMROOT", "TEMP", "WINDIR")
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
        print(json.dumps({"type": "step_finish", "part": {"reason": "error"}}))
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
    if mode == "truncated":
        text("PARTIAL ANSWER")
        print(json.dumps({"type": "step_finish", "part": {"reason": "length"}}))
        sys.exit(0)
    if mode == "paid-failure":
        for _ in range(2):
            print(json.dumps({"type": "step_start", "part": {}}))
        print(json.dumps({"type": "step_finish", "part": {"cost": 0.015, "tokens": {
            "input": 42, "cache": {"read": 0}}}}))
        sys.exit(1)
    if mode == "cachefinish":
        print(json.dumps({"type": "step_start", "sessionID": "ses_c", "part": {}}))
        text("Findings: none.\\nVERDICT: APPROVE")
        print(json.dumps({"type": "step_finish", "part": {"reason": "stop", "tokens": {
            "total": 10, "input": 8, "output": 2, "cache": {"write": 5, "read": 100}}}}))
        sys.exit(0)
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
    if mode == "usage":
        print(json.dumps({"type": "status", "phase": "step_start", "turn": 1, "step": 1}))
        print(json.dumps({"type": "status", "phase": "step_end", "turn": 1, "step": 1,
                          "usage": {"inputTokens": 500, "outputTokens": 25, "totalTokens": 525}}))
        print(json.dumps({"type": "status", "phase": "step_start", "turn": 1, "step": 2}))
        print(json.dumps({"type": "status", "phase": "step_end", "turn": 1, "step": 2,
                          "usage": {"inputTokens": 20, "outputTokens": 15, "cacheReadTokens": 480,
                                    "cacheWriteTokens": 0, "reasoningTokens": 10, "totalTokens": 515}}))
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
        self.assertEqual(proc.stdout.split(), ["stepfun", "antigravity", "muse", "glm", "deepseek"])

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

    def test_windows_required_env_reaches_opencode(self):
        # 2026-11-17 crash repair: without SYSTEMROOT the pinned OpenCode binary
        # fail-fasts (0xC0000409) on Windows before any output. The review path
        # must pass the same qualified Windows vars through as second opinions.
        self.mode("ok")
        self.env["SYSTEMROOT"] = "C:\\Windows"
        self.env["WINDIR"] = "C:\\Windows"
        self.env["TEMP"] = os.path.join(self.tmp.name, "warm")
        proc, _ = self.run_review(route="muse-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        env = self.oc_calls()[0]["env"]
        self.assertEqual(env.get("SYSTEMROOT"), "C:\\Windows")
        self.assertEqual(env.get("WINDIR"), "C:\\Windows")
        self.assertTrue(env.get("TEMP", "").endswith("warm"))


class FailureTests(Base):
    def test_missing_harness_is_unavailable_with_unknown_cache(self):
        # Force resolver absence without depending on the machine's installed runtime.
        import importlib.machinery, importlib.util
        from unittest import mock
        loader = importlib.machinery.SourceFileLoader("ars_no_harness", SCRIPT)
        spec = importlib.util.spec_from_loader("ars_no_harness", loader)
        ars = importlib.util.module_from_spec(spec)
        loader.exec_module(ars)
        with mock.patch.object(ars.RR, "resolve_deepseek_harness", return_value=None):
            verdict, text, error, cache = ars.run_harness_once({}, "review", self.repo,
                                                             self.tmp.name, "fixture-key", 1)
        self.assertEqual((verdict, text, cache), (None, "", None))
        self.assertTrue(error.startswith("local:"))

    def test_harness_timeout_returns_unavailable_instead_of_crashing(self):
        self.env["AI_REVIEW_CACHE"] = "1"
        self.mode("sleep")
        proc, result = self.run_review("--timeout", "1", route="deepseek-openrouter")
        self.assertEqual(proc.returncode, 3, proc.stderr)
        self.assertEqual(result["error"], "timeout after 1s")
        self.assertEqual(result["cache"], {"read": None, "write": None})
        self.assertEqual(len(self.dsh_calls()), 1)

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

    def test_harness_duplicate_terminal_response_does_not_qualify(self):
        ars = self.load_ars()
        completed = json.dumps({"type": "final", "reason": {"kind": "completed"},
                                "text": "VERDICT: APPROVE"})
        for extra in (completed, json.dumps({"type": "final", "reason": {"kind": "error"}})):
            with self.subTest(extra=extra):
                answer, error = ars.read_harness_events(completed + "\n" + extra)
                self.assertEqual(answer, "")
                self.assertTrue(error)


class SecondOpinionRouteTests(Base):
    def setUp(self):
        super().setUp()
        home = pathlib.Path(self.tmp.name, "user-home")
        self.muse_default = home / ".config" / "ai-devops" / "muse-second-opinion-default"
        self.muse_default.parent.mkdir(parents=True)
        self.env.update(HOME=str(home), USERPROFILE=str(home))

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

    def test_truncated_answer_preserves_last_good_visible_history(self):
        self.mode("ok", "truncated")
        args = ("muse", "--route", "muse-openrouter")
        first = self.run_so(*args, "new", "truncated-case", "first question")
        self.assertEqual(first.returncode, 0, first.stderr)
        before = self.meta("muse", "truncated-case")
        transcript = os.path.join(self.so_dir("muse", "truncated-case"), "transcript.md")
        with open(transcript, encoding="utf-8") as fh:
            prior_text = fh.read()
        second = self.run_so(*args, "ask", "truncated-case", "next question")
        self.assertEqual(second.returncode, 3)
        self.assertIn("incomplete answer: length", second.stderr)
        after = self.meta("muse", "truncated-case")
        for field in ("turns", "visible", "session", "route"):
            self.assertEqual(after[field], before[field])
        with open(transcript, encoding="utf-8") as fh:
            self.assertEqual(fh.read(), prior_text)

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
        self.assertEqual([turn["q"] for turn in m["visible"]],
                         ["question one", "second question"])
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

    def test_deepseek_default_and_rollback_preserve_conversation_routes(self):
        self.mode("approve")
        result = self.run_so("deepseek", "new", "ds-default", "hello")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.meta("deepseek", "ds-default")["route"], "deepseek-openrouter")
        setting = self.muse_default.with_name("deepseek-second-opinion-default")
        setting.write_text("legacy\n")
        legacy = self.run_so("deepseek", "new", "ds-legacy", "hello")
        self.assertEqual(legacy.returncode, 0, legacy.stderr)
        self.assertNotIn("route", self.meta("deepseek", "ds-legacy"))
        resumed = self.run_so("deepseek", "ask", "ds-default", "again")
        self.assertEqual(resumed.returncode, 0, resumed.stderr)
        self.assertIn("--session-id", self.dsh_calls()[-1]["args"])
        setting.unlink()
        resumed_legacy = self.run_so("deepseek", "ask", "ds-legacy", "again")
        self.assertEqual(resumed_legacy.returncode, 0, resumed_legacy.stderr)
        self.assertNotIn("route", self.meta("deepseek", "ds-legacy"))

    def test_invalid_deepseek_default_refuses_before_contact(self):
        setting = self.muse_default.with_name("deepseek-second-opinion-default")
        setting.write_text("bad value")
        result = self.run_so("deepseek", "new", "ds-invalid", "hello")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("invalid DeepSeek default", result.stderr)
        self.assertEqual(self.dsh_calls(), [])

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

    def test_new_muse_session_defaults_to_candidate_route(self):
        # Activation (#2531, 2026-11-17): a new Muse conversation without
        # --route runs the candidate route (auto = muse-meta with same-model
        # OpenRouter failover), and later turns stay on it.
        self.mode("ok")
        r = self.run_so("muse", "new", "nd", "plain question")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.meta("muse", "nd")["route"], "muse-meta")
        r2 = self.run_so("muse", "ask", "nd", "follow up")
        self.assertEqual(r2.returncode, 0, r2.stderr)
        self.assertEqual(self.meta("muse", "nd")["route"], "muse-meta")
        self.assertIn("--session", self.oc_calls()[-1]["args"])

    def test_default_muse_continuation_keeps_automatic_failover(self):
        self.mode("ok", "auth", "ok")
        first = self.run_so("muse", "new", "default-failover", "first question")
        self.assertEqual(first.returncode, 0, first.stderr)
        resumed = self.run_so("muse", "ask", "default-failover", "second question")
        self.assertEqual(resumed.returncode, 0, resumed.stderr)
        self.assertEqual(self.meta("muse", "default-failover")["route"], "muse-openrouter")

    def test_muse_legacy_default_applies_only_to_new_implicit_sessions(self):
        self.mode("credit", "ok", "ok", "ok")
        self.muse_default.write_bytes(b"legacy\r\n")
        failed = self.run_so("muse", "new", "legacy", "first question")
        self.assertEqual(failed.returncode, 3, failed.stderr)
        self.assertEqual(len(self.oc_calls()), 1)
        self.assertNotIn("route", self.meta("muse", "legacy"))
        self.assertEqual(set(self.oc_calls()[0]["config"]["provider"]), {"meta-model-api"})

        self.muse_default.write_bytes(b"bad value")
        invalid = self.run_so("muse", "ask", "one-shot question")
        self.assertEqual(invalid.returncode, 2, invalid.stderr)
        self.assertIn("invalid Muse default", invalid.stderr)
        self.assertEqual(len(self.oc_calls()), 1)
        explicit = self.run_so("muse", "--route", "muse-openrouter", "new", "routed",
                               "explicit question")
        self.assertEqual(explicit.returncode, 0, explicit.stderr)
        self.assertEqual(self.meta("muse", "routed")["route"], "muse-openrouter")
        resumed = self.run_so("muse", "ask", "legacy", "follow up")
        self.assertEqual(resumed.returncode, 0, resumed.stderr)
        self.assertNotIn("route", self.meta("muse", "legacy"))
        implementation = self.run_so("muse", "implement", "implementation", "write request")
        self.assertEqual(implementation.returncode, 0, implementation.stderr)
        self.assertEqual(self.meta("muse", "implementation")["mode"], "implement")

    def test_muse_unreadable_default_fails_before_creating_a_session(self):
        self.muse_default.mkdir()
        result = self.run_so("muse", "new", "unreadable", "plain question")
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertIn("cannot read the Muse default", result.stderr)
        self.assertFalse(os.path.exists(self.so_dir("muse", "unreadable")))
        self.assertFalse(os.path.exists(os.path.join(self.state, "oc-calls.jsonl")))

    def test_legacy_routeless_session_stays_legacy(self):
        # A conversation created before the activation (meta without a route)
        # keeps the legacy provider on later turns; the default only applies
        # to new conversations.
        self.mode("ok")
        r = self.run_so("muse", "new", "lg", "plain question")
        self.assertEqual(r.returncode, 0, r.stderr)
        mp = os.path.join(self.so_dir("muse", "lg"), "meta.json")
        with open(mp) as fh:
            m = json.load(fh)
        m.pop("route", None)
        m.pop("auto_route", None)
        m.pop("visible", None)
        with open(mp, "w") as fh:
            json.dump(m, fh)
        r2 = self.run_so("muse", "ask", "lg", "follow up")
        self.assertEqual(r2.returncode, 0, r2.stderr)
        m2 = self.meta("muse", "lg")
        self.assertNotIn("route", m2)
        self.assertNotIn("visible", m2)


class WorkflowDefaultTests(Base):
    WF = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                      ".github", "workflows", "ai-review.yml")

    def test_default_rotation_expands_into_candidate_plan(self):
        # Activation (#2531, 2026-11-17): with no explicit candidate_routes
        # input, the workflow computes the candidate expansion itself; the
        # legacy per-provider loop is gone and reverting restores it.
        with open(self.WF, encoding="utf-8") as fh:
            wf = fh.read()
        self.assertIn('if [ -z "$candidate_routes" ]; then', wf)
        self.assertIn('python3 "$script" --candidate-plan "$PR"', wf)
        self.assertNotIn('python3 "$script" --rotation "$PR"', wf)
        self.assertIn('AI_REVIEW_CANDIDATE_ROUTES', wf)
        # the #2584 stray-brace guard: no GitHub expression inside a bash ${:-}
        self.assertNotIn(':-${{', wf)
        self.assertIn('candidate_routes="${AI_REVIEW_CANDIDATE_ROUTES:-$candidate_routes}"', wf)




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
            fh.write(json.dumps({"args": args, "cwd": os.getcwd(), "task": task,
                                 "tracked": open("tracked.txt").read() if os.path.exists("tracked.txt") else None,
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
        self.bash, _ = resolve_bash()
        self.assertIsNotNone(self.bash, "the DeepSeek fixture needs Bash")
        test_dir, home_dir = self.fx, os.path.join(self.fx, "home")
        if os.name == "nt":  # The wrapper consumes Git Bash paths for these two settings.
            test_dir = subprocess.run(["cygpath", "-u", self.fx], capture_output=True,
                                      text=True, check=True).stdout.strip()
            home_dir = subprocess.run(["cygpath", "-u", os.path.join(self.fx, "home")],
                                      capture_output=True, text=True, check=True).stdout.strip()
        self.agent_env = dict(os.environ, HOME=home_dir,
                              USERPROFILE=os.path.join(self.fx, "home"),
                              PATH=os.pathsep.join((os.path.join(self.fx, "bin"), os.environ.get("PATH", ""))),
                              AI_DEEPSEEK_TEST_DIR=test_dir,
                              AI_REVIEW_EVENT_DIR=os.path.join(self.fx, "events"),
                              AI_REVIEW_SIMPLE_DSH=self.fake_agent_dsh,
                              AGENT_DSH_LOG=self.dsh_log,
                              AI_DEEPSEEK_HARNESS_TIMEOUT="60",
                              PYTHONDONTWRITEBYTECODE="1")
        for k in ("DEEPSEEK_API_KEY", "AI_MUSE_KEY", "AI_OPENROUTER_KEY"):
            self.agent_env.pop(k, None)
        # The direct store is populated through the script's own protected flow.
        stored = self.agent("store-key")
        self.assertEqual(stored.returncode, 0, stored.stdout + stored.stderr)
        self.or_store = os.path.join(self.fx, "home", ".config", "ai-devops", "secrets",
                                     "openrouter-reviewer-key")

    def protect_or_store(self):
        os.makedirs(os.path.dirname(self.or_store), exist_ok=True)
        with open(self.or_store, "w") as fh:
            fh.write("or-agent-key-123456789012345\n")
        if os.name == "nt":
            helper = os.path.join(ROOT, "bin", "windows-private-file.ps1")
            protected = subprocess.run(["powershell.exe", "-NoProfile", "-ExecutionPolicy", "Bypass",
                                        "-Command", ". '%s'; Protect-AiDevOpsPrivatePath -Path '%s'"
                                        % (helper, self.or_store)], capture_output=True, text=True)
            self.assertEqual(protected.returncode, 0, protected.stdout + protected.stderr)
        else:
            os.chmod(os.path.dirname(self.or_store), 0o700)
            os.chmod(self.or_store, 0o600)

    def agent(self, *args):
        return subprocess.run([self.bash, os.path.join(ROOT, "bin", "ai-deepseek-agent"), *args],
                              env=self.agent_env, cwd=self.repo, capture_output=True,
                              text=True, timeout=180)

    def dsh_log_rows(self):
        if not os.path.exists(self.dsh_log):
            return []
        with open(self.dsh_log) as fh:
            return [json.loads(line) for line in fh if line.strip()]

    def test_harness_send_reply_and_show(self):
        self.protect_or_store()
        identifier = "bill-" + "f" * 32
        self.agent_env.update(AI_REVIEW_USAGE="1", AI_REVIEW_BILLING_ID=identifier)
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
        self.assertIn(f'x-session-id: "{identifier}"', rows[0]["patch"])
        r2 = self.agent("show", session_id)
        self.assertEqual(r2.returncode, 0, r2.stderr)
        self.assertIn("HARNESS deepseek-openrouter", r2.stdout)
        r3 = self.agent("reply", session_id, "--route", "deepseek-openrouter", "second turn")
        self.assertEqual(r3.returncode, 0, r3.stderr)
        rows = self.dsh_log_rows()
        self.assertIn("--session-id", rows[-1]["args"])
        self.assertIn(f'x-session-id: "{identifier}"', rows[-1]["patch"])
        value = json.load(open(sess_path))
        self.assertEqual(len(value["turns"]), 4)
        usage_path = pathlib.Path(sess_path).with_suffix(".dsh-home") / "usage.jsonl"
        receipts = [json.loads(line) for line in usage_path.read_text().splitlines()]
        self.assertEqual([row["outcome"] for row in receipts], ["answer", "answer"])

    def test_harness_doctor_live_route(self):
        self.protect_or_store()
        r = self.agent("doctor", "--live", "--route", "deepseek-openrouter")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("live provider response (deepseek-openrouter)", r.stdout)

    def test_harness_is_default_and_resumes_without_route_flag(self):
        self.protect_or_store()
        pathlib.Path(self.or_store).with_name("deepseek-api-key").unlink()
        result = self.agent("send", "hello there")
        self.assertEqual(result.returncode, 0, result.stderr)
        session_id = next(line.split(":", 1)[1].strip() for line in result.stdout.splitlines()
                          if line.startswith("SESSION_ID:"))
        setting = pathlib.Path(self.or_store).parent.parent / "deepseek-second-opinion-default"
        setting.write_text("legacy\n")
        pathlib.Path(self.repo, "tracked.txt").write_text("updated source\n")
        home = pathlib.Path(self.repo, ".ai", "deepseek-sessions", session_id + ".dsh-home")
        interrupted = home / "deepseek-turn.workspace"
        interrupted.mkdir()
        (interrupted / "recover.txt").write_text("interrupted fixture\n")
        resumed = self.agent("reply", session_id, "second turn")
        self.assertEqual(resumed.returncode, 0, resumed.stderr)
        self.assertIn("--session-id", self.dsh_log_rows()[-1]["args"])
        for row in self.dsh_log_rows():
            self.assertTrue(row["cwd"].replace("\\", "/").endswith(
                ".dsh-home/deepseek-turn.workspace/repo"), row["cwd"])
            self.assertFalse(pathlib.Path(row["cwd"]).exists())
        self.assertEqual(self.dsh_log_rows()[-1]["tracked"], "updated source\n")
        retained = list(home.glob("interrupted-workspace.*/snapshot/recover.txt"))
        self.assertEqual(len(retained), 1)
        self.assertEqual(retained[0].read_text(), "interrupted fixture\n")

    def test_missing_or_store_refuses(self):
        r = self.agent("send", "--route", "deepseek-openrouter", "hello")
        self.assertEqual(r.returncode, 1)
        self.assertIn("openrouter reviewer key store is missing", r.stderr)

    def test_older_harness_conversation_replays_visible_history_once(self):
        self.protect_or_store()
        first = self.agent("send", "remember the public fixture marker")
        self.assertEqual(first.returncode, 0, first.stderr)
        session_id = next(line.split(":", 1)[1].strip() for line in first.stdout.splitlines()
                          if line.startswith("SESSION_ID:"))
        path = pathlib.Path(self.repo, ".ai", "deepseek-sessions", session_id + ".json")
        value = json.loads(path.read_text())
        value.pop("workspace_mode")
        path.write_text(json.dumps(value))
        shutil.rmtree(path.with_suffix(".dsh-home"))
        resumed = self.agent("reply", session_id, "continue the discussion")
        self.assertEqual(resumed.returncode, 0, resumed.stderr)
        row = self.dsh_log_rows()[-1]
        self.assertNotIn("--session-id", row["args"])
        self.assertIn("remember the public fixture marker", row["task"])
        self.assertIn("continue the discussion", row["task"])
        migrated = json.loads(path.read_text())
        self.assertEqual(migrated["workspace_mode"], "stable-per-session")
        self.assertEqual(len(migrated["turns"]), 4)

    def test_route_refuses_review_combination(self):
        self.protect_or_store()
        r = self.agent("send", "--route", "deepseek-openrouter", "--review", "hello")
        self.assertEqual(r.returncode, 2)
        self.assertIn("cannot be combined", r.stderr)


class CacheReceiptTests(unittest.TestCase):
    """Usage is external input: absent or invalid counters are not zeroes."""

    @classmethod
    def setUpClass(cls):
        import importlib.machinery, importlib.util
        loader = importlib.machinery.SourceFileLoader("ars_receipts", SCRIPT)
        spec = importlib.util.spec_from_loader("ars_receipts", loader)
        cls.ars = importlib.util.module_from_spec(spec)
        loader.exec_module(cls.ars)

    def receipts(self, *parts):
        return self.ars.cache_receipts("\n".join(
            json.dumps({"type": "step_finish", "part": part}) for part in parts))

    def test_missing_cache_counters_remain_unknown(self):
        for part in (None, {}, {"reason": "stop"}, {"tokens": {}},
                     {"tokens": {"cache": {}}}, {"tokens": {"cache": None}},
                     {"tokens": {"cache": {"read": None, "write": None}}}):
            with self.subTest(part=part):
                self.assertEqual(self.receipts(part), {"read": None, "write": None})

    def test_cache_counters_are_independent_and_preserve_zero(self):
        for counters, expected in (
                ({"read": 0, "write": 0}, {"read": 0, "write": 0}),
                ({"read": 0}, {"read": 0, "write": None}),
                ({"write": 5}, {"read": None, "write": 5})):
            with self.subTest(counters=counters):
                self.assertEqual(self.receipts({"tokens": {"cache": counters}}), expected)

    def test_invalid_cache_counters_and_shapes_are_ignored(self):
        for part in ([], "invalid", {"tokens": []}, {"tokens": "invalid"},
                     {"tokens": {"cache": []}}, {"tokens": {"cache": "invalid"}}):
            with self.subTest(part=part):
                self.assertEqual(self.receipts(part), {"read": None, "write": None})
        for value in (-1, True, False, 1.5, "10", [], {}):
            with self.subTest(value=value):
                self.assertEqual(self.receipts({"tokens": {"cache": {
                    "read": value, "write": value}}}), {"read": None, "write": None})

    def test_only_reported_cache_counters_are_summed(self):
        self.assertEqual(self.receipts(
            {"tokens": {"cache": {"read": 100, "write": 5}}},
            {"reason": "stop"},
            {"tokens": {"cache": {"read": 0}}},
            {"tokens": {"cache": {"read": 25, "write": 0}}}),
            {"read": 125, "write": 5})

    def test_unrelated_or_malformed_events_do_not_invent_usage(self):
        self.assertEqual(self.ars.cache_receipts(
            'not json\n{broken\n[]\n{"type":"text","part":{"tokens":'
            '{"cache":{"read":99,"write":99}}}}'), {"read": None, "write": None})


class CacheQualificationTests(SecondOpinionRouteTests):
    """Phase C (#2551): opt-in cache identifiers, prompt order and receipts."""

    @classmethod
    def setUpClass(cls):
        import importlib.machinery, importlib.util
        loader = importlib.machinery.SourceFileLoader("ars_qualification", SCRIPT)
        spec = importlib.util.spec_from_loader(loader.name, loader)
        cls.ars = importlib.util.module_from_spec(spec)
        loader.exec_module(cls.ars)

    def openrouter_options(self, call):
        provider = call["config"]["provider"]["openrouter-muse"]
        return provider["models"]["meta/muse-spark-1.3-contributor"].get("options", {})

    def test_usage_coverage_and_failed_attempt_costs(self):
        self.env["AI_REVIEW_USAGE"] = "1"
        self.mode("paid-failure", "cachefinish")
        proc, result = self.run_review(route="muse-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        failed, succeeded = result["usage_attempts"]
        self.assertEqual((failed["outcome"], succeeded["outcome"]), ("failed", "verdict"))
        self.assertEqual((failed["step_starts"], failed["step_finishes"]), (2, 1))
        self.assertEqual(failed["adapter_counters"]["input_uncached"],
                         {"subtotal": 42, "reported_steps": 1})
        self.assertEqual(failed["adapter_counters"]["cache_read"]["subtotal"], 0)
        self.assertIsNone(failed["adapter_counters"]["cache_write"]["subtotal"])
        self.assertEqual(failed["adapter_cost_estimate_usd"],
                         {"subtotal": 0.015, "reported_steps": 1})
        for attempt in (failed, succeeded):
            self.assertIsNone(attempt["billed_cost_usd"])
            self.assertIsNone(attempt["provider_request_count"])
        self.env.pop("AI_REVIEW_USAGE")
        self.mode("cachefinish")
        proc, result = self.run_review(route="muse-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertNotIn("usage_attempts", result)

    def test_usage_observes_top_level_session_and_rejects_conflicting_duplicates(self):
        from reviewer_usage import reviewer_attempt
        first = {"type": "step_finish", "sessionID": "fixture",
                 "part": {"messageID": "reply", "id": "part", "tokens": {"input": 10}}}
        second = {"type": "step_finish", "sessionID": "fixture",
                  "part": {"messageID": "reply", "id": "second", "tokens": {"input": 3}}}
        conflict = {**first, "part": {**first["part"], "tokens": {"input": 99}}}
        receipt = reviewer_attempt(
            "\n".join(json.dumps(event) for event in (first, first, second, conflict)),
            route="muse-openrouter", model="fixture", engine="opencode",
            outcome="failed", elapsed=1, billing_id="bill-" + "f" * 32,
        )
        self.assertEqual(receipt["step_finishes"], 2)
        self.assertEqual(receipt["adapter_counters"]["input_uncached"],
                         {"subtotal": 3, "reported_steps": 1})
        self.assertEqual(len(receipt["billing_fingerprint"]), 64)
        self.assertNotIn("bill-", json.dumps(receipt))

    def test_usage_records_both_failover_attempts_without_conversation_text(self):
        self.env["AI_REVIEW_USAGE"] = "1"
        self.mode("ok", "credit", "cachefinish")
        first = self.run_so("muse", "--route", "auto", "new", "billing", "private marker")
        self.assertEqual(first.returncode, 0, first.stderr)
        second = self.run_so("muse", "--route", "auto", "ask", "billing", "follow up")
        self.assertEqual(second.returncode, 0, second.stderr)
        path = os.path.join(self.so_dir("muse", "billing"), "usage.jsonl")
        with open(path, encoding="utf-8") as fh:
            raw = fh.read()
        self.assertNotIn("private marker", raw)
        self.assertNotIn("follow up", raw)
        receipts = [json.loads(line) for line in raw.splitlines()]
        self.assertEqual([(r["route"], r["outcome"]) for r in receipts],
                         [("muse-meta", "answer"), ("muse-meta", "failed"),
                          ("muse-openrouter", "answer")])

    def test_muse_cache_key_scope_and_stability(self):
        self.env["AI_REVIEW_CACHE"] = "1"
        self.mode("ok")
        proc, result = self.run_review(route="muse-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        cfg = self.openrouter_options(self.oc_calls()[0])
        key = cfg["prompt_cache_key"]
        session = cfg["session_id"]
        self.assertTrue(key.startswith("aidv1-"))
        self.assertTrue(session.startswith("aidv1-s-"))
        self.assertLessEqual(len(key), 256)
        self.assertNotIn("or-key", key + session)  # never credential-derived
        self.assertIn("cache", result)
        # stable across a second identical review; the session id follows the head
        self.mode("ok")
        self.run_review(route="muse-openrouter")
        cfg2 = self.openrouter_options(self.oc_calls()[1])
        self.assertEqual(cfg2["prompt_cache_key"], key)
        self.assertEqual(cfg2["session_id"], session)
        # a different namespace isolates the shared key
        self.env["AI_REVIEW_CACHE_NAMESPACE"] = "other"
        self.mode("ok")
        self.run_review(route="muse-openrouter")
        cfg3 = self.openrouter_options(self.oc_calls()[2])
        self.assertNotEqual(cfg3["prompt_cache_key"], key)
        del self.env["AI_REVIEW_CACHE_NAMESPACE"]

    def test_meta_gets_cache_key_without_openrouter_session_header(self):
        self.env["AI_REVIEW_CACHE"] = "1"
        self.mode("ok")
        proc, _ = self.run_review(route="muse-meta")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        cfg = self.oc_calls()[0]["config"]["provider"]["meta-model-api"]
        options = cfg["models"]["muse-spark-1.3-contributor"]["options"]
        self.assertTrue(options["promptCacheKey"].startswith("aidv1-"))
        self.assertNotIn("session_id", options)
        self.assertNotIn("headers", cfg)

    def test_muse_cache_on_by_default_and_disableable(self):
        self.env.pop("AI_REVIEW_CACHE", None)
        self.mode("ok")
        proc, result = self.run_review(route="muse-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        options = self.openrouter_options(self.oc_calls()[0])
        self.assertTrue(options["prompt_cache_key"].startswith("aidv1-"))
        self.assertTrue(options["session_id"].startswith("aidv1-s-"))
        self.assertIn("cache", result)

        self.mode("ok")
        proc, result = self.run_review(route="muse-meta")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        meta_cfg = self.oc_calls()[1]["config"]["provider"]["meta-model-api"]
        meta_opts = meta_cfg["models"]["muse-spark-1.3-contributor"].get("options", {})
        self.assertTrue(meta_opts["promptCacheKey"].startswith("aidv1-"))
        self.assertNotIn("session_id", meta_opts)
        self.assertNotIn("headers", meta_cfg)
        self.assertIn("cache", result)

        self.env["AI_REVIEW_CACHE"] = "0"
        self.mode("ok")
        proc, result = self.run_review(route="muse-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        cfg = self.oc_calls()[2]["config"]["provider"]["openrouter-muse"]
        self.assertEqual(self.openrouter_options(self.oc_calls()[2]), {})
        self.assertNotIn("body", cfg)
        self.assertNotIn("headers", cfg)
        self.assertNotIn("cache", result)

        self.mode("ok")
        proc, result = self.run_review(route="muse-meta")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        meta_cfg2 = self.oc_calls()[3]["config"]["provider"]["meta-model-api"]
        self.assertNotIn("options", meta_cfg2["models"]["muse-spark-1.3-contributor"])
        self.assertNotIn("cache", result)

    def test_non_muse_routes_keep_cache_off_by_default(self):
        self.env.pop("AI_REVIEW_CACHE", None)
        self.mode("approve")
        proc, result = self.run_review(route="deepseek-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        patch = self.dsh_calls()[0]["patch"]
        self.assertNotIn("x-session-id", patch)
        self.assertNotIn("prompt_cache_key", patch)
        self.assertNotIn("cache", result)

        self.mode("ok")
        proc, result = self.run_review(route="hy4-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        model = self.oc_calls()[0]["config"]["provider"]["openrouter-hy4"]["models"]["tencent/hy4"]
        self.assertNotIn("options", model)
        self.assertNotIn("cache", result)

    def test_non_muse_routes_use_affinity_without_muse_cache_keys(self):
        self.env["AI_REVIEW_CACHE"] = "1"
        self.mode("approve")
        proc, _ = self.run_review(route="deepseek-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        patch = self.dsh_calls()[0]["patch"]
        self.assertIn("openrouter", patch)  # prove we inspected the actual profile
        self.assertNotIn("prompt_cache_key", patch)
        self.assertIn('x-session-id: "aidv1-s-', patch)
        self.mode("ok")
        proc, _ = self.run_review(route="hy4-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        model = self.oc_calls()[0]["config"]["provider"]["openrouter-hy4"]["models"]["tencent/hy4"]
        self.assertNotIn("prompt_cache_key", model["options"])
        self.assertTrue(model["options"]["session_id"].startswith("aidv1-s-"))

    def test_affinity_scope_separates_repositories_routes_and_sessions(self):
        from unittest.mock import patch
        with patch.dict(os.environ, {"AI_REVIEW_CACHE": "1", "GITHUB_REPOSITORY": "public/repo"}):
            first = RR.cache_affinity_id("hy4-openrouter", self.repo, self.head)
            self.assertEqual(first, RR.cache_affinity_id("hy4-openrouter", self.tmp.name, self.head))
            self.assertNotEqual(first, RR.cache_affinity_id("deepseek-openrouter", self.repo, self.head))
            self.assertNotEqual(first, RR.cache_affinity_id("hy4-openrouter", self.repo, self.base))
            with patch.dict(os.environ, {"GITHUB_REPOSITORY": "public/other"}):
                self.assertNotEqual(first, RR.cache_affinity_id("hy4-openrouter", self.repo, self.head))

    def test_openrouter_billing_session_supports_hy4_and_deepseek(self):
        identifier = "bill-" + "c" * 32
        self.env.update(AI_REVIEW_USAGE="1", AI_REVIEW_BILLING_ID=identifier)
        self.mode("cachefinish")
        proc, result = self.run_review(route="hy4-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        model = self.oc_calls()[0]["config"]["provider"]["openrouter-hy4"]["models"]["tencent/hy4"]
        self.assertEqual(model["options"], {"session_id": identifier})
        self.assertNotIn(identifier, json.dumps(result))

        self.mode("approve")
        proc, result = self.run_review(route="deepseek-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn(f'x-session-id: "{identifier}"', self.dsh_calls()[0]["patch"])
        self.assertNotIn(identifier, json.dumps(result))

    def test_hy4_billing_session_survives_restart(self):
        identifier = "bill-" + "d" * 32
        self.env.update(AI_REVIEW_USAGE="1", AI_REVIEW_BILLING_ID=identifier)
        first = self.run_so("hy4-openrouter", "new", "usage-hy4", "remember this")
        self.assertEqual(first.returncode, 0, first.stderr)
        del self.env["AI_REVIEW_BILLING_ID"]
        second = self.run_so("hy4-openrouter", "ask", "usage-hy4", "recall it")
        self.assertEqual(second.returncode, 0, second.stderr)
        for call in self.oc_calls():
            model = call["config"]["provider"]["openrouter-hy4"]["models"]["tencent/hy4"]
            self.assertEqual(model["options"], {"session_id": identifier})
        self.env["AI_REVIEW_BILLING_ID"] = "bill-" + "e" * 32
        changed = self.run_so("hy4-openrouter", "ask", "usage-hy4", "recall it")
        self.assertEqual(changed.returncode, 2)
        self.assertEqual(len(self.oc_calls()), 2)

    def test_lean_prompt_preserves_review_contract(self):
        prompt = self.ars.build_prompt(self.repo, self.base, self.head, "lean")
        self.assertIn("+two", prompt)
        for required in (self.base, self.head, "read-only", "file, line, and impact",
                         "VERDICT: APPROVE", "VERDICT: REJECT", "VERDICT: REVISE"):
            self.assertIn(required, prompt)

    def test_lean_requires_template_scope_section(self):
        from unittest.mock import patch
        broken = pathlib.Path(self.tmp.name, "wrong-template.md")
        broken.write_text("No scope heading", encoding="utf-8")
        with patch.object(self.ars, "TEMPLATE", broken):
            with self.assertRaisesRegex(RR.RouteError, "missing its scope section"):
                self.ars.build_prompt(self.repo, self.base, self.head, "lean")

    def test_review_refuses_candidate_without_inline_patch(self):
        self.env["AI_REVIEW_PROMPT_VARIANT"] = "file-map"
        proc, result = self.run_review(route="muse-openrouter")
        self.assertEqual(proc.returncode, 2)
        self.assertIn("unknown reviewer prompt variant", result["error"])
        self.assertEqual(self.oc_calls(), [])

    def test_concise_report_preserves_findings_and_verdict(self):
        original = self.ars.build_prompt(self.repo, self.base, self.head)
        concise = self.ars.build_prompt(self.repo, self.base, self.head, "concise")
        self.assertTrue(concise.endswith(original))
        self.assertIn("Include every material finding", concise)
        self.assertIn("file and line, defect, and impact", concise)

    def test_cache_prefix_puts_fixed_instructions_before_variable_ids(self):
        prompt = self.ars.build_prompt(self.repo, self.base, self.head)
        fixed = prompt.index("Do not report style preferences.")
        head_at = prompt.index(self.head)
        base_at = prompt.index(self.base)
        self.assertLess(fixed, head_at)
        self.assertLess(fixed, base_at)

    def test_cache_usage_receipts_distinguish_missing_from_zero(self):
        self.env["AI_REVIEW_CACHE"] = "1"
        self.mode("cachefinish")
        proc, result = self.run_review(route="muse-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(result["cache"], {"read": 100, "write": 5})
        self.mode("ok")
        proc, result = self.run_review(route="muse-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        # no token events at all: the measurement is missing, not a zero hit
        self.assertEqual(result["cache"], {"read": None, "write": None})
        import json as _json
        zero = _json.dumps({"type": "step_finish", "part": {"tokens": {
            "cache": {"read": 0, "write": 0}}}})
        import importlib.machinery, importlib.util
        _ld = importlib.machinery.SourceFileLoader("ars_z", SCRIPT)
        _sp = importlib.util.spec_from_loader("ars_z", _ld)
        _m = importlib.util.module_from_spec(_sp)
        _ld.exec_module(_m)
        self.assertEqual(_m.cache_receipts(zero), {"read": 0, "write": 0})

    def test_second_opinion_cache_fields_stable_across_resume(self):
        self.env["AI_REVIEW_CACHE"] = "1"
        self.mode("ok")
        r = self.run_so("muse", "--route", "muse-openrouter", "new", "cs", "hello")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.mode("ok")
        r2 = self.run_so("muse", "--route", "muse-openrouter", "ask", "cs", "again")
        self.assertEqual(r2.returncode, 0, r2.stderr)
        cfgs = [self.openrouter_options(call) for call in self.oc_calls()]
        self.assertEqual(cfgs[0]["prompt_cache_key"], cfgs[1]["prompt_cache_key"])
        self.assertEqual(cfgs[0]["session_id"], cfgs[1]["session_id"])

    def test_second_opinion_muse_auto_wires_cache_from_turn_one_and_failover(self):
        self.env.pop("AI_REVIEW_CACHE", None)
        self.mode("ok", "ok", "credit", "ok")
        r1 = self.run_so("muse", "new", "auto-cache", "first")
        self.assertEqual(r1.returncode, 0, r1.stderr)
        r2 = self.run_so("muse", "ask", "auto-cache", "second")
        self.assertEqual(r2.returncode, 0, r2.stderr)
        r3 = self.run_so("muse", "ask", "auto-cache", "third")
        self.assertEqual(r3.returncode, 0, r3.stderr)
        calls = self.oc_calls()
        turn1_opts = calls[0]["config"]["provider"]["meta-model-api"]["models"][
            "muse-spark-1.3-contributor"].get("options", {})
        turn2_opts = calls[1]["config"]["provider"]["meta-model-api"]["models"][
            "muse-spark-1.3-contributor"].get("options", {})
        self.assertTrue(turn1_opts.get("promptCacheKey", "").startswith("aidv1-"))
        self.assertEqual(turn2_opts.get("promptCacheKey"), turn1_opts["promptCacheKey"])
        self.assertIn("--session", calls[1]["args"])
        failover_opts = self.openrouter_options(calls[3])
        self.assertTrue(failover_opts["prompt_cache_key"].startswith("aidv1-"))
        self.assertTrue(failover_opts["session_id"].startswith("aidv1-s-"))

        self.env["AI_REVIEW_CACHE"] = "0"
        self.mode("ok")
        r4 = self.run_so("muse", "new", "auto-nocache", "first")
        self.assertEqual(r4.returncode, 0, r4.stderr)
        nocache_model = self.oc_calls()[4]["config"]["provider"]["meta-model-api"]["models"][
            "muse-spark-1.3-contributor"]
        self.assertNotIn("options", nocache_model)

    def test_harness_disables_session_title_llm(self):
        patch = RR.harness_patch_yaml(RR.route("deepseek-openrouter"))
        self.assertIn("- id: session-title-llm\n  disabled: true\n", patch)

    def test_harness_usage_and_cache_receipts_distinguish_missing_from_zero(self):
        from reviewer_usage import reviewer_attempt

        lines = [
            json.dumps({"type": "status", "phase": "step_start", "turn": 1, "step": 1}),
            json.dumps({"type": "status", "phase": "step_end", "turn": 1, "step": 1,
                        "usage": {"inputTokens": 100, "outputTokens": 10}}),
            json.dumps({"type": "status", "phase": "step_start", "turn": 1, "step": 2}),
            json.dumps({"type": "status", "phase": "step_end", "turn": 1, "step": 2,
                        "usage": {"inputTokens": 12, "outputTokens": 8, "cacheReadTokens": 90,
                                  "cacheWriteTokens": 0, "reasoningTokens": True}}),
            json.dumps({"type": "status", "phase": "step_end", "turn": 1, "step": 3,
                        "usage": {"cacheReadTokens": -1, "cacheWriteTokens": False}}),
        ]
        stdout = "\n".join(lines)
        self.assertEqual(self.ars.harness_cache_receipts(stdout), {"read": 90, "write": 0})
        self.assertEqual(self.ars.harness_cache_receipts("not json\n{}"), {"read": None, "write": None})

        receipt = reviewer_attempt(stdout, route="deepseek-openrouter",
                                   model="deepseek/deepseek-v4.1-flash-1017",
                                   engine="deepseek-harness", outcome="verdict", elapsed=1.5)
        self.assertEqual(receipt["step_starts"], 2)
        self.assertEqual(receipt["step_finishes"], 3)
        self.assertEqual(receipt["adapter_counters"]["input_uncached"], {"subtotal": 112, "reported_steps": 2})
        self.assertEqual(receipt["adapter_counters"]["output_visible"], {"subtotal": 18, "reported_steps": 2})
        self.assertEqual(receipt["adapter_counters"]["cache_read"], {"subtotal": 90, "reported_steps": 1})
        self.assertEqual(receipt["adapter_counters"]["cache_write"], {"subtotal": 0, "reported_steps": 1})
        self.assertEqual(receipt["adapter_counters"]["reasoning"], {"subtotal": None, "reported_steps": 0})

        self.env.update(AI_REVIEW_USAGE="1", AI_REVIEW_CACHE="1")
        self.mode("usage")
        proc, result = self.run_review(route="deepseek-openrouter")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(result["cache"], {"read": 480, "write": 0})
        attempt = result["usage_attempts"][0]
        self.assertEqual((attempt["step_starts"], attempt["step_finishes"]), (2, 2))
        self.assertEqual(attempt["adapter_counters"]["input_uncached"], {"subtotal": 520, "reported_steps": 2})
        self.assertEqual(attempt["adapter_counters"]["cache_read"], {"subtotal": 480, "reported_steps": 1})
        self.assertEqual(attempt["adapter_counters"]["reasoning"], {"subtotal": 10, "reported_steps": 1})

    def test_opencode_deepseek_context_limits_match_model_capacity(self):
        cfg_path = os.path.join(ROOT, "config", "opencode-deepseek", "opencode.json")
        with open(cfg_path, encoding="utf-8") as fh:
            models = json.load(fh)["provider"]["deepseek-api"]["models"]
        for model_id in ("deepseek-flash", "deepseek-v4-pro"):
            self.assertEqual(models[model_id]["limit"], {"context": 1048576, "output": 65536})
        legacy = self.ars.PROVIDERS["deepseek"]["provider"]["deepseek-api"]["models"]["deepseek-flash"]
        self.assertEqual(legacy["limit"], {"context": 1048576, "output": 65536})


if __name__ == "__main__":
    unittest.main(verbosity=2)
