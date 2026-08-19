// WildBrain DAM (Wedia) full capture. Paste into the browser MCP javascript_tool
// on an authenticated https://dam.wildbrain.com tab. Run STEP 1, then STEP 2,
// then STEP 3 (one download at a time, confirming each landed).
//
// Pagination note: every offset param (start/first/offset/page/skip) is IGNORED
// and max is capped at 200. Page with {"id":{"gt":lastId}} + orderby=id, and
// always verify UNIQUE IDs rather than row count.

// ---------- STEP 1: assets ----------
(async () => {
  const P = ['id','name','originalfilename','assetnature','wiluniverse','wilbrand',
    'wilfranchise','wilera','wilcreative','wilcreativetype','wilassetcategory',
    'wilassetcatfranchise','wilcharactername','keywords','wilkeywords','created',
    'modified','filesize','nbpages','description','folder','coverage'].join(',');
  let all = [], lastId = 0, guard = 0;
  while (guard++ < 60) {
    const q = JSON.stringify({ and: [{ activated: true }, { id: { gt: lastId } }] });
    const url = `/api/rest/dam/asset?lang=en&max=200&headers=false&maxchildren=200`
      + `&props=${encodeURIComponent(P)}&orderby=id&query=${encodeURIComponent(q)}&x-context=portal`;
    const d = (await (await fetch(url)).json()).response.data || [];
    if (!d.length) break;
    for (const a of d) all.push({
      id: a.id, uuid: a.$uuid, name: a.name, file: a.originalfilename,
      type: a.assetnature && a.assetnature.name,
      universe: a.wiluniverse && a.wiluniverse.name,
      brand: a.wilbrand && a.wilbrand.name,
      franchise: a.wilfranchise && a.wilfranchise.name,
      eraId: a.wilera && a.wilera.id, era: a.wilera && a.wilera.name,
      creative: a.wilcreative && a.wilcreative.name, creativetype: a.wilcreativetype,
      cat: a.wilassetcategory && a.wilassetcategory.name,
      catf: a.wilassetcatfranchise && a.wilassetcatfranchise.name,
      chars: (a.wilcharactername || []).map(c => c.id + ':' + c.name),
      charTotal: (a.$moreChildren_wilcharactername || {}).total,
      kw: a.wilkeywords, kw2: (a.keywords || []).map(k => k.name || k),
      desc: a.description, folder: (a.folder || []).map(f => f.name),
      coverage: a.coverage && a.coverage.name,
      created: a.created, size: a.filesize, pages: a.nbpages
    });
    lastId = d[d.length - 1].id;
  }
  window.__assets = all;
  // charTotal > chars.length would mean truncated child lists - must be 0.
  return 'rows=' + all.length
    + ' unique=' + new Set(all.map(a => a.id)).size
    + ' truncatedCharLists=' + all.filter(a => a.charTotal > a.chars.length).length;
})()

// ---------- STEP 2: dictionaries ----------
(async () => {
  const names = ['wiluniverse','wilbrand','wilfranchise','wilera','wilcreative',
    'wilassetcategory','wilassetcatfranchise','assetnature','wilcharactername'];
  const out = {}, log = [];
  for (const n of names) {
    let all = [], last = -1, g = 0;
    while (g++ < 50) {
      const q = JSON.stringify({ id: { gt: last } });
      const url = `/api/rest/dam/data/${n}?lang=en&max=200&headers=false&orderby=id`
        + `&query=${encodeURIComponent(q)}&x-context=portal`;
      const d = (await (await fetch(url)).json()).response.data || [];
      if (!d.length) break;
      d.forEach(x => {
        const o = { id: x.id, name: x.name };
        if (x.code) o.code = x.code;
        if (x.parentobject) o.parentId = x.parentobject.id;  // era hierarchy
        all.push(o);
      });
      last = d[d.length - 1].id;
    }
    out[n] = all; log.push(n + '=' + all.length);
  }
  window.__vocab = out;
  return log.join(', ');   // expect wilcharactername=217, not 200
})()

// ---------- STEP 3: emit. ONE download per call; confirm each landed. ----------
(() => {
  const A = window.__assets;
  const esc = s => (s === null || s === undefined ? '' : String(s)).replace(/[\t\r\n]/g, ' ');
  const tsv = ['asset_id\tuuid\tname\toriginal_filename\tfile_type\tuniverse\tera_id\tera'
    + '\tcreative_group\tasset_category\tguide_keywords\tcharacter_ids\tcharacter_names'
    + '\tcreated_ms\tfilesize\tpages']
    .concat(A.map(a => [a.id, a.uuid, esc(a.name), esc(a.file), esc(a.type), esc(a.universe),
      a.eraId || '', esc(a.era), esc(a.creative), esc(a.catf), esc(a.kw),
      a.chars.map(c => c.split(':')[0]).join('|'),
      a.chars.map(c => c.split(':').slice(1).join(':')).join('|'),
      a.created, a.size, a.pages || ''].join('\t'))).join('\n');
  const dl = (n, s) => {
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([s], { type: 'text/plain' }));
    a.download = n; document.body.appendChild(a); a.click(); a.remove();
  };
  dl('ssc-assets.tsv', tsv);
  // then, in a SEPARATE call:
  // dl('ssc-vocabularies.json', JSON.stringify(window.__vocab, null, 1));
  return 'lines=' + (tsv.split('\n').length);
})()
