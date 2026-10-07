"""Linux sealed verified bytes: pathname replacement cannot alter later use."""
import hashlib
import os
import stat
import re


def verified_snapshot(path, expected, limit=536870912):
    # Imports stay inside the Linux-only capability; metadata validation is
    # independently usable on Windows and never claims Windows execution.
    import fcntl

    if not isinstance(expected, str) or re.fullmatch(r"[0-9a-f]{64}", expected) is None:
        raise ValueError("invalid pinned digest")
    if not hasattr(os, "memfd_create"):
        raise ValueError("sealed Linux snapshot unavailable")
    source_fd = snapshot_fd = None
    try:
        source_fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC)
        info = os.fstat(source_fd)
        if not stat.S_ISREG(info.st_mode) or not 0 <= info.st_size <= limit:
            raise ValueError("invalid pinned input")
        snapshot_fd = os.memfd_create("ai-gh-verified", os.MFD_CLOEXEC | os.MFD_ALLOW_SEALING)
        copied = 0
        while True:
            block = os.read(source_fd, 1048576)
            if not block:
                break
            copied += len(block)
            if copied > limit:
                raise ValueError("pinned input exceeds limit")
            view = memoryview(block)
            while view:
                written = os.write(snapshot_fd, view)
                if written <= 0:
                    raise ValueError("snapshot write failed")
                view = view[written:]
        # Seal FIRST; the hash and every later use bind the identical immutable
        # snapshot, not an open-but-mutable original inode or private pathname.
        seals = fcntl.F_SEAL_WRITE | fcntl.F_SEAL_GROW | fcntl.F_SEAL_SHRINK | fcntl.F_SEAL_SEAL
        fcntl.fcntl(snapshot_fd, fcntl.F_ADD_SEALS, seals)
        if fcntl.fcntl(snapshot_fd, fcntl.F_GET_SEALS) & seals != seals:
            raise ValueError("snapshot sealing failed")
        os.lseek(snapshot_fd, 0, os.SEEK_SET)
        snapshot = os.fdopen(snapshot_fd, "rb")
        snapshot_fd = None
        try:
            actual = hashlib.file_digest(snapshot, "sha256").hexdigest()
            if actual != expected:
                raise ValueError("pinned input checksum mismatch")
            snapshot.seek(0)
            return snapshot
        except BaseException:
            snapshot.close()
            raise
    finally:
        if source_fd is not None:
            os.close(source_fd)
        if snapshot_fd is not None:
            os.close(snapshot_fd)
