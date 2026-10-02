#!/usr/bin/env bash
# Regression test for tools/ci/runner-router.cjs, the verify.yml job that gives
# idle qualified self-hosted Windows hosts ordinary Windows sections, keeps the
# rest on GitHub-hosted runners, and sends overflow to WarpBuild only after
# both are full.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v node >/dev/null 2>&1; then
  printf 'FAIL: node is required to test tools/ci/runner-router.cjs\n' >&2
  exit 1
fi
cd "$ROOT" || exit 1
node - <<'JS'
const assert = require('assert');
const path = require('path');
const cfg = require(path.resolve('config/ci-runner-routing.json'));
const { decide, run } = require(path.resolve('tools/ci/runner-router.cjs'));
let failures = 0;
const lanes = m => m.map(x => x.lane).join(',');
function check(label, fn) {
  try { fn(); console.log(`  ok   ${label}`); }
  catch (e) { failures += 1; console.error(`  FAIL ${label}: ${e.message}`); }
}
const allGithub = Array(cfg.windows_sections).fill('github-hosted').join(',');
const allWarp = Array(cfg.windows_sections).fill('warpbuild').join(',');

check('no idle host and GitHub available keeps every section on GitHub-hosted', () => {
  assert.strictEqual(lanes(decide(cfg, { event: 'pull_request', idleQualified: 0 }).windows_matrix), allGithub);
});
check('Blacksmith is out of the pool', () => {
  const cfgNoComment = { ...cfg }; delete cfgNoComment._comment;
  assert.ok(!/blacksmith/i.test(JSON.stringify(cfgNoComment)));
  assert.ok(!/blacksmith/i.test(JSON.stringify(decide(cfg, { event: 'pull_request', idleQualified: 0 }))));
});
check('the pool names GitHub-hosted, qualified self-hosted, and WarpBuild', () => {
  assert.strictEqual(cfg.github_windows, 'windows-2025');
  assert.deepStrictEqual(cfg.qualified_windows, ['self-hosted', 'Windows', 'X64', 'ai-devops-windows-qualified']);
  assert.deepStrictEqual(cfg.warpbuild_windows, [
    'warp-custom-warpbuild-win2022-canary',
    'warp-custom-warpbuild-win2022-use2',
    'warp-custom-warpbuild-win2022-cus',
  ]);
});
check('every section is planned exactly once', () => {
  for (const i of [0, 2, 99]) {
    assert.deepStrictEqual(decide(cfg, { event: 'pull_request', idleQualified: i }).windows_matrix.map(x => x.section),
      Array.from({ length: cfg.windows_sections }, (_, k) => k + 1));
  }
});
check('one idle qualified host takes exactly one pull-request section', () => {
  const p = decide(cfg, { event: 'pull_request', idleQualified: 1 });
  assert.strictEqual(lanes(p.windows_matrix), 'qualified-self-hosted' + allGithub.slice('github-hosted'.length));
  assert.deepStrictEqual(p.windows_matrix[0].runs_on, cfg.qualified_windows);
  assert.strictEqual(p.windows_matrix[1].runs_on, cfg.github_windows);
});
check('manual runs keep one qualified host free for the reviewer proof', () => {
  assert.strictEqual(decide(cfg, { event: 'workflow_dispatch', idleQualified: 1 }).windows_matrix.filter(x => x.lane === 'qualified-self-hosted').length, 0);
  assert.strictEqual(decide(cfg, { event: 'workflow_dispatch', idleQualified: 2 }).windows_matrix.filter(x => x.lane === 'qualified-self-hosted').length, 1);
});
check('more idle hosts than sections never over-assigns', () => {
  assert.strictEqual(decide(cfg, { event: 'pull_request', idleQualified: 50 }).windows_matrix.filter(x => x.lane === 'qualified-self-hosted').length, cfg.windows_sections);
});
check('WarpBuild is the final option only when GitHub is full and ENVY is gone', () => {
  const p = decide(cfg, { event: 'pull_request', idleQualified: 0, githubFull: true });
  assert.strictEqual(lanes(p.windows_matrix), allWarp);
  const mixed = decide(cfg, { event: 'pull_request', idleQualified: 1, githubFull: true });
  assert.strictEqual(lanes(mixed.windows_matrix), 'qualified-self-hosted,warpbuild,warpbuild,warpbuild,warpbuild,warpbuild,warpbuild,warpbuild');
  const notFull = decide(cfg, { event: 'pull_request', idleQualified: 0, githubFull: false });
  assert.ok(notFull.windows_matrix.every(w => w.lane === 'github-hosted'));
});
check('WarpBuild labels are distributed round-robin across the three BYOC stacks', () => {
  const p = decide(cfg, { event: 'pull_request', idleQualified: 0, githubFull: true });
  const labels = cfg.warpbuild_windows;
  for (const w of p.windows_matrix) {
    assert.strictEqual(w.runs_on, labels[(w.section - 1) % labels.length]);
  }
});
check('github_windows_limit overflows the remainder to WarpBuild', () => {
  const limited = Object.assign({}, cfg, { github_windows_limit: 2 });
  const p = decide(limited, { event: 'pull_request', idleQualified: 0 });
  assert.strictEqual(lanes(p.windows_matrix), 'github-hosted,github-hosted,warpbuild,warpbuild,warpbuild,warpbuild,warpbuild,warpbuild');
});
check('a foreign head never reaches the self-hosted pool or WarpBuild', () => {
  const p = decide(cfg, { event: 'pull_request', idleQualified: 50, foreign: true });
  assert.strictEqual(lanes(p.windows_matrix), allGithub);
  for (const w of p.windows_matrix) {
    assert.strictEqual(w.runs_on, cfg.github_windows);
  }
});

function fakeCore() {
  const out = {};
  return { out, info() {}, warning(m) { out._warn = (out._warn || []).concat(m); }, setOutput(k, v) { out[k] = v; },
    summary: { addRaw() { return this; }, async write() {} } };
}
function fakeGithub(activeJobs = [], throws = false) {
  return { rest: { actions: {
    listWorkflowRunsForRepo: async () => { if (throws) throw new Error('rate limited'); return { data: { workflow_runs: [{ id: 7 }, { id: 1 }] } }; },
    listJobsForWorkflowRun: async ({ run_id }) => ({ data: { jobs: run_id === 7 ? activeJobs : [] } }),
  } } };
}
function fakePool(runners, throws = false) {
  return { rest: { actions: { listSelfHostedRunnersForRepo: 'list' } },
    paginate: async () => { if (throws) throw new Error('no token scope'); return runners; } };
}
const envy = (busy, labels = ['self-hosted', cfg.qualified_label]) => ({ status: 'online', busy, labels: labels.map(name => ({ name })) });
const ctx = { repo: { owner: 'o', repo: 'r' }, runId: 1, eventName: 'pull_request' };
const lanesOut = core => lanes(JSON.parse(core.out.windows_matrix));

(async () => {
  const cases = [
    ['a failed pool lookup keeps every section on GitHub-hosted', { github: fakeGithub(), poolGithub: fakePool([], true) }, allGithub],
    ['a failed job lookup keeps every section on GitHub-hosted', { github: fakeGithub([], true), poolGithub: fakePool([envy(false)]) }, allGithub],
    ['no pool token keeps every section on GitHub-hosted', { github: fakeGithub(), poolGithub: null }, allGithub],
    ['an idle qualified host takes section 1', { github: fakeGithub(), poolGithub: fakePool([envy(false)]) }, 'qualified-self-hosted' + allGithub.slice('github-hosted'.length)],
    ['a job already waiting for the qualified host claims it first',
      { github: fakeGithub([{ status: 'queued', labels: ['self-hosted', cfg.qualified_label] }]), poolGithub: fakePool([envy(false)]) }, allGithub],
    ['busy, offline and unqualified hosts are never used',
      { github: fakeGithub(), poolGithub: fakePool([envy(true), envy(false, ['self-hosted', 'ai-devops-windows']), { ...envy(false), status: 'offline' }]) }, allGithub],
  ];
  for (const [label, deps, expected] of cases) {
    const core = fakeCore();
    await run({ ...deps, context: ctx, core, cfg });
    check(label, () => assert.strictEqual(lanesOut(core), expected));
  }
  for (const [label, head] of [['a fork pull request never reaches a self-hosted host or WarpBuild', { repo: { full_name: 'stranger/ai-devops' } }],
                               ['a pull request from a deleted fork never reaches a self-hosted host or WarpBuild', { repo: null }]]) {
    const core = fakeCore();
    const forkCtx = { ...ctx, payload: { pull_request: { head } } };
    await run({ github: fakeGithub(), poolGithub: fakePool([envy(false)]), context: forkCtx, core, cfg });
    check(label, () => assert.strictEqual(lanesOut(core), allGithub));
  }
  {
    const core = fakeCore();
    await run({ github: fakeGithub(), poolGithub: fakePool([]), context: ctx, core, cfg, githubFull: true });
    check('run() passes GitHub-full through to WarpBuild overflow', () => assert.strictEqual(lanesOut(core), allWarp));
  }
  if (failures) { console.error(`${failures} runner-router check(s) failed`); process.exit(1); }
  console.log('runner-router: all checks passed');
})();
JS
