#!/usr/bin/env python3
"""#658: keep root-run updater Git writes usable by the checkout's owner.

Only update.sh calls this bounded subprocess wrapper. Public Git gets umask022;
the invoking installer retains its private umask. Only new/replaced root-owned
tracked paths and an explicit primary-Git metadata allowlist change ownership.
Private configuration, submodules, other worktrees and untracked files are out
of scope. This is not a general permission-repair command.

Owner: #658 coordinator. Necessary only while supported root-run updates write
an installed owner's public Git checkout. Retire this updater-only helper when
Git writes run as that owner with demonstrated authentication and mode parity.
"""
import os
import pathlib
import re
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
    def directory(path):
        try: info = path.lstat()
        except FileNotFoundError: return False
        if not stat.S_ISDIR(info.st_mode):
            raise ValueError("known primary metadata directory is not a directory")
        entries[path] = 0o755
        return True

    directory(common / "worktrees")

    # Updater fetches/advances only main. Private refs, other branches and their
    # reflogs are not updater outputs, even when another writer creates them.
    for name in ("refs/heads/main", "refs/remotes/origin/main", "logs/HEAD",
                 "logs/refs/heads/main", "logs/refs/remotes/origin/main"):
        relative = pathlib.PurePosixPath(name)
        for depth in range(1, len(relative.parts)):
            directory(common.joinpath(*relative.parts[:depth]))
        entries[common / name] = 0o644

    objects = common / "objects"
    if not directory(objects):
        return entries
    # Only Git's two-hex loose-object buckets are examined. Unknown directories,
    # temporary files, locks and private names are neither opened nor traversed.
    for bucket in objects.iterdir():
        if not re.fullmatch(r"[0-9a-f]{2}", bucket.name):
            continue
        if directory(bucket):
            for path in bucket.iterdir():
                if re.fullmatch(r"(?:[0-9a-f]{38}|[0-9a-f]{62})", path.name):
                    entries[path] = 0o444
    pack = objects / "pack"
    if directory(pack):
        for path in pack.iterdir():
            if (re.fullmatch(r"pack-(?:[0-9a-f]{40}|[0-9a-f]{64})\.(?:pack|idx|rev|bitmap|promisor|keep)", path.name)
                    or path.name == "multi-pack-index"):
                entries[path] = 0o444
    info = objects / "info"
    if directory(info):
        for name in ("commit-graph", "packs"):
            entries[info / name] = 0o444
        graphs = info / "commit-graphs"
        if directory(graphs):
            entries[graphs / "commit-graph-chain"] = 0o444
            for path in graphs.iterdir():
                if re.fullmatch(r"graph-(?:[0-9a-f]{40}|[0-9a-f]{64})\.graph", path.name):
                    entries[path] = 0o444
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
