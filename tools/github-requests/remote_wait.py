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
import threading
import time
import uuid

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


def valid_start(row, argument_hash, active_completion=False, sdk_coordinator=False):
    return (isinstance(row, dict) and set(row) == START_KEYS and type(row["schema"]) is int
            and row["schema"] == 1 and row["frame"] == "started"
            and digest(row["observer_run_id"], 32) and digest(row["source_sha"], 40)
            and digest(row["source_fingerprint"]) and row["observer_arguments_sha256"] == argument_hash
            and row["source_scope"] == "git_raw_bin_tools_config_v1"
            and row["execution_profile"] == ("active_sdk_coordinator" if sdk_coordinator else "original_active" if active_completion else "restricted_read")
            and row["start_boundary"] == "process_resumed"
            and row["stdin_profile"] == ("active_no_stdin" if active_completion else "read_only_no_stdin"))


def valid_counter_binding(row, expected_hash):
    keys = {"schema", "manifest_sha256", "image_sha256", "counter_source_fingerprint", "runtime_version",
            "ordinary_image_sha256", "closure_entry", "scope", "http_requests", "graphql_operations", "qualification_only"}
    return (isinstance(row, dict) and set(row) == keys and type(row["schema"]) is int and row["schema"] == 1
            and digest(expected_hash) and row["manifest_sha256"] == expected_hash
            and all(digest(row[key]) for key in ("image_sha256", "counter_source_fingerprint", "ordinary_image_sha256"))
            and isinstance(row["runtime_version"], str) and re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", row["runtime_version"]) is not None
            and row["closure_entry"] == "extra/counter.exe" and row["scope"] == "primary_constructor_subset"
            and row["http_requests"] is None and row["graphql_operations"] is None and row["qualification_only"] is True)


def counter_aggregate(raw):
    """One existing numeric-only validator; never transmit raw child pipe data."""
    location = str(HERE / "instrumented-gh")
    if location not in sys.path:
        sys.path.insert(0, location)
    from managed_read import aggregate_invocations
    return aggregate_invocations(raw.encode("utf-8") if isinstance(raw, str) else b"")


def valid_counter_measurement(row):
    unknown = counter_aggregate(None)
    if not isinstance(row, dict) or set(row) != set(unknown) or type(row["complete"]) is not bool:
        return False
    if row == unknown:
        return True
    return (row["measurement"] == unknown["measurement"] and row["http_requests"] is None
            and row["complete"] is True and type(row["counted_invocations"]) is int and 1 <= row["counted_invocations"] <= 64
            and row["failed_write_attempts"] == 0
            and all(type(row[key]) is int and 0 <= row[key] <= 64000000000 for key in
                    ("observed_completed_writes", "failed_write_attempts", "observed_external_writes")))


def valid_receipt(row, started, expected_counter_hash=None, active_completion=False):
    if not isinstance(row, dict) or not isinstance(started, dict):
        return False
    required = {"schema", "source_sha", "source_fingerprint", "loaded_source_fingerprint", "source_scope",
                "install_generation_binding", "source_boundary", "child_exit", "source_verified", "unknown_reason",
                "boundary_detail", "execution_profile", "clock_quality", "clock_error_bound_ms", "observer_run_id",
                "observer_arguments_sha256", "stdin_profile", "observer_event_json", "observer_event_status", "start_boundary"}
    if expected_counter_hash is not None:
        required |= {"counter_binding", "counter_measurement"}
        if not valid_counter_binding(row.get("counter_binding"), expected_counter_hash) or not valid_counter_measurement(row.get("counter_measurement")):
            return False
    if active_completion:
        required.add("active_channel_status")
        if row.get("active_channel_status") not in {"valid", "invalid"}:
            return False
        if started.get("execution_profile") == "original_active" and row.get("source_verified") != "unknown":
            return False
    return (set(row) == required and type(row["schema"]) is int and row["schema"] == 1
            and all(row[key] == started[key] for key in ("source_sha", "source_fingerprint", "source_scope",
                    "observer_run_id", "observer_arguments_sha256", "execution_profile", "stdin_profile", "start_boundary"))
            and digest(row["install_generation_binding"])
            and row["loaded_source_fingerprint"] == row["source_fingerprint"]
            and row["source_boundary"] == "windows_locked_generation"
            and type(row["child_exit"]) is int and -2147483648 <= row["child_exit"] <= 4294967295
            and row["source_verified"] in {"verified", "unknown"}
            and row["unknown_reason"] in {"none", "boundary_unavailable"}
            and row["boundary_detail"] in ({"none", "privileged_original_context", "active_original_context_unqualified"}
                                           if active_completion else {"none", "privileged_original_context"})
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
    expected = {"stdout": "data", "stderr": "data", "started": "record", "receipt": "record", "exit": "code", "active": "record", "cleanup": "record"}
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


def _send_active_control(stream, data):
    """One atomic nonblocking write to this observer's OWN Linux control pipe."""
    if not isinstance(data, bytes) or not 0 < len(data) <= 4096:
        return False
    try:
        descriptor = stream.fileno()
        if (os.get_blocking(descriptor) or not stat.S_ISFIFO(os.fstat(descriptor).st_mode)
                or len(data) > os.fpathconf(descriptor, "PC_PIPE_BUF")):
            return False
        return os.write(descriptor, data) == len(data)
    except (OSError, ValueError):
        return False


def _write_active_private(path, value):
    """Publish a complete active verdict only after private storage succeeds."""
    path = Path(path)
    parent = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    temporary = ".active-" + uuid.uuid4().hex
    linked = False
    identity = None
    try:
        info = os.fstat(parent)
        if info.st_uid != os.getuid() or info.st_mode & 0o077 or not stat.S_ISDIR(info.st_mode):
            raise ValueError("private owned active receipt directory required")
        descriptor = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=parent)
        identity = os.fstat(descriptor)
        with os.fdopen(descriptor, "wb") as output:
            output.write(json.dumps(value, sort_keys=True).encode("utf-8") + b"\n")
            output.flush(); os.fsync(output.fileno())
        os.fsync(parent)
        os.link(temporary, path.name, src_dir_fd=parent, dst_dir_fd=parent, follow_symlinks=False)
        linked = True
        os.fsync(parent)
        os.unlink(temporary, dir_fd=parent)
        os.fsync(parent)
    except BaseException:
        if linked:
            current = os.stat(path.name, dir_fd=parent, follow_symlinks=False)
            if (current.st_dev, current.st_ino) != (identity.st_dev, identity.st_ino):
                raise RuntimeError("owned active publication identity changed")
            os.unlink(path.name, dir_fd=parent)
        raise
    finally:
        try: os.unlink(temporary, dir_fd=parent)
        except FileNotFoundError: pass
        os.close(parent)
def _finish_active_result(result, observation_started_ns, verified):
    result.update(transport_cleanup_status="verified" if verified else "unverified",
                  observer_transport_elapsed_ns=time.perf_counter_ns() - observation_started_ns,
                  observer_elapsed_boundary=("parent_entry_before_popen_through_owned_transport_exit_before_storage" if verified
                                             else "parent_entry_through_unverified_terminal_or_failure_before_storage"),
                  setup_ssh_and_native_bootstrap_included=True,
                  receipt_storage_elapsed_ns=None,
                  unmeasured_overhead=["caller_interpreter_startup", "pre_entry_argument_preparation",
                                       "receipt_storage_and_fsync", "post_return_cleanup"],
                  whole_observer_budget_qualification="unknown")
    if not verified:
        result["active_completion_qualified"] = False
        result["active_source_protocol_verified"] = False
        for record in result["active_completion_records"]:
            record["completion_qualification"].update(clock_quality="unknown", duration_lower_ms=None,
                    duration_upper_ms=None, unknown_reason="transport_unverified")
            if isinstance(record.get("event_qualification"), dict):
                record["event_qualification"].update(clock_quality="unknown", latency_lower_ms=None,
                        latency_upper_ms=None, clock_error_bound_ms=None, unknown_reason="transport_unverified")
    return result


def observe(command, arguments, receipt_path, timeout_seconds, expected_counter_hash=None,
            active_completion=False, sdk_coordinator=False):
    """Linux parent; only live frames can produce this observer receipt."""
    if not sys.platform.startswith("linux"):
        raise ValueError("Linux parent clock required")
    if active_completion and (arguments not in (["tick"], ["alarm"], ["links"]) or
                              (sdk_coordinator and arguments == ["tick"])):
        raise ValueError("finite active coordinator operation required")
    argument_bytes = json.dumps(arguments, separators=(",", ":"), ensure_ascii=True).encode("ascii")
    bounded_arguments(argument_bytes)
    argument_hash = hashlib.sha256(argument_bytes).hexdigest()
    observation_started_ns = time.perf_counter_ns()  # BEFORE SSH Popen, never command-runtime-only.
    child = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=None,
                             start_new_session=True)
    if active_completion:
        os.set_blocking(child.stdin.fileno(), False)
    selector = selectors.DefaultSelector()
    selector.register(child.stdout, selectors.EVENT_READ)
    deadline = time.monotonic() + timeout_seconds
    pending = bytearray()
    started = start_clock = received = None
    started_frame_elapsed_ns = None
    got_receipt = False
    got_exit = False
    original_exit = None
    transcript = None
    active_result = None
    got_cleanup = cleanup_verified = False
    if active_completion:
        def acknowledge(identity):
            return _send_active_control(child.stdin, frame("active_ack", workflow_id=identity))
        transcript = get_report().ActiveCompletionTranscript(arguments[0], acknowledge)
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
                    if started is not None or got_receipt or not valid_start(row["record"], argument_hash, active_completion, sdk_coordinator):
                        raise ValueError("observer start unavailable")
                    start_clock = get_report().qualification_clock()
                    started_frame_elapsed_ns = time.perf_counter_ns() - observation_started_ns
                    started = row["record"]
                elif row["kind"] == "active":
                    if not active_completion or started is None or got_receipt:
                        raise ValueError("unexpected active completion frame")
                    value = row["record"]
                    if (not isinstance(value, dict) or set(value) != {"data", "queued"}
                            or not isinstance(value["data"], str) or type(value["queued"]) is not bool
                            or len(value["data"].encode("utf-8")) > 4096):
                        transcript.invalid = True
                    else:
                        try:
                            transcript.receive(loads(value["data"]), get_report().qualification_clock(), queued=value["queued"])
                        except (ValueError, TypeError, KeyError):
                            transcript.invalid = True
                elif row["kind"] == "receipt":
                    received = get_report().qualification_clock()  # BEFORE ACK, while source custody remains held.
                    receipt_elapsed_ns = time.perf_counter_ns() - observation_started_ns
                    source = row["record"]
                    if got_receipt or not valid_receipt(source, started, expected_counter_hash, active_completion):
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
                              "observation_timing_basis": "linux_parent_perf_counter_ns_before_ssh_popen",
                              "started_frame_elapsed_ns": started_frame_elapsed_ns,
                              "receipt_elapsed_ns": receipt_elapsed_ns,
                              "stdin_profile": "read_only_no_stdin", "transport": "ssh_included"}
                    if expected_counter_hash is not None:
                        result["measurement"] = "linux_observed_windows_managed_read_counter"
                        result["counter_measurement"] = source["counter_measurement"]
                    if active_completion:
                        if source["active_channel_status"] != "valid":
                            transcript.invalid = True
                        qualified, records = transcript.result(source["child_exit"], source_verified=source["source_verified"] == "verified")
                        interval_verified = bool(qualified and records and all(
                            item["completion_qualification"]["unknown_reason"] == "none" for item in records))
                        result.update(measurement="linux_observed_windows_active_completion", active_completion_records=records,
                                      active_source_protocol_verified=qualified,
                                      active_completion_qualified=interval_verified, stdin_profile="active_no_stdin",
                                      qualification_profile="sdk_only_no_provider" if sdk_coordinator else "original_context",
                                      original_privilege_equivalence=False,
                                      native_execution_profile=source["execution_profile"],
                                      detection_latency_ms=None, detection_unknown_reason="eligibility_and_delivery_not_witnessed")
                        result.pop("event_qualification", None)
                        if not _send_active_control(child.stdin, frame("ack", observer_run_id=source["observer_run_id"])):
                            transcript.invalid = True
                            _, result["active_completion_records"] = transcript.result(source["child_exit"], source_verified=False)
                            result["active_completion_qualified"] = False
                            result["active_source_protocol_verified"] = False
                            result["active_control_status"] = "unavailable"
                        else:
                            result["active_control_status"] = "delivered"
                        active_result = result  # Never publish active qualification before cleanup/exit.
                    else:
                        try:
                            _write_private(receipt_path, result)
                        except (OSError, ValueError):
                            print("request observation: receipt unavailable; original command status preserved", file=sys.stderr)
                    got_receipt = True
                    if not active_completion:
                        child.stdin.write(frame("ack", observer_run_id=source["observer_run_id"]))
                        child.stdin.flush()
                    original_exit = source["child_exit"]
                elif row["kind"] == "cleanup":
                    record = row["record"]
                    if (not active_completion or not got_receipt or got_cleanup or not isinstance(record, dict)
                            or set(record) != {"schema", "frame", "observer_run_id", "owned_cleanup_verified"}
                            or type(record["schema"]) is not int or record["schema"] != 1 or record["frame"] != "cleanup"
                            or record["observer_run_id"] != started["observer_run_id"]
                            or type(record["owned_cleanup_verified"]) is not bool):
                        raise ValueError("active owned cleanup confirmation unavailable")
                    got_cleanup, cleanup_verified = True, record["owned_cleanup_verified"]
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
        if active_completion and active_result is not None:
            active_result["native_cleanup_reported"] = got_cleanup
            active_result["native_cleanup_verified"] = cleanup_verified
            _finish_active_result(active_result, observation_started_ns, got_cleanup and cleanup_verified)
            try:
                _write_active_private(receipt_path, active_result)
            except (OSError, ValueError):
                print("active observation: receipt storage unavailable; original command status preserved", file=sys.stderr)
        return original_exit
    except BaseException:
        if active_completion and active_result is not None:
            try:
                _write_active_private(receipt_path, _finish_active_result(active_result, observation_started_ns, False))
            except (OSError, ValueError):
                pass
        raise
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


def _active_terminal_status(source, status, cleanup):
    if (source is not None and status == 125 and not (
            source["child_exit"] == 125 and isinstance(cleanup, dict)
            and cleanup.get("owned_cleanup_verified") is True)):
        return source["child_exit"], {"schema": 1, "frame": "cleanup", "observer_run_id": source["observer_run_id"],
                                      "owned_cleanup_verified": False}
    return status, cleanup


def bounded_arguments(argument_bytes):
    if not isinstance(argument_bytes, bytes) or len(argument_bytes) > 8192:
        raise ValueError("bounded original argument JSON required")
    arguments = loads(argument_bytes.decode("utf-8", errors="strict"))
    if not isinstance(arguments, list) or any(not isinstance(value, str) or "\x00" in value for value in arguments):
        raise ValueError("read argument array required")
    return arguments


def windows_supervisor_command(source_root, argument_bytes, receipt_handle, ack_handle, counter_manifest=None, expected_counter_hash=None,
                               active_completion=False, sdk_coordinator=False):
    """Documented process-only script execution; never changes persistent/GPO policy."""
    powershell = str(Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe")
    bounded_arguments(argument_bytes)
    argument_payload = base64.b64encode(argument_bytes).decode("ascii")
    command = [powershell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(HERE / "source_generation_windows.ps1"),
            "-SourceRoot", source_root, "-EntryPoint", "bin/ai-pr-wait", "-ArgumentsBase64", argument_payload,
            "-ReceiptHandle", str(receipt_handle), "-ReceiptAckHandle", str(ack_handle),
            "-RestrictedReadProfile", "-ObserverEvents", "-ReadOnlyNoStdin"]
    if active_completion:
        arguments = bounded_arguments(argument_bytes)
        if counter_manifest is not None or arguments not in (["tick"], ["alarm"], ["links"]) or (sdk_coordinator and arguments == ["tick"]):
            raise ValueError("finite original active operation required")
        command[command.index("bin/ai-pr-wait")] = "bin/ai-blocker-watch"
        for flag in ("-RestrictedReadProfile", "-ObserverEvents", "-ReadOnlyNoStdin"):
            command.remove(flag)
        command += ["-ActiveCompletion", "-ActiveNoStdin"]
        if sdk_coordinator:
            command += ["-ActiveSdkProfile"]
    if counter_manifest is not None:
        if not digest(expected_counter_hash):
            raise ValueError("exact approved counter manifest digest required")
        command[command.index("bin/ai-pr-wait")] = "bin/ai-gh"
        command.remove("-ObserverEvents")
        command += ["-CounterManifest", counter_manifest, "-ExpectedCounterManifestSha256", expected_counter_hash]
    return command


def windows_controller(source_root, argument_bytes, timeout_seconds, counter_manifest=None, expected_counter_hash=None,
                       active_completion=False, sdk_coordinator=False):
    """Windows native controller: stream bytes; hold receipt custody until Linux ACK."""
    import msvcrt
    arguments = bounded_arguments(argument_bytes)
    receipt_read, receipt_write = os.pipe()
    ack_read, ack_write = os.pipe()
    if active_completion:
        try:
            os.set_blocking(ack_write, False)  # This parent owns this pipe, never a caller descriptor.
        except (OSError, NotImplementedError):
            kernel = ctypes.WinDLL("kernel32", use_last_error=True)
            kernel.SetNamedPipeHandleState.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_ulong), ctypes.c_void_p, ctypes.c_void_p]
            mode = ctypes.c_ulong(1)
            if not kernel.SetNamedPipeHandleState(msvcrt.get_osfhandle(ack_write), ctypes.byref(mode), None, None):
                raise ValueError("owned nonblocking active control unavailable")
    receipt_handle, ack_handle = msvcrt.get_osfhandle(receipt_write), msvcrt.get_osfhandle(ack_read)
    os.set_handle_inheritable(receipt_handle, True)
    os.set_handle_inheritable(ack_handle, True)
    startup = subprocess.STARTUPINFO()
    startup.lpAttributeList = {"handle_list": [receipt_handle, ack_handle]}
    controls = queue.Queue(maxsize=258)
    def control_reader():
        # Raw descriptor IO avoids a daemon holding CPython's buffered-stdin
        # lock during cancellation/interpreter shutdown.
        data = bytearray()
        try:
            messages = 0
            while messages < (257 if active_completion else 1):
                chunk = os.read(sys.stdin.fileno(), 4097 - len(data) if active_completion else 1025 - len(data))
                if not chunk:
                    controls.put_nowait(b""); return
                data.extend(chunk)
                while b"\n" in data:
                    line, _, rest = data.partition(b"\n"); data = bytearray(rest)
                    controls.put_nowait(bytes(line) + b"\n"); messages += 1
                    if not active_completion:
                        return
                if len(data) > (4096 if active_completion else 1024):
                    controls.put_nowait(b""); return
        except (OSError, queue.Full):
            try: controls.put_nowait(b"")
            except queue.Full: pass
    threading.Thread(target=control_reader, daemon=True).start()
    child = None
    reader = None
    command = windows_supervisor_command(source_root, argument_bytes, receipt_handle, ack_handle, counter_manifest, expected_counter_hash,
                                         active_completion, sdk_coordinator)
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
        active_control_failed = False
        native_cleanup = None
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
                    elif active_completion and record.get("frame") == "active":
                        if set(record) != {"schema", "frame", "data", "queued"} or record["schema"] != 1:
                            active_control_failed = True
                        else:
                            sys.stdout.buffer.write(frame("active", record={"data": record["data"], "queued": record["queued"]}))
                    elif active_completion and record.get("frame") == "cleanup":
                        if not got_receipt or native_cleanup is not None:
                            raise ValueError("cleanup before source custody receipt")
                        native_cleanup = record  # Finalize only after the actual supervisor exit.
                    else:
                        if got_receipt:
                            raise ValueError("duplicate native receipt")
                        # Child has exited. Drain its complete output BEFORE
                        # forwarding the final receipt on this ordered stream.
                        output_frames()
                        if counter_manifest is not None:
                            if not valid_counter_binding(record.get("counter_binding"), expected_counter_hash):
                                raise ValueError("native counter binding unavailable")
                            record["counter_measurement"] = counter_aggregate(record.pop("counter_raw", None))
                        source = record
                        if active_completion and active_control_failed:
                            source["active_channel_status"] = "invalid"
                        got_receipt = True
                        sys.stdout.buffer.write(frame("receipt", record=record))
                    sys.stdout.buffer.flush()
            if not controls.empty():
                control = controls.get_nowait()
                if active_completion and control:
                    try:
                        value = loads(control)
                        if (isinstance(value, dict) and set(value) == {"protocol", "kind", "workflow_id"}
                                and type(value["protocol"]) is int and value["protocol"] == 1
                                and value["kind"] == "active_ack" and digest(value["workflow_id"], 32)):
                            outgoing = {"schema": 1, "phase": "ack", "workflow_id": value["workflow_id"]}
                        elif source and value == {"protocol": 1, "kind": "ack", "observer_run_id": source["observer_run_id"]}:
                            outgoing = {"schema": 1, "phase": "custody_ack", "observer_run_id": source["observer_run_id"]}
                        else:
                            raise ValueError("invalid parent control")
                        data = json.dumps(outgoing, separators=(",", ":")).encode("ascii") + b"\n"
                        if os.write(ack_write, data) != len(data):
                            active_control_failed = True
                    except (ValueError, TypeError, OSError):
                        active_control_failed = True
                    continue
                expected = {"protocol": 1, "kind": "ack", "observer_run_id": source["observer_run_id"]} if source else None
                if not control or len(control) > 1024 or loads(control) != expected:
                    break
                os.write(ack_write, b"\x01")
            if child.poll() is not None:
                if active_completion and _peek(reader):
                    continue  # Drain the final parent-private cleanup frame before terminal exit.
                if active_completion and pending:
                    raise ValueError("partial terminal active source frame")
                output_frames()
                status = child.returncode
                if active_completion:
                    status, native_cleanup = _active_terminal_status(source, status, native_cleanup)
                    if native_cleanup is not None:
                        sys.stdout.buffer.write(frame("cleanup", record=native_cleanup))
                sys.stdout.buffer.write(frame("exit", code=status))
                sys.stdout.buffer.flush()
                return status
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
    parser.add_argument("--read-only-no-stdin", action="store_true")
    parser.add_argument("--active-completion", action="store_true")
    parser.add_argument("--active-no-stdin", action="store_true")
    parser.add_argument("--sdk-coordinator-profile", action="store_true")
    parser.add_argument("--timeout-seconds", type=int, default=3600)
    parser.add_argument("--arguments-base64")
    parser.add_argument("--counter-manifest")
    parser.add_argument("--expected-counter-manifest-sha256")
    parser.add_argument("arguments", nargs=argparse.REMAINDER)
    options = parser.parse_args()
    if options.active_completion:
        if not options.active_no_stdin or options.read_only_no_stdin or options.counter_manifest:
            parser.error("explicit active/no-stdin profile required; no counter/read relabeling")
    elif not options.read_only_no_stdin or options.active_no_stdin or options.sdk_coordinator_profile:
        parser.error("explicit existing read-only/no-stdin profile required")
    if not 1 <= options.timeout_seconds <= 7200:
        parser.error("finite observer deadline required")
    if bool(options.counter_manifest) != bool(options.expected_counter_manifest_sha256) or (options.counter_manifest and
            (not digest(options.expected_counter_manifest_sha256) or not re.fullmatch(r"[A-Za-z]:[/\\][A-Za-z0-9_./\\ -]+", options.counter_manifest))):
        parser.error("fixed native manifest path and exact approved SHA256 required")
    if options.windows_controller:
        if os.name != "nt" or options.arguments_base64 is None:
            parser.error("native Windows controller required")
        return windows_controller(options.source_root, base64.b64decode(options.arguments_base64, validate=True), options.timeout_seconds,
                                  options.counter_manifest, options.expected_counter_manifest_sha256,
                                  options.active_completion, options.sdk_coordinator_profile)
    if not options.host or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,62}", options.host) or not options.receipt:
        parser.error("known SSH host and new private receipt destination required")
    if not re.fullmatch(r"[A-Za-z]:[/\\][A-Za-z0-9_./\\ -]+", options.source_root):
        parser.error("ordinary native Windows source path required")
    arguments = options.arguments[1:] if options.arguments[:1] == ["--"] else options.arguments
    argument_bytes = json.dumps(arguments, separators=(",", ":"), ensure_ascii=True).encode("ascii")
    bounded_arguments(argument_bytes)  # before SSH or native supervisor creation.
    if options.active_completion and (arguments not in (["tick"], ["alarm"], ["links"]) or
                                      (options.sdk_coordinator_profile and arguments == ["tick"])):
        parser.error("finite active operation required; SDK profile excludes providers/ticks")
    payload = base64.b64encode(argument_bytes).decode("ascii")
    remote_path = options.source_root.rstrip("/\\") + "/tools/github-requests/remote_wait.py"
    remote_arguments = ["python.exe", "-I", remote_path, "--windows-controller", "--source-root", options.source_root,
                        "--timeout-seconds", str(options.timeout_seconds), "--arguments-base64", payload]
    remote_arguments += ["--active-completion", "--active-no-stdin"] if options.active_completion else ["--read-only-no-stdin"]
    if options.sdk_coordinator_profile:
        remote_arguments += ["--sdk-coordinator-profile"]
    if options.counter_manifest:
        remote_arguments += ["--counter-manifest", options.counter_manifest, "--expected-counter-manifest-sha256", options.expected_counter_manifest_sha256]
    remote = subprocess.list2cmdline(remote_arguments)
    if any(os.environ.get(key) for key in ("LD_PRELOAD", "LD_LIBRARY_PATH", "PYTHONPATH", "PYTHONHOME")):
        parser.error("ambient source injection prevents observer qualification")
    ssh = get_report().trusted_boundary_executable("/usr/bin/ssh")
    command = [ssh, "-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=12", options.host, remote]
    return observe(command, arguments, options.receipt, options.timeout_seconds, options.expected_counter_manifest_sha256,
                   options.active_completion, options.sdk_coordinator_profile)


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
