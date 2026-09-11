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
  return { root, manifest: { schema_version: 1, applicable_checks: ['unit-tests'], files: [{ path: 'change.txt', sha256: sha256(content), impact, reason: `proved ${impact}` }] } }
}

for (const impact of ['documentation', 'reviewer-tooling', 'ci-workflow', 'read-only-test', 'application-only']) {
  test(`${impact} can explicitly prove no database preview`, () => {
    const { root, manifest } = fixture(impact)
    const result = classifyDatabasePreview(manifest, { root })
    assert.equal(result.decision, 'NO_DATABASE_PREVIEW')
    assert.equal(result.reason_code, 'proven_non_database_change')
    assert.ok(result.applicable_checks.includes('unit-tests'))
  })
}

for (const impact of ['database-structure', 'database-behavior', 'database-permission', 'database-data', 'generated', 'ambiguous']) {
  test(`${impact} requires database preview`, () => {
    const { root, manifest } = fixture(impact)
    assert.equal(classifyDatabasePreview(manifest, { root }).decision, 'DATABASE_PREVIEW_REQUIRED')
  })
}

test('unknown impact fails safely to preview required', () => {
  const { root, manifest } = fixture('invented-exemption')
  assert.equal(classifyDatabasePreview(manifest, { root }).decision, 'DATABASE_PREVIEW_REQUIRED')
})

test('changed bytes invalidate a prior manifest', () => {
  const { root, manifest } = fixture('documentation')
  writeFileSync(path.join(root, 'change.txt'), 'changed\n')
  assert.throws(() => classifyDatabasePreview(manifest, { root }), /content digest changed/)
})

test('missing checks, reasons, files, and duplicate paths refuse', () => {
  const { root, manifest } = fixture('documentation')
  assert.throws(() => classifyDatabasePreview({ ...manifest, applicable_checks: [] }, { root }), PreviewClassificationError)
  assert.throws(() => classifyDatabasePreview({ ...manifest, files: [{ ...manifest.files[0], reason: '' }] }, { root }), PreviewClassificationError)
  assert.throws(() => classifyDatabasePreview({ ...manifest, files: [] }, { root }), PreviewClassificationError)
  assert.throws(() => classifyDatabasePreview({ ...manifest, files: [manifest.files[0], manifest.files[0]] }, { root }), /duplicate inspected path/)
})

test('classification is deterministic across file and check ordering', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'preview-classifier-'))
  writeFileSync(path.join(root, 'a.txt'), 'a')
  writeFileSync(path.join(root, 'b.txt'), 'b')
  const files = [
    { path: 'a.txt', sha256: sha256('a'), impact: 'documentation', reason: 'prose' },
    { path: 'b.txt', sha256: sha256('b'), impact: 'read-only-test', reason: 'no mutation' },
  ]
  const first = classifyDatabasePreview({ schema_version: 1, files, applicable_checks: ['lint', 'test'] }, { root })
  const second = classifyDatabasePreview({ schema_version: 1, files: [...files].reverse(), applicable_checks: ['test', 'lint'] }, { root })
  assert.equal(first.inspected_digest, second.inspected_digest)
})
