import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { appendArtAssetBatch } from './append_art_asset_batch.mjs';

const headers = {
  'assets.csv': 'asset_source_id,file_name,source_path,season,property_labels,franchise_labels,style_guide_source_id,style_guide_natural_key,character_labels,modified_date,created_date,captured_date,source_url,warner_asset_id,file_size_bytes\n',
  'characters.csv': 'source_term,source_id,label,visible_asset_count,captured_date,source_url\n',
  'franchise-properties.csv': 'source_term,source_id,label,visible_asset_count,captured_date,source_url\n',
  'style-guides.csv': 'source_term,source_id,label,visible_asset_count,captured_date,source_url\n',
  'links-asset-character.csv': 'asset_source_id,file_name,character_source_id,character_label,captured_date,source_url\n',
  'links-asset-franchise-property.csv': 'asset_source_id,file_name,franchise_property_source_id,franchise_property_label,captured_date,source_url\n',
  'links-asset-style-guide.csv': 'asset_source_id,file_name,style_guide_source_id,style_guide_natural_key,captured_date,source_url\n',
};

function makeRepo() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'warner-collector-'));
  const base = path.join(root, 'warner-bros');
  fs.mkdirSync(base);
  for (const [name, header] of Object.entries(headers)) fs.writeFileSync(path.join(base, name), header);
  return root;
}

test('appends allowed metadata and exact links once', () => {
  const repoPath = makeRepo();
  const batch = {
    repoPath,
    capturedDate: '2026-08-07',
    sourceUrl: 'https://example.test/search',
    assets: [{
      assetSourceId: 'asset-1', fileName: 'file.ext', sourcePath: '/safe/path', fileSizeBytes: '42',
      properties: [{ id: 'property-1', label: 'Property' }],
      franchises: [{ id: 'franchise-1', label: 'Franchise' }],
      characters: [{ id: 'character-1', label: 'Character' }],
      styleGuideNaturalKey: 'Guide',
    }],
  };
  const first = appendArtAssetBatch(batch);
  const second = appendArtAssetBatch(batch);
  assert.deepEqual(first, { assets: 1, assetCharacters: 1, assetProperties: 2, assetStyleGuides: 1, characters: 1, properties: 2, styleGuides: 1 });
  assert.deepEqual(second, { assets: 0, assetCharacters: 0, assetProperties: 0, assetStyleGuides: 0, characters: 0, properties: 0, styleGuides: 0 });
  assert.match(fs.readFileSync(path.join(repoPath, 'warner-bros', 'assets.csv'), 'utf8'), /"file.ext"/);
});
