'use strict';
// Routes verify.yml Windows sections across three lanes. 2026-10-01 owner
// ruling: KEEP Blacksmith live until WarpBuild is fully up; prefer WarpBuild
// when it works, fall back to Blacksmith so CI is never stuck. WarpBuild Azure
// BYOC (popcre-ci-use1) takes up to cfg.warpbuild_sections sections (the Azure
// standardDASv4Family quota is 10 vCPUs = 2 concurrent Standard_D4as_v4 VMs).
// Idle qualified self-hosted hosts (ai-devops-windows-qualified) are extra
// capacity after that. Everything else - including every foreign-head section,
// because BYOC VMs are our own Azure subscription - stays on Blacksmith, the
// overflow and emergency lane. run() never throws: any lookup error keeps the
// all-Blacksmith plan, so routing can only add capacity and never sends work
// back to the GitHub-hosted queue.

function range(n) { return Array.from({ length: n }, (_, i) => i + 1); }

function decide(cfg, { event, idleQualified, foreign }) {
  const reserve = cfg.reserve_qualified_for_reviewer_events.includes(event) ? cfg.reserved_qualified_hosts : 0;
  // A foreign head never runs on our machines: not the BYOC VMs and not the
  // self-hosted pool. Both stay zero; every section falls through to Blacksmith.
  let warpbuild = foreign ? 0 : Math.max(0, Math.min(cfg.warpbuild_sections, cfg.windows_sections));
  let selfHosted = foreign ? 0 : Math.max(0, Math.min(cfg.windows_sections - warpbuild, (idleQualified || 0) - reserve));
  return {
    idle_qualified: idleQualified || 0,
    windows_matrix: range(cfg.windows_sections).map(section => {
      if (warpbuild > 0) { warpbuild -= 1; return { section, lane: 'warpbuild', runs_on: cfg.warpbuild_windows }; }
      if (selfHosted > 0) { selfHosted -= 1; return { section, lane: 'qualified-self-hosted', runs_on: cfg.qualified_windows }; }
      return { section, lane: 'blacksmith', runs_on: cfg.blacksmith_windows };
    }),
  };
}

// Jobs already queued for a qualified host will claim idle ones first, so two
// verify runs starting together do not both count the same machine.
async function queuedQualifiedJobs(github, context, cfg) {
  const repo = context.repo;
  let queued = 0;
  const { data } = await github.rest.actions.listWorkflowRunsForRepo({ ...repo, status: 'in_progress', per_page: cfg.max_active_runs_sampled });
  for (const run of data.workflow_runs.slice(0, cfg.max_active_runs_sampled)) {
    if (run.id === context.runId) continue;
    const { data: jobs } = await github.rest.actions.listJobsForWorkflowRun({ ...repo, run_id: run.id, filter: 'latest', per_page: 100 });
    queued += jobs.jobs.filter(j => j.status === 'queued' && (j.labels || []).includes(cfg.qualified_label)).length;
  }
  return queued;
}

async function countIdleQualified(poolGithub, context, cfg) {
  const runners = await poolGithub.paginate(poolGithub.rest.actions.listSelfHostedRunnersForRepo, { ...context.repo, per_page: 100 });
  return runners.filter(r => r.status === 'online' && !r.busy && r.labels.some(l => l.name === cfg.qualified_label)).length;
}

// Code from another repository (a fork pull request) never runs on our own
// machines: neither the self-hosted pool nor the WarpBuild BYOC VMs in our own
// Azure subscription. Missing secrets already hide the pool from forks; this
// makes the rule explicit instead of incidental.
function isForeignHead(context) {
  const head = context.payload && context.payload.pull_request && context.payload.pull_request.head;
  return !!head && (!head.repo || head.repo.full_name !== `${context.repo.owner}/${context.repo.repo}`);
}

async function run({ github, poolGithub, context, core, cfg }) {
  let idle = 0;
  const foreign = isForeignHead(context);
  if (foreign) {
    core.info('Pull request head is outside this repository; every Windows section stays on Blacksmith.');
    poolGithub = null;
  }
  try {
    if (poolGithub) idle = Math.max(0, (await countIdleQualified(poolGithub, context, cfg)) - (await queuedQualifiedJobs(github, context, cfg)));
  } catch (error) {
    core.warning(`Qualified pool unknown (${error.message}); every non-WarpBuild section stays on Blacksmith.`);
    idle = 0;
  }
  const plan = decide(cfg, { event: context.eventName, idleQualified: idle, foreign });
  core.info(`idle_qualified=${plan.idle_qualified}`);
  for (const w of plan.windows_matrix) core.info(`windows section ${w.section} -> ${w.lane}`);
  core.setOutput('windows_matrix', JSON.stringify(plan.windows_matrix));
  core.summary.addRaw(`Runner routing: idle qualified Windows hosts ${plan.idle_qualified}.\n\n` +
    plan.windows_matrix.map(w => `- Windows section ${w.section}: ${w.lane}`).join('\n') + '\n');
  await core.summary.write();
  return plan;
}

module.exports = { decide, run, isForeignHead };
