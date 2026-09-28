#!/usr/bin/env python3
"""Share a complete PR status response between local waiters of one identity.

The lock is held by the operating system, so a killed refresh owner releases it.
The cache is an optimization only: any uncertainty runs the supplied command or
returns an explicit error; it never turns an incomplete response into success.
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import time

if os.name == "nt":
    import msvcrt
else:
    import fcntl


def windows_acl(mode, path):
    helper = Path(__file__).with_name("secure-windows-path.ps1")
    if not helper.is_file():
        return False
    try:
        return subprocess.run(
            ["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
             "-File", str(helper), "-Mode", mode, "-Path", str(path)],
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False, timeout=15,
        ).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def unix_private(path, kind, *, owner=None):
    """Accept only our own private inode; never follow a substituted symlink."""
    try:
        info = os.lstat(path) if owner is None else os.fstat(owner)
        wanted = stat.S_ISDIR if kind == "directory" else stat.S_ISREG
        return (wanted(info.st_mode) and info.st_uid == os.geteuid()
                and not info.st_mode & 0o077 and (kind == "directory" or info.st_nlink == 1))
    except OSError:
        return False


def unix_prepare_parent(path):
    """Build missing private parents only below an unreplaceable ancestor."""
    path = path.absolute()
    current = Path(path.anchor)
    for part in path.parts[1:]:
        if part == "..":
            return False
        try:
            info = os.lstat(current)
            if not stat.S_ISDIR(info.st_mode) or info.st_uid not in {0, os.geteuid()}:
                return False
            # A sticky root-owned public parent (for example /tmp) protects
            # the user's private child from replacement by another user.
            public_sticky = info.st_uid == 0 and info.st_mode & stat.S_ISVTX
            if info.st_mode & 0o022 and not public_sticky:
                return False
            current = current / part
            if not current.exists():
                current.mkdir(mode=0o700)
        except OSError:
            return False
    try:
        info = os.lstat(current)
        return (stat.S_ISDIR(info.st_mode) and info.st_uid == os.geteuid()
                and not info.st_mode & 0o022)
    except OSError:
        return False


def read_private_cache(path):
    """Read one verified Unix inode, without following a swapped pathname."""
    try:
        descriptor = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        with os.fdopen(descriptor, "rb") as file:
            if not unix_private(path, "file", owner=file.fileno()):
                return None
            info = os.fstat(file.fileno())
            if info.st_size > 1048576:
                return None
            return info, file.read(1048577)
    except OSError:
        return None


def lock(file):
    if os.name == "nt":
        file.seek(0)
        if not file.read(1):
            file.seek(0)
            file.write(b"0")
            file.flush()
        file.seek(0)
        msvcrt.locking(file.fileno(), msvcrt.LK_NBLCK, 1)
    else:
        fcntl.flock(file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)


def unlock(file):
    if os.name == "nt":
        file.seek(0)
        msvcrt.locking(file.fileno(), msvcrt.LK_UNLCK, 1)
    else:
        fcntl.flock(file.fileno(), fcntl.LOCK_UN)


def complete(raw):
    try:
        data = json.loads(raw)
        if not isinstance(data, dict) or data.get("errors"):
            return False
        pr = data["data"]["repository"]["pullRequest"]
        if not isinstance(pr, dict) or pr.get("state") not in {"OPEN", "CLOSED", "MERGED"}:
            return False
        if not isinstance(pr.get("isInMergeQueue"), bool):
            return False
        if pr["state"] != "OPEN":
            return True
        rollup = pr["commits"]["nodes"][0]["commit"]["statusCheckRollup"]
        if rollup is None:
            return True
        contexts = rollup["contexts"]
        if not isinstance(contexts["nodes"], list):
            return False
        if not all(isinstance(node, dict) for node in contexts["nodes"]):
            return False
        if not isinstance(contexts["totalCount"], int) or contexts["totalCount"] != len(contexts["nodes"]):
            return False
        page = contexts["pageInfo"]
        return page.get("hasPreviousPage") is False
    except (TypeError, ValueError, KeyError, IndexError):
        return False


def cacheable(raw, expected_head):
    if not complete(raw):
        return False
    pr = json.loads(raw)["data"]["repository"]["pullRequest"]
    if pr["state"] != "OPEN" or not pr.get("headRefOid"):
        return False
    if expected_head != "any" and pr["headRefOid"] != expected_head:
        return False
    rollup = pr["commits"]["nodes"][0]["commit"]["statusCheckRollup"]
    if rollup is None:
        return False
    if rollup.get("state") in {"FAILURE", "ERROR"}:
        return False
    nodes = rollup["contexts"]["nodes"]
    return not any(
        node.get("conclusion") in {"FAILURE", "TIMED_OUT", "CANCELLED"}
        or node.get("state") in {"FAILURE", "ERROR"}
        for node in nodes
    )


def atomic_write(path, data):
    descriptor, name = tempfile.mkstemp(prefix=".status-", dir=path.parent)
    try:
        if os.name != "nt":
            os.fchmod(descriptor, stat.S_IRUSR | stat.S_IWUSR)
        with os.fdopen(descriptor, "wb") as file:
            file.write(data)
            file.flush()
            os.fsync(file.fileno())
        if os.name == "nt" and not windows_acl("VerifyCache", Path(name)):
            raise OSError("snapshot file ACL is not private")
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def prune(directory):
    """A stale snapshot is never useful; bound retained private metadata."""
    now = time.time()
    candidates = []
    for path in directory.glob("*.json"):
        try:
            if path.is_symlink() or not path.is_file():
                continue
            age = now - path.stat().st_mtime
            if age > 3600 or age < -1:
                path.unlink()
            else:
                candidates.append((path.stat().st_mtime, path))
        except OSError:
            continue
    for _, path in sorted(candidates)[:-256]:
        try:
            path.unlink()
        except OSError:
            pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--state-dir", required=True)
    parser.add_argument("--key", required=True)
    parser.add_argument("--ttl", type=int, required=True)
    parser.add_argument("--wait-seconds", type=int, required=True)
    parser.add_argument("--age-file", required=True)
    parser.add_argument("--source-file", required=True)
    parser.add_argument("--expected-head", required=True)
    parser.add_argument("--force-refresh", action="store_true")
    parser.add_argument("--cap-supervisor-timeout", action="store_true")
    parser.add_argument("--defer-source-mark", action="store_true")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not args.command or args.command[0] != "--" or args.ttl < 1 or args.wait_seconds < 1 or not args.expected_head:
        return 3
    command = args.command[1:]
    deadline = time.monotonic() + args.wait_seconds
    joined_ns = time.time_ns()

    def upstream(cache_path):
        return run(command, cache_path, args.age_file, args.source_file, args.expected_head,
                   deadline, args.cap_supervisor_timeout, args.defer_source_mark)

    directory = Path(args.state_dir)
    if directory.is_symlink() or (directory.exists() and not directory.is_dir()):
        return upstream(None)
    if os.name == "nt":
        if not windows_acl("EnsureCache", directory):
            return upstream(None)
    else:
        try:
            if not unix_prepare_parent(directory.parent):
                return upstream(None)
            directory.mkdir(parents=True, mode=0o700, exist_ok=True)
            if not unix_private(directory, "directory"):
                return upstream(None)
        except OSError:
            return upstream(None)
    prune(directory)
    digest = hashlib.sha256(args.key.encode()).hexdigest()
    cache = directory / f"{digest}.json"
    # A fixed namespace avoids an immortal lock file for every historical
    # identity/PR/head. Colliding keys serialize, but snapshots retain their
    # exact digest and never cross the identity boundary.
    lock_path = directory / f".flight-{digest[:2]}.lock"
    if cache.is_symlink() or lock_path.is_symlink():
        return upstream(None)
    if os.name == "nt" and cache.exists() and not windows_acl("VerifyCache", cache):
        return upstream(None)
    if os.name != "nt" and cache.exists() and not unix_private(cache, "file"):
        return upstream(None)
    try:
        if os.name == "nt":
            owner_file = open(lock_path, "a+b")
        else:
            flags = os.O_RDWR | os.O_CREAT | getattr(os, "O_NOFOLLOW", 0)
            descriptor = os.open(lock_path, flags, 0o600)
            if not unix_private(lock_path, "file", owner=descriptor):
                os.close(descriptor)
                return upstream(None)
            owner_file = os.fdopen(descriptor, "r+b")
    except OSError:
        return upstream(None)
    with owner_file as owner:
        if os.name == "nt" and not windows_acl("VerifyCache", lock_path):
            return upstream(None)
        while True:
            try:
                lock(owner)
                break
            except (BlockingIOError, OSError):
                if time.monotonic() >= deadline:
                    print("ai-pr-wait: shared refresh still active at the request deadline", file=sys.stderr)
                    return 75
                time.sleep(0.05)
        try:
            if cache.is_file() and not cache.is_symlink():
                if os.name == "nt":
                    if not windows_acl("VerifyCache", cache):
                        return upstream(None)
                    stat_result, raw = cache.stat(), cache.read_bytes()
                else:
                    result = read_private_cache(cache)
                    if result is None:
                        return upstream(None)
                    stat_result, raw = result
                wall_age = time.time() - stat_result.st_mtime
                if stat_result.st_size <= 1048576 and (stat_result.st_mtime_ns >= joined_ns or
                        (not args.force_refresh and 0 <= wall_age < args.ttl)):
                    # The first condition shares only a response completed
                    # after this subscriber joined the in-flight refresh.
                    # Older terminal/failed/queue results are never replayed.
                    same_flight = joined_ns <= stat_result.st_mtime_ns <= time.time_ns()
                    if (same_flight and complete(raw)) or (not args.force_refresh and
                            0 <= wall_age < args.ttl and cacheable(raw, args.expected_head)):
                        age = 0 if same_flight else int(wall_age)
                        Path(args.age_file).write_text(str(age))
                        Path(args.source_file).write_text("cache")
                        sys.stdout.buffer.write(raw)
                        return 0
            return upstream(cache)
        finally:
            unlock(owner)


def run(command, cache, age_file, source_file, expected_head=None,
        deadline=None, cap_supervisor_timeout=False, defer_source_mark=False):
    if cap_supervisor_timeout:
        try:
            index = command.index("--timeout-seconds")
            original_limit = int(command[index + 1])
        except (ValueError, IndexError):
            print("ai-pr-wait: shared refresh has no bounded supervisor", file=sys.stderr)
            return 3
        remaining = int(deadline - time.monotonic())
        if remaining < 1:
            print("ai-pr-wait: shared refresh used the request deadline", file=sys.stderr)
            return 75
        command = list(command)
        command[index + 1] = str(min(original_limit, remaining))
    # Mark the actual transport before it starts. A completed cache read never
    # reports upstream spend, even when its age rounds down to zero seconds.
    if not defer_source_mark:
        Path(source_file).write_text("upstream")
    result = subprocess.run(command, capture_output=True, check=False)
    sys.stderr.buffer.write(result.stderr)
    sys.stdout.buffer.write(result.stdout)
    Path(age_file).write_text("0")
    if result.returncode:
        return result.returncode
    if not complete(result.stdout):
        print("ai-pr-wait: incomplete or invalid pull-request status; refusing cached success", file=sys.stderr)
        return 4
    if cache is not None and len(result.stdout) <= 1048576 and complete(result.stdout):
        try:
            atomic_write(cache, result.stdout)
        except OSError:
            # A cache write must not erase an otherwise valid fresh outcome.
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
