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
import math
import re
import secrets

if os.name == "nt":
    import msvcrt
else:
    import fcntl

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))


def _gh_state_dir():
    root = os.environ.get("AI_GH_STATE_DIR") or str(Path.home() / ".ai-devops" / "gh-throttle")
    return Path(root)


def _measurement_dir():
    return _gh_state_dir() / "measurements"


def _target_ordinal(key):
    try:
        import target_ordinal
        return target_ordinal.ordinal_for(_gh_state_dir(), key)
    except Exception:
        return None


def _emit_record(record_obj):
    try:
        import measure_append
        measure_append.append_record(_measurement_dir(), json.dumps(record_obj, separators=(",", ":")))
    except Exception:
        pass


def observation_caller(value=None):
    # Never persist arbitrary caller/environment strings as telemetry labels.
    selected = value if value is not None else os.environ.get("AI_GH_CALLER") or "ai-pr-wait"
    return selected if isinstance(selected, str) and selected in {
        "ai-pr-wait", "ai-gh-wait", "ai-blocker-watch", "ai-merge-group-evidence", "unknown"} else "unknown"


def read_clock():
    """Bracket the UTC sample with actual local monotonic readings."""
    try:
        before = time.monotonic_ns()
        wall = time.time_ns() // 1000000
        after = time.monotonic_ns()
        if before < 0 or after < before or not 0 <= wall <= 9999999999999:
            return None
        return before, wall, after
    except (OSError, AttributeError, OverflowError):
        return None


def begin_read(key, expected_head, ttl, force_refresh):
    arrival = read_clock()
    parent = os.environ.get("AI_GH_WORKFLOW_ID", "")
    if re.fullmatch(r"[0-9a-f]{32}", parent) is None:
        parent = os.environ.get("PR_WAIT_RECEIPT_ID", "")
    correlated = re.fullmatch(r"[0-9a-f]{32}", parent) is not None
    return {"arrival": arrival, "expected_head": expected_head,
            "workflow_id": parent if correlated else secrets.token_hex(16),
            "workflow_correlation": "workflow" if correlated else "unknown",
            "head_known": re.fullmatch(r"[0-9a-f]{40}", expected_head) is not None,
            "ttl_seconds": ttl, "force_refresh": force_refresh, "sharing_scope": None}


def bind_read_scope(interval, directory):
    if interval is None:
        return
    try:
        info = os.stat(directory, follow_symlinks=False)
        if stat.S_ISDIR(info.st_mode) and info.st_ino > 0:
            interval["sharing_scope"] = f"{info.st_dev}:{info.st_ino}"
    except OSError:
        pass


def read_interval(key, interval, raw, cache_age_ms, cache_policy):
    finish = interval.get("finish")
    arrival = interval["arrival"]
    clock_state, elapsed = "unavailable", None
    try:
        resolution = max(1, math.ceil(max(time.get_clock_info("time").resolution,
                                        time.get_clock_info("monotonic").resolution) * 1000))
    except (OSError, AttributeError, ValueError):
        resolution = None
    if arrival is not None and finish is not None and resolution is not None:
        lower = finish[0] - arrival[2]
        upper = finish[2] - arrival[0]
        if lower >= 0 and upper >= lower:
            elapsed = [max(0, lower // 1000000 - resolution), math.ceil(upper / 1000000) + resolution]
            wall_elapsed = finish[1] - arrival[1]
            clock_state = "local_unqualified" if elapsed[0] - 2 * resolution <= wall_elapsed <= elapsed[1] + 2 * resolution else "jump"
        else:
            clock_state = "jump"
    matched = None
    if interval["head_known"]:
        try:
            actual = json.loads(raw)["data"]["repository"]["pullRequest"].get("headRefOid")
            if isinstance(actual, str) and re.fullmatch(r"[0-9a-f]{40}", actual):
                matched = actual == interval["expected_head"]
        except (ValueError, TypeError, KeyError):
            pass
    generation = None
    if interval["head_known"] and interval["sharing_scope"] is not None:
        generation = _target_ordinal("read-generation-v1\0" + key + "\0" + interval["expected_head"] + "\0" + interval["sharing_scope"])
    return {"interval_version": 1, "workflow_id": interval["workflow_id"],
            "workflow_correlation": interval["workflow_correlation"], "generation_ordinal": generation,
            "head_known": interval["head_known"], "head_matches": matched,
            "arrival_utc_ms": arrival[1] if arrival is not None else None,
            "finish_utc_ms": finish[1] if finish is not None else None,
            "elapsed_monotonic_ms": elapsed, "clock_basis": "python_monotonic", "clock_state": clock_state,
            "clock_resolution_ms": resolution,
            "ttl_seconds": interval["ttl_seconds"] if 1 <= interval["ttl_seconds"] <= 1000000000 else None,
            "force_refresh": interval["force_refresh"],
            "cache_age_ms": (cache_age_ms if type(cache_age_ms) is int
                             and 0 <= cache_age_ms <= 604800000 else None),
            "cache_policy": cache_policy,
            "ttl_cacheable": cacheable(raw, interval["expected_head"])}


def emit_read_observation(key, source, caller=None, interval=None, raw=None, cache_age_ms=None, cache_policy="upstream"):
    """Count a completed status read: cache saves an upstream read."""
    if interval is not None:
        interval = dict(interval)
        if "finish" not in interval:
            interval["finish"] = read_clock()
    ordinal = _target_ordinal(key)
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    record = {
        "schema": 6,
        "utc": now,
        "measurement": "read_observation",
        "caller": observation_caller(caller),
        "workflow": "pr_wait",
        "target_ordinal": ordinal,
        "source": source,
        "cache_hit": source == "cache",
        "saved_upstream_read": source == "cache",
    }
    if interval is not None:
        try:
            record.update(read_interval(key, interval, raw, cache_age_ms, cache_policy))
        except Exception:
            # Optional observation cannot alter the original read or emit a
            # second, misleading legacy row after partial collection.
            return
    _emit_record(record)


def emit_write_observation(key, action, content_changed, caller=None):
    """Record a managed cache write or the skip that avoids an unchanged rewrite."""
    ordinal = _target_ordinal(key)
    now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    relation = "new" if content_changed else "unchanged"
    _emit_record({
        "schema": 6,
        "utc": now,
        "measurement": "write_observation",
        "caller": observation_caller(caller),
        "workflow": "pr_wait",
        "target_ordinal": ordinal,
        "action": action,
        "content_relation": relation,
        "duplicate_unchanged_write": action == "written" and not content_changed,
    })


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
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
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
    try:
        interval = begin_read(args.key, args.expected_head, args.ttl, args.force_refresh)
    except Exception:
        interval = None
    joined_ns = time.time_ns()

    def upstream(cache_path):
        observation_interval = interval if cache_path is not None or interval is None else dict(interval, sharing_scope=None)
        return run(command, cache_path, args.age_file, args.source_file, args.expected_head,
                   deadline, args.cap_supervisor_timeout, args.defer_source_mark, args.key, observation_interval)

    directory = Path(args.state_dir)
    if directory.is_symlink() or (directory.exists() and not directory.is_dir()):
        return upstream(None)
    if os.name == "nt":
        if not windows_acl("EnsureCache", directory):
            return upstream(None)
    else:
        try:
            if not hasattr(os, "O_NOFOLLOW"):
                return upstream(None)
            if not unix_prepare_parent(directory.parent):
                return upstream(None)
            directory.mkdir(parents=True, mode=0o700, exist_ok=True)
            if not unix_private(directory, "directory"):
                return upstream(None)
        except OSError:
            return upstream(None)
    bind_read_scope(interval, directory)
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
            flags = os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW
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
                        emit_read_observation(args.key, "cache", interval=interval, raw=raw,
                                              cache_age_ms=max(0, int(wall_age * 1000)),
                                              cache_policy="in_flight" if same_flight else "ttl")
                        return 0
            return upstream(cache)
        finally:
            unlock(owner)


def run(command, cache, age_file, source_file, expected_head=None,
        deadline=None, cap_supervisor_timeout=False, defer_source_mark=False, args_key=None, interval=None):
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
    if interval is not None:
        interval["finish"] = read_clock()
    if cache is not None and len(result.stdout) <= 1048576 and complete(result.stdout):
        previous = None
        if cache.is_file() and not cache.is_symlink():
            try:
                previous = cache.read_bytes()
            except OSError:
                previous = None
        if previous == result.stdout:
            # Zero duplicate unchanged writes: an identical snapshot is already
            # present, so skip the content rewrite and count the avoided
            # duplicate. Refresh mtime anyway so waiters that joined during
            # this refresh still see st_mtime_ns >= joined_ns and share the
            # completed read instead of re-hitting upstream.
            try:
                os.utime(cache, None)
                if interval is not None:
                    interval["finish"] = read_clock()
            except OSError:
                if interval is not None:
                    interval["sharing_scope"] = None
            if args_key:
                emit_write_observation(args_key, "skipped", False)
        else:
            try:
                atomic_write(cache, result.stdout)
                if interval is not None:
                    interval["finish"] = read_clock()
                if args_key:
                    emit_write_observation(args_key, "written", True)
            except OSError:
                # A cache write must not erase an otherwise valid fresh outcome.
                if interval is not None:
                    interval["sharing_scope"] = None
    elif interval is not None:
        interval["sharing_scope"] = None
    if args_key:
        emit_read_observation(args_key, "upstream", interval=interval, raw=result.stdout)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
