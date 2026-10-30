#!/usr/bin/env python3
"""Cheap GitHub lifecycle checks for review-fixer; never invokes a model.

Commands: plan [ISSUE], prepare ISSUE FILE, check FILE [WORKTREE],
retire TARGET_BRANCH, metadata FILE, invalid FILE REPORT.
Workflow jobs serialize all commands for one repository/target branch.
"""
from __future__ import annotations

import json
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from urllib.parse import quote

MARKER = "review-fixer:v1"
INVALID = "review-fixer-invalid:v1"
DEFERRED = "fixer-deferred"


def adapter_env():
    # Caller code gets runtime essentials only, never job tokens or provider keys.
    return {key: os.environ[key] for key in
            ("PATH", "SystemRoot", "SYSTEMROOT", "TMP", "TEMP", "TMPDIR", "GITHUB_REPOSITORY")
            if key in os.environ}


def gh(*args):
    wrapper = Path(__file__).resolve().parents[2] / "bin/ai-gh"
    result = subprocess.run(["bash", str(wrapper), *map(str, args)], text=True, capture_output=True)
    if result.returncode:
        raise subprocess.CalledProcessError(result.returncode, result.args, result.stdout, result.stderr)
    return result.stdout.strip()


def api(endpoint):
    return json.loads(gh("api", endpoint))


def paged(endpoint):
    pages = json.loads(gh("api", "--paginate", "--slurp", endpoint))
    return [item for page in pages for item in page]


def repository():
    repo = os.environ["GITHUB_REPOSITORY"]
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repo):
        raise ValueError("invalid repository")
    return repo


def labels(issue):
    return {x["name"] for x in issue.get("labels", [])}


def marker(body, kind=MARKER):
    match = re.search(r"<!-- " + re.escape(kind) + r" (.*?) -->", body or "")
    return json.loads(match[1]) if match else None


def encoded_marker(data, kind=MARKER):
    # Keep arbitrary report text from terminating the HTML comment.
    return "<!-- " + kind + " " + json.dumps(data, ensure_ascii=True).replace("<", "\\u003c").replace(">", "\\u003e") + " -->"


def validate(data, repo, pr=None):
    if not isinstance(data, dict) or data.get("repository") != repo:
        raise ValueError("receipt repository mismatch")
    if any(type(data.get(key)) is not int or data[key] < 1 for key in ("issue", "source_pr")):
        raise ValueError("receipt issue/source PR is invalid")
    if any(not re.fullmatch(r"[0-9a-f]{40}", data.get(key, "")) for key in ("reviewed_head", "target_head")):
        raise ValueError("receipt commit is invalid")
    if not isinstance(data.get("target_branch"), str) or not re.fullmatch(r"[A-Za-z0-9-]+", data.get("owner", "")):
        raise ValueError("receipt target/owner is invalid")
    branch = data["target_branch"]
    if (not branch or branch.startswith("-") or branch == "@"
            or re.search(r"[\x00-\x20\x7f~^:?*\[\\]", branch)
            or ".." in branch or "@{" in branch or branch.endswith(".")
            or any(not part or part.startswith(".") or part.endswith(".lock") for part in branch.split("/"))):
        raise ValueError("receipt target branch is invalid")
    if pr and (data["target_branch"] != pr["base"]["ref"] or pr["head"]["ref"] != f"review-fix/{data['issue']}"):
        raise ValueError("receipt does not belong to this fix PR")


class State:
    def __init__(self):
        self.repo = repository()
        self.prefix = "repos/" + self.repo
        self.sig = os.environ.get("AI_GH_SIGNATURE", "Posted by review-fixer")

    def source(self, issue):
        body = issue.get("body") or ""
        pr = re.search(r"^PR:\s*https://github\.com/" + re.escape(self.repo) + r"/pull/(\d+)\s*$", body, re.M)
        head = re.search(r"^Head SHA:\s*`?([0-9a-f]{40})`?\s*$", body, re.M)
        if not pr or not head:
            raise ValueError("finding lacks a same-repository source PR and reviewed Head SHA")
        current = api(f"{self.prefix}/pulls/{pr[1]}")
        target = current["head"]["ref"]
        return {"issue": issue["number"], "source_pr": int(pr[1]),
                "repository": self.repo,
                "reviewed_head": head[1], "target_branch": target,
                "target_head": current["head"]["sha"],
                "owner": current["user"]["login"]}, current

    def issue(self, number):
        return api(f"{self.prefix}/issues/{number}")

    def pulls(self):
        return paged(f"{self.prefix}/pulls?state=open&per_page=100")

    def assign(self, data):
        try:
            gh("issue", "edit", data["issue"], "--repo", self.repo, "--add-assignee", data["owner"])
        except subprocess.CalledProcessError:
            print("WARNING: could not assign deferred finding", file=sys.stderr)

    def defer(self, data, reason):
        self.assign(data)
        gh("label", "create", DEFERRED, "--repo", self.repo, "--color", "FBCA04", "--force")
        gh("issue", "comment", data["issue"], "--repo", self.repo, "--body",
           f"Automatic fix deferred to @{data['owner']}: {reason}. Finding remains unresolved; the owner's normal checks must verify it.\n\n{self.sig}")
        gh("issue", "edit", data["issue"], "--repo", self.repo, "--add-label", DEFERRED)
        print("DEFERRED: " + reason)

    def current(self, data):
        validate(data, self.repo)
        pr = api(f"{self.prefix}/pulls/{data['source_pr']}")
        head = pr.get("head") or {}
        if pr["state"] != "open":
            return "source PR is closed"
        if (head.get("repo") or {}).get("full_name") != self.repo:
            return "source branch is not in this repository"
        if pr["user"]["login"] != data["owner"]:
            raise ValueError("receipt owner does not match source PR")
        if head.get("ref") != data["target_branch"] or head.get("sha") != data["reviewed_head"]:
            return "source moved to " + head.get("sha", "unknown")
        try:
            ref = api(f"{self.prefix}/git/ref/heads/{quote(data['target_branch'], safe='/')}")
        except subprocess.CalledProcessError as error:
            if "HTTP 404" in (error.stderr or ""):
                return "target branch is deleted"
            raise
        if ref["object"]["sha"] != data["target_head"]:
            return "target moved to " + ref["object"]["sha"]
        return None

    def check(self, data, work=None):
        issue = self.issue(data["issue"])
        if issue["state"] != "open" or "review-finding" not in labels(issue) or labels(issue) & {DEFERRED, "fixer-done", "fixer-failed"}:
            print("SKIPPED: finding already handled")
            return False
        reason = self.current(data)
        if reason:
            self.defer(data, reason)
            return False
        pulls = self.pulls()
        for pr in pulls:
            if pr["base"]["ref"] == data["target_branch"] and pr["head"]["ref"].startswith("review-fix/"):
                if pr["head"]["ref"] == f"review-fix/{data['issue']}":
                    print("SKIPPED: fix PR already exists")
                else:
                    self.defer(data, f"existing automatic fix PR #{pr['number']} owns this target")
                return False
        if work:
            changed = set(filter(None, subprocess.check_output(
                ["git", "-C", work, "diff", "--name-only", "-z", data["target_head"], "--"], text=True).split("\0")))
            trusted = os.environ.get("REVIEW_FIXER_TRUSTED_ROOT")
            adapter = Path(trusted) / "scripts/review-fixer-lifecycle.mjs" if trusted else None
            if adapter and adapter.is_file():
                with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as paths:
                    json.dump(sorted(changed), paths)
                try:
                    result = subprocess.run(["node", str(adapter), "check", "--source-pr", str(data["source_pr"]),
                                             "--issue", str(data["issue"]), "--paths-file", paths.name,
                                             "--worktree", work], capture_output=True, text=True, cwd=trusted,
                                            env=adapter_env())
                finally:
                    Path(paths.name).unlink()
                if result.returncode == 3:
                    self.defer(data, result.stdout.strip() or result.stderr.strip() or "object ownership collision")
                    return False
                if result.returncode:
                    raise ValueError("trusted object check failed: " + result.stdout + result.stderr)
            source_base = api(f"{self.prefix}/pulls/{data['source_pr']}")["base"]["ref"]
            for pr in pulls:
                if pr["number"] == data["source_pr"] or pr["head"]["ref"].startswith("review-fix/"):
                    continue
                if pr["base"]["ref"] not in {data["target_branch"], source_base}:
                    continue
                files = {x["filename"] for x in paged(f"{self.prefix}/pulls/{pr['number']}/files?per_page=100")}
                if changed & files:
                    self.defer(data, f"overlapping owner work in PR #{pr['number']}")
                    return False
        return True

    def retire(self, target):
        for pr in self.pulls():
            if pr["base"]["ref"] != target or not pr["head"]["ref"].startswith("review-fix/"):
                continue
            data = marker(pr.get("body"))
            if not data:
                body = pr.get("body") or ""
                number = re.fullmatch(r"review-fix/([1-9][0-9]*)", pr["head"]["ref"])
                generated = re.search(r"^Posted by review-fixer workflow run [0-9]+\s*$", body, re.M)
                if not number or not generated or not re.search(r"^Closes #" + number[1] + r"\s*$", body, re.M):
                    print(f"LEGACY: PR #{pr['number']} has no trusted retirement receipt")
                    continue
                data, source = self.source(self.issue(int(number[1])))
                if data["target_branch"] != target or (source["head"].get("repo") or {}).get("full_name") != self.repo:
                    print(f"LEGACY: PR #{pr['number']} source/target association is unproven")
                    continue
                data["target_head"] = data["reviewed_head"]
            validate(data, self.repo, pr)
            reason = self.current(data)
            if not reason:
                continue
            self.defer(data, reason)
            trusted = os.environ.get("REVIEW_FIXER_TRUSTED_ROOT")
            adapter = Path(trusted) / "scripts/review-fixer-lifecycle.mjs" if trusted else None
            if adapter and adapter.is_file():
                subprocess.run(["node", str(adapter), "retire", "--fix-pr", str(pr["number"]),
                                "--issue", str(data["issue"])], check=True, cwd=trusted, env=adapter_env())
            gh("pr", "close", pr["number"], "--repo", self.repo, "--comment",
               f"Stale automatic fix: {reason}. Finding https://github.com/{self.repo}/issues/{data['issue']} remains with @{data['owner']}.\n\n{self.sig}")
            print(f"RETIRED: PR #{pr['number']}")

    def plan(self, number=None):
        groups = {}
        cleanup = os.environ.get("GITHUB_EVENT_NAME") in {"push", "pull_request", "pull_request_target", "delete"}
        for pr in self.pulls():
            if pr["head"]["ref"].startswith("review-fix/"):
                groups.setdefault(pr["base"]["ref"], [])
        issues = [self.issue(number)] if number else ([] if cleanup else paged(f"{self.prefix}/issues?state=open&labels=review-finding&per_page=100"))
        for issue in issues:
            if issue["state"] != "open" or "review-finding" not in labels(issue) or labels(issue) & {DEFERRED, "fixer-done", "fixer-failed"}:
                continue
            try:
                data, _ = self.source(issue)
            except ValueError:
                continue
            groups.setdefault(data["target_branch"], []).append(issue["number"])
        return {"include": [{"target": target, "key": hashlib.sha256(target.encode()).hexdigest(), "issues": nums}
                            for target, nums in sorted(groups.items())]}


def main():
    state = State()
    command, *args = sys.argv[1:]
    if command == "plan":
        print(json.dumps(state.plan(int(args[0]) if args and args[0] else None)))
    elif command == "prepare":
        issue = state.issue(int(args[0]))
        data, _ = state.source(issue)
        Path(args[1]).write_text(json.dumps(data), encoding="utf-8")
        if not state.check(data):
            return 3
        if "fixer-invalid" in labels(issue):
            gh("issue", "edit", data["issue"], "--repo", state.repo, "--remove-label", "fixer-invalid")
    elif command == "check":
        if not state.check(json.loads(Path(args[0]).read_text()), args[1] if len(args) > 1 else None):
            return 3
    elif command == "retire":
        state.retire(args[0])
    elif command == "metadata":
        print(encoded_marker(json.loads(Path(args[0]).read_text())))
    elif command == "invalid":
        data = json.loads(Path(args[0]).read_text())
        report = Path(args[1]).read_text().strip()
        if not report:
            raise ValueError("invalid disposition needs evidence")
        if not state.check(data):
            return 3
        data["evidence"] = report
        data["run_id"] = os.environ.get("GITHUB_RUN_ID", "")
        data["run_url"] = f"https://github.com/{state.repo}/actions/runs/{data['run_id']}"
        data["run_attempt"] = os.environ.get("GITHUB_RUN_ATTEMPT", "")
        data["job_name"] = "review-fixer-" + hashlib.sha256(data["target_branch"].encode()).hexdigest()
        gh("issue", "comment", data["issue"], "--repo", state.repo, "--body", report + "\n\n" + encoded_marker(data, INVALID) + "\n\n" + state.sig)
        gh("label", "create", "fixer-invalid", "--repo", state.repo, "--color", "0E8A16", "--force")
        gh("issue", "edit", data["issue"], "--repo", state.repo, "--add-label", "fixer-invalid")
    else:
        raise ValueError("unknown lifecycle command")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, KeyError, subprocess.CalledProcessError) as error:
        print("review-fixer lifecycle refused: " + str(error), file=sys.stderr)
        sys.exit(1)
