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
      } else if (char === '"') quoted = false;
      else cell += char;
    } else if (char === '"') quoted = true;
    else if (char === ',') {
      row.push(cell);
      cell = '';
    } else if (char === '\n') {
      row.push(cell.replace(/\r$/, ''));
      if (row.some((value) => value !== '')) rows.push(row);
      row = [];
      cell = '';
    } else cell += char;
  }
  if (cell || row.length) {
    row.push(cell.replace(/\r$/, ''));
    rows.push(row);
  }
  return rows;
}

function loadRows(filePath) {
  if (!fs.existsSync(filePath)) return [];
  return parseCsv(fs.readFileSync(filePath, 'utf8')).slice(1);
}

function appendRows(filePath, header, rows) {
  if (!fs.existsSync(filePath)) fs.writeFileSync(filePath, `${header}\n`, 'utf8');
  if (!rows.length) return;
  const prefix = fs.readFileSync(filePath, 'utf8').endsWith('\n') ? '' : '\n';
  fs.appendFileSync(filePath, prefix + rows.map((row) => row.map(csvCell).join(',')).join('\n') + '\n', 'utf8');
}

export function appendPropertyCharacterBatch({ repoPath, properties, capturedAt, sourceUrl }) {
  const base = path.join(repoPath, 'warner-bros');
  const linksPath = path.join(base, 'links-property-character.csv');
  const charactersPath = path.join(base, 'characters.csv');
  const propertiesPath = path.join(base, 'franchise-properties.csv');
  const existingLinks = new Set(loadRows(linksPath).map((row) => `${row[0]}\0${row[2]}`));
  const existingCharacterIds = new Set(loadRows(charactersPath).map((row) => row[1]).filter(Boolean));
  const existingPropertyIds = new Set(loadRows(propertiesPath).map((row) => row[1]).filter(Boolean));
  const linkRows = [];
  const characterRows = [];
  const propertyRows = [];

  for (const property of properties) {
    if (!property.id || !property.label) continue;
    if (!existingPropertyIds.has(property.id)) {
      propertyRows.push(['Property', property.id, property.label, '', capturedAt.slice(0, 10), sourceUrl]);
      existingPropertyIds.add(property.id);
    }
    for (const character of property.characters || []) {
      if (!character.id || !character.label) continue;
      const key = `${property.id}\0${character.id}`;
      if (!existingLinks.has(key)) {
        linkRows.push([property.id, property.label, character.id, character.label, 'false', capturedAt, sourceUrl]);
        existingLinks.add(key);
      }
      if (!existingCharacterIds.has(character.id)) {
        characterRows.push(['Character', character.id, character.label, '', capturedAt.slice(0, 10), sourceUrl]);
        existingCharacterIds.add(character.id);
      }
    }
  }

  appendRows(linksPath, 'property_source_id,property_label,character_source_id,character_label,id_fallback,captured_at,source_url', linkRows);
  appendRows(charactersPath, '', characterRows);
  appendRows(propertiesPath, '', propertyRows);
  return { links: linkRows.length, characters: characterRows.length, properties: propertyRows.length };
}
