#!/usr/bin/env python3
"""#658: keep root-run updater Git writes usable by the checkout's owner.

Only update.sh calls this bounded subprocess wrapper. Public Git gets umask022;
the invoking installer retains its private umask. Only new/replaced root-owned
tracked paths and an explicit primary-Git metadata allowlist change ownership.
Private configuration, submodules, other worktrees and untracked files are out
of scope. This is not a general permission-repair command.
"""
import os
import pathlib
import stat
import subprocess
import sys


STORAGE_OVERRIDES = {"GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_INDEX_FILE",
                     "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES"}


def metadata(path):
    try:
        info = path.lstat()
    except FileNotFoundError:
        return None
    return (info.st_dev, info.st_ino, info.st_uid, info.st_gid,
            stat.S_IMODE(info.st_mode), info.st_ctime_ns, info.st_mtime_ns)


def tracked(root):
    entries = {}
    output = subprocess.check_output(["git", "-C", str(root), "ls-files", "--stage", "-z"])
    for row in output.split(b"\0"):
        if not row:
            continue
        header, name = row.split(b"\t", 1)
        mode, _, stage = header.split()
        if stage != b"0" or mode not in (b"100644", b"100755"):
            continue
        relative = pathlib.PurePosixPath(os.fsdecode(name))
        if relative.is_absolute() or ".." in relative.parts:
            raise ValueError("tracked source path escapes checkout")
        path = root.joinpath(*relative.parts)
        entries[path] = 0o755 if mode == b"100755" else 0o644
        for depth in range(1, len(relative.parts)):
            parent = root.joinpath(*relative.parts[:depth])
            if parent.is_symlink():
                raise ValueError("tracked source directory is a symlink")
            entries.setdefault(parent, 0o755)
    return entries


def primary_metadata(common):
    entries = {common / name: 0o644 for name in ("HEAD", "index", "packed-refs", "FETCH_HEAD", "ORIG_HEAD")}
    # The shared container is needed by future owner worktree creation. No
    # registered worktree's administrative contents are ever enumerated.
    entries[common / "worktrees"] = 0o755
    for name in ("refs", "objects", "logs"):
        base = common / name
        if not base.exists():
            continue
        if base.is_symlink():
            raise ValueError("primary metadata root is a symlink")
        for directory, children, files in os.walk(base, followlinks=False):
            directory = pathlib.Path(directory)
            entries[directory] = 0o755
            if any((directory / child).is_symlink() for child in children):
                raise ValueError("primary metadata directory is a symlink")
            for filename in files:
                # Lock files belong to their live Git writer, never this repair.
                if filename.endswith(".lock") or name == "objects" and filename == "alternates":
                    continue
                path = directory / filename
                if path.is_symlink():
                    raise ValueError("primary metadata file is a symlink")
                entries[path] = 0o444 if name == "objects" else 0o644
    return entries


def pinned_open(base, path):
    """Do not follow a replaced parent directory outside this exact base."""
    relative = path.relative_to(base)
    descriptor = os.open(base, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        for part in relative.parts[:-1]:
            following = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
                                dir_fd=descriptor)
            os.close(descriptor)
            descriptor = following
        return os.open(relative.parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_CLOEXEC, dir_fd=descriptor)
    finally:
        os.close(descriptor)


def public_git(root, arguments):
    root = pathlib.Path(root).resolve(strict=True)
    if STORAGE_OVERRIDES.intersection(os.environ):
        raise ValueError("updater Git storage overrides are not permitted")
    # Only storage routing is excluded. Existing authentication, credential
    # configuration and SSH identity selection retain their ordinary behavior.
    identity_environment = {name: value for name, value in os.environ.items() if name not in STORAGE_OVERRIDES}
    top = pathlib.Path(subprocess.check_output(
        ["git", "-C", str(root), "rev-parse", "--show-toplevel"], env=identity_environment, text=True).strip())
    primary = root / ".git"
    if not top.samefile(root) or primary.is_symlink() or not primary.is_dir():
        raise ValueError("updater requires the exact primary source checkout")
    owner = root.stat()
    common = pathlib.Path(subprocess.check_output(
        ["git", "-C", str(root), "rev-parse", "--path-format=absolute", "--git-common-dir"],
        env=identity_environment, text=True).strip())
    if not common.samefile(primary):
        raise ValueError("updater Git common directory differs from the primary checkout")
    before = {}
    if os.geteuid() == 0 and owner.st_uid != 0:
        before = {path: metadata(path) for path in (tracked(root) | primary_metadata(common))}
    # Popen's native umask option avoids changing any parent process/thread.
    result = subprocess.run(["git", "-C", str(root), *arguments], umask=0o022)
    if os.geteuid() == 0 and owner.st_uid != 0:
        try:
            restore_outputs(root, common, owner, before)
        except (OSError, ValueError):
            print("public Git ownership restoration failed; source capability needs recovery", file=sys.stderr)
            if result.returncode:
                return result.returncode
            raise
    return result.returncode


def restore_outputs(root, common, owner, before):
    if subprocess.run(["git", "-C", str(root), "diff", "--no-ext-diff", "--quiet", "HEAD", "--"]).returncode:
        raise ValueError("public source changed outside the Git result")
    candidates = tracked(root) | primary_metadata(common)
    if (root.stat().st_dev, root.stat().st_ino) != (owner.st_dev, owner.st_ino):
        raise ValueError("installed checkout identity changed during Git")
    for path, intended_mode in candidates.items():
        observed = metadata(path)
        prior = before.get(path)
        if observed is None or observed[2] != 0 or (prior is not None and observed[:2] == prior[:2]):
            continue
        # Existing directories keep established ownership/permissions. Only
        # exact new directories and new/replaced public file inodes qualify.
        info = path.lstat()
        if stat.S_ISDIR(info.st_mode) and prior is not None:
            continue
        if not (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)):
            raise ValueError("public Git output is not a regular file/directory")
        descriptor = pinned_open(common if path.is_relative_to(common) else root, path)
        try:
            pinned = os.fstat(descriptor)
            if ((pinned.st_dev, pinned.st_ino, pinned.st_uid, pinned.st_gid,
                 stat.S_IMODE(pinned.st_mode), pinned.st_ctime_ns, pinned.st_mtime_ns) != observed
                    or metadata(path) != observed):
                raise ValueError("public Git output changed outside updater custody")
            os.fchown(descriptor, owner.st_uid, owner.st_gid)
            os.fchmod(descriptor, intended_mode)
        finally:
            os.close(descriptor)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit("usage: install-public-git.py CHECKOUT GIT_ARGUMENT...")
    raise SystemExit(public_git(sys.argv[1], sys.argv[2:]))
