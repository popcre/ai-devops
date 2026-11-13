#!/usr/bin/env node
// GHOST-RUN SWEEPER (2026-11-11 20:22Z dispatch wedge, popcre/ai-devops#2367)
// ======================================================================
//
// A GitHub dispatch wedge on 2026-11-11 20:22 UTC left "ghost" workflow run
// records: the runs LIST endpoint shows them queued with zero jobs ever
// created, while GET and DELETE /repos/{owner}/{repo}/actions/runs/{id}
// return 404 and cancel is refused ("Cannot cancel a workflow run that is
// completed"). They hold per-ref concurrency groups (cancel-in-progress:
// false) and block every later run of their workflow on their ref.
//
// This tool reaps those ghost records on a schedule. A run is a ghost when
// the listing shows it queued, it is older than the age floor (default 30
// minutes), and it never created a job. Healthy work never matches: a run
// that is progressing is not queued, and a young queued run is still within
// the dispatch grace.
//
// Ported from popcre/shared-db's scripts/db-flow/lane-watchdog.mjs (PR #6216,
// branch fix/ghost-run-reaper; tracking issue popcre/shared-db#6215).
// Adapted as a standalone tool because ai-devops has no lane-watchdog.
//
// EXIT CODES: 0 swept (no unreapable ghosts); 1 an unreapable ghost remains
// (red — a GitHub support purge is the only route left); 2 the state could
// not be read (an instrument that could not read must never be mistaken for
// "no findings").
//
// Run: node tools/ci/ghost-run-sweep.mjs --repo owner/name [--min-age-minutes 30] [--dry-run]
import { execFileSync } from 'node:child_process'
import { pathToFileURL } from 'node:url'

// ---------------------------------------------------------------------------
// Pure decision logic, unit-tested offline.
// ---------------------------------------------------------------------------

export const DEFAULT_GHOST_MIN_AGE_MS = 30 * 60 * 1000

const REPO_SLUG = /^[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+$/

/**
 * The reap plan. `runs` are `GET /actions/runs?status=queued` entries
 * ({id, status, created_at, name, head_branch, html_url}); `jobsCount` when
 * the caller probed the run's jobs endpoint is honoured — a run that did
 * create jobs is not a ghost however old. Returns { reap, notes }.
 */
export function planGhostActions(runs, nowMs = Date.now(), minAgeMs = DEFAULT_GHOST_MIN_AGE_MS) {
  const reap = []
  const notes = []
  for (const run of runs ?? []) {
    const id = Number(run?.id)
    const createdMs = Date.parse(String(run?.created_at ?? ''))
    if (!Number.isSafeInteger(id) || id <= 0 || !Number.isFinite(createdMs)) {
      notes.push({ action: 'skip-unreadable-run', reason: `run entry without a usable id/created_at: ${JSON.stringify(run?.id ?? null)}` })
      continue
    }
    if (run.status !== 'queued') continue
    if (run.jobsCount !== undefined && run.jobsCount > 0) continue
    const ageMs = nowMs - createdMs
    if (ageMs < minAgeMs) {
      notes.push({ id, action: 'skip-young-run', reason: `queued ${Math.round(ageMs / 60000)}m (< ${Math.round(minAgeMs / 60000)}m floor); still within dispatch grace` })
      continue
    }
    reap.push({
      id,
      workflow: String(run?.name ?? 'unknown workflow'),
      head_branch: String(run?.head_branch ?? ''),
      age_minutes: Math.round(ageMs / 60000),
      reason: `queued ${Math.round(ageMs / 60000)}m with no job ever created (ghost record)`,
    })
  }
  return { reap, notes }
}

// ---------------------------------------------------------------------------
// Live pass. GitHub calls go through `gh api` (the CI caller passes GH_TOKEN;
// local sessions route through bin/ai-gh per the repository contract). The
// only writes are cancel and delete of a confirmed ghost run record.
// ---------------------------------------------------------------------------

function gh(args) {
  return execFileSync('gh', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] })
}

function transportIo({ log = console.log } = {}) {
  return {
    readJson(args) {
      return JSON.parse(gh(args))
    },
    cancelRun(repo, runId) {
      if (!REPO_SLUG.test(repo)) throw new Error(`refusing unsafe repo slug: ${repo}`)
      if (!Number.isSafeInteger(runId) || runId <= 0) throw new Error(`refusing unsafe run id: ${runId}`)
      gh(['api', '-X', 'POST', `repos/${repo}/actions/runs/${runId}/cancel`])
    },
    deleteRun(repo, runId) {
      if (!REPO_SLUG.test(repo)) throw new Error(`refusing unsafe repo slug: ${repo}`)
      if (!Number.isSafeInteger(runId) || runId <= 0) throw new Error(`refusing unsafe run id: ${runId}`)
      gh(['api', '-X', 'DELETE', `repos/${repo}/actions/runs/${runId}`])
    },
    log,
  }
}

/**
 * Reap ghost run records (see planGhostActions). Each ghost is cancelled,
 * then deleted; the queued listing is read once more to see what actually
 * survived. Ghosts that remain are returned in `remaining` — the caller
 * should go red on them, because an unremovable ghost keeps holding its
 * concurrency group and only GitHub support can purge it.
 */
export function runGhostSweep({
  repo,
  io = transportIo(),
  nowMs = Date.now(),
  minAgeMs = DEFAULT_GHOST_MIN_AGE_MS,
  dryRun = false,
} = {}) {
  if (!REPO_SLUG.test(String(repo ?? ''))) throw new Error('--repo owner/name (or GITHUB_REPOSITORY) is required')
  const log = io.log ?? console.log
  const readQueued = () => {
    const answer = io.readJson(['api', `repos/${repo}/actions/runs?status=queued&per_page=100`])
    if (!Array.isArray(answer?.workflow_runs)) throw new Error('queued run listing did not return workflow_runs; refusing rather than judge a partial read')
    return answer.workflow_runs
  }
  const { reap, notes } = planGhostActions(readQueued(), nowMs, minAgeMs)
  for (const note of notes) log(`ghost sweep: ${note.action}${note.id ? ` run ${note.id}` : ''}: ${note.reason}`)
  if (!reap.length) {
    log('ghost sweep: no wedged queued runs.')
    return { reap: [], remaining: [], notes }
  }
  const remaining = []
  for (const ghost of reap) {
    if (dryRun) {
      log(`ghost sweep: DRY-RUN would cancel+delete run ${ghost.id} (${ghost.workflow} on ${ghost.head_branch}) — ${ghost.reason}`)
      continue
    }
    try {
      io.cancelRun(repo, ghost.id)
    } catch (error) {
      log(`ghost sweep: run ${ghost.id} cancel refused (${error?.message ?? error}); trying delete`)
    }
    try {
      io.deleteRun(repo, ghost.id)
      log(`ghost sweep: reaped run ${ghost.id} (${ghost.workflow} on ${ghost.head_branch}) — ${ghost.reason}`)
    } catch (error) {
      log(`ghost sweep: run ${ghost.id} DELETE refused (${error?.message ?? error})`)
    }
  }
  if (!dryRun) {
    const survivors = new Set(readQueued().map((run) => Number(run?.id)))
    for (const ghost of reap) if (survivors.has(ghost.id)) remaining.push(ghost)
    for (const ghost of remaining) log(`ghost sweep: UNREAPABLE run ${ghost.id} (${ghost.workflow} on ${ghost.head_branch}) still queued; a GitHub support purge is the only route left`)
  }
  return { reap, remaining, notes }
}

// ---------------------------------------------------------------------------
// CLI
// ---------------------------------------------------------------------------

function argValue(argv, flag) {
  const i = argv.indexOf(flag)
  return i >= 0 ? argv[i + 1] : undefined
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const argv = process.argv.slice(2)
  try {
    const minAgeMinutes = Number(argValue(argv, '--min-age-minutes') ?? 30)
    const result = runGhostSweep({
      repo: argValue(argv, '--repo') ?? process.env.GITHUB_REPOSITORY,
      minAgeMs: Math.max(0, minAgeMinutes) * 60000,
      dryRun: argv.includes('--dry-run'),
    })
    // Red on unreaped ghosts: they hold concurrency groups and silence is
    // what made the 2026-11-11 batch invisible for a day.
    if (result.remaining.length) process.exit(1)
    process.exit(0)
  } catch (error) {
    console.error(`ghost sweep: could not read the state: ${error?.message ?? error}`)
    process.exit(2)
  }
}
