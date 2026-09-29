#!/usr/bin/env node
/* =====================================================================================
   One calculator, three products.

   `engine.js` at the repo root is the ONLY place the maths and the constants live. This
   script pushes it out to the two products that cannot import it directly:

     browser_extension/engine.js   — the engine verbatim, plus a small adapter that keeps
                                     the `SIP.*` surface the extension's scripts already use
     app/assets/calc/models.v2.json — the same constants as data, for the Flutter app

   Both outputs are GENERATED. Never hand-edit them; edit engine.js and run this:

       node tools/build-shared.js

   Why this exists: for two weeks the prototype's maths improved and the other two stayed
   on the 2026-09-14 constants. A heavy prompt came out 24% apart, and the extension had
   no India region at all — so an Indian user was shown roughly half the real figure. An
   app whose whole claim is an honest number cannot ship three of them.
   `docs/test/parity.js` fails the build if these outputs and engine.js ever disagree.
   ===================================================================================== */
const fs = require('fs'), path = require('path');
const ROOT = path.join(__dirname, '..');
const engineSrc = fs.readFileSync(path.join(ROOT, 'engine.js'), 'utf8');
const { C, estimate, regionParams, tok, fmt } =
  (new Function(engineSrc + '\nreturn {C, estimate, regionParams, tok, fmt};'))();

/* ---------- 1. the browser extension ---------------------------------------------------
   Everything below the engine is presentation or detection that only the extension needs:
   turning a model name on screen into a tier, and turning millilitres into everyday words. */
const ADAPTER = `
/* ---------------------------------------------------------------------------------------
   Extension adapter. Above this line is engine.js, copied verbatim by tools/build-shared.js.
   Below it is the part only the extension needs: reading a tier out of the model name shown
   on the page, and the everyday comparison in the popup. Keeps the SIP.* names the existing
   content/background/popup scripts already call, so nothing else had to change.
   --------------------------------------------------------------------------------------- */
const SIP = (() => {
  const DEFAULT_REGION = 'us_hyperscale';
  const EQ = [['bottle',500],['coffee cup',240],['espresso',30],['sip',15]];
  const paramsFor = (region, cooling, hydro) => {
    const id = C.regions[region] ? region : DEFAULT_REGION;
    const cool = C.cooling[cooling] ? cooling : (C.regions[id].defaultCooling || 'reported');
    return regionParams(id, cool, hydro !== false);
  };
  function resolveTier(vendor, hint){
    const v = C.vendorMap[vendor] || C.vendorMap.unknown, h = (hint||'').toLowerCase();
    let best = null;
    for(const p in v.p) if(h.includes(p) && (!best || p.length > best.length)) best = p;
    return best ? v.p[best] : v.def;
  }
  /* same call shape the extension always used; outputTokens stays optional, so when the
     page gives us no answer length the task default applies, exactly as in the app */
  function est({ tier, task, region, inputTokens = 0, outputTokens = null, items = 1, cooling, hydro }){
    const e = estimate({ tier, task, inputTokens, outputTokens, items, params: paramsFor(region, cooling, hydro) });
    return Object.assign({}, e, { tokens: e.weightedTokens });
  }
  function savingsIfLighter(tier, task, region, inputTokens){
    const alt = tier === 'reasoning' ? 'standard' : tier === 'standard' ? 'lightweight' : null;
    if(!alt || task === 'image') return { alt:null, ml:0 };
    return { alt, ml: est({tier,task,region,inputTokens}).total - est({tier:alt,task,region,inputTokens}).total };
  }
  function equiv(ml){
    for(const [l,v] of EQ) if(ml >= v) return \`\${fmt(ml/v,1)} \${l}\${ml/v >= 1.95 ? 's' : ''}\`;
    return \`\${fmt(ml/15,1)} of a sip\`;
  }
  return { C, tok, fmt, resolveTier, estimate: est, savingsIfLighter, equiv, DEFAULT_REGION };
})();
if (typeof module !== 'undefined') module.exports = SIP;
`;

const banner = `/* GENERATED FILE — do not edit.
   Source: engine.js · rebuild with: node tools/build-shared.js
   Constants version: ${C.version} */\n`;
fs.writeFileSync(path.join(ROOT, 'browser_extension', 'engine.js'), banner + engineSrc + ADAPTER);

/* a region is only as trustworthy as its least certain input */
const RANK = { low: 0, medium: 1, high: 2 };
const weakest = list => list.reduce((a, b) => (RANK[b] ?? 0) < (RANK[a] ?? 0) ? b : a, 'high');

/* ---------- 2. the Flutter app ---------------------------------------------------------
   Data, not code. Written to models.v2.json so the live file is untouched until the Dart
   side is ready to read this schema. */
const models = {
  schema_version: '2.0.0',
  constants_version: C.version,
  generated_by: 'tools/build-shared.js from engine.js — do not hand-edit',
  notes: [
    'Estimates from public sources; vendors do not publish per-query figures for most models.',
    'Units: energy in Wh; WUE and EWIF in L/kWh (numerically identical to mL/Wh), so water_mL = energy_Wh * pue * (wue_site + ewif_grid).',
    'Output tokens are weighted 5x input tokens and energy_wh_per_1k_tokens is re-normalised by 400/320 so the reference prompt (100 in + 300 out) is unchanged at 0.30 Wh on the standard tier. See docs/TOKEN-ECONOMICS.md.'
  ],
  token_estimation: { chars_per_token: C.charsPerToken },
  token_weights: C.tokenWeights,
  task_profiles: Object.fromEntries(Object.entries(C.tasks).map(([id, t]) => [id,
    t.fixed != null ? { fixed_energy_wh_per_item: t.fixed, label: t.label }
                    : { default_output_tokens: t.out, energy_multiplier: 1.0, label: t.label }])),
  /* the key is deliberately NOT the old `energy_wh_per_1k_tokens`: the value now means *weighted*
     tokens, so a reader that has not been updated should fail loudly on a missing key rather than
     quietly compute a number that is 24% out. */
  model_tiers: Object.fromEntries(Object.entries(C.tiers).map(([id, t]) => [id,
    { energy_wh_per_1k_weighted_tokens: t.wh1k, label: t.label, confidence: 'medium' }])),
  cooling_overrides: C.cooling,
  regions: Object.fromEntries(Object.entries(C.regions).map(([id, r]) => [id, {
    label: r.label, short: r.short, pue: r.pue,
    wue_site_l_per_kwh: r.wueSite,
    wue_grid_l_per_kwh: r.ewif.incl,                       // default: hydro reservoir evaporation counted
    wue_grid_l_per_kwh_excluding_hydro: r.ewif.excl,       // the Settings toggle picks this instead
    default_cooling: r.defaultCooling, water_stress_class: r.stress,
    confidence: weakest([r.conf.pue, r.conf.wueSite, r.conf.ewifIncl]),
    confidence_detail: r.conf, note: r.note, sources: r.sources
  }])),
  vendor_model_map: Object.fromEntries(Object.entries(C.vendorMap).map(([v, m]) =>
    [v, { default_tier: m.def, patterns: m.p }])),
  equivalents_ml: C.opp,
  range: C.range,
  /* golden values the Dart tests must reproduce exactly — generated, so they can never be
     quietly edited to make a failing test pass */
  golden: (() => {
    const cases = [
      { region:'us_hyperscale', tier:'standard',    task:'text', inputTokens:100, outputTokens:300 },
      { region:'india',         tier:'standard',    task:'text', inputTokens:100, outputTokens:300 },
      { region:'us_hyperscale', tier:'reasoning',   task:'code', inputTokens:500, outputTokens:600 },
      { region:'eu_average',    tier:'lightweight', task:'text', inputTokens:50,  outputTokens:120 },
      { region:'singapore',     tier:'standard',    task:'image', inputTokens:0,  outputTokens:0, items:2 }
    ];
    return cases.map(c => {
      const p = regionParams(c.region, C.regions[c.region].defaultCooling || 'reported', true);
      const e = estimate({ ...c, params: p });
      return { ...c, expect_energy_wh: +e.energyWh.toFixed(6), expect_scope1_ml: +e.s1.toFixed(6),
               expect_scope2_ml: +e.s2.toFixed(6), expect_total_ml: +e.total.toFixed(6) };
    });
  })()
};
fs.writeFileSync(path.join(ROOT, 'app', 'assets', 'calc', 'models.v2.json'), JSON.stringify(models, null, 2) + '\n');

console.log('wrote browser_extension/engine.js   (engine + adapter)');
console.log('wrote app/assets/calc/models.v2.json (constants ' + C.version + ', ' +
            Object.keys(C.regions).length + ' regions, ' + models.golden.length + ' golden cases)');
