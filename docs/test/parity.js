/* One calculator, three products — this is the check that keeps them honest.
   Run:  node docs/test/parity.js        (no dependencies)

   It fails if the browser extension's engine disagrees with the prototype's by so much as a
   rounding error, if the generated files are stale, or if a region present in the app is
   missing from the extension. That last one is not hypothetical: the extension shipped with
   two regions and no India, so an Indian user was shown roughly half the real number. */
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');
const ROOT = path.join(__dirname, '..', '..');
let pass = 0, fail = 0;
const ok = (name, cond, extra = '') => { if (cond) { pass++; console.log('  ✓', name); }
                                         else { fail++; console.log('  ✗', name, extra); } };
const load = p => fs.readFileSync(path.join(ROOT, p), 'utf8');

/* the generated files must be current — a stale extension is exactly the bug this prevents */
console.log('\nGENERATED FILES ARE CURRENT');
const before = { ext: load('browser_extension/engine.js'), json: (()=>{ try { return load('app/assets/calc/models.v2.json'); } catch(e){ return null; } })() };
execFileSync(process.execPath, [path.join(ROOT, 'tools', 'build-shared.js')], { stdio: 'pipe' });
ok('browser_extension/engine.js is in step with engine.js', before.ext === load('browser_extension/engine.js'),
   'run: node tools/build-shared.js');
ok('app/assets/calc/models.v2.json is in step with engine.js', before.json === load('app/assets/calc/models.v2.json'),
   'run: node tools/build-shared.js');

/* load both engines the way their own product does */
const app = (new Function(load('engine.js') + '\nreturn {C, estimate, regionParams, tok};'))();
const ext = (new Function('module', load('browser_extension/engine.js') + '\nreturn SIP;'))({ });

console.log('\nTHE SAME PROMPT GIVES THE SAME ANSWER');
const cases = [];
for (const region of Object.keys(app.C.regions))
  for (const tier of Object.keys(app.C.tiers))
    for (const task of Object.keys(app.C.tasks))
      for (const inputTokens of [0, 100, 900])
        cases.push({ region, tier, task, inputTokens });

let worst = 0, worstCase = null;
for (const c of cases) {
  const p = app.regionParams(c.region, app.C.regions[c.region].defaultCooling || 'reported', true);
  const a = app.estimate({ tier: c.tier, task: c.task, inputTokens: c.inputTokens, params: p }).total;
  const b = ext.estimate({ tier: c.tier, task: c.task, region: c.region, inputTokens: c.inputTokens }).total;
  const d = Math.abs(a - b);
  if (d > worst) { worst = d; worstCase = c; }
}
ok(`all ${cases.length} combinations agree exactly`, worst < 1e-9,
   worstCase ? `worst: ${JSON.stringify(worstCase)} differs by ${worst}` : '');

console.log('\nNO REGION IS MISSING FROM ANY PRODUCT');
ok('extension carries every region the app has', Object.keys(ext.C.regions).join() === Object.keys(app.C.regions).join(),
   `app: ${Object.keys(app.C.regions).length}, extension: ${Object.keys(ext.C.regions).length}`);
ok('India is one of them', !!ext.C.regions.india);
const ml = r => { const p = app.regionParams(r, 'reported', true);
                  return app.estimate({ tier: 'standard', task: 'text', inputTokens: 100, outputTokens: 300, params: p }).total; };
ok('and it is not quietly the US figure', Math.abs(ml('india') - ml('us_hyperscale')) > 0.5,
   `india ${ml('india').toFixed(3)} mL vs us ${ml('us_hyperscale').toFixed(3)} mL`);

console.log('\nOUTPUT TOKENS ARE WEIGHTED EVERYWHERE');
ok('extension applies the 5x output weighting', (() => {
  const a = ext.estimate({ tier: 'standard', task: 'text', region: 'us_hyperscale', inputTokens: 400, outputTokens: 0 }).total;
  const b = ext.estimate({ tier: 'standard', task: 'text', region: 'us_hyperscale', inputTokens: 0, outputTokens: 400 }).total;
  return Math.abs(b / a - 5) < 1e-6;
})());
ok('the reference prompt is still 1.2959 mL', Math.abs(ml('us_hyperscale') - 1.2959) < 0.0005, ml('us_hyperscale').toFixed(4));

console.log('\nTHE 5x MULTIPLIER CAN BE REPLACED SAFELY');
/* D-22: 5x is a placeholder until I-30 measures it. Swapping it must not move the calibrated
   reference prompt off 0.30 Wh — the normalisation has to follow the multiplier automatically. */
for (const ratio of [3, 5, 8, 10]) {
  const src = load('engine.js').replace(/const OUTPUT_PER_INPUT = \d+(\.\d+)?;/, `const OUTPUT_PER_INPUT = ${ratio};`);
  const m = (new Function(src + '\nreturn {C, estimate, regionParams};'))();
  const p = m.regionParams('us_hyperscale', 'reported', true);
  const wh = m.estimate({ tier: 'standard', task: 'text', inputTokens: 100, outputTokens: 300, params: p }).energyWh;
  const heavyIn  = m.estimate({ tier: 'standard', task: 'text', inputTokens: 400, outputTokens: 0, params: p }).total;
  const heavyOut = m.estimate({ tier: 'standard', task: 'text', inputTokens: 0, outputTokens: 400, params: p }).total;
  ok(`at ${ratio}x the reference prompt is still 0.30 Wh`, Math.abs(wh - 0.30) < 1e-9, wh.toFixed(6));
  ok(`at ${ratio}x an output token really costs ${ratio}x`, Math.abs(heavyOut / heavyIn - ratio) < 1e-6);
}
/* comments may still explain the old literal; what matters is that no live code carries it */
const engineCode = load('engine.js').replace(/\/\*[\s\S]*?\*\//g, '').replace(/^\s*\/\/.*$/gm, '');
ok('no live code hardcodes the old 400/320', !/400\s*\/\s*320/.test(engineCode));
ok('the tiers derive from the multiplier', /wh1k:\s*[\d.]+\s*\*\s*WEIGHT_NORM/.test(engineCode));

console.log('\nTHE FLUTTER CONSTANTS MATCH TOO');
const j = JSON.parse(load('app/assets/calc/models.v2.json'));
ok('same constants version', j.constants_version === app.C.version);
ok('same regions', Object.keys(j.regions).join() === Object.keys(app.C.regions).join());
ok('token weights carried over', j.token_weights.input === app.C.tokenWeights.input && j.token_weights.output === app.C.tokenWeights.output);
let gbad = null;
for (const g of j.golden) {
  const p = app.regionParams(g.region, app.C.regions[g.region].defaultCooling || 'reported', true);
  const e = app.estimate({ tier: g.tier, task: g.task, inputTokens: g.inputTokens, outputTokens: g.outputTokens, items: g.items || 1, params: p });
  if (Math.abs(e.total - g.expect_total_ml) > 1e-6) gbad = g;
}
ok(`${j.golden.length} golden cases reproduce`, !gbad, gbad ? JSON.stringify(gbad) : '');

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
