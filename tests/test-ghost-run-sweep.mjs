// Guard: the ghost-run sweeper's decision logic (2026-11-11 20:22Z batch;
// popcre/ai-devops#2367; ported from popcre/shared-db#6215/#6216). Everything
// here is offline: the pure planning function runs against fixture queued-run
// listings, and the live sweep runs against a fake transport, proving the
// exact decisions the live pass makes:
//
//   - a ghost is a run the listing shows as queued past the age floor with
//     no job ever created,
//   - young queued runs and progressing runs are left alone,
//   - a surviving ghost (delete refused) is reported, never swallowed,
//   - dry-run touches nothing.
//
// Run: node --test tests/test-ghost-run-sweep.mjs
import test from 'node:test'
import assert from 'node:assert/strict'
import {
  planGhostActions,
  runGhostSweep,
  DEFAULT_GHOST_MIN_AGE_MS,
} from '../tools/ci/ghost-run-sweep.mjs'

const GHOST_NOW = Date.parse('2026-11-12T22:00:00Z')
const ghost = (over) => ({ id: 9001, status: 'queued', created_at: '2026-11-11T20:22:36Z', name: 'verify', head_branch: 'fix/some-pr', ...over })

test('planGhostActions reaps only old queued runs with no jobs', () => {
  const { reap, notes } = planGhostActions([
    ghost({}),
    ghost({ id: 9002, created_at: '2026-11-12T21:50:00Z' }), // 10m old: grace
    ghost({ id: 9003, status: 'in_progress' }), // progressing: never touched
    ghost({ id: 9004, jobsCount: 1 }), // created a job: not a ghost
    ghost({ id: 'not-a-number' }), // unreadable entry: skipped, never guessed
  ], GHOST_NOW, DEFAULT_GHOST_MIN_AGE_MS)
  assert.deepEqual(reap.map((g) => g.id), [9001])
  assert.match(reap[0].reason, /ghost record/)
  assert.ok(notes.some((n) => n.id === 9002 && n.action === 'skip-young-run'))
  assert.ok(notes.some((n) => n.action === 'skip-unreadable-run'))
})

test('runGhostSweep cancels, deletes, and reports what survived', () => {
  const calls = []
  let listingPass = 0
  const io = {
    readJson: (args) => {
      assert.match(String(args[1]), /status=queued/)
      listingPass += 1
      // Second pass: 9001 reaped, 9002 survived every mutation.
      return { workflow_runs: listingPass === 1 ? [ghost({}), ghost({ id: 9002, created_at: '2026-11-11T21:22:36Z' })] : [ghost({ id: 9002, created_at: '2026-11-11T21:22:36Z' })] }
    },
    cancelRun: (repo, id) => { calls.push(['cancel', repo, id]) },
    deleteRun: (repo, id) => {
      calls.push(['delete', repo, id])
      if (id === 9002) throw new Error('404 Not Found')
    },
    log: () => {},
  }
  const result = runGhostSweep({ repo: 'acme/widgets', io, nowMs: GHOST_NOW, minAgeMs: DEFAULT_GHOST_MIN_AGE_MS })
  assert.deepEqual(calls, [
    ['cancel', 'acme/widgets', 9001], ['delete', 'acme/widgets', 9001],
    ['cancel', 'acme/widgets', 9002], ['delete', 'acme/widgets', 9002],
  ])
  assert.equal(result.reap.length, 2)
  assert.deepEqual(result.remaining.map((g) => g.id), [9002], 'the surviving ghost must be reported, not swallowed')
})

test('runGhostSweep dry-run touches nothing', () => {
  const calls = []
  const io = {
    readJson: () => ({ workflow_runs: [ghost({})] }),
    cancelRun: (...a) => { calls.push(['cancel', ...a]) },
    deleteRun: (...a) => { calls.push(['delete', ...a]) },
    log: () => {},
  }
  const result = runGhostSweep({ repo: 'acme/widgets', io, nowMs: GHOST_NOW, minAgeMs: DEFAULT_GHOST_MIN_AGE_MS, dryRun: true })
  assert.deepEqual(calls, [])
  assert.equal(result.reap.length, 1)
  assert.deepEqual(result.remaining, [])
})
