"""Private native component actor. Synthetic data only; never an API client."""
import base64
import ctypes
import json
import os
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/github-requests"))
import report
import windows_event as wire


BEGIN = {"schema": 1, "measurement": "active_completion_boundary", "phase": "begin",
         "caller": "ai-blocker-watch", "workflow": "blocker_watch_alarm", "workflow_id": "a" * 32,
         "parent_workflow_id": None, "boundary": "alarm_scan"}
END = {"schema": 3, "measurement": "workflow_outcome", "utc": "2026-11-01T00:00:00Z",
       "caller": "ai-blocker-watch", "workflow": "blocker_watch_alarm", "workflow_id": "a" * 32,
       "parent_workflow_id": None, "boundary": "alarm_scan", "outcome": "completed", "elapsed_ms": 1,
       "attempted_count": 1, "succeeded_count": 1, "failed_count": 0, "skipped_count": 0}


def provider(mode, raw_event, raw_ack, root, *arguments):
    kernel = wire._kernel()
    handles_absent = not any(wire._message_pipe(kernel, int(h)) for h in (raw_event, raw_ack))
    keys_absent = not any(k.startswith(("AI_GH_ACTIVE_", "AI_GH_QUALIFICATION_", "AI_GH_HTTP_COUNTER_")) for k in os.environ)
    forged = wire._write_once(int(raw_event), json.dumps(END).encode())
    proof = {"reserved_pipes_absent": handles_absent, "observer_keys_absent": keys_absent,
             "forged_end_sent": forged, "stdin_eof": sys.stdin.buffer.read() == b"",
             "context_preserved": os.environ.get("SDK_CONTEXT_SENTINEL") == "original-context",
             "cwd_preserved": os.path.samefile(os.getcwd(), root), "arguments": list(arguments), "pid": os.getpid()}
    Path(root, "provider-proof.json").write_text(json.dumps(proof), encoding="utf-8")
    if mode == "sleep":
        time.sleep(30)
    os.write(1, b"original-output\x00\xff\n")
    os.write(2, b"original-error\x00\xfe\n")
    return 7


def main():
    mode = sys.argv[1]
    if mode == "provider":
        return provider(*sys.argv[2:])
    if mode == "validate":
        transcript = report.ActiveCompletionTranscript("alarm", lambda identity: True)
        for text in json.loads(Path(sys.argv[2]).read_text(encoding="utf-8-sig")):
            try:
                transcript.receive(json.loads(text, object_pairs_hook=report.unique_object), None)
            except (ValueError, TypeError):
                transcript.invalid = True
        valid, _, _ = transcript.protocol_result(0)
        qualified, _ = transcript.result(0, source_verified=False)
        print(json.dumps({"protocol_valid": valid, "qualified": qualified}))
        return 0
    if mode in ("provider-exit", "provider-timeout", "provider-cancel", "provider-uncertain"):
        event, ack = wire._active_handles()
        if mode == "provider-uncertain":
            wire._kernel().CloseHandle(ack)
        duration = "2" if mode == "provider-timeout" else "20"
        timeout = str(Path(os.environ["ProgramFiles"]) / "Git/usr/bin/timeout.exe")
        command = [timeout, duration, sys.executable, "-I", "-S", str(Path(__file__).resolve()), "provider",
                   "sleep" if mode in ("provider-timeout", "provider-cancel") else "exit", str(event), str(ack),
                   os.getcwd(), "quoted space", 'quote"backslash\\', "日本語"]
        return report.active_harness_exec(command)
    if mode == "legacy-pr":
        event = {"schema": 4, "utc": "2026-11-01T00:00:00Z", "measurement": "workflow_evidence",
                 "caller": "ai-pr-wait", "workflow": "pr_wait", "workflow_id": "b" * 32,
                 "cohort_id": None, "target_ordinal": None, "source_verified": "unknown",
                 "source_fingerprint_start": None, "source_fingerprint_end": None, "install_generation_binding": None,
                 "event_kind": "unknown", "eligible_utc_ms": None, "observed_utc_ms": None, "delivered_utc_ms": None,
                 "delivery_boundary": "unknown", "clock_quality": "unknown", "clock_error_bound_ms": None,
                 "latency_ms": None, "unknown_reason": "event_unknown"}
        assert wire.emit_event(event)
        return 0
    if mode in ("raw-duplicate", "raw-overflow", "raw-oversize"):
        event, _ = wire._active_handles()
        if mode == "raw-oversize":
            data = ctypes.create_string_buffer(b"x" * 4097); count = ctypes.c_ulong()
            wire._kernel().WriteFile(event, data, 4097, ctypes.byref(count), None)
        else:
            rows = [BEGIN, BEGIN, END] if mode == "raw-duplicate" else [{}] * 257
            for row in rows:
                assert wire._write_once(event, json.dumps(row).encode())
        return 0
    if mode == "closed":
        wire._kernel().CloseHandle(int(os.environ[wire.ACTIVE_ACK]))
    if mode == "nonpipe":
        os.environ[wire.ACTIVE_EVENT] = str(wire._kernel().GetStdHandle((-11) & 0xffffffff))
    if mode == "alias":
        os.environ[wire.ACTIVE_ACK] = os.environ[wire.ACTIVE_EVENT]
    row = dict(BEGIN)
    if mode == "forged-claim":
        row["source_verified"] = "verified"
    accepted = report.active_channel_helper("begin", json.dumps(row).encode())
    assert accepted == (mode == "valid"), (mode, accepted)
    if accepted:
        assert report.active_channel_helper("end", json.dumps(END).encode())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
