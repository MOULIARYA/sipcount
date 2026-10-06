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
const { C, estimate, regionParams, tok, fmt, ZONE_UI, opportunityCost, hiddenFrom } =
  (new Function(engineSrc + '\nreturn {C, estimate, regionParams, tok, fmt, ZONE_UI, opportunityCost, hiddenFrom};'))();

/* ---------- 1. the browser extension ---------------------------------------------------
   Everything below the engine is presentation or detection that only the extension needs:
   turning a model name on screen into a tier, and turning millilitres into everyday words. */
const ADAPTER = `
/* ---------------------------------------------------------------------------------------
   Extension adapter. Everything above is engine.js, copied verbatim, and everything in this
   file lives INSIDE the closure below — only \`SIP\` reaches the global scope.

   That matters: \`background.js\` is loaded with importScripts(), which shares one global
   scope with this file. The engine declares dayKey, fmt, tok and others at its top level,
   and background.js declares its own dayKey — two \`const dayKey\` in one scope is a syntax
   error, and Chrome answers by refusing to register the service worker at all
   ("Status code: 15"). Wrapping is the fix; parity.js asserts nothing else leaks.
   --------------------------------------------------------------------------------------- */
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
  function est({ tier, task, region, inputTokens = 0, outputTokens = null, hiddenTokens = 0, contextTokens = 0, items = 1, cooling, hydro }){
    const e = estimate({ tier, task, inputTokens, outputTokens, hiddenTokens, contextTokens, items, params: paramsFor(region, cooling, hydro) });
    return Object.assign({}, e, { tokens: e.weightedTokens });
  }
  /* Compared on the SAME turn, not on a hypothetical 300-token answer — otherwise the popup can
     claim a lighter model "would have saved" more water than the turn actually used. */
  function savingsIfLighter(tier, task, region, inputTokens, outputTokens, hiddenTokens){
    const alt = tier === 'reasoning' ? 'standard' : tier === 'standard' ? 'lightweight' : null;
    if(!alt || task === 'image') return { alt:null, ml:0 };
    /* A turn that spent most of its effort off-screen was researching, calling tools or writing a
       file. Telling someone a light model "would have saved 96 mL" is wrong twice: a light model
       could not have done the job, and the comparison assumes it would have done the same work.
       Offer nothing rather than bad advice. */
    if(hiddenTokens > outputTokens) return { alt:null, ml:0 };
    const a = est({tier,task,region,inputTokens,outputTokens,hiddenTokens}).total;
    const b = est({tier:alt,task,region,inputTokens,outputTokens,hiddenTokens}).total;
    return { alt, ml: a - b };
  }
  function equiv(ml){
    for(const [l,v] of EQ) if(ml >= v) return \`\${fmt(ml/v,1)} \${l}\${ml/v >= 1.95 ? 's' : ''}\`;
    return \`\${fmt(ml/15,1)} of a sip\`;
  }
  return { C, tok, fmt, scriptOf, hiddenFrom, contextFactor, zone, ZONE_UI, opportunityCost, applyConstants, resolveTier, estimate: est, savingsIfLighter, equiv, DEFAULT_REGION };
`;

const banner = `/* GENERATED FILE — do not edit.
   Source: engine.js · rebuild with: node tools/build-shared.js
   Constants version: ${C.version}

   Everything is sealed inside one closure so that only \`SIP\` enters the global scope, because
   background.js shares that scope via importScripts(). */\n`;
fs.writeFileSync(path.join(ROOT, 'browser_extension', 'engine.js'),
  banner + 'const SIP = (() => {\n' + engineSrc + ADAPTER + '\n})();\n' +
  "if (typeof module !== 'undefined') module.exports = SIP;\n");

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
  /* The phone app hardcoded its own 100 mL for three weeks because this generator never offered it
     the agreed number — a hole in "one calculator" that parity.js could not see, because it only
     ever compared what both sides computed, never what only one side knew. */
  default_budget_ml: C.defaultBudgetMl,
  default_region_id: C.defaultRegionId,
  token_estimation: { chars_per_token: C.charsPerToken },
  /* The two corrections that make a heavy turn honest. Neither was published, so the phone's
     calculator was quietly a simpler, older engine than the one the extension and the prototype
     share — a 28× undercount on an agentic turn, and `parity.js` could not see it because its
     golden cases only ever exercised the inputs both sides happened to support. */
  thinking: { tokens_per_sec: C.thinking.tokensPerSec, floor_sec: C.thinking.floorSec, max_sec: C.thinking.maxSec },
  context: { per_thousand: C.context.perThousand, max: C.context.max },
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

  /* ---- content, not just coefficients -------------------------------------------------------
     Until 2026-10-06 this generator published only the numbers needed to CALCULATE, so the phone
     app could not render the prototype's zone pill, fact banner, brand breakdown or
     opportunity-cost line — the words were never sent to it. Any port would have had to retype
     the copy into Dart, where it would start drifting the same day. The prototype is the reference
     design, so its content ships from here too, and `parity.js` holds the two sides equal. */
  zones: C.zones,
  zone_ui: Object.fromEntries(Object.entries(ZONE_UI).map(([z, u]) => [z, { icon: u.ico, label: u.label }])),
  brands: C.brands,
  /* The five mascot frames, 0 = pristine → 4 = at the limit, exactly as the prototype indexes
     them. The art is Mouli's and lives in `assets/`, so the phone shows the same pictures rather
     than a Flutter re-creation of them. */
  characters: Object.fromEntries(['plant', 'bear', 'glacier', 'leopard']
    .map(n => [n, [0, 1, 2, 3, 4].map(i => `${n}-${i}.webp`)])),
  facts: C.facts.map(f => ({ emoji: f.e, hook: f.hook, text: f.t, full: f.full, source: f.s, url: f.url })),
  fact_cadence: { every_prompts: 5, max_per_day: 2, on_open: false },
  range: C.range,
  /* The unseen-work rule itself, as fixtures. `estimate()` charges whatever hidden tokens it is
     handed; the judgement about how many there are — and that a reasoning model has none, because
     it is already priced at ~10× — lives in `hiddenFrom()`. The phone has to apply the same
     judgement, so it is pinned rather than described. */
  hidden_rule: (() => {
    const cases = [
      { active_ms: 1500,   output_tokens: 300, tier: 'standard'    },   // the floor: nothing yet
      { active_ms: 5000,   output_tokens: 300, tier: 'standard'    },
      { active_ms: 30000,  output_tokens: 300, tier: 'standard'    },
      { active_ms: 300000, output_tokens: 600, tier: 'standard'    },   // a research turn
      { active_ms: 300000, output_tokens: 600, tier: 'reasoning'   },   // must be 0 — no double-count
      { active_ms: 300000, output_tokens: 600, tier: 'lightweight' },
      { active_ms: 0,      output_tokens: 300, tier: 'standard'    },
      { active_ms: 9e9,    output_tokens: 300, tier: 'standard'    }    // clamped at max_sec
    ];
    return cases.map(c => ({ ...c,
      expect_hidden_tokens: hiddenFrom({ activeMs: c.active_ms, outputTokens: c.output_tokens, tier: c.tier }) }));
  })(),

  /* golden values the Dart tests must reproduce exactly — generated, so they can never be
     quietly edited to make a failing test pass */
  golden: (() => {
    const cases = [
      { region:'us_hyperscale', tier:'standard',    task:'text', inputTokens:100, outputTokens:300 },
      { region:'india',         tier:'standard',    task:'text', inputTokens:100, outputTokens:300 },
      { region:'us_hyperscale', tier:'reasoning',   task:'code', inputTokens:500, outputTokens:600 },
      { region:'eu_average',    tier:'lightweight', task:'text', inputTokens:50,  outputTokens:120 },
      { region:'singapore',     tier:'standard',    task:'image', inputTokens:0,  outputTokens:0, items:2 },
      /* The two corrections the Dart side could not even express until 2026-10-06. Pinned here
         because a golden case is the only thing that would have caught it: the earlier five all
         happened to use the subset both engines supported, so parity passed while the phone ran a
         simpler calculator (I-62). An agentic research turn and a long thread are exactly the
         cases where the two disagree by an order of magnitude. */
      { region:'us_hyperscale', tier:'standard',    task:'text', inputTokens:100, outputTokens:300, hiddenTokens:24300 },
      { region:'india',         tier:'standard',    task:'text', inputTokens:100, outputTokens:300, contextTokens:30000 },
      /* A reasoning turn carries NO hidden tokens — not because estimate() refuses them (it does
         not; it charges whatever it is handed) but because hiddenFrom() returns 0 for that tier.
         Pinning the combination here would pin a state the product cannot reach; the rule itself
         is pinned in `hidden_rule` below instead. */
      { region:'us_hyperscale', tier:'reasoning',   task:'text', inputTokens:100, outputTokens:300, hiddenTokens:0 },
      { region:'eu_average',    tier:'lightweight', task:'code', inputTokens:500, outputTokens:600, hiddenTokens:2250, contextTokens:8000 }
    ];
    return cases.map(c => {
      const p = regionParams(c.region, C.regions[c.region].defaultCooling || 'reported', true);
      const e = estimate({ ...c, params: p });
      return { ...c, expect_energy_wh: +e.energyWh.toFixed(6), expect_scope1_ml: +e.s1.toFixed(6),
               expect_scope2_ml: +e.s2.toFixed(6), expect_total_ml: +e.total.toFixed(6),
               expect_input_share: +e.inputShare.toFixed(6) };
    });
  })()
};
fs.writeFileSync(path.join(ROOT, 'app', 'assets', 'calc', 'models.v2.json'), JSON.stringify(models, null, 2) + '\n');

/* The mascot art is Mouli's and lives in `assets/` at the repo root, where the prototype reads it.
   Flutter can only bundle assets inside the app package, so the frames the app is told about are
   copied in from there — generated, like models.v2.json, so the root stays the single source and
   the phone can never show a different picture from the prototype. Only the frames listed in
   `characters` are copied: 20 files, under a megabyte. */
{
  const dest = path.join(ROOT, 'app', 'assets', 'characters');
  fs.mkdirSync(dest, { recursive: true });
  const wanted = new Set(Object.values(models.characters).flat());
  for (const f of fs.readdirSync(dest)) if (!wanted.has(f)) fs.unlinkSync(path.join(dest, f));
  let copied = 0;
  for (const f of wanted) {
    const src = path.join(ROOT, 'assets', f);
    if (!fs.existsSync(src)) { console.error(`MISSING mascot frame: assets/${f}`); process.exit(1); }
    const to = path.join(dest, f);
    // byte-compare rather than always copying, so the CI staleness gate stays quiet on a no-op
    if (!fs.existsSync(to) || !fs.readFileSync(src).equals(fs.readFileSync(to))) { fs.copyFileSync(src, to); copied++; }
  }
  console.log(`synced app/assets/characters/   (${wanted.size} frames, ${copied} updated)`);
}

/* ---------- 3. the constants people can pick up without a release --------------------------
   Numbers only, served from GitHub Pages, checked hard by applyConstants() before anything is
   believed. This is how a fitted multiplier reaches an installed app. */
const published = {
  schema: 'sipcount-constants/1',
  version: C.version,
  published_at: new Date().toISOString().slice(0, 10),
  note: 'GENERATED from engine.js. Numbers only — never code. Every value is re-checked against a physical band by applyConstants() before it is used; anything out of range rejects the whole file and the app keeps what it shipped with.',
  outputPerInput: C.outputPerInput,
  charsPerToken: C.charsPerToken,
  charsPerTokenByScript: C.charsPerTokenByScript,
  thinking: { tokensPerSec: C.thinking.tokensPerSec },
  context: { perThousand: C.context.perThousand, max: C.context.max },
  tiers: Object.fromEntries(Object.entries(C.tiers).map(([id, t]) => [id, { base: t.base }])),
  regions: Object.fromEntries(Object.entries(C.regions).map(([id, r]) => [id, { pue: r.pue, wueSite: r.wueSite, ewif: r.ewif }]))
};
fs.writeFileSync(path.join(ROOT, 'docs', 'constants.json'), JSON.stringify(published, null, 2) + '\n');

console.log('wrote browser_extension/engine.js   (engine + adapter)');
console.log('wrote docs/constants.json           (publishable, ' + Object.keys(published.regions).length + ' regions)');
console.log('wrote app/assets/calc/models.v2.json (constants ' + C.version + ', ' +
            Object.keys(C.regions).length + ' regions, ' + models.golden.length + ' golden cases)');
