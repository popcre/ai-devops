import fs from "node:fs";
import path from "node:path";

const root = process.argv[2];
if (!root) throw new Error("Usage: node consolidate-index.mjs <nbcu-directory>");

const indexDir = path.join(root, "raw", "index");
const partsDir = path.join(root, "raw", "index-parts");
const files = [
  ...(fs.existsSync(indexDir) ? fs.readdirSync(indexDir).map(name => path.join(indexDir, name)) : []),
  ...(fs.existsSync(partsDir) ? fs.readdirSync(partsDir).map(name => path.join(partsDir, name)) : []),
].filter(name => name.endsWith(".json"));

const scopes = new Map();
for (const file of files) {
  const data = JSON.parse(fs.readFileSync(file, "utf8"));
  const key = `${data.scope.label}\n${data.scope.href}`;
  const scope = scopes.get(key) ?? { ...data.scope, pages: new Map(), terminal: false, source_files: [] };
  scope.source_files.push(path.relative(root, file).replaceAll("\\", "/"));
  if (Array.isArray(data.assets)) {
    scope.pages.set(0, { offset: 0, status: 200, assets: data.assets });
    for (const page of data.pages ?? []) scope.pages.set(page.offset, { ...page, assets: [] });
    scope.terminal = true;
  } else {
    for (const page of data.pages ?? []) scope.pages.set(page.offset, page);
    scope.terminal ||= Boolean(data.terminal);
  }
  scopes.set(key, scope);
}

const globalAssets = new Map();
const scopeRows = [];
for (const scope of [...scopes.values()].sort((a, b) => a.label.localeCompare(b.label))) {
  const pages = [...scope.pages.values()].sort((a, b) => a.offset - b.offset);
  const local = new Map();
  for (const page of pages) {
    for (const asset of page.assets ?? []) {
      if (!local.has(asset.detail_href)) local.set(asset.detail_href, asset);
    }
  }
  const offsets = pages.map(page => page.offset);
  const missingOffsets = [];
  if (offsets.length) {
    for (let n = 0; n <= Math.max(...offsets); n += 100) if (!scope.pages.has(n)) missingOffsets.push(n);
  }
  scopeRows.push({
    scope_label: scope.label,
    scope_href: scope.href,
    page_count: pages.length,
    indexed_rows: pages.reduce((n, page) => n + (page.assets?.length ?? page.rows ?? 0), 0),
    unique_assets: local.size,
    terminal: scope.terminal,
    missing_offsets: missingOffsets,
    source_files: scope.source_files,
  });
  for (const asset of local.values()) {
    const row = globalAssets.get(asset.detail_href) ?? { ...asset, scope_labels: [], scope_hrefs: [] };
    row.scope_labels.push(scope.label);
    row.scope_hrefs.push(scope.href);
    globalAssets.set(asset.detail_href, row);
  }
}

const q = value => `"${String(value ?? "").replaceAll('"', '""')}"`;
const csv = [
  ["detail_href", "file_name", "scope_labels", "scope_hrefs"].join(","),
  ...[...globalAssets.values()].sort((a, b) => a.detail_href.localeCompare(b.detail_href)).map(row => [
    row.detail_href,
    row.file_name,
    JSON.stringify(row.scope_labels),
    JSON.stringify(row.scope_hrefs),
  ].map(q).join(",")),
].join("\n") + "\n";

fs.writeFileSync(path.join(root, "asset-index.csv"), csv, "utf8");
fs.writeFileSync(path.join(root, "scope-summary.json"), JSON.stringify({
  generated_at: new Date().toISOString(),
  scope_count: scopeRows.length,
  unique_asset_count: globalAssets.size,
  scopes: scopeRows,
}, null, 2) + "\n", "utf8");

const failures = scopeRows.filter(row => !row.terminal || row.missing_offsets.length);
if (failures.length) {
  console.error(JSON.stringify(failures, null, 2));
  process.exitCode = 1;
} else {
  console.log(JSON.stringify({ scopes: scopeRows.length, unique_assets: globalAssets.size }));
}
