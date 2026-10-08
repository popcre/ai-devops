#!/usr/bin/env python3
"""Build and verify a deliberately narrow, history-free private code review export."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile


DENIED_PARTS = {
    ".ai", ".git", "archive", "archives", "asset", "assets", "capture",
    "captures", "credential", "credentials", "data", "dataset", "datasets",
    "evidence", "export", "exports", "fixture", "fixtures", "licensed",
    "logs", "private", "raw", "report", "reports", "secret", "secrets",
    "transcript", "transcripts", "vendor", "vendors",
}
CODE_SUFFIXES = {".bash", ".c", ".cc", ".cpp", ".cs", ".go", ".h", ".java", ".js", ".jsx", ".mjs", ".cjs", ".py", ".ps1", ".rs", ".sh", ".ts", ".tsx"}
CONTRACT_SUFFIXES = {".graphql", ".json", ".proto", ".sql", ".yaml", ".yml"}
CONTRACT_PARTS = {"contract", "contracts", "migration", "migrations", "schema", "schemas", "types"}
GATE_DECLARATION = ".ai-devops/task-gates.json"
HEX40 = re.compile(r"^[0-9a-f]{40}$")
HEX64 = re.compile(r"^[0-9a-f]{64}$")


def fail(message):
    raise ValueError(message)


# Absolute repository-location variables in the inherited environment (set by
# git hooks and some wrappers) override `git -C`, which would point the
# synthetic export's git calls at the private source instead of the stage.
# Every git subprocess below runs with these stripped (exact-head review,
# 2026-09-25).
GIT_ENV_BLOCK = frozenset((
    "GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE",
    "GIT_OBJECT_DIRECTORY", "GIT_COMMON_DIR",
    "GIT_ALTERNATE_OBJECT_DIRECTORIES",
))


def git_env(extra=None):
    env = {k: v for k, v in os.environ.items() if k not in GIT_ENV_BLOCK}
    if extra:
        env.update(extra)
    return env


def git(root, *args, data=None, check=True):
    proc = subprocess.run(["git", "-C", str(root), *args], input=data, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=False, env=git_env())
    if check and proc.returncode:
        fail("git operation failed: " + " ".join(args[:2]))
    return proc.stdout if check else proc


def digest(data):
    return hashlib.sha256(data).hexdigest()


def source_digest(source):
    script = Path(__file__).with_name("ai-review-sandbox")
    proc = subprocess.run(["bash", str(script), "digest", str(source)], stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=False, env=git_env())
    if proc.returncode:
        fail("source digest unavailable")
    result = proc.stdout.decode("ascii").strip()
    if not HEX64.fullmatch(result):
        fail("invalid source digest")
    return result


def safe_path(raw):
    if not isinstance(raw, str) or not raw or raw.startswith("/") or "\\" in raw or "\0" in raw:
        fail("invalid approved path")
    if any(ord(char) < 32 or ord(char) == 127 for char in raw):
        fail("control character in approved path")
    if any(char in raw for char in "*?[]{}") or ":" in raw:
        fail("ambiguous approved path")
    parts = raw.split("/")
    if any(part in {"", ".", ".."} for part in parts):
        fail("noncanonical approved path")
    # A private repository's own gate declaration is policy, never licensed
    # rows; it is the one hidden path a sealed review may see, exactly (#1239).
    if raw == GATE_DECLARATION:
        return raw
    lower = [part.lower() for part in parts]
    if any(part in DENIED_PARTS or part.startswith(".") for part in lower):
        fail("evidence or hidden path refused")
    suffix = Path(raw).suffix.lower()
    executable_bin = len(parts) == 2 and lower[0] == "bin" and lower[1].startswith("ai-") and suffix == ""
    if not executable_bin and suffix not in CODE_SUFFIXES and not (suffix in CONTRACT_SUFFIXES and any(p in CONTRACT_PARTS for p in lower[:-1])):
        fail("ambiguous non-code path refused")
    return raw


def approved_paths(path):
    parsed = json.loads(Path(path).read_text(encoding="utf-8"))
    if not isinstance(parsed, list) or not parsed or not all(isinstance(p, str) for p in parsed):
        fail("approved path file must be a nonempty JSON string array")
    paths = [safe_path(p) for p in parsed]
    if len(set(paths)) != len(paths) or len({p.casefold() for p in paths}) != len(paths):
        fail("duplicate approved path")
    return sorted(paths)


def tree_mode(source, ref, path):
    proc = git(source, "ls-tree", "-z", ref, "--", path)
    if not proc:
        return None
    rows = [row for row in proc.split(b"\0") if row]
    if len(rows) != 1:
        fail("ambiguous approved tree path")
    metadata, name = rows[0].split(b"\t", 1)
    if name.decode("utf-8", "surrogateescape") != path:
        fail("nonexact approved tree path")
    mode, kind, _ = metadata.split(b" ")
    if kind != b"blob" or mode not in {b"100644", b"100755"}:
        fail("symlink or submodule refused")
    return mode


def current_bytes(source, path):
    item = source.joinpath(*path.split("/"))
    if item.is_symlink():
        fail("symlink refused")
    # A linked PARENT that stays inside the repository can smuggle a denied
    # directory under an approved spelling (src -> data plus an approved
    # src/tracked.txt), so every parent below the source root must be a real
    # directory, not a link (exact-head review, 2026-09-25).
    walked = source.resolve()
    for part in path.split("/")[:-1]:
        walked = walked / part
        if walked.is_symlink():
            fail("linked parent directory refused")
        if not walked.exists():
            break
    if not item.exists():
        return None
    if not item.is_file():
        fail("nonfile approved path refused")
    # Resolve every parent as well: an ordinary file under a linked directory
    # can otherwise escape the source repository without itself being a link.
    resolved_root = source.resolve()
    resolved = item.resolve()
    # A hardlink keeps the approved spelling while its bytes are shared with a
    # denied location, and resolve() cannot see it; the link count is the only
    # witness (exact-head review, 2026-09-25).
    if item.stat().st_nlink != 1 or resolved.stat().st_nlink != 1:
        fail("hardlinked approved path refused")
    if not resolved.is_relative_to(resolved_root):
        fail("approved path escapes source")
    # The approved spelling passed the denied-parts check; the resolved
    # location must pass it too, or a link could rename a denied directory
    # into an approved-looking one.
    relative = resolved.relative_to(resolved_root)
    lowered = [part.lower() for part in relative.parts]
    if relative.as_posix() == GATE_DECLARATION and relative.as_posix() == path:
        pass
    elif any(part in DENIED_PARTS or part.startswith(".") for part in lowered):
        fail("approved path resolves into a refused location")
    value = item.read_bytes()
    validate_text(value)
    return value


def validate_text(value):
    if len(value) > 1_048_576 or b"\0" in value:
        fail("oversized or binary approved path refused")
    try:
        value.decode("utf-8")
    except UnicodeDecodeError:
        fail("non-UTF-8 approved path refused")


def manifest_for(source, paths, head, base):
    entries = []
    for path in paths:
        head_mode = tree_mode(source, head, path)
        base_mode = tree_mode(source, base, path)
        if head_mode is None and base_mode is None:
            ignored = git(source, "check-ignore", "--no-index", "--", path, check=False)
            if ignored.returncode == 0:
                fail("ignored approved path refused")
        value = current_bytes(source, path)
        if head_mode is None and base_mode is None and value is None:
            fail("approved path is absent from base, head, and worktree")
        if base_mode:
            validate_text(git(source, "show", f"{base}:{path}"))
        entries.append({"path": path, "current_sha256": digest(value) if value is not None else None,
                        "base_mode": base_mode.decode() if base_mode else None,
                        "head_mode": head_mode.decode() if head_mode else None})
    return entries


def write_tree(stage, source, paths, base=None):
    for path in paths:
        if base is None:
            value = current_bytes(source, path)
        else:
            value = git(source, "show", f"{base}:{path}") if tree_mode(source, base, path) else None
        target = stage.joinpath(*path.split("/"))
        if value is None:
            if target.exists():
                target.unlink()
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(value)


def commit(stage, label):
    git(stage, "add", "--all")
    env = git_env({
        "GIT_AUTHOR_NAME": "Code Review Export", "GIT_AUTHOR_EMAIL": "export@invalid.local",
        "GIT_COMMITTER_NAME": "Code Review Export", "GIT_COMMITTER_EMAIL": "export@invalid.local",
    })
    # The synthetic export is machine-generated evidence, never a signed or
    # hooked commit: inherit neither commit.gpgsign nor commit hooks from the
    # user's global config, which would fail closed with a generic refusal
    # (exact-head review, 2026-09-25).
    proc = subprocess.run(["git", "-C", str(stage), "-c", "commit.gpgsign=false",
                           "commit", "--quiet", "--allow-empty", "--no-verify", "-m", label],
                          env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if proc.returncode:
        fail("could not commit synthetic export")


def validate_snapshot(stage, expected=None):
    marker = stage / ".ai-review-sandbox"
    if not marker.is_file() or marker.is_symlink():
        fail("code-only marker missing")
    lines = marker.read_text(encoding="utf-8").splitlines()
    if len(lines) != 1:
        fail("code-only marker malformed")
    record = json.loads(lines[0])
    if not isinstance(record, dict):
        fail("code-only marker malformed")
    owner_file = stage.with_name(stage.name + ".owners.json")
    if not owner_file.is_file() or owner_file.is_symlink():
        fail("host-only evidence ownership is missing")
    ownership = json.loads(owner_file.read_text(encoding="utf-8"))
    if (not isinstance(ownership, dict) or ownership.get("schema_version") != 1 or
            ownership.get("mode") != "code-only" or
            ownership.get("marker_sha256") != digest(marker.read_bytes()) or
            ownership.get("source_id") != record.get("source_id") or
            ownership.get("export_head") != record.get("export_head") or
            not isinstance(ownership.get("review_source"), str) or
            not isinstance(ownership.get("owners"), list) or
            any(not isinstance(owner, str) or not re.fullmatch(r"[a-z]+:[0-9a-f]{32}", owner)
                for owner in ownership["owners"]) or
            len(ownership["owners"]) != len(set(ownership["owners"]))):
        fail("host-only evidence ownership is invalid")
    Path(ownership["review_source"]).resolve(strict=True)
    sidecar = stage.with_name(stage.name + ".source.json")
    if not sidecar.is_file() or sidecar.is_symlink():
        fail("host-only source binding missing")
    binding = json.loads(sidecar.read_text(encoding="utf-8"))
    source = Path(binding["source"]).resolve(strict=True)
    if digest(str(source).encode()) != record.get("source_id"):
        fail("host-only source binding mismatch")
    if record.get("mode") != "code-only" or record.get("schema_version") != 1:
        fail("code-only marker invalid")
    head = record.get("original_head")
    if not isinstance(head, str) or not HEX40.fullmatch(head) or (expected and head != expected):
        fail("original head mismatch")
    if git(source, "rev-parse", "HEAD").decode().strip() != head:
        fail("original source head moved")
    if source_digest(source) != record.get("source_digest"):
        fail("original source digest moved")
    paths = record.get("paths")
    if not isinstance(paths, list) or not paths or [safe_path(p) for p in paths] != sorted(set(paths)):
        fail("approved paths invalid")
    base = record.get("original_base")
    if not isinstance(base, str) or not HEX40.fullmatch(base):
        fail("original base invalid")
    if git(source, "merge-base", base, head).decode().strip() != base:
        fail("original base no longer anchors source HEAD")
    actual = manifest_for(source, paths, head, base)
    if digest(json.dumps(actual, sort_keys=True, separators=(",", ":")).encode()) != record.get("path_manifest_sha256"):
        fail("approved path contents moved")
    if git(stage, "rev-list", "--count", "HEAD").decode().strip() != "2":
        fail("synthetic history is not exactly two commits")
    synthetic_head = git(stage, "rev-parse", "HEAD").decode().strip()
    if synthetic_head != record.get("export_head"):
        fail("synthetic head moved")
    if git(stage, "rev-parse", "HEAD^{tree}").decode().strip() != record.get("export_tree"):
        fail("synthetic tree moved")
    present = set()
    for row in git(stage, "ls-files", "-z").split(b"\0"):
        if row:
            present.add(row.decode("utf-8", "surrogateescape"))
    if not present.issubset(set(paths)):
        fail("unapproved file in synthetic export")
    baseline = {row.decode("utf-8", "surrogateescape") for row in
                git(stage, "ls-tree", "-r", "--name-only", "-z", "HEAD^").split(b"\0") if row}
    if not baseline.issubset(set(paths)):
        fail("unapproved file in synthetic history")
    for path in paths:
        value = current_bytes(stage, path)
        expected_value = current_bytes(source, path)
        if value != expected_value:
            fail("synthetic file content mismatch")
        tree_mode(stage, "HEAD", path)
        tree_mode(stage, "HEAD^", path)
        source_base = git(source, "show", f"{base}:{path}") if tree_mode(source, base, path) else None
        export_base = git(stage, "show", f"HEAD^:{path}") if tree_mode(stage, "HEAD^", path) else None
        if source_base != export_base:
            fail("synthetic baseline content mismatch")
    extras = git(stage, "ls-files", "--others", "--exclude-standard", "-z").split(b"\0")
    if any(item and item.decode("utf-8", "surrogateescape") != ".ai-review-sandbox"
           and item.decode("utf-8", "surrogateescape") != "AI-REVIEW-SANDBOX.md"
           and not re.match(r"^\.ai-review-[^/]+/", item.decode("utf-8", "surrogateescape")) for item in extras):
        fail("unexpected untracked export file")
    if record.get("export_digest") != digest(git(stage, "archive", "--format=tar", "HEAD")):
        fail("synthetic export digest moved")
    allowed = set(paths) | {".ai-review-sandbox", "AI-REVIEW-SANDBOX.md"}
    for item in stage.rglob("*"):
        rel = item.relative_to(stage).as_posix()
        if rel == ".git" or rel.startswith(".git/") or rel == ".ai/deepseek-sessions" or rel.startswith(".ai/deepseek-sessions/"):
            continue
        if re.match(r"^\.ai-review-[^/]+(?:/|$)", rel):
            continue
        if item.is_symlink():
            fail("symlink appeared in synthetic export")
        if item.is_file() and rel not in allowed:
            fail("unapproved file appeared in synthetic export")
    return record


def create(args):
    source = Path(args.source).resolve(strict=True)
    stage = Path(args.stage)
    if stage.exists() or stage.is_symlink():
        fail("export destination already exists")
    paths = approved_paths(args.paths_file)
    head = git(source, "rev-parse", "HEAD").decode().strip()
    if not HEX40.fullmatch(head):
        fail("original head invalid")
    source_before = source_digest(source)
    target_ref = args.base or "refs/remotes/origin/main"
    target = git(source, "rev-parse", "--verify", f"{target_ref}^{{commit}}", check=False)
    if target.returncode:
        fail("requested code-only base is unavailable")
    target_sha = target.stdout.decode().strip()
    base = git(source, "merge-base", "HEAD", target_sha).decode().strip()
    if args.base and base != target_sha:
        fail("requested code-only base is not an ancestor of source HEAD")
    manifest = manifest_for(source, paths, head, base)
    stage.mkdir(parents=True)
    git(stage, "init", "--quiet")
    git(stage, "config", "--local", "core.autocrlf", "false")
    write_tree(stage, source, paths, base)
    commit(stage, "Approved code baseline")
    write_tree(stage, source, paths)
    commit(stage, "Approved code under review")
    if git(source, "rev-parse", "HEAD").decode().strip() != head or source_digest(source) != source_before:
        fail("original source changed during export")
    record = {"schema_version": 1, "mode": "code-only", "source_id": digest(str(source).encode()), "original_head": head,
              "original_base": base, "source_digest": source_before, "paths": paths,
              "path_manifest_sha256": digest(json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()),
              "export_head": git(stage, "rev-parse", "HEAD").decode().strip(),
              "export_tree": git(stage, "rev-parse", "HEAD^{tree}").decode().strip(),
              "export_digest": digest(git(stage, "archive", "--format=tar", "HEAD"))}
    (stage / ".ai-review-sandbox").write_text(json.dumps(record, sort_keys=True) + "\n", encoding="utf-8")
    sidecar = stage.with_name(stage.name + ".source.json")
    sidecar.write_text(json.dumps({"source": str(source)}, sort_keys=True) + "\n", encoding="utf-8")
    sidecar.chmod(0o600)
    owner_file = stage.with_name(stage.name + ".owners.json")
    owner_file.write_text(json.dumps({"schema_version": 1, "mode": "code-only",
                                      "marker_sha256": digest((stage / ".ai-review-sandbox").read_bytes()),
                                      "source_id": record["source_id"], "export_head": record["export_head"],
                                      "review_source": str(source), "owners": []}, sort_keys=True) + "\n",
                          encoding="utf-8")
    owner_file.chmod(0o600)
    with (stage / ".git" / "info" / "exclude").open("a", encoding="utf-8") as out:
        out.write("\n/.ai-review-sandbox\n/AI-REVIEW-SANDBOX.md\n/.ai-review-*/\n/.ai/deepseek-sessions/\n")
    (stage / "AI-REVIEW-SANDBOX.md").write_text(
        "# Sanitized code review export\n\nOnly explicitly approved code and contract paths are present. "
        "The two Git commits are synthetic and carry no source history. Review this directory only.\n", encoding="utf-8")
    validate_snapshot(stage, head)


def clone_export(args):
    source_export = Path(args.source_export).resolve(strict=True)
    record = validate_snapshot(source_export)
    stage = Path(args.stage)
    if stage.exists() or stage.is_symlink():
        fail("export copy destination already exists")
    proc = subprocess.run(["git", "-c", "core.autocrlf=false", "clone", "--quiet", "--no-hardlinks", str(source_export), str(stage)],
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False, env=git_env())
    if proc.returncode:
        fail("could not clone synthetic export")
    git(stage, "config", "--local", "core.autocrlf", "false")
    git(stage, "remote", "remove", "origin")
    git(stage, "checkout", "--quiet", "--detach", record["export_head"])
    shutil.copyfile(source_export / ".ai-review-sandbox", stage / ".ai-review-sandbox")
    shutil.copyfile(source_export.with_name(source_export.name + ".source.json"),
                    stage.with_name(stage.name + ".source.json"))
    owner_file = stage.with_name(stage.name + ".owners.json")
    owner_file.write_text(json.dumps({"schema_version": 1, "mode": "code-only",
                                      "marker_sha256": digest((stage / ".ai-review-sandbox").read_bytes()),
                                      "source_id": record["source_id"], "export_head": record["export_head"],
                                      "review_source": str(source_export), "owners": []}, sort_keys=True) + "\n",
                          encoding="utf-8")
    owner_file.chmod(0o600)
    (stage / "AI-REVIEW-SANDBOX.md").write_text(
        "# Sanitized code review export\n\nOnly explicitly approved code and contract paths are present. "
        "The two Git commits are synthetic and carry no source history. Review this directory only.\n", encoding="utf-8")
    with (stage / ".git" / "info" / "exclude").open("a", encoding="utf-8") as out:
        out.write("\n/.ai-review-sandbox\n/AI-REVIEW-SANDBOX.md\n/.ai-review-*/\n/.ai/deepseek-sessions/\n")
    validate_snapshot(stage, record["original_head"])


def private_read(path, limit=16 * 1024 * 1024, private=True):
    """Read a bounded private regular inode through no-follow directory handles."""
    if os.name != "posix" or not hasattr(os, "O_NOFOLLOW"):
        fail("native proof requires supported no-follow filesystem reads")
    path = Path(path).absolute()
    if ".." in path.parts:
        fail("unsafe evidence path")
    fd = os.open(path.anchor, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in path.parts[1:-1]:
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = next_fd
        descriptor = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
        with os.fdopen(descriptor, "rb") as stream:
            before = os.fstat(stream.fileno())
            if not stat.S_ISREG(before.st_mode) or before.st_uid not in ((os.getuid(),) if private else (0, os.getuid())) or before.st_mode & (0o077 if private else 0o022) or before.st_size > limit:
                fail("native evidence inode is not private and bounded")
            content = stream.read(limit + 1)
            after = os.fstat(stream.fileno())
            if len(content) > limit or (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns) != (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns):
                fail("native evidence changed during read")
            return content
    finally:
        os.close(fd)


def private_publish(stage, run_id, data):
    if not re.fullmatch(r"code-only-[A-Za-z0-9-]+", run_id):
        fail("invalid invocation report identity")
    fd = os.open(stage, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in (".ai-review-lifecycle", run_id):
            try:
                os.mkdir(part, mode=0o700, dir_fd=fd)
            except FileExistsError:
                pass
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = next_fd
            info = os.fstat(fd)
            if info.st_uid != os.getuid() or info.st_mode & 0o077:
                fail("report parent is not private")
        report_fd = os.open("report.txt", os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=fd)
        with os.fdopen(report_fd, "wb") as out:
            out.write(data)
    finally:
        os.close(fd)


def lifecycle_proof(args):
    # This is prospective completion of an existing original-source invocation,
    # never an import API. Identity is derived from the sealed export mapping.
    state = json.loads(private_read(args.state))
    if state.get("status") != ("completed" if args.completed else "running") or state.get("provider") != "deepseek":
        fail("no running DeepSeek invocation")
    if not state.get("implementer_engine") or state["implementer_engine"].lower() == "deepseek":
        fail("independent implementer required")
    stage = Path(state["code_only_export"]).resolve(strict=True)
    record = validate_snapshot(stage, state["head"])
    if record != state["code_only"] or record["source_digest"] != state["source_digest"]:
        fail("prospective source binding changed")
    source = json.loads(stage.with_name(stage.name + ".source.json").read_text())["source"]
    if Path(source).resolve() != Path(state["repository_root"]).resolve():
        fail("original repository mapping differs")
    sid = args.session
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,127}", sid):
        fail("invalid native session")
    if sid.split(".")[0].upper() in {"CON", "PRN", "AUX", "NUL", *("COM" + str(n) for n in range(1, 10)), *("LPT" + str(n) for n in range(1, 10))}:
        fail("reserved native session")
    sessions = stage / ".ai" / "deepseek-sessions"
    for directory in (stage, stage / ".ai", sessions):
        if directory.is_symlink() or not directory.is_dir() or directory.stat().st_uid != os.getuid() or directory.stat().st_mode & 0o022:
            fail("native evidence directory is not privately owned")
    def regular(path):
        path = Path(path)
        if path.is_symlink() or not path.is_file() or sessions.resolve() not in path.resolve().parents:
            fail("native evidence outside owned session")
        return private_read(path)
    meta = json.loads(regular(sessions / (sid + ".meta.json")))
    pending = sessions / (sid + ".pending")
    intent_bytes = regular(pending / "intent.json")
    intent = json.loads(intent_bytes)
    if digest(intent_bytes) != regular(pending / "intent.sha256").decode().strip():
        fail("native intent seal changed")
    complete = json.loads(regular(pending / "complete.json"))
    observed = json.loads(regular(pending / "observed.json"))
    for evidence in (meta, intent):
        if evidence.get("provider") != "deepseek" or evidence.get("model") != "deepseek-flash" or evidence.get("session_id") != sid or evidence.get("head") != record["export_head"] or evidence.get("governed_head") != record["export_head"] or Path(evidence.get("repository_root", "")).resolve() != stage or evidence.get("caller") != state["caller"]:
            fail("native session identity differs")
    if meta.get("schema_version") != 2 or intent.get("schema_version") != 1:
        fail("native evidence schema differs")
    if meta.get("status") != "complete" or meta.get("verdict_mode") != "governed" or meta.get("evidence_scope") not in ("attached-materials-only", "repository-read-tools") or not isinstance(meta.get("repository_access"), bool) or intent.get("repository_access") is not meta.get("repository_access") or intent.get("review") != 1 or intent.get("before_transcript_sha256") != "absent" or complete.get("state") != "complete" or complete.get("incomplete_reason"):
        fail("native completion is not fresh synthetic-export review")
    identity = meta.get("source_identity", {})
    if identity.get("schema_version") != 1 or identity.get("head") != record["export_head"] or Path(identity.get("repository", "")).resolve() != stage or identity.get("code_only") != record:
        fail("provider reviewed another export")
    source_identity_file = Path(intent["source_identity_file"])
    if json.loads(regular(source_identity_file)) != identity or digest(regular(str(source_identity_file) + ".files")) != intent.get("source_files_sha256"):
        fail("native resolved source identity differs")
    if digest(regular(pending / "messages.json")) != intent.get("request_sha256"):
        fail("native request seal differs")
    if digest(regular(sessions / (sid + ".attachments"))) != complete.get("ledger_sha256"):
        fail("native completed attachment ledger differs")
    transcript = regular(sessions / (sid + ".json"))
    if digest(transcript) != complete.get("transcript_sha256"):
        fail("native transcript changed")
    response = regular(observed.get("response_path", ""))
    if type(observed.get("transport_exit_code")) is not int or observed.get("transport_exit_code") != 0 or str(observed.get("http_status")) != "200" or digest(response) != observed.get("response_sha256"):
        fail("native provider transport proof differs")
    content = json.loads(response)["choices"][0]["message"]["content"]
    if not isinstance(content, str) or not content.strip():
        fail("native response has no final message")
    messages = json.loads(transcript)
    if messages[-1].get("role") != "assistant" or messages[-1].get("content") != content.rstrip("\n"):
        fail("native final transcript differs from response")
    if regular(pending / "reply.txt") != (content + "\n").encode():
        fail("native final reply differs from response")
    verdicts = re.findall(r"^VERDICT: (APPROVE|REVISE|REJECT|BLOCKED) " + re.escape(record["export_head"]) + r"\s*$", content, re.M)
    if len(verdicts) != 1 or verdicts[0] != meta.get("verdict"):
        fail("native governed verdict differs")
    packet = Path(meta["source_packet_directory"])
    expected_tag = "deepseek-" + digest(intent["source_identity_file"].encode())[:24]
    if packet != sessions / (".ai-review-" + expected_tag) or intent.get("source_tag") != expected_tag or packet.is_symlink() or not packet.is_dir() or intent.get("source_packet") != str(packet) or intent.get("packet_sha256") != meta.get("packet_sha256"):
        fail("native packet binding differs")
    proc = subprocess.run([str(Path(__file__).with_name("ai-review-packet")), "verify", str(packet)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode or regular(packet / "MANIFEST.sha256").decode().strip() != meta["packet_sha256"] or json.loads(regular(packet / "identity.json")) != meta["source_identity"]:
        fail("native packet verification refused")
    if state.get("action_profile_binding"):
        binding = state["action_profile_binding"]
        expected_line = "Action scope: " + binding["profile"] + " descriptor sha256:" + binding["manifest_descriptor_sha256"] + "."
        if verdicts[0] == "APPROVE" and content.splitlines().count(expected_line) != 1:
            fail("native approval does not explicitly cover the exact bounded action")
        action = subprocess.run([sys.executable, str(Path(__file__).resolve().parents[1] / "tools/review_action_profile.py"), "finish", args.state, "--manifest", state["action_manifest"]], stdout=subprocess.PIPE, stderr=subprocess.PIPE) if not args.completed else None
        if not args.completed and action.returncode:
            fail("bounded action changed during prospective review")
    raw_final = content.encode("utf-8")
    exact = messages[-1]["content"].encode("utf-8")
    report = Path(args.report).absolute()
    if report != stage / ".ai-review-lifecycle" / state["run_id"] / "report.txt":
        fail("report is outside the owned invocation")
    if args.publish:
        if args.completed:
            fail("completed native proof is read-only; publication is prospective only")
        if report.is_symlink() or report.exists():
            fail("report destination already exists")
        if private_read(args.publish) != (content.rstrip("\n") + "\n").encode():
            fail("provider stdout differs from actual final message")
        private_publish(stage, state["run_id"], exact)
    if report.is_symlink() or not report.is_file() or private_read(report) != exact:
        fail("report bytes differ from actual final message")
    print(json.dumps({"verdict": {"APPROVE": "APPROVE", "REVISE": "REJECT", "REJECT": "REJECT", "BLOCKED": "BLOCKED"}[verdicts[0]], "packet_dir": str(packet), "packet_sha256": meta["packet_sha256"], "response_sha256": observed["response_sha256"], "raw_final_message_sha256": digest(raw_final), "transcript_report_sha256": digest(exact), "session_id": sid}, sort_keys=True))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    builder = sub.add_parser("create")
    builder.add_argument("source")
    builder.add_argument("stage")
    builder.add_argument("paths_file")
    builder.add_argument("--base")
    cloner = sub.add_parser("clone")
    cloner.add_argument("source_export")
    cloner.add_argument("stage")
    verifier = sub.add_parser("verify")
    verifier.add_argument("stage")
    verifier.add_argument("--assert-head")
    proof = sub.add_parser("lifecycle-proof")
    proof.add_argument("state")
    proof.add_argument("session")
    proof.add_argument("report")
    proof.add_argument("--publish")
    proof.add_argument("--completed", action="store_true")
    args = parser.parse_args()
    try:
        if args.command == "create":
            create(args)
        elif args.command == "clone":
            clone_export(args)
        elif args.command == "lifecycle-proof":
            lifecycle_proof(args)
        else:
            record = validate_snapshot(Path(args.stage).resolve(strict=True), args.assert_head)
            print(json.dumps(record, sort_keys=True))
    except (OSError, ValueError, KeyError, IndexError, TypeError, json.JSONDecodeError) as exc:
        print("ai-review-code-only: " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
