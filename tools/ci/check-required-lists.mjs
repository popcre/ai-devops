#!/usr/bin/env node
// Step 3.5 (plan_ci-process-repair.md, #2367): compare each repo's live
// required-check list with the one list the 2026-10-30 ruling allows, on a
// schedule, so a silent reversal is detected within a day and reported
// through the ci-red route (findings fail this advisory job; the
// scheduled-failure reporter opens the owned issue).
//
// The 2026-10-30 incident: a session reverted shared-db's required list and
// it had to be reapplied by hand, silently. This check makes the reversal a
// named alarm instead.
//
// RESTORE: `--apply` writes the expected contexts back into the named
// ruleset, and ONLY the expected contexts. It is for a local session or the
// watchdog duty pool holding an administration token; the workflow itself
// runs compare-only (its token cannot write rulesets).
//
// Exit codes: 0 clean; 1 differences named; 2 the check broke.
import { execFileSync } from 'node:child_process'
import { readFileSync, writeFileSync, rmSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { tmpdir } from 'node:os'
import { fileURLToPath, pathToFileURL } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..')
const EXPECTED_PATH = join(ROOT, 'config', 'required-checks-expected.json')

function gh(args) {
  return execFileSync('gh', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] })
}

export function loadExpected(path = EXPECTED_PATH) {
  const config = JSON.parse(readFileSync(path, 'utf8'))
  if (config.schema_version !== 1 || !config.repos) throw new Error('expected-lists config is malformed')
  for (const [repo, row] of Object.entries(config.repos)) {
    if (!row.ruleset_name || !Array.isArray(row.required_contexts)) {
      throw new Error(`expected-lists entry for ${repo} is malformed`)
    }
  }
  return config.repos
}

export function compareRepo(repo, expected, rulesets) {
  const ruleset = (rulesets ?? []).find((row) => row.name === expected.ruleset_name)
  if (!ruleset) return { repo, missing_ruleset: true, differences: [`ruleset "${expected.ruleset_name}" not found`] }
  const contexts = []
  for (const rule of ruleset.rules ?? []) {
    if (rule.type !== 'required_status_checks') continue
    for (const entry of rule.parameters?.required_status_checks ?? []) contexts.push(entry.context)
  }
  const live = [...new Set(contexts)].sort()
  const wanted = [...new Set(expected.required_contexts)].sort()
  const differences = []
  for (const context of wanted) if (!live.includes(context)) differences.push(`missing required check: ${context}`)
  for (const context of live) if (!wanted.includes(context)) differences.push(`required check beyond the ruling's list: ${context}`)
  return { repo, ruleset_id: ruleset.id, live, differences }
}

function liveRulesets(repo) {
  // The list endpoint omits rule bodies; resolve each named ruleset in full.
  const listed = JSON.parse(gh(['api', `repos/${repo}/rulesets`]))
  return listed.map((row) => JSON.parse(gh(['api', `repos/${repo}/rulesets/${row.id}`])))
}

export function main(argv) {
  let expected
  try {
    expected = loadExpected(argv.includes('--expected') ? argv[argv.indexOf('--expected') + 1] : EXPECTED_PATH)
  } catch (error) {
    console.error(`REFUSED: ${error.message}`)
    return 2
  }
  const apply = argv.includes('--apply')
  const reports = []
  try {
    for (const [repo, row] of Object.entries(expected)) {
      reports.push(compareRepo(repo, row, liveRulesets(repo)))
    }
  } catch (error) {
    console.error(`REFUSED: live ruleset read broke: ${String(error.message).slice(0, 200)}`)
    return 2
  }
  let bad = 0
  for (const report of reports) {
    if (report.differences.length === 0) {
      console.log(`${report.repo}: required list matches the 2026-10-30 ruling (${report.live.length} check${report.live.length === 1 ? '' : 's'})`)
      continue
    }
    bad += 1
    for (const difference of report.differences) console.log(`REQUIRED-LIST-DRIFT ${report.repo}: ${difference}`)
    if (apply && !report.missing_ruleset) {
      // Write back exactly the expected contexts. The integration_id on each
      // existing entry is preserved where the context matches; new entries go
      // in without one (GitHub accepts a bare context).
      const ruleset = JSON.parse(gh(['api', `repos/${report.repo}/rulesets/${report.ruleset_id}`]))
      const kept = new Map()
      for (const rule of ruleset.rules ?? []) {
        if (rule.type !== 'required_status_checks') continue
        for (const entry of rule.parameters?.required_status_checks ?? []) kept.set(entry.context, entry.integration_id)
      }
      const wanted = expected[report.repo].required_contexts
      const updated = JSON.parse(JSON.stringify(ruleset))
      for (const rule of updated.rules ?? []) {
        if (rule.type !== 'required_status_checks') continue
        rule.parameters.required_status_checks = wanted.map((context) => (
          kept.has(context) ? { context, integration_id: kept.get(context) } : { context }
        ))
      }
      const temp = join(tmpdir(), `required-list-restore-${report.repo.replaceAll('/', '~')}.json`)
      writeFileSync(temp, JSON.stringify(updated))
      gh(['api', '-X', 'PUT', `repos/${report.repo}/rulesets/${report.ruleset_id}`, '--input', temp])
      rmSync(temp, { force: true })
      console.log(`RESTORED ${report.repo} to exactly the ruling's list (${wanted.length} checks)`)
    }
  }
  if (bad > 0) return 1
  console.log('required-list compare clean')
  return 0
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  process.exit(main(process.argv.slice(2)))
}
