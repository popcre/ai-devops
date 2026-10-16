"""Pinned OpenCode tool-path fixture: isolated loopback transport, NO real model.

The outer test uses a new network namespace and hides the real home/temp roots.
No production origin receipt/admission is created. This is a source test only.
"""
import argparse
import base64
import math
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def outer():
    if not sys.platform.startswith("linux") or not shutil.which("bwrap"):
        raise RuntimeError("pinned fixture requires Linux bubblewrap; do not run unisolated")
    pin = (ROOT / "config/opencode/version").read_text().strip()
    binary = Path.home() / f".local/lib/ai-devops/opencode/{pin}/node_modules/opencode-ai/bin/opencode.exe"
    if not binary.is_file():
        raise RuntimeError("pinned runtime unavailable; no download or provider call attempted")
    with tempfile.TemporaryDirectory(prefix="glm-pinned-fixture-") as temporary:
        scratch = Path(temporary).resolve()
        parent_netns = os.readlink("/proc/self/ns/net")
        command = ["bwrap", "--unshare-net", "--die-with-parent", "--new-session", "--ro-bind", "/", "/",
                   "--tmpfs", str(Path.home()), "--tmpfs", "/tmp", "--proc", "/proc", "--dev", "/dev",
                   "--ro-bind", str(ROOT), str(ROOT), "--ro-bind", str(binary.parent.parent), str(binary.parent.parent),
                   "--bind", str(scratch), str(scratch), "--chdir", str(scratch),
                   "--clearenv", "--setenv", "PATH", os.environ.get("PATH", "/usr/bin:/bin"),
                   sys.executable, str(Path(__file__).resolve()), "--isolated", "--scratch", str(scratch),
                   "--binary", str(binary), "--parent-netns", parent_netns]
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=120)
        print(result.stdout.decode(), end="")
        if result.returncode:
            print(result.stderr.decode()[-3000:], file=sys.stderr)
            raise RuntimeError("pinned isolated fixture failed")


def isolated(args):
    assert os.readlink("/proc/self/ns/net") != args.parent_netns, "network isolation missing"
    assert not any(key in os.environ for key in ["ZAI_API_KEY", "OPENAI_API_KEY", "OP_SERVICE_ACCOUNT_TOKEN"])
    # There is no external interface/route in this namespace. No real key files
    # are visible: actual home is tmpfs except the exact source and pinned runtime.
    for line in Path("/proc/net/route").read_text().splitlines()[1:]:
        assert line.split()[0] == "lo", "external network route present"
    scratch = Path(args.scratch)
    repo = scratch / "repository"
    repo.mkdir(); subprocess.run(["git", "init", "-q", str(repo)], check=True)
    seed = repo / "invented.txt"
    seed.write_bytes(("".join(f"LINE {number:04d} invented α漢字🙂 evidence \\\"\t" + "x" * 270 + "\r\n"
                             for number in range(300))).encode())
    config = scratch / "config/opencode"
    (config / "agent").mkdir(parents=True)
    data = scratch / "data"
    data.mkdir()
    calls = []
    shared = {"phase": 0, "mirror": None, "view_rows": 0, "foreign_output": None,
              "foreign_phase": 0, "probe_phase": 0}
    foreign_repo = scratch / "foreign-repository"
    foreign_repo.mkdir(); subprocess.run(["git", "init", "-q", str(foreign_repo)], check=True)
    foreign_seed = foreign_repo / "invented-foreign.txt"
    foreign_seed.write_bytes(seed.read_bytes())

    class FakeTransport(BaseHTTPRequestHandler):
        def log_message(self, *_): pass
        def do_POST(self):
            request = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            assert self.path == "/v1/chat/completions", self.path
            calls.append(request)
            encoded_request = json.dumps(request)
            arguments = None
            if "FOREIGN DENIAL PROBE" in encoded_request:
                shared["probe_phase"] += 1
                phase = 100 + shared["probe_phase"]
                path = shared["foreign_output"] if shared["probe_phase"] == 1 else None
            elif "FOREIGN PRODUCER" in encoded_request:
                shared["foreign_phase"] += 1
                phase = 200 + shared["foreign_phase"]
                path = str(foreign_seed) if shared["foreign_phase"] == 1 else None
            else:
                shared["phase"] += 1
                phase = shared["phase"]
                path = None
            if phase == 1:
                path = str(seed)
            elif phase == 2:
                text = json.dumps(request)
                found = re.findall(r"(/[^\s\"\\]*tool-output/tool_[A-Za-z0-9_-]+)", text)
                assert found, "actual tool did not expose a managed output path"
                path = found[-1]
            elif 4 <= phase < 4 + math.ceil(shared["view_rows"] / 20):
                assert shared["mirror"]
                path = shared["mirror"]
                arguments = {"path": path, "offset": 1 + (phase - 4) * 20, "limit": 20}
            if path:
                delta = {"role": "assistant", "tool_calls": [{"index": 0, "id": f"fixture_call_{phase}",
                    "type": "function", "function": {"name": "read", "arguments": json.dumps(arguments or {"path": path})}}]}
                finish = "tool_calls"
            else:
                delta = {"role": "assistant", "content": "Fixture intermediate stop" if phase == 3 else "Fixture complete"}
                finish = "stop"
            chunks = [{"id": f"fixture_{phase}", "object": "chat.completion.chunk", "created": 1,
                       "model": "test", "choices": [{"index": 0, "delta": delta, "finish_reason": None}]},
                      {"id": f"fixture_{phase}", "object": "chat.completion.chunk", "created": 1,
                       "model": "test", "choices": [{"index": 0, "delta": {}, "finish_reason": finish}],
                       "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}}]
            self.send_response(200); self.send_header("Content-Type", "text/event-stream"); self.end_headers()
            for item in chunks:
                self.wfile.write(("data: " + json.dumps(item) + "\n\n").encode())
            self.wfile.write(b"data: [DONE]\n\n"); self.wfile.flush()

    fake = ThreadingHTTPServer(("127.0.0.1", 0), FakeTransport)
    threading.Thread(target=fake.serve_forever, daemon=True).start()
    settings = {"model": "fixture/test", "small_model": "fixture/test", "share": "disabled", "autoupdate": False,
                "plugin": [], "mcp": {}, "permission": {"read": "allow", "external_directory": "ask"},
                "provider": {"fixture": {"npm": "@ai-sdk/openai-compatible", "name": "Loopback fixture",
                    "options": {"baseURL": f"http://127.0.0.1:{fake.server_port}/v1", "apiKey": "public-fixture-not-a-real-key"},
                    "models": {"test": {"name": "Fixture", "limit": {"context": 200000, "output": 8192}}}}}}
    (config / "opencode.json").write_text(json.dumps(settings))
    agent = (ROOT / "config/opencode/agent/glm-review.md").read_text().replace("zai-coding-plan/glm-5.3", "fixture/test")
    (config / "agent/glm-review.md").write_text(agent)
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0)); port = probe.getsockname()[1]
    environment = {"PATH": os.environ["PATH"], "XDG_CONFIG_HOME": str(config.parent),
                   "XDG_DATA_HOME": str(data), "XDG_STATE_HOME": str(scratch / "state"),
                   "XDG_CACHE_HOME": str(scratch / "cache"), "OPENCODE_CONFIG": str(config / "opencode.json"),
                   "OPENCODE_DISABLE_PROJECT_CONFIG": "true", "OPENCODE_DISABLE_DEFAULT_PLUGINS": "true",
                   "OPENCODE_DISABLE_MODELS_FETCH": "true", "OPENCODE_SERVER_PASSWORD": "public-fixture-password"}
    log = (scratch / "server.log").open("wb")
    process = subprocess.Popen([args.binary, "serve", "--hostname", "127.0.0.1", "--port", str(port)],
                               env=environment, stdout=log, stderr=log)
    try:
        def api(method, path, body=None):
            request = urllib.request.Request(f"http://127.0.0.1:{port}" + path,
                data=json.dumps(body).encode() if body is not None else None, method=method,
                headers={"Authorization": "Basic " + base64.b64encode(b"opencode:public-fixture-password").decode(),
                         "Content-Type": "application/json"})
            with urllib.request.urlopen(request, timeout=10) as response:
                raw = response.read()
            return json.loads(raw) if raw else None
        def wait(predicate):
            deadline = time.monotonic() + 40
            while time.monotonic() < deadline:
                try:
                    value = predicate()
                    if value: return value
                except (urllib.error.URLError, ConnectionError, TimeoutError):
                    pass
                if process.poll() is not None:
                    raise RuntimeError("pinned fixture server exited: " + (scratch / "server.log").read_text()[-2000:])
                time.sleep(0.05)
            raise RuntimeError("bounded pinned fixture wait expired: " + (scratch / "server.log").read_text()[-3000:])
        wait(lambda: api("GET", "/global/health"))
        foreign = api("POST", "/session?directory=" + urllib.parse.quote(str(foreign_repo)),
                      {"title": "invented foreign producer", "agent": "glm-review",
                       "model": {"providerID": "fixture", "id": "test"}})["id"]
        api("POST", f"/api/session/{foreign}/prompt", {"prompt": {"text": "FOREIGN PRODUCER invented only"}})
        wait(lambda: next((message for message in api("GET", f"/api/session/{foreign}/message?limit=1")["data"]
                           if message.get("finish") == "stop"), None))
        foreign_messages = api("GET", f"/api/session/{foreign}/message?limit=200")["data"]
        foreign_outputs = [path for message in foreign_messages for tool in message.get("content", [])
                           for path in tool.get("state", {}).get("outputPaths", [])]
        assert len(foreign_outputs) == 1
        shared["foreign_output"] = foreign_outputs[0]
        session = api("POST", "/session?directory=" + urllib.parse.quote(str(repo)),
                      {"title": "invented local tool fixture", "agent": "glm-review",
                       "model": {"providerID": "fixture", "id": "test"}})["id"]
        api("POST", f"/api/session/{session}/prompt", {"prompt": {"text": "Read invented fixture only."}})
        permission = wait(lambda: (api("GET", f"/api/session/{session}/permission") or {}).get("data"))
        assert len(permission) == 1 and permission[0]["action"] == "external_directory"
        messages = api("GET", f"/api/session/{session}/message?limit=200")["data"]
        completed = [tool for message in messages for tool in message.get("content", [])
                     if tool.get("type") == "tool" and tool.get("state", {}).get("status") == "completed"]
        output = [path for tool in completed for path in tool["state"].get("outputPaths", [])]
        assert len(output) == 1 and Path(output[0]).parent == data / "opencode/tool-output"
        pending = [tool for message in messages for tool in message.get("content", [])
                   if tool.get("id") == permission[0]["source"]["callID"]]
        assert len(pending) == 1 and pending[0]["state"]["input"]["path"] == output[0]
        assert completed[0]["name"] == pending[0]["name"] == "read"
        assert completed[0]["provider"]["executed"] is False and pending[0]["provider"]["executed"] is False
        own_assistants = [message for message in messages if message.get("type") == "assistant"]
        assert own_assistants and all(message["agent"] == "glm-review"
                                     and message["model"]["id"] == "test"
                                     and message["model"]["providerID"] == "fixture"
                                     for message in own_assistants)
        assert type(completed[0]["time"]["completed"]) is int and type(pending[0]["time"]["ran"]) is int
        print(json.dumps({"actual_tool_time_schema": {
            "completed": completed[0].get("time"), "pending": pending[0].get("time")}}, sort_keys=True))
        api("POST", f"/api/session/{session}/permission/{permission[0]['id']}/reply",
            {"reply": "reject", "message": "Own output must use a private copy; no external access."})
        sys.path.insert(0, str(ROOT / "tools"))
        import glm_output_recovery
        record = {"version": "fixture-only-not-an-admission", "run": "f" * 32,
                  "source_path": output[0], "original_read_path": str(seed),
                  "originating_call_id": completed[0]["id"],
                  "boundary": str(repo), "deadline_epoch": int(time.time()) + 60}
        mirror = glm_output_recovery.mirror(record)
        assert Path(mirror["destination"]).read_bytes() == Path(output[0]).read_bytes()
        shared["mirror"] = mirror["readable_view"]
        shared["view_rows"] = mirror["view_rows"]
        wait(lambda: next((message for message in api("GET", f"/api/session/{session}/message?limit=1")["data"]
                           if message.get("finish") == "stop"), None))
        api("POST", f"/api/session/{session}/prompt", {"prompt": {"text": "Read exact invented private copy: " + shared["mirror"]}})
        page_count = math.ceil(mirror["view_rows"] / 20)
        wait(lambda: shared["phase"] >= 4 + page_count and next((message for message in api("GET", f"/api/session/{session}/message?limit=1")["data"]
                           if message.get("finish") == "stop"), None))
        final = api("GET", f"/api/session/{session}/message?limit=200")["data"]
        native_stops = [message for message in final if message.get("finish") == "stop"]
        print(json.dumps({"actual_native_completion_identity": [
            {key: message.get(key) for key in ("id", "sessionID", "sessionId", "session_id", "agent", "model", "finish", "role")}
            for message in native_stops]}, sort_keys=True))
        assert native_stops and all(message.get("agent") == "glm-review"
            and message.get("model", {}).get("providerID") == "fixture"
            and message.get("model", {}).get("id") == "test"
            and message.get("id") and not message.get("error") for message in native_stops), \
            "native completion identity differs from readiness protocol"
        own_latest = api("GET", f"/api/session/{session}/message?limit=1")["data"]
        assert len(own_latest) == 1 and own_latest[0] == native_stops[0]
        binary_bytes = Path(args.binary).read_bytes()
        assert re.search(rb"zai-coding-plan.{0,500}ZHIPU_API_KEY", binary_bytes)
        assert b"ZAI_API_KEY" not in binary_bytes, "pinned provider credential table changed"
        mirror_reads = [tool for message in final for tool in message.get("content", [])
                        if tool.get("type") == "tool" and tool.get("state", {}).get("input", {}).get("path") == shared["mirror"]]
        assert len(mirror_reads) == page_count and all(tool["state"]["status"] == "completed" for tool in mirror_reads)
        mirror_reads.sort(key=lambda tool: tool["state"]["input"]["offset"])
        read_lines = []
        for tool in mirror_reads:
            assert not tool["state"].get("outputPaths"), "ordinary paging recursively spilled"
            content = tool["state"]["structured"]["content"]
            read_lines.extend(content.splitlines())
        reconstructed_view = ("\n".join(read_lines) + "\n").encode()
        assert reconstructed_view == Path(mirror["readable_view"]).read_bytes(), "not all view bytes were read"
        rows = [json.loads(line) for line in read_lines]
        original_content = json.loads(Path(output[0]).read_bytes())["content"]
        restored_content = "".join(row["text"] for row in rows if row["kind"] == "original-content-segment")
        assert restored_content == original_content
        assert hashlib.sha256(restored_content.encode()).hexdigest() == mirror["content_sha256"]
        probe = api("POST", "/session?directory=" + urllib.parse.quote(str(repo)),
                    {"title": "invented foreign denial probe", "agent": "glm-review",
                     "model": {"providerID": "fixture", "id": "test"}})["id"]
        api("POST", f"/api/session/{probe}/prompt", {"prompt": {"text": "FOREIGN DENIAL PROBE invented only"}})
        denied = wait(lambda: (api("GET", f"/api/session/{probe}/permission") or {}).get("data"))
        assert len(denied) == 1 and denied[0]["action"] == "external_directory"
        foreign_latest = api("GET", f"/api/session/{probe}/message?limit=1")["data"]
        assert len(foreign_latest) == 1 and foreign_latest[0] != own_latest[0]
        probe_messages = api("GET", f"/api/session/{probe}/message?limit=200")["data"]
        assert not any(tool.get("state", {}).get("outputPaths") for message in probe_messages for tool in message.get("content", []))
        api("POST", f"/api/session/{probe}/permission/{denied[0]['id']}/reply",
            {"reply": "reject", "message": "Other session output is forbidden."})
        wait(lambda: shared["probe_phase"] == 2 and next((message for message in api("GET", f"/api/session/{probe}/message?limit=1")["data"]
                           if message.get("finish") == "stop"), None))
        result = {"fixture": "pinned-local-no-real-model", "binary_sha256": hashlib.file_digest(open(args.binary, "rb"), "sha256").hexdigest(),
                  "network_namespace_isolated": True, "real_keys_loaded": False,
                  "own_original_bytes": mirror["bytes"], "own_original_sha256": mirror["sha256"],
                  "private_git_read_completed": True, "all_view_pages_read": page_count,
                  "view_reconstructed_byte_exact": True, "original_content_reconstructed_byte_exact": True,
                  "original_page_truncated": mirror["original_page_truncated"],
                  "sibling_other_session_permission_rejected": True, "production_origin_issued": False,
                  "config_generated_top_entries": sorted(path.name for path in config.iterdir()),
                  "fake_transport_requests": len(calls), "native_completion_identity_verified": True,
                  "pinned_coding_plan_credential_variable": "ZHIPU_API_KEY"}
        result["native_own_endpoint_and_foreign_identity_distinct"] = True
        print(json.dumps(result, sort_keys=True))
    finally:
        process.terminate()
        try: process.wait(timeout=5)
        except subprocess.TimeoutExpired: process.kill(); process.wait()
        fake.shutdown(); log.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--isolated", action="store_true")
    parser.add_argument("--scratch")
    parser.add_argument("--binary")
    parser.add_argument("--parent-netns")
    arguments = parser.parse_args()
    isolated(arguments) if arguments.isolated else outer()
