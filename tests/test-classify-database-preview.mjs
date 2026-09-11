import test from 'node:test'
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { mkdtempSync, writeFileSync } from 'node:fs'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { classifyDatabasePreview, PreviewClassificationError } from '../tools/ci/classify-database-preview.mjs'

const sha256 = (value) => createHash('sha256').update(value).digest('hex')
const fixture = (impact, content = 'safe fixture\n') => {
  const root = mkdtempSync(path.join(tmpdir(), 'preview-classifier-'))
  writeFileSync(path.join(root, 'change.txt'), content)
  const manifest = { schema_version: 1, base_sha: 'a'.repeat(40), head_sha: 'b'.repeat(40), applicable_checks: ['unit-tests'], files: [{ path: 'change.txt', sha256: sha256(content), impact, reason: `proved ${impact}` }] }
  return { root, manifest, adapters: { root, isAncestor: () => true, listChangedFiles: () => manifest.files.map((file) => file.path), listDeletedFiles: () => [], readFileAt: () => Buffer.from(content), modeAt: () => '100644' } }
}

for (const impact of ['documentation']) {
  test(`${impact} can explicitly prove no database preview`, () => {
    const { manifest, adapters } = fixture(impact)
    const result = classifyDatabasePreview(manifest, adapters)
    assert.equal(result.decision, 'NO_DATABASE_PREVIEW')
    assert.equal(result.reason_code, 'proven_non_database_change')
    assert.ok(result.applicable_checks.includes('unit-tests'))
  })
}

for (const impact of ['reviewer-tooling', 'ci-workflow', 'read-only-test', 'application-only']) test(`${impact} requires deterministic path proof`, () => {
  const { manifest, adapters } = fixture(impact)
  assert.equal(classifyDatabasePreview(manifest, adapters).decision, 'DATABASE_PREVIEW_REQUIRED')
})

for (const impact of ['database-structure', 'database-behavior', 'database-permission', 'database-data', 'generated', 'ambiguous']) {
  test(`${impact} requires database preview`, () => {
    const { manifest, adapters } = fixture(impact)
    assert.equal(classifyDatabasePreview(manifest, adapters).decision, 'DATABASE_PREVIEW_REQUIRED')
  })
}

test('unknown impact fails safely to preview required', () => {
  const { manifest, adapters } = fixture('invented-exemption')
  assert.equal(classifyDatabasePreview(manifest, adapters).decision, 'DATABASE_PREVIEW_REQUIRED')
})

test('changed bytes invalidate a prior manifest', () => {
  const { root, manifest, adapters } = fixture('documentation')
  writeFileSync(path.join(root, 'change.txt'), 'changed\n')
  assert.throws(() => classifyDatabasePreview(manifest, { ...adapters, readFileAt: () => Buffer.from('changed\n') }), /content digest changed/)
})

test('missing checks, reasons, files, and duplicate paths refuse', () => {
  const { manifest, adapters } = fixture('documentation')
  assert.throws(() => classifyDatabasePreview({ ...manifest, applicable_checks: [] }, adapters), PreviewClassificationError)
  assert.throws(() => classifyDatabasePreview({ ...manifest, files: [{ ...manifest.files[0], reason: '' }] }, adapters), PreviewClassificationError)
  assert.throws(() => classifyDatabasePreview({ ...manifest, files: [] }, adapters), PreviewClassificationError)
  assert.throws(() => classifyDatabasePreview({ ...manifest, files: [manifest.files[0], manifest.files[0]] }, adapters), /duplicate inspected path/)
})

test('classification is deterministic across file and check ordering', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'preview-classifier-'))
  writeFileSync(path.join(root, 'a.txt'), 'a')
  writeFileSync(path.join(root, 'b.txt'), 'b')
  const files = [
    { path: 'a.txt', sha256: sha256('a'), impact: 'documentation', reason: 'prose' },
    { path: 'b.txt', sha256: sha256('b'), impact: 'read-only-test', reason: 'no mutation' },
  ]
  const base = { schema_version: 1, base_sha: 'a'.repeat(40), head_sha: 'b'.repeat(40), files, applicable_checks: ['lint', 'test'] }
  const adapters = { root, isAncestor: () => true, listChangedFiles: () => ['b.txt', 'a.txt'] }
  adapters.listDeletedFiles = () => []
  adapters.readFileAt = (_ref, file) => Buffer.from(file === 'a.txt' ? 'a' : 'b')
  adapters.modeAt = () => '100644'
  const first = classifyDatabasePreview(base, adapters)
  const second = classifyDatabasePreview({ ...base, files: [...files].reverse(), applicable_checks: ['test', 'lint'] }, adapters)
  assert.equal(first.inspected_digest, second.inspected_digest)
})

test('omitted, extra, non-ancestral, and unreadable changed-file evidence refuses', () => {
  const { manifest, adapters } = fixture('documentation')
  assert.throws(() => classifyDatabasePreview(manifest, { ...adapters, listChangedFiles: () => ['change.txt', 'hidden.sql'] }), /do not exactly match/)
  assert.throws(() => classifyDatabasePreview(manifest, { ...adapters, listChangedFiles: () => [] }), /empty or invalid/)
  assert.throws(() => classifyDatabasePreview(manifest, { ...adapters, isAncestor: () => false }), /not a proved ancestor/)
  assert.throws(() => classifyDatabasePreview(manifest, { ...adapters, listChangedFiles: () => { throw new Error('truncated') } }), /unreadable or truncated/)
})

test('deleted files are complete-diff inputs and always require preview', () => {
  const { root, manifest, adapters } = fixture('documentation', 'drop table core.customer;\n')
  manifest.files[0].path = 'deleted.sql'
  manifest.files[0].sha256 = sha256('drop table core.customer;\n')
  const deletionAdapters = {
    ...adapters,
    listChangedFiles: () => ['deleted.sql'],
    listDeletedFiles: () => ['deleted.sql'],
    readFileAt: () => Buffer.from('drop table core.customer;\n'),
    modeAt: () => '100644',
  }
  const result = classifyDatabasePreview(manifest, deletionAdapters)
  assert.equal(result.decision, 'DATABASE_PREVIEW_REQUIRED')
  assert.equal(result.files[0].change_type, 'deleted')
  assert.equal(result.files[0].impact, 'ambiguous')
  assert.throws(() => classifyDatabasePreview({ ...manifest, files: [] }, deletionAdapters), PreviewClassificationError)
})

test('exact Git bytes override dirty worktree bytes and database content cannot self-label safe', () => {
  const { root, manifest, adapters } = fixture('documentation', 'harmless prose\n')
  writeFileSync(path.join(root, 'change.txt'), 'dirty harmless bytes\n')
  manifest.files[0].sha256 = sha256('drop table core.customer;\n')
  const exact = { ...adapters, readFileAt: () => Buffer.from('drop table core.customer;\n') }
  assert.equal(classifyDatabasePreview(manifest, exact).decision, 'DATABASE_PREVIEW_REQUIRED')
})

test('symlinks, gitlinks, and renamed old paths fail safely to preview required', () => {
  const { manifest, adapters } = fixture('documentation')
  assert.equal(classifyDatabasePreview(manifest, { ...adapters, modeAt: () => '120000' }).decision, 'DATABASE_PREVIEW_REQUIRED')
  assert.equal(classifyDatabasePreview(manifest, { ...adapters, modeAt: () => '160000' }).decision, 'DATABASE_PREVIEW_REQUIRED')
  const renamed = { ...manifest, files: [manifest.files[0], { ...manifest.files[0], path: 'old.sql' }] }
  const renameAdapters = { ...adapters, listChangedFiles: () => ['change.txt', 'old.sql'], listDeletedFiles: () => ['old.sql'] }
  assert.equal(classifyDatabasePreview(renamed, renameAdapters).decision, 'DATABASE_PREVIEW_REQUIRED')
})
