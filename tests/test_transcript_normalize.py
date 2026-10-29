#!/usr/bin/env python3
"""Transcript-store normalizer (plan step 2). Synthetic fixtures only."""

import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools" / "transcript_store"))
import normalize  # noqa: E402

LONG = "please look at the failing pipeline and tell me why it broke"


def claude_line(role, content, sid="sess-a", cwd="/home/u/repos/demo-app", ts="2026-10-01T00:00:00Z"):
    return json.dumps({"type": role, "sessionId": sid, "cwd": cwd, "timestamp": ts,
                       "message": {"role": role, "content": content}})


def write(tmp, name, lines, trailing_newline=True):
    p = Path(tmp) / name
    p.write_text("\n".join(lines) + ("\n" if trailing_newline else ""), encoding="utf-8")
    return p


# Fake secrets are assembled at runtime so this public file holds no
# secret-shaped literal.
def fake(prefix, n, ch="A"):
    return prefix + ch * n


POSITIVES = {
    "anthropic": fake("sk-" + "ant-", 24),
    "openai-style": fake("sk-", 20, "b"),
    "github": fake("gh" + "p_", 24),
    "github-pat": fake("github_" + "pat_", 24),
    "aws-key-id": fake("AK" + "IA", 16, "Q"),
    "aws-secret": "aws secret = " + "x" * 40,
    "dropbox": fake("sl" + ".", 110),
    "jwt": fake("ey" + "J", 24) + ".payloadpart",
    "pem": "-----BEGIN RSA PRIVATE " + "KEY-----\nabc\n-----END RSA PRIVATE " + "KEY-----",
    "op-ref": "op" + "://vault/item/field",
    "bearer": "Bearer " + "t" * 20,
    "key-value": "password=" + "p" * 14,
}
NEAR_MISSES = {
    "anthropic": "sk-" + "ant-short",
    "openai-style": "sk-" + "short",
    "github": "gh" + "x_" + "A" * 24,
    "github-pat": "github_" + "pat_short",
    "aws-key-id": "AK" + "IA" + "Q" * 10,
    "aws-secret": "aws secret = short",
    "dropbox": "sl" + "." + "A" * 20,
    "jwt": "ey" + "J" + "short.x",
    "pem": "-----BEGIN PUBLIC " + "KEY-----",
    "op-ref": "op" + ":/not-a-ref",
    "bearer": "bearer tok",
    "key-value": "password=" + "short",
}


class Redaction(unittest.TestCase):
    def test_every_kind_positive_and_near_miss(self):
        kinds = [k for k, _ in normalize.load_patterns()]
        self.assertEqual(set(kinds), set(POSITIVES))
        self.assertLess(kinds.index("anthropic"), kinds.index("openai-style"))
        for kind, text in POSITIVES.items():
            out, n = normalize.redact("x " + text + " y")
            self.assertGreaterEqual(n, 1, kind)
            self.assertIn("[REDACTED:", out, kind)
        for kind, text in NEAR_MISSES.items():
            out, n = normalize.redact("x " + text + " y")
            self.assertEqual(n, 0, f"{kind}: {out}")

    def test_anthropic_wins_over_openai(self):
        out, _ = normalize.redact(POSITIVES["anthropic"])
        self.assertEqual(out, "[REDACTED:anthropic]")

    def test_normalize_redacts_secrets(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = write(tmp, "s.jsonl", [claude_line("user", LONG + " here " + POSITIVES["github"])])
            r = normalize.parse_file(p)
            self.assertEqual(r["redactions"], 1)
            self.assertNotIn(POSITIVES["github"], r["turns"][0]["text"])
            self.assertIn("[REDACTED:github]", r["turns"][0]["text"])


class Parsing(unittest.TestCase):
    def test_claude_turns_tools_and_signature_skipped(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = write(tmp, "c.jsonl", [
                claude_line("user", LONG),
                claude_line("assistant", [
                    {"type": "thinking", "thinking": "reasoning about the pipeline issue", "signature": "SIGNATUREBLOB" * 5},
                    {"type": "text", "text": "I will run the test suite now to check it."},
                    {"type": "tool_use", "id": "t1", "name": "Bash", "input": {"command": "run the tests please"}},
                ]),
                claude_line("user", [{"type": "tool_result", "tool_use_id": "t1", "content": "HUGE TOOL OUTPUT DUMP"}]),
            ])
            r = normalize.parse_file(p)
            self.assertEqual([t["role"] for t in r["turns"]], ["user", "assistant"])
            a = r["turns"][1]
            self.assertEqual(a["tools"], ["Bash"])
            self.assertNotIn("SIGNATUREBLOB", a["text"])
            self.assertNotIn("HUGE TOOL OUTPUT", " ".join(t["text"] for t in r["turns"]))
            self.assertEqual(r["meta"]["session_id"], "sess-a")
            self.assertEqual(r["meta"]["repo"], "demo-app")

    def test_codex_turns_and_function_call(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = write(tmp, "x.jsonl", [
                json.dumps({"type": "session_meta", "payload": {"id": "codex-1", "cwd": "C:\\Users\\u\\repos\\Demo-Repo\\sub"}}),
                json.dumps({"type": "response_item", "timestamp": "2026-10-02T00:00:00Z",
                            "payload": {"type": "message", "role": "user", "content": [{"type": "input_text", "text": LONG}]}}),
                json.dumps({"type": "response_item", "payload": {"type": "function_call", "name": "shell",
                                                                 "arguments": "{\"cmd\": \"ls -la the folder\"}"}}),
                json.dumps({"type": "response_item", "payload": {"type": "function_call_output", "output": "OUTPUT DUMP " * 10}}),
                json.dumps({"type": "response_item", "payload": {"type": "reasoning", "encrypted_content": "ENC" * 20}}),
            ])
            r = normalize.parse_file(p)
            self.assertEqual(r["meta"]["session_id"], "codex-1")
            self.assertEqual(r["meta"]["repo"], "demo-repo")
            self.assertEqual(len(r["turns"]), 2)
            self.assertEqual(r["turns"][1]["tools"], ["shell"])
            self.assertNotIn("OUTPUT DUMP", r["turns"][1]["text"])

    def test_short_turns_skipped_and_cap(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = write(tmp, "c.jsonl", [claude_line("user", "ok"), claude_line("assistant", "y" * 9000)])
            r = normalize.parse_file(p)
            self.assertEqual(len(r["turns"]), 1)
            self.assertEqual(len(r["turns"][0]["text"]), normalize.MAX_TURN_CHARS)

    def test_normalize_skips_malformed_lines(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = write(tmp, "c.jsonl", [claude_line("user", LONG), "{not json", "[1, 2, 3]", "42",
                                       claude_line("assistant", LONG + " answer")])
            r = normalize.parse_file(p)
            self.assertEqual(r["bad_lines"], 3)
            self.assertEqual(len(r["turns"]), 2)
            self.assertFalse(r["truncated_tail"])

    def test_truncated_last_line_not_consumed(self):
        with tempfile.TemporaryDirectory() as tmp:
            full = claude_line("assistant", LONG + " second")
            p = write(tmp, "c.jsonl", [claude_line("user", LONG), full[:30]], trailing_newline=False)
            r = normalize.parse_file(p)
            self.assertTrue(r["truncated_tail"])
            self.assertEqual(r["bad_lines"], 0)
            self.assertEqual(r["bytes_parsed"], len(claude_line("user", LONG).encode()) + 1)


class Repo(unittest.TestCase):
    def test_rules(self):
        cases = {
            "C:\\Users\\ahazan\\repos\\ai-devops": "ai-devops",
            "/home/ahazan/repos/designflow-frontend": "designflow-frontend",
            "/home/ahazan/repos/ai-devops/.claude/worktrees/x": "ai-devops",
            "/srv/x/.codex/worktrees/abc/repos/zzz": "unknown",
            "/worksp/popdam/worktrees/feat": "popdam",
            "/home/u/src/tool-one/": "tool-one",
            "-home-ahazan-repos-ai-devops--claude-worktrees-x": "ai-devops",
            "-worksp-popdam--claude-worktrees-x": "popdam",
            "/home/ahazan": "unknown",
            "/tmp": "unknown",
            "/var/tmp/scratch": "unknown",
            None: "unknown",
        }
        for cwd, want in cases.items():
            self.assertEqual(normalize.derive_repo(cwd), want, cwd)


class Lineage(unittest.TestCase):
    def test_forks_share_opening_and_unrelated_continue_both_kept(self):
        opening = [claude_line("user", LONG + f" step {i}") for i in range(3)]
        with tempfile.TemporaryDirectory() as tmp:
            a = normalize.parse_file(write(tmp, "a.jsonl", opening + [claude_line("user", "continue with the next item")]))
            b = normalize.parse_file(write(tmp, "b.jsonl", opening + [claude_line("user", "a different follow up request")]))
            c = normalize.parse_file(write(tmp, "c.jsonl", [claude_line("user", "unrelated session opening text"),
                                                           claude_line("user", "continue with the next item")]))
            self.assertEqual(normalize.lineage_key(a["turns"]), normalize.lineage_key(b["turns"]))
            self.assertNotEqual(normalize.lineage_key(a["turns"]), normalize.lineage_key(c["turns"]))
            # same "continue" turn hash, but different lineages -> different turn keys
            self.assertEqual(a["turns"][-1]["turn_hash"], c["turns"][-1]["turn_hash"])

    def test_repeated_turn_occurrences(self):
        with tempfile.TemporaryDirectory() as tmp:
            r = normalize.parse_file(write(tmp, "a.jsonl", [claude_line("user", "continue with the next item")] * 3))
            self.assertEqual([t["occurrence_no"] for t in r["turns"]], [1, 2, 3])

    def test_turn_hash_whitespace_normalized(self):
        self.assertEqual(normalize.turn_hash("user", "a  b\n c "), normalize.turn_hash("user", "a b c"))


if __name__ == "__main__":
    unittest.main(verbosity=1)
