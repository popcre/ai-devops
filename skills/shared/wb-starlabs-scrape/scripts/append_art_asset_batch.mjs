import fs from 'node:fs';
import path from 'node:path';

function csvCell(value) {
  const text = value == null ? '' : String(value);
  return `"${text.replaceAll('"', '""')}"`;
}

function parseCsv(text) {
  const rows = [];
  let row = [];
  let cell = '';
  let quoted = false;
  for (let i = 0; i < text.length; i += 1) {
    const char = text[i];
    if (quoted) {
      if (char === '"' && text[i + 1] === '"') {
        cell += '"';
        i += 1;
      } else if (char === '"') {
        quoted = false;
      } else {
        cell += char;
      }
    } else if (char === '"') {
      quoted = true;
    } else if (char === ',') {
      row.push(cell);
      cell = '';
    } else if (char === '\n') {
      row.push(cell.replace(/\r$/, ''));
      if (row.some((value) => value !== '')) rows.push(row);
      row = [];
      cell = '';
    } else {
      cell += char;
    }
  }
  if (cell || row.length) {
    row.push(cell.replace(/\r$/, ''));
    rows.push(row);
  }
  return rows;
}

function loadTable(filePath) {
  const rows = parseCsv(fs.readFileSync(filePath, 'utf8'));
  return { header: rows[0], rows: rows.slice(1) };
}

function appendRows(filePath, rows) {
  if (!rows.length) return;
  const prefix = fs.readFileSync(filePath, 'utf8').endsWith('\n') ? '' : '\n';
  fs.appendFileSync(
    filePath,
    prefix + rows.map((row) => row.map(csvCell).join(',')).join('\n') + '\n',
    'utf8',
  );
}

function uniqueBy(rows, key) {
  const seen = new Set();
  return rows.filter((row) => {
    const value = key(row);
    if (seen.has(value)) return false;
    seen.add(value);
    return true;
  });
}

export function appendArtAssetBatch({ repoPath, assets, capturedDate, sourceUrl }) {
  const base = path.join(repoPath, 'warner-bros');
  const files = {
    assets: path.join(base, 'assets.csv'),
    characters: path.join(base, 'characters.csv'),
    properties: path.join(base, 'franchise-properties.csv'),
    styleGuides: path.join(base, 'style-guides.csv'),
    assetCharacters: path.join(base, 'links-asset-character.csv'),
    assetProperties: path.join(base, 'links-asset-franchise-property.csv'),
    assetStyleGuides: path.join(base, 'links-asset-style-guide.csv'),
  };

  const existing = Object.fromEntries(
    Object.entries(files).map(([name, filePath]) => [name, loadTable(filePath)]),
  );
  const existingAssetIds = new Set(existing.assets.rows.map((row) => row[0]));
  const existingCharacterLinks = new Set(existing.assetCharacters.rows.map((row) => `${row[0]}\0${row[2] || row[3]}`));
  const existingPropertyLinks = new Set(existing.assetProperties.rows.map((row) => `${row[0]}\0${row[2] || row[3]}`));
  const existingStyleLinks = new Set(existing.assetStyleGuides.rows.map((row) => `${row[0]}\0${row[2] || row[3]}`));
  const existingCharacterIds = new Set(existing.characters.rows.map((row) => row[1]).filter(Boolean));
  const existingPropertyIds = new Set(existing.properties.rows.map((row) => row[1]).filter(Boolean));
  const existingStyleKeys = new Set(existing.styleGuides.rows.map((row) => row[1] || row[2]).filter(Boolean));

  const assetRows = [];
  const characterLinkRows = [];
  const propertyLinkRows = [];
  const styleLinkRows = [];
  const characterRows = [];
  const propertyRows = [];
  const styleRows = [];

  for (const asset of assets) {
    if (!asset.assetSourceId || !asset.fileName) continue;
    const properties = asset.properties || [];
    const franchises = asset.franchises || [];
    const characters = asset.characters || [];
    if (!existingAssetIds.has(asset.assetSourceId)) {
      assetRows.push([
        asset.assetSourceId,
        asset.fileName,
        asset.sourcePath || '',
        asset.season || '',
        JSON.stringify(properties.map((item) => item.label)),
        JSON.stringify(franchises.map((item) => item.label)),
        asset.styleGuideSourceId || '',
        asset.styleGuideNaturalKey || '',
        JSON.stringify(characters.map((item) => item.label)),
        asset.modifiedDate || '',
        asset.createdDate || '',
        capturedDate,
        sourceUrl,
        asset.warnerAssetId || '',
        asset.fileSizeBytes || '',
      ]);
      existingAssetIds.add(asset.assetSourceId);
    }

    for (const item of characters) {
      if (!item.label) continue;
      const linkKey = `${asset.assetSourceId}\0${item.id || item.label}`;
      if (!existingCharacterLinks.has(linkKey)) {
        characterLinkRows.push([asset.assetSourceId, asset.fileName, item.id || '', item.label, capturedDate, sourceUrl]);
        existingCharacterLinks.add(linkKey);
      }
      if (item.id && !existingCharacterIds.has(item.id)) {
        characterRows.push(['Character', item.id, item.label, '', capturedDate, sourceUrl]);
        existingCharacterIds.add(item.id);
      }
    }

    for (const item of [...properties, ...franchises]) {
      if (!item.label) continue;
      const linkKey = `${asset.assetSourceId}\0${item.id || item.label}`;
      if (!existingPropertyLinks.has(linkKey)) {
        propertyLinkRows.push([asset.assetSourceId, asset.fileName, item.id || '', item.label, capturedDate, sourceUrl]);
        existingPropertyLinks.add(linkKey);
      }
      if (item.id && !existingPropertyIds.has(item.id)) {
        propertyRows.push(['Franchise / Property', item.id, item.label, '', capturedDate, sourceUrl]);
        existingPropertyIds.add(item.id);
      }
    }

    if (asset.styleGuideNaturalKey) {
      const styleKey = asset.styleGuideSourceId || asset.styleGuideNaturalKey;
      const linkKey = `${asset.assetSourceId}\0${styleKey}`;
      if (!existingStyleLinks.has(linkKey)) {
        styleLinkRows.push([
          asset.assetSourceId,
          asset.fileName,
          asset.styleGuideSourceId || '',
          asset.styleGuideNaturalKey,
          capturedDate,
          sourceUrl,
        ]);
        existingStyleLinks.add(linkKey);
      }
      if (!existingStyleKeys.has(styleKey)) {
        styleRows.push(['Style Guide', asset.styleGuideSourceId || '', asset.styleGuideNaturalKey, '', capturedDate, sourceUrl]);
        existingStyleKeys.add(styleKey);
      }
    }
  }

  const additions = {
    assets: uniqueBy(assetRows, (row) => row[0]),
    assetCharacters: uniqueBy(characterLinkRows, (row) => `${row[0]}\0${row[2] || row[3]}`),
    assetProperties: uniqueBy(propertyLinkRows, (row) => `${row[0]}\0${row[2] || row[3]}`),
    assetStyleGuides: uniqueBy(styleLinkRows, (row) => `${row[0]}\0${row[2] || row[3]}`),
    characters: uniqueBy(characterRows, (row) => row[1]),
    properties: uniqueBy(propertyRows, (row) => row[1]),
    styleGuides: uniqueBy(styleRows, (row) => row[1] || row[2]),
  };

  for (const [name, rows] of Object.entries(additions)) appendRows(files[name], rows);
  return Object.fromEntries(Object.entries(additions).map(([name, rows]) => [name, rows.length]));
}
