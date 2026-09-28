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
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if not args.command or args.command[0] != "--" or args.ttl < 1 or args.wait_seconds < 1 or not args.expected_head:
        return 3
    command = args.command[1:]
    deadline = time.monotonic() + args.wait_seconds

    def upstream(cache_path):
        return run(command, cache_path, args.age_file, args.source_file, args.expected_head,
                   deadline, args.cap_supervisor_timeout)

    directory = Path(args.state_dir)
    if directory.is_symlink() or (directory.exists() and not directory.is_dir()):
        return upstream(None)
    if os.name == "nt":
        if not windows_acl("EnsureCache", directory):
            return upstream(None)
    else:
        try:
            directory.mkdir(parents=True, mode=0o700, exist_ok=True)
            if directory.is_symlink() or directory.stat().st_mode & 0o077:
                return upstream(None)
        except OSError:
            return upstream(None)
    prune(directory)
    digest = hashlib.sha256(args.key.encode()).hexdigest()
    cache = directory / f"{digest}.json"
    lock_path = directory / f"{digest}.lock"
    if cache.is_symlink() or lock_path.is_symlink():
        return upstream(None)
    if os.name == "nt" and cache.exists() and not windows_acl("VerifyCache", cache):
        return upstream(None)
    try:
        owner_file = open(lock_path, "a+b")
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
            if not args.force_refresh and cache.is_file() and not cache.is_symlink():
                wall_age = time.time() - cache.stat().st_mtime
                if 0 <= wall_age < args.ttl:
                    age = int(wall_age)
                    if cache.stat().st_size > 1048576:
                        raw = b""
                    else:
                        raw = cache.read_bytes()
                    if cacheable(raw, args.expected_head):
                        Path(args.age_file).write_text(str(age))
                        Path(args.source_file).write_text("cache")
                        sys.stdout.buffer.write(raw)
                        return 0
            return upstream(cache)
        finally:
            unlock(owner)


def run(command, cache, age_file, source_file, expected_head=None,
        deadline=None, cap_supervisor_timeout=False):
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
    if cache is not None and len(result.stdout) <= 1048576 and cacheable(result.stdout, expected_head):
        try:
            atomic_write(cache, result.stdout)
        except OSError:
            # A cache write must not erase an otherwise valid fresh outcome.
            pass
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
