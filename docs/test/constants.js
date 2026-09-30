/* Can a published constants file move the number, and can a bad one do damage?
   Run:  node docs/test/constants.js        (no dependencies)

   `docs/constants.json` exists so a measured coefficient reaches people who already installed the
   app, instead of waiting for a store release. That is also a supply-chain surface: anything that
   can change the number can lie about it. So the rule is fail closed — a payload that is the wrong
   shape, or carries any value outside a physical band, is rejected whole and the app keeps exactly
   what it shipped with. These tests are that rule. */
const fs = require('fs'), path = require('path');
const ROOT = path.join(__dirname, '..', '..');
const src = fs.readFileSync(path.join(ROOT, 'engine.js'), 'utf8');
const fresh = () => (new Function(src + '\nreturn {C, estimate, regionParams, applyConstants, recalibrate, hiddenFrom, tok};'))();

let pass = 0, fail = 0;
const ok = (n, c, x = '') => { if (c) { pass++; console.log('  ✓', n); } else { fail++; console.log('  ✗', n, x); } };
/* Deliberately NOT the reference prompt (100 in / 300 out): that one is held fixed by the
   normalisation whatever the multiplier is, so it can never show a change. A lopsided prompt is
   what actually moves when the input/output ratio is re-fitted. */
const ml = e => { const P = e.regionParams('india', 'reported', true);
  return e.estimate({ tier: 'standard', task: 'text', inputTokens: 2000, outputTokens: 200, params: P }).total; };
const good = () => JSON.parse(fs.readFileSync(path.join(ROOT, 'docs', 'constants.json'), 'utf8'));

console.log('\nWHAT WE PUBLISH IS WHAT WE SHIP');
{
  const e = fresh(), before = ml(e);
  const r = e.applyConstants(good());
  ok('the published file is accepted', r.ok, r.reason || '');
  ok('and changes nothing, because it came from the engine', Math.abs(ml(e) - before) < 1e-9);
  ok('it carries numbers only — no code, no strings to execute', (() => {
    const flat = JSON.stringify(good());
    return !/function|=>|eval|script|require|<|\$\{/.test(flat.replace(/"note":"[^"]*"/, ''));
  })());
}

console.log('\nA MEASURED COEFFICIENT REACHES AN INSTALLED APP');
{
  const e = fresh(), before = ml(e);
  const payload = Object.assign(good(), { version: '2026-11-01', outputPerInput: 3 });
  const r = e.applyConstants(payload);
  ok('a re-fitted multiplier is applied', r.ok && r.applied.includes('outputPerInput'));
  ok('the calibrated reference prompt still holds at 0.30 Wh', (() => {
    const P = e.regionParams('us_hyperscale', 'reported', true);
    return Math.abs(e.estimate({ tier: 'standard', task: 'text', inputTokens: 100, outputTokens: 300, params: P }).energyWh - 0.30) < 1e-9;
  })());
  ok('and heavy prompts move, which is the point', Math.abs(ml(e) - before) > 1e-6, `${before.toFixed(3)} → ${ml(e).toFixed(3)} mL`);
  const e2 = fresh();
  e2.applyConstants(Object.assign(good(), { version: 'x', thinking: { tokensPerSec: 140 } }));
  ok('a re-fitted thinking rate is applied', e2.hiddenFrom({ activeMs: 60000, outputTokens: 0, tier: 'standard' }) > fresh().hiddenFrom({ activeMs: 60000, outputTokens: 0, tier: 'standard' }));
}

console.log('\nA BAD FILE CANNOT MOVE THE NUMBER');
const hostile = [
  ['no schema', {}],
  ['wrong schema', { schema: 'something-else', version: '1' }],
  ['version is an object', { schema: 'sipcount-constants/1', version: { a: 1 } }],
  ['absurd multiplier', { schema: 'sipcount-constants/1', version: '1', outputPerInput: 1000 }],
  ['zero multiplier', { schema: 'sipcount-constants/1', version: '1', outputPerInput: 0 }],
  ['negative energy', { schema: 'sipcount-constants/1', version: '1', tiers: { standard: { base: -5 } } }],
  ['impossible PUE', { schema: 'sipcount-constants/1', version: '1', regions: { india: { pue: 99, wueSite: 2, ewif: { incl: 3, excl: 2 } } } }],
  ['a region we do not have', { schema: 'sipcount-constants/1', version: '1', regions: { atlantis: { pue: 1.2, wueSite: 1, ewif: { incl: 3, excl: 2 } } } }],
  ['a tier we do not have', { schema: 'sipcount-constants/1', version: '1', tiers: { magic: { base: 1 } } }],
  ['a string where a number belongs', { schema: 'sipcount-constants/1', version: '1', outputPerInput: '5' }],
  ['NaN', { schema: 'sipcount-constants/1', version: '1', outputPerInput: NaN }],
  ['Infinity', { schema: 'sipcount-constants/1', version: '1', thinking: { tokensPerSec: Infinity } }],
  ['null', null]
];
for (const [name, payload] of hostile) {
  const e = fresh(), before = ml(e), v = e.C.version;
  const r = e.applyConstants(payload);
  ok(`rejected: ${name}`, !r.ok && Math.abs(ml(e) - before) < 1e-12 && e.C.version === v, JSON.stringify(r));
}

console.log('\nHALF-WRONG IS STILL WHOLLY REJECTED');
{
  const e = fresh(), before = ml(e);
  /* one good change and one impossible one in the same file: the good one must NOT slip through,
     or a payload could be crafted to apply exactly the part it wants */
  const r = e.applyConstants({ schema: 'sipcount-constants/1', version: '1',
    thinking: { tokensPerSec: 120 }, regions: { india: { pue: 99, wueSite: 2, ewif: { incl: 3, excl: 2 } } } });
  ok('a payload that is partly invalid applies none of it', !r.ok
     && Math.abs(ml(e) - before) < 1e-12
     && e.hiddenFrom({ activeMs: 60000, outputTokens: 0, tier: 'standard' }) === fresh().hiddenFrom({ activeMs: 60000, outputTokens: 0, tier: 'standard' }));
  ok('unknown extra keys are ignored rather than trusted', (() => {
    const e2 = fresh(); const r2 = e2.applyConstants(Object.assign(good(), { version: 'y', somethingNew: { evil: true } }));
    return r2.ok && e2.C.somethingNew === undefined;
  })());
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
