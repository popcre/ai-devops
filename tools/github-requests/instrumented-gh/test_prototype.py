#!/usr/bin/env python3
"""Trusted local server parity/hidden-retry proof. No GitHub writes or tokens."""
import hashlib
import http.server
import importlib.util
import json
import os
import pathlib
import signal
import socket
import ssl
import subprocess
from sealed import verified_run
import sys
import threading
import tempfile
import time
import unittest

HERE = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("counter_runner", HERE / "run.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)
MANIFEST = json.loads(pathlib.Path(sys.argv.pop(1)).read_text()) if len(sys.argv) > 1 else None


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *_args):
        pass

    def do_GET(self):
        path = self.path.removeprefix("/api/v3")
        with self.server.lock:
            self.server.received += 1
            self.server.paths.append(self.path)
            ordinal = self.server.received
        if path.startswith("/slow"):
            self.server.entered.set()
            time.sleep(1)
            body = b"[]"
            self.send_response(200)
        elif path.startswith("/pages"):
            page = 2 if "page=2" in path else 3 if "page=3" in path else 1
            if page == 2 and self.server.retry and ordinal == 2:
                # Read a real second request on the reused connection, then
                # close before response. Go retries the idempotent request.
                self.connection.shutdown(socket.SHUT_RDWR)
                self.connection.close()
                self.close_connection = True
                return
            body = json.dumps([page]).encode()
            self.send_response(200)
            if page < 3:
                host = "localhost:" + str(self.server.server_port)
                self.send_header("Link", '<https://' + host + '/api/v3/pages?page=' + str(page + 1) + '>; rel="next"')
        elif path.startswith("/private"):
            body = b'{"private":"fake-body-sentinel"}'
            self.send_response(200)
        else:
            body = b'{"message":"fixture failure"}'
            self.send_response(403)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class PrototypeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if MANIFEST is None:
            raise RuntimeError("paired build manifest required")
        cls.scratch = tempfile.TemporaryDirectory(prefix="gh-http-fixture-")
        scratch = pathlib.Path(cls.scratch.name)
        certificate, key = scratch / "certificate.pem", scratch / "key.pem"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1",
                        "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1",
                        "-keyout", str(key), "-out", str(certificate)], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, check=True)
        cls.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        tls.load_cert_chain(certificate, key)
        cls.server.socket = tls.wrap_socket(cls.server.socket, server_side=True)
        cls.server.lock = threading.Lock()
        cls.server.entered = threading.Event()
        cls.server.handle_error = lambda *_args: None
        cls.server.daemon_threads = True
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        cls.host = "localhost:" + str(cls.server.server_port)
        cls.env = {name: os.environ[name] for name in ("PATH",) if name in os.environ}
        cls.env.update(GH_HOST=cls.host, GH_TOKEN="fake-token-sentinel", GH_PROMPT_DISABLED="1",
                       GH_ENTERPRISE_TOKEN="fake-token-sentinel", GH_CONFIG_DIR=str(scratch / "config"),
                       HOME=str(scratch), XDG_CACHE_HOME=str(scratch / "cache"),
                       SSL_CERT_FILE=str(certificate), SSL_CERT_DIR=str(scratch / "trust"),
                       GH_NO_UPDATE_NOTIFIER="1", GH_TELEMETRY="false", NO_COLOR="1")

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.scratch.cleanup()

    def reset(self, retry=False):
        self.server.received = 0
        self.server.paths = []
        self.server.retry = retry

    def execute(self, kind, args, instrument=True):
        artifact = MANIFEST["artifacts"][kind]
        if not instrument:
            result = verified_run(artifact, args, env=self.env, capture_output=True, timeout=20)
            return result, None
        read_fd, write_fd = os.pipe()
        try:
            result = subprocess.run([sys.executable, str(HERE / "run.py"), "--binary", artifact["path"],
                                     "--sha256", artifact["sha256"], "--api-host", self.host,
                                     "--metadata-fd", str(write_fd), "--", *args], env=self.env,
                                    pass_fds=(write_fd,), capture_output=True, timeout=20)
            os.close(write_fd)
            write_fd = -1
            raw = os.read(read_fd, 4096)
            self.assertNotIn(b"fake-token-sentinel", raw)
            self.assertNotIn(b"fake-body-sentinel", raw)
            self.assertNotIn(b"fake-query-sentinel", raw)
            self.assertNotIn(self.host.encode(), raw)
            return result, json.loads(raw)
        finally:
            os.close(read_fd)
            if write_fd >= 0:
                os.close(write_fd)

    def parity(self, args, expected, retry=False):
        self.reset(retry)
        baseline, _ = self.execute("baseline", args, instrument=False)
        self.assertEqual(self.server.received, expected)
        self.reset(retry)
        patched, metadata = self.execute("instrumented", args)
        self.assertEqual(self.server.received, expected)
        self.assertEqual((patched.returncode, patched.stdout, patched.stderr),
                         (baseline.returncode, baseline.stdout, baseline.stderr))
        self.assertEqual(metadata["observed_completed_writes"], expected)
        self.assertTrue(metadata["complete"])
        self.assertIsNone(metadata["http_requests"])

    def test_pagination(self):
        self.parity(["api", "pages", "--paginate"], 3)

    def test_hidden_retry_matches_server_ledger(self):
        self.parity(["api", "pages", "--paginate"], 4, retry=True)
        self.assertEqual(sum("page=2" in path for path in self.server.paths), 2)

    def test_private_query_body_stay_out_of_metadata(self):
        self.parity(["api", "private?secret=fake-query-sentinel"], 1)

    def test_failure_preserves_status_and_diagnostics(self):
        self.parity(["api", "denied"], 1)

    def test_uninstrumented_binary_missing_finish_is_unknown(self):
        self.reset()
        result, metadata = self.execute("baseline", ["api", "private"])
        self.assertEqual(result.returncode, 0)
        self.assertIsNone(metadata["observed_completed_writes"])
        self.assertFalse(metadata["complete"])

    def test_malformed_secret_metadata_fails_unknown(self):
        for raw in (b"", b"fake-token-sentinel", b'{"schema":1,"started":true}\n',
                    b'{"schema":true,"started":true}\n', b'[]\n', b'null\n'):
            self.assertEqual(runner.validate(raw), runner.UNKNOWN)

    def test_cache_hit_is_zero_observed_writes_not_fake_http_total(self):
        self.reset()
        first, first_metadata = self.execute("instrumented", ["api", "private", "--cache", "60s"])
        second, second_metadata = self.execute("instrumented", ["api", "private", "--cache", "60s"])
        self.assertEqual(self.server.received, 1)
        self.assertEqual(first_metadata["observed_completed_writes"], 1)
        self.assertEqual(second_metadata["observed_completed_writes"], 0)
        self.assertEqual(first.stdout, second.stdout)
        self.assertIsNone(second_metadata["http_requests"])

    def test_termination_leaves_unknown_without_replay(self):
        self.reset()
        self.server.entered.clear()
        artifact = MANIFEST["artifacts"]["instrumented"]
        read_fd, write_fd = os.pipe()
        process = None
        try:
            process = subprocess.Popen([sys.executable, str(HERE / "run.py"), "--binary", artifact["path"],
                                        "--sha256", artifact["sha256"], "--api-host", self.host,
                                        "--metadata-fd", str(write_fd), "--", "api", "slow"],
                                       env=self.env, pass_fds=(write_fd,), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertTrue(self.server.entered.wait(10))
            process.send_signal(signal.SIGTERM)
            process.communicate(timeout=10)
            os.close(write_fd)
            write_fd = -1
            metadata = json.loads(os.read(read_fd, 4096))
            self.assertEqual(self.server.received, 1)
            self.assertEqual(process.returncode, 143)
            self.assertFalse(metadata["complete"])
            self.assertIsNone(metadata["observed_completed_writes"])
        finally:
            if process is not None and process.poll() is None:
                process.kill()
                process.wait()
            os.close(read_fd)
            if write_fd >= 0:
                os.close(write_fd)

    def test_descendant_does_not_inherit_counter_environment(self):
        alias = '!if [ -z "${AI_GH_HTTP_COUNTER_FD+x}" ] && [ -z "${AI_GH_HTTP_COUNTER_HOST+x}" ]; then printf "CLEAR\\n"; else exit 4; fi'
        baseline = MANIFEST["artifacts"]["baseline"]
        configured = verified_run(baseline, ["alias", "set", "fixture-counter-env", alias],
                                    env=self.env, capture_output=True, timeout=10)
        self.assertEqual(configured.returncode, 0)
        result, metadata = self.execute("instrumented", ["fixture-counter-env"])
        self.assertEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b"CLEAR\n")
        self.assertTrue(metadata["complete"])
        self.assertEqual(metadata["observed_completed_writes"], 0)
        self.assertIsNone(metadata["http_requests"])


if __name__ == "__main__":
    unittest.main()
