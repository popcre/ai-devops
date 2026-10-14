"""Bounded post-worker output verification; issues no authority.

Only newly admitted output bytes are inspected. The caller retains the output
directory descriptor from before worker launch; no returned path is trusted.
"""
import hashlib
import json
import os
from pathlib import Path
import stat


def require(value, reason):
    if not value:
        raise ValueError(reason)


def identity(info):
    return (info.st_dev, info.st_ino, info.st_uid, info.st_mode, info.st_nlink,
            info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def open_directory(path):
    path = Path(path)
    require(path.is_absolute() and '..' not in path.parts, 'unsafe output path')
    fd = os.open('/', os.O_PATH | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in path.parts[1:]:
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = child
        info = os.fstat(fd)
        require(stat.S_ISDIR(info.st_mode) and info.st_uid == os.getuid()
                and stat.S_IMODE(info.st_mode) == 0o700, 'owned private output directory required')
        return fd
    except BaseException:
        os.close(fd)
        raise


def verify(fd, initial, receipt, limits):
    root = os.fstat(fd)
    require((root.st_dev, root.st_ino) == (initial.st_dev, initial.st_ino)
            and stat.S_ISDIR(root.st_mode) and root.st_uid == os.getuid()
            and stat.S_IMODE(root.st_mode) == 0o700, 'output directory changed')
    names = ['c' + str(index) + '.json' for index in range(33)]
    require(set(os.listdir(fd)) == set(names), 'fixed output inventory differs')
    total = 0
    hashes = []
    for name in names:
        probe = os.open(name, os.O_PATH | os.O_NOFOLLOW, dir_fd=fd)
        try:
            before = os.fstat(probe)
            require(stat.S_ISREG(before.st_mode) and before.st_uid == os.getuid()
                    and stat.S_IMODE(before.st_mode) == 0o600 and before.st_nlink == 1,
                    'nonregular or unsafe output file')
            require(0 < before.st_size <= limits['per_file_bytes'], 'output file exceeds bound')
            total += before.st_size
            require(total <= limits['output_bytes'], 'aggregate output exceeds bound')
            content = os.open(name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=fd)
            try:
                require(identity(os.fstat(content)) == identity(before), 'output changed before read')
                digest = hashlib.sha256()
                remaining = before.st_size
                while remaining:
                    chunk = os.read(content, min(1024 * 1024, remaining))
                    require(bool(chunk), 'output truncated')
                    digest.update(chunk)
                    remaining -= len(chunk)
                require(not os.read(content, 1) and identity(os.fstat(content)) == identity(before),
                        'output changed during read')
                hashes.append(digest.hexdigest())
            finally:
                os.close(content)
        finally:
            os.close(probe)
    require(identity(os.fstat(fd)) == identity(root), 'output directory changed during verification')
    expected = hashlib.sha256(json.dumps(hashes, separators=(',', ':')).encode()).hexdigest()
    require(type(receipt.get('artifact_count')) is int and receipt['artifact_count'] == 33
            and type(receipt.get('output_bytes')) is int and receipt['output_bytes'] == total
            and receipt.get('outputs_sha256') == expected, 'actual output receipt differs')
