#!/usr/bin/env node
// Same HTTP stack family as Claude Code (undici fetch) against a brotli mock
// through the DietCode proxy. Pass = JSON body, no content-encoding leaked.
import http from "node:http";
import zlib from "node:zlib";
import { setTimeout as sleep } from "node:timers/promises";

const UP = 18091;
const PX = 18092;

const payload = JSON.stringify({
  id: "msg_mock",
  type: "message",
  role: "assistant",
  content: [{ type: "text", text: "INTERCEPT_OK" }],
  model: "claude-opus-5-5",
  stop_reason: "end_turn",
  usage: { input_tokens: 1, output_tokens: 1 },
});

const packed = zlib.brotliCompressSync(Buffer.from(payload));

const upstream = http.createServer((req, res) => {
  res.writeHead(200, {
    "content-type": "application/json",
    "content-encoding": "br",
    "content-length": packed.length,
  });
  res.end(packed);
});

await new Promise((r) => upstream.listen(UP, "127.0.0.1", r));

const { spawn } = await import("node:child_process");
const proxy = spawn(
  "node",
  ["/home/ahazan/.local/lib/node_modules/dietcode/dist/bin/proxy.js", "--port", String(PX)],
  {
    env: {
      ...process.env,
      SCALEDOWN_API_KEY: "test-key-not-real",
      SCALEDOWN_PROXY_UPSTREAM: `http://127.0.0.1:${UP}`,
      SCALEDOWN_PROXY_DISABLE: "true",
    },
    stdio: ["ignore", "pipe", "pipe"],
  }
);
proxy.stderr.on("data", (d) => process.stderr.write(d));
await sleep(800);

try {
  const res = await fetch(`http://127.0.0.1:${PX}/v1/messages?beta=true`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      // Claude Code asks for brotli; this is the failing shape.
      "accept-encoding": "br, gzip",
    },
    body: JSON.stringify({
      model: "claude-opus-5-5",
      max_tokens: 16,
      messages: [{ role: "user", content: "hi" }],
    }),
  });
  const enc = res.headers.get("content-encoding");
  const text = await res.text();
  console.log("status", res.status);
  console.log("client_content_encoding", enc);
  console.log("body_prefix", text.slice(0, 120));
  if (enc && enc !== "identity") {
    console.log("FAIL_FORWARDED_CONTENT_ENCODING", enc);
    process.exitCode = 1;
  } else {
    const j = JSON.parse(text);
    console.log("json_ok", j.content);
    console.log("PASS_UNDICI_NO_BROTLI_BREAK");
  }
} catch (e) {
  console.log("FAIL", e && e.name, e && e.message);
  process.exitCode = 1;
} finally {
  proxy.kill();
  upstream.close();
}
