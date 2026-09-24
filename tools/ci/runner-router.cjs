'use strict';
// Gives idle qualified self-hosted Windows hosts (EDGE-RUNN-ENVY and any other
// host labelled ai-devops-windows-qualified) ordinary verify.yml Windows
// sections as extra capacity. Every other section stays on Blacksmith, the
// owner's 2026-09-23 lane for all verify jobs. run() never throws: any lookup
// error keeps the all-Blacksmith plan, so routing can only add capacity and
// never sends work back to the GitHub-hosted queue.

function range(n) { return Array.from({ length: n }, (_, i) => i + 1); }

function decide(cfg, { event, idleQualified }) {
  const reserve = cfg.reserve_qualified_for_reviewer_events.includes(event) ? cfg.reserved_qualified_hosts : 0;
  let selfHosted = Math.max(0, Math.min(cfg.windows_sections, (idleQualified || 0) - reserve));
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

async function run({ github, poolGithub, context, core, cfg }) {
  let idle = 0;
  try {
    if (poolGithub) idle = Math.max(0, (await countIdleQualified(poolGithub, context, cfg)) - (await queuedQualifiedJobs(github, context, cfg)));
  } catch (error) {
    core.warning(`Qualified pool unknown (${error.message}); every Windows section stays on Blacksmith.`);
    idle = 0;
  }
  const plan = decide(cfg, { event: context.eventName, idleQualified: idle });
  core.info(`idle_qualified=${plan.idle_qualified}`);
  for (const w of plan.windows_matrix) core.info(`windows section ${w.section} -> ${w.lane}`);
  core.setOutput('windows_matrix', JSON.stringify(plan.windows_matrix));
  core.summary.addRaw(`Runner routing: idle qualified Windows hosts ${plan.idle_qualified}.\n\n` +
    plan.windows_matrix.map(w => `- Windows section ${w.section}: ${w.lane}`).join('\n') + '\n');
  await core.summary.write();
  return plan;
}

module.exports = { decide, run };
