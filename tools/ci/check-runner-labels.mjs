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
// The advisory workflow reports findings through the scheduled-failure reporter.
// Missing coverage is visible but never reported as a dead label. Exit codes:
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
const HOSTED_LABEL = /^(?:ubuntu-(?:latest|slim|\d{2}\.\d{2}(?:-arm)?)|windows-(?:latest|\d{2,4}(?:-vs\d{4})?(?:-arm)?)|macos-(?:latest|\d{2,3}(?:-arm64|-m1|-intel)?)|xcode-\d{2,3})$/i
// Baseline self-hosted labels every runner carries or that are structural.
const BASELINE_LABELS = new Set([
  'self-hosted', 'linux', 'windows', 'macos', 'x64', 'arm64',
])
// Dynamic matrix routing is resolved by the router, not by this scan.
const DYNAMIC = '${{'
const TOOLKIT_REPO = 'popcre/ai-devops'
const ROUTING_SCALARS = [
  'candidate_label', 'qualified_label', 'section_label', 'paused_label',
  'linux_label', 'hosted_windows', 'hosted_linux', 'warpbuild_windows',
]
const ROUTING_ARRAYS = ['qualified_windows', 'section_windows', 'linux_self_hosted']

function gh(args, { runnerInventory = false, missingAllowed = false } = {}) {
  const token = runnerInventory && process.env.RUNNER_POOL_READ_TOKEN
  try {
    return execFileSync('gh', args, {
      encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'],
      env: token ? { ...process.env, GH_TOKEN: token } : process.env,
      timeout: 30_000, maxBuffer: 16 * 1024 * 1024,
    })
  } catch (error) {
    const status = String(error.stderr ?? '').match(/\bHTTP (\d{3})\b/)?.[1]
    if (missingAllowed && status === '404') return null
    throw new Error(status ? `GitHub returned HTTP ${status}` : 'GitHub request failed')
  }
}

export function allowedLabelsFromConfig(configPath) {
  const labels = new Set()
  const config = JSON.parse(readFileSync(configPath, 'utf8'))
  if (!config || typeof config !== 'object' || Array.isArray(config)) {
    throw new Error('invalid runner routing config')
  }
  for (const key of ROUTING_SCALARS) {
    if (key in config) {
      if (typeof config[key] !== 'string' || !config[key]) throw new Error(`invalid ${key}`)
      labels.add(config[key].toLowerCase())
    }
  }
  for (const key of ROUTING_ARRAYS) {
    if (key in config) {
      if (!Array.isArray(config[key]) || config[key].some((label) => typeof label !== 'string' || !label)) {
        throw new Error(`invalid ${key}`)
      }
      for (const label of config[key]) {
        if (!BASELINE_LABELS.has(label.toLowerCase())) labels.add(label.toLowerCase())
      }
    }
  }
  return labels
}

export function runsOnLabels(workflowText) {
  const labels = []
  let dynamic = 0
  const lines = workflowText.split(/\r?\n/).map((line) => line.replace(/\s+#.*$/, ''))
  for (let i = 0; i < lines.length; i += 1) {
    const match = /^(\s*)runs-on:\s*(.*?)\s*$/.exec(lines[i])
    if (!match) continue
    let value = match[2]
    const sequence = []
    if (!value) {
      while (i + 1 < lines.length) {
        const next = /^(\s*)(.*)$/.exec(lines[i + 1])
        if (next[2] && next[1].length <= match[1].length && !next[2].startsWith('- ')) break
        i += 1
        if (next[2].startsWith('- ')) sequence.push(next[2].slice(2))
        if (next[2].startsWith('labels:')) value = next[2].slice('labels:'.length).trim()
      }
    }
    const inline = value.replace(/\$\{\{.*?\}\}/g, DYNAMIC)
    const parts = inline.startsWith('[') ? inline.slice(1, -1).split(',') : [inline, ...sequence]
    const staticLabels = parts.map((part) => part.trim().replace(/^['"]|['"]$/g, '')).filter(Boolean)
    if (staticLabels.some((label) => label.includes(DYNAMIC))) dynamic += 1
    const selfHosted = staticLabels.some((label) => label.toLowerCase() === 'self-hosted')
    for (const label of staticLabels) {
      if (label.includes(DYNAMIC)) continue
      if (selfHosted && BASELINE_LABELS.has(label.toLowerCase())) continue
      labels.push(label)
    }
  }
  return { labels, dynamic }
}

function scanText(name, text, allowed) {
  const { labels, dynamic } = runsOnLabels(text)
  const unknown = [...new Set(labels)].filter((label) => !allowed.has(label.toLowerCase()) && !HOSTED_LABEL.test(label))
  return { workflow: name, unknown, dynamic }
}

function scanLocalDir(dir, allowed) {
  const rows = []
  const workflows = join(dir, '.github', 'workflows')
  for (const entry of readdirSync(workflows)) {
    if (!/\.ya?ml$/.test(entry)) continue
    rows.push(scanText(entry, readFileSync(join(workflows, entry), 'utf8'), allowed))
  }
  if (!rows.length) throw new Error('no workflow files found in the local scan')
  return rows
}

function listRepos(unverified) {
  const repos = new Set()
  for (const owner of ['popcre', 'u2giants']) {
    const type = owner === 'popcre' ? 'orgs' : 'users'
    try {
      const pages = JSON.parse(gh(['api', '--paginate', '--slurp', `${type}/${owner}/repos?per_page=100`]))
      if (!Array.isArray(pages) || !pages.every(Array.isArray)) throw new Error('invalid repository list')
      for (const repo of pages.flat()) {
        if (!repo.archived && !repo.disabled) repos.add(repo.full_name)
      }
    } catch (error) {
      unverified.push(`${owner}: repository discovery unavailable (${error.message})`)
    }
  }
  return repos
}

function registeredLabels(repo) {
  const out = gh(['api', '--paginate', '--slurp', `repos/${repo}/actions/runners?per_page=100`], {
    runnerInventory: repo === TOOLKIT_REPO,
  })
  const pages = JSON.parse(out)
  if (!Array.isArray(pages) || !pages.length || !pages.every((page) => Array.isArray(page.runners))) {
    throw new Error('invalid runner inventory')
  }
  return new Set(pages.flatMap((page) =>
    page.runners.flatMap((runner) => runner.labels.map((label) => label.name.toLowerCase()))))
}

function scanRepo(repo, allowed, unverified) {
  const rows = []
  const endpoint = `repos/${repo}/contents`
  const out = gh(['api', `${endpoint}/.github/workflows`], { missingAllowed: true })
  if (out === null) {
    // A 404 can conceal denied access. Prove readable contents or no branches.
    if (gh(['api', endpoint], { missingAllowed: true }) === null) {
      const branches = JSON.parse(gh(['api', `repos/${repo}/branches?per_page=1`]))
      if (!Array.isArray(branches) || branches.length > 0) {
        throw new Error('cannot confirm the repository has no workflow files')
      }
    }
    return rows
  }
  const entries = JSON.parse(out)
  if (!Array.isArray(entries)) throw new Error('invalid workflow directory')
  for (const entry of entries) {
    if (entry.type !== 'file' || !/\.ya?ml$/.test(entry.name)) continue
    try {
      const body = JSON.parse(gh(['api', `${endpoint}/.github/workflows/${encodeURIComponent(entry.name)}`]))
      if (body.encoding !== 'base64' || typeof body.content !== 'string') throw new Error('invalid workflow content')
      const text = Buffer.from(body.content, 'base64').toString('utf8')
      rows.push(scanText(`${repo}/${entry.name}`, text, allowed))
    } catch (error) {
      unverified.push(`${repo}/${entry.name}: workflow read unavailable (${error.message})`)
    }
  }
  if (repo === TOOLKIT_REPO || rows.some((row) => row.unknown.length)) {
    try {
      const labels = registeredLabels(repo)
      for (const row of rows) row.unknown = row.unknown.filter((label) => !labels.has(label.toLowerCase()))
    } catch (error) {
      unverified.push(`${repo}: runner inventory unavailable (${error.message})`)
      for (const row of rows) {
        for (const label of row.unknown) unverified.push(`${row.workflow}: could not verify label ${label}`)
        row.unknown = []
      }
    }
  }
  return rows
}

export function main(argv) {
  const offline = argv.includes('--offline')
  const option = (name, fallback) => {
    const index = argv.indexOf(name)
    if (index < 0) return fallback
    const value = argv[index + 1]
    if (!value || value.startsWith('--')) throw new Error(`missing value for ${name}`)
    return value
  }
  const unverified = []
  let rows = []
  try {
    const configPath = option('--config', join(ROOT, 'config', 'ci-runner-routing.json'))
    const allowed = allowedLabelsFromConfig(configPath)
    if (offline) {
      rows = scanLocalDir(option('--dir', ROOT), allowed)
    } else {
      const selected = option('--repos', null)
      const repos = selected ? selected.split(',') : listRepos(unverified)
      for (const repo of repos) {
        try {
          rows.push(...scanRepo(repo, repo === TOOLKIT_REPO ? allowed : new Set(), unverified))
        } catch (error) {
          unverified.push(`${repo}: workflow listing unavailable (${error.message})`)
        }
      }
    }
  } catch (error) {
    console.error(`REFUSED: scan broke: ${String(error.message).slice(0, 200)}`)
    return 2
  }
  const findings = rows.filter((row) => row.unknown.length > 0)
  const dynamic = rows.reduce((sum, row) => sum + row.dynamic, 0)
  console.log(`scanned ${rows.length} workflow file(s); ${dynamic} runs-on field(s) contained dynamic expressions`)
  for (const item of unverified) console.log(`UNVERIFIED ${item}`)
  if (findings.length === 0 && unverified.length === 0 && rows.length > 0) {
    console.log('runner label scan clean: every static runs-on label is a hosted image, routing-config label, or registered runner label')
    return 0
  }
  for (const row of findings) {
    for (const label of row.unknown) console.log(`DEAD-LABEL ${row.workflow}: ${label}`)
  }
  if (unverified.length || !rows.length) console.log('runner label scan incomplete')
  return findings.length ? 1 : 2
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exit(main(process.argv.slice(2)))
}
