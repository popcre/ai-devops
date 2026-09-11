#!/usr/bin/env node
import { createHash } from 'node:crypto'
import { readFileSync } from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

export class PreviewClassificationError extends Error {}
export const CLASSIFIER_VERSION = 1
export const NO_PREVIEW_IMPACTS = Object.freeze([
  'documentation', 'reviewer-tooling', 'ci-workflow', 'read-only-test', 'application-only',
])
export const PREVIEW_REQUIRED_IMPACTS = Object.freeze([
  'database-structure', 'database-behavior', 'database-permission', 'database-data', 'generated', 'ambiguous',
])

const sha256 = (value) => createHash('sha256').update(value).digest('hex')
const canonical = (value) => Array.isArray(value)
  ? `[${value.map(canonical).join(',')}]`
  : value && typeof value === 'object'
    ? `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonical(value[key])}`).join(',')}}`
    : JSON.stringify(value)

export function classifyDatabasePreview(manifest, { root = process.cwd(), readFile = readFileSync } = {}) {
  if (!manifest || manifest.schema_version !== 1 || !Array.isArray(manifest.files) || !manifest.files.length) {
    throw new PreviewClassificationError('a schema-version-1 manifest with at least one file is required')
  }
  if (!Array.isArray(manifest.applicable_checks) || !manifest.applicable_checks.length) {
    throw new PreviewClassificationError('applicable non-database checks are required')
  }
  const seen = new Set()
  const files = manifest.files.map((entry) => {
    if (!entry || typeof entry.path !== 'string' || path.isAbsolute(entry.path) || entry.path.includes('..')) {
      throw new PreviewClassificationError('every inspected path must be repository-relative and safe')
    }
    const normalizedPath = entry.path.replaceAll('\\', '/')
    if (seen.has(normalizedPath)) throw new PreviewClassificationError(`duplicate inspected path: ${normalizedPath}`)
    seen.add(normalizedPath)
    const allowed = [...NO_PREVIEW_IMPACTS, ...PREVIEW_REQUIRED_IMPACTS]
    const impact = allowed.includes(entry.impact) ? entry.impact : 'ambiguous'
    if (typeof entry.reason !== 'string' || !entry.reason.trim()) throw new PreviewClassificationError(`missing impact reason for ${normalizedPath}`)
    let bytes
    try { bytes = readFile(path.resolve(root, normalizedPath)) } catch { throw new PreviewClassificationError(`inspected file is unreadable: ${normalizedPath}`) }
    const digest = sha256(bytes)
    if (entry.sha256 !== digest) throw new PreviewClassificationError(`content digest changed for ${normalizedPath}`)
    return { path: normalizedPath, sha256: digest, impact, reason: entry.reason.trim() }
  }).sort((a, b) => a.path.localeCompare(b.path))
  const applicableChecks = [...new Set(manifest.applicable_checks.map(String))].sort()
  if (applicableChecks.some((check) => !check.trim())) throw new PreviewClassificationError('applicable checks must be non-empty')
  const required = files.filter((file) => PREVIEW_REQUIRED_IMPACTS.includes(file.impact))
  const inspectedDigest = sha256(canonical({ classifier_version: CLASSIFIER_VERSION, files, applicable_checks: applicableChecks }))
  return {
    schema_version: 1,
    decision: required.length ? 'DATABASE_PREVIEW_REQUIRED' : 'NO_DATABASE_PREVIEW',
    reason_code: required.length ? `impact_${required[0].impact.replaceAll('-', '_')}` : 'proven_non_database_change',
    inspected_digest: inspectedDigest,
    files,
    applicable_checks: applicableChecks,
    invalidated_by: ['file-content-change', 'file-set-change', 'impact-evidence-change', 'applicable-check-change', 'classifier-version-change'],
  }
}

export function main(argv) {
  const index = argv.indexOf('--manifest')
  if (index < 0 || !argv[index + 1]) { console.error('REFUSED: --manifest <json> is required'); return 2 }
  try {
    const manifest = JSON.parse(readFileSync(argv[index + 1], 'utf8'))
    console.log(JSON.stringify(classifyDatabasePreview(manifest), null, 2))
    return 0
  } catch (error) {
    console.error(`REFUSED: ${error.message}`)
    return 2
  }
}

if (process.argv[1] && path.resolve(fileURLToPath(import.meta.url)) === path.resolve(process.argv[1])) process.exitCode = main(process.argv.slice(2))
