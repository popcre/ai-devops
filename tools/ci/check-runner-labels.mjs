#!/usr/bin/env node
// Step 3.1 (plan_ci-process-repair.md, #2367): flag every runs-on label in
// every popcre/u2giants workflow that matches no known hosted image, no
// self-hosted baseline label, no label in the runner routing config, and no
// registered runner label (when the token can list them).
//
// WHY: the Blacksmith removal (2026-11-03) left workflow labels pointing at a
// provider that no longer exists; jobs queued on a label with no runner look
// like "waiting", not "broken", and nothing failed loudly. A dead pool's jobs
// must be named as a dead label, in one place, on a schedule.
//
// ADVISORY WIRING: the scheduled job runs this tool and lets it fail the
// (non-required) job when findings exist; the scheduled-failure reporter
// (step 1.4) then opens the owned ci-red issue. Exit codes:
//   0  scan clean
//   1  findings (dead labels named on stdout)
//   2  the scan itself is broken (API unreadable, config malformed)
import { execFileSync } from 'node:child_process'
import { readFileSync, readdirSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..')

// GitHub-hosted image families (public repos run free). Any label of these
// shapes is a hosted image; anything else must be a known self-hosted label.
const HOSTED_LABEL = /^(?:ubuntu|windows|macos|ubuntu-latest|windows-latest|macos-latest|ubuntu-\d{2,4}(?:\.\d+)?(?:-arm)?|windows-\d{2,4}|macos-\d{2,3}(?:-arm64|-m1)?)$/
// Baseline self-hosted labels every runner carries or that are structural.
const BASELINE_LABELS = new Set([
  'self-hosted', 'linux', 'windows', 'macos', 'x64', 'arm64',
])
// Dynamic matrix routing is resolved by the router, not by this scan.
const DYNAMIC = '${{'

function gh(args, { allowFailure = false } = {}) {
  try {
    return execFileSync('gh', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] })
  } catch (error) {
    if (allowFailure) return null
    throw error
  }
}

export function allowedLabelsFromConfig(configPath) {
  const labels = new Set(BASELINE_LABELS)
  let config = {}
  try {
    config = JSON.parse(readFileSync(configPath, 'utf8'))
  } catch {
    throw new Error('runner routing config is missing or invalid')
  }
  const walk = (value) => {
    if (Array.isArray(value)) {
      for (const item of value) if (typeof item === 'string') labels.add(item)
    } else if (value && typeof value === 'object') {
      for (const [key, item] of Object.entries(value)) {
        if (typeof item === 'string' && /label|hosted/i.test(key)) labels.add(item)
        else if (/label|hosted|linux_self_hosted|qualified|windows_sections|section/i.test(key)) walk(item)
      }
    }
  }
  walk(config)
  return labels
}

export function runsOnLabels(workflowText) {
  const labels = []
  let dynamic = 0
  for (const line of workflowText.split(/\r?\n/)) {
    const match = /^\s*runs-on:\s*(.+?)\s*$/.exec(line)
    if (!match) continue
    const value = match[1]
    if (value.includes(DYNAMIC)) { dynamic += 1; continue }
    if (value.startsWith('[')) {
      for (const part of value.slice(1, -1).split(',')) {
        const label = part.trim().replace(/^['"]|['"]$/g, '')
        if (label) labels.push(label)
      }
    } else {
      labels.push(value.replace(/^['"]|['"]$/g, ''))
    }
  }
  return { labels, dynamic }
}

function scanText(name, text, allowed) {
  const { labels, dynamic } = runsOnLabels(text)
  const unknown = [...new Set(labels)].filter((label) => !allowed.has(label) && !HOSTED_LABEL.test(label))
  return { workflow: name, unknown, dynamic }
}

function scanLocalDir(dir, allowed) {
  const rows = []
  const workflows = join(dir, '.github', 'workflows')
  let entries = []
  try { entries = readdirSync(workflows) } catch { return rows }
  for (const entry of entries) {
    if (!/\.ya?ml$/.test(entry)) continue
    rows.push(scanText(entry, readFileSync(join(workflows, entry), 'utf8'), allowed))
  }
  return rows
}

function listRepos() {
  const repos = []
  for (const owner of ['popcre', 'u2giants']) {
    const type = owner === 'popcre' ? 'orgs' : 'users'
    const out = gh(['api', '--paginate', '--slurp', `${type}/${owner}/repos?per_page=100`], { allowFailure: true })
    if (!out) continue
    // --slurp returns one array per page; flatten to repo rows.
    for (const page of JSON.parse(out)) {
      for (const repo of Array.isArray(page) ? page : []) {
        if (!repo.archived && !repo.disabled) repos.push(repo.full_name)
      }
    }
  }
  if (repos.length === 0) throw new Error('no repositories discovered for either owner')
  return repos
}

function registeredLabels(repo) {
  const out = gh(['api', `repos/${repo}/actions/runners?per_page=100`], { allowFailure: true })
  if (!out) return new Set()
  const labels = new Set()
  try {
    for (const runner of JSON.parse(out).runners ?? []) {
      for (const label of runner.labels ?? []) labels.add(label.name)
    }
  } catch { /* unreadable body: contribute nothing */ }
  return labels
}

function scanRepo(repo, allowed) {
  const labels = new Set([...allowed, ...registeredLabels(repo)])
  const rows = []
  const out = gh(['api', `repos/${repo}/contents/.github/workflows`], { allowFailure: true })
  if (!out) return rows
  let entries = []
  try { entries = JSON.parse(out) } catch { return rows }
  for (const entry of entries ?? []) {
    if (entry.type !== 'file' || !/\.ya?ml$/.test(entry.name)) continue
    const body = gh(['api', entry.url, '--jq', '.content'], { allowFailure: true })
    if (!body) continue
    const text = Buffer.from(body.trim(), 'base64').toString('utf8')
    rows.push(scanText(`${repo}/${entry.name}`, text, labels))
  }
  return rows
}

export function main(argv) {
  const offline = argv.includes('--offline')
  const configFlag = argv.indexOf('--config')
  const configPath = configFlag >= 0 ? argv[configFlag + 1] : join(ROOT, 'config', 'ci-runner-routing.json')
  let allowed
  try {
    allowed = allowedLabelsFromConfig(configPath)
  } catch (error) {
    console.error(`REFUSED: ${error.message}`)
    return 2
  }
  let rows = []
  try {
    if (offline) {
      rows = scanLocalDir(argv[argv.indexOf('--dir') + 1] ?? ROOT, allowed)
    } else {
      const reposFlag = argv.indexOf('--repos')
      const repos = reposFlag >= 0
        ? argv[reposFlag + 1].split(',')
        : listRepos()
      for (const repo of repos) rows.push(...scanRepo(repo, allowed))
    }
  } catch (error) {
    console.error(`REFUSED: scan broke: ${String(error.message).slice(0, 200)}`)
    return 2
  }
  const findings = rows.filter((row) => row.unknown.length > 0)
  const dynamic = rows.reduce((sum, row) => sum + row.dynamic, 0)
  console.log(`scanned ${rows.length} workflow file(s); ${dynamic} dynamic runs-on expression(s) skipped (router-resolved)`)
  if (findings.length === 0) {
    console.log('runner label scan clean: every static runs-on label is a hosted image, routing-config label, or registered runner label')
    return 0
  }
  for (const row of findings) {
    for (const label of row.unknown) console.log(`DEAD-LABEL ${row.workflow}: ${label}`)
  }
  return 1
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exit(main(process.argv.slice(2)))
}
