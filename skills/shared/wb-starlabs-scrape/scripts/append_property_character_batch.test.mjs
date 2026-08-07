import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { appendPropertyCharacterBatch } from './append_property_character_batch.mjs';

test('appends exact property-character links once', () => {
  const repoPath = fs.mkdtempSync(path.join(os.tmpdir(), 'warner-property-character-'));
  const base = path.join(repoPath, 'warner-bros');
  fs.mkdirSync(base);
  fs.writeFileSync(path.join(base, 'characters.csv'), 'source_term,source_id,label,visible_asset_count,captured_date,source_url\n');
  fs.writeFileSync(path.join(base, 'franchise-properties.csv'), 'source_term,source_id,label,visible_asset_count,captured_date,source_url\n');
  const batch = {
    repoPath,
    capturedAt: '2026-08-07T20:30:00Z',
    sourceUrl: 'https://example.test/product',
    properties: [{ id: 'property-1', label: 'Example Property', characters: [{ id: 'character-1', label: 'Example Character' }] }],
  };
  assert.deepEqual(appendPropertyCharacterBatch(batch), { links: 1, characters: 1, properties: 1 });
  assert.deepEqual(appendPropertyCharacterBatch(batch), { links: 0, characters: 0, properties: 0 });
  assert.equal(fs.readFileSync(path.join(base, 'links-property-character.csv'), 'utf8').trim().split(/\r?\n/).length, 2);
});
