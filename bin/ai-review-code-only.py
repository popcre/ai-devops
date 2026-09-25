#!/usr/bin/env python3
"""Build and verify a deliberately narrow, history-free private code review export."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
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
HEX40 = re.compile(r"^[0-9a-f]{40}$")
HEX64 = re.compile(r"^[0-9a-f]{64}$")


def fail(message):
    raise ValueError(message)


def git(root, *args, data=None, check=True):
    proc = subprocess.run(["git", "-C", str(root), *args], input=data, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=False)
    if check and proc.returncode:
        fail("git operation failed: " + " ".join(args[:2]))
    return proc.stdout if check else proc


def digest(data):
    return hashlib.sha256(data).hexdigest()


def source_digest(source):
    script = Path(__file__).with_name("ai-review-sandbox")
    proc = subprocess.run(["bash", str(script), "digest", str(source)], stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE, check=False)
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
    if not item.exists():
        return None
    if not item.is_file():
        fail("nonfile approved path refused")
    # Resolve every parent as well: an ordinary file under a linked directory
    # can otherwise escape the source repository without itself being a link.
    if not item.resolve().is_relative_to(source.resolve()):
        fail("approved path escapes source")
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
    env = dict(os.environ, GIT_AUTHOR_NAME="Code Review Export", GIT_AUTHOR_EMAIL="export@invalid.local",
               GIT_COMMITTER_NAME="Code Review Export", GIT_COMMITTER_EMAIL="export@invalid.local")
    proc = subprocess.run(["git", "-C", str(stage), "commit", "--quiet", "--allow-empty", "-m", label],
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
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
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
    args = parser.parse_args()
    try:
        if args.command == "create":
            create(args)
        elif args.command == "clone":
            clone_export(args)
        else:
            record = validate_snapshot(Path(args.stage).resolve(strict=True), args.assert_head)
            print(json.dumps(record, sort_keys=True))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print("ai-review-code-only: " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
