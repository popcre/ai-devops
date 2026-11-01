#!/usr/bin/env python3
"""Explicit #658 Linux-observed Windows PR read; no Windows clock claim.

The opt-in read-only/no-stdin profile reserves SSH stdin for bounded custody
ACK/cancellation. Ordinary waiters and their input/output remain unchanged.
Original command output is byte-framed and forwarded without interpretation.
"""
from __future__ import annotations

import argparse
import base64
import ctypes
import hashlib
import json
import os
from pathlib import Path
import queue
import re
import selectors
import stat
import subprocess
import sys
import tempfile
import threading
import time

HERE = Path(__file__).resolve().parent
MAX_FRAME = 131072
START_KEYS = {"schema", "frame", "observer_run_id", "observer_arguments_sha256", "source_sha",
              "source_fingerprint", "source_scope", "execution_profile", "stdin_profile", "start_boundary"}


def get_report():
    if str(HERE) not in sys.path:
        sys.path.insert(0, str(HERE))
    import report
    return report


def loads(data):
    return json.loads(data, object_pairs_hook=get_report().unique_object)


def digest(value, size=64):
    return isinstance(value, str) and re.fullmatch(r"[a-f0-9]{%d}" % size, value) is not None


def valid_start(row, argument_hash):
    return (isinstance(row, dict) and set(row) == START_KEYS and type(row["schema"]) is int
            and row["schema"] == 1 and row["frame"] == "started"
            and digest(row["observer_run_id"], 32) and digest(row["source_sha"], 40)
            and digest(row["source_fingerprint"]) and row["observer_arguments_sha256"] == argument_hash
            and row["source_scope"] == "git_raw_bin_tools_config_v1"
            and row["execution_profile"] == "restricted_read"
            and row["start_boundary"] == "process_resumed"
            and row["stdin_profile"] == "read_only_no_stdin")


def valid_receipt(row, started):
    if not isinstance(row, dict) or not isinstance(started, dict):
        return False
    required = {"schema", "source_sha", "source_fingerprint", "loaded_source_fingerprint", "source_scope",
                "install_generation_binding", "source_boundary", "child_exit", "source_verified", "unknown_reason",
                "boundary_detail", "execution_profile", "clock_quality", "clock_error_bound_ms", "observer_run_id",
                "observer_arguments_sha256", "stdin_profile", "observer_event_json", "observer_event_status", "start_boundary"}
    return (set(row) == required and type(row["schema"]) is int and row["schema"] == 1
            and all(row[key] == started[key] for key in ("source_sha", "source_fingerprint", "source_scope",
                    "observer_run_id", "observer_arguments_sha256", "execution_profile", "stdin_profile", "start_boundary"))
            and digest(row["install_generation_binding"])
            and row["loaded_source_fingerprint"] == row["source_fingerprint"]
            and row["source_boundary"] == "windows_locked_generation"
            and type(row["child_exit"]) is int and -2147483648 <= row["child_exit"] <= 4294967295
            and row["source_verified"] in {"verified", "unknown"}
            and row["unknown_reason"] in {"none", "boundary_unavailable"}
            and row["boundary_detail"] in {"none", "privileged_original_context"}
            and (row["source_verified"] != "verified" or (row["unknown_reason"] == "none" and row["boundary_detail"] == "none"))
            and row["clock_quality"] == "unknown" and row["clock_error_bound_ms"] is None
            and row["observer_event_status"] in {"received", "unavailable", "invalid"}
            and (row["observer_event_json"] is None or (isinstance(row["observer_event_json"], str)
                 and len(row["observer_event_json"].encode("utf-8")) <= 4096)))


def valid_clock(value):
    return (isinstance(value, dict) and set(value) == {"wall_ms", "monotonic_ms", "error_bound_ms", "basis"}
            and all(type(value[key]) is int and value[key] >= 0 for key in ("wall_ms", "monotonic_ms", "error_bound_ms"))
            and value["error_bound_ms"] <= 59000 and value["basis"] == "linux_adjtimex_maxerror")


def qualify_remote_event(event, started_clock, received_clock, source_verified):
    """A conditional GitHub-UTC interval INCLUDING SSH delivery, never WinUTC."""
    result = {"clock_quality": "unknown", "unknown_reason": "clock_unknown", "event_kind": "unknown",
              "latency_lower_ms": None, "latency_upper_ms": None, "clock_error_bound_ms": None,
              "delivery_boundary": "linux_parent_received_over_ssh", "github_utc_assumption": True,
              "github_timestamp_resolution_ms": 1000, "start_boundary": "process_resumed"}
    if not source_verified:
        result["unknown_reason"] = "source_unknown"
        return result
    if not get_report().unqualified_event(event) or event["event_kind"] == "unknown" or event["delivery_boundary"] != "terminal_report":
        result["unknown_reason"] = "event_unknown"
        return result
    result["event_kind"] = event["event_kind"]
    if not valid_clock(started_clock) or not valid_clock(received_clock):
        return result
    wall = received_clock["wall_ms"] - started_clock["wall_ms"]
    mono = received_clock["monotonic_ms"] - started_clock["monotonic_ms"]
    error = started_clock["error_bound_ms"] + received_clock["error_bound_ms"] + 2
    if wall < 0 or mono < 0 or abs(wall - mono) > error:
        result["unknown_reason"] = "clock_jump"
        return result
    eligible = event["eligible_utc_ms"]
    # A start-frame receive is AFTER actual child resume. Requiring the event
    # later than its upper bound is deliberately conservative.
    if eligible <= started_clock["wall_ms"] + started_clock["error_bound_ms"]:
        result["unknown_reason"] = "event_before_observed_start"
        return result
    lower = received_clock["wall_ms"] - received_clock["error_bound_ms"] - eligible - 1000
    upper = received_clock["wall_ms"] + received_clock["error_bound_ms"] - eligible
    if upper < 0 or upper > 604800000 or error + 1000 > 60000:
        result["unknown_reason"] = "event_invalid"
        return result
    result.update(clock_quality="linux_observer_bound_github_utc_assumed", unknown_reason="none",
                  latency_lower_ms=max(0, lower), latency_upper_ms=upper, clock_error_bound_ms=error + 1000)
    return result


def frame(kind, **fields):
    return (json.dumps({"protocol": 1, "kind": kind, **fields}, separators=(",", ":"), ensure_ascii=True) + "\n").encode("ascii")


def parse_frame(line):
    if len(line) > MAX_FRAME or not line.endswith(b"\n"):
        raise ValueError("invalid observer frame length")
    row = loads(line)
    if not isinstance(row, dict) or type(row.get("protocol")) is not int or row["protocol"] != 1:
        raise ValueError("invalid observer protocol")
    kind = row.get("kind")
    expected = {"stdout": "data", "stderr": "data", "started": "record", "receipt": "record", "exit": "code"}
    if kind not in expected or set(row) != {"protocol", "kind", expected[kind]}:
        raise ValueError("invalid observer frame shape")
    if kind in {"stdout", "stderr"}:
        if not isinstance(row["data"], str):
            raise ValueError("invalid output frame")
        row["decoded"] = base64.b64decode(row["data"], validate=True)
        if len(row["decoded"]) > 8192:
            raise ValueError("oversized output frame")
    if kind == "exit" and (type(row["code"]) is not int or not -2147483648 <= row["code"] <= 4294967295):
        raise ValueError("invalid exit frame")
    return row


def _write_private(path, value):
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
    path = Path(path)
    parent = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        info = os.fstat(parent)
        if info.st_uid != os.getuid() or info.st_mode & 0o077 or not stat.S_ISDIR(info.st_mode):
            raise ValueError("private owned receipt directory required")
        descriptor = os.open(path.name, flags, 0o600, dir_fd=parent)
        with os.fdopen(descriptor, "wb") as output:
            output.write(json.dumps(value, sort_keys=True).encode("utf-8") + b"\n")
            output.flush()
            os.fsync(output.fileno())
    finally:
        os.close(parent)


def observe(command, arguments, receipt_path, timeout_seconds):
    """Linux parent; only live frames can produce this observer receipt."""
    if not sys.platform.startswith("linux"):
        raise ValueError("Linux parent clock required")
    argument_bytes = json.dumps(arguments, separators=(",", ":"), ensure_ascii=True).encode("ascii")
    argument_hash = hashlib.sha256(argument_bytes).hexdigest()
    child = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=None,
                             start_new_session=True)
    selector = selectors.DefaultSelector()
    selector.register(child.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + timeout_seconds
    pending = bytearray()
    started = start_clock = received = None
    got_receipt = False
    got_exit = False
    original_exit = None
    try:
        while time.monotonic() < deadline:
            if not selector.select(min(0.2, max(0, deadline - time.monotonic()))):
                if child.poll() is not None:
                    break
                continue
            chunk = os.read(child.stdout.fileno(), 8192)
            if not chunk:
                break
            pending.extend(chunk)
            if len(pending) > MAX_FRAME and b"\n" not in pending:
                raise ValueError("observer frame overflow")
            while b"\n" in pending:
                line, _, rest = pending.partition(b"\n")
                pending = bytearray(rest)
                row = parse_frame(bytes(line) + b"\n")
                if got_exit:
                    raise ValueError("observer frames after terminal exit")
                if row["kind"] in {"stdout", "stderr"}:
                    output = sys.stdout.buffer if row["kind"] == "stdout" else sys.stderr.buffer
                    output.write(row["decoded"])
                    output.flush()
                elif row["kind"] == "started":
                    if started is not None or got_receipt or not valid_start(row["record"], argument_hash):
                        raise ValueError("observer start unavailable")
                    start_clock = get_report().qualification_clock()
                    started = row["record"]
                elif row["kind"] == "receipt":
                    received = get_report().qualification_clock()  # BEFORE ACK, while source custody remains held.
                    source = row["record"]
                    if got_receipt or not valid_receipt(source, started):
                        raise ValueError("observer source receipt unavailable")
                    event = None
                    event_invalid = False
                    if source["observer_event_json"] is not None:
                        try:
                            event = loads(source["observer_event_json"])
                            if not get_report().unqualified_event(event):
                                event = None
                                event_invalid = True
                        except (ValueError, TypeError):
                            event_invalid = True
                    evidence = qualify_remote_event(event, start_clock, received, source["source_verified"] == "verified")
                    if event_invalid:
                        evidence["unknown_reason"] = "event_invalid"
                    result = {"schema": 1, "measurement": "linux_observed_windows_pr_wait", "source_receipt": source,
                              "started_clock": start_clock, "received_clock": received, "event_qualification": evidence,
                              "stdin_profile": "read_only_no_stdin", "transport": "ssh_included"}
                    try:
                        _write_private(receipt_path, result)
                    except (OSError, ValueError):
                        print("request observation: receipt unavailable; original command status preserved", file=sys.stderr)
                    got_receipt = True
                    child.stdin.write(frame("ack", observer_run_id=source["observer_run_id"]))
                    child.stdin.flush()
                    original_exit = source["child_exit"]
                elif row["kind"] == "exit":
                    got_exit = True
                    if original_exit is None:
                        original_exit = row["code"]
                    if row["code"] != original_exit:
                        raise ValueError("observer exit mismatch")
        if time.monotonic() >= deadline:
            raise TimeoutError("bounded remote observer deadline")
        code = child.wait(timeout=max(1, deadline - time.monotonic()))
        if pending or not got_exit or original_exit is None or code != original_exit:
            raise ValueError("observer transport ended without original exit")
        return original_exit
    finally:
        selector.close()
        if child.stdin:
            child.stdin.close()  # EOF requests native cleanup; never a second API operation.
        if child.stdout:
            child.stdout.close()
        if child.poll() is None:
            try:
                child.wait(timeout=10)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=5)


def _peek(stream):
    import msvcrt
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.PeekNamedPipe.argtypes = [ctypes.c_void_p, ctypes.c_void_p, ctypes.c_ulong,
                                    ctypes.c_void_p, ctypes.POINTER(ctypes.c_ulong), ctypes.c_void_p]
    available = ctypes.c_ulong()
    return available.value if kernel.PeekNamedPipe(msvcrt.get_osfhandle(stream.fileno()), None, 0, None,
                                                   ctypes.byref(available), None) else 0


def windows_controller(source_root, argument_bytes, timeout_seconds):
    """Windows native controller: stream bytes; hold receipt custody until Linux ACK."""
    import msvcrt
    arguments = loads(argument_bytes)
    if not isinstance(arguments, list) or any(not isinstance(value, str) for value in arguments):
        raise ValueError("read argument array required")
    receipt_read, receipt_write = os.pipe()
    ack_read, ack_write = os.pipe()
    receipt_handle, ack_handle = msvcrt.get_osfhandle(receipt_write), msvcrt.get_osfhandle(ack_read)
    os.set_handle_inheritable(receipt_handle, True)
    os.set_handle_inheritable(ack_handle, True)
    startup = subprocess.STARTUPINFO()
    startup.lpAttributeList = {"handle_list": [receipt_handle, ack_handle]}
    controls = queue.Queue()
    def control_reader():
        # Raw descriptor IO avoids a daemon holding CPython's buffered-stdin
        # lock during cancellation/interpreter shutdown.
        data = bytearray()
        try:
            while len(data) <= 1024 and b"\n" not in data:
                chunk = os.read(sys.stdin.fileno(), 1025 - len(data))
                if not chunk:
                    break
                data.extend(chunk)
            controls.put(bytes(data))
        except OSError:
            controls.put(b"")
    threading.Thread(target=control_reader, daemon=True).start()
    child = None
    reader = None
    with tempfile.TemporaryDirectory(prefix="ai-gh-observer-") as temporary:
        argument_file = Path(temporary) / "arguments.json"
        argument_file.write_bytes(argument_bytes)
        powershell = str(Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe")
        command = [powershell, "-NoProfile", "-File", str(HERE / "source_generation_windows.ps1"),
                   "-SourceRoot", source_root, "-EntryPoint", "bin/ai-pr-wait", "-ArgumentsFile", str(argument_file),
                   "-ReceiptHandle", str(receipt_handle), "-ReceiptAckHandle", str(ack_handle),
                   "-RestrictedReadProfile", "-ObserverEvents", "-ReadOnlyNoStdin"]
        try:
            child = subprocess.Popen(command, startupinfo=startup, close_fds=True, stdin=subprocess.DEVNULL,
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            os.close(receipt_write)
            os.close(ack_read)
            reader = os.fdopen(receipt_read, "rb", buffering=0)
            pending = bytearray()
            got_receipt = False
            deadline = time.monotonic() + timeout_seconds
            source = None
            def output_frames():
                for name, stream in (("stdout", child.stdout), ("stderr", child.stderr)):
                    while _peek(stream):
                        data = os.read(stream.fileno(), min(8192, _peek(stream)))
                        sys.stdout.buffer.write(frame(name, data=base64.b64encode(data).decode("ascii")))
                        sys.stdout.buffer.flush()
            while time.monotonic() < deadline:
                output_frames()
                available = _peek(reader)
                if available:
                    pending.extend(os.read(reader.fileno(), min(available, 8192)))
                    if len(pending) > MAX_FRAME:
                        raise ValueError("native receipt overflow")
                    while b"\n" in pending:
                        line, _, rest = pending.partition(b"\n")
                        pending = bytearray(rest)
                        record = loads(line)
                        if record.get("frame") == "started":
                            sys.stdout.buffer.write(frame("started", record=record))
                        else:
                            if got_receipt:
                                raise ValueError("duplicate native receipt")
                            # Child has exited. Drain its complete output BEFORE
                            # forwarding the final receipt on this ordered stream.
                            output_frames()
                            source = record
                            got_receipt = True
                            sys.stdout.buffer.write(frame("receipt", record=record))
                        sys.stdout.buffer.flush()
                if not controls.empty():
                    control = controls.get_nowait()
                    expected = {"protocol": 1, "kind": "ack", "observer_run_id": source["observer_run_id"]} if source else None
                    if not control or len(control) > 1024 or loads(control) != expected:
                        break
                    os.write(ack_write, b"\x01")
                if child.poll() is not None:
                    output_frames()
                    sys.stdout.buffer.write(frame("exit", code=child.returncode))
                    sys.stdout.buffer.flush()
                    return child.returncode
                time.sleep(0.005)
            sys.stdout.buffer.write(frame("exit", code=130))
            sys.stdout.buffer.flush()
            return 130
        finally:
            try:
                os.close(ack_write)  # native supervisor observes EOF and cleans up.
            except OSError:
                pass
            if child is not None and child.poll() is None:
                try:
                    child.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait(timeout=5)
            if reader is not None:
                reader.close()
            if child is not None:
                child.stdout.close()
                child.stderr.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--windows-controller", action="store_true")
    parser.add_argument("--host")
    parser.add_argument("--source-root", required=True)
    parser.add_argument("--receipt")
    parser.add_argument("--read-only-no-stdin", action="store_true", required=True)
    parser.add_argument("--timeout-seconds", type=int, default=3600)
    parser.add_argument("--arguments-base64")
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    options = parser.parse_args()
    if not 1 <= options.timeout_seconds <= 7200:
        parser.error("finite observer deadline required")
    if options.windows_controller:
        if os.name != "nt" or options.arguments_base64 is None:
            parser.error("native Windows controller required")
        return windows_controller(options.source_root, base64.b64decode(options.arguments_base64, validate=True), options.timeout_seconds)
    if not options.host or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,62}", options.host) or not options.receipt:
        parser.error("known SSH host and new private receipt destination required")
    if not re.fullmatch(r"[A-Za-z]:[/\\][A-Za-z0-9_./\\ -]+", options.source_root):
        parser.error("ordinary native Windows source path required")
    arguments = options.arguments[1:] if options.arguments[:1] == ["--"] else options.arguments
    payload = base64.b64encode(json.dumps(arguments, separators=(",", ":"), ensure_ascii=True).encode("ascii")).decode("ascii")
    remote_path = options.source_root.rstrip("/\\") + "/tools/github-requests/remote_wait.py"
    remote = subprocess.list2cmdline(["python.exe", "-I", remote_path, "--windows-controller", "--source-root", options.source_root,
                                     "--read-only-no-stdin", "--timeout-seconds", str(options.timeout_seconds), "--arguments-base64", payload])
    if any(os.environ.get(key) for key in ("LD_PRELOAD", "LD_LIBRARY_PATH", "PYTHONPATH", "PYTHONHOME")):
        parser.error("ambient source injection prevents observer qualification")
    ssh = get_report().trusted_boundary_executable("/usr/bin/ssh")
    command = [ssh, "-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=12", options.host, remote]
    return observe(command, arguments, options.receipt, options.timeout_seconds)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
    except TimeoutError:
        print("remote request observation canceled at deadline; no command replayed", file=sys.stderr)
        raise SystemExit(130)
    except (OSError, ValueError, subprocess.SubprocessError):
        print("remote request observation unavailable; no command replayed", file=sys.stderr)
        raise SystemExit(2)
