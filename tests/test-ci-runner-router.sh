#!/usr/bin/env bash
# Regression test for tools/ci/runner-router.cjs, the verify.yml job that gives
# idle qualified self-hosted Windows hosts (EDGE-RUNN-ENVY and any other host
# labelled ai-devops-windows-qualified) ordinary verify.yml Windows sections as
# extra capacity and keeps every other section on Blacksmith (owner ruling
# 2026-10-01: KEEP Blacksmith in the pool; USE Blacksmith for runs that would
# otherwise get stuck; 2026-10-02: use blacksmith to run your tests). WarpBuild
# Azure BYOC is NOT routed here; only warpbuild-win2022-canary.yml uses it.
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
const { decide, decideLinux, parseEligible, run } = require(path.resolve('tools/ci/runner-router.cjs'));
let failures = 0;
const lanes = m => m.map(x => x.lane).join(',');
function check(label, fn) {
  try { fn(); console.log(`  ok   ${label}`); }
  catch (e) { failures += 1; console.error(`  FAIL ${label}: ${e.message}`); }
}
const allBlacksmith = Array(cfg.windows_sections).fill('blacksmith').join(',');

check('no idle host keeps every section on Blacksmith', () => {
  assert.strictEqual(lanes(decide(cfg, { event: 'pull_request', idleQualified: 0 }).windows_matrix), allBlacksmith);
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
check('one idle qualified host takes exactly one pull-request section', () => {
  const p = decide(cfg, { event: 'pull_request', idleQualified: 1 });
  assert.strictEqual(lanes(p.windows_matrix), 'qualified-self-hosted' + allBlacksmith.slice('blacksmith'.length));
  assert.deepStrictEqual(p.windows_matrix[0].runs_on, cfg.qualified_windows);
  assert.strictEqual(p.windows_matrix[1].runs_on, cfg.blacksmith_windows);
});
check('manual runs keep one qualified host free for the reviewer proof', () => {
  assert.strictEqual(decide(cfg, { event: 'workflow_dispatch', idleQualified: 1 }).windows_matrix.filter(x => x.lane !== 'blacksmith').length, 0);
  assert.strictEqual(decide(cfg, { event: 'workflow_dispatch', idleQualified: 2 }).windows_matrix.filter(x => x.lane !== 'blacksmith').length, 1);
});
check('more idle hosts than sections never over-assigns', () => {
  assert.strictEqual(decide(cfg, { event: 'pull_request', idleQualified: 50 }).windows_matrix.filter(x => x.lane !== 'blacksmith').length, cfg.windows_sections);
});
check('the section-only lane uses its own label, never the qualified one', () => {
  assert.deepStrictEqual(cfg.section_windows, ['self-hosted', 'Windows', 'X64', cfg.section_label]);
  assert.ok(!cfg.section_windows.includes(cfg.qualified_label));
  assert.notStrictEqual(cfg.section_label, cfg.qualified_label);
  // Pinned to EDGE-ALIEN's measured-with-headroom sections (run 37628253929, #1312).
  assert.deepStrictEqual(cfg.section_lane_order, [3, 4, 6]);
  assert.strictEqual(new Set(cfg.section_lane_order).size, cfg.section_lane_order.length);
  for (const s of cfg.section_lane_order) assert.ok(Number.isInteger(s) && s >= 1 && s <= cfg.windows_sections);
});
check('a section outside section_lane_order never reaches a section-only host', () => {
  const p = decide(cfg, { event: 'pull_request', idleQualified: 0, idleSection: cfg.windows_sections });
  for (const w of p.windows_matrix) {
    if (w.lane === 'section-self-hosted') assert.ok(cfg.section_lane_order.includes(w.section));
  }
  assert.strictEqual(p.windows_matrix.filter(x => x.lane === 'section-self-hosted').length, cfg.section_lane_order.length);
});
check('section-only hosts skip sections a qualified host already holds', () => {
  const p = decide(cfg, { event: 'pull_request', idleQualified: cfg.section_lane_order[0], idleSection: 1 });
  const taken = p.windows_matrix.filter(x => x.lane === 'section-self-hosted');
  assert.ok(taken.length <= 1);
  for (const w of taken) assert.ok(w.section > cfg.section_lane_order[0]);
});
check('one idle section-only host takes exactly one section, the first in section_lane_order', () => {
  const p = decide(cfg, { event: 'pull_request', idleQualified: 0, idleSection: 1 });
  const taken = p.windows_matrix.filter(x => x.lane === 'section-self-hosted');
  assert.strictEqual(taken.length, 1);
  assert.strictEqual(taken[0].section, cfg.section_lane_order[0]);
  assert.deepStrictEqual(taken[0].runs_on, cfg.section_windows);
  assert.strictEqual(p.windows_matrix.filter(x => x.lane === 'blacksmith').length, cfg.windows_sections - 1);
});
check('section-only and qualified hosts never take the same section', () => {
  const p = decide(cfg, { event: 'pull_request', idleQualified: cfg.windows_sections, idleSection: 1 });
  assert.strictEqual(p.windows_matrix.filter(x => x.lane === 'section-self-hosted').length, 0);
  const q = decide(cfg, { event: 'pull_request', idleQualified: 2, idleSection: 3 });
  assert.strictEqual(q.windows_matrix.filter(x => x.lane === 'qualified-self-hosted').length, 2);
  assert.strictEqual(q.windows_matrix.filter(x => x.lane === 'section-self-hosted').length, 3);
});
check('a manual run keeps the reviewer reserve and still gives section-only hosts one section each', () => {
  const p = decide(cfg, { event: 'workflow_dispatch', idleQualified: 1, idleSection: 1 });
  assert.strictEqual(p.windows_matrix.filter(x => x.lane === 'qualified-self-hosted').length, 0);
  assert.strictEqual(p.windows_matrix.filter(x => x.lane === 'section-self-hosted').length, 1);
});
check('a foreign head never reaches a section-only host', () => {
  const p = decide(cfg, { event: 'pull_request', idleQualified: 0, idleSection: 5, foreign: true });
  assert.strictEqual(lanes(p.windows_matrix), allBlacksmith);
});
check('a foreign head never reaches the self-hosted pool or WarpBuild', () => {
  const p = decide(cfg, { event: 'pull_request', idleQualified: 50, foreign: true });
  assert.strictEqual(lanes(p.windows_matrix), allBlacksmith);
  for (const w of p.windows_matrix) {
    assert.strictEqual(w.runs_on, cfg.blacksmith_windows);
  }
});

const allBlacksmithLinux = Array(cfg.linux_shards).fill('blacksmith').join(',');
check('Linux: no idle host keeps every section on Blacksmith', () => {
  const p = decideLinux(cfg, { idleLinux: 0 });
  assert.strictEqual(lanes(p.linux_matrix), allBlacksmithLinux);
  for (const l of p.linux_matrix) assert.strictEqual(l.runs_on, cfg.blacksmith_linux);
  assert.deepStrictEqual(p.linux_matrix.map(x => x.shard), [1, 2, 3, 4]);
});
check('Linux: the self-hosted lane is the ai-devops-linux label', () => {
  assert.deepStrictEqual(cfg.linux_self_hosted, ['self-hosted', 'Linux', 'X64', cfg.linux_label]);
  assert.strictEqual(cfg.blacksmith_linux, 'blacksmith-4vcpu-ubuntu-2404');
});
check('Linux: one idle host takes exactly one section', () => {
  const p = decideLinux(cfg, { idleLinux: 1, eligible: [1, 2, 3, 4] });
  assert.strictEqual(p.linux_matrix.filter(x => x.lane === 'linux-self-hosted').length, 1);
  assert.deepStrictEqual(p.linux_matrix[cfg.linux_lane_order[0] - 1].runs_on, cfg.linux_self_hosted);
});
check('Linux: more idle hosts than sections never over-assigns', () => {
  assert.strictEqual(decideLinux(cfg, { idleLinux: 99, eligible: [1, 2, 3, 4] }).linux_matrix.filter(x => x.lane !== 'blacksmith').length, cfg.linux_shards);
});
check('Linux: no eligible list keeps every section on Blacksmith (fail closed)', () => {
  assert.strictEqual(lanes(decideLinux(cfg, { idleLinux: 4 }).linux_matrix), allBlacksmithLinux);
});
check('Linux: only an eligible section may go self-hosted', () => {
  const p = decideLinux(cfg, { idleLinux: 1, eligible: [3] });
  assert.deepStrictEqual(p.linux_matrix.filter(x => x.lane === 'linux-self-hosted').map(x => x.shard), [3]);
});
check('Linux: the eligible list parses strictly', () => {
  assert.deepStrictEqual(parseEligible('2,3'), [2, 3]);
  assert.deepStrictEqual(parseEligible(''), []);
  assert.deepStrictEqual(parseEligible(undefined), []);
  assert.deepStrictEqual(parseEligible('x,0,-1,4'), [4]);
});
check('Linux: test-ai-lock-doctor.sh is unfit for self-hosted Linux', () => {
  assert.ok(cfg.linux_unfit_suites.includes('test-ai-lock-doctor.sh'));
});
check('Linux: a foreign head never reaches a self-hosted Linux host', () => {
  assert.strictEqual(lanes(decideLinux(cfg, { idleLinux: 5, foreign: true, eligible: [1, 2, 3, 4] }).linux_matrix), allBlacksmithLinux);
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
const sectionOnly = Array.from({ length: cfg.windows_sections }, (_, k) => (k + 1 === cfg.section_lane_order[0] ? 'section-self-hosted' : 'blacksmith')).join(',');

(async () => {
  const cases = [
    ['a failed pool lookup keeps every section on Blacksmith', { github: fakeGithub(), poolGithub: fakePool([], true) }, allBlacksmith],
    ['a failed job lookup keeps every section on Blacksmith', { github: fakeGithub([], true), poolGithub: fakePool([envy(false)]) }, allBlacksmith],
    ['no pool token keeps every section on Blacksmith', { github: fakeGithub(), poolGithub: null }, allBlacksmith],
    ['an idle qualified host takes section 1', { github: fakeGithub(), poolGithub: fakePool([envy(false)]) }, 'qualified-self-hosted' + allBlacksmith.slice('blacksmith'.length)],
    ['a job already waiting for the qualified host claims it first',
      { github: fakeGithub([{ status: 'queued', labels: ['self-hosted', cfg.qualified_label] }]), poolGithub: fakePool([envy(false)]) }, allBlacksmith],
    ['busy, offline and unqualified hosts are never used',
      { github: fakeGithub(), poolGithub: fakePool([envy(true), envy(false, ['self-hosted', 'ai-devops-windows']), { ...envy(false), status: 'offline' }]) }, allBlacksmith],
    ['an idle section-only host takes one section only',
      { github: fakeGithub(), poolGithub: fakePool([envy(false, ['self-hosted', 'ai-devops-windows', cfg.section_label])]) }, sectionOnly],
    ['a busy or offline section-only host leaves every section on Blacksmith',
      { github: fakeGithub(), poolGithub: fakePool([envy(true, ['self-hosted', cfg.section_label]), { ...envy(false, ['self-hosted', cfg.section_label]), status: 'offline' }]) }, allBlacksmith],
    ['a section job already waiting for the section-only host claims it first',
      { github: fakeGithub([{ status: 'queued', labels: ['self-hosted', cfg.section_label] }]), poolGithub: fakePool([envy(false, ['self-hosted', cfg.section_label])]) }, allBlacksmith],
    ['queued qualified and section jobs each claim only their own pool',
      { github: fakeGithub([{ status: 'queued', labels: ['self-hosted', cfg.qualified_label] }, { status: 'queued', labels: ['self-hosted', cfg.section_label] }]),
        poolGithub: fakePool([envy(false), envy(false, ['self-hosted', cfg.section_label]), envy(false, ['self-hosted', cfg.section_label])]) }, sectionOnly],
    ['a queued job carrying both labels claims a qualified host, not a section host',
      { github: fakeGithub([{ status: 'queued', labels: ['self-hosted', cfg.qualified_label, cfg.section_label] }]),
        poolGithub: fakePool([envy(false), envy(false, ['self-hosted', cfg.section_label])]) }, sectionOnly],
    ['a host with both labels counts only as qualified',
      { github: fakeGithub(), poolGithub: fakePool([envy(false, ['self-hosted', cfg.qualified_label, cfg.section_label])]) }, 'qualified-self-hosted' + allBlacksmith.slice('blacksmith'.length)],
    ['a failed pool lookup never routes to a section-only host', { github: fakeGithub([], true), poolGithub: fakePool([envy(false, ['self-hosted', cfg.section_label])]) }, allBlacksmith],
  ];
  for (const [label, deps, expected] of cases) {
    const core = fakeCore();
    await run({ ...deps, context: ctx, core, cfg });
    check(label, () => assert.strictEqual(lanesOut(core), expected));
  }
  const linuxHost = (busy, status = 'online') => ({ status, busy, labels: ['self-hosted', 'Linux', cfg.linux_label].map(name => ({ name })) });
  const linuxOne = Array.from({ length: cfg.linux_shards }, (_, k) => (k + 1 === cfg.linux_lane_order[0] ? 'linux-self-hosted' : 'blacksmith')).join(',');
  process.env.LINUX_ELIGIBLE_SHARDS = '1,2,3,4';
  const linuxCases = [
    ['Linux: an idle edge-dev3-linux host takes one section', { github: fakeGithub(), poolGithub: fakePool([linuxHost(false)]) }, linuxOne],
    ['Linux: a busy or offline host leaves every section on Blacksmith', { github: fakeGithub(), poolGithub: fakePool([linuxHost(true), linuxHost(false, 'offline')]) }, allBlacksmithLinux],
    ['Linux: a job already queued for the host claims it first',
      { github: fakeGithub([{ status: 'queued', labels: ['self-hosted', cfg.linux_label] }]), poolGithub: fakePool([linuxHost(false)]) }, allBlacksmithLinux],
    ['Linux: a failed pool lookup keeps every section on Blacksmith', { github: fakeGithub(), poolGithub: fakePool([], true) }, allBlacksmithLinux],
    ['Linux: no pool token keeps every section on Blacksmith', { github: fakeGithub(), poolGithub: null }, allBlacksmithLinux],
    ['Linux: an idle Windows host never takes a Linux section', { github: fakeGithub(), poolGithub: fakePool([envy(false)]) }, allBlacksmithLinux],
  ];
  for (const [label, deps, expected] of linuxCases) {
    const core = fakeCore();
    await run({ ...deps, context: ctx, core, cfg });
    check(label, () => assert.strictEqual(lanes(JSON.parse(core.out.linux_matrix)), expected));
  }
  {
    const core = fakeCore();
    await run({ github: fakeGithub(), poolGithub: fakePool([linuxHost(false)]), context: { ...ctx, payload: { pull_request: { head: { repo: { full_name: 'stranger/ai-devops' } } } } }, core, cfg });
    check('Linux: a fork pull request never reaches edge-dev3-linux', () => assert.strictEqual(lanes(JSON.parse(core.out.linux_matrix)), allBlacksmithLinux));
  }
  {
    process.env.LINUX_ELIGIBLE_SHARDS = '';
    const core = fakeCore();
    await run({ github: fakeGithub(), poolGithub: fakePool([linuxHost(false)]), context: ctx, core, cfg });
    check('Linux: an idle host with no eligible section leaves every section on Blacksmith', () => assert.strictEqual(lanes(JSON.parse(core.out.linux_matrix)), allBlacksmithLinux));
    delete process.env.LINUX_ELIGIBLE_SHARDS;
  }
  for (const [label, head] of [['a fork pull request never reaches a self-hosted host or WarpBuild', { repo: { full_name: 'stranger/ai-devops' } }],
                               ['a pull request from a deleted fork never reaches a self-hosted host or WarpBuild', { repo: null }]]) {
    const core = fakeCore();
    const forkCtx = { ...ctx, payload: { pull_request: { head } } };
    await run({ github: fakeGithub(), poolGithub: fakePool([envy(false)]), context: forkCtx, core, cfg });
    check(label, () => assert.strictEqual(lanesOut(core), allBlacksmith));
    check(label + ' (never our machines)', () => {
      for (const w of JSON.parse(core.out.windows_matrix)) assert.strictEqual(w.runs_on, cfg.blacksmith_windows);
    });
  }
  if (failures) { console.error(`${failures} runner-router check(s) failed`); process.exit(1); }
  console.log('runner-router: all checks passed');
})();
JS
