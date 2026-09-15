import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import seed from '../data/us_benchmarks_seed.json';
import type { Region } from './regions';

/**
 * Fair-price references used by the bill audit.
 *
 * US: Medicare national amounts (PFS for physician services, CLFS for labs,
 * OPPS for hospital outpatient facility fees). Exact figures are loaded into
 * Firestore `benchmarks/CMS_PFS/codes/{code}` by scripts/import_cms_pfs.ts;
 * until then the bundled seed (approximate, labelled as such) is used.
 */
export interface Benchmark {
  code: string;
  description: string;
  /** Physician fee in an office / non-facility setting. */
  nonFacility: number;
  /** Physician fee when performed in a facility. */
  facility: number;
  /** Hospital outpatient facility fee (OPPS), if applicable. */
  opps?: number;
  year: number;
  currency: string;
  source: string;
  approximate: boolean;
}

interface SeedFile {
  source: string;
  year: number;
  currency: string;
  approximate: boolean;
  codes: Array<{ code: string; description: string; nonFacility: number; facility: number; opps?: number }>;
}

const SEED = seed as SeedFile;
const SEED_MAP = new Map<string, Benchmark>(
  SEED.codes.map((c) => [
    c.code,
    {
      ...c,
      year: SEED.year,
      currency: SEED.currency,
      source: SEED.source,
      approximate: SEED.approximate,
    },
  ]),
);

const COLLECTION: Record<NonNullable<Region['benchmarkSource']>, string> = {
  CMS_PFS: 'benchmarks/CMS_PFS/codes',
  AU_MBS: 'benchmarks/AU_MBS/codes',
};

/** Normalises a printed code ("99213-25", " 99213 ") to its lookup key. */
export function normalizeCode(raw: string | undefined | null): string {
  if (!raw) return '';
  const cleaned = raw.trim().toUpperCase().split(/[-\s,]/)[0] ?? '';
  return /^[A-Z0-9]{4,6}$/.test(cleaned) ? cleaned : '';
}

export async function lookupBenchmarks(region: Region, codes: string[]): Promise<Map<string, Benchmark>> {
  const result = new Map<string, Benchmark>();
  if (!region.benchmarkSource) return result;
  const wanted = Array.from(new Set(codes.map(normalizeCode).filter(Boolean)));
  if (wanted.length === 0) return result;

  // Firestore first (exact, imported data) …
  try {
    const db = getFirestore();
    const refs = wanted.map((c) => db.doc(`${COLLECTION[region.benchmarkSource!]}/${c}`));
    const snaps = await db.getAll(...refs);
    for (const snap of snaps) {
      if (snap.exists) {
        const d = snap.data() as Benchmark;
        result.set(d.code, { ...d, approximate: d.approximate ?? false });
      }
    }
  } catch (err) {
    logger.warn('benchmarks.firestore_failed', { err: String(err) });
  }

  // … then the bundled seed for anything missing (US only).
  if (region.benchmarkSource === 'CMS_PFS') {
    for (const c of wanted) {
      if (!result.has(c) && SEED_MAP.has(c)) result.set(c, SEED_MAP.get(c)!);
    }
  }
  return result;
}

/** Renders the benchmark table for the audit prompt. */
export function benchmarkTable(benchmarks: Map<string, Benchmark>, currency: string): string {
  if (benchmarks.size === 0) return '(no benchmark data available for these codes)';
  const rows = Array.from(benchmarks.values()).map((b) => {
    const parts = [`${b.code} — ${b.description}:`];
    if (b.nonFacility > 0) parts.push(`office/physician ${currency} ${b.nonFacility.toFixed(2)}`);
    if (b.facility > 0 && b.facility !== b.nonFacility) parts.push(`physician-in-facility ${currency} ${b.facility.toFixed(2)}`);
    if (b.opps && b.opps > 0) parts.push(`hospital outpatient facility fee ${currency} ${b.opps.toFixed(2)}`);
    parts.push(`(${b.source.split(',')[0]}${b.approximate ? ', approximate' : ''} ${b.year})`);
    return `- ${parts.join(' · ')}`;
  });
  return rows.join('\n');
}

/** The best single reference price for ratio checks. */
export function referencePrice(b: Benchmark, setting: 'office' | 'hospital'): number {
  if (setting === 'hospital') {
    // Physician + facility component when both exist.
    const phys = b.facility > 0 ? b.facility : b.nonFacility;
    return (b.opps ?? 0) + phys;
  }
  return b.nonFacility > 0 ? b.nonFacility : b.facility;
}
