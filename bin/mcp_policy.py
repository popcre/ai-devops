#!/usr/bin/env python3
"""Linux reader of the MCP membership declared in bin/setup-machine.ps1.

setup-machine.ps1 holds the only copy of the lists (as check-mcp-drift.ps1
also relies on); this parses the same literals so Linux cannot drift from them.

  mcp_policy.py policy                      JSON: desktop, code, retired, scope
  mcp_policy.py deliver --catalog C --claude-json J [--dry-run]
      Write each scoped server into the owning repositories (and multi-repo
      non-git parent folders such as dflow_plm) on this machine across all
      coding harnesses:
        - Claude Code: projects[<root>].mcpServers in J (+ untracked .mcp.json
          in non-git parent folders)
        - Codex: <root>/.codex/config.toml
        - Antigravity: <root>/.agents/plugins/ai-devops-project-mcp/
        - ZCode: <root>/.zcode/config.json
        - MiMoCode: <root>/.mimocode/mimocode.json
      Stale managed names are pruned; tracked or hand-written files are left
      alone.
"""
import argparse, glob, json, os, re, shutil, subprocess, sys, time

BIN = os.path.dirname(os.path.realpath(__file__))
SETUP = os.environ.get("AI_DEVOPS_SETUP_SCRIPT", os.path.join(BIN, "setup-machine.ps1"))
CODEX_MARKER = "# Managed by ai-devops bin/mcp_policy.py. Rewritten by install.sh."
MANAGED_MARKER = "Managed by ai-devops bin/mcp_policy.py (#2916). Rewritten by install.sh.\n"


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


def _is_git(root):
    return os.path.exists(os.path.join(root, ".git"))


def _is_tracked(root, relpath):
    return _is_git(root) and (_git(root, "ls-files", "--error-unmatch", relpath) is not None)


_ACCEPTS = {}


def _accepts(key, url):
    if (key, url) not in _ACCEPTS:
        # Resolve Bash from PATH before launching the shebang script.
        # Native Windows process lookup otherwise checks System32 first.
        path = os.pathsep.join(entry for entry in os.get_exec_path() if os.path.isabs(entry))
        bash = shutil.which("bash", path=path)
        if not bash or not os.path.isabs(bash):
            raise SystemExit("mcp_policy: Bash is required to check repository identity")
        _ACCEPTS[(key, url)] = subprocess.run(
            [bash, os.path.join(BIN, "ai-repo-identity"), "accepts", key, url],
            capture_output=True).returncode == 0
    return _ACCEPTS[(key, url)]


def _scan_bases():
    env = os.environ.get("AI_REPO_CLONE_ROOTS")
    bases = env.split(os.pathsep) if env else ["/worksp", os.path.expanduser("~/repos")]
    return [os.path.abspath(b) for b in bases if b and os.path.isdir(b)]


def clone_roots(key):
    found = []
    for base in _scan_bases():
        # Match clones by origin identity, not folder name (#2778): the
        # popdam3 clone on hetz lives at /worksp/popdam.
        marks = glob.glob(os.path.join(base, "*", ".git")) + glob.glob(os.path.join(base, "*", "*", ".git"))
        for clone in sorted({os.path.dirname(m) for m in marks}):
            url = (_git(clone, "remote", "get-url", "origin") or "").strip()
            if not url or not _accepts(key, url):
                continue
            for line in (_git(clone, "worktree", "list", "--porcelain") or "worktree %s\n" % clone).splitlines():
                wt = line[len("worktree "):].strip() if line.startswith("worktree ") else ""
                if wt and os.path.isdir(wt) and wt not in found:
                    found.append(wt)
    return found


def delivery_roots(key):
    clones = clone_roots(key)
    if not clones:
        return []
    bases = {os.path.normcase(os.path.normpath(b)) for b in _scan_bases()}
    seen = set()
    result = []
    for root in clones:
        norm = os.path.normcase(os.path.normpath(root))
        if norm not in seen:
            seen.add(norm)
            result.append(root)
        # Only primary clones (.git directory) propagate to a multi-repo non-git
        # parent folder (e.g. ~/repos/dflow_plm).
        if not os.path.isdir(os.path.join(root, ".git")):
            continue
        parent = os.path.dirname(os.path.abspath(root))
        parent_norm = os.path.normcase(os.path.normpath(parent))
        if not parent or parent_norm in bases:
            continue
        if os.path.exists(os.path.join(parent, ".git")):
            continue
        if re.search(r"(^|[.-])worktrees$", os.path.basename(parent)):
            continue
        if parent_norm not in seen:
            seen.add(parent_norm)
            result.append(parent)
    return result


def _toml_block(name, srv):
    s = lambda v: json.dumps(str(v))
    out = ["[mcp_servers.%s]" % s(name)]
    for k in ("command", "url", "cwd"):
        if k in srv: out.append("%s = %s" % (k, s(srv[k])))
    if "args" in srv: out.append("args = [%s]" % ", ".join(s(a) for a in srv["args"]))
    if srv.get("env"): out.append("env = { %s }" % ", ".join("%s = %s" % (k, s(v)) for k, v in srv["env"].items()))
    for k in ("startup_timeout_sec", "tool_timeout_sec"):
        if k in srv: out.append("%s = %d" % (k, int(srv[k])))
    if "enabled" in srv: out.append("enabled = %s" % ("true" if srv["enabled"] else "false"))
    return out + [""]


def _write(path, text, dry, backup=True):
    if dry:
        print("  [dry-run] would write " + path); return
    if backup and os.path.exists(path):
        with open(path) as src, open("%s.aidevops-%s.bak" % (path, time.strftime("%Y%m%d%H%M%S")), "w") as dst:
            dst.write(src.read())
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path + ".tmp", "w") as fh: fh.write(text)
    os.replace(path + ".tmp", path)


def _write_if_changed(path, text, dry, backup=True):
    if os.path.exists(path) and open(path).read() == text:
        return False
    _write(path, text, dry, backup=backup)
    return True


def _exclude(root, patterns, dry):
    if dry or not _is_git(root):
        return
    exclude = (_git(root, "rev-parse", "--git-path", "info/exclude") or "").strip()
    if not exclude:
        return
    if not os.path.isabs(exclude):
        exclude = os.path.join(root, exclude)
    lines = open(exclude).read().splitlines() if os.path.exists(exclude) else []
    missing = [p for p in patterns if p not in lines]
    if missing:
        os.makedirs(os.path.dirname(exclude), exist_ok=True)
        with open(exclude, "a") as fh:
            for p in missing:
                fh.write(p + "\n")


def _project_key(projects, root):
    """Reuse an existing project key that denotes the same directory: temp
    roots arrive long, short, slashed or backslashed depending on which tool
    produced the spelling, and a second spelling would fork the project."""
    for k in projects:
        try:
            if os.path.samefile(k, root):
                return k
        except OSError:
            pass
        if os.path.normcase(os.path.normpath(k)) == os.path.normcase(os.path.normpath(root)):
            return k
    return root


def _deliver_antigravity(root, wanted, dry):
    pdir = os.path.join(root, ".agents", "plugins", "ai-devops-project-mcp")
    pjson = os.path.join(pdir, "plugin.json")
    mjson = os.path.join(pdir, "mcp_config.json")
    marker = os.path.join(pdir, ".ai-devops-managed")
    if _is_tracked(root, ".agents/plugins/ai-devops-project-mcp/plugin.json") or \
       _is_tracked(root, ".agents/plugins/ai-devops-project-mcp/mcp_config.json"):
        print("  skip %s is tracked; left untouched" % pdir); return
    if os.path.exists(pdir) and not os.path.exists(marker):
        print("  skip %s is hand-written; left untouched" % pdir); return
    servers = {}
    for n in sorted(wanted):
        src = wanted[n]
        if "url" in src:
            e = {"url": str(src["url"])}
            if src.get("headers"):
                e["headers"] = {str(k): str(v) for k, v in sorted(src["headers"].items())}
            servers[n] = e
        elif "command" in src:
            e = {"command": str(src["command"])}
            if src.get("args"):
                e["args"] = [str(a) for a in src["args"]]
            if src.get("env"):
                e["env"] = {str(k): str(v) for k, v in sorted(src["env"].items())}
            servers[n] = e
    if not servers:
        return
    _write_if_changed(pjson, json.dumps({"name": "ai-devops-project-mcp", "version": "1.0.0"}, indent=2) + "\n", dry, backup=False)
    _write_if_changed(mjson, json.dumps({"mcpServers": servers}, indent=2) + "\n", dry)
    _write_if_changed(marker, MANAGED_MARKER, dry, backup=False)
    _exclude(root, ["/.agents/plugins/ai-devops-project-mcp/"], dry)


def _deliver_zcode(root, wanted, dry):
    zdir = os.path.join(root, ".zcode")
    zcfg = os.path.join(zdir, "config.json")
    marker = os.path.join(zdir, ".ai-devops-mcp-managed")
    if _is_tracked(root, ".zcode/config.json"):
        print("  skip %s is tracked; left untouched" % zcfg); return
    if os.path.exists(zcfg) and not os.path.exists(marker):
        print("  skip %s is hand-written; left untouched" % zcfg); return
    servers = {}
    for n in sorted(wanted):
        src = wanted[n]
        if "command" not in src:
            continue
        e = {"command": str(src["command"])}
        if src.get("args"):
            e["args"] = [str(a) for a in src["args"]]
        if src.get("cwd"):
            e["cwd"] = str(src["cwd"])
        if src.get("env"):
            e["env"] = {str(k): str(v) for k, v in sorted(src["env"].items())}
        e["timeoutMs"] = 120000
        servers[n] = e
    if not servers:
        return
    _write_if_changed(zcfg, json.dumps({"mcp": {"servers": servers}}, indent=2) + "\n", dry)
    _write_if_changed(marker, MANAGED_MARKER, dry, backup=False)
    _exclude(root, ["/.zcode/config.json", "/.zcode/.ai-devops-mcp-managed"], dry)


def _deliver_mimo(root, wanted, dry):
    mdir = os.path.join(root, ".mimocode")
    mcfg = os.path.join(mdir, "mimocode.json")
    marker = os.path.join(mdir, ".ai-devops-mcp-managed")
    if _is_tracked(root, ".mimocode/mimocode.json"):
        print("  skip %s is tracked; left untouched" % mcfg); return
    if os.path.exists(mcfg) and not os.path.exists(marker):
        print("  skip %s is hand-written; left untouched" % mcfg); return
    servers = {}
    for n in sorted(wanted):
        src = wanted[n]
        if "command" not in src:
            continue
        argv = [str(src["command"])] + [str(a) for a in (src.get("args") or [])]
        e = {"type": "local", "command": argv}
        if src.get("env"):
            e["env"] = {str(k): str(v) for k, v in sorted(src["env"].items())}
        e["enabled"] = True
        e["timeout"] = 120000
        servers[n] = e
    if not servers:
        return
    payload = {"$schema": "https://mimo.xiaomi.com/mimocode/config.json", "mcp": servers}
    _write_if_changed(mcfg, json.dumps(payload, indent=2) + "\n", dry)
    _write_if_changed(marker, MANAGED_MARKER, dry, backup=False)
    _exclude(root, ["/.mimocode/mimocode.json", "/.mimocode/.ai-devops-mcp-managed"], dry)


def deliver(catalog_path, claude_json, dry):
    pol = policy()
    catalog = json.load(open(catalog_path))
    managed = set(catalog) | set(pol["retired"]) | set(pol["scoped"])
    cfg = json.load(open(claude_json)) if os.path.exists(claude_json) else {}
    projects = cfg.setdefault("projects", {})
    dirty = False
    for key, names in pol["scope"].items():
        wanted = {n: catalog[n] for n in names if n in catalog}
        roots = delivery_roots(key)
        if not roots:
            print("  skip %s not cloned here; loads nowhere: %s" % (key, ", ".join(names)))
        for root in roots:
            is_git = _is_git(root)
            if not is_git:
                # Non-git parent folder (e.g. ~/repos/dflow_plm): write untracked .mcp.json
                # directly so Claude Code sessions opened at the parent load it too.
                mcp_path = os.path.join(root, ".mcp.json")
                existing = json.load(open(mcp_path)) if os.path.exists(mcp_path) else {}
                new_servers = {k: v for k, v in (existing.get("mcpServers") or {}).items() if k not in managed}
                new_servers.update(wanted)
                _write_if_changed(mcp_path, json.dumps({"mcpServers": new_servers}, indent=2) + "\n", dry)
            entry = projects.setdefault(_project_key(projects, root), {})
            servers = entry.setdefault("mcpServers", {})
            before = dict(servers)
            for n in [n for n in servers if n in managed and n not in wanted]:
                del servers[n]
            servers.update(wanted)
            if servers != before:
                dirty = True
            print("  ok %s: %s" % (root, ", ".join(sorted(wanted)) or "(none)"))
            codex = os.path.join(root, ".codex", "config.toml")
            if _is_tracked(root, ".codex/config.toml"):
                print("  skip %s is tracked; left untouched" % codex)
            elif os.path.exists(codex) and CODEX_MARKER not in open(codex).read():
                print("  skip %s is hand-written; left untouched" % codex)
            else:
                text = "\n".join([CODEX_MARKER, ""] + [l for n in sorted(wanted) for l in _toml_block(n, wanted[n])]).rstrip() + "\n"
                _write_if_changed(codex, text, dry)
                _exclude(root, ["/.codex/config.toml"], dry)
            _deliver_antigravity(root, wanted, dry)
            _deliver_zcode(root, wanted, dry)
            _deliver_mimo(root, wanted, dry)
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
