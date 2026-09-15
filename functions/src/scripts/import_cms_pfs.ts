/**
 * Imports EXACT Medicare amounts from the official CMS files, replacing the
 * approximate seed values.
 *
 *   PFS RVU file (physician services):
 *     node lib/scripts/import_cms_pfs.js --type pfs --file PPRRVU26_JAN.csv --cf 33.40 --year 2026
 *   CLFS file (lab tests):
 *     node lib/scripts/import_cms_pfs.js --type clfs --file CLFS26.csv --year 2026
 *
 * Download from cms.gov → Medicare → Physician Fee Schedule → "RVU files"
 * and → Clinical Laboratory Fee Schedule files. Column names vary slightly
 * by year; the parser matches headers case-insensitively and tolerates
 * quoting. National amount = total RVU × conversion factor (GPCI 1.0).
 */
import { readFileSync } from 'node:fs';
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

function arg(name: string, fallback = ''): string {
  const i = process.argv.indexOf(`--${name}`);
  return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}

function parseCsv(text: string): string[][] {
  const rows: string[][] = [];
  let row: string[] = [];
  let cell = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (quoted) {
      if (ch === '"' && text[i + 1] === '"') { cell += '"'; i++; }
      else if (ch === '"') quoted = false;
      else cell += ch;
    } else if (ch === '"') quoted = true;
    else if (ch === ',') { row.push(cell); cell = ''; }
    else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i++;
      row.push(cell); rows.push(row); row = []; cell = '';
    } else cell += ch;
  }
  if (cell || row.length) { row.push(cell); rows.push(row); }
  return rows.filter((r) => r.some((c) => c.trim()));
}

function findCol(headers: string[], ...needles: string[]): number {
  const h = headers.map((x) => x.toUpperCase().replace(/[^A-Z0-9]/g, ''));
  for (const n of needles) {
    const key = n.toUpperCase().replace(/[^A-Z0-9]/g, '');
    const idx = h.findIndex((x) => x === key || x.includes(key));
    if (idx >= 0) return idx;
  }
  return -1;
}

async function main() {
  const type = arg('type', 'pfs');
  const file = arg('file');
  const year = Number(arg('year', String(new Date().getFullYear())));
  const cf = Number(arg('cf', '0'));
  if (!file) throw new Error('--file is required');
  if (type === 'pfs' && !cf) throw new Error('--cf (conversion factor, e.g. 33.40) is required for PFS');

  const rows = parseCsv(readFileSync(file, 'utf8'));
  // Header row is the first row that contains HCPCS.
  const headerIdx = rows.findIndex((r) => r.some((c) => /HCPCS/i.test(c)));
  if (headerIdx < 0) throw new Error('Could not find a header row containing HCPCS');
  const headers = rows[headerIdx];
  const body = rows.slice(headerIdx + 1);

  const cCode = findCol(headers, 'HCPCS');
  const cMod = findCol(headers, 'MOD', 'MODIFIER');
  const cDesc = findCol(headers, 'DESCRIPTION', 'SHORT DESCRIPTION', 'DESC');
  const cNonFac = findCol(headers, 'NON-FAC TOTAL', 'NONFACILITY TOTAL', 'NON FACILITY TOTAL');
  const cFac = findCol(headers, 'FAC TOTAL', 'FACILITY TOTAL');
  const cRate = findCol(headers, 'RATE', 'PAYMENT', 'NATIONAL LIMIT');
  const cStatus = findCol(headers, 'STATUS');

  initializeApp();
  const db = getFirestore();
  let batch = db.batch();
  let n = 0;
  let written = 0;
  for (const r of body) {
    const code = (r[cCode] ?? '').trim().toUpperCase();
    if (!/^[A-Z0-9]{5}$/.test(code)) continue;
    const mod = cMod >= 0 ? (r[cMod] ?? '').trim() : '';
    if (mod) continue; // base code rows only
    if (cStatus >= 0 && /^[BCDEIMNRXZ]$/.test((r[cStatus] ?? '').trim())) continue; // non-payable statuses
    const desc = (r[cDesc] ?? '').trim();
    let nonFacility = 0;
    let facility = 0;
    if (type === 'pfs') {
      nonFacility = Number(r[cNonFac] ?? 0) * cf;
      facility = Number(r[cFac] ?? 0) * cf;
      if (!nonFacility && !facility) continue;
    } else {
      const rate = Number(r[cRate] ?? 0);
      if (!rate) continue;
      nonFacility = rate;
      facility = rate;
    }
    batch.set(
      db.doc(`benchmarks/CMS_PFS/codes/${code}`),
      {
        code,
        description: desc,
        nonFacility: Number(nonFacility.toFixed(2)),
        facility: Number(facility.toFixed(2)),
        year,
        currency: 'USD',
        source: type === 'pfs' ? `CMS Physician Fee Schedule ${year} (CF ${cf})` : `CMS Clinical Laboratory Fee Schedule ${year}`,
        approximate: false,
      },
      { merge: true },
    );
    n++;
    written++;
    if (n === 400) {
      await batch.commit();
      batch = db.batch();
      n = 0;
      process.stdout.write(`\r${written} codes written`);
    }
  }
  if (n) await batch.commit();
  await db.doc('benchmarks/CMS_PFS').set({ year, approximate: false, lastImport: new Date().toISOString(), type }, { merge: true });
  console.log(`\nDone: ${written} codes written.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
