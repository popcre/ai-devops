"""Offline parser, incremental-cost and owned-tree credit-stop proof."""
import importlib.machinery
import importlib.util
import json
import datetime
import os
from pathlib import Path
import signal
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


if __name__ == "__main__": unittest.main()
