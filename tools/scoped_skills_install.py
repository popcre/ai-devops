#!/usr/bin/env python3
"""Read-only source validation, private snapshot and separate scoped-skill receipt.

Owned by ai-install-skills. This is not a release authority: the Bash installer
always invokes the candidate task gate and its lifecycle approval validator.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


def fail(message):
    raise ValueError(message)


def git(root, *args):
    return subprocess.check_output(['git', '-C', str(root), *args], stderr=subprocess.DEVNULL)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def safe(path):
    path = Path(path)
    if not path.is_absolute() or path.resolve() != path or '\n' in str(path) or '\t' in str(path):
        fail('noncanonical or symbolic path')
    for parent in [path, *path.parents]:
        if parent.is_symlink():
            fail('symbolic path refused')
    return path


def tree(path):
    result = {}
    if path.exists():
        for entry in sorted(path.rglob('*')):
            if entry.is_symlink() or not (entry.is_dir() or entry.is_file()):
                fail('special file or symbolic link refused')
            if entry.is_file():
                result[str(entry.relative_to(path))] = sha(entry.read_bytes())
    return result


def origin(root):
    url = git(root, 'remote', 'get-url', 'origin').decode().strip()
    if not re.fullmatch(r'(?:https://github.com/|git@github.com:|ssh://git@github.com/)(?:popcre|u2giants)/ai-devops(?:\.git)?', url):
        fail('unsupported source origin')
    head = git(root, 'rev-parse', 'HEAD').decode().strip()
    subprocess.run(['git', '-C', str(root), 'merge-base', '--is-ancestor', head, 'refs/remotes/origin/main'], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if git(root, 'status', '--porcelain=v1', '--untracked-files=all').strip():
        fail('candidate must be clean')
    # Require critical entrypoints and policy to be committed regular files,
    # never a symlink or an ignored/untracked substitute.
    critical = ['bin/ai-install-skills', 'bin/ai-task-gates', 'tools/scoped_skills_install.py', 'tools/lib/task-gates.sh', 'config/task-gates.json']
    hashes = {}
    for rel in critical:
        path = safe(root / rel)
        row = git(root, 'ls-tree', head, '--', rel).decode()
        if not row.startswith('100') or not path.is_file():
            fail('missing committed entrypoint')
        expected = git(root, 'show', f'{head}:{rel}')
        if path.read_bytes() != expected:
            fail('entrypoint differs from committed source')
        hashes[rel] = sha(expected)
    return head, hashes


def homes(claude, codex):
    base = Path(os.environ.get('USERPROFILE') or os.environ['HOME'])
    # Git Bash exposes Windows profiles as drive paths; use cygpath when needed.
    if os.environ.get('USERPROFILE') and ':' in str(base):
        base = Path(subprocess.check_output(['cygpath', '-u', str(base)], text=True).strip())
    base = safe(base)
    expected = [base / '.claude', base / '.codex']
    got = [safe(Path(claude)), safe(Path(codex))]
    if got != expected:
        fail('scoped installation uses canonical client homes only')
    return dict(zip(['claude', 'codex'], map(str, got)))


def entries(root, names, client_homes):
    if not names or names != sorted(set(names)):
        fail('selection must be nonempty, normalized exact names')
    scope = json.loads((root / 'config/skill-scope.json').read_text()).get('skills', {})
    result = []
    for name in names:
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_-]*', name) or name in scope:
            fail('invalid or repository-scoped selection')
        found = False
        for client in ['claude', 'codex']:
            specific = root / 'skills' / client / name
            shared = root / 'skills/shared' / name
            if (specific / 'SKILL.md').exists() and (shared / 'SKILL.md').exists():
                fail('selected shared/client collision')
            for source in [specific, shared]:
                if not (source / 'SKILL.md').is_file():
                    continue
                found = True
                safe(source)
                files = tree(source)
                for rel in files:
                    if rel.startswith('-') or any(c.isspace() for c in rel):
                        fail('unsupported source filename')
                if client == 'codex' and not Path(client_homes[client]).is_dir():
                    continue
                dest = safe(Path(client_homes[client]) / 'skills' / name)
                tree(dest)  # Reject preexisting links before any reconciliation.
                marker = dest / '.ai-devops-managed'
                if marker.exists():
                    for line in marker.read_text().splitlines():
                        if not line.strip() or line.startswith('#'):
                            continue
                        parts = line.split()
                        if len(parts) != 2 or not re.fullmatch('[0-9a-f]{64}', parts[0]):
                            fail('unsafe installed marker')
                        rel = Path(parts[1])
                        if rel.is_absolute() or '..' in rel.parts or str(rel).startswith('-'):
                            fail('unsafe installed marker path')
                safe(Path(client_homes[client]) / 'skills-backup')
                result.append(dict(client=client, name=name, source=str(source.relative_to(root)), destination=str(dest), files=files))
        if not found:
            fail('unknown selected name')
    if not result:
        fail('selection has no installed client destination')
    return result


def prepare(root, report, claude, codex, names, scratch=None):
    if sys.platform != "linux":
        fail("scoped host route is qualified on Linux; use the existing full installation route elsewhere")
    root = safe(Path(root))
    report = safe(Path(report))
    head, critical = origin(root)
    client_homes = homes(claude, codex)
    names = sorted(set(names))
    selected = entries(root, names, client_homes)
    for home in client_homes.values():
        if root == Path(home) or root.is_relative_to(Path(home) / 'skills'):
            fail('source overlaps destination')
    scratch = safe(Path(scratch)) if scratch else Path(tempfile.mkdtemp(prefix='ai-scoped-skills-', dir=os.environ.get('TMPDIR')))
    if not scratch.is_dir() or any(scratch.iterdir()) or scratch.stat().st_uid != os.getuid() or scratch.stat().st_mode & 0o077:
        fail('snapshot scratch must be an empty private owned directory')
    try:
        snapshot = scratch / 'source'
        for entry in selected:
            target = snapshot / entry['source']
            if not target.exists():
                target.mkdir(parents=True)
                for rel in entry['files']:
                    dst = target / rel
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    dst.write_bytes(git(root, 'show', f"{head}:{entry['source']}/{rel}"))
                    os.chmod(dst, (root / entry['source'] / rel).stat().st_mode & 0o777)
        # Freeze scope metadata used by the existing Bash reconciler.
        (snapshot / 'config').mkdir(exist_ok=True)
        for name in ['skill-scope.json', 'skill-trigger-policy.json', 'repo-identities.tsv']:
            src = root / 'config' / name
            if src.is_file():
                (snapshot / 'config' / name).write_bytes(git(root, 'show', f'{head}:config/{name}'))
        plan = dict(schema_version=1, source_root=str(root), head=head, critical=critical,
                    names=names, homes=client_homes, entries=selected,
                    report=str(report), report_sha256=sha(report.read_bytes()),
                    snapshot=str(snapshot), run_id=scratch.name)
        path = scratch / 'plan.json'
        path.write_text(json.dumps(plan, sort_keys=True))
        validate(path, root, report)
        print(path)
    except BaseException:
        shutil.rmtree(scratch)
        raise


def validate(path, root, report):
    path = safe(Path(path))
    plan = json.loads(path.read_text())
    if plan.get('schema_version') != 1:
        fail('unsupported snapshot plan')
    root, report = safe(Path(root)), safe(Path(report))
    head, critical = origin(root)
    if plan['source_root'] != str(root) or plan['head'] != head or plan['critical'] != critical:
        fail('source changed')
    if plan['report'] != str(report) or plan['report_sha256'] != sha(report.read_bytes()):
        fail('review report changed')
    client_homes = homes(plan['homes']['claude'], plan['homes']['codex'])
    if plan['entries'] != entries(root, plan['names'], client_homes):
        fail('selection or destination changed')
    snapshot = safe(Path(plan['snapshot']))
    if snapshot != path.parent / 'source' or plan['run_id'] != path.parent.name:
        fail('invalid private snapshot')
    expected = {}
    for entry in plan['entries']:
        if tree(snapshot / entry['source']) != entry['files']:
            fail('snapshot differs from reviewed source')
        for rel, digest in entry['files'].items():
            expected[entry['source'] + '/' + rel] = digest
    for name in ['skill-scope.json', 'skill-trigger-policy.json', 'repo-identities.tsv']:
        source = root / 'config' / name
        if source.is_file():
            expected['config/' + name] = sha(source.read_bytes())
    if tree(snapshot) != expected:
        fail('snapshot contains unexpected files')
    return plan


def finish(path):
    path = Path(path)
    plan = json.loads(path.read_text())
    # Revalidate source and snapshot, then prove the actual copied bytes.
    validate(path, plan['source_root'], plan['report'])
    for entry in plan['entries']:
        actual = tree(Path(entry['destination']))
        for rel, digest in entry['files'].items():
            if actual.get(rel) != digest:
                fail('installed bytes differ')
        backup = Path(plan['homes'][entry['client']]) / 'skills-backup' / (entry['name'] + '.' + plan['run_id'])
        entry['backup'] = str(backup) if backup.exists() else None
        entry['backup_files'] = tree(backup)
    receipt_dir = safe(Path(os.environ['HOME']) / '.local/state/ai-devops/scoped-skills')
    receipt_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    receipt = receipt_dir / (plan['run_id'] + '.json')
    plan['approval_summary'] = (path.parent / 'gate-summary.txt').read_text().strip()
    plan['status'] = 'verified'
    plan.pop('snapshot')
    fd, stage = tempfile.mkstemp(dir=receipt_dir)
    with os.fdopen(fd, 'w') as out:
        json.dump(plan, out, sort_keys=True, indent=2)
        out.write('\n')
        out.flush()
        os.fsync(out.fileno())
    os.replace(stage, receipt)
    print(receipt)


if __name__ == '__main__':
    try:
        operation, *args = sys.argv[1:]
        if operation == 'prepare':
            if args[4:5] == ['--scratch']:
                prepare(*args[:4], args[6:], scratch=args[5])
            else:
                prepare(*args[:4], args[4:])
        elif operation == 'validate':
            validate(*args)
        elif operation == 'finish':
            finish(*args)
        else:
            fail('unknown scoped operation')
    except (ValueError, KeyError, OSError, subprocess.SubprocessError) as error:
        print('Scoped skill installation refused: ' + str(error), file=sys.stderr)
        sys.exit(3)
