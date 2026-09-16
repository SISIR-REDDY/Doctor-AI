import { test } from 'node:test';
import assert from 'node:assert/strict';

import { runRules, type AuditInput } from '../src/tasks/audit';
import { normalizeCode, referencePrice, type Benchmark } from '../src/benchmarks';
import { safeParseJson } from '../src/ai/gemini';
import { regionOf } from '../src/regions';

/**
 * The deterministic audit rules are what turn a scanned bill into a dollar
 * claim the user may put in a dispute letter. They must fire only on evidence
 * in the document, and never on a coincidence.
 */

const bench = (code: string, nonFacility: number, opps = 0): Benchmark => ({
  code,
  description: code,
  nonFacility,
  facility: nonFacility * 0.7,
  opps,
  year: 2026,
  currency: 'USD',
  source: 'test',
  approximate: false,
});

const line = (o: Partial<AuditInput['expenses'][number]['lineItems'][number]>) => ({
  code: '',
  codeSystem: 'CPT',
  modifier: '',
  description: 'item',
  dateOfService: '2026-03-01',
  quantity: 1,
  unitPrice: 0,
  amount: 0,
  category: 'other',
  ...o,
});

const input = (expenses: AuditInput['expenses']): AuditInput => ({
  region: 'US',
  currency: 'USD',
  caseType: 'outpatient',
  diagnosis: '',
  providerName: '',
  setting: 'office',
  expenses,
  userNotes: '',
});

test('duplicate: same code, same date, same amount, billed twice', () => {
  const out = runRules(
    input([
      {
        id: 'e1', vendor: '', date: '', category: 'other', amount: 184, note: '', lineItemsText: '',
        lineItems: [
          line({ code: '85025', description: 'CBC with differential', amount: 92 }),
          line({ code: '85025', description: 'CBC with differential', amount: 92 }),
        ],
      },
    ]),
    new Map(),
    'office',
  );
  const dup = out.filter((f) => f.type === 'duplicate');
  assert.equal(dup.length, 1);
  assert.equal(dup[0].amountAtIssue, 92);
});

test('duplicate: NOT flagged when it is a legitimate multi-unit line', () => {
  const out = runRules(
    input([
      {
        id: 'e1', vendor: '', date: '', category: 'other', amount: 184, note: '', lineItemsText: '',
        lineItems: [
          line({ code: '85025', amount: 92, quantity: 2 }),
          line({ code: '85025', amount: 92, quantity: 2 }),
        ],
      },
    ]),
    new Map(),
    'office',
  );
  assert.equal(out.filter((f) => f.type === 'duplicate').length, 0);
});

test('duplicate: different dates are different visits, not duplicates', () => {
  const out = runRules(
    input([
      {
        id: 'e1', vendor: '', date: '', category: 'other', amount: 184, note: '', lineItemsText: '',
        lineItems: [
          line({ code: '85025', amount: 92, dateOfService: '2026-03-01' }),
          line({ code: '85025', amount: 92, dateOfService: '2026-03-08' }),
        ],
      },
    ]),
    new Map(),
    'office',
  );
  assert.equal(out.filter((f) => f.type === 'duplicate').length, 0);
});

test('quantity: an office-visit E&M code billed more than once a day', () => {
  const out = runRules(
    input([
      {
        id: 'e1', vendor: '', date: '', category: 'other', amount: 778, note: '', lineItemsText: '',
        lineItems: [line({ code: '99214', amount: 778, quantity: 2 })],
      },
    ]),
    new Map(),
    'office',
  );
  assert.equal(out.filter((f) => f.type === 'quantity').length, 1);
});

test('overpriced: fires at ≥3× the Medicare reference and reports the ratio', () => {
  const benchmarks = new Map([['70450', bench('70450', 120)]]); // CT head w/o contrast
  const out = runRules(
    input([
      {
        id: 'e1', vendor: '', date: '', category: 'other', amount: 1850, note: '', lineItemsText: '',
        lineItems: [line({ code: '70450', amount: 1850, unitPrice: 1850 })],
      },
    ]),
    benchmarks,
    'office',
  );
  const over = out.filter((f) => f.type === 'overpriced');
  assert.equal(over.length, 1);
  assert.equal(over[0].benchmarkCode, '70450');
  assert.equal(over[0].benchmarkReferencePrice, 120);
  assert.ok(over[0].benchmarkRatio! > 15);
});

test('overpriced: does NOT fire below 3× — a 2.9× charge is not a finding', () => {
  const benchmarks = new Map([['70450', bench('70450', 120)]]);
  const out = runRules(
    input([
      {
        id: 'e1', vendor: '', date: '', category: 'other', amount: 348, note: '', lineItemsText: '',
        lineItems: [line({ code: '70450', amount: 348, unitPrice: 348 })],
      },
    ]),
    benchmarks,
    'office',
  );
  assert.equal(out.filter((f) => f.type === 'overpriced').length, 0);
});

test('overpriced: hospital setting adds the facility (OPPS) component', () => {
  const b = bench('70450', 120, 300);
  assert.equal(referencePrice(b, 'office'), 120);
  assert.equal(referencePrice(b, 'hospital'), 300 + 120 * 0.7);
});

test('math: line items that do not add up to the bill total', () => {
  const out = runRules(
    input([
      {
        id: 'e1', vendor: '', date: '', category: 'other', amount: 500, note: '', lineItemsText: '',
        lineItems: [line({ code: 'A', amount: 100 }), line({ code: 'B', amount: 200 })],
      },
    ]),
    new Map(),
    'office',
  );
  const m = out.filter((f) => f.type === 'math_error');
  assert.equal(m.length, 1);
  assert.equal(m[0].amountAtIssue, 200);
});

test('math: tolerates rounding (≤2%) and single-line bills', () => {
  const out = runRules(
    input([
      {
        id: 'e1', vendor: '', date: '', category: 'other', amount: 301, note: '', lineItemsText: '',
        lineItems: [line({ code: 'A', amount: 100 }), line({ code: 'B', amount: 200 })],
      },
      {
        id: 'e2', vendor: '', date: '', category: 'other', amount: 999, note: '', lineItemsText: '',
        lineItems: [line({ code: 'A', amount: 100 })],
      },
    ]),
    new Map(),
    'office',
  );
  assert.equal(out.filter((f) => f.type === 'math_error').length, 0);
});

test('normalizeCode strips modifiers and whitespace, keeps HCPCS letters', () => {
  assert.equal(normalizeCode(' 99214-25 '), '99214');
  assert.equal(normalizeCode('j1100'), 'J1100');
  assert.equal(normalizeCode(''), '');
  assert.equal(normalizeCode(undefined), '');
});

test('safeParseJson tolerates fences and prose around the object', () => {
  assert.deepEqual(safeParseJson('```json\n{"a":1}\n```'), { a: 1 });
  assert.deepEqual(safeParseJson('Sure! Here it is: {"a":1} — done.'), { a: 1 });
  assert.equal(safeParseJson('not json at all'), undefined);
});

test('regionOf falls back to US for unknown codes and is case-insensitive', () => {
  assert.equal(regionOf('gb').code, 'GB');
  assert.equal(regionOf('ZZ').code, 'US');
});
