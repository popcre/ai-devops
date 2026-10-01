'use strict';
// Gives idle qualified self-hosted Windows hosts (EDGE-RUNN-ENVY and any other
// host labelled ai-devops-windows-qualified) ordinary verify.yml Windows
// sections as extra capacity. Every other section stays on Blacksmith, the
// lane that always has capacity (owner ruling 2026-10-01: KEEP Blacksmith in
// the pool until WarpBuild is fully up; USE Blacksmith for runs that would
// otherwise get stuck). WarpBuild Azure BYOC is NOT routed here: it runs the
// required suite as a non-blocking proof job (windows-offline-warpbuild-proof
// in verify.yml) outside the required aggregate, so an unqueued WarpBuild pool
// can never block a merge. run() never throws: any lookup error keeps the
// all-Blacksmith plan, so routing can only add capacity and never sends work
// back to the GitHub-hosted queue.

function range(n) { return Array.from({ length: n }, (_, i) => i + 1); }

function decide(cfg, { event, idleQualified, foreign }) {
  const reserve = cfg.reserve_qualified_for_reviewer_events.includes(event) ? cfg.reserved_qualified_hosts : 0;
  // A foreign head never runs on our machines: not the self-hosted pool and
  // not the WarpBuild BYOC VMs in our own Azure subscription. Both stay zero;
  // every section falls through to Blacksmith.
  let selfHosted = foreign ? 0 : Math.max(0, Math.min(cfg.windows_sections, (idleQualified || 0) - reserve));
  return {
    idle_qualified: idleQualified || 0,
    windows_matrix: range(cfg.windows_sections).map(section => {
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
// Azure subscription. This check is defense in depth - the workflow's own
// job-level `if` conditions are the primary guard and are not editable by the
// router this job loads from the pull request's tree.
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
    core.warning(`Qualified pool unknown (${error.message}); every Windows section stays on Blacksmith.`);
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
