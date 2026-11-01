#!/usr/bin/env python3
"""One optional, finite Windows DATA-only event write; never grants authority.

The inherited handle must already be a nonblocking message pipe. This helper
never changes its mode. An isolated disposable writer has a one-second watchdog
because another holder can race its mode after validation.
"""
from __future__ import annotations

import ctypes
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import threading
import time

MAX_MESSAGE = 4096
HANDLE_ENV = "AI_GH_QUALIFICATION_EVENT_HANDLE"
ACTIVE_EVENT = "AI_GH_ACTIVE_EVENT_HANDLE"
ACTIVE_ACK = "AI_GH_ACTIVE_ACK_HANDLE"


def event_bytes(value):
    """Use the owning reporter's exact unqualified schema, never env claims."""
    try:
        import report
        if isinstance(value, str):
            value = json.loads(value, object_pairs_hook=report.unique_object)
        if not report.unqualified_event(value):
            return None
        data = json.dumps(value, separators=(",", ":"), ensure_ascii=True).encode("ascii")
        return data if 0 < len(data) <= MAX_MESSAGE else None
    except (ImportError, AttributeError, TypeError, ValueError):
        return None


def _kernel():
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    handle = ctypes.c_void_p
    dword = ctypes.c_ulong
    kernel.GetFileType.argtypes = [handle]
    kernel.GetFileType.restype = dword
    kernel.GetNamedPipeHandleStateW.argtypes = [handle, ctypes.POINTER(dword), ctypes.c_void_p,
                                               ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, dword]
    kernel.GetNamedPipeInfo.argtypes = [handle, ctypes.POINTER(dword), ctypes.c_void_p,
                                      ctypes.c_void_p, ctypes.c_void_p]
    kernel.WriteFile.argtypes = [handle, ctypes.c_void_p, dword, ctypes.POINTER(dword), ctypes.c_void_p]
    kernel.GetCurrentProcess.restype = handle
    kernel.DuplicateHandle.argtypes = [handle, handle, handle, ctypes.POINTER(handle), dword,
                                      ctypes.c_int, dword]
    kernel.CloseHandle.argtypes = [handle]
    kernel.GetHandleInformation.argtypes = [handle, ctypes.POINTER(dword)]
    kernel.GetStdHandle.argtypes = [dword]
    kernel.GetStdHandle.restype = handle
    kernel.ReadFile.argtypes = [handle, ctypes.c_void_p, dword, ctypes.POINTER(dword), ctypes.c_void_p]
    return kernel


def _active_handles(environment=None):
    environment = os.environ if environment is None else environment
    values = [environment.get(key, "") for key in (ACTIVE_EVENT, ACTIVE_ACK)]
    if any(not re.fullmatch(r"[1-9][0-9]{0,19}", value) for value in values):
        raise ValueError("invalid active handles")
    handles = tuple(map(int, values))
    if handles[0] == handles[1]:
        raise ValueError("aliased active handles")
    return handles


def _message_pipe(kernel, handle):
    mode, kind = ctypes.c_ulong(), ctypes.c_ulong()
    return (kernel.GetFileType(handle) == 3
            and kernel.GetNamedPipeHandleStateW(handle, ctypes.byref(mode), None, None, None, None, 0)
            and mode.value & 1
            and kernel.GetNamedPipeInfo(handle, ctypes.byref(kind), None, None, None)
            and kind.value & 4)


def _active_direct(phase, row, timeout_seconds):
    location = str(Path(__file__).resolve().parent)
    if location not in sys.path:
        sys.path.insert(0, location)
    import report
    if ((phase == "begin" and not report.active_begin_valid(row))
            or (phase == "end" and not report.active_outcome_valid(row, parent=True))
            or phase not in ("begin", "end")):
        return False
    event, ack = _active_handles()
    kernel = _kernel()
    if not all(_message_pipe(kernel, h) for h in (event, ack)):
        return False
    deadline = time.monotonic() + timeout_seconds
    data = json.dumps(row, separators=(",", ":"), ensure_ascii=True).encode("ascii")
    if not _write_once(event, data):
        return False
    if phase == "end":
        return True
    while time.monotonic() < deadline:
        if not _message_pipe(kernel, ack):
            return False
        buffer, count = ctypes.create_string_buffer(MAX_MESSAGE + 1), ctypes.c_ulong()
        if kernel.ReadFile(ack, buffer, MAX_MESSAGE + 1, ctypes.byref(count), None):
            raw = buffer.raw[:count.value]
            if time.monotonic() >= deadline or not raw.endswith(b"\n") or len(raw) > MAX_MESSAGE:
                return False
            value = json.loads(raw, object_pairs_hook=report.unique_object)
            return (isinstance(value, dict) and set(value) == {"schema", "phase", "workflow_id"}
                    and type(value["schema"]) is int and value["schema"] == 1
                    and value["phase"] == "ack" and value["workflow_id"] == row["workflow_id"])
        if ctypes.get_last_error() != 232:  # PIPE_NOWAIT: no message yet.
            return False
        time.sleep(0.002)
    return False


def active_completion_io(phase, row, timeout_seconds=0.250):
    """DATA-only reciprocal transport; the disposable child bounds raced pipe modes."""
    if os.name != "nt" or not 0 < timeout_seconds <= 0.250:
        return False
    duplicates = []
    kernel = _kernel()
    process = kernel.GetCurrentProcess()
    try:
        original = _active_handles()
        environment = os.environ.copy()
        for key, handle in zip((ACTIVE_EVENT, ACTIVE_ACK), original):
            duplicate = ctypes.c_void_p()
            if not kernel.DuplicateHandle(process, handle, process, ctypes.byref(duplicate), 0, True, 2):
                return False
            duplicates.append(duplicate.value)
            environment[key] = str(duplicate.value)
        startup = subprocess.STARTUPINFO()
        startup.lpAttributeList = {"handle_list": duplicates}
        data = json.dumps(row, separators=(",", ":"), ensure_ascii=True).encode("ascii")
        if not 0 < len(data) <= MAX_MESSAGE or phase not in ("begin", "end"):
            return False
        child = subprocess.Popen([sys.executable, "-I", "-S", str(Path(__file__).resolve()), "--active-once", phase],
                                 env=environment, startupinfo=startup, close_fds=True, stdin=subprocess.PIPE,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            child.communicate(data, timeout=1.25)
            return child.returncode == 0
        except subprocess.TimeoutExpired:
            child.kill(); child.communicate(timeout=0.25)
            return False
    except (OSError, ValueError, TypeError, subprocess.SubprocessError):
        return False
    finally:
        for handle in duplicates:
            kernel.CloseHandle(handle)


def active_harness_exec(arguments):
    """Run the original resolved timeout/provider once, without observer inheritance."""
    if not arguments:
        return 127
    environment = os.environ.copy()
    unsafe, event = False, None
    kernel = _kernel()
    try:
        event, ack = _active_handles(environment)
        standards = {kernel.GetStdHandle(n & 0xffffffff) for n in (-10, -11, -12)}
        # ACK first; event remains available for negative-only invalidation.
        for handle in (ack, event):
            if handle in standards or not _message_pipe(kernel, handle):
                unsafe = True
                continue
            if not kernel.CloseHandle(handle):
                unsafe = True
            flags = ctypes.c_ulong()
            ctypes.set_last_error(0)
            if kernel.GetHandleInformation(handle, ctypes.byref(flags)) or ctypes.get_last_error() != 6:
                unsafe = True
            if unsafe and handle != event:
                _write_once(event, b"{}")
        if unsafe:
            _write_once(event, b"{}")
    except (OSError, ValueError, TypeError):
        unsafe = True
        if event is not None:
            _write_once(event, b"{}")
    for key in tuple(environment):
        if key.startswith(("AI_GH_ACTIVE_", "AI_GH_QUALIFICATION_", "AI_GH_HTTP_COUNTER_")):
            environment.pop(key, None)
    # Explicit standard-stream-only inheritance is decisive even if closure
    # verification was uncertain. Such uncertainty never grants qualification.
    try:
        child = subprocess.Popen(arguments, env=environment, stdin=subprocess.DEVNULL,
                                 stdout=None, stderr=None, close_fds=True)
        return child.wait()
    except OSError:
        return 127


def _write_once(handle, data):
    """Called only inside the disposable watchdog process."""
    if os.name != "nt" or not isinstance(data, bytes) or not 0 < len(data) <= MAX_MESSAGE:
        return False
    try:
        kernel = _kernel()
        state, kind = ctypes.c_ulong(), ctypes.c_ulong()
        if (kernel.GetFileType(handle) != 3
                or not kernel.GetNamedPipeHandleStateW(handle, ctypes.byref(state), None, None, None, None, 0)
                or not state.value & 1
                or not kernel.GetNamedPipeInfo(handle, ctypes.byref(kind), None, None, None)
                or not kind.value & 4):
            return False
        written = ctypes.c_ulong()
        buffer = ctypes.create_string_buffer(data)
        return bool(kernel.WriteFile(handle, buffer, len(data), ctypes.byref(written), None)
                    and written.value == len(data))
    except (OSError, ValueError, OverflowError):
        return False


def emit_event(value):
    """Never terminate the importing workflow or mutate its pipe/environment."""
    raw = os.environ.get(HANDLE_ENV, "")
    if os.name != "nt" or not re.fullmatch(r"[1-9][0-9]{0,19}", raw):
        return False
    data = event_bytes(value)
    if data is None:
        return False
    duplicate = ctypes.c_void_p()
    kernel = _kernel()
    process = kernel.GetCurrentProcess()
    try:
        # Only our new duplicate is inheritable; caller handle flags stay intact.
        if not kernel.DuplicateHandle(process, int(raw), process, ctypes.byref(duplicate), 0, True, 2):
            return False
        startup = subprocess.STARTUPINFO()
        startup.lpAttributeList = {"handle_list": [duplicate.value]}
        environment = os.environ.copy()
        environment[HANDLE_ENV] = str(duplicate.value)
        command = [sys.executable, "-I", str(Path(__file__).resolve()), "--write-once"]
        child = subprocess.Popen(command, startupinfo=startup, close_fds=True, env=environment,
                                 stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            child.communicate(data, timeout=1.25)
            return child.returncode == 0
        except subprocess.TimeoutExpired:
            child.kill()
            child.communicate(timeout=0.25)
            return False
    except (OSError, ValueError, subprocess.SubprocessError):
        return False
    finally:
        if duplicate.value:
            kernel.CloseHandle(duplicate)


def main():
    active = len(sys.argv) == 3 and sys.argv[1] == "--active-once" and sys.argv[2] in ("begin", "end")
    if not active and sys.argv[1:] not in ([], ["--write-once"]):
        return 2
    # This timer kills ONLY the disposable writer, never its importing tool.
    timer = threading.Timer(0.250 if active else 1.0, lambda: os._exit(2))
    timer.daemon = True
    timer.start()
    try:
        if active:
            location = str(Path(__file__).resolve().parent)
            if location not in sys.path:
                sys.path.insert(0, location)
            import report
            raw = sys.stdin.buffer.read(MAX_MESSAGE + 1)
            row = json.loads(raw, object_pairs_hook=report.unique_object)
            return 0 if _active_direct(sys.argv[2], row, 0.250) else 2
        raw = os.environ.get(HANDLE_ENV, "")
        if not re.fullmatch(r"[1-9][0-9]{0,19}", raw):
            return 2
        data = sys.stdin.buffer.read(MAX_MESSAGE + 1)
        if not sys.argv[1:]:
            # The shell collector invokes this disposable CLI directly.
            # Importing callers use emit_event(), which isolates its watchdog.
            data = event_bytes(data.decode("utf-8"))
            if data is None:
                return 2
        return 0 if _write_once(int(raw), data) else 2
    except (OSError, ValueError, UnicodeError):
        return 2
    finally:
        timer.cancel()


if __name__ == "__main__":
    raise SystemExit(main())
