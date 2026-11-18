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
REFRESH_REPOSITORY = "popcre/designflow-frontend"
REFRESH_BRANCHES = ("sandbox-albert", "develop")
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


def run(argv, root, env, timeout_seconds=30, max_stdout=262144):
    completed = subprocess.run(argv, cwd=root, env=env, capture_output=True, timeout=timeout_seconds,
                               check=False)
    require(completed.returncode == 0, "read-only source-release proof command failed")
    require(len(completed.stdout) <= max_stdout, "oversized proof response")
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
    def pinned_git(*args):
        # A fixed commit SHA still follows refs/replace unless explicitly
        # disabled. Read receipt-pinned objects, never substituted tree bytes.
        return run([GIT, "--no-replace-objects", "-C", str(toolkit), *args], root, env)
    require(pinned_git("rev-parse", "HEAD").decode().strip() == source, "installed source moved")
    identity = [row for row in rows if len(row) == 4 and row[:2] == ["symlink", str(launcher)]]
    require(len(identity) == 1 and identity[0][2] == str(helper)
            and identity[0][3] == digest(helper.read_bytes()), "installed helper receipt differs")
    closure = {}
    paths = pinned_git("ls-tree", "-r", "--name-only", source, "--",
                       "bin/ai-gh", "tools/github-requests").decode().splitlines()
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
        expected = pinned_git("show", f"{source}:{relative}")
        require(raw == expected, "installed helper closure differs")
        closure[relative] = digest(raw)
    public_binary(GH)
    return helper, {"source": source, "closure": closure,
                    "gh_sha256": digest(Path(GH).read_bytes())}


def remote_ref(root, repo, helper, env, branch="develop"):
    require(branch in REFRESH_BRANCHES, "unexpected exact-ref target")
    child = {key: value for key, value in env.items()
             if key not in {"BASH_ENV", "ENV", "SHELLOPTS", "BASHOPTS", "LD_PRELOAD",
                            "LD_LIBRARY_PATH", "LD_AUDIT", "PYTHONPATH", "PYTHONHOME"}
             and not key.startswith("BASH_FUNC_")}
    child["PATH"] = "/usr/bin:/bin"
    child["AI_GH_REAL_GH"] = GH  # only the provenance-verified native path, never caller input
    public_binary("/usr/bin/python3")
    child["PYTHON_RUNNER"] = "/usr/bin/python3"
    public_binary("/bin/bash")
    # Give this genuine shared-gate read a finite ten-minute queue allowance;
    # this is not a guarantee about queue duration. Local commands stay short.
    raw = run(["/bin/bash", "--noprofile", "--norc", str(helper),
               "api", "--hostname", "github.com", "--method", "GET",
               f"repos/{repo}/git/ref/heads/{branch}"], root, child, timeout_seconds=600)
    value = parse(raw)
    require(type(value) is dict and set(value) <= {"ref", "node_id", "url", "object"}
            and {"ref", "object"} <= set(value), "malformed exact-ref response")
    require("node_id" not in value or type(value["node_id"]) is str,
            "malformed ref identity")
    obj = value["object"]
    require(value["ref"] == f"refs/heads/{branch}" and type(obj) is dict
            and set(obj) <= {"type", "sha", "url"} and {"type", "sha"} <= set(obj)
            and obj["type"] == "commit" and type(obj["sha"]) is str
            and SHA.fullmatch(obj["sha"]), "exact branch commit proof unavailable")
    if "url" in value:
        require(value["url"] == f"https://api.github.com/repos/{repo}/git/refs/heads/{branch}",
                "foreign ref response refused")
    if "url" in obj:
        require(obj["url"] == f"https://api.github.com/repos/{repo}/git/commits/{obj['sha']}",
                "foreign commit response refused")
    return obj["sha"]


def refresh_context(root, repo, base, env):
    require(repo == REFRESH_REPOSITORY and SHA.fullmatch(base), "refresh target or base refused")
    root = Path(root).resolve(strict=True)
    require(Path.cwd().resolve() == root
            and Path(git(root, env, "rev-parse", "--show-toplevel")).resolve() == root,
            "refresh source root differs from selected context")
    common = Path(git(root, env, "rev-parse", "--path-format=absolute", "--git-common-dir"))
    common = common.resolve(strict=True)
    require(git(root, env, "rev-parse", "--is-shallow-repository") == "false"
            and not git(root, env, "replace", "-l"), "incomplete or replaced history refused")
    graft = common / "info/grafts"
    require(not graft.exists() or graft.stat().st_size == 0, "grafted ancestry refused")
    raw_origin = git(root, env, "config", "--get-all", "remote.origin.url")
    require(raw_origin in origin_forms(repo)
            and git(root, env, "remote", "get-url", "origin") in origin_forms(repo)
            and git(root, env, "remote", "get-url", "--push", "--all", "origin") in origin_forms(repo),
            "canonical fetch and push origin required")
    require(not git(root, env, "-c", "core.fsmonitor=false", "--no-optional-locks",
                    "status", "--porcelain=v1", "--untracked-files=all"),
            "published refresh worktree must be clean")
    flags = run([GIT, "-C", str(root), "ls-files", "-v", "-z"], root, env, max_stdout=8 * 1024 * 1024)
    require(not any(path[:1] == b"S" or path[:1].islower() for path in flags.split(b"\0")),
            "hidden working-copy differences refused")
    branch = git(root, env, "rev-parse", "--abbrev-ref", "HEAD")
    worktree = Path(git(root, env, "rev-parse", "--absolute-git-dir")).resolve(strict=True)
    require(worktree != common and branch in {"HEAD", "sandbox-albert"},
            "refresh must use an isolated sandbox-albert or detached worktree")
    sandbox = git(root, env, "rev-parse", "refs/remotes/origin/sandbox-albert")
    develop = git(root, env, "rev-parse", "refs/remotes/origin/develop")
    head = git(root, env, "rev-parse", "HEAD")
    require(sandbox == base and head != sandbox and all(map(SHA.fullmatch, (sandbox, develop, head))),
            "refresh base or source ref is unavailable, differs, or has no update")
    if head == develop:
        git(root, env, "merge-base", "--is-ancestor", sandbox, develop)
    else:
        parents = git(root, env, "show", "-s", "--format=%P", head).split()
        require(parents == [sandbox, develop], "refresh must merge only the two published heads")
    require(git(root, env, "rev-parse", f"{head}^{{tree}}") == git(root, env, "rev-parse", f"{develop}^{{tree}}"),
            "refresh tree differs from the exact published develop tree")
    git(root, env, "diff", "--quiet", sandbox, head, "--", ".", ":(exclude)shared-db")
    config = run([GIT, "-C", str(root), "config", "--null", "--list", "--show-origin"], root, env)
    return {"repository": repo, "head": head, "sandbox-albert": sandbox, "develop": develop,
            "config_sha256": digest(config)}


def frontend_cloud_proof(root, develop, env):
    import grp
    import pwd  # The maintained exact GitHub ref verifier is Linux-only.

    policy = Path(__file__).resolve().parents[1] / "config/task-gates.json"
    target = parse(policy.read_bytes())["application_source_releases"][REFRESH_REPOSITORY]["target"]
    project, region = target["project"], target["region"]
    connection, source_repo = "popcre", "pop-dflow-frontend"
    cloud_repo = f"projects/{project}/locations/{region}/connections/{connection}/repositories/{source_repo}"
    github = f"https://github.com/{REFRESH_REPOSITORY}.git"
    gcloud = public_binary("/usr/bin/gcloud")
    account = pwd.getpwuid(os.getuid())
    home = Path(account.pw_dir).resolve(strict=True)
    # Use the account's standard SDK profile and system trust. No caller
    # process environment can select a proxy, endpoint, CA or SDK executable.
    child = {"HOME": str(home), "PATH": "/usr/bin:/bin"}
    for directory in (home / ".config", home / ".config/gcloud"):
        metadata = directory.lstat()
        require(stat.S_ISDIR(metadata.st_mode) and metadata.st_uid == os.getuid() and not metadata.st_mode & 0o002,
                "standard Cloud SDK configuration path is not under account custody")
        if metadata.st_mode & 0o020:
            members = set(grp.getgrgid(metadata.st_gid).gr_mem)
            members.update(user.pw_name for user in pwd.getpwall() if user.pw_gid == metadata.st_gid)
            require(members == {account.pw_name}, "Cloud SDK configuration is writable by another account")

    def cloud(*args):
        return parse(run([gcloud, "--quiet", *args, f"--project={project}", f"--region={region}"],
                         root, child))

    settings = parse(run([gcloud, "--quiet", "config", "list",
                          "--format=json(api_endpoint_overrides,core.custom_ca_certs_file,proxy)"], root, child))
    require(not settings, "alternate Cloud Build endpoint, proxy or certificate authority refused")
    repo = cloud("builds", "repositories", "describe", source_repo, f"--connection={connection}",
                 "--format=json(name,remoteUri)")
    require(repo == {"name": cloud_repo, "remoteUri": github}, "Cloud Build source repository differs")
    triggers = cloud("builds", "triggers", "list",
                     "--format=json(id,name,disabled,filename,filter,ignoredFiles,includedFiles,repositoryEventConfig,"
                     "substitutions._SERVICE_NAME,substitutions._APP_ENV,substitutions._REGION)")

    def trigger_id(branch, service, ignored):
        matches = [entry["id"] for entry in triggers if not entry.get("disabled")
                   and entry.get("name") == service and entry.get("filename") == "cloudbuild.yaml"
                   and not entry.get("filter") and not entry.get("includedFiles")
                   and entry.get("ignoredFiles", []) == ignored
                   and entry.get("repositoryEventConfig") == {"repository": cloud_repo,
                       "repositoryType": "GITHUB", "push": {"branch": f"^{branch}$"}}
                   and all(entry.get("substitutions", {}).get(key) == value for key, value in {
                       "_SERVICE_NAME": service, "_APP_ENV": branch, "_REGION": region}.items())]
        require(len(matches) == 1 and re.fullmatch(r"[a-f0-9-]{36}", matches[0]),
                "exact enabled Cloud Build target is unavailable")
        return matches[0]

    sandbox_trigger = trigger_id(target["branch"], target["service"], [])
    develop_trigger = trigger_id("develop", "popcre-frontend-dev", ["shared-db/**"])
    docker_ignore = git(root, env, "show", f"{develop}:.dockerignore").splitlines()
    require(docker_ignore.count("shared-db") == 1 and not any(line.lstrip().startswith("!") for line in docker_ignore),
            "frontend build does not exclude the mirrored tree")
    dockerfile = git(root, env, "show", f"{develop}:Dockerfile").splitlines()
    require("RUN yarn test" in dockerfile and "RUN yarn build:${NODE_ENV}" in dockerfile,
            "frontend build lacks its pinned application checks")
    builds = cloud("builds", "list", "--limit=10", f"--filter=buildTriggerId={develop_trigger} AND status=SUCCESS",
                   "--format=json(id,status,buildTriggerId,sourceProvenance.resolvedGitSource,substitutions.COMMIT_SHA)")
    for entry in builds:
        source = entry.get("sourceProvenance", {}).get("resolvedGitSource", {})
        revision = source.get("revision", "")
        build_id = entry.get("id", "")
        if not (entry.get("status") == "SUCCESS" and entry.get("buildTriggerId") == develop_trigger
                and source.get("url") == github and SHA.fullmatch(revision)
                and entry.get("substitutions", {}).get("COMMIT_SHA") == revision
                and re.fullmatch(r"[a-f0-9-]{36}", build_id)):
            continue
        try:
            git(root, env, "merge-base", "--is-ancestor", revision, develop)
            git(root, env, "diff", "--quiet", revision, develop, "--", ".", ":(exclude)shared-db")
        except ValueError:
            continue
        build = cloud("builds", "describe", build_id, "--format=json(id,status,buildTriggerId,steps)")
        require(build.get("id") == build_id and build.get("status") == "SUCCESS"
                and build.get("buildTriggerId") == develop_trigger
                and any(step.get("id") == "Build" and step.get("status") == "SUCCESS"
                        and step.get("name") == "gcr.io/cloud-builders/docker"
                        and {"build", "."} <= set(step.get("args", [])) for step in build.get("steps", [])),
                "successful frontend test-and-build step unavailable")
        return {"sandbox_trigger": sandbox_trigger, "tested_develop_build": build_id,
                "tested_develop_source": revision}
    raise ValueError("no successful Cloud Build with the exact frontend application tree")


def prove_refresh(root, repo, base, env):
    env = confined_environment(env)
    before = refresh_context(root, repo, base, env)
    helper, closure = installed_helper(root, env)
    for branch in REFRESH_BRANCHES:
        require(remote_ref(root, repo, helper, env, branch) == before[branch],
                "local refresh parent differs from fresh canonical remote")
    cloud = frontend_cloud_proof(root, before["develop"], env)
    after = refresh_context(root, repo, base, env)
    _, closure_after = installed_helper(root, env)
    require(before == after and closure == closure_after, "refresh source or helper moved during proof")
    for branch in reversed(REFRESH_BRANCHES):
        require(remote_ref(root, repo, helper, env, branch) == after[branch],
                "canonical remote refresh parent moved during proof")
    return {**before, **cloud}


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
    parser.add_argument("mode", choices=("preflight", "prove", "refresh-preflight", "prove-refresh"))
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
        elif args.mode == "refresh-preflight":
            confined_environment(os.environ)
        elif args.mode == "prove-refresh":
            print(json.dumps(prove_refresh(args.root, args.repository, args.base, os.environ), sort_keys=True))
        else:
            print(json.dumps(prove(args.root, args.repository, args.base, os.environ), sort_keys=True))
        return 0
    except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError):
        # Never echo remote output, environment/configuration or credentials.
        print("application source release: supplemental read-only proof refused", file=sys.stderr)
        return 3


if __name__ == "__main__":
    sys.exit(main())
