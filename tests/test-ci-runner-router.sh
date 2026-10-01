#!/usr/bin/env bash
# Regression test for tools/ci/runner-router.cjs, the verify.yml job that gives
# WarpBuild Azure BYOC its proven allotment of Windows sections, hands the rest
# to idle qualified self-hosted hosts when one is free, and keeps every other
# section on Blacksmith so CI is never stuck (owner ruling 2026-10-01).
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
// The default plan is the WarpBuild allotment first, Blacksmith overflow.
const warpLane = Array(cfg.warpbuild_sections).fill('warpbuild').join(',');
const overflowCount = cfg.windows_sections - cfg.warpbuild_sections;
const overflow = Array(overflowCount).fill('blacksmith').join(',');
const defaultPlan = warpLane + (overflowCount ? ',' + overflow : '');

check('no idle host keeps the WarpBuild allotment and Blacksmith overflow', () => {
  assert.strictEqual(lanes(decide(cfg, { event: 'pull_request', idleQualified: 0 }).windows_matrix), defaultPlan);
});
check('the config never names a GitHub-hosted label', () => {
  assert.ok(!/windows-20\d\d"|ubuntu-\d\d\.\d\d/.test(JSON.stringify(cfg).replace(cfg.blacksmith_windows, '').replace(cfg.warpbuild_windows, '')));
});
check('every section is planned exactly once', () => {
  for (const i of [0, 2, 99]) {
    assert.deepStrictEqual(decide(cfg, { event: 'pull_request', idleQualified: i }).windows_matrix.map(x => x.section),
      Array.from({ length: cfg.windows_sections }, (_, k) => k + 1));
  }
});
check('one idle qualified host takes one overflow section', () => {
  const p = decide(cfg, { event: 'pull_request', idleQualified: 1 });
  // First warpbuild_sections to WarpBuild, next one to the qualified host.
  assert.deepStrictEqual(p.windows_matrix[0].runs_on, cfg.warpbuild_windows);
  assert.deepStrictEqual(p.windows_matrix[cfg.warpbuild_sections].runs_on, cfg.qualified_windows);
  assert.strictEqual(p.windows_matrix[cfg.warpbuild_sections].lane, 'qualified-self-hosted');
  assert.strictEqual(p.windows_matrix[cfg.warpbuild_sections + 1].runs_on, cfg.blacksmith_windows);
});
check('manual runs keep one qualified host free for the reviewer proof', () => {
  assert.strictEqual(decide(cfg, { event: 'workflow_dispatch', idleQualified: 1 }).windows_matrix.filter(x => x.lane === 'qualified-self-hosted').length, 0);
  assert.strictEqual(decide(cfg, { event: 'workflow_dispatch', idleQualified: 2 }).windows_matrix.filter(x => x.lane === 'qualified-self-hosted').length, 1);
});
check('more idle hosts than overflow slots never over-assigns', () => {
  const p = decide(cfg, { event: 'pull_request', idleQualified: 50 });
  assert.strictEqual(p.windows_matrix.filter(x => x.lane === 'qualified-self-hosted').length, overflowCount);
  assert.strictEqual(p.windows_matrix.filter(x => x.lane === 'warpbuild').length, cfg.warpbuild_sections);
});
check('a foreign head never reaches WarpBuild or the self-hosted pool', () => {
  const p = decide(cfg, { event: 'pull_request', idleQualified: 50, foreign: true });
  assert.strictEqual(lanes(p.windows_matrix), Array(cfg.windows_sections).fill('blacksmith').join(','));
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
    ['a failed pool lookup keeps the WarpBuild allotment and Blacksmith overflow', { github: fakeGithub(), poolGithub: fakePool([], true) }, defaultPlan],
    ['a failed job lookup keeps the WarpBuild allotment and Blacksmith overflow', { github: fakeGithub([], true), poolGithub: fakePool([envy(false)]) }, defaultPlan],
    ['no pool token keeps the WarpBuild allotment and Blacksmith overflow', { github: fakeGithub(), poolGithub: null }, defaultPlan],
    ['an idle qualified host takes one overflow section', { github: fakeGithub(), poolGithub: fakePool([envy(false)]) },
      Array(cfg.warpbuild_sections).fill('warpbuild').concat(['qualified-self-hosted'], Array(overflowCount - 1).fill('blacksmith')).join(',')],
    ['a job already waiting for the qualified host claims it first',
      { github: fakeGithub([{ status: 'queued', labels: ['self-hosted', cfg.qualified_label] }]), poolGithub: fakePool([envy(false)]) }, defaultPlan],
    ['busy, offline and unqualified hosts are never used',
      { github: fakeGithub(), poolGithub: fakePool([envy(true), envy(false, ['self-hosted', 'ai-devops-windows']), { ...envy(false), status: 'offline' }]) }, defaultPlan],
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
    check(label, () => assert.strictEqual(lanesOut(core), Array(cfg.windows_sections).fill('blacksmith').join(',')));
  }
  if (failures) { console.error(`${failures} runner-router check(s) failed`); process.exit(1); }
  console.log('runner-router: all checks passed');
})();
JS
