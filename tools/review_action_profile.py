#!/usr/bin/env python3
"""Native, data-only admission for the single reviewed #770 rehearsal profile.

No repository-supplied executable is loaded. Private manifest values never
become provider attachments, arguments, environment variables or diagnostics.
"""
import argparse
import hashlib
try:
    import fcntl
except ImportError:
    fcntl = None
import tempfile
import datetime
import importlib.util
import json
import os
from pathlib import Path
import stat
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
_spec = importlib.util.spec_from_file_location("native_code_only", ROOT / "bin/ai-review-code-only.py")
_native = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_native)
PROFILE = "shared-db-770-isolated-timing-rehearsal-v1"
BINDINGS = {"review_report", "review_report_sha256", "review_identity", "review_identity_sha256", "review_provider_meta", "review_provider_meta_sha256", "review_provider_response_sha256", "verdict"}
LIMIT = 16 * 1024 * 1024


def require(value, reason):
    if not value:
        raise ValueError(reason)


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True).encode()


def sha(value):
    return hashlib.sha256(value).hexdigest()


def unique(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate action descriptor key")
        result[key] = value
    return result


def decode(raw):
    require(len(raw) <= LIMIT, "action descriptor exceeds native bound")
    return json.loads(raw, object_pairs_hook=unique)


def profiles():
    path = ROOT / "config/review-action-profiles.json"
    if os.environ.get("AI_REVIEW_ACTION_PROFILES_FILE"):
        require(os.environ.get("AI_DEVOPS_TEST_MODE") == "1", "profile substitution is a hostile-test hook only")
        path = Path(os.environ["AI_REVIEW_ACTION_PROFILES_FILE"])
    raw = path.read_bytes()
    config = decode(raw)
    require(config.get("schema_version") == 1, "unsupported installed profile schema")
    profile = config["profiles"][PROFILE]
    require(profile["action"] == "database" and set(profile["review_binding_slots"]) == BINDINGS, "installed action semantics differ")
    require(sha(canonical(profile["paths"])) == profile["path_set_sha256"] and len(profile["paths"]) == 52, "installed implementation closure differs")
    return profile, sha(raw)


def mount_private(path):
    require(sys.platform == "linux", "isolated action profile requires supported Linux custody")
    if os.environ.get("AI_DEVOPS_TEST_MODE") == "1" and os.environ.get("AI_REVIEW_ACTION_TEST_CUSTODY") == "1":
        return
    candidate = str(Path(path).absolute())
    mounted = False
    for line in Path("/proc/self/mountinfo").read_text().splitlines():
        left, right = line.split(" - ", 1)
        mount = left.split()[4].replace("\\040", " ").replace("\\134", "\\")
        if right.split()[0] == "fuse.gocryptfs" and (candidate == mount or candidate.startswith(mount.rstrip("/") + "/")):
            mounted = True
    require(mounted, "protected action input lacks encrypted mounted custody")


def file_hash(path, private=False):
    """Hash a bounded stable regular descriptor without following ancestors."""
    path = Path(path).absolute()
    require(".." not in path.parts and hasattr(os, "O_NOFOLLOW"), "unsafe immutable input path")
    if private:
        mount_private(path)
    directory = os.open(path.anchor, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        for part in path.parts[1:-1]:
            next_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=directory)
            os.close(directory)
            directory = next_fd
        fd = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
        with os.fdopen(fd, "rb") as stream:
            before = os.fstat(stream.fileno())
            require(stat.S_ISREG(before.st_mode) and before.st_uid in (0, os.getuid()) and not before.st_mode & (0o077 if private else 0o022) and before.st_size <= 2 * 1024**3, "immutable input custody or bound differs")
            result = hashlib.file_digest(stream, "sha256").hexdigest()
            after = os.fstat(stream.fileno())
            require((before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns) == (after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns), "immutable input changed while hashing")
            return result, before
    finally:
        os.close(directory)


def git(repo, *args):
    return _native.git(repo, *args)


def task_identity(repo):
    out = subprocess.run([str(ROOT / "bin/ai-task-gates"), "explain", "--json"], cwd=repo, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=_native.git_env())
    require(out.returncode == 0, "truthful native task classification unavailable")
    explanation = decode(out.stdout)
    identity = explanation["repository"]
    require(identity == "popcre/designflow-backend" and explanation["declared_class"] and explanation["base"], "declared original task identity missing")
    key = sha((identity + "\0" + str(repo)).encode())
    state_dir = Path(os.environ.get("AI_TASK_GATES_DIR", str(Path.home() / ".local/state/ai-devops/task-gates")))
    state = decode(_native.private_read(state_dir / (key + ".json")))
    require(state["worktree"] == str(repo) and state["identity"] == identity and state["base"] == explanation["base"], "native task state and classification differ")
    base = git(repo, "rev-parse", "--verify", state["base"] + "^{commit}").decode().strip()
    start = state["start_head"]
    git(repo, "merge-base", "--is-ancestor", start, "HEAD")
    changed = set()
    for args in (("diff", "--no-renames", "--name-only", "-z", base, "HEAD"), ("diff", "--no-renames", "--name-only", "-z"), ("diff", "--cached", "--no-renames", "--name-only", "-z"), ("ls-files", "--others", "--exclude-standard", "-z")):
        changed.update(x.decode("utf-8") for x in git(repo, *args).split(b"\0") if x)
    return {"state_sha256": sha(canonical({key: value for key, value in state.items() if key != "overrides"})), "base": base, "start_head": start, "classification_sha256": sha(canonical(explanation)), "changed_paths": sorted(changed), "effective_class": explanation["effective_class"]}


def tree_inventory(root, expected=None):
    """Same canonical runtime inventory used by the reviewed rehearsal code."""
    root = Path(root)
    require(root.is_dir() and not root.is_symlink(), "runtime tree root differs")
    rows = []
    total = 0
    for directory, dirs, files in os.walk(root, followlinks=False):
        for name in sorted(dirs + files):
            path = Path(directory) / name
            info = path.lstat()
            rel = str(path.relative_to(root))
            require(info.st_uid == os.getuid() and (stat.S_ISLNK(info.st_mode) or not info.st_mode & 0o022), "runtime tree custody differs")
            if stat.S_ISLNK(info.st_mode):
                require(expected is None, "linked parser runtime refused")
                row = {"path": rel, "type": "link", "target": os.readlink(path)}
            elif stat.S_ISDIR(info.st_mode):
                row = {"path": rel, "type": "dir", "mode": stat.S_IMODE(info.st_mode)}
            else:
                digest, held = file_hash(path)
                total += held.st_size
                row = {"path": rel, "type": "file", "mode": stat.S_IMODE(held.st_mode), "sha256": digest, "bytes": held.st_size}
            rows.append(row)
            require(len(rows) <= 100000 and total <= 2 * 1024**3, "runtime complete closure exceeds bounds")
    rows.sort(key=lambda row: row["path"])
    if expected is not None:
        require(rows == expected, "parser complete runtime closure differs")
    return sha(canonical(rows)), rows


def action_binding(state, manifest, phase, stage="initial-forward"):
    profile, profile_digest = profiles()
    require(state["normalized_upstream"] == profile["repository"], "foreign original repository cannot use this profile")
    require(state["review_mode"] in ("final-check", "security-review"), "bounded action requires final or security review")
    record = _native.validate_snapshot(Path(state["code_only_export"]), state["head"])
    require(record == state["code_only"] and record["paths"] == profile["paths"], "selected paths do not cover the complete action implementation")
    require(isinstance(manifest, dict) and set(manifest) == set(profile["manifest_keys"]), "operational action manifest schema differs")
    for field in ("target_ref", "schema", "preparation_scope", "issue_isolated_credentials"):
        require(manifest[field] == profile[field] and type(manifest[field]) is type(profile[field]), "bounded target or flags differ")
    require(manifest["verdict"] in ("PENDING", "APPROVE"), "invalid action review binding status")
    require(manifest["authorization_attested"] is False and manifest["action_authority"]["root_action_authorized"] is False, "eligibility cannot invent root action authority")
    require("acceptance_runner" not in manifest and "acceptance_command" not in manifest, "application callback is outside timing profile")
    repo = Path(state["repository_root"])
    require(manifest["source_head"] == state["head"], "manifest source head is stale or foreign")
    inputs = manifest["input_sha256"]
    require(isinstance(inputs, dict) and len(inputs) == profile["immutable_input_count"], "complete immutable action input set missing")
    code = {str(repo / path): path for path in profile["paths"]}
    require(set(code).issubset(inputs), "runtime code closure is partial")
    interpreter = manifest["python_interpreter"]
    require(interpreter == manifest["pglast_dependency"]["interpreter"] and interpreter in inputs, "actual interpreter input missing")
    require(manifest["loader_sha256"] == inputs[str(repo / "scripts/cutover-rehearsal/loader.py")], "loader claim differs from actual selected code")
    actual = {}
    for path, expected in inputs.items():
        require(isinstance(expected, str) and len(expected) == 64, "immutable input hash is malformed")
        current, _ = file_hash(path, private=path not in code and path != interpreter)
        require(current == expected, "actual immutable action input changed")
        actual[path] = current
    contract_path = repo / "scripts/cutover-rehearsal/contracts/timing_action_contract.json"
    require(manifest["reviewed_action_contract_sha256"] == inputs[str(contract_path)], "typed action contract claim differs")
    contract = decode(_native.private_read(contract_path, private=False))
    typed_code = {row["logical_label"][5:]: row["sha256"] for row in contract["immutable_inputs"] if row["logical_label"].startswith("code/")}
    expected_code = {path: inputs[str(repo / path)] for path in profile["paths"] if path != str(contract_path.relative_to(repo))}
    require(typed_code == expected_code and len(typed_code) == 51, "typed action contract omits or changes runtime code edges")
    tools = {"auth_dependency_bootstrap": "scripts/cutover-recovery/schema/auth_dependency_bootstrap.sql", "tuple_constraint_contract": "scripts/cutover-rehearsal/contracts/tuple_constraint_contract.json", "tuple_preflight_tool": "scripts/cutover-rehearsal/tuple_preflight.py", "recovery_tool": "scripts/cutover-recovery/designflow-recovery.py", "postwrite_runner": "scripts/cutover-recovery/postwrite_bwrap.py", "postwrite_runtime_helper": "scripts/cutover-recovery/bwrap_restore.py", "networked_client_tool": "scripts/cutover-recovery/networked_client.py", "credential_tool": "scripts/cutover/issue_designflow_credentials.py", "custody_tool": "scripts/cutover/service_credential_custody.py"}
    require(all(manifest[key] == str(repo / path) for key, path in tools.items()), "executed implementation descriptor is outside the installed closure")
    required = ("source_config", "destination_config", "before_manifest", "recovery_proof", "encrypted_backup", "schema_snapshot", "metadata", "grants_snapshot", "seed_rows", "archive_dependency_proof", "auth_dependency_bootstrap", "tuple_constraint_contract", "tuple_preflight_tool", "recovery_tool", "postwrite_runner", "postwrite_runtime_helper", "networked_client_tool", "credential_tool", "custody_tool")
    require(all(manifest[field] in inputs for field in required), "operational input descriptor is not immutable")
    def protected_json(path):
        raw = _native.private_read(path)
        require(sha(raw) == inputs[path], "protected descriptor changed between verification and decoding")
        return decode(raw)
    source = protected_json(manifest["source_config"])
    target = protected_json(manifest["destination_config"])
    connection_keys = {"user", "host", "dbname", "password", "port", "sslmode", "sslrootcert", "connect_timeout"}
    require(set(source) == connection_keys and set(target) == connection_keys | {"runtime_port"}, "connection descriptor contains unreviewed options")
    require(all(type(config["connect_timeout"]) is int and 1 <= config["connect_timeout"] <= 30 and isinstance(config["password"], str) and config["password"] for config in (source, target)), "bounded connection credentials descriptor differs")
    require(sha(str(source.get("host", "")).encode()) == profile["source_host_sha256"] and source.get("user") == "albert_read_only" and source.get("dbname") == "postgres" and source.get("port") == 5432 and source.get("sslmode") == "verify-ca", "source read-only identity differs")
    require(target.get("user") == "postgres." + profile["target_ref"] and target.get("dbname") == "postgres" and target.get("host") == "aws-0-us-east-1.pooler.supabase.com" and target.get("port") == 5432 and target.get("runtime_port") == 6543 and target.get("sslmode") == "verify-full", "isolated destination identity differs")
    require(source["sslrootcert"] in inputs and target["sslrootcert"] in inputs, "TLS root input is not immutable")
    dep = manifest["pglast_dependency"]
    require(set(dep) == {"interpreter", "interpreter_sha256", "abi", "version", "root", "files", "closure_sha256"} and dep["version"] == "8.5" and dep["interpreter_sha256"] == inputs[interpreter], "parser runtime descriptor differs")
    parser_rows = []
    for package in ("pglast", "pglast-8.5.dist-info"):
        _, rows = tree_inventory(Path(dep["root"]) / package, expected=None)
        top = Path(dep["root"]) / package
        require(not any(row["type"] == "link" for row in rows), "linked parser closure refused")
        parser_rows.append({"path": package, "type": "dir", "mode": stat.S_IMODE(top.stat().st_mode)})
        parser_rows.extend(dict(row, path=package + "/" + row["path"]) for row in rows)
    parser_rows.sort(key=lambda row: row["path"])
    require(parser_rows == dep["files"] and sha(canonical(parser_rows)) == dep["closure_sha256"], "actual parser complete closure differs")
    runtime_paths = [path for path in inputs if Path(path).name == "bwrap-runtime.json"]
    require(len(runtime_paths) == 1, "runtime descriptor missing")
    runtime = protected_json(runtime_paths[0])
    closure, _ = tree_inventory(runtime["runtime_root"])
    require(closure == runtime["runtime_closure_sha256"] == manifest["postwrite_runtime_closure_sha256"] == profile["postwrite_runtime_closure_sha256"], "actual isolated runtime closure changed")
    require(manifest["original_restoration_result"] and manifest["proposed_result"] and len(manifest["future_outputs_nonexistence"]) == 5, "mandatory original restoration or future outputs missing")
    if phase == "capture" or (phase == "preaction" and stage == "initial-forward"):
        require(all(value is True and not Path(path).exists() and not Path(path).is_symlink() for path, value in manifest["future_outputs_nonexistence"].items()), "future action outputs already exist")
    if phase == "preaction" and stage == "original-restoration":
        for path in manifest["future_outputs_nonexistence"]:
            item = Path(path)
            if item.exists() or item.is_symlink():
                mount_private(item)
                file_hash(item, private=True)
    descriptor = {key: value for key, value in manifest.items() if key not in BINDINGS}
    return {"profile": PROFILE, "profile_sha256": profile_digest, "action": "database", "manifest_descriptor_sha256": sha(canonical(descriptor)), "immutable_input_sha256": sha(canonical(actual)), "task": task_identity(repo), "path_set_sha256": profile["path_set_sha256"], "entrypoint": profile["entrypoint"], "target_ref": profile["target_ref"], "schema": profile["schema"], "root_action_authority": False, "future_output_leaves": sorted(manifest["future_outputs_nonexistence"])}


def receipt_binding(state, binding):
    return {"schema_version": 1, "stage": "initial-forward", "source_head": state["head"], "source_digest": state["source_digest"], "native_completion": state["code_only_completion"], "action_profile_binding": binding}


def admit(state_path, state, binding, stage, publish):
    require(state.get("verdict") == "APPROVE" and state.get("stale") is False and state.get("failure_class") is None, "native completed action is non-authorizing")
    proof = subprocess.run([sys.executable, str(ROOT / "bin/ai-review-code-only.py"), "lifecycle-proof", str(state_path), state["session_id"], state["report_path"], "--completed"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    require(proof.returncode == 0 and decode(proof.stdout) == state["code_only_completion"], "genuine native completed action evidence changed")
    expected = receipt_binding(state, binding)
    receipt = state.get("action_initial_admission")
    if receipt is not None:
        require(receipt.get("binding") == expected and receipt.get("binding_sha256") == sha(canonical(expected)), "initial native admission receipt is foreign or changed")
    if stage == "original-restoration":
        require(receipt is not None, "original restoration lacks a native initial database gate receipt")
        return
    if not publish:
        return
    require(state["report_sha256"] == state["code_only_completion"]["transcript_report_sha256"], "native lifecycle report hash differs")
    repo = Path(state["repository_root"])
    key = sha(("popcre/designflow-backend" + "\0" + str(repo)).encode())
    task_dir = Path(os.environ.get("AI_TASK_GATES_DIR", str(Path.home() / ".local/state/ai-devops/task-gates")))
    task = decode(_native.private_read(task_dir / (key + ".json")))
    summary = "APPROVE by " + state["provider"] + " (implementer " + state["implementer_engine"] + ", run " + state["run_id"] + ", " + state["review_mode"] + ") for database at " + state["head"] + " report sha256:" + state["report_sha256"]
    require(any(row.get("kind") == "reviewer-approval" and row.get("action") == "database" and row.get("reason") == summary and row.get("observed_class") == binding["task"]["effective_class"] for row in task.get("overrides", []) if isinstance(row, dict)), "native successful database reviewer receipt missing")
    state_path = Path(state_path)
    lock = os.open(str(state_path) + ".admission.lock", os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    try:
        info = os.fstat(lock)
        require(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid() and not info.st_mode & 0o077, "native receipt lock is unsafe")
        fcntl.flock(lock, fcntl.LOCK_EX)
        current = decode(_native.private_read(state_path))
        require({k: v for k, v in current.items() if k != "action_initial_admission"} == {k: v for k, v in state.items() if k != "action_initial_admission"}, "lifecycle changed during receipt publication")
        existing = current.get("action_initial_admission")
        if existing is not None:
            require(existing.get("binding") == expected and existing.get("binding_sha256") == sha(canonical(expected)), "concurrent initial receipt collision")
            return
        current["action_initial_admission"] = {"binding": expected, "binding_sha256": sha(canonical(expected)), "issued_at": datetime.datetime.now(datetime.timezone.utc).isoformat()}
        descriptor, temporary = tempfile.mkstemp(prefix=".action-admission-", dir=state_path.parent)
        try:
            with os.fdopen(descriptor, "wb") as out:
                out.write(canonical(current) + b"\n")
                out.flush()
                os.fsync(out.fileno())
            os.replace(temporary, state_path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
    finally:
        os.close(lock)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("phase", choices=("capture", "finish", "preaction"))
    parser.add_argument("state")
    parser.add_argument("--manifest")
    parser.add_argument("--profile", default=PROFILE)
    parser.add_argument("--stage", choices=("initial-forward", "original-restoration"), default="initial-forward")
    parser.add_argument("--admit", action="store_true")
    args = parser.parse_args()
    try:
        require(sys.platform == "linux" and fcntl is not None, "isolated action profile requires supported Linux custody")
        require(args.profile == PROFILE, "unknown installed action profile")
        state = decode(_native.private_read(args.state))
        require(state["status"] == ({"capture": "preflight", "finish": "running", "preaction": "completed"}[args.phase]), "wrong prospective lifecycle phase")
        if args.manifest:
            mount_private(args.manifest)
            manifest = decode(_native.private_read(args.manifest))
        else:
            raw = sys.stdin.buffer.read(LIMIT + 1)
            manifest = decode(raw)
        binding = action_binding(state, manifest, args.phase, args.stage)
        if args.phase != "capture":
            require(binding == state["action_profile_binding"], "current action, installed profile or original task changed")
        if args.phase == "preaction":
            admit(args.state, state, binding, args.stage, args.admit)
        else:
            require(args.stage == "initial-forward" and not args.admit, "restoration is not a capture or finish bypass")
        print(json.dumps(binding, sort_keys=True))
    except (OSError, ValueError, KeyError, TypeError, json.JSONDecodeError, RecursionError):
        print("ai-review-action-profile: native bounded action validation refused", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
