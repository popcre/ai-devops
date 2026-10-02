'use strict';
// Windows section routing pool (Blacksmith removed — it is turned off).
// Preference order:
// 1. idle qualified self-hosted hosts (EDGE-RUNN-ENVY and any other host
//    labelled ai-devops-windows-qualified) as extra capacity
// 2. GitHub-hosted Windows runners
// 3. WarpBuild Azure BYOC — final option, only after GitHub-hosted and
//    edge-runn-envy are full
// run() never throws: any lookup error keeps the all-GitHub plan.

function range(n) { return Array.from({ length: n }, (_, i) => i + 1); }

function decide(cfg, { event, idleQualified, githubFull = false, foreign = false }) {
  const reserve = cfg.reserve_qualified_for_reviewer_events.includes(event) ? cfg.reserved_qualified_hosts : 0;
  // A foreign head never runs on our machines: not the self-hosted pool and
  // not the WarpBuild BYOC VMs in our own Azure subscription. Both stay zero;
  // every section falls through to GitHub-hosted.
  let selfHosted = foreign ? 0 : Math.max(0, Math.min(cfg.windows_sections, (idleQualified || 0) - reserve));
  const limit = cfg.github_windows_limit == null ? cfg.windows_sections : cfg.github_windows_limit;
  let github = githubFull ? 0 : Math.max(0, Math.min(cfg.windows_sections, limit));
  return {
    idle_qualified: idleQualified || 0,
    github_full: !!githubFull,
    windows_matrix: range(cfg.windows_sections).map(section => {
      if (selfHosted > 0) { selfHosted -= 1; return { section, lane: 'qualified-self-hosted', runs_on: cfg.qualified_windows }; }
      if (github > 0) { github -= 1; return { section, lane: 'github-hosted', runs_on: cfg.github_windows }; }
      return { section, lane: 'warpbuild', runs_on: cfg.warpbuild_windows };
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

async function run({ github, poolGithub, context, core, cfg, githubFull = false }) {
  let idle = 0;
  const foreign = isForeignHead(context);
  if (foreign) {
    core.info('Pull request head is outside this repository; every Windows section stays on GitHub-hosted runners.');
    poolGithub = null;
  }
  try {
    if (poolGithub) idle = Math.max(0, (await countIdleQualified(poolGithub, context, cfg)) - (await queuedQualifiedJobs(github, context, cfg)));
  } catch (error) {
    core.warning(`Qualified pool unknown (${error.message}); every Windows section stays on GitHub-hosted runners.`);
    idle = 0;
  }
  const plan = decide(cfg, { event: context.eventName, idleQualified: idle, githubFull, foreign });
  core.info(`idle_qualified=${plan.idle_qualified}`);
  core.info(`github_full=${plan.github_full}`);
  for (const w of plan.windows_matrix) core.info(`windows section ${w.section} -> ${w.lane}`);
  core.setOutput('windows_matrix', JSON.stringify(plan.windows_matrix));
  core.summary.addRaw(`Runner routing: idle qualified Windows hosts ${plan.idle_qualified}; GitHub-hosted full ${plan.github_full}.\n\n` +
    plan.windows_matrix.map(w => `- Windows section ${w.section}: ${w.lane}`).join('\n') + '\n');
  await core.summary.write();
  return plan;
}

module.exports = { decide, run, isForeignHead };
