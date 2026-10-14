"""Invented loopback credentials only; exercise the actual installer health block."""
import base64
import http.server
import json
import os
import pathlib
import shutil
import subprocess
import tempfile
import threading
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


@unittest.skipUnless(os.name == "posix", "Linux installer check")
class AuthPipeTests(unittest.TestCase):
    def test_actual_installer_keeps_escaped_authentication_off_argv(self):
        password = 'PUBLIC-INVENTED-quote"-slash\\-password'
        expected = "Basic " + base64.b64encode(("opencode:" + password).encode()).decode()
        requests = []

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                requests.append((self.path, self.headers.get("Authorization")))
                self.send_response(200 if self.headers.get("Authorization") == expected else 401)
                self.end_headers()

            def log_message(self, *args):
                pass

        server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            with tempfile.TemporaryDirectory() as tmp:
                folder = pathlib.Path(tmp)
                capture = folder / "argv.jsonl"
                fakecurl = folder / "curl"
                fakecurl.write_text(
                    "#!" + shutil.which("python3") + "\n"
                    "import json, os, sys\n"
                    "with open(os.environ['ARGV_CAPTURE'], 'a') as out:\n"
                    "    out.write(json.dumps(sys.argv[1:]) + '\\n')\n"
                    "os.execv(os.environ['REAL_CURL'], [os.environ['REAL_CURL']] + sys.argv[1:])\n"
                )
                fakecurl.chmod(0o700)
                source = (ROOT / "bin/setup-opencode-glm.sh").read_text()
                start = source.index("ok=0\nfor _ in $(seq 1 30); do")
                stop = source.index('\ninfo "OpenCode GLM server is up', start)
                block = source[start:stop]
                env = dict(
                    os.environ,
                    PATH=tmp + os.pathsep + os.environ["PATH"],
                    REAL_CURL=shutil.which("curl"),
                    ARGV_CAPTURE=str(capture),
                    PUBLIC_PASSWORD=password,
                    PUBLIC_PORT=str(server.server_port),
                    PUBLIC_HELPER=str(ROOT / "tools/lib/opencode-curl-auth.sh"),
                    http_proxy="http://127.0.0.1:9",
                    HTTP_PROXY="http://127.0.0.1:9",
                    ALL_PROXY="http://127.0.0.1:9",
                    all_proxy="http://127.0.0.1:9",
                    NO_PROXY="", no_proxy="",
                )
                run = subprocess.run(
                    ["bash", "-c", 'set -euo pipefail; source "$PUBLIC_HELPER"; PW="$PUBLIC_PASSWORD"; PORT="$PUBLIC_PORT"; die(){ exit 1; }; ' + block],
                    env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10,
                )
                self.assertEqual(run.returncode, 0, "actual installer health block did not authenticate")
                rows = [json.loads(x) for x in capture.read_text().splitlines()]
                self.assertEqual(len(rows), 1)
                self.assertEqual(rows[0][:2], ["--config", "-"])
                self.assertFalse(any(password in arg or expected in arg or arg in ("-u", "--user") for row in rows for arg in row))
                self.assertEqual(requests, [("/global/health", expected)])
        finally:
            server.shutdown()
            server.server_close()
            worker.join(timeout=2)

    def test_actual_glm_client_authenticates_all_http_paths_without_proxy_or_argv_leaks(self):
        password = 'PUBLIC-INVENTED-quote"-slash\\-password'
        expected = "Basic " + base64.b64encode(("opencode:" + password).encode()).decode()
        requests = []

        class Handler(http.server.BaseHTTPRequestHandler):
            def result(self):
                body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
                requests.append((self.command, self.path, self.headers.get("Authorization"), body))
                self.send_response(200 if self.headers.get("Authorization") == expected else 401)
                self.end_headers()
                self.wfile.write(b"PUBLIC")

            do_GET = result
            do_POST = result

            def log_message(self, *args):
                pass

        server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            with tempfile.TemporaryDirectory() as tmp:
                folder = pathlib.Path(tmp)
                config = folder / "config"
                password_file = config / "opencode/server-password"
                password_file.parent.mkdir(parents=True)
                password_file.write_text(password)
                password_file.chmod(0o600)
                capture = folder / "argv.jsonl"
                fakecurl = folder / "curl"
                fakecurl.write_text(
                    "#!" + shutil.which("python3") + "\n"
                    "import json, os, subprocess, sys\n"
                    "config = sys.stdin.buffer.read()\n"
                    "with open(os.environ['ARGV_CAPTURE'], 'a') as out:\n"
                    "    out.write(json.dumps({'args': sys.argv[1:], 'noproxy': b'noproxy = \\\"*\\\"' in config}) + '\\n')\n"
                    "raise SystemExit(subprocess.run([os.environ['REAL_CURL'], *sys.argv[1:]], input=config).returncode)\n"
                )
                fakecurl.chmod(0o700)
                client = (ROOT / "bin/ai-glm").resolve(strict=True)
                self.assertEqual(client, ROOT / "bin/ai-glm")
                env = dict(
                    os.environ,
                    PATH=tmp + os.pathsep + os.environ["PATH"],
                    REAL_CURL=shutil.which("curl"),
                    ARGV_CAPTURE=str(capture),
                    AI_DEVOPS_CONFIG_DIR=str(config),
                    AI_GLM_STATE_DIR=str(folder / "state"),
                    AI_GLM_PORT=str(server.server_port),
                    AI_GLM_CALLER="codex",
                    PUBLIC_BODY='{"public":true}',
                    http_proxy="http://127.0.0.1:9",
                    HTTP_PROXY="http://127.0.0.1:9",
                    all_proxy="http://127.0.0.1:9",
                    ALL_PROXY="http://127.0.0.1:9",
                    no_proxy="",
                    NO_PROXY="",
                )
                script = (
                    'set -euo pipefail; source "$PUBLIC_CLIENT"; '
                    'test "$(api GET /global/health)" = PUBLIC; '
                    'test "$(api_code GET /global/health 3)" = 200; '
                    'permission_http POST /fixture-permission "$PUBLIC_BODY"; '
                    'test "$HTTP_STATUS" = 200; test "$HTTP_BODY" = PUBLIC'
                )
                env["PUBLIC_CLIENT"] = str(client)
                run = subprocess.run(
                    ["bash", "-c", script], env=env,
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=15,
                )
                self.assertEqual(run.returncode, 0, "actual GLM client auth paths failed")
                rows = [json.loads(line) for line in capture.read_text().splitlines()]
                self.assertEqual(len(rows), 3)
                for row in rows:
                    self.assertEqual(row["args"][:2], ["--config", "-"])
                    self.assertTrue(row["noproxy"])
                    self.assertFalse(any(
                        password in arg or expected in arg or arg in ("-u", "--user")
                        for arg in row["args"]
                    ))
                self.assertEqual(
                    requests,
                    [
                        ("GET", "/global/health", expected, b""),
                        ("GET", "/global/health", expected, b""),
                        ("POST", "/fixture-permission", expected, b'{"public":true}'),
                    ],
                )
        finally:
            server.shutdown()
            server.server_close()
            worker.join(timeout=2)

    def test_control_bytes_refuse_without_emitting_a_config(self):
        for bad in ("PUBLIC\nINJECTION", "PUBLIC\rINJECTION"):
            env = dict(os.environ, PUBLIC_PASSWORD=bad, PUBLIC_HELPER=str(ROOT / "tools/lib/opencode-curl-auth.sh"))
            result = subprocess.run(
                ["bash", "-c", 'source "$PUBLIC_HELPER"; opencode_curl_auth_config opencode "$PUBLIC_PASSWORD"'],
                env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, b"")

    def test_username_control_bytes_and_missing_fields_refuse(self):
        for user in ("PUBLIC\nINJECTION", "PUBLIC\rINJECTION"):
            env = dict(os.environ, PUBLIC_USER=user, PUBLIC_HELPER=str(ROOT / "tools/lib/opencode-curl-auth.sh"))
            result = subprocess.run(
                ["bash", "-c", 'source "$PUBLIC_HELPER"; opencode_curl_auth_config "$PUBLIC_USER" PUBLIC'],
                env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, b"")
        result = subprocess.run(
            ["bash", "-c", 'source "$1"; opencode_curl_auth_config PUBLIC', "fixture", str(ROOT / "tools/lib/opencode-curl-auth.sh")],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5,
        )
        self.assertEqual(result.returncode, 2)
        self.assertEqual(result.stdout, b"")


if __name__ == "__main__":
    unittest.main()
