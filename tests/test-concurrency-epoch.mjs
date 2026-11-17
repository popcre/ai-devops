// Guard for the ghost-run escape (popcre/ai-devops#2367, docs/ghost-run-escape.md):
// bumping repo variable LANE_EPOCH must rename every concurrency group at once,
// so every group: line inside a concurrency: block must end with the suffix.
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readdirSync, readFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const SUFFIX = "-${{ vars.LANE_EPOCH || '0' }}"
const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')
const WF = join(ROOT, '.github', 'workflows')

export function concurrencyGroups(text) {
  const groups = []
  let block = -1
  text.split('\n').forEach((raw, idx) => {
    const line = raw.replace(/\s+#.*$/, '')
    const body = line.trimStart()
    if (!body || body.startsWith('#')) return
    const indent = line.length - body.length
    if (/^concurrency:\s*$/.test(body)) { block = indent; return }
    if (block >= 0 && indent <= block) block = -1
    if (block >= 0 && /^group:\s/.test(body)) groups.push({ line: idx + 1, text: body.trimEnd() })
  })
  return groups
}

export function missingSuffix(text) {
  return concurrencyGroups(text).filter((g) => !g.text.endsWith(SUFFIX))
}

test('every workflow concurrency group carries the shared LANE_EPOCH suffix', () => {
  const files = readdirSync(WF).filter((f) => /\.ya?ml$/.test(f))
  let seen = 0
  const bad = []
  for (const f of files) {
    const text = readFileSync(join(WF, f), 'utf8')
    seen += concurrencyGroups(text).length
    for (const g of missingSuffix(text)) bad.push(`${f}:${g.line}: ${g.text}`)
  }
  assert.ok(seen >= 8, `expected at least 8 concurrency groups, found ${seen}`)
  assert.deepEqual(bad, [], `groups missing ${SUFFIX}:\n${bad.join('\n')}`)
})

test('a group without the suffix is reported (top-level and job-level)', () => {
  const fixture = [
    'concurrency:',
    '  group: lane-a',
    'jobs:',
    '  x:',
    '    concurrency:',
    `      group: lane-b${SUFFIX}`,
    '    steps:',
    '      - run: echo "::group::not a concurrency group"',
    '  y:',
    '    concurrency:',
    '      group: lane-c',
  ].join('\n')
  assert.deepEqual(missingSuffix(fixture).map((g) => g.text), ['group: lane-a', 'group: lane-c'])
})
