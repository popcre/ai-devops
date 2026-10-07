'use strict';
// Gives idle qualified self-hosted Windows hosts (EDGE-RUNN-ENVY and any other
// host labelled ai-devops-windows-qualified) ordinary verify.yml Windows
// sections as extra capacity. Every other section stays on Blacksmith, the
// lane that always has capacity (owner ruling 2026-10-01: KEEP Blacksmith in
// the pool until WarpBuild is fully up; USE Blacksmith for runs that would
// otherwise get stuck; 2026-10-02: "use blacksmith to run your tests").
// WarpBuild Azure BYOC is NOT routed here; it is proven only by
// warpbuild-win2022-canary.yml. run() never throws: any lookup error keeps the
// all-Blacksmith plan, so routing can only add capacity and never sends work
// back to the GitHub-hosted queue.
//
// Section-only hosts (#1312; owner 2026-10-06: "keep it for lighter jobs." and
// "set this machine up to take one test piece at a time") carry
// ai-devops-windows-section but not the qualified label. They have only some
// sections measured green with headroom, so each idle one takes at
// most one section (in cfg.section_lane_order) and nothing else: no complete
// matrix, no reviewer proof. A host carrying both labels counts only as
// qualified. Busy, offline or unknown means the section stays on Blacksmith.

function range(n) { return Array.from({ length: n }, (_, i) => i + 1); }

function decide(cfg, { event, idleQualified, idleSection, foreign }) {
  const reserve = cfg.reserve_qualified_for_reviewer_events.includes(event) ? cfg.reserved_qualified_hosts : 0;
  // A foreign head never runs on our machines: not the self-hosted pool and
  // not the WarpBuild BYOC VMs in our own Azure subscription. Both stay zero;
  // every section falls through to Blacksmith.
  let selfHosted = foreign ? 0 : Math.max(0, Math.min(cfg.windows_sections, (idleQualified || 0) - reserve));
  const matrix = range(cfg.windows_sections).map(section => {
    if (selfHosted > 0) { selfHosted -= 1; return { section, lane: 'qualified-self-hosted', runs_on: cfg.qualified_windows }; }
    return { section, lane: 'blacksmith', runs_on: cfg.blacksmith_windows };
  });
  // One section per idle section-only host, never more than there are hosts.
  let sectionHosts = foreign || !cfg.section_label ? 0 : Math.max(0, idleSection || 0);
  for (const section of cfg.section_lane_order || []) {
    if (sectionHosts <= 0) break;
    const slot = matrix[section - 1];
    if (!slot || slot.lane !== 'blacksmith') continue;
    matrix[section - 1] = { section, lane: 'section-self-hosted', runs_on: cfg.section_windows };
    sectionHosts -= 1;
  }
  return { idle_qualified: idleQualified || 0, idle_section: idleSection || 0, windows_matrix: matrix };
}

// Jobs already queued for a qualified host will claim idle ones first, so two
// verify runs starting together do not both count the same machine.
async function queuedPoolJobs(github, context, cfg) {
  const repo = context.repo;
  const queued = { qualified: 0, section: 0 };
  const { data } = await github.rest.actions.listWorkflowRunsForRepo({ ...repo, status: 'in_progress', per_page: cfg.max_active_runs_sampled });
  for (const run of data.workflow_runs.slice(0, cfg.max_active_runs_sampled)) {
    if (run.id === context.runId) continue;
    const { data: jobs } = await github.rest.actions.listJobsForWorkflowRun({ ...repo, run_id: run.id, filter: 'latest', per_page: 100 });
    for (const j of jobs.jobs) {
      if (j.status !== 'queued') continue;
      const labels = j.labels || [];
      if (labels.includes(cfg.qualified_label)) queued.qualified += 1;
      else if (cfg.section_label && labels.includes(cfg.section_label)) queued.section += 1;
    }
  }
  return queued;
}

async function countIdlePool(poolGithub, context, cfg) {
  const runners = await poolGithub.paginate(poolGithub.rest.actions.listSelfHostedRunnersForRepo, { ...context.repo, per_page: 100 });
  const idle = runners.filter(r => r.status === 'online' && !r.busy);
  const has = (r, name) => r.labels.some(l => l.name === name);
  return {
    qualified: idle.filter(r => has(r, cfg.qualified_label)).length,
    section: cfg.section_label ? idle.filter(r => has(r, cfg.section_label) && !has(r, cfg.qualified_label)).length : 0,
  };
}

// Code from another repository (a fork pull request) never runs on our own
// machines: neither the self-hosted pool nor the WarpBuild BYOC VMs in our own
// Azure subscription. This check is defense in depth - the workflow's own
// job-level `if` conditions are the primary guard and are not editable by the
// router this job loads from the pull request's tree.
function isForeignHead(context) {
  const head = context.payload && context.payload.pull_request && context.payload.pull_request.head;
  return !!head && (!head.repo || head.repo.full_name !== `${context.repo.owner}/${context.repo.repo}`);
}

async function run({ github, poolGithub, context, core, cfg }) {
  let idle = 0;
  let idleSection = 0;
  const foreign = isForeignHead(context);
  if (foreign) {
    core.info('Pull request head is outside this repository; every Windows section stays on Blacksmith.');
    poolGithub = null;
  }
  try {
    if (poolGithub) {
      const pool = await countIdlePool(poolGithub, context, cfg);
      const queued = await queuedPoolJobs(github, context, cfg);
      idle = Math.max(0, pool.qualified - queued.qualified);
      idleSection = Math.max(0, pool.section - queued.section);
    }
  } catch (error) {
    core.warning(`Qualified pool unknown (${error.message}); every Windows section stays on Blacksmith.`);
    idle = 0;
    idleSection = 0;
  }
  const plan = decide(cfg, { event: context.eventName, idleQualified: idle, idleSection, foreign });
  core.info(`idle_qualified=${plan.idle_qualified} idle_section=${plan.idle_section}`);
  for (const w of plan.windows_matrix) core.info(`windows section ${w.section} -> ${w.lane}`);
  core.setOutput('windows_matrix', JSON.stringify(plan.windows_matrix));
  core.summary.addRaw(`Runner routing: idle qualified Windows hosts ${plan.idle_qualified}; idle section-only hosts ${plan.idle_section}.\n\n` +
    plan.windows_matrix.map(w => `- Windows section ${w.section}: ${w.lane}`).join('\n') + '\n');
  await core.summary.write();
  return plan;
}

module.exports = { decide, run, isForeignHead };
