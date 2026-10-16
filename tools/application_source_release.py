#!/usr/bin/env python3
"""Supplemental, read-only proofs for three exact Linux sandbox source releases.

This module cannot approve, deploy, or publish a receipt. Backend deliberately
does not enter this supplemental path; its existing admission remains unchanged.
"""
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

NEW_REPOSITORIES = {
    "popcre/designflow-tracking", "popcre/designflow-frontend",
    "popcre/designflow-item-master",
}
MANIFEST = ".ai-devops/application-release-target.json"
GIT = "/usr/bin/git"
GH = "/usr/bin/gh"
SHA = re.compile(r"[0-9a-f]{40}\Z")
UNSAFE = {
    "GIT_DIR", "GIT_WORK_TREE", "GIT_COMMON_DIR", "GIT_INDEX_FILE",
    "GIT_OBJECT_DIRECTORY", "GIT_ALTERNATE_OBJECT_DIRECTORIES", "GIT_NAMESPACE",
    "GIT_CEILING_DIRECTORIES", "GIT_DISCOVERY_ACROSS_FILESYSTEM", "GIT_CONFIG",
    "GIT_CONFIG_SYSTEM", "GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM",
    "GIT_CONFIG_COUNT", "GIT_CONFIG_PARAMETERS", "GIT_REPLACE_REF_BASE",
    "GIT_GRAFT_FILE",
    "GIT_SHALLOW_FILE", "GIT_EXEC_PATH", "LD_PRELOAD", "LD_LIBRARY_PATH", "LD_AUDIT",
}


def require(ok, message):
    if not ok:
        raise ValueError(message)


def unique(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate JSON key")
        result[key] = value
    return result


def parse(raw):
    require(len(raw) <= 262144, "oversized proof input")
    def constant(_):
        raise ValueError("nonstandard JSON constant")
    return json.loads(raw, object_pairs_hook=unique, parse_constant=constant)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def public_binary(path):
    actual = Path(path).resolve(strict=True)
    require(str(actual).startswith("/usr/") or str(actual).startswith("/lib/"),
            "untrusted executable origin")
    require(actual.is_file() and os.access(actual, os.X_OK), "executable unavailable")
    for entry in (actual, *actual.parents):
        info = entry.stat()
        require(info.st_uid == 0 and not info.st_mode & 0o022,
                "executable origin is writable or not root-owned")
    return str(actual)


def confined_environment(env):
    require(sys.platform.startswith("linux"), "new source-release targets require qualified Linux")
    for key, value in env.items():
        require(not value or not (key in UNSAFE or key.startswith("GIT_CONFIG_KEY_")
                                 or key.startswith("GIT_CONFIG_VALUE_")),
                "Git context environment override refused")
    require(not env.get("AI_GH_REAL_GH"), "caller-selected GitHub executable refused")
    require(shutil.which("git", path=env.get("PATH")) is not None,
            "Git executable unavailable")
    require(Path(shutil.which("git", path=env.get("PATH"))).resolve() == Path(GIT).resolve(),
            "PATH-selected Git executable refused")
    public_binary(GIT)
    return dict(env)


def discriminator(root):
    """No Git discovery. Not an authorization: final target/source binding is mandatory."""
    try:
        path = Path(root) / MANIFEST
        require(not path.parent.is_symlink() and path.is_file() and not path.is_symlink()
                and path.stat().st_size <= 262144, "manifest unavailable")
        value = parse(path.read_bytes())
        repo = value.get("repository") if type(value) is dict else None
        return repo if repo in NEW_REPOSITORIES else ""
    except (OSError, ValueError, TypeError):
        return ""


def run(argv, root, env):
    completed = subprocess.run(argv, cwd=root, env=env, capture_output=True, timeout=30,
                               check=False)
    require(completed.returncode == 0, "read-only source-release proof command failed")
    require(len(completed.stdout) <= 262144, "oversized proof response")
    return completed.stdout


def git(root, env, *args):
    return run([GIT, "-C", str(root), *args], root, env).decode().strip()


def origin_forms(repo):
    return {f"https://github.com/{repo}{suffix}" for suffix in ("", ".git")} | {
        f"git@github.com:{repo}{suffix}" for suffix in ("", ".git")
    } | {f"ssh://git@github.com/{repo}{suffix}" for suffix in ("", ".git")}


def local_context(root, repo, base, env):
    require(repo in NEW_REPOSITORIES, "supplemental target refused")
    require(SHA.fullmatch(base), "recorded base unavailable")
    root = Path(root).resolve(strict=True)
    require(Path.cwd().resolve() == root, "source root differs from selected context")
    require(Path(git(root, env, "rev-parse", "--show-toplevel")).resolve() == root,
            "Git source root differs")
    common = Path(git(root, env, "rev-parse", "--path-format=absolute", "--git-common-dir"))
    common = common.resolve(strict=True)
    require(git(root, env, "rev-parse", "--is-shallow-repository") == "false",
            "shallow history refused")
    require(not git(root, env, "replace", "-l"), "replacement ancestry refused")
    graft = common / "info/grafts"
    require(not graft.exists() or graft.stat().st_size == 0, "grafted ancestry refused")
    raw_origin = git(root, env, "config", "--get-all", "remote.origin.url")
    effective_origin = git(root, env, "remote", "get-url", "origin")
    require(raw_origin in origin_forms(repo) and effective_origin in origin_forms(repo),
            "canonical origin required")
    require(git(root, env, "symbolic-ref", "--short", "HEAD") == "sandbox-albert",
            "actual sandbox source branch required")
    head = git(root, env, "rev-parse", "HEAD")
    develop = git(root, env, "rev-parse", "refs/remotes/origin/develop")
    require(SHA.fullmatch(head) and SHA.fullmatch(develop), "source ref unavailable")
    require(git(root, env, "merge-base", "--all", "HEAD", "refs/remotes/origin/develop") == base,
            "recorded base differs from unique honest merge-base")
    git(root, env, "merge-base", "--is-ancestor", "refs/remotes/origin/develop", "HEAD")
    # Config bytes are hashed only; no values are returned or logged.
    config = run([GIT, "-C", str(root), "config", "--null", "--list", "--show-origin"], root, env)
    return {"repository": repo, "root": str(root), "common": str(common), "head": head,
            "develop": develop, "base": base, "config_sha256": digest(config)}


def installed_helper(root, env):
    """Use the genuine installed helper/closure, not a source checkout or PATH shim."""
    launcher = Path("/usr/local/bin/ai-gh")
    require(launcher.is_symlink(), "installed managed GitHub helper unavailable")
    helper = launcher.resolve(strict=True)
    toolkit = helper.parent.parent
    require(helper == toolkit / "bin/ai-gh", "installed helper path invalid")
    receipt = Path("/etc/ai-devops/install-manifest.tsv")
    require(receipt.is_file() and not receipt.is_symlink(), "installed toolkit receipt unavailable")
    rows = [line.split("\t") for line in receipt.read_text().splitlines()]
    sources = [row[2] for row in rows if len(row) == 4 and row[:2] == ["meta", "source_sha"]]
    require(len(sources) == 1 and SHA.fullmatch(sources[0]), "installed source receipt invalid")
    source = sources[0]
    require(git(toolkit, env, "rev-parse", "HEAD") == source, "installed source moved")
    identity = [row for row in rows if len(row) == 4 and row[:2] == ["symlink", str(launcher)]]
    require(len(identity) == 1 and identity[0][2] == str(helper)
            and identity[0][3] == digest(helper.read_bytes()), "installed helper receipt differs")
    closure = {}
    paths = git(toolkit, env, "ls-tree", "-r", "--name-only", source, "--",
                "bin/ai-gh", "tools/github-requests").splitlines()
    require("bin/ai-gh" in paths and "tools/github-requests/telemetry.sh" in paths
            and "tools/github-requests/pr-status-context" in paths, "helper closure incomplete")
    for relative in paths:
        # These are Windows-only custody/fixture programs, unreachable from
        # the qualified Linux helper. Their checkout legitimately uses CRLF.
        # Backend Windows admission never enters this Linux proof.
        if relative.endswith(".ps1"):
            continue
        path = toolkit / relative
        require(path.is_file() and not path.is_symlink(), "helper closure file unavailable")
        raw = path.read_bytes()
        expected = run([GIT, "-C", str(toolkit), "show", f"{source}:{relative}"], root, env)
        require(raw == expected, "installed helper closure differs")
        closure[relative] = digest(raw)
    public_binary(GH)
    return helper, {"source": source, "closure": closure,
                    "gh_sha256": digest(Path(GH).read_bytes())}


def remote_ref(root, repo, helper, env):
    child = {key: value for key, value in env.items()
             if key not in {"BASH_ENV", "ENV", "SHELLOPTS", "BASHOPTS", "LD_PRELOAD",
                            "LD_LIBRARY_PATH", "LD_AUDIT", "PYTHONPATH", "PYTHONHOME"}
             and not key.startswith("BASH_FUNC_")}
    child["PATH"] = "/usr/bin:/bin"
    child["AI_GH_REAL_GH"] = GH  # only the provenance-verified native path, never caller input
    public_binary("/usr/bin/python3")
    child["PYTHON_RUNNER"] = "/usr/bin/python3"
    public_binary("/bin/bash")
    raw = run(["/bin/bash", "--noprofile", "--norc", str(helper),
               "api", "--hostname", "github.com", "--method", "GET",
               f"repos/{repo}/git/ref/heads/develop"], root, child)
    value = parse(raw)
    require(type(value) is dict and set(value) <= {"ref", "node_id", "url", "object"}
            and {"ref", "object"} <= set(value), "malformed exact-ref response")
    require("node_id" not in value or type(value["node_id"]) is str,
            "malformed ref identity")
    obj = value["object"]
    require(value["ref"] == "refs/heads/develop" and type(obj) is dict
            and set(obj) <= {"type", "sha", "url"} and {"type", "sha"} <= set(obj)
            and obj["type"] == "commit" and type(obj["sha"]) is str
            and SHA.fullmatch(obj["sha"]), "exact develop commit proof unavailable")
    if "url" in value:
        require(value["url"] == f"https://api.github.com/repos/{repo}/git/refs/heads/develop",
                "foreign ref response refused")
    if "url" in obj:
        require(obj["url"] == f"https://api.github.com/repos/{repo}/git/commits/{obj['sha']}",
                "foreign commit response refused")
    return obj["sha"]


def prove(root, repo, base, env):
    env = confined_environment(env)
    before = local_context(root, repo, base, env)
    helper, closure = installed_helper(root, env)
    require(remote_ref(root, repo, helper, env) == before["develop"],
            "local develop differs from fresh canonical remote")
    after = local_context(root, repo, base, env)
    _, closure_after = installed_helper(root, env)
    require(before == after and closure == closure_after, "source or helper moved during proof")
    return {**after, "helper": closure}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mode", choices=("preflight", "prove"))
    parser.add_argument("root")
    parser.add_argument("repository", nargs="?")
    parser.add_argument("base", nargs="?")
    args = parser.parse_args()
    try:
        if args.mode == "preflight":
            repo = discriminator(args.root)
            if repo:
                confined_environment(os.environ)
            print(repo)
        else:
            print(json.dumps(prove(args.root, args.repository, args.base, os.environ), sort_keys=True))
        return 0
    except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError):
        # Never echo remote output, environment/configuration or credentials.
        print("application source release: supplemental read-only proof refused", file=sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())
