#!/usr/bin/env python3
"""Committed-source fixtures only; no production env gate-disable switch."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('scoped', ROOT / 'tools/scoped_skills_install.py')
scoped = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(scoped)


class ScopedInstall(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory()
        cls.base = Path(cls.tmp.name)
        cls.root = cls.base / 'repo'
        cls.root.mkdir()
        # Exact test-confined copy: real gate, lifecycle and installer sources.
        for folder in ['bin', 'tools', 'config']:
            shutil.copytree(ROOT / folder, cls.root / folder, ignore=shutil.ignore_patterns('__pycache__'))
        (cls.root / 'templates/system').mkdir(parents=True)
        (cls.root / 'templates/system/CLAUDE-global.md').write_text('Fixture Claude global\n')
        (cls.root / 'templates/system/AGENTS-global-codex.md').write_text('Fixture Codex global\n')
        (cls.root / 'skills/shared/one').mkdir(parents=True)
        (cls.root / 'skills/shared/one/SKILL.md').write_text('one\n')
        (cls.root / 'skills/shared/one/run.sh').write_text('#!/bin/sh\nexit 0\n')
        (cls.root / 'skills/shared/one/run.sh').chmod(0o755)
        (cls.root / 'skills/shared/two').mkdir()
        (cls.root / 'skills/shared/two/SKILL.md').write_text('two\n')
        (cls.root / 'config/skill-scope.json').write_text('{"skills": {}}')
        cls.git('init', '-q', '--initial-branch=main')
        cls.git('config', 'user.name', 'Fixture')
        cls.git('config', 'user.email', 'fixture@example.invalid')
        cls.git('remote', 'add', 'origin', 'https://github.com/popcre/ai-devops')
        cls.git('add', '.')
        cls.git('commit', '-qm', 'fixture')
        cls.git('update-ref', 'refs/remotes/origin/main', 'HEAD')
        cls.head = cls.git('rev-parse', 'HEAD').strip()

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    @classmethod
    def git(cls, *args):
        return subprocess.check_output(['git', '-C', str(cls.root), *args], text=True)

    def setUp(self):
        self.case = Path(tempfile.mkdtemp(dir=self.base))
        self.home = self.case / 'home'
        self.home.mkdir()
        (self.home / '.codex').mkdir()
        self.env = os.environ.copy()
        for key in ['AI_INSTALL_LOG', 'AI_TASK_GATES_FILE', 'AI_REPO_POLICY_BIN', 'USERPROFILE', 'CLAUDE_HOME', 'CODEX_HOME', 'AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE']:
            self.env.pop(key, None)
        self.env.update(HOME=str(self.home), GIT_CONFIG_GLOBAL=str(self.home / '.gitconfig'), XDG_CONFIG_HOME=str(self.home / '.config'), AI_TASK_GATES_DIR=str(self.case / 'gates'), AI_REVIEW_LIFECYCLE_DIR=str(self.case / 'lifecycle'))
        self.old_home = os.environ.get('HOME')
        os.environ['HOME'] = str(self.home)
        self.report = self.case / 'report.md'
        self.report.write_text('fixture\n')
        self.plans = []

    def tearDown(self):
        for path in self.plans:
            shutil.rmtree(path.parent, ignore_errors=True)
        os.environ['HOME'] = self.old_home
        for path in [self.root / 'dirty.txt', self.root / 'skills/shared/one/link']:
            path.unlink(missing_ok=True)

    def run_cmd(self, *args, ok=True):
        run = subprocess.run(args, cwd=self.root, env=self.env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if ok:
            self.assertEqual(run.returncode, 0, run.stdout)
        else:
            self.assertNotEqual(run.returncode, 0, run.stdout)
        return run

    def plan(self):
        run = self.run_cmd('python3', str(self.root / 'tools/scoped_skills_install.py'), 'prepare', str(self.root), str(self.report), str(self.home / '.claude'), str(self.home / '.codex'), 'one')
        path = Path(run.stdout.strip())
        self.plans.append(path)
        return path

    def approve(self, extra='.'):
        command = 'source "$1"; export LIB_REVIEWER_APPROVAL_BIN="$2/bin"; mint_reviewer_approval "$3" "$2" final-check "" "$4"'
        run = self.run_cmd('bash', '-c', command, 'fixture', str(ROOT / 'tests/lib-reviewer-approval.sh'), str(self.root), str(self.case), extra)
        self.report = Path(run.stdout.strip())

    def install(self, ok=True, *extra):
        return self.run_cmd('bash', str(self.root / 'bin/ai-install-skills'), '--only', 'one', '--reviewer-approval', str(self.report), *extra, ok=ok)

    def declare(self, name='installation'):
        self.run_cmd(str(self.root / 'bin/ai-task-gates'), 'start', '--class', name)

    def test_reviewed_install_receipt_modes_backup_and_unrelated(self):
        self.declare()
        self.approve()
        unrelated = self.home / '.claude/skills/two/SKILL.md'
        unrelated.parent.mkdir(parents=True)
        unrelated.write_text('untouched\n')
        self.install()
        actual = self.home / '.claude/skills/one/SKILL.md'
        self.assertEqual(actual.read_text(), 'one\n')
        self.assertTrue((actual.parent / 'run.sh').stat().st_mode & 0o111)
        actual.write_text('local edit\n')
        self.install()
        backups = list((self.home / '.claude/skills-backup').glob('one.*/SKILL.md'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), 'local edit\n')
        receipts = list((self.home / '.local/state/ai-devops/scoped-skills').glob('*.json'))
        self.assertEqual(len(receipts), 2)
        receipt = json.loads(receipts[-1].read_text())
        self.assertEqual(receipt['head'], self.head)
        self.assertEqual(receipt['names'], ['one'])
        self.assertIn('APPROVE by grok', receipt['approval_summary'])
        self.assertEqual(unrelated.read_text(), 'untouched\n')
        self.assertFalse((self.home / '.claude/CLAUDE.md').exists())
        self.assertFalse((self.home / '.codex/AGENTS.md').exists())
        self.assertEqual(self.git('status', '--porcelain'), '')

    def test_missing_approval_cannot_be_disabled(self):
        self.declare()
        self.env['AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE'] = '1'
        self.install(False)
        self.assertFalse((self.home / '.claude/skills').exists())

    def test_wrong_class(self):
        self.declare('code')
        self.approve()
        self.install(False)

    def test_missing_test_evidence(self):
        self.declare()
        self.approve('.tests=null')
        self.assertIn('local-tests', self.install(False).stdout)

    def test_wrong_head_approval(self):
        self.declare()
        self.approve('.head="0000000000000000000000000000000000000000"')
        self.install(False)

    def test_snapshot_tamper(self):
        path = self.plan()
        plan = json.loads(path.read_text())
        (Path(plan['snapshot']) / 'skills/shared/one/SKILL.md').write_text('substitution')
        with self.assertRaises(ValueError):
            scoped.validate(path, self.root, self.report)

    def test_selection_tamper(self):
        path = self.plan()
        plan = json.loads(path.read_text())
        plan['names'] = ['two']
        path.write_text(json.dumps(plan))
        with self.assertRaises(ValueError):
            scoped.validate(path, self.root, self.report)

    def test_source_tamper(self):
        path = self.plan()
        (self.root / 'dirty.txt').write_text('dirty')
        with self.assertRaises(ValueError):
            scoped.validate(path, self.root, self.report)

    def test_destination_tamper(self):
        path = self.plan()
        plan = json.loads(path.read_text())
        plan['homes']['claude'] = str(self.case / 'other')
        path.write_text(json.dumps(plan))
        with self.assertRaises(ValueError):
            scoped.validate(path, self.root, self.report)

    def test_source_symlink(self):
        (self.root / 'skills/shared/one/link').symlink_to(self.report)
        self.run_cmd('python3', str(self.root / 'tools/scoped_skills_install.py'), 'prepare', str(self.root), str(self.report), str(self.home / '.claude'), str(self.home / '.codex'), 'one', ok=False)

    def test_destination_symlink(self):
        dest = self.home / '.claude/skills'
        dest.parent.mkdir()
        dest.symlink_to(self.case)
        self.run_cmd('python3', str(self.root / 'tools/scoped_skills_install.py'), 'prepare', str(self.root), str(self.report), str(self.home / '.claude'), str(self.home / '.codex'), 'one', ok=False)

    def test_marker_traversal(self):
        dest = self.home / '.claude/skills/one'
        dest.mkdir(parents=True)
        (dest / '.ai-devops-managed').write_text('0' * 64 + '  ../escape\n')
        self.run_cmd('python3', str(self.root / 'tools/scoped_skills_install.py'), 'prepare', str(self.root), str(self.report), str(self.home / '.claude'), str(self.home / '.codex'), 'one', ok=False)

    def test_incompatible_full_flags(self):
        self.install(False, '--adopt-globals')
        self.install(False, '--log')

    def test_dry_run_writes_nothing(self):
        before = scoped.tree(self.home)
        self.install(True, '--dry-run')
        self.assertEqual(scoped.tree(self.home), before)

    def test_existing_full_and_scoped_install_share_lock(self):
        import fcntl
        lock = self.home / '.cache/ai-devops/skills-install.lock'
        lock.parent.mkdir(parents=True)
        with lock.open('w') as held:
            fcntl.flock(held, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertIn('another installation', self.install(False).stdout)
            run = self.run_cmd('bash', str(self.root / 'bin/ai-install-skills'), ok=False)
            self.assertIn('another installation', run.stdout)
        self.assertFalse((self.home / '.claude/skills').exists())

    def test_missing_merged_release_ref(self):
        self.git('update-ref', '-d', 'refs/remotes/origin/main')
        try:
            self.run_cmd('python3', str(self.root / 'tools/scoped_skills_install.py'), 'prepare', str(self.root), str(self.report), str(self.home / '.claude'), str(self.home / '.codex'), 'one', ok=False)
        finally:
            self.git('update-ref', 'refs/remotes/origin/main', self.head)

    def test_foreign_origin(self):
        self.git('remote', 'set-url', 'origin', 'https://github.com/example/ai-devops')
        try:
            self.run_cmd('python3', str(self.root / 'tools/scoped_skills_install.py'), 'prepare', str(self.root), str(self.report), str(self.home / '.claude'), str(self.home / '.codex'), 'one', ok=False)
        finally:
            self.git('remote', 'set-url', 'origin', 'https://github.com/popcre/ai-devops')

    def test_wrong_review_mode(self):
        self.declare()
        self.approve('.review_mode="plan-review"')
        self.install(False)

    def test_report_substitution(self):
        self.declare()
        self.approve()
        self.report.write_text('substituted report')
        self.install(False)

    def test_full_receipt_and_launchers_are_unchanged(self):
        targets = [Path('/etc/ai-devops/install-manifest.tsv'), Path('/usr/local/bin/ai-task-gates')]
        before = {str(path): (path.read_bytes(), str(path.resolve())) for path in targets if path.is_file()}
        self.declare()
        self.approve()
        self.install()
        after = {str(path): (path.read_bytes(), str(path.resolve())) for path in targets if path.is_file()}
        self.assertEqual(after, before)

    def test_repeated_names_deduplicate(self):
        self.declare()
        self.approve()
        self.install(True, '--only', 'one')
        receipts = list((self.home / '.local/state/ai-devops/scoped-skills').glob('*.json'))
        receipt = json.loads(receipts[0].read_text())
        self.assertEqual(receipt['names'], ['one'])
        self.assertEqual(len(receipt['entries']), 2)

    def test_selected_shared_client_collision_refused_before_writes(self):
        collision = self.root / 'skills/claude/one'
        collision.mkdir(parents=True)
        (collision / 'SKILL.md').write_text('collision')
        try:
            before = scoped.tree(self.home)
            self.assertIn('also exists', self.install(False).stdout)
            self.assertEqual(scoped.tree(self.home), before)
        finally:
            shutil.rmtree(collision.parent)

    def test_full_install_without_flock_is_preserved(self):
        self.env['AI_DEVOPS_SKIP_MACHINE_TOOLS_GATE'] = '1'
        # This function exists only in the test process; production exposes no
        # env switch to skip its installation admission or source validation.
        command = 'command() { if [[ "$*" == "-v flock" ]]; then return 1; fi; builtin command "$@"; }; source "$1" --keep-orphans'
        self.run_cmd('bash', '-c', command, 'fixture', str(self.root / 'bin/ai-install-skills'))
        self.assertEqual((self.home / '.claude/skills/one/SKILL.md').read_text(), 'one\n')

    def test_alternate_gate_policy(self):
        self.declare()
        self.approve()
        policy = self.case / 'policy.json'
        shutil.copyfile(self.root / 'config/task-gates.json', policy)
        self.env['AI_TASK_GATES_FILE'] = str(policy)
        self.install(False)


if __name__ == '__main__':
    unittest.main()
