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


def gh(*args):
    wrapper = Path(__file__).resolve().parents[2] / "bin/ai-gh"
    environment = os.environ.copy()
    environment["AI_GH_CALLER"] = "review-fixer"
    result = subprocess.run(["bash", str(wrapper), *map(str, args)], text=True,
                            capture_output=True, env=environment)
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


def inventory_path(path):
    if (not isinstance(path, str) or not path or "\0" in path or path.startswith("/")
            or any(part in {"", ".", ".."} for part in path.split("/"))):
        raise ValueError("collision inventory path is invalid")
    return path


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
    if pr and data["target_head"] != data["reviewed_head"]:
        raise ValueError("receipt target commit differs from reviewed commit")
    if not isinstance(data.get("target_branch"), str) or not re.fullmatch(r"[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\[bot\])?", data.get("owner", "")):
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

    def pulls(self, base=None):
        # Cleanup already knows its target branch. Ask GitHub for that branch
        # rather than paging through every unrelated open PR on each event.
        endpoint = f"{self.prefix}/pulls?state=open&per_page=100"
        if base is not None:
            endpoint += "&base=" + quote(base, safe="")
        return paged(endpoint)

    def candidate_files(self, candidates):
        """Read the same collision candidates in bounded GraphQL batches.

        Complete small connections need one request per <=50 candidates. Only
        a genuinely paginated connection uses its existing complete REST path.
        Unknown/partial responses never count as an empty collision inventory.
        """
        numbers = [pr.get("number") for pr in candidates]
        if any(type(number) is not int or not 0 < number <= 2147483647 for number in numbers) or len(set(numbers)) != len(numbers):
            raise ValueError("collision candidate PR numbers are invalid")
        owner, name = self.repo.split("/", 1)
        result = {}
        for offset in range(0, len(numbers), 50):
            chunk = numbers[offset:offset + 50]
            fields = " ".join(
                f"p_{number}: pullRequest(number: {number}) {{ number files(first: 100) {{ totalCount nodes {{ path }} pageInfo {{ hasNextPage }} }} }}"
                for number in chunk)
            query = "query($owner:String!,$name:String!){repository(owner:$owner,name:$name){nameWithOwner " + fields + "}}"
            with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", suffix=".json", delete=False) as request:
                json.dump({"query": query, "variables": {"owner": owner, "name": name}}, request)
            try:
                response = json.loads(gh("api", "graphql", "--input", request.name))
            finally:
                Path(request.name).unlink()
            if not isinstance(response, dict) or ("errors" in response and response["errors"] != []):
                raise ValueError("collision file query returned errors or invalid data")
            data = response.get("data")
            repo = data.get("repository") if isinstance(data, dict) else None
            if not isinstance(repo, dict) or repo.get("nameWithOwner") != self.repo:
                raise ValueError("collision file query repository is missing or mismatched")
            for number in chunk:
                pr = repo.get(f"p_{number}")
                if not isinstance(pr, dict) or type(pr.get("number")) is not int or pr["number"] != number:
                    raise ValueError("collision file query PR is missing or mismatched")
                files = pr.get("files")
                if not isinstance(files, dict) or type(files.get("totalCount")) is not int or files["totalCount"] < 0:
                    raise ValueError("collision file query count is invalid")
                nodes, page = files.get("nodes"), files.get("pageInfo")
                if not isinstance(nodes, list) or not isinstance(page, dict) or type(page.get("hasNextPage")) is not bool:
                    raise ValueError("collision file query nodes/page metadata are invalid")
                paths = []
                for node in nodes:
                    path = node.get("path") if isinstance(node, dict) else None
                    paths.append(inventory_path(path))
                count, more = files["totalCount"], page["hasNextPage"]
                if len(paths) != min(count, 100) or len(set(paths)) != len(paths) or more != (count > len(paths)):
                    raise ValueError("collision file query is incomplete or inconsistent")
                if more:
                    rows = paged(f"{self.prefix}/pulls/{number}/files?per_page=100")
                    if not isinstance(rows, list):
                        raise ValueError("collision fallback inventory is invalid")
                    paths = []
                    for row in rows:
                        path = row.get("filename") if isinstance(row, dict) else None
                        paths.append(inventory_path(path))
                    if len(paths) != count or len(set(paths)) != len(paths):
                        raise ValueError("collision fallback inventory is incomplete or changed")
                result[number] = set(paths)
        return result

    def assign(self, data):
        try:
            gh("issue", "edit", data["issue"], "--repo", self.repo, "--add-assignee", data["owner"])
        except subprocess.CalledProcessError:
            # Bot/source authors need not be assignable. The durable comment
            # still names the owner; an assignment failure must not strand a PR.
            print(f"WARNING: could not assign deferred finding to @{data['owner']}; owner remains named in its comment", file=sys.stderr)

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
            ref = api(f"{self.prefix}/git/ref/heads/{quote(data['target_branch'], safe='')}")
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
                # This is same-repository DEFAULT-branch code, never PR-head
                # code. Preserve GitHub auth/HOME: its existing ownership
                # checks require authenticated reads, not a tokenless sandbox.
                with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as paths:
                    json.dump(sorted(changed), paths)
                try:
                    result = subprocess.run(["node", str(adapter), "check", "--source-pr", str(data["source_pr"]),
                                             "--issue", str(data["issue"]), "--paths-file", paths.name,
                                             "--worktree", work], capture_output=True, text=True, cwd=trusted)
                finally:
                    Path(paths.name).unlink()
                if result.returncode == 3:
                    self.defer(data, result.stdout.strip() or result.stderr.strip() or "object ownership collision")
                    return False
                if result.returncode:
                    raise ValueError("trusted object check failed: " + result.stdout + result.stderr)
            source_base = api(f"{self.prefix}/pulls/{data['source_pr']}")["base"]["ref"]
            candidates = [pr for pr in pulls if pr["number"] != data["source_pr"]
                          and not pr["head"]["ref"].startswith("review-fix/")
                          and pr["base"]["ref"] in {data["target_branch"], source_base}]
            inventories = self.candidate_files(candidates)
            for pr in candidates:
                if changed & inventories[pr["number"]]:
                    self.defer(data, f"overlapping owner work in PR #{pr['number']}")
                    return False
        return True

    def retire(self, target):
        for pr in self.pulls(base=target):
            if pr["base"]["ref"] != target or not pr["head"]["ref"].startswith("review-fix/"):
                continue
            if (pr["head"].get("repo") or {}).get("full_name") != self.repo:
                print(f"WARNING: PR #{pr['number']} is not a same-repository fixer; skipped", file=sys.stderr)
                continue
            try:
                data = marker(pr.get("body"))
                if not data:
                    body = pr.get("body") or ""
                    number = re.fullmatch(r"review-fix/([1-9][0-9]*)", pr["head"]["ref"])
                    generated = re.search(r"^Posted by review-fixer workflow run [0-9]+\s*$", body, re.M)
                    if not number or not generated or not re.search(r"^Closes #" + number[1] + r"\s*$", body, re.M):
                        raise ValueError("no trusted retirement receipt")
                    finding = self.issue(int(number[1]))
                    data, _ = self.source(finding)
                    data["target_head"] = data["reviewed_head"]
                else:
                    validate(data, self.repo, pr)
                    finding = self.issue(data["issue"])
                if "review-finding" not in labels(finding):
                    raise ValueError("associated issue is not a review finding")
                actual, source = self.source(finding)
                if (source["head"].get("repo") or {}).get("full_name") != self.repo:
                    raise ValueError("finding source is not in the same repository")
                bound = ("issue", "source_pr", "reviewed_head", "target_branch", "owner")
                if any(data.get(key) != actual.get(key) for key in bound):
                    raise ValueError("receipt does not match the actual finding source")
                validate(data, self.repo, pr)
            except (ValueError, TypeError) as error:
                print(f"WARNING: PR #{pr['number']} retirement skipped: {error}", file=sys.stderr)
                continue
            reason = self.current(data)
            if not reason:
                continue
            self.defer(data, reason)
            trusted = os.environ.get("REVIEW_FIXER_TRUSTED_ROOT")
            adapter = Path(trusted) / "scripts/review-fixer-lifecycle.mjs" if trusted else None
            if adapter and adapter.is_file():
                # Same trusted default-branch adapter; preserve its GitHub auth.
                subprocess.run(["node", str(adapter), "retire", "--fix-pr", str(pr["number"]),
                                "--issue", str(data["issue"])], check=True, cwd=trusted)
            gh("pr", "close", pr["number"], "--repo", self.repo, "--comment",
               f"Stale automatic fix: {reason}. Finding https://github.com/{self.repo}/issues/{data['issue']} remains with @{data['owner']}.\n\n{self.sig}")
            print(f"RETIRED: PR #{pr['number']}")

    def plan(self, number=None):
        groups = {}
        event = os.environ.get("GITHUB_EVENT_NAME", "workflow_dispatch")
        cleanup = event in {"push", "pull_request", "pull_request_target", "delete"}
        target = None
        if cleanup:
            event_path = os.environ.get("GITHUB_EVENT_PATH")
            if not event_path:
                raise ValueError("cleanup event has no GITHUB_EVENT_PATH")
            payload = json.loads(Path(event_path).read_text(encoding="utf-8"))
            if not isinstance(payload, dict):
                raise ValueError("cleanup event payload is not an object")
            if event == "push":
                ref = payload.get("ref")
                if not isinstance(ref, str):
                    raise ValueError("push event has no ref")
                if ref.startswith("refs/tags/"):
                    if not ref[len("refs/tags/"):]:
                        raise ValueError("push tag event has no tag name")
                    return {"include": []}
                if not ref.startswith("refs/heads/"):
                    raise ValueError("push event ref is not a branch or tag")
                target = ref[len("refs/heads/"):]
            elif event == "delete":
                if not isinstance(payload.get("ref"), str) or not payload["ref"]:
                    raise ValueError("delete event has no ref")
                if payload.get("ref_type") == "tag":
                    return {"include": []}
                if payload.get("ref_type") != "branch":
                    raise ValueError("delete event has no branch/tag ref_type")
                target = payload.get("ref")
            else:
                pr = payload.get("pull_request")
                if not isinstance(pr, dict) or not isinstance(pr.get("head"), dict):
                    raise ValueError("pull request event has no head")
                head = pr["head"]
                if "repo" not in head:
                    raise ValueError("pull request event has no head repository")
                head_repo = head.get("repo")
                if head_repo is None:  # Deleted fork repository; no same-repo target.
                    return {"include": []}
                if not isinstance(head_repo, dict) or not isinstance(head_repo.get("full_name"), str):
                    raise ValueError("pull request event has no head repository identity")
                if head_repo["full_name"] != self.repo:
                    return {"include": []}
                target = head.get("ref")
            if not isinstance(target, str) or not target or target.startswith("refs/"):
                raise ValueError("cleanup event has no valid branch name")
            if target.startswith("review-fix/"):
                return {"include": []}
        elif event not in {"schedule", "workflow_dispatch", "issues"}:
            raise ValueError("unsupported fixer event: " + event)
        elif event == "issues" and not number:
            raise ValueError("issue event has no issue number")

        issues = []
        if not cleanup and number:
            issue = self.issue(number)
            data, _ = self.source(issue)
            target = data["target_branch"]
            issues = [issue]
        for pr in self.pulls(base=target):
            if pr["head"]["ref"].startswith("review-fix/") and (target is None or pr["base"]["ref"] == target):
                groups.setdefault(pr["base"]["ref"], [])
        if not cleanup and not number:
            issues = paged(f"{self.prefix}/issues?state=open&labels=review-finding&per_page=100")
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
