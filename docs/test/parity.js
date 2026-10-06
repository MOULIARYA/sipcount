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

/* The extension must actually START. background.js is loaded with importScripts(), which shares
   ONE global scope with engine.js — so a name declared in both is a syntax error and Chrome
   refuses to register the service worker ("Status code: 15"). That is exactly what shipped on
   2026-09-29, because the generated engine leaked twenty-odd top-level names including `dayKey`,
   which background.js also declares. This loads them into one shared context, as Chrome does. */
console.log('\nTHE EXTENSION LOADS THE WAY CHROME LOADS IT');
{
  const vm = require('vm');
  const stub = () => {};
  const listener = { addListener: stub };
  const sandbox = {
    console: { log: stub, warn: stub, error: stub }, setTimeout, clearTimeout, TextEncoder, TextDecoder,
    importScripts: stub, location: { hostname: 'chatgpt.com' },
    chrome: { storage: { local: { get: async () => ({}), set: async () => {} } },
              runtime: { onMessage: listener, onInstalled: listener, onStartup: listener },
              action: { setBadgeText: stub, setBadgeBackgroundColor: stub, setBadgeTextColor: stub, setIcon: stub } },
    OffscreenCanvas: function () { return { getContext: () => null }; }
  };
  sandbox.globalThis = sandbox; sandbox.self = sandbox;
  const ctx = vm.createContext(sandbox);

  let started = null;
  try {
    vm.runInContext(load('browser_extension/engine.js'), ctx, { filename: 'engine.js' });
    vm.runInContext(load('browser_extension/background.js').replace(/^\s*importScripts\(.*$/m, ''), ctx, { filename: 'background.js' });
  } catch (e) { started = `${e.name}: ${e.message}`; }
  ok('service worker registers (engine + background share one scope)', started === null, started || '');
  ok('and SIP is usable from it', started === null && vm.runInContext('typeof SIP === "object" && typeof SIP.estimate === "function"', ctx));

  /* the collision that caused it: `const` at the top of a script occupies the shared global
     lexical scope, so re-declaring an engine internal must NOT throw — meaning it never leaked */
  let clash = null;
  /* engine internals only — background.js legitimately declares dayKey, KEY and defaults itself */
  try { vm.runInContext('const fmt=0, tok=0, C=0, zone=0, estimate=0, makeStore=0, regionParams=0, SIPCOUNT_CONFIG=0, ZONE_UI=0;', ctx); }
  catch (e) { clash = e.message; }
  ok('no engine internals leak into that scope', clash === null, clash || '');
}

/* load both engines the way their own product does */
const app = (new Function(load('engine.js') + '\nreturn {C, estimate, regionParams, tok, scriptOf, hiddenFrom, contextFactor};'))();
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

console.log('\nCHARACTERS PER TOKEN IS NOT LANGUAGE-NEUTRAL');
/* Treating every script as English under-counts the audience we most want to reach: the same
   4,000-character answer is 1,000 tokens in English and 1,250 in Hindi. */
{
  const cases = [['How does photosynthesis work?', 'latin'], ['प्रकाश संश्लेषण कैसे काम करता है', 'devanagari'],
                 ['mujhe ek python function chahiye जो string reverse kare', 'hinglish'],
                 ['const x = 5; function go(){ return x; }', 'code'], ['光合作用是如何工作的', 'cjk']];
  for (const [text, want] of cases) ok(`"${text.slice(0, 22)}…" reads as ${want}`, app.scriptOf ? app.scriptOf(text) === want : ext.scriptOf(text) === want, ext.scriptOf(text));
  ok('the extension classifies identically', cases.every(([t, w]) => ext.scriptOf(t) === w));
  const latin = ext.tok(4000, 'latin'), dev = ext.tok(4000, 'devanagari');
  ok('a Hindi answer costs more tokens than an English one', dev > latin * 1.2, `${latin} vs ${dev}`);
  ok('an unknown script falls back to English, not to zero', ext.tok(4000, 'klingon') === latin);
}

console.log('\nWORK THAT NEVER REACHES THE SCREEN');
/* A five-minute research turn shows a few paragraphs and was charged as a short chat turn —
   under-counted ~28×. Hidden tokens = rate × active time − what we saw. */
{
  const h = (activeMs, outputTokens, tier = 'standard') => ext.C && app.hiddenFrom({ activeMs, outputTokens, tier });
  ok('an ordinary chat turn gains nothing', h(12000, 900) < 100, String(h(12000, 900)));
  ok('a quick answer gains nothing at all', h(4000, 300) === 0);
  ok('five minutes of work is counted', h(270000, 875) > 20000, h(270000, 875).toLocaleString());
  ok('a reasoning tier is not charged twice', h(270000, 875, 'reasoning') === 0);
  ok('missing timing costs nothing rather than guessing', h(undefined, 900) === 0 && h(0, 900) === 0);
  ok('and it cannot run away', h(99999999, 0) <= app.C.thinking.tokensPerSec * app.C.thinking.maxSec);
  const P = app.regionParams('india', 'reported', true);
  const seen = app.estimate({ tier: 'standard', task: 'text', inputTokens: 50, outputTokens: 875, params: P }).total;
  const all = app.estimate({ tier: 'standard', task: 'text', inputTokens: 50, outputTokens: 875, hiddenTokens: h(270000, 875), params: P }).total;
  ok('the research turn is worth ~25x what we showed', all / seen > 20, `${seen.toFixed(1)} → ${all.toFixed(1)} mL`);
  ok('the extension agrees with the engine on it', Math.abs(
      ext.estimate({ tier: 'standard', task: 'text', region: 'india', inputTokens: 50, outputTokens: 875, hiddenTokens: h(270000, 875) }).total - all) < 1e-9);
  const sv = ext.savingsIfLighter('standard', 'text', 'india', 50, 875, h(270000, 875));
  ok('"a lighter model would have saved X" never exceeds the turn', sv.ml < all, `${sv.ml.toFixed(1)} vs ${all.toFixed(1)}`);
  /* Live on 2026-09-30 the popup called a five-minute research job a "Simple task?" and offered a
     lighter model that could not have done it. Offer nothing rather than bad advice. */
  ok('no lighter-model advice on a turn that was mostly unseen work', sv.alt === null && sv.ml === 0);
  ok('but ordinary turns still get the advice', ext.savingsIfLighter('standard', 'text', 'india', 30, 900, 40).alt === 'lightweight');
}

console.log('\nA LONG CONVERSATION COSTS MORE');
/* Each output token re-reads the whole context, so the twentieth message in a thread is dearer
   than the first even when the reply is identical — and heavy users live in long threads. */
{
  const f = app.contextFactor;
  ok('a fresh chat is unaffected', f(0) === 1 && f(undefined) === 1);
  ok('and so is the calibrated reference prompt', (() => {
    const P = app.regionParams('us_hyperscale', 'reported', true);
    return Math.abs(app.estimate({ tier: 'standard', task: 'text', inputTokens: 100, outputTokens: 300, contextTokens: 0, params: P }).energyWh - 0.30) < 1e-9;
  })());
  ok('a long thread costs more for the same answer', f(30000) > 2, f(30000).toFixed(2) + 'x');
  ok('but it cannot run away', f(10_000_000) === app.C.context.max);
  ok('it lifts the answer, not the question', (() => {
    const P = app.regionParams('india', 'reported', true);
    const allIn = app.estimate({ tier: 'standard', task: 'text', inputTokens: 4000, outputTokens: 0, contextTokens: 40000, params: P }).total;
    const base  = app.estimate({ tier: 'standard', task: 'text', inputTokens: 4000, outputTokens: 0, contextTokens: 0, params: P }).total;
    return Math.abs(allIn - base) < 1e-9;      // no output tokens ⇒ context changes nothing
  })());
  ok('the extension agrees', Math.abs(
      ext.estimate({ tier: 'standard', task: 'text', region: 'india', inputTokens: 50, outputTokens: 800, contextTokens: 30000 }).total
      - app.estimate({ tier: 'standard', task: 'text', inputTokens: 50, outputTokens: 800, contextTokens: 30000, params: app.regionParams('india', 'reported', true) }).total) < 1e-9);
  ok('and it can be re-fitted without a release', (() => {
    const e = (new Function(load('engine.js') + '\nreturn {C, applyConstants, contextFactor};'))();
    const r = e.applyConstants(Object.assign(JSON.parse(load('docs/constants.json')), { version: 'z', context: { perThousand: 0.08, max: 6 } }));
    return r.ok && e.contextFactor(30000) > f(30000);
  })());
}

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
/* Every region the constants carry must have a human name in the phone app, or the user is shown
   a raw id. Five of them were, from the two-region era, until 2026-10-01 (I-52). */
{
  const dart = load('app/lib/features/settings/presentation/settings_page.dart');
  const labelled = [...dart.matchAll(/'([a-z_]+)':\s*'/g)].map(m => m[1]);
  const missing = Object.keys(app.C.regions).filter(r => !labelled.includes(r));
  ok('every region has a name in the phone app', missing.length === 0, missing.join(', '));
}
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

/* Parity used to mean only "both sides compute the same number from the same inputs". That let the
   phone app sit on its own invented defaults — 100 mL after we agreed 500, and a region id that had
   stopped existing — because neither was ever an input to a shared calculation. A shared default is
   as much a shared constant as a coefficient, so it is checked like one. */
ok('the agreed daily budget reaches the phone app', j.default_budget_ml === app.C.defaultBudgetMl,
   `engine ${app.C.defaultBudgetMl} vs published ${j.default_budget_ml}`);
ok('the starting region reaches the phone app', j.default_region_id === app.C.defaultRegionId,
   `engine ${app.C.defaultRegionId} vs published ${j.default_region_id}`);
ok('the starting region is a region that exists', !!j.regions[j.default_region_id], j.default_region_id);
{
  /* The crash this is here to prevent: a fresh install read `us_default`, the constants had no such
     region, and the first prompt counted threw on the null. No literal region id belongs in app
     code — the constants are the only list. */
  const stale = [];
  for (const f of ['app/lib/features/tracking/application/tracker.dart',
                   'app/lib/features/calculation_engine/data/aggregate_store.dart']) {
    const src = load(f);
    for (const m of src.matchAll(/'([a-z]+_[a-z_]+)'/g)) {
      const id = m[1];
      if (/^(us|eu|india|singapore|japan|nordic|colo)_/.test(id) && !app.C.regions[id]) stale.push(`${f}: ${id}`);
    }
  }
  ok('no phone code names a region the constants do not have', stale.length === 0, stale.join(', '));
}

/* ---------------------------------------------------------------------------------------------
   THE APP MUST NOT SILENTLY FALL BEHIND THE DESIGN

   Every suite here compared numbers. None compared the shipping app to the prototype it is built
   from, so the phone app sat three revisions behind for three weeks with CI fully green (I-58).
   These three checks are the gate: a contract stamp, the palette, and the copy rules. They cannot
   tell whether a screen looks right — nothing automated can — but they make drift loud.
--------------------------------------------------------------------------------------------- */
console.log('\nTHE PHONE APP AGAINST THE REFERENCE DESIGN');
{
  const html = load('sipcount.html');
  const dartContract = load('app/lib/app/ui_contract.dart');
  const proto = Number((html.match(/name="sipcount-ui-contract"\s+content="(\d+)"/) || [])[1]);
  const ack = Number((dartContract.match(/acknowledgedPrototypeContract\s*=\s*(\d+)/) || [])[1]);
  const impl = Number((dartContract.match(/implementedUiContract\s*=\s*(\d+)/) || [])[1]);

  ok('the prototype declares a UI contract number', Number.isFinite(proto));
  ok('the phone app declares which contract it implements', Number.isFinite(impl) && Number.isFinite(ack));
  /* Not `impl === proto` — that would leave CI red until the port lands, and a build that cannot be
     made green is a build that stops being read. It is the ACKNOWLEDGEMENT that must keep up: the
     next prototype change fails here until someone looks at the difference and decides. */
  ok('the prototype has not moved without anyone deciding what the app does about it',
     ack === proto,
     `prototype is at contract ${proto}, phone app last acknowledged ${ack}. Review what changed, ` +
     `then either port it and raise both numbers in app/lib/app/ui_contract.dart, or raise ` +
     `acknowledgedPrototypeContract alone and book the gap in docs/TRACEABILITY.md (P7).`);
  if (impl < proto) {
    console.log(`  · known gap: app implements ${impl}, prototype is ${proto} — booked as P7 / I-58`);
  }
}
{
  /* The palette drifted from true-black-and-green to navy-and-blue and nothing noticed, because
     theme.dart and the prototype's :root had no relationship beyond a comment claiming one. */
  const root = (load('sipcount.html').match(/:root\{([\s\S]*?)\}/) || [])[1] || '';
  const cssVar = n => ((root.match(new RegExp('--' + n + ':\\s*(#[0-9A-Fa-f]{6})')) || [])[1] || '').toUpperCase();
  const dart = load('app/lib/app/theme.dart');
  const dartColor = n => ((dart.match(new RegExp('\\b' + n + '\\s*=\\s*Color\\(0xFF([0-9A-Fa-f]{6})\\)')) || [])[1] || '').toUpperCase();
  const mapping = [['bg', 'ink'], ['surface', 'surface'], ['surface2', 'surface-2'], ['line', 'line'],
                   ['text', 'text'], ['muted', 'muted'], ['water', 'green'], ['waterDeep', 'green-deep'],
                   ['warn', 'amber'], ['danger', 'red'], ['good', 'green']];
  // both sides normalised to bare uppercase hex: the CSS carries a leading '#', the Dart does not
  const hex = s => s.replace('#', '');
  const wrong = mapping.filter(([d, c]) => dartColor(d) !== hex(cssVar(c)) || !dartColor(d))
                       .map(([d, c]) => `${d}=${dartColor(d) || '?'} but --${c}=${cssVar(c) || '?'}`);
  ok('the phone app uses the prototype palette', wrong.length === 0, wrong.join('; '));
}
{
  /* The copy pass retired this vocabulary from the prototype; "Scope 1 / Scope 2" survived on the
     phone's main screen for three weeks. A copy rule that holds in only one product is not a rule. */
  const banned = /\b(PUE|WUE|Scope [12]|tokens?)\b/;
  const offenders = [];
  for (const f of ['app/lib/features/tracking/presentation/today_page.dart',
                   'app/lib/features/settings/presentation/settings_page.dart']) {
    for (const m of load(f).matchAll(/'([^'\\]{12,})'/g)) {       // user-visible strings only
      if (banned.test(m[1])) offenders.push(`${f.split('/').pop()}: “${m[1].slice(0, 60)}”`);
    }
  }
  ok('no jargon in the phone app’s user-facing copy', offenders.length === 0, offenders.join(' | '));
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
