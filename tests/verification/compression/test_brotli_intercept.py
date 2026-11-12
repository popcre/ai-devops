#!/usr/bin/env python3
"""Prove DietCode proxy no longer Brotli-breaks the client (run on edge-dev3)."""
from __future__ import annotations

import http.server
import json
import os
import subprocess
import threading
import time
import urllib.request

UPSTREAM_PORT = 18081
PROXY_PORT = 18082
DIETCODE_PROXY_JS = "/home/ahazan/.local/lib/node_modules/dietcode/dist/bin/proxy.js"


def brotli_compress(data: bytes) -> bytes:
    import tempfile

    with tempfile.NamedTemporaryFile(delete=False) as inf, tempfile.NamedTemporaryFile(
        delete=False
    ) as outf:
        inf.write(data)
        in_path, out_path = inf.name, outf.name
    subprocess.check_call(
        [
            "node",
            "-e",
            "const z=require('zlib');const fs=require('fs');"
            "fs.writeFileSync(process.argv[2], z.brotliCompressSync(fs.readFileSync(process.argv[1])));",
            in_path,
            out_path,
        ]
    )
    with open(out_path, "rb") as fh:
        return fh.read()


class Upstream(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        return

    def do_POST(self):
        body = json.dumps(
            {
                "id": "msg_mock",
                "type": "message",
                "role": "assistant",
                "content": [{"type": "text", "text": "INTERCEPT_OK"}],
                "model": "claude-opus-5-5",
                "stop_reason": "end_turn",
                "usage": {"input_tokens": 1, "output_tokens": 1},
            }
        ).encode()
        packed = brotli_compress(body)
        self.send_response(200)
        self.send_header("content-type", "application/json")
        self.send_header("content-encoding", "br")
        self.send_header("content-length", str(len(packed)))
        self.end_headers()
        self.wfile.write(packed)


def main() -> int:
    httpd = http.server.ThreadingHTTPServer(("127.0.0.1", UPSTREAM_PORT), Upstream)
    threading.Thread(target=httpd.serve_forever, daemon=True).start()

    env = os.environ.copy()
    env["SCALEDOWN_API_KEY"] = "test-key-not-real"
    env["SCALEDOWN_PROXY_UPSTREAM"] = f"http://127.0.0.1:{UPSTREAM_PORT}"
    env["SCALEDOWN_PROXY_DISABLE"] = "true"
    proc = subprocess.Popen(
        ["node", DIETCODE_PROXY_JS, "--port", str(PROXY_PORT)],
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    time.sleep(1.0)

    try:
        req = urllib.request.Request(
            f"http://127.0.0.1:{PROXY_PORT}/v1/messages?beta=true",
            data=json.dumps(
                {
                    "model": "claude-opus-5-5",
                    "max_tokens": 16,
                    "messages": [{"role": "user", "content": "hi"}],
                }
            ).encode(),
            method="POST",
            headers={"content-type": "application/json", "accept-encoding": "br, gzip"},
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            enc = (resp.headers.get("content-encoding") or "").strip()
            raw = resp.read()
            print("client_content_encoding", repr(enc))
            print("client_bytes", len(raw))
            if enc and enc not in ("identity", ""):
                print("FAIL_FORWARDED_CONTENT_ENCODING", enc)
                return 1
            decoded = json.loads(raw)
            print("json_ok", decoded.get("content"))
            print("PASS_NO_BROTLI_BREAK")
            return 0
    except Exception as exc:  # noqa: BLE001
        print("FAIL", type(exc).__name__, exc)
        return 1
    finally:
        proc.kill()
        httpd.shutdown()


if __name__ == "__main__":
    raise SystemExit(main())
