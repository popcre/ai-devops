#!/usr/bin/env python3
"""Append one allowlisted measurement record from a Python caller.

Shared by the PR-status singleflight and other #658 measurement emitters so
they do not reimplement the shell collector's private daily-file boundary.
Never follow a symlink; never write past the daily ceiling; never fail the
caller's primary result on telemetry error (callers check the return value
and ignore it).
"""

from __future__ import annotations

import datetime
import os
from pathlib import Path
import stat
import time
import sys


def write_event_fd(descriptor: int, record: str) -> bool:
    """One atomic, nonblocking write through an independent pipe description.

    dup() would share status flags with the caller; reopening its already-held
    Linux pipe makes O_NONBLOCK local to this write. Regular files, stdio,
    oversized records and unavailable readers are refused without side effects.
    """
    opened = None
    try:
        if (type(descriptor) is not int or not 3 <= descriptor <= 65535
                or not isinstance(record, str) or not record or "\n" in record):
            return False
        data = (record + "\n").encode("utf-8")
        original = os.fstat(descriptor)
        if not stat.S_ISFIFO(original.st_mode) or len(data) > min(4096, os.fpathconf(descriptor, "PC_PIPE_BUF")):
            return False
        opened = os.open(f"/proc/self/fd/{descriptor}", os.O_WRONLY | os.O_NONBLOCK | os.O_CLOEXEC)
        info = os.fstat(opened)
        if not stat.S_ISFIFO(info.st_mode) or (info.st_dev, info.st_ino) != (original.st_dev, original.st_ino):
            return False
        return os.write(opened, data) == len(data)
    except (OSError, ValueError, UnicodeError):
        return False
    finally:
        if opened is not None:
            os.close(opened)


def append_record(measurements_dir: Path, record: str) -> bool:
    """Append one newline-terminated record. Returns False on any refusal."""
    try:
        if not isinstance(record, str) or "\n" in record or not record:
            return False
        if measurements_dir.is_symlink():
            return False
        if not measurements_dir.exists():
            measurements_dir.mkdir(parents=True, mode=0o700, exist_ok=True)
        if not measurements_dir.is_dir():
            return False
        if os.name != "nt":
            info = os.lstat(measurements_dir)
            if not stat.S_ISDIR(info.st_mode) or info.st_mode & 0o077:
                return False
        day = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
        target = measurements_dir / f"{day}.jsonl"
        if target.is_symlink() or (target.exists() and not target.is_file()):
            return False
        lock = measurements_dir / "write.lock"
        acquired = False
        for _ in range(50):
            try:
                lock.mkdir(mode=0o700)
                acquired = True
                break
            except OSError:
                try:
                    if lock.is_dir() and (time.time() - lock.stat().st_mtime) > 60:
                        lock.rmdir()
                        lock.mkdir(mode=0o700)
                        acquired = True
                        break
                except OSError:
                    pass
                time.sleep(0.01)
        if not acquired:
            return False
        try:
            if target.exists() and target.stat().st_size >= 4193280:
                return False
            with open(target, "a", encoding="utf-8", newline="\n") as handle:
                handle.write(record + "\n")
                handle.flush()
                os.fsync(handle.fileno())
            return True
        except OSError:
            return False
        finally:
            try:
                lock.rmdir()
            except OSError:
                pass
    except OSError:
        return False


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--event-fd" and sys.argv[2].isdigit():
        data = sys.stdin.buffer.read(4097)
        try:
            success = len(data) <= 4096 and write_event_fd(int(sys.argv[2]), data.decode("utf-8"))
        except UnicodeError:
            success = False
        sys.exit(0 if success else 1)
    sys.exit(2)
