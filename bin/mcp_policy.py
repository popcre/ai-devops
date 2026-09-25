#!/usr/bin/env python3
"""Linux reader of the MCP membership declared in bin/setup-machine.ps1.

setup-machine.ps1 holds the only copy of the lists (as check-mcp-drift.ps1
also relies on); this parses the same literals so Linux cannot drift from them.

  mcp_policy.py policy                      JSON: desktop, code, retired, scope
  mcp_policy.py deliver --catalog C --claude-json J [--dry-run]
      Write each scoped server into the owning repositories on this machine:
      a Claude Code project entry in J (projects[<root>].mcpServers) and a
      marked, untracked <root>/.codex/config.toml. Stale managed names are
      pruned; anything we do not manage is left alone.
"""
import argparse, glob, json, os, re, subprocess, sys, time

BIN = os.path.dirname(os.path.realpath(__file__))
SETUP = os.environ.get("AI_DEVOPS_SETUP_SCRIPT", os.path.join(BIN, "setup-machine.ps1"))
CODEX_MARKER = "# Managed by ai-devops bin/mcp_policy.py. Rewritten by install.sh."


def _names(text, var):
    m = re.search(r"(?m)^\$" + var + r"\s*=\s*@\(([^)]*)\)", text)
    if not m:
        raise SystemExit("mcp_policy: $%s not found in %s" % (var, SETUP))
    return re.findall(r'"([^"]+)"', m.group(1))


def policy():
    text = open(SETUP).read()
    m = re.search(r"(?ms)^\$McpProjectScope\s*=\s*\[ordered\]@\{(.*?)^\}", text)
    if not m:
        raise SystemExit("mcp_policy: $McpProjectScope not found in %s" % SETUP)
    scope = {}
    for key, body in re.findall(r'(?m)^\s*"([A-Za-z0-9][A-Za-z0-9_-]*)"\s*=\s*@\(([^)]*)\)', m.group(1)):
        scope[key] = re.findall(r'"([^"]+)"', body)
    return {
        "desktop": _names(text, "ClaudeDesktopMcpNames"),
        "code": _names(text, "ClaudeCodeMcpNames"),
        "retired": _names(text, "RetiredMcpServerNames"),
        "scope": scope,
        "scoped": sorted({n for v in scope.values() for n in v}),
    }


def _git(root, *args):
    r = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def clone_roots(key):
    env = os.environ.get("AI_REPO_CLONE_ROOTS")
    bases = env.split(os.pathsep) if env else ["/worksp", os.path.expanduser("~/repos")]
    found = []
    for base in filter(os.path.isdir, bases):
        for clone in sorted({os.path.join(base, key), *glob.glob(os.path.join(base, "*", key))}):
            if not os.path.exists(os.path.join(clone, ".git")):
                continue
            url = (_git(clone, "remote", "get-url", "origin") or "").strip()
            ok = url and subprocess.run([os.path.join(BIN, "ai-repo-identity"), "accepts", key, url],
                                        capture_output=True).returncode == 0
            if not ok:
                continue
            for line in (_git(clone, "worktree", "list", "--porcelain") or "worktree %s\n" % clone).splitlines():
                wt = line[len("worktree "):].strip() if line.startswith("worktree ") else ""
                if wt and os.path.isdir(wt) and wt not in found:
                    found.append(wt)
    return found


def _toml_block(name, srv):
    s = lambda v: json.dumps(str(v))
    out = ["[mcp_servers.%s]" % s(name)]
    for k in ("command", "url", "cwd"):
        if k in srv: out.append("%s = %s" % (k, s(srv[k])))
    if "args" in srv: out.append("args = [%s]" % ", ".join(s(a) for a in srv["args"]))
    if srv.get("env"): out.append("env = { %s }" % ", ".join("%s = %s" % (k, s(v)) for k, v in srv["env"].items()))
    for k in ("startup_timeout_sec", "tool_timeout_sec"):
        if k in srv: out.append("%s = %d" % (k, int(srv[k])))
    return out + [""]


def _write(path, text, dry):
    if dry:
        print("  [dry-run] would write " + path); return
    if os.path.exists(path):
        with open(path) as src, open("%s.aidevops-%s.bak" % (path, time.strftime("%Y%m%d%H%M%S")), "w") as dst:
            dst.write(src.read())
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path + ".tmp", "w") as fh: fh.write(text)
    os.replace(path + ".tmp", path)


def deliver(catalog_path, claude_json, dry):
    pol = policy()
    catalog = json.load(open(catalog_path))
    managed = set(catalog) | set(pol["retired"]) | set(pol["scoped"])
    cfg = json.load(open(claude_json)) if os.path.exists(claude_json) else {}
    projects = cfg.setdefault("projects", {})
    dirty = False
    for key, names in pol["scope"].items():
        wanted = {n: catalog[n] for n in names if n in catalog}
        roots = clone_roots(key)
        if not roots:
            print("  skip %s not cloned here; loads nowhere: %s" % (key, ", ".join(names)))
        for root in roots:
            entry = projects.setdefault(root, {})
            servers = entry.setdefault("mcpServers", {})
            before = dict(servers)
            for n in [n for n in servers if n in managed and n not in wanted]:
                del servers[n]
            servers.update(wanted)
            if servers != before:
                dirty = True
            print("  ok %s: %s" % (root, ", ".join(sorted(wanted)) or "(none)"))
            codex = os.path.join(root, ".codex", "config.toml")
            if _git(root, "ls-files", "--error-unmatch", ".codex/config.toml") is not None:
                print("  skip %s is tracked; left untouched" % codex); continue
            if os.path.exists(codex) and CODEX_MARKER not in open(codex).read():
                print("  skip %s is hand-written; left untouched" % codex); continue
            text = "\n".join([CODEX_MARKER, ""] + [l for n in sorted(wanted) for l in _toml_block(n, wanted[n])]).rstrip() + "\n"
            if not os.path.exists(codex) or open(codex).read() != text:
                _write(codex, text, dry)
            exclude = (_git(root, "rev-parse", "--git-path", "info/exclude") or "").strip()
            if exclude and not dry:
                exclude = os.path.join(root, exclude)
                lines = open(exclude).read().splitlines() if os.path.exists(exclude) else []
                if "/.codex/config.toml" not in lines:
                    os.makedirs(os.path.dirname(exclude), exist_ok=True)
                    with open(exclude, "a") as fh: fh.write("/.codex/config.toml\n")
    if dirty:
        _write(claude_json, json.dumps(cfg, indent=2) + "\n", dry)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("policy")
    d = sub.add_parser("deliver")
    d.add_argument("--catalog", required=True)
    d.add_argument("--claude-json", required=True)
    d.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    if a.cmd == "policy":
        print(json.dumps(policy()))
    else:
        deliver(a.catalog, a.claude_json, a.dry_run)


if __name__ == "__main__":
    main()
