/**
 * Loads the bundled approximate US benchmark seed into Firestore.
 *   cd functions && npm run build && npm run seed:benchmarks
 * Requires Application Default Credentials (`gcloud auth application-default login`)
 * or GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key.
 */
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import seed from '../../data/us_benchmarks_seed.json';

async function main() {
  initializeApp();
  const db = getFirestore();
  const batchSize = 400;
  const codes = seed.codes;
  for (let i = 0; i < codes.length; i += batchSize) {
    const batch = db.batch();
    for (const c of codes.slice(i, i + batchSize)) {
      batch.set(db.doc(`benchmarks/CMS_PFS/codes/${c.code}`), {
        ...c,
        year: seed.year,
        currency: seed.currency,
        source: seed.source,
        approximate: seed.approximate,
      });
    }
    await batch.commit();
    console.log(`seeded ${Math.min(i + batchSize, codes.length)}/${codes.length}`);
  }
  await db.doc('benchmarks/CMS_PFS').set({ year: seed.year, source: seed.source, approximate: seed.approximate, count: codes.length });
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
