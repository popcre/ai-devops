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

MAX_MESSAGE = 4096
HANDLE_ENV = "AI_GH_QUALIFICATION_EVENT_HANDLE"


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
    return kernel


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
    if sys.argv[1:] not in ([], ["--write-once"]):
        return 2
    # This timer kills ONLY the disposable writer, never its importing tool.
    timer = threading.Timer(1.0, lambda: os._exit(2))
    timer.daemon = True
    timer.start()
    try:
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
