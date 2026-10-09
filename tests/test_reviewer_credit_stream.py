"""Offline parser, incremental-cost and owned-tree credit-stop proof."""
import importlib.machinery
import importlib.util
import json
import datetime
import os
from pathlib import Path
import signal
import uuid
import shlex
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from reviewer_credit_stream import LIMIT, Monitor, Reader, error_payload, refusal, qwen_monthly_reset


class CreditStreamTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.out, self.err, self.marker = (self.base / n for n in ("out", "err", "marker"))
        self.out.touch(); self.err.touch()

    def tearDown(self):
        self.tmp.cleanup()

    def test_provider_fixtures(self):
        fixtures = {"grok": "grok-xai-403.stderr", "muse": "muse-insufficient-quota.jsonl",
                    "qwen": "qwen-arrearage.jsonl", "gemini": "gemini-prepay.json",
                    "deepseek": "deepseek-402.json", "stepfun": "stepfun-402.txt"}
        for provider, filename in fixtures.items():
            with self.subTest(provider=provider):
                path = ROOT / "tests/fixtures/reviewer-credit" / filename
                self.assertIsNotNone(Reader(str(path), provider == "grok").read(provider))

    def test_glm_subscription_error(self):
        self.assertEqual(refusal("glm", {"code": "1310", "message": "Limit Exhausted"})["failure_class"], "allowance-exhausted")

    def test_adversarial_assistant_and_tools(self):
        for provider in ("grok", "muse", "qwen", "gemini", "deepseek", "stepfun", "glm"):
            for kind in ("assistant", "text", "tool_use", "tool_result", "user"):
                row = {"type": kind, "error": {"message": "out of credits"},
                       "result": "[API Error: out of credits]", "message": {"content": "Insufficient Balance"}}
                self.assertIsNone(error_payload(provider, row), (provider, kind))
            self.assertIsNone(error_payload(provider, {"type": "result", "result": "The code says out of credits"}))

    def test_muse_terminal_text_and_gemini_response_ignored(self):
        self.assertIsNone(refusal("muse", error_payload("muse", {"payload_type": "run.terminal.failed", "payload": {"terminal": "failed", "text": "insufficient_quota"}})))
        self.assertIsNone(refusal("gemini", error_payload("gemini", {"status": "ERROR", "response": "out of credits", "error": {"code": "INTERNAL"}})))
        for kind in ("run.tool.failed", "run.tool.error", "unknown.failed"):
            self.assertIsNone(error_payload("muse", {"payload_type": kind, "payload": {"error": {"message": "out of credits"}}}))

    def test_ordinary_rate_limit_not_credit(self):
        for provider in ("grok", "muse", "qwen", "gemini", "deepseek", "stepfun", "glm"):
            self.assertIsNone(refusal(provider, "429 Too Many Requests: rate limit exceeded; retry after20s"))
            self.assertIsNone(refusal(provider, "RESOURCE_EXHAUSTED"))

    def test_partial_then_complete(self):
        self.out.write_bytes(b'{"type":"error","error":{"message":"out of')
        reader = Reader(str(self.out), False)
        self.assertIsNone(reader.read("muse"))
        with self.out.open("ab") as out: out.write(b' credits"}}\n')
        self.assertEqual(reader.read("muse")["failure_class"], "out-of-credit")
        self.assertEqual(reader.bytes_read, self.out.stat().st_size)

    def test_no_reread_or_subprocess_for_healthy_output(self):
        line = json.dumps({"type": "text", "part": {"text": "healthy" * 10}}).encode() + b"\n"
        self.out.write_bytes(line * 500)
        reader = Reader(str(self.out), False)
        start = time.perf_counter()
        for _ in range(100): self.assertIsNone(reader.read("deepseek"))
        elapsed = time.perf_counter() - start
        self.assertEqual(reader.bytes_read, self.out.stat().st_size)
        self.assertLess(elapsed, .25)
        print(f"healthy scanner: bytes={reader.bytes_read} checks=100 elapsed_ms={elapsed*1000:.2f}")

    def test_read_bound_and_oversized_line(self):
        self.out.write_bytes(b"x" * (LIMIT * 3) + b'\n{"type":"error","error":{"message":"out of credits"}}\n')
        reader = Reader(str(self.out), False)
        self.assertIsNone(reader.read("muse")); self.assertEqual(reader.bytes_read, LIMIT)
        self.assertIsNone(reader.read("muse")); self.assertIsNone(reader.read("muse"))
        self.assertIsNotNone(reader.read("muse"))
        self.assertLessEqual(len(reader.pending), LIMIT)

    def test_deeply_nested_json_is_malformed_not_supervisor_failure(self):
        self.out.write_text('[' * 3000 + '0' + ']' * 3000 + '\n')
        self.assertIsNone(Reader(str(self.out), False).read("muse"))

    def test_truncated_and_replaced_file(self):
        reader = Reader(str(self.out), False)
        self.out.write_text("ordinary\n" * 20); self.assertIsNone(reader.read("muse"))
        self.out.write_text('{"type":"error","error":{"message":"out of credits"}}\n')
        self.assertIsNotNone(reader.read("muse"))
        self.out.unlink(); self.out.write_text("ordinary\n")
        self.assertIsNone(reader.read("muse"))

    def test_explicit_reset_only_and_safe_marker(self):
        value = refusal("glm", {"code": "1310", "message": "Limit Exhausted SECRET123",
                               "reset_at": "2026-11-01T16:00:00Z", "retry_after": 20})
        self.assertEqual(value["provider_reset_at"], "2026-11-01T16:00:00Z")
        self.assertNotIn("reset_at", value) # Error-schema fields are informational until qualified.
        self.assertNotIn("SECRET123", json.dumps(value))
        self.assertNotIn("reset_at", refusal("glm", {"code": "1310", "message": "Limit Exhausted", "retry_after": 20}))

    def test_provider_subscription_reset_message_is_preserved(self):
        value = refusal("qwen", "Quota exhausted: Your token-plan 1-month quota has been exhausted. The quota will reset at 11-01 16:00:00 UTC.")
        self.assertEqual(value["failure_class"], "allowance-exhausted")
        self.assertEqual(value["provider_quota_reset_at"], "11-01 16:00:00 UTC")
        # Actual month/day dates are bounded against the current monthly window.

    def test_qwen_typed_monthly_reset_bounds(self):
        def message(date): return f"Quota exhausted: Your token-plan 1-month quota has been exhausted. The quota will reset at {date} UTC."
        utc = datetime.timezone.utc
        self.assertEqual(qwen_monthly_reset(message("01-01 16:00:00"), datetime.datetime(2026,12,31,tzinfo=utc)), "2027-01-01T16:00:00Z")
        self.assertEqual(qwen_monthly_reset("[API Error: " + message("01-01 16:00:00") + "]", datetime.datetime(2026,12,31,tzinfo=utc)), "2027-01-01T16:00:00Z")
        self.assertEqual(qwen_monthly_reset(message("02-29 16:00:00"), datetime.datetime(2028,2,1,tzinfo=utc)), "2028-02-29T16:00:00Z")
        self.assertIsNone(qwen_monthly_reset(message("02-29 16:00:00"), datetime.datetime(2027,2,1,tzinfo=utc)))
        self.assertIsNone(qwen_monthly_reset(message("03-20 16:00:00"), datetime.datetime(2026,2,1,tzinfo=utc)))
        self.assertIsNone(qwen_monthly_reset(message("2026-01-01 16:00:00"), datetime.datetime(2026,2,1,tzinfo=utc)))
        self.assertIsNone(qwen_monthly_reset(message("16:00:00"), datetime.datetime(2026,2,1,tzinfo=utc)))
        self.assertIsNone(qwen_monthly_reset("The code quotes " + message("03-01 16:00:00"), datetime.datetime(2026,2,1,tzinfo=utc)))

    def test_stderr_quoted_json_without_provider_error_ignored(self):
        self.err.write_text('"message": "out of credits"\n')
        self.assertIsNone(Reader(str(self.err), True).read("grok"))

    @unittest.skipIf(os.name == "nt", "shell launcher fixture runs in Git Bash suite on Windows")
    def test_shell_helper_preserves_stdin_and_success(self):
        code = "import sys;print(sys.stdin.read())"
        script = f'source {shlex.quote(str(ROOT / "tools/reviewer_event_guard.sh"))}; reviewer_credit_run muse {shlex.quote(str(self.out))} {shlex.quote(str(self.err))} -- {shlex.quote(sys.executable)} -c {shlex.quote(code)}'
        result = subprocess.run(["bash", "-c", script], input="fixture-header", text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "fixture-header")

    @unittest.skipIf(os.name == "nt", "POSIX helper fixture; Windows helper platform suite runs Git Bash")
    def test_same_output_healthy_followup_preserves_prior_receipt(self):
        env = dict(os.environ); env["AI_REVIEW_QUARANTINE_DIR"] = str(self.base / "holds")
        prefix = f'source {shlex.quote(str(ROOT / "tools/reviewer_event_guard.sh"))}; reviewer_credit_run muse {shlex.quote(str(self.out))} {shlex.quote(str(self.err))} -- {shlex.quote(sys.executable)} -c '
        code = 'import json,time;print(json.dumps({"type":"error","error":{"message":"Insufficient Balance"}}),flush=True);time.sleep(20)'
        env["AI_REVIEW_EVENT_RUN_ID"] = "1" * 32
        script = prefix + shlex.quote(code) + f' >{shlex.quote(str(self.out))} 2>{shlex.quote(str(self.err))}'
        first = subprocess.run(["bash", "-c", script], env=env, timeout=5)
        self.assertEqual(first.returncode, 92)
        prior = Path(str(self.out) + ".credit-refusal." + "1" * 32 + ".json")
        old = prior.read_bytes()
        env["AI_REVIEW_EVENT_RUN_ID"] = "2" * 32
        script = prefix + shlex.quote('print("healthy")') + f' >{shlex.quote(str(self.out))} 2>{shlex.quote(str(self.err))}'
        second = subprocess.run(["bash", "-c", script], env=env, timeout=5)
        self.assertEqual(second.returncode, 0, self.err.read_text())
        self.assertEqual(prior.read_bytes(), old)
        self.assertFalse(Path(str(self.out) + ".credit-refusal." + "2" * 32 + ".json").exists())

    def test_marker_publication_failure_stops_owned_tree(self):
        self.marker = self.base / "missing-parent" / "receipt"
        source = f"import time;open({str(self.out)!r},'w').write('{{\"type\":\"error\",\"error\":{{\"message\":\"out of credits\"}}}}\\n');time.sleep(20)"
        started = time.monotonic(); child = self.run_supervisor(source)
        _, err = child.communicate(timeout=5)
        self.assertEqual(child.returncode, 1, err)
        self.assertIn(b"owned provider tree stopped", err)
        self.assertLess(time.monotonic() - started, 2)

    def test_stopfile_cancellation_outranks_credit(self):
        stop = self.base / "stop"; stop.touch()
        self.out.write_text('{"type":"error","error":{"message":"out of credits"}}\n')
        command = [sys.executable, str(ROOT / "bin/ai-process-supervisor"), "--stop-file", str(stop),
            "--credit-provider", "muse", "--credit-output", str(self.out), "--credit-stderr", str(self.err),
            "--credit-marker", str(self.marker), "--", sys.executable, "-c", "import time;time.sleep(20)"]
        result = subprocess.run(command, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertFalse(self.marker.exists())

    @unittest.skipIf(os.name == "nt", "native fake launcher is POSIX; Windows actual doors covered by Bash suites")
    def test_six_formal_doors_stop_hung_provider_error(self):
        fixture = self.base / "provider"
        fixture.write_text('#!/usr/bin/env python3\nimport os,time\nprint(open(os.path.join(os.path.dirname(os.path.abspath(__file__)),"error.json")).read(),flush=True)\ntime.sleep(30)\n')
        fixture.chmod(0o700)
        prompt = self.base / "prompt.md"; prompt.write_text("review fixture")
        env = dict(os.environ)
        env.update(AI_REVIEW_RUNNER_CORE="review-lifecycle-core/1", DOOR_WORKDIR=str(self.base),
                   DOOR_PACKET_DIR=str(self.base), DOOR_PROMPT_FILE=str(prompt),
                   DOOR_REPORT_OUT=str(self.base / "report"), DOOR_HEAD="1" * 40,
                   AI_REVIEW_QUARANTINE_DIR=str(self.base / "holds"), HOME=str(self.base))
        mapping = {"grok": "AI_GROK_BIN", "muse": "AI_MUSE_BIN", "qwen": "AI_QWEN_BIN",
                   "gemini": "AI_GEMINI_BIN", "deepseek": "AI_DEEPSEEK_OPENCODE", "stepfun": "AI_STEPFUN_OPENCODE"}
        for provider, variable in mapping.items():
            with self.subTest(provider=provider):
                current = env.copy(); current[variable] = str(fixture)
                current[f"AI_{provider.upper()}_ALLOW_NO_CREDS"] = "1"
                if provider == "stepfun": current["AI_STEPFUN_ENGINE"] = "opencode"
                (self.base / "error.json").write_text(json.dumps({"type": "error", "error": {"code": "402", "message": "Insufficient Balance"}}))
                started = time.monotonic()
                result = subprocess.run(["bash", str(ROOT / f"tools/lib/review-doors/{provider}.sh"), "review"],
                                        env=current, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=5)
                elapsed = time.monotonic() - started
                self.assertEqual(result.returncode, 92, result.stderr)
                self.assertIn("AI_REVIEWER_OUT_OF_CREDIT provider=" + provider, result.stderr)
                self.assertLess(elapsed, 2, provider)
                print(f"formal {provider} hung refusal: {elapsed:.3f}s")

    @unittest.skipIf(os.name == "nt", "native fake launcher POSIX; Windows Git Bash provider suites remain required")
    def test_qwen_formal_door_distinct_allowance_and_monthly_return(self):
        date = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=1)).strftime("%m-%d %H:%M:%S")
        message = f"Quota exhausted: Your token-plan 1-month quota has been exhausted. The quota will reset at {date} UTC."
        fixture = self.base / "qwen"
        fixture.write_text('#!/usr/bin/env python3\nimport json,time\nprint(' + repr(json.dumps({"type": "result", "is_error": False, "result": "[API Error: " + message + "]"})) + ',flush=True)\ntime.sleep(30)\n')
        fixture.chmod(0o700)
        prompt = self.base / "prompt"; prompt.write_text("fixture")
        env = dict(os.environ)
        env.update(AI_REVIEW_RUNNER_CORE="review-lifecycle-core/1", DOOR_WORKDIR=str(self.base), DOOR_PACKET_DIR=str(self.base),
                   DOOR_PROMPT_FILE=str(prompt), DOOR_REPORT_OUT=str(self.base / "report"), DOOR_HEAD="1" * 40,
                   AI_QWEN_BIN=str(fixture), AI_QWEN_ALLOW_NO_CREDS="1", HOME=str(self.base),
                   AI_REVIEW_QUARANTINE_DIR=str(self.base / "holds"))
        result = subprocess.run(["bash", str(ROOT / "tools/lib/review-doors/qwen.sh"), "review"], env=env,
                                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=5)
        self.assertEqual(result.returncode, 92, result.stderr)
        self.assertIn("AI_REVIEWER_ALLOWANCE_EXHAUSTED provider=qwen", result.stderr)
        self.assertIn("ALLOWANCE EXHAUSTED", result.stderr)
        self.assertNotIn("OUT OF CREDIT", result.stderr)
        self.assertNotIn("reset unavailable", result.stderr)

    def run_supervisor(self, source):
        return subprocess.Popen([sys.executable, str(ROOT / "bin/ai-process-supervisor"),
            "--credit-provider", "muse", "--credit-output", str(self.out), "--credit-stderr", str(self.err),
            "--credit-marker", str(self.marker), "--", sys.executable, "-c", source], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)

    def test_hung_child_credit_promptly_stopped(self):
        source = f"import time;open({str(self.out)!r},'w').write('{{\"type\":\"error\",\"error\":{{\"message\":\"out of credits\"}}}}\\n');time.sleep(20)"
        started = time.monotonic(); child = self.run_supervisor(source)
        _, err = child.communicate(timeout=5)
        elapsed = time.monotonic() - started
        self.assertEqual(child.returncode, 92, err)
        self.assertLess(elapsed, 2)
        self.assertEqual(json.loads(self.marker.read_text())["failure_class"], "out-of-credit")
        print(f"credit detection and cooperative teardown: {elapsed:.3f}s")

    def test_detection_precedes_existing_stubborn_child_escalation(self):
        source = f"import signal,time;signal.signal(signal.SIGTERM,signal.SIG_IGN);open({str(self.out)!r},'w').write('{{\"type\":\"error\",\"error\":{{\"message\":\"out of credits\"}}}}\\n');time.sleep(20)"
        started = time.monotonic(); child = self.run_supervisor(source)
        while not self.marker.exists() and time.monotonic() - started < 2:
            time.sleep(.01)
        self.assertTrue(self.marker.exists())
        detection = time.monotonic() - started
        _, err = child.communicate(timeout=5)
        self.assertEqual(child.returncode, 92, err)
        self.assertLess(detection, 1)
        self.assertLess(time.monotonic() - started, 5)
        print(f"stubborn child detection={detection:.3f}s; existing owned-tree teardown={time.monotonic()-started:.3f}s")

    def test_success_and_failure_unchanged(self):
        for code in (0, 7):
            child = self.run_supervisor(f"raise SystemExit({code})")
            _, err = child.communicate(timeout=5)
            self.assertEqual(child.returncode, code, err)
            self.assertFalse(self.marker.exists())

    def test_final_check_bypasses_interval_and_finds_bounded_terminal_tail(self):
        monitor = Monitor("qwen", str(self.out), str(self.err), str(self.marker))
        self.assertFalse(monitor.check())
        monitor.next_check = time.monotonic() + 60
        date = (datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(days=24)).replace(microsecond=0)
        message = "Quota exhausted: Your token-plan 1-month quota has been exhausted. The quota will reset at " + date.strftime("%m-%d %H:%M:%S") + " UTC."
        terminal = json.dumps({"type": "result", "is_error": True, "error": {"message": message}})
        self.out.write_text(json.dumps({"type": "assistant", "text": "x" * (LIMIT * 3)}) + "\n" + terminal + "\n")
        self.assertFalse(monitor.check())
        self.assertTrue(monitor.safe_check(final=True))
        receipt = json.loads(self.marker.read_text())
        self.assertEqual(receipt["reset_at"], date.isoformat().replace("+00:00", "Z"))
        self.assertLessEqual(sum(reader.bytes_read for reader in monitor.readers), LIMIT)

    def test_fast_terminal_refusal_is_preserved_before_child_exit(self):
        source = f"import json;open({str(self.out)!r},'w').write(json.dumps({{'type':'error','error':{{'message':'out of credits'}}}})+'\\n')"
        child = self.run_supervisor(source)
        _, err = child.communicate(timeout=5)
        self.assertEqual(child.returncode, 92, err)
        self.assertEqual(json.loads(self.marker.read_text())["failure_class"], "out-of-credit")

    def test_final_tail_never_promotes_assistant_quoted_error(self):
        monitor = Monitor("muse", str(self.out), str(self.err), str(self.marker))
        self.assertFalse(monitor.check())
        self.out.write_text("x" * (LIMIT * 2) + "\n" + json.dumps({"type": "assistant", "error": {"message": "out of credits"}}) + "\n")
        self.assertFalse(monitor.safe_check(final=True))
        self.assertFalse(self.marker.exists())

    @unittest.skipIf(os.name == "nt", "POSIX group accounting; native Windows proof uses Job Object")
    def test_direct_child_exit_keeps_normal_checks_until_owned_group_ends(self):
        loader = importlib.machinery.SourceFileLoader("credit_supervisor_fixture", str(ROOT / "bin/ai-process-supervisor"))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        supervisor = importlib.util.module_from_spec(spec)
        loader.exec_module(supervisor)
        child = mock.Mock(pid=123, poll=mock.Mock(return_value=0))
        monitor = mock.Mock(safe_check=mock.Mock(return_value=False))
        with mock.patch.object(supervisor.subprocess, "Popen", return_value=child), \
             mock.patch.object(supervisor.os, "killpg", side_effect=[None, None, ProcessLookupError()]), \
             mock.patch.object(supervisor.signal, "signal"), mock.patch.object(supervisor.time, "sleep"):
            self.assertEqual(supervisor.posix_main(["fixture"], credit_monitor=monitor), 0)
        self.assertEqual(monitor.safe_check.call_args_list, [mock.call(final=False), mock.call(final=False), mock.call(final=True)])

    @unittest.skipIf(os.name == "nt", "POSIX signal proof; Windows Job Object runs in CI")
    def test_cancellation_and_sibling_survive(self):
        sibling = subprocess.Popen([sys.executable, "-c", "import time;time.sleep(20)"])
        child = self.run_supervisor("import time;time.sleep(20)")
        try:
            time.sleep(.15); child.send_signal(signal.SIGTERM)
            _, err = child.communicate(timeout=5)
            self.assertEqual(child.returncode, 143, err)
            self.assertIsNone(sibling.poll()); self.assertFalse(self.marker.exists())
        finally:
            sibling.terminate(); sibling.wait(timeout=5)


@unittest.skipUnless(sys.platform.startswith("linux"), "Real Linux PID namespace proof; Windows ownership tests remain above")
class ReviewPidIsolationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.supervisor = str(ROOT / "bin/ai-process-supervisor")

    def tearDown(self):
        self.tmp.cleanup()

    def run_isolated(self, *command, env=None):
        return subprocess.run([sys.executable, self.supervisor, "--review-pid-isolation", "--", *command],
                              input=b"literal input", capture_output=True, env=env, timeout=15)

    def test_host_process_hidden_and_survives_broad_signal_own_child_can_stop(self):
        token = "review-isolation-sentinel-" + uuid.uuid4().hex
        sentinel = subprocess.Popen([sys.executable, "-c", "import time;time.sleep(30)", token])
        config = self.base / "fixture.json"
        config.write_text(json.dumps({"token": token, "host_pid": sentinel.pid}))
        script = self.base / "owned-model.py"
        script.write_text("""import json,os,signal,subprocess,sys,time
c=json.load(open(sys.argv[1]))
assert not os.path.exists('/proc/'+str(c['host_pid']))
try: os.kill(c['host_pid'],signal.SIGTERM)
except ProcessLookupError: pass
else: raise AssertionError('host PID visible')
child=subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)',c['token']])
time.sleep(.1)
r=subprocess.run(['pkill','-f',c['token']])
assert r.returncode==0
assert child.wait(timeout=3)==-signal.SIGTERM
assert sys.stdin.read()=='literal input'
print('host hidden; own child stopped; stdin preserved')
""")
        try:
            result = self.run_isolated(sys.executable, str(script), str(config))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(b"own child stopped", result.stdout)
            self.assertIsNone(sentinel.poll())
        finally:
            sentinel.terminate(); sentinel.wait(timeout=5)

    def test_files_build_output_network_and_exit_status_preserved(self):
        import http.server
        import threading
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200); self.end_headers(); self.wfile.write(b"offline-network")
            def log_message(self, *_args): pass
        server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        out = self.base / "compiled-result"
        code = ("import pathlib,subprocess,sys,urllib.request;"
                "p=pathlib.Path(sys.argv[1]);p.write_bytes(b'preserved-file');"
                "subprocess.run([sys.executable,'-c','compile(\"x=1\",\"fixture\",\"exec\")'],check=True);"
                "assert urllib.request.urlopen(sys.argv[2]).read()==b'offline-network';"
                "sys.stdout.buffer.write(b'z'*100000);sys.stderr.write('retained stderr');raise SystemExit(17)")
        try:
            result = self.run_isolated(sys.executable, "-c", code, str(out), f"http://127.0.0.1:{server.server_port}")
            self.assertEqual(result.returncode, 17, result.stderr)
            self.assertEqual(result.stdout, b"z" * 100000)
            self.assertEqual(result.stderr, b"retained stderr")
            self.assertEqual(out.read_bytes(), b"preserved-file")
        finally:
            server.shutdown(); server.server_close(); thread.join(timeout=3)

    def test_missing_or_nonisolating_bwrap_refuses_before_model_command(self):
        empty = self.base / "empty"; empty.mkdir()
        marker = self.base / "model-dispatched"
        command = [sys.executable, "-c", "import pathlib,sys;pathlib.Path(sys.argv[1]).touch()", str(marker)]
        env = dict(os.environ, PATH=str(empty))
        result = self.run_isolated(*command, env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(marker.exists())
        self.assertIn(b"bubblewrap is required", result.stderr)
        invoked=self.base/'fake-invoked'
        fake = empty / "bwrap"
        fake.write_text("#!/bin/sh\nprintf invoked > "+shlex.quote(str(invoked))+"\nprintf '%s' '{\"pid\":2,\"pid_namespace\":\"forged\",\"user_namespace\":\"forged\",\"visible_pids\":[\"1\",\"2\"],\"cap_eff\":\"0\"}'\n")
        fake.chmod(0o700)
        result = self.run_isolated(*command, env=env)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(marker.exists())
        self.assertFalse(invoked.exists())
        self.assertIn(b"custody refused before invocation", result.stderr)

    def test_host_supervisor_interrupt_reaps_namespace(self):
        heartbeat = self.base / "heartbeat"
        source = self.base / "heartbeat.py"
        source.write_text("import pathlib,sys,time\np=pathlib.Path(sys.argv[1])\nwhile True:\n p.write_text(str(time.monotonic()));time.sleep(.05)\n")
        child = subprocess.Popen([sys.executable, self.supervisor, "--review-pid-isolation", "--",
                                  sys.executable, str(source), str(heartbeat)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            deadline = time.monotonic() + 5
            while not heartbeat.exists() and time.monotonic() < deadline: time.sleep(.02)
            self.assertTrue(heartbeat.exists())
            child.send_signal(signal.SIGTERM)
            _, err = child.communicate(timeout=6)
            self.assertEqual(child.returncode, 143, err)
            before = heartbeat.read_bytes(); time.sleep(.2)
            self.assertEqual(heartbeat.read_bytes(), before)
        finally:
            if child.poll() is None: child.kill(); child.wait(timeout=3)



@unittest.skipUnless(sys.platform.startswith("linux"), "Native sibling capsules require Linux; other provider routes retain cross-platform tests")
class NativeSiblingBrokerTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.supervisor = ROOT / "bin/ai-process-supervisor"
        loader = importlib.machinery.SourceFileLoader("native_broker_fixture", str(self.supervisor))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        self.module = importlib.util.module_from_spec(spec)
        loader.exec_module(self.module)

    def tearDown(self):
        self.tmp.cleanup()

    def capsule(self, body, hook=None):
        broker = self.module.NativeShellBroker(str(self.base), sys.executable)
        script = self.base / "synthetic-engine.py"
        script.write_text("""import importlib.machinery,importlib.util,json,os,pathlib,socket,struct,subprocess,sys,time
helper=sys.argv[1];socket_path=sys.argv[2];expected_peer=sys.argv[3]
loader=importlib.machinery.SourceFileLoader('native_client_fixture',helper)
spec=importlib.util.spec_from_loader(loader.name,loader);m=importlib.util.module_from_spec(spec);loader.exec_module(m)
def command(value):
 return subprocess.run([sys.executable,helper,'--native-shell-client',socket_path,expected_peer,'-c',value],capture_output=True,timeout=10)
def raw(value,header=None):
 with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as conn:
  conn.connect(socket_path);conn.sendall(struct.pack('!I',len(value) if header is None else header)+value)
  while True:
   kind=m.exact(conn,1);size=struct.unpack('!I',m.exact(conn,4))[0];data=m.exact(conn,size)
   if kind==b'X':return int(data)
""" + body)
        dummy=['/usr/bin/timeout','30',sys.executable,'run','--dir',str(self.base)]
        prefix,env=broker.engine_command(dummy,None)
        prefix=prefix[:-len(dummy)]
        os.link(broker.client_path,self.base/'client-mutable-alias')
        os.link(broker.control/'bash',self.base/'launcher-mutable-alias')
        child = subprocess.Popen(prefix + [sys.executable, str(script), str(broker.client_path), broker.path,broker.server_identity],
                                 cwd=self.base, stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True,env=env,pass_fds=broker.engine_fds())
        called = False
        try:
            deadline=time.monotonic()+15
            while child.poll() is None and time.monotonic()<deadline:
                broker.capture_engine(child)
                if hook and broker.engine is not None and not called:
                    hook(broker,child);called=True
                time.sleep(.02)
            out,err=child.communicate(timeout=2)
            self.assertEqual(child.returncode,0,err)
            if hook:self.assertTrue(called)
            return out
        finally:
            if child.poll() is None:os.killpg(child.pid,signal.SIGKILL);child.wait(timeout=3)
            broker.close()
            self.assertFalse(broker.active())

    def test_real_selfkill_continuation_binary_streams_and_readonly_client(self):
        out=self.capsule("""
a=command('printf before;kill -TERM $$;printf forbidden')
assert a.returncode==143 and a.stdout==b'before', (a.returncode,a.stdout,a.stderr)
b=command("python3 -c 'import sys;sys.stdout.buffer.write(bytes(range(256))*400);sys.stderr.buffer.write(bytes(range(256))*400)' ")
assert b.returncode==0 and b.stdout==bytes(range(256))*400 and b.stderr==bytes(range(256))*400
c=command('printf after;exit 17');assert c.returncode==17 and c.stdout==b'after'
before=pathlib.Path(helper).read_bytes()
pathlib.Path('client-mutable-alias').chmod(0o700)
pathlib.Path('client-mutable-alias').write_bytes(b'FORGED_CLIENT_BYTES')
pathlib.Path('launcher-mutable-alias').chmod(0o700)
pathlib.Path('launcher-mutable-alias').write_bytes(b'FORGED_IDENTITY_BYTES')
assert pathlib.Path(helper).read_bytes()==before
try:open(helper,'ab').write(b'forbidden')
except OSError:pass
else:raise AssertionError('native client writable')
try:os.link(helper,'new-client-hardlink')
except OSError:pass
else:raise AssertionError('native client hardlink writable')
assert command('printf immutable-client').stdout==b'immutable-client'
tool=command('printf TOOL_FORGED > client-mutable-alias; printf TOOL_IDENTITY_FORGED > launcher-mutable-alias')
assert tool.returncode==0,tool.stderr
assert pathlib.Path(helper).read_bytes()==before
assert command('printf sibling-immutable-client').stdout==b'sibling-immutable-client'
print('actual selfkill143 then next tool; exact binary streams; readonly client')
""")
        self.assertIn(b"actual selfkill143",out)

    def test_strict_duplicate_unknown_nested_non_utf8_oversize_and_cwd_refusal(self):
        outside=self.base/'outside';outside.mkdir();(self.base/'link').symlink_to(outside,target_is_directory=True)
        out=self.capsule("""
base=os.getcwd()
values=[b'{"command":"touch forbidden","cwd":"'+base.encode()+b'","env":{}}',
 b'{"command":"true","command":"touch forbidden","cwd":"'+base.encode()+b'"}',
 bytes([255]),json.dumps({'command':{'exe':'touch forbidden'},'cwd':base}).encode(),
 json.dumps({'command':'touch forbidden','cwd':base+'/../'}).encode(),
 json.dumps({'command':'touch forbidden','cwd':base+'/link'}).encode()]
for value in values:assert raw(value)==2,value
assert raw(b'',m.MAX_HEADER+1)==2
assert not pathlib.Path('forbidden').exists()
print('malformed and foreign cwd refused without execution')
""")
        self.assertIn(b"without execution",out)

    def test_live_namespace_peer_rejects_host_and_foreign_capsule(self):
        def hook(broker,child):
            self.assertEqual(os.stat(broker.path).st_mode & 0o777,0o600)
            self.assertEqual(broker.control.stat().st_mode & 0o777,0o700)
            cmd=[sys.executable,str(self.supervisor),'--native-shell-client',broker.path,broker.server_identity,'-c','touch forbidden']
            host=subprocess.run(cmd,cwd=self.base,capture_output=True,timeout=5)
            other=subprocess.run(broker.prefix+['--',*cmd],cwd=self.base,capture_output=True,timeout=5)
            self.assertNotEqual(host.returncode,0,host.stderr);self.assertNotEqual(other.returncode,0,other.stderr)
            self.assertFalse((self.base/'forbidden').exists())
        self.capsule("time.sleep(2);assert command('printf owned').stdout==b'owned'\n",hook)

    def test_fd_pinned_cwd_rejects_rename_symlink_substitution(self):
        broker=self.module.NativeShellBroker(str(self.base),sys.executable)
        (self.base/'safe').mkdir();(self.base/'safe'/'marker').write_text('owned')
        fd=broker.cwd_fd(str(self.base/'safe'))
        try:
            (self.base/'safe').rename(self.base/'renamed');(self.base/'safe').symlink_to('/tmp',target_is_directory=True)
            result=subprocess.run(['/bin/cat','marker'],cwd=f'/proc/self/fd/{fd}',pass_fds=(fd,),capture_output=True)
            self.assertEqual(result.stdout,b'owned')
            with self.assertRaises(OSError):broker.cwd_fd(str(self.base/'safe'))
        finally:os.close(fd);broker.close()

    def test_four_tools_bound_until_disconnect_cleanup_completes(self):
        out=self.capsule("""
connections=[]
for _ in range(4):
 s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);s.connect(socket_path)
 value=json.dumps({'command':'sleep 10','cwd':os.getcwd()}).encode();s.sendall(struct.pack('!I',len(value))+value);connections.append(s)
time.sleep(.3)
r=command('touch forbidden');assert r.returncode!=0
assert not pathlib.Path('forbidden').exists()
for s in connections:s.close()
time.sleep(.3)
assert command('printf recovered').stdout==b'recovered'
print('four tool bound; slots retained through cleanup')
""")
        self.assertIn(b"four tool bound",out)

    def test_closed_output_sink_disconnect_reaps_background_tool(self):
        out=self.capsule("""
r=subprocess.Popen([sys.executable,helper,'--native-shell-client',socket_path,expected_peer,'-c','while :; do printf x >> heartbeat; printf x; sleep .03; done'],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
assert r.stdout.read(1)==b'x';r.stdout.close();r.wait(timeout=5)
time.sleep(.3);p=pathlib.Path('heartbeat');before=p.read_bytes();time.sleep(.3);assert p.read_bytes()==before
assert command('printf next').stdout==b'next'
print('closed sink stops owned tool and next tool works')
""")
        self.assertIn(b"closed sink",out)

    def server_identity(self):
        fd=os.pidfd_open(os.getpid())
        try:
            info=os.fstat(fd)
            return f'{info.st_dev}:{info.st_ino}'
        finally:os.close(fd)

    def test_client_rejects_invalid_exit_and_output_frames(self):
        import socket,struct,threading
        for payload in (b'X'+struct.pack('!I',1)+b'0EXTRA',b'X'+struct.pack('!I',3)+b'999',b'X'+struct.pack('!I',2)+b'-1',
                        b'X'+struct.pack('!I',2)+b'00',b'Q'+struct.pack('!I',1)+b'x',
                        b'O'+struct.pack('!I',self.module.CHUNK+1)):
            path=str(self.base/'bad-socket');server=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);server.bind(path);server.listen(1)
            def reply():
                conn,_=server.accept()
                with conn:
                    size=struct.unpack('!I',self.module.exact(conn,4))[0];self.module.exact(conn,size);conn.sendall(payload)
            thread=threading.Thread(target=reply);thread.start()
            try:
                result=subprocess.run([sys.executable,str(self.supervisor),'--native-shell-client',path,self.server_identity(),'-c','true'],cwd=self.base,capture_output=True,timeout=5)
                self.assertEqual(result.returncode,143)
            finally:thread.join(timeout=2);server.close();Path(path).unlink()

    def test_failed_engine_capture_closes_real_acquired_pidfd(self):
        broker=self.module.NativeShellBroker(str(self.base),sys.executable)
        fd=os.pidfd_open(os.getpid())
        try:
            with mock.patch.object(self.module.os,'pidfd_open',return_value=fd),mock.patch.object(broker,'process_identity',side_effect=ProcessLookupError):
                with self.assertRaises(ProcessLookupError):broker.bind_engine(os.getpid())
            with self.assertRaises(OSError):os.fstat(fd)
            self.assertIsNone(broker.engine)
        finally:broker.close()

    def test_postlaunch_exception_closes_broker_and_real_child(self):
        broker=mock.Mock()
        broker.engine_command.side_effect=lambda command,timeout:(command,None)
        broker.engine_fds.return_value=()
        broker.engine_data_fds=()
        broker.capture_engine.side_effect=RuntimeError('synthetic capture failure')
        original=self.module.subprocess.Popen
        children=[]
        def launch(*args,**kwargs):
            child=original(*args,**kwargs);children.append(child);return child
        with mock.patch.object(self.module,'NativeShellBroker',return_value=broker),mock.patch.object(self.module.subprocess,'Popen',side_effect=launch):
            with self.assertRaisesRegex(RuntimeError,'synthetic capture failure'):
                self.module.posix_main([sys.executable,'-c','import time;time.sleep(30)'],native_options=('synthetic','synthetic'))
        broker.close.assert_called_once()
        self.assertIsNotNone(children[0].poll())

    def test_unreapable_job_retains_failure_accounting(self):
        broker=self.module.NativeShellBroker(str(self.base),sys.executable)
        job=mock.Mock(pid=123456789)
        job.poll.return_value=None
        job.wait.side_effect=subprocess.TimeoutExpired('synthetic',1)
        try:
            with mock.patch.object(self.module.os,'killpg'):
                self.assertFalse(broker.stop_job(job))
            self.assertTrue(broker.cleanup_failed.is_set())
            self.assertEqual(job.wait.call_count,2)
        finally:
            with self.assertRaisesRegex(RuntimeError,'closure incomplete'):broker.close()

    def test_postlaunch_parent_fd_close_failure_reaps_real_child(self):
        broker=mock.Mock()
        broker.engine_command.side_effect=lambda command,timeout:(command,None)
        broker.engine_fds.return_value=()
        fd=os.open('/dev/null',os.O_RDONLY)
        broker.engine_data_fds=(fd,)
        original_launch=self.module.subprocess.Popen;original_close=os.close;children=[]
        def launch(*args,**kwargs):
            child=original_launch(*args,**kwargs);children.append(child);return child
        def close(value):
            if value==fd:raise OSError('synthetic parent FD close failure')
            return original_close(value)
        try:
            with mock.patch.object(self.module,'NativeShellBroker',return_value=broker),mock.patch.object(self.module.subprocess,'Popen',side_effect=launch),mock.patch.object(self.module.os,'close',side_effect=close):
                with self.assertRaisesRegex(OSError,'synthetic parent FD close failure'):
                    self.module.posix_main([sys.executable,'-c','import time;time.sleep(30)'],native_options=('synthetic','synthetic'))
            self.assertIsNotNone(children[0].poll())
            broker.close.assert_called_once()
        finally:
            original_close(fd)
            for child in children:
                if child.poll() is None:child.kill();child.wait()

    def test_trusted_launcher_isolates_python_startup_only(self):
        out=self.capsule("""
evil=pathlib.Path('startup');evil.mkdir()
(evil/'sitecustomize.py').write_text("import pathlib;pathlib.Path('startup-ran').write_text('injected')")
os.environ['PYTHONPATH']=str(evil.absolute())
launcher=json.loads(os.environ['OPENCODE_CONFIG_CONTENT'])['shell']
r=subprocess.run([launcher,'-c','printf trusted-client'],capture_output=True,timeout=5)
assert r.returncode==0 and r.stdout==b'trusted-client',r.stderr
assert not pathlib.Path('startup-ran').exists()
subprocess.run([sys.executable,'-c','print("ordinary-python")'],check=True)
assert pathlib.Path('startup-ran').read_text()=='injected'
print('trusted transport isolated; ordinary Python startup retained')
""")
        self.assertIn(b'trusted transport isolated',out)

    def test_foreign_server_pidfd_refused_before_request(self):
        path=str(self.base/'foreign-socket');received=self.base/'received'
        code="""import pathlib,socket,sys
s=socket.socket(socket.AF_UNIX,socket.SOCK_STREAM);s.bind(sys.argv[1]);s.listen(1)
c,_=s.accept();pathlib.Path(sys.argv[2]).write_bytes(c.recv(1024));c.close();s.close()
"""
        server=subprocess.Popen([sys.executable,'-c',code,path,str(received)])
        try:
            deadline=time.monotonic()+3
            while not Path(path).exists() and time.monotonic()<deadline:time.sleep(.01)
            result=subprocess.run([sys.executable,str(self.supervisor),'--native-shell-client',path,self.server_identity(),'-c','touch forbidden'],capture_output=True,timeout=5)
            self.assertEqual(result.returncode,143)
            server.wait(timeout=3)
            self.assertEqual(received.read_bytes(),b'')
            self.assertFalse((self.base/'forbidden').exists())
        finally:
            if server.poll() is None:server.kill();server.wait()

    def test_group_writable_engine_refused(self):
        import shutil
        engine=self.base/'unsafe-engine';shutil.copyfile(sys.executable,engine);engine.chmod(0o770)
        with self.assertRaises(ValueError):self.module.NativeShellBroker(str(self.base),str(engine))

    def test_root_file_claim_cannot_bypass_writable_ancestor(self):
        import shutil
        binary=self.base/'bwrap';shutil.copyfile(shutil.which('bwrap'),binary);binary.chmod(0o755)
        original=Path.stat
        def claimed_root(path,*args,**kwargs):
            info=original(path,*args,**kwargs)
            if str(path).startswith(str(self.base)):
                values=list(info);values[4]=0
                return os.stat_result(values)
            return info
        with mock.patch.object(self.module.shutil,'which',return_value=str(binary)),mock.patch.object(Path,'stat',claimed_root),mock.patch.object(self.module.subprocess,'run') as probe:
            with self.assertRaises(SystemExit):self.module.isolated_review_command([])
            probe.assert_not_called()

    def test_failed_snapshot_closes_all_acquired_descriptors(self):
        before=set(os.listdir('/proc/self/fd'))
        control=self.base/'failed-control';control.mkdir()
        with mock.patch.object(self.module.tempfile,'mkdtemp',return_value=str(control)),mock.patch.object(self.module.NativeShellBroker,'sealed_data',side_effect=OSError('synthetic sealing failure')):
            with self.assertRaisesRegex(OSError,'synthetic sealing failure'):
                self.module.NativeShellBroker(str(self.base),sys.executable)
        self.assertEqual(set(os.listdir('/proc/self/fd')),before)
        self.assertFalse(control.exists())

    def test_signal_admission_close_never_reenters_job_lock(self):
        broker=self.module.NativeShellBroker(str(self.base),sys.executable)
        try:
            with broker.lock:
                started=time.monotonic()
                broker.stop_admission(signal_safe=True)
                self.assertTrue(broker.admission_closed)
                self.assertLess(time.monotonic()-started,.2)
        finally:broker.close()

    def test_native_supervisor_timeout_signal_credit_and_abrupt_death_close_tools(self):
        import shutil
        engine=self.base/'synthetic-native-engine'
        shutil.copyfile(sys.executable,engine);engine.chmod(0o700)
        script=self.base/'run'
        script.write_text("""import json,os,pathlib,subprocess,time
shell=json.loads(os.environ['OPENCODE_CONFIG_CONTENT'])['shell']
p=subprocess.Popen([shell,'-c',"trap '' TERM; while :; do printf x >> heartbeat; sleep .03; done"],stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
while not pathlib.Path('heartbeat').exists():time.sleep(.01)
if os.environ.get('SYNTHETIC_CREDIT_OUTPUT'):
 pathlib.Path(os.environ['SYNTHETIC_CREDIT_OUTPUT']).write_text('{"type":"error","error":{"message":"out of credits"}}\\n')
time.sleep(30)
""")
        sentinel=subprocess.Popen([sys.executable,'-c','import time;time.sleep(30)'])
        try:
            for stage in ('signal','timeout','credit','abrupt'):
                with self.subTest(stage=stage):
                    heartbeat=self.base/'heartbeat';heartbeat.unlink(missing_ok=True)
                    out=self.base/'credit-out';err=self.base/'credit-err';marker=self.base/'credit-marker'
                    out.write_text('');err.write_text('');marker.unlink(missing_ok=True)
                    options=[];env=dict(os.environ)
                    if stage=='timeout':options=['--timeout-seconds','1']
                    if stage=='credit':
                        options=['--credit-provider','muse','--credit-output',str(out),'--credit-stderr',str(err),'--credit-marker',str(marker)]
                        env['SYNTHETIC_CREDIT_OUTPUT']=str(out)
                    args=[sys.executable,str(self.supervisor),'--native-deepseek-review',str(self.base),str(engine),*options,'--','/usr/bin/timeout','30',str(engine),'run','--dir',str(self.base)]
                    child=subprocess.Popen(args,cwd=self.base,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env)
                    try:
                        deadline=time.monotonic()+5
                        while not heartbeat.exists() and child.poll() is None and time.monotonic()<deadline:time.sleep(.02)
                        if not heartbeat.exists():
                            if child.poll() is None:child.kill()
                            captured_out,captured_err=child.communicate(timeout=3)
                            self.fail(f'{stage}: native fixture failed before tool heartbeat: {captured_err!r} {captured_out!r}')
                        if stage=='signal':child.send_signal(signal.SIGTERM)
                        if stage=='abrupt':child.kill()
                        _,stderr=child.communicate(timeout=5)
                        self.assertEqual(child.returncode,{'signal':143,'timeout':124,'credit':92,'abrupt':-signal.SIGKILL}[stage],stderr)
                        before=heartbeat.read_bytes();time.sleep(.2);self.assertEqual(heartbeat.read_bytes(),before)
                        self.assertIsNone(sentinel.poll())
                    finally:
                        if child.poll() is None:child.kill()
                        child.communicate(timeout=3)
        finally:sentinel.terminate();sentinel.wait(timeout=3)

    def test_private_devices_build_network_and_fixed_tool_environment(self):
        import http.server,threading
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200);self.end_headers();self.wfile.write(b'synthetic-network')
            def log_message(self,*_args):pass
        server=http.server.HTTPServer(('127.0.0.1',0),Handler)
        thread=threading.Thread(target=server.serve_forever);thread.start()
        code=("import os,pathlib,urllib.request;"
              "assert open('/dev/null','rb').read()==b'';"
              "assert len(os.urandom(32))==32;"
              "assert next(x.split()[1] for x in open('/proc/self/status') if x.startswith('CapEff:'))=='0000000000000000';"
              "assert 'DEEPSEEK_API_KEY' not in os.environ and 'OP_SERVICE_ACCOUNT_TOKEN' not in os.environ;"
              "compile('x=1','synthetic-build','exec');pathlib.Path('build-output').write_bytes(b'built');"
              f"assert urllib.request.urlopen('http://127.0.0.1:{server.server_port}').read()==b'synthetic-network';"
              "print('private devices; fixed credential-free tools; build and network preserved')")
        try:
            with mock.patch.dict(os.environ,{'DEEPSEEK_API_KEY':'SYNTHETIC-NOT-A-KEY','OP_SERVICE_ACCOUNT_TOKEN':'SYNTHETIC-NOT-A-TOKEN'}):
                out=self.capsule('r=command('+repr('python3 -c '+shlex.quote(code))+');assert r.returncode==0,r.stderr;print(r.stdout.decode())\n')
            self.assertIn(b'build and network preserved',out)
            self.assertEqual((self.base/'build-output').read_bytes(),b'built')
        finally:server.shutdown();server.server_close();thread.join(timeout=3)

if __name__ == "__main__": unittest.main()
