#!/usr/bin/env node
import { createHash } from 'node:crypto'
import { execFileSync } from 'node:child_process'
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

export function classifyDatabasePreview(manifest, {
  root = process.cwd(),
  readFileAt = (ref, file) => execFileSync('git', ['show', `${ref}:${file}`], { cwd: root, maxBuffer: 16 * 1024 * 1024 }),
  modeAt = (ref, file) => execFileSync('git', ['ls-tree', ref, '--', file], { cwd: root, encoding: 'utf8', maxBuffer: 1024 * 1024 }).trim().split(/\s+/, 1)[0],
  isAncestor = (base, head) => { execFileSync('git', ['merge-base', '--is-ancestor', base, head], { cwd: root }); return true },
  listChangedFiles = (base, head) => execFileSync('git', ['diff', '--no-renames', '--name-only', '--diff-filter=ACMRD', `${base}...${head}`], { cwd: root, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 }).split(/\r?\n/).filter(Boolean),
  listDeletedFiles = (base, head) => execFileSync('git', ['diff', '--no-renames', '--name-only', '--diff-filter=D', `${base}...${head}`], { cwd: root, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 }).split(/\r?\n/).filter(Boolean),
} = {}) {
  if (!manifest || manifest.schema_version !== 1 || !Array.isArray(manifest.files) || !manifest.files.length) {
    throw new PreviewClassificationError('a schema-version-1 manifest with at least one file is required')
  }
  if (!Array.isArray(manifest.applicable_checks) || !manifest.applicable_checks.length) {
    throw new PreviewClassificationError('applicable non-database checks are required')
  }
  for (const field of ['base_sha', 'head_sha']) {
    if (!/^[0-9a-f]{40}$/i.test(manifest[field] ?? '')) throw new PreviewClassificationError(`${field} must be an exact commit SHA`)
  }
  try {
    if (isAncestor(manifest.base_sha, manifest.head_sha) !== true) throw new Error('not an ancestor')
  } catch { throw new PreviewClassificationError('base_sha is not a proved ancestor of head_sha') }
  let deletedFiles
  try { deletedFiles = new Set(listDeletedFiles(manifest.base_sha, manifest.head_sha).map((file) => file.replaceAll('\\', '/'))) }
  catch { throw new PreviewClassificationError('the deleted-file set is unreadable or truncated') }
  const seen = new Set()
  const files = manifest.files.map((entry) => {
    if (!entry || typeof entry.path !== 'string' || path.isAbsolute(entry.path) || entry.path.includes('..')) {
      throw new PreviewClassificationError('every inspected path must be repository-relative and safe')
    }
    const normalizedPath = entry.path.replaceAll('\\', '/')
    if (seen.has(normalizedPath)) throw new PreviewClassificationError(`duplicate inspected path: ${normalizedPath}`)
    seen.add(normalizedPath)
    const deleted = deletedFiles.has(normalizedPath)
    if (typeof entry.reason !== 'string' || !entry.reason.trim()) throw new PreviewClassificationError(`missing impact reason for ${normalizedPath}`)
    const sourceRef = deleted ? manifest.base_sha : manifest.head_sha
    let bytes, mode
    try { bytes = readFileAt(sourceRef, normalizedPath); mode = modeAt(sourceRef, normalizedPath) }
    catch { throw new PreviewClassificationError(`inspected file is unreadable: ${normalizedPath}`) }
    const digest = sha256(bytes)
    if (entry.sha256 !== digest) throw new PreviewClassificationError(`content digest changed for ${normalizedPath}`)
    const text = Buffer.from(bytes).toString('utf8')
    const databaseSignal = /(?:\b(?:create|alter|drop|grant|revoke|insert|update|delete)\b[\s\S]{0,40}\b(?:table|view|function|policy|role|schema|into|from)\b|\bsupabase\b|\bpsql\b|\bapply_migration\b|\bdb\s+push\b)/i.test(text)
    const databasePath = /(?:^|\/)(?:supabase|migrations?|policies)(?:\/|$)|\.sql$/i.test(normalizedPath)
    const safeDocumentation = /(?:^|\/)(?:docs\/.*|HANDOFF\.d\/.*|plan_[^/]*|README)\.(?:md|txt)$/i.test(normalizedPath) || /\.txt$/i.test(normalizedPath)
    let impact = 'ambiguous'
    if (deleted || !['100644', '100755'].includes(mode)) impact = 'ambiguous'
    else if (databaseSignal || databasePath) impact = 'database-behavior'
    else if (entry.impact === 'documentation' && safeDocumentation) impact = 'documentation'
    else if (entry.impact === 'reviewer-tooling' && /^(?:bin\/ai-(?:review|reviewer)|tools\/reviewer_)/.test(normalizedPath)) impact = 'reviewer-tooling'
    else if (PREVIEW_REQUIRED_IMPACTS.includes(entry.impact)) impact = entry.impact
    return { path: normalizedPath, sha256: digest, mode, impact, reason: entry.reason.trim(), change_type: deleted ? 'deleted' : 'present' }
  }).sort((a, b) => a.path.localeCompare(b.path))
  let changedFiles
  try { changedFiles = listChangedFiles(manifest.base_sha, manifest.head_sha).map((file) => file.replaceAll('\\', '/')).sort() }
  catch { throw new PreviewClassificationError('the complete changed-file set is unreadable or truncated') }
  if (!changedFiles.length || new Set(changedFiles).size !== changedFiles.length) throw new PreviewClassificationError('the complete changed-file set is empty or invalid')
  const declaredFiles = files.map((file) => file.path)
  if (canonical(changedFiles) !== canonical(declaredFiles)) throw new PreviewClassificationError('manifest files do not exactly match the complete changed-file set')
  const applicableChecks = [...new Set(manifest.applicable_checks.map(String))].sort()
  if (applicableChecks.some((check) => !check.trim())) throw new PreviewClassificationError('applicable checks must be non-empty')
  const required = files.filter((file) => PREVIEW_REQUIRED_IMPACTS.includes(file.impact))
  const inspectedDigest = sha256(canonical({ classifier_version: CLASSIFIER_VERSION, base_sha: manifest.base_sha.toLowerCase(), head_sha: manifest.head_sha.toLowerCase(), files, applicable_checks: applicableChecks }))
  return {
    schema_version: 1,
    decision: required.length ? 'DATABASE_PREVIEW_REQUIRED' : 'NO_DATABASE_PREVIEW',
    reason_code: required.length ? `impact_${required[0].impact.replaceAll('-', '_')}` : 'proven_non_database_change',
    base_sha: manifest.base_sha.toLowerCase(),
    head_sha: manifest.head_sha.toLowerCase(),
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
