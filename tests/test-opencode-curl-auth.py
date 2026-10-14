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

    def test_control_bytes_refuse_without_emitting_a_config(self):
        for bad in ("PUBLIC\nINJECTION", "PUBLIC\rINJECTION"):
            env = dict(os.environ, PUBLIC_PASSWORD=bad, PUBLIC_HELPER=str(ROOT / "tools/lib/opencode-curl-auth.sh"))
            result = subprocess.run(
                ["bash", "-c", 'source "$PUBLIC_HELPER"; opencode_curl_auth_config opencode "$PUBLIC_PASSWORD"'],
                env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=5,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, b"")


if __name__ == "__main__":
    unittest.main()
